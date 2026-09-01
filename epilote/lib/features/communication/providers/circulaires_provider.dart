import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CIRCULAIRE DE TUTELLE
//
//  ── CE QUE C'EST ───────────────────────────────────────────────────────────
//  Une note DESCENDANTE d'un ministère vers les établissements de son réseau,
//  datée et ACCUSÉE. Ce n'est pas une messagerie : ni fil, ni réponse, ni
//  destinataire individuel. Le seul retour est l'accusé de lecture — et c'est
//  tout l'intérêt : une circulaire dont on ne peut pas prouver la réception
//  n'a aucune valeur administrative.
//
//  ── DEUX LECTURES DU MÊME OBJET ───────────────────────────────────────────
//  • ÉMETTEUR (la tutelle) : ses circulaires, et qui les a lues.
//  • DESTINATAIRE (chaque groupe du réseau) : celles qui lui sont adressées,
//    et l'état d'accusé de CHACUNE de ses écoles.
//  Un seul module, deux providers — pas deux implémentations.
//
//  ⚠️ Les destinataires sont des ÉTABLISSEMENTS, jamais des personnes. La
//  chaîne est ministère → groupe / chef d'établissement. Jamais l'élève, jamais
//  le parent : ouvrir un canal par lequel l'État écrit aux familles d'une école
//  privée ne se déciderait pas par commodité technique, et ne se refermerait
//  plus.
//
//  ⚠️ Les deux écritures (publier, accuser) passent par des RPC. Aucun UPDATE
//  direct : un UPDATE que la RLS écarte ne lève RIEN — zéro ligne, 204, et
//  l'écran affiche « enregistré ». Une RPC qui refuse, elle, lève.
// ════════════════════════════════════════════════════════════════════════════

enum CirculairePriorite { normale, importante, urgente }

CirculairePriorite _prioriteDe(String? s) => switch (s) {
      'importante' => CirculairePriorite.importante,
      'urgente' => CirculairePriorite.urgente,
      _ => CirculairePriorite.normale,
    };

String prioriteLabel(CirculairePriorite p) => switch (p) {
      CirculairePriorite.normale => 'Normale',
      CirculairePriorite.importante => 'Importante',
      CirculairePriorite.urgente => 'Urgente',
    };

/// L'état d'accusé pour UNE école destinataire.
class CirculaireEcole {
  const CirculaireEcole({
    required this.schoolId,
    required this.nom,
    required this.groupId,
    this.luLe,
  });

  final String schoolId, nom, groupId;
  final DateTime? luLe;

  bool get lue => luLe != null;
}

class Circulaire {
  const Circulaire({
    required this.id,
    required this.emetteurGroupId,
    required this.objet,
    required this.corps,
    required this.priorite,
    required this.accuseRequis,
    required this.createdAt,
    this.emetteurNom,
    this.reference,
    this.cibleSecteur,
    this.cibleDepartement,
    this.echeance,
    this.publieeLe,
    this.nbDestinataires = 0,
    this.nbLus = 0,
    this.mesEcoles = const [],
  });

  factory Circulaire.fromRow(Map<String, dynamic> r) {
    final em = r['school_groups'] as Map<String, dynamic>?;
    return Circulaire(
      id: r['id'] as String,
      emetteurGroupId: r['emetteur_group_id'] as String,
      emetteurNom: em?['name'] as String?,
      reference: r['reference'] as String?,
      objet: r['objet'] as String? ?? '',
      corps: r['corps'] as String? ?? '',
      priorite: _prioriteDe(r['priorite'] as String?),
      cibleSecteur: r['cible_secteur'] as String?,
      cibleDepartement: r['cible_departement'] as String?,
      accuseRequis: r['accuse_requis'] as bool? ?? true,
      echeance: DateTime.tryParse(r['echeance'] as String? ?? ''),
      publieeLe: DateTime.tryParse(r['publiee_le'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime(2000),
    );
  }

  /// Depuis la ligne LOCALE `circulaire_destinataires` (migration 0167).
  ///
  /// Le poste ecole ne voit jamais la table `circulaires` : elle n'a pas de
  /// `school_id`, et les Sync Rules interdisent le JOIN en requete de
  /// parametres. C'est la ligne du destinataire qui porte l'instantane.
  ///
  /// `cibleSecteur` / `cibleDepartement` restent nuls, deliberement : le
  /// ciblage regarde l'emetteur. Une ecole n'a pas a savoir qui d'autre a
  /// recu la note — elle a recu la sienne.
  factory Circulaire.fromLigneLocale(Map<String, dynamic> r) => Circulaire(
        id: r['circulaire_id'] as String,
        emetteurGroupId: r['emetteur_group_id'] as String? ?? '',
        emetteurNom: r['emetteur_nom'] as String?,
        reference: r['reference'] as String?,
        objet: r['objet'] as String? ?? '',
        corps: r['corps'] as String? ?? '',
        priorite: _prioriteDe(r['priorite'] as String?),
        accuseRequis: (r['accuse_requis'] as num?)?.toInt() == 1,
        echeance: DateTime.tryParse(r['echeance'] as String? ?? ''),
        publieeLe: DateTime.tryParse(r['publiee_le'] as String? ?? ''),
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime(2000),
        mesEcoles: [
          CirculaireEcole(
            schoolId: r['school_id'] as String? ?? '',
            groupId: r['group_id'] as String? ?? '',
            nom: r['school_name'] as String? ?? '\u2014',
            luLe: DateTime.tryParse(r['lu_le'] as String? ?? ''),
          ),
        ],
      );

  final String id, emetteurGroupId, objet, corps;
  final String? emetteurNom, reference, cibleSecteur, cibleDepartement;
  final CirculairePriorite priorite;
  final bool accuseRequis;
  final DateTime? echeance, publieeLe;
  final DateTime createdAt;

  /// Côté ÉMETTEUR : l'assiette figée à la publication, et ce qui a été lu.
  final int nbDestinataires, nbLus;

  /// Côté DESTINATAIRE : l'état de chacune de MES écoles.
  final List<CirculaireEcole> mesEcoles;

  bool get publiee => publieeLe != null;

  /// ⚠️ `null` quand il n'y a aucun destinataire — pas 0 %. « 0 % lu » sur une
  /// circulaire qui n'est allée à personne se lirait comme un échec de
  /// diffusion alors qu'il n'y a rien eu à diffuser.
  double? get tauxLecture =>
      nbDestinataires == 0 ? null : nbLus * 100 / nbDestinataires;

  /// Côté destinataire : toutes mes écoles ont-elles accusé ?
  bool get toutesLues =>
      mesEcoles.isNotEmpty && mesEcoles.every((e) => e.lue);
  int get nbMesEcolesLues => mesEcoles.where((e) => e.lue).length;

  Circulaire copyWith({
    int? nbDestinataires,
    int? nbLus,
    List<CirculaireEcole>? mesEcoles,
  }) =>
      Circulaire(
        id: id,
        emetteurGroupId: emetteurGroupId,
        emetteurNom: emetteurNom,
        reference: reference,
        objet: objet,
        corps: corps,
        priorite: priorite,
        cibleSecteur: cibleSecteur,
        cibleDepartement: cibleDepartement,
        accuseRequis: accuseRequis,
        echeance: echeance,
        publieeLe: publieeLe,
        createdAt: createdAt,
        nbDestinataires: nbDestinataires ?? this.nbDestinataires,
        nbLus: nbLus ?? this.nbLus,
        mesEcoles: mesEcoles ?? this.mesEcoles,
      );
}

const _kChamps =
    'id, emetteur_group_id, reference, objet, corps, priorite, cible_secteur, '
    'cible_departement, accuse_requis, echeance, publiee_le, created_at';

// ─── ÉMETTEUR : mes circulaires, et qui les a lues ──────────────────────────

final circulairesEmisesProvider =
    FutureProvider.autoDispose<List<Circulaire>>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];
  final client = ref.read(supabaseClientProvider);

  final rows = await client
      .from('circulaires')
      .select(_kChamps)
      .eq('emetteur_group_id', groupId)
      .order('created_at', ascending: false) as List;

  final circulaires = rows
      .map((r) => Circulaire.fromRow(Map<String, dynamic>.from(r as Map)))
      .toList();
  if (circulaires.isEmpty) return circulaires;

  // Les accusés, en UNE requête pour toutes les circulaires. Une requête par
  // circulaire ferait N+1 appels réseau sur un écran de liste.
  final dest = await client
      .from('circulaire_destinataires')
      .select('circulaire_id, lu_le')
      .inFilter('circulaire_id', circulaires.map((c) => c.id).toList()) as List;

  final total = <String, int>{};
  final lus = <String, int>{};
  for (final d in dest) {
    final m = Map<String, dynamic>.from(d as Map);
    final cid = m['circulaire_id'] as String;
    total[cid] = (total[cid] ?? 0) + 1;
    if (m['lu_le'] != null) lus[cid] = (lus[cid] ?? 0) + 1;
  }

  return [
    for (final c in circulaires)
      c.copyWith(nbDestinataires: total[c.id] ?? 0, nbLus: lus[c.id] ?? 0),
  ];
});

// ─── DESTINATAIRE : ce que ma tutelle m'a adressé ───────────────────────────

//  ⚠️ DEUX CHEMINS DE DONNEES, UN SEUL PROVIDER — la regle centrale du projet
//  appliquee ici. `admin_groupe` lit Supabase EN LIGNE ; le personnel d'ecole
//  lit sa base locale PowerSync, donc HORS LIGNE. Pas deux implementations et
//  pas deux ecrans : le meme, dont le perimetre est deduit du role.
//
//  Le poste ecole ne peut pas lire `circulaires` — la table n'a pas de
//  `school_id`, et les Sync Rules interdisent le JOIN en requete de
//  parametres. La migration 0167 pose donc l'INSTANTANE de la circulaire sur
//  la ligne du destinataire, qui se filtre par ecole. Bucket
//  `circulaires_ecole` dans `powersync/config/sync-rules.yaml`.
//
//  ⚠️ `StreamProvider` et non `FutureProvider` : cote ecole la source est
//  `db.watch()`, qui doit rafraichir l'ecran quand la circulaire ARRIVE. Un
//  chef d'etablissement qui regarde la liste au moment ou la note de son
//  ministere descend ne doit pas avoir a la recharger pour la voir. Cote
//  groupe la requete est emise une fois — `ref.invalidate` la rejoue,
//  exactement comme avant.
//
//  ⚠️ LECTURE SEULE hors ligne. `circulaire_destinataires` n'a AUCUNE
//  politique d'UPDATE : un accuse ecrit localement partirait, ne toucherait
//  AUCUNE ligne et se tairait. L'accuse passe par la RPC `circulaire_accuser`,
//  donc en ligne — c'est une preuve administrative, elle ne s'invente pas sur
//  un poste.
final circulairesRecuesProvider =
    StreamProvider.autoDispose<List<Circulaire>>((ref) {
  final ctx = ref.watch(communicationContextProvider);

  // ── Personnel d'ecole : la base locale ──────────────────────────────────
  if (ctx.isSchool) {
    final schoolId = ctx.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return Stream.value(const <Circulaire>[]);
    }
    ref.keepAlive();
    return db.watch(
      'SELECT d.*, s.name AS school_name '
      'FROM circulaire_destinataires d '
      'LEFT JOIN schools s ON s.id = d.school_id '
      'WHERE d.school_id = ? '
      'ORDER BY d.publiee_le DESC',
      parameters: [schoolId],
    ).map((rows) => [for (final r in rows) Circulaire.fromLigneLocale(r)]);
  }

  // ── Administrateur de groupe : Supabase direct ──────────────────────────
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return Stream.value(const <Circulaire>[]);
  final client = ref.read(supabaseClientProvider);

  return Stream.fromFuture(() async {
    // La RLS ne rend que les circulaires PUBLIEES dont mon groupe est
    // destinataire : inutile de refiltrer cote client, et dangereux de le
    // croire.
    final rows = await client
        .from('circulaires')
        .select('$_kChamps, school_groups!emetteur_group_id(name)')
        .not('publiee_le', 'is', null)
        .order('publiee_le', ascending: false) as List;

    final circulaires = rows
        .map((r) => Circulaire.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
    if (circulaires.isEmpty) return circulaires;

    final dest = await client
        .from('circulaire_destinataires')
        .select('circulaire_id, school_id, lu_le, group_id, schools(name)')
        .eq('group_id', groupId)
        .inFilter('circulaire_id', circulaires.map((c) => c.id).toList())
        as List;

    final parCirculaire = <String, List<CirculaireEcole>>{};
    for (final d in dest) {
      final m = Map<String, dynamic>.from(d as Map);
      final ec = m['schools'] as Map<String, dynamic>?;
      parCirculaire.putIfAbsent(m['circulaire_id'] as String, () => []).add(
            CirculaireEcole(
              schoolId: m['school_id'] as String,
              groupId: m['group_id'] as String,
              nom: ec?['name'] as String? ?? '\u2014',
              luLe: DateTime.tryParse(m['lu_le'] as String? ?? ''),
            ),
          );
    }

    return [
      for (final c in circulaires)
        c.copyWith(mesEcoles: parCirculaire[c.id] ?? const []),
    ];
  }());
});

// ─── Écritures ──────────────────────────────────────────────────────────────

/// Crée un BROUILLON. Rien ne part tant que `publier` n'a pas été appelé.
Future<String> creerCirculaire(
  WidgetRef ref, {
  required String groupId,
  required String tutelle,
  required String objet,
  required String corps,
  String? reference,
  CirculairePriorite priorite = CirculairePriorite.normale,
  String? cibleSecteur,
  String? cibleDepartement,
  List<String>? cibleGroupIds,
  bool accuseRequis = true,
  DateTime? echeance,
}) async {
  final client = ref.read(supabaseClientProvider);
  final row = await client.from('circulaires').insert({
    'emetteur_group_id': groupId,
    'tutelle': tutelle,
    'objet': objet.trim(),
    'corps': corps.trim(),
    'reference': reference?.trim().isEmpty ?? true ? null : reference!.trim(),
    'priorite': priorite.name,
    'cible_secteur': cibleSecteur,
    'cible_departement': cibleDepartement,
    'cible_group_ids': cibleGroupIds,
    'accuse_requis': accuseRequis,
    'echeance': echeance?.toIso8601String().substring(0, 10),
  }).select('id').single();
  return row['id'] as String;
}

Future<void> majCirculaire(
  WidgetRef ref, {
  required String id,
  required Map<String, dynamic> champs,
}) async {
  final client = ref.read(supabaseClientProvider);
  await client.from('circulaires').update({
    ...champs,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> supprimerBrouillon(WidgetRef ref, String id) async {
  final client = ref.read(supabaseClientProvider);
  await client.from('circulaires').delete().eq('id', id);
}

/// Publie : fige la liste des destinataires et notifie les groupes.
///
/// Renvoie le nombre d'établissements et de groupes touchés — à AFFICHER.
/// « Publiée » sans nombre laisse le rédacteur sans moyen de vérifier que son
/// ciblage désignait bien qui il croyait.
Future<Map<String, dynamic>> publierCirculaire(WidgetRef ref, String id) async {
  final client = ref.read(supabaseClientProvider);
  final res = await client.rpc('circulaire_publier', params: {'p_id': id});
  return Map<String, dynamic>.from(res as Map);
}

Future<Map<String, dynamic>> accuserCirculaire(
    WidgetRef ref, String circulaireId, String schoolId) async {
  final client = ref.read(supabaseClientProvider);
  final res = await client.rpc('circulaire_accuser', params: {
    'p_circulaire_id': circulaireId,
    'p_school_id': schoolId,
  });
  return Map<String, dynamic>.from(res as Map);
}
