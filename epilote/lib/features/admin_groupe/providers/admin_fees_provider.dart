import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/paged_fetch.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_settings_provider.dart' show adminGroupProfileProvider;

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS & TARIFS DU GROUPE — le seul endroit où un montant se crée.
//
//  Un barème n'est pas une donnée de l'école : dans le public il vient d'un
//  arrêté, dans le privé du siège. L'école reçoit et applique (décision D2,
//  migration 0096). Ici, l'écriture est autorisée par la RLS
//  (`fee_structures_insert/update/delete` = `is_admin_groupe()`).
//
//  ⚠️ admin_groupe travaille EN LIGNE, sur Supabase direct. Jamais `db.watch()`.
//  C'est la règle centrale du projet.
//
//  ⚠️ TOUTE lecture de table passe par `fetchAllRows`. PostgREST plafonne une
//  réponse à 1 000 lignes SANS le signaler : sur un ministère de 1 000 écoles,
//  la liste déroulante « Portée » perdait les dernières écoles de l'alphabet —
//  qui devenaient donc intarifables, sans le moindre message — et le KPI
//  « Tarifs publiés » affichait la limite de pagination comme un effectif.
//  Même piège, mêmes dégâts que dans `admin_schools_provider` (commit 89e04e3).
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();

/// Le catalogue des types de frais, aligné sur l'enum `fee_type` en base
/// (`inscription, mensualite, frais_examens, autre, cotisation_ape`).
///
/// Il vit ici, avec la donnée, et non dans le formulaire : l'écran, la ligne de
/// liste et la boîte de saisie le lisent tous les trois. Deux libellés qui
/// dérivent l'un de l'autre sur une page d'argent, c'est un ticket de support.
const kAdminFeeTypes = <String, String>{
  'inscription': 'Inscription',
  'mensualite': 'Mensualité',
  'frais_examens': 'Frais d\'examens',
  'cotisation_ape': 'Cotisation APE',
  'autre': 'Autre',
};

String adminFeeTypeLabel(String? t) => kAdminFeeTypes[t] ?? 'Autre';

/// Le groupe relève-t-il de l'enseignement PUBLIC ? Lu en base (`group_type`),
/// jamais déduit d'un nom. `null` tant que le secteur n'est pas connu.
final adminGroupePublicProvider = Provider.autoDispose<bool?>((ref) {
  final g = ref.watch(adminGroupProfileProvider).valueOrNull;
  return g == null ? null : g.groupType == 'public';
});

/// Les types de frais qu'on peut proposer à ce groupe.
///
/// ⚠️ **La mensualité disparaît du choix quand le groupe est PUBLIC** : la loi
/// 25-95 (art. 1) pose que l'enseignement public est gratuit. Le serveur la
/// refuse de toute façon (migration 0100) — mais un choix qui n'existe pas vaut
/// mieux qu'un refus après coup. C'est la même doctrine que le retrait des
/// mutations de barème côté école : « l'absence de bouton est la vraie
/// protection, la règle serveur n'est que le filet ».
///
/// Deux précautions :
///  • secteur INCONNU (chargement, erreur) → on ne présume rien, on laisse la
///    liste entière et c'est le serveur qui tranche, avec son message ;
///  • [typeActuel] est toujours réintroduit — on modifie un barème hérité sans
///    que la liste perde sa propre valeur (un `DropdownButtonFormField` dont la
///    `value` est absente des `items` lève une assertion), et le RETRAIT d'une
///    mensualité devenue illégale reste possible.
Map<String, String> typesDeFraisProposables({
  required bool? groupePublic,
  String? typeActuel,
}) {
  if (groupePublic != true) return kAdminFeeTypes;
  return {
    for (final e in kAdminFeeTypes.entries)
      if (e.key != 'mensualite' || e.key == typeActuel) e.key: e.value,
  };
}

/// Portée d'un barème : tout le réseau, ou une école désignée.
/// Dans les deux cas c'est le GROUPE qui écrit — `school_id` dit « s'applique
/// à », jamais « créé par ».
class AdminFee {
  const AdminFee({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.schoolId,
    required this.schoolName,
    required this.levelId,
    required this.levelName,
    required this.dueDay,
    required this.sourceReference,
    required this.isActive,
    required this.examSessionId,
    required this.educationLevelId,
    this.examId,
    this.examName,
  });

  final String id, name, feeType;
  final int amount;
  final String? schoolId, schoolName, levelId, levelName, sourceReference;
  final int? dueDay;

  /// Niveau du RÉFÉRENTIEL PARTAGÉ (migration 0101). C'est ainsi — et
  /// uniquement ainsi — qu'un tarif de portée réseau vise un niveau : « la 6e »
  /// du pays, et non « la 6e de l'école A ».
  final String? educationLevelId;

  /// Un tarif retiré reste en base — un reçu ne doit jamais renvoyer à un
  /// barème introuvable — mais ne s'applique plus. L'écran le range dans
  /// « Retirés », d'où il peut être rétabli.
  final bool isActive;

  /// Session d'examen précise. Ne sert qu'à DÉROGER — un rattrapage au tarif
  /// différent. Le ciblage courant est [examId].
  final String? examSessionId;

  /// L'EXAMEN visé (migration 0103) : « Baccalauréat technique », stable d'une
  /// année sur l'autre. Chaque poste résout la session de SON année scolaire.
  ///
  /// C'est ce qui rend le rattachement tenable : viser la session obligeait à
  /// re-pointer le tarif tous les ans, et surtout à attendre l'ouverture des
  /// inscriptions pour publier un montant fixé par arrêté.
  final String? examId;
  final String? examName;

  bool get estReseau => schoolId == null;

  /// Un frais d'examen publié sans aucune cible : la caisse de l'examen restera
  /// fermée alors que l'écran affiche un tarif. Panne muette, signalée.
  bool get examenOrphelin =>
      feeType == 'frais_examens' && examSessionId == null && examId == null;
}

/// Les barèmes du groupe pour une année donnée, toutes portées confondues —
/// **actifs et retirés**. Le tri des uns et des autres se fait à l'écran :
/// masquer les retirés ici rendrait le retrait irréversible depuis l'interface.
final adminFeesProvider = FutureProvider.autoDispose
    .family<List<AdminFee>, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || yearId.isEmpty) return const [];

  final rows = await fetchAllRows(() => client
      .from('fee_structures')
      .select('id, name, fee_type, amount_xaf, school_id, applies_to_level_id, '
          'applies_to_education_level_id, due_day_of_month, source_reference, '
          'is_active, exam_session_id, applies_to_exam_id, '
          'schools(name), school_levels(name), education_levels(name), '
          'national_exams(name)')
      .eq('group_id', groupId)
      .eq('academic_year_id', yearId)
      // ⚠️ `fee_type` seul n'est pas un ordre TOTAL : des dizaines de lignes le
      // partagent. Or `fetchAllRows` rejoue la requête page par page, et deux
      // requêtes successives n'ont aucune obligation de rendre les ex æquo dans
      // le même ordre. Un tarif pouvait donc être sauté à la frontière de deux
      // pages, ou compté deux fois. `id` clôt le tri.
      .order('fee_type')
      .order('id'));

  return [
    for (final r in rows)
      AdminFee(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '—',
        feeType: (r['fee_type'] as String?) ?? 'autre',
        amount: (r['amount_xaf'] as num?)?.round() ?? 0,
        schoolId: r['school_id'] as String?,
        schoolName: (r['schools'] as Map?)?['name'] as String?,
        levelId: r['applies_to_level_id'] as String?,
        educationLevelId: r['applies_to_education_level_id'] as String?,
        // Un seul des deux est renseigné (contrainte 0101) : le libellé vient
        // de celui qui l'est, et la ligne de liste n'a pas à savoir lequel.
        levelName: (r['school_levels'] as Map?)?['name'] as String? ??
            (r['education_levels'] as Map?)?['name'] as String?,
        dueDay: (r['due_day_of_month'] as num?)?.round(),
        sourceReference: r['source_reference'] as String?,
        isActive: (r['is_active'] as bool?) ?? true,
        examSessionId: r['exam_session_id'] as String?,
        examId: r['applies_to_exam_id'] as String?,
        examName: (r['national_exams'] as Map?)?['name'] as String?,
      ),
  ];
});

typedef OptionRef = ({String id, String name});

/// Un niveau du référentiel, AVEC SON ORIGINE.
///
/// Le drapeau n'est pas décoratif. Le référentiel affiché mélange deux choses :
/// le squelette national (`group_id IS NULL`, commun au pays) et les entrées que
/// le groupe a créées pour lui. Rien ne les distinguait à l'œil, alors que deux
/// entrées peuvent décrire LA MÊME année — « Sixième (6e) » au national et
/// « 6ème » chez le METP. Un tarif posé sur l'une n'atteint pas les écoles
/// rattachées à l'autre. Cf. l'écran « Rattachement des niveaux ».
typedef NiveauRef = ({String id, String name, bool duGroupe});

/// Les écoles du groupe — choix de portée du barème.
final adminFeeSchoolsProvider =
    FutureProvider.autoDispose<List<OptionRef>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];
  final rows = await fetchAllRows(() => client
      .from('schools')
      .select('id, name')
      .eq('group_id', groupId)
      .eq('is_active', true)
      // Deux écoles homonymes existent (« CEG de Kinkala »). `id` clôt le tri :
      // sans lui, la pagination pourrait en perdre une (cf. adminFeesProvider).
      .order('name')
      .order('id'));
  return [
    for (final r in rows)
      (id: r['id'] as String, name: (r['name'] as String?) ?? '—'),
  ];
});

/// Les niveaux du RÉFÉRENTIEL PARTAGÉ — le seul ciblage possible sur un tarif
/// de portée réseau (migration 0101).
///
/// C'est ce qui permet au ministère d'écrire une fois « inscription en 6e =
/// X » et de couvrir la 6e de ses 1 000 écoles. La correspondance existe déjà :
/// `school_levels.education_level_id` est renseigné à 100 % dans les groupes
/// réels, et chaque poste traduit tout seul le niveau national en son propre
/// niveau (cf. `obligation_provider`).
///
/// Le libellé porte le CYCLE et la FILIÈRE : « 1ère année » existe une
/// quinzaine de fois dans le référentiel technique, une par métier. Sans eux,
/// le ministère choisirait au hasard.
final adminEducationLevelsProvider =
    FutureProvider.autoDispose<List<NiveauRef>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];

  // Le référentiel NATIONAL porte `group_id IS NULL` ; un groupe peut y ajouter
  // ses variantes. La RLS autorise déjà la lecture des deux.
  final rows = await fetchAllRows(() => client
      .from('education_levels')
      .select('id, name, order_index, group_id, '
          'education_cycles(name), education_programs(name)')
      .or('group_id.is.null,group_id.eq.$groupId')
      .eq('is_active', true)
      .order('order_index')
      .order('id'));

  final niveaux = [
    for (final r in rows)
      (
        id: r['id'] as String,
        cycle: ((r['education_cycles'] as Map?)?['name'] as String? ?? '').trim(),
        filiere:
            ((r['education_programs'] as Map?)?['name'] as String? ?? '').trim(),
        niveau: ((r['name'] as String?) ?? '—').trim(),
        ordre: (r['order_index'] as num?)?.toInt() ?? 0,
        // `group_id` non nul = le groupe a créé cette entrée lui-même.
        duGroupe: r['group_id'] != null,
      ),
  ]..sort((a, b) {
      final c = a.cycle.compareTo(b.cycle);
      if (c != 0) return c;
      final f = a.filiere.compareTo(b.filiere);
      if (f != 0) return f;
      final o = a.ordre.compareTo(b.ordre);
      return o != 0 ? o : a.niveau.compareTo(b.niveau);
    });

  return [
    for (final n in niveaux)
      (
        id: n.id,
        name: [
          if (n.cycle.isNotEmpty) n.cycle,
          if (n.filiere.isNotEmpty) n.filiere,
          n.niveau,
        ].join(' · '),
        duGroupe: n.duGroupe,
      ),
  ];
});

/// Les niveaux D'UNE ÉCOLE — ciblage optionnel d'un barème d'établissement.
///
/// ⚠️ **Un tarif de portée réseau ne peut pas cibler un niveau**, et c'est une
/// contrainte de fond, pas un oubli : `fee_structures.applies_to_level_id`
/// pointe sur `school_levels`, dont chaque ligne appartient à UNE école — 178
/// lignes pour 13 noms de niveau sur 37 écoles. Un tarif réseau visant « la
/// 6e de l'école A » ne matcherait jamais les élèves de l'école B, et le
/// ministère croirait avoir tarifé tout le pays.
///
/// Un tarif réseau par niveau passe donc par le référentiel partagé
/// (`adminEducationLevelsProvider` / `applies_to_education_level_id`, migration
/// 0101) : ce provider-ci ne sert qu'au ciblage d'un barème d'ÉTABLISSEMENT.
/// Cf. `[[premiere-heure-etablissement]]` : joindre `school_levels` sur le
/// seul `group_id` avait déjà fait remonter 42 niveaux au lieu de 6.
final adminFeeLevelsProvider = FutureProvider.autoDispose
    .family<List<OptionRef>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  if (schoolId.isEmpty) return const [];
  final rows = await fetchAllRows(() => client
      .from('school_levels')
      .select('id, name, order_index')
      .eq('school_id', schoolId)
      .eq('is_active', true)
      .order('order_index')
      .order('id'));
  return [
    for (final r in rows)
      (id: r['id'] as String, name: ((r['name'] as String?) ?? '—').trim()),
  ];
});

/// Les examens nationaux — la cible d'un `frais_examens` (migration 0103).
///
/// Référentiel NATIONAL, sans `group_id` : les mêmes examens pour tout le pays,
/// déjà diffusés à tous les postes par le bucket global. Le libellé porte le
/// code (« BAC ») autant que le nom, parce que c'est le code qui figure sur
/// les arrêtés.
///
/// ⚠️ La liste n'est PAS filtrée par tutelle, et c'est TOUJOURS voulu — mais
/// plus pour la raison qui était écrite ici. Le groupe porte désormais sa
/// tutelle (migration 0153) : l'argument « `school_groups` ne porte pas de
/// tutelle » est périmé, il ne justifie plus rien.
///
/// Ce qui justifie encore de ne pas filtrer : un frais d'examen doit pouvoir
/// viser TOUT examen auquel l'établissement présente effectivement des
/// candidats. Une liste trop étroite ne produit pas une erreur visible — elle
/// produit un frais MANQUANT, que personne ne remarque avant l'encaissement.
/// La tutelle est donc AFFICHÉE en clair sur chaque ligne, pour informer le
/// choix sans le restreindre.
final adminNationalExamsProvider =
    FutureProvider.autoDispose<List<OptionRef>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await fetchAllRows(() => client
      .from('national_exams')
      .select('id, code, name, tutelle, order_index')
      .eq('is_active', true)
      .order('order_index')
      .order('id'));
  return [
    for (final r in rows)
      (
        id: r['id'] as String,
        name: '${((r['name'] as String?) ?? '—').trim()} '
            '(${((r['code'] as String?) ?? '').trim()}'
            '${(r['tutelle'] as String?) == null ? '' : ' · ${(r['tutelle'] as String).toUpperCase()}'})',
      ),
  ];
});

/// Un barème de même portée est déjà publié pour cette année.
///
/// Le refus vient de l'index unique `uniq_fee_structure_portee_active`
/// (migration 0099). Sans lui, deux « Inscription » actives sur la même portée
/// cohabitaient et le poste de l'école en choisissait une au hasard.
class BaremeDoublonException implements Exception {
  const BaremeDoublonException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Refus MÉTIER prononcé par la base — aujourd'hui la mensualité dans le public
/// (migration 0100), demain d'autres règles.
///
/// Le message vient du serveur et s'affiche tel quel : c'est la BASE qui porte
/// le texte de la règle, avec sa référence légale. Le jour où la règle change,
/// le message suit sans qu'on retouche une ligne de Dart.
class BaremeInterditException implements Exception {
  const BaremeInterditException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Crée ou met à jour un barème. `schoolId` nul = tarif de tout le réseau.
///
/// Lève [BaremeDoublonException] si un barème actif couvre déjà exactement la
/// même portée : c'est un refus MÉTIER, pas une panne, et il doit se lire
/// comme tel.
Future<void> saveAdminFee(
  SupabaseClient client, {
  String? id,
  required String groupId,
  required String academicYearId,
  required String name,
  required String feeType,
  required int amount,
  String? schoolId,
  String? levelId,
  String? educationLevelId,
  String? examId,
  int? dueDay,
  required String sourceReference,
}) async {
  final now = DateTime.now().toIso8601String();
  final payload = <String, dynamic>{
    'group_id': groupId,
    'school_id': schoolId,
    'academic_year_id': academicYearId,
    'name': name,
    'fee_type': feeType,
    'amount_xaf': amount,
    // Les deux ciblages s'excluent (contrainte 0101) : un tarif réseau vise le
    // référentiel partagé, un tarif d'établissement vise ses propres niveaux.
    'applies_to_level_id': schoolId == null ? null : levelId,
    'applies_to_education_level_id': schoolId == null ? educationLevelId : null,
    // L'examen visé n'a de sens que sur un frais d'examen — la contrainte 0103
    // le refuse ailleurs, et changer de type doit RELÂCHER la cible plutôt que
    // faire échouer l'enregistrement sur une valeur devenue absurde.
    'applies_to_exam_id': feeType == 'frais_examens' ? examId : null,
    'due_day_of_month': dueDay,
    'source_reference': sourceReference,
    'is_active': true,
    'updated_at': now,
  };
  try {
    if (id != null) {
      await client.from('fee_structures').update(payload).eq('id', id);
    } else {
      await client.from('fee_structures').insert({
        ...payload,
        'id': _uuid.v4(),
        'created_at': now,
      });
    }
  } on PostgrestException catch (e) {
    // `P0001` = RAISE EXCEPTION d'un trigger métier : le message est rédigé
    // pour être lu par un agent, on le transmet mot pour mot.
    if (e.code == 'P0001') throw BaremeInterditException(e.message);
    if (e.code == '23505' ||
        e.message.toLowerCase().contains('duplicate key')) {
      final portee =
          '${schoolId == null ? 'année, sur tout le réseau' : 'école et cette année'}'
          '${levelId == null ? '' : ', sur ce niveau'}';
      // Un frais ANNEXE se heurte à son intitulé, pas à son type : depuis la
      // migration 0108, la cantine et le transport cohabitent. Dire à l'agent
      // de « modifier le tarif existant » l'enverrait écraser sa cantine pour
      // saisir son bus — le geste exact que la migration a supprimé.
      throw BaremeDoublonException(
        feeType == 'autre'
            ? 'Un frais annexe intitulé « $name » est déjà publié pour cette '
                '$portee. Deux lignes portant le même nom réclameraient deux '
                'fois la même chose. Modifiez celle qui existe, ou donnez à '
                'celle-ci un intitulé distinct — cantine, transport et tenue '
                'peuvent parfaitement coexister.'
            : 'Un tarif « ${adminFeeTypeLabel(feeType)} » est déjà publié pour '
                'cette $portee. '
                'Modifiez le tarif existant plutôt que d\'en publier un second : '
                'deux barèmes concurrents feraient réclamer deux sommes '
                'différentes au même élève.',
      );
    }
    rethrow;
  }
}

/// Retrait LOGIQUE. Un tarif qui a servi à des encaissements ne disparaît pas
/// de l'histoire : il cesse simplement de s'appliquer. Le supprimer vraiment
/// laisserait des reçus se référant à un barème introuvable.
Future<void> deactivateAdminFee(SupabaseClient client, String id) =>
    client.from('fee_structures').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

/// Rétablit un tarif retiré. Un retrait par erreur ferme la caisse de tout un
/// réseau : il doit se défaire d'un geste, pas d'une ressaisie.
///
/// Peut lever [BaremeDoublonException] : si un autre barème a été publié sur
/// la même portée entre-temps, c'est LUI qui fait foi.
Future<void> restoreAdminFee(SupabaseClient client, String id) async {
  try {
    await client.from('fee_structures').update({
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  } on PostgrestException catch (e) {
    // Rétablir une mensualité dans un groupe devenu public est refusé par le
    // trigger : le message légal remonte tel quel.
    if (e.code == 'P0001') throw BaremeInterditException(e.message);
    if (e.code == '23505' ||
        e.message.toLowerCase().contains('duplicate key')) {
      throw const BaremeDoublonException(
        'Un autre tarif couvre déjà cette portée pour cette année. Retirez-le '
        'd\'abord si celui-ci doit reprendre sa place.',
      );
    }
    rethrow;
  }
}
