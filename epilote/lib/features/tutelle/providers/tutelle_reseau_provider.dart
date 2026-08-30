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
  final groupes = await client.rpc('tutelle_groupes') as List;
  final ecoles = await client.rpc('tutelle_ecoles') as List;
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
