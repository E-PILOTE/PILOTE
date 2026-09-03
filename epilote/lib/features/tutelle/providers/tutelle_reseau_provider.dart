import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RÉSEAU DE LA TUTELLE — ce qu'un ministère voit de SON ministère
//
//  ── LES DEUX CASQUETTES ───────────────────────────────────────────────────
//  Un ministère est à la fois EXPLOITANT (il possède ses écoles) et TUTELLE
//  (il supervise toutes les écoles de son ministère, y compris celles qu'il ne
//  possède pas). Le premier rôle est déjà servi par « Mes écoles ». Celui-ci
//  sert le second.
//
//  Fait mesuré au 2026-08-30 : le MEPSA ne voyait que 14 des 25 écoles placées
//  sous sa tutelle — onze lui échappaient. Par ces fonctions il en voit 25.
//
//  ── ⚠️ PAS DE `supabase.from(...)` ICI, ET C'EST LE POINT ─────────────────
//  Tout passe par deux RPC `SECURITY DEFINER` (`tutelle_groupes`,
//  `tutelle_ecoles`, migration 0158). Élargir la RLS de vingt tables à « ou si
//  je suis le ministère » aurait multiplié par vingt les occasions d'ouvrir
//  des données d'élèves par erreur. Une fonction décide en UN endroit, lisible,
//  ce qui sort.
//
//  Ce que ces fonctions ne rendent PAS, et qu'il ne faut pas ajouter ici :
//   • aucun nom d'élève, aucune note, aucune absence, aucun paiement — des
//     AGRÉGATS, uniquement ;
//   • aucun plan d'abonnement, aucun statut de paiement : ce qu'un groupe
//     privé paie à E-PILOTE ne regarde pas son ministère.
//
//  La SEULE donnée nominative est le chef d'établissement : c'est
//  l'interlocuteur officiel de la tutelle, et un ministère qui ignore qui
//  dirige une école de son réseau ne peut ni la convoquer ni lui écrire.
// ════════════════════════════════════════════════════════════════════════════

/// Un groupe scolaire du réseau, vu par sa tutelle.
class TutelleGroupe {
  const TutelleGroupe({
    required this.id,
    required this.nom,
    required this.secteur,
    required this.nbEcoles,
    required this.nbEcolesActives,
    required this.nbEleves,
    required this.nbFilles,
    required this.nbPersonnel,
    required this.nbClasses,
    required this.nbEcolesAgreees,
    this.departement,
    this.email,
    this.telephone,
    this.logoUrl,
    this.anneeCreation,
    this.agrementNumero,
    this.agrementType,
    this.agrementDate,
    this.actif = true,
  });

  factory TutelleGroupe.fromRow(Map<String, dynamic> r) => TutelleGroupe(
        id: r['group_id'] as String,
        nom: r['nom'] as String? ?? '—',
        secteur: r['secteur'] as String? ?? 'prive',
        departement: r['departement'] as String?,
        email: r['email'] as String?,
        telephone: r['telephone'] as String?,
        logoUrl: r['logo_url'] as String?,
        anneeCreation: (r['annee_creation'] as num?)?.toInt(),
        actif: r['actif'] as bool? ?? true,
        agrementNumero: r['agrement_numero'] as String?,
        agrementType: r['agrement_type'] as String?,
        agrementDate: r['agrement_date'] == null
            ? null
            : DateTime.tryParse(r['agrement_date'] as String),
        nbEcoles: _n(r['nb_ecoles']),
        nbEcolesActives: _n(r['nb_ecoles_actives']),
        nbEleves: _n(r['nb_eleves']),
        nbFilles: _n(r['nb_filles']),
        nbPersonnel: _n(r['nb_personnel']),
        nbClasses: _n(r['nb_classes']),
        nbEcolesAgreees: _n(r['nb_ecoles_agreees']),
      );

  final String id, nom, secteur;
  final String? departement, email, telephone, logoUrl;
  final int? anneeCreation;
  final bool actif;
  final String? agrementNumero, agrementType;
  final DateTime? agrementDate;
  final int nbEcoles, nbEcolesActives, nbEleves, nbFilles, nbPersonnel,
      nbClasses, nbEcolesAgreees;

  bool get estPublic => secteur == 'public';

  /// ⚠️ `null` quand l'agrément n'est pas renseigné — et « non renseigné »
  /// n'est PAS « non agréé ». La plateforme n'instruit aucun agrément : elle
  /// n'enregistre que ce qu'on lui a dit.
  bool get aDeclareUnAgrement => (agrementNumero ?? '').trim().isNotEmpty;
}

/// Une école du réseau, vue par sa tutelle.
class TutelleEcole {
  const TutelleEcole({
    required this.id,
    required this.groupId,
    required this.groupeNom,
    required this.nom,
    required this.secteur,
    required this.nbEleves,
    required this.nbFilles,
    required this.nbPersonnel,
    required this.nbClasses,
    this.code,
    this.typeEtablissement,
    this.typeEtablissementCourt,
    this.departement,
    this.ville,
    this.arrondissement,
    this.latitude,
    this.longitude,
    this.capacite,
    this.anneeCreation,
    this.telephone,
    this.courriel,
    this.chefEtablissement,
    this.agrementNumero,
    this.agrementType,
    this.agrementDate,
    this.actif = true,
  });

  factory TutelleEcole.fromRow(Map<String, dynamic> r) => TutelleEcole(
        id: r['school_id'] as String,
        groupId: r['group_id'] as String,
        groupeNom: r['groupe_nom'] as String? ?? '—',
        nom: r['nom'] as String? ?? '—',
        code: r['code'] as String?,
        secteur: r['secteur'] as String? ?? 'prive',
        typeEtablissement: r['type_etablissement'] as String?,
        typeEtablissementCourt: r['type_etablissement_court'] as String?,
        departement: r['departement'] as String?,
        ville: r['ville'] as String?,
        arrondissement: r['arrondissement'] as String?,
        latitude: (r['latitude'] as num?)?.toDouble(),
        longitude: (r['longitude'] as num?)?.toDouble(),
        capacite: (r['capacite'] as num?)?.toInt(),
        actif: r['actif'] as bool? ?? true,
        anneeCreation: (r['annee_creation'] as num?)?.toInt(),
        telephone: r['telephone'] as String?,
        courriel: r['courriel'] as String?,
        chefEtablissement: r['chef_etablissement'] as String?,
        agrementNumero: r['agrement_numero'] as String?,
        agrementType: r['agrement_type'] as String?,
        agrementDate: r['agrement_date'] == null
            ? null
            : DateTime.tryParse(r['agrement_date'] as String),
        nbEleves: _n(r['nb_eleves']),
        nbFilles: _n(r['nb_filles']),
        nbPersonnel: _n(r['nb_personnel']),
        nbClasses: _n(r['nb_classes']),
      );

  final String id, groupId, groupeNom, nom, secteur;
  final String? code,
      typeEtablissement,
      typeEtablissementCourt,
      departement,
      ville,
      arrondissement,
      telephone,
      courriel,
      chefEtablissement,
      agrementNumero,
      agrementType;
  final double? latitude, longitude;
  final int? capacite, anneeCreation;
  final DateTime? agrementDate;
  final bool actif;
  final int nbEleves, nbFilles, nbPersonnel, nbClasses;

  bool get estPublic => secteur == 'public';
  bool get aDeclareUnAgrement => (agrementNumero ?? '').trim().isNotEmpty;

  /// Taux d'occupation. `null` si la capacité n'est pas renseignée — surtout
  /// ne pas rendre 0, qui se lirait comme « école vide ».
  double? get occupation =>
      (capacite != null && capacite! > 0) ? nbEleves / capacite! : null;
}

/// ⚠️ PostgREST rend les `bigint` tantôt en entier, tantôt en texte selon le
/// chemin. Les deux sont acceptés — un `as int` sec aurait planté au hasard.
int _n(Object? v) => switch (v) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };

/// Le réseau complet : groupes et écoles sous la tutelle de l'utilisateur.
class TutelleReseau {
  const TutelleReseau({required this.groupes, required this.ecoles});
  final List<TutelleGroupe> groupes;
  final List<TutelleEcole> ecoles;

  static const vide = TutelleReseau(groupes: [], ecoles: []);
}

/// ⚠️ AUCUN `catch` muet. Une tutelle qui lit « 0 école » parce que la requête
/// a échoué prendrait un incident réseau pour un réseau vide — et c'est le
/// genre de chiffre qui finit dans un état ministériel. L'écran doit voir
/// l'erreur et la dire.
final tutelleReseauProvider =
    FutureProvider.autoDispose<TutelleReseau>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  // ⚠️ EN PARALLÈLE, et non l'une après l'autre. Les deux RPC sont
  // indépendantes ; enchaînées, elles additionnaient leurs latences sur un
  // réseau congolais où l'aller-retour se compte en centaines de millisecondes.
  // À la cible nationale — plus de mille établissements — chacune agrège les
  // effectifs école par école : c'est le chargement le plus lourd de l'espace
  // groupe, et il n'y a aucune raison de le payer deux fois de suite.
  final reponses = await Future.wait<dynamic>([
    client.rpc('tutelle_groupes'),
    client.rpc('tutelle_ecoles'),
  ]);
  final groupes = reponses[0] as List;
  final ecoles = reponses[1] as List;
  return TutelleReseau(
    groupes: [
      for (final r in groupes)
        TutelleGroupe.fromRow(Map<String, dynamic>.from(r as Map)),
    ],
    ecoles: [
      for (final r in ecoles)
        TutelleEcole.fromRow(Map<String, dynamic>.from(r as Map)),
    ],
  );
});

/// La tutelle du groupe connecté (`mepsa` | `metp`), pour la nommer à l'écran.
///
/// Une requête d'une ligne, séparée du réseau : afficher « MEPSA » ne doit pas
/// attendre le chargement de mille écoles.
final tutelleDuGroupeProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || groupId.isEmpty) return null;
  final g = await ref
      .watch(supabaseClientProvider)
      .from('school_groups')
      .select('tutelle')
      .eq('id', groupId)
      .maybeSingle();
  return g?['tutelle'] as String?;
});

// ════════════════════════════════════════════════════════════════════════════
//  LE RÉSEAU SUPERVISÉ — le périmètre de tutelle MOINS soi-même
//
//  ── LE DÉFAUT QUE CETTE DISTINCTION CORRIGE ───────────────────────────────
//  Vu à l'écran le 2026-09-02, compte METP : la page « Réseau sous tutelle »
//  annonçait « toutes les écoles sous tutelle METP, Y COMPRIS CELLES QUE VOUS
//  NE GÉREZ PAS », puis affichait 12 écoles réparties dans 1 groupe — et ce
//  groupe unique ÉTAIT le ministère qui regardait la page. Une page de
//  supervision dont tout le contenu est la carte de son propre lecteur.
//  Colonne « Groupe » : le même nom douze fois. KPI privé : 0.
//
//  Un ministère porte deux casquettes, et la plateforme leur doit deux écrans :
//   • EXPLOITANT — ses propres établissements → « Mes écoles » ;
//   • TUTELLE    — les groupes qu'il supervise SANS les administrer → ici.
//  Tant que le premier périmètre était inclus dans le second, le second ne
//  répondait à aucune question.
//
//  ── ⚠️ POURQUOI CE FILTRE N'EST PAS DANS LE SQL ──────────────────────────
//  Il serait tentant d'ajouter `AND sg.id <> auth_group_id()` dans les RPC de
//  la migration 0158. Ce serait un défaut silencieux : `circulaire_publier`
//  (0167) calcule ses destinataires EN BASE sur `schools.tutelle`, sans cette
//  exclusion — une circulaire ministérielle atteint bien les écoles du
//  ministère. Le formulaire de circulaire, lui, compte ses cibles avec
//  `tutelleReseauProvider`. Amputer la RPC ferait donc annoncer « 11
//  établissements touchés » à un envoi qui en toucherait 25.
//
//  Les deux périmètres sont RÉELS et différents. Ils portent donc deux noms :
//  `tutelleReseauProvider` = ce que la tutelle COUVRE (ciblage d'une
//  circulaire) ; `reseauSuperviseProvider` = ce qu'elle SUPERVISE sans
//  l'administrer (la page). Ne jamais substituer l'un à l'autre.
// ════════════════════════════════════════════════════════════════════════════

/// Le réseau qu'un ministère supervise sans l'exploiter.
class ReseauSupervise {
  const ReseauSupervise({
    required this.groupes,
    required this.ecoles,
    required this.nbEcolesPropres,
  });

  /// Les groupes tiers — jamais le groupe qui consulte.
  final List<TutelleGroupe> groupes;

  /// Leurs établissements.
  final List<TutelleEcole> ecoles;

  /// Combien d'établissements le consultant exploite lui-même. Sert à le DIRE
  /// à l'écran : sans ce nombre, un ministère qui ne retrouve pas ses douze
  /// écoles croit à une panne plutôt qu'à un périmètre.
  final int nbEcolesPropres;

  bool get estVide => groupes.isEmpty;
}

/// Retire [monGroupeId] du périmètre — fonction PURE, testable sans réseau.
///
/// ⚠️ L'exclusion porte sur le GROUPE, pas sur l'école : une école du
/// ministère se reconnaît à son `groupId`, jamais à son secteur. Filtrer sur
/// `estPublic` aurait écarté par la même occasion les groupes publics TIERS
/// (au MEPSA : EDEC et Savorgnan, 4 écoles et 2 575 élèves) — des opérateurs
/// que le ministère supervise sans les administrer, et qu'aucun autre écran ne
/// lui montre.
ReseauSupervise reseauSuperviseDe(TutelleReseau complet, String? monGroupeId) {
  // Le super_admin n'a pas de groupe : il n'exploite rien, donc rien à retirer.
  if (monGroupeId == null || monGroupeId.isEmpty) {
    return ReseauSupervise(
      groupes: complet.groupes,
      ecoles: complet.ecoles,
      nbEcolesPropres: 0,
    );
  }
  var propres = 0;
  final ecoles = <TutelleEcole>[];
  for (final e in complet.ecoles) {
    if (e.groupId == monGroupeId) {
      propres++;
    } else {
      ecoles.add(e);
    }
  }
  return ReseauSupervise(
    groupes: [
      for (final g in complet.groupes)
        if (g.id != monGroupeId) g,
    ],
    ecoles: ecoles,
    nbEcolesPropres: propres,
  );
}

final reseauSuperviseProvider =
    FutureProvider.autoDispose<ReseauSupervise>((ref) async => reseauSuperviseDe(
          await ref.watch(tutelleReseauProvider.future),
          ref.watch(authNotifierProvider).valueOrNull?.groupId,
        ));
