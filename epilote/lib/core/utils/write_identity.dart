// ════════════════════════════════════════════════════════════════════════════
//  IDENTITÉ D'ÉCRITURE — le garde-fou contre la perte silencieuse.
//
//  ── Le mécanisme de la panne ───────────────────────────────────────────────
//  En base, `group_id`, `school_id`, `recorded_by`, `created_by`… sont des
//  colonnes `uuid` NOT NULL. Le SQLite local, lui, n'impose RIEN : une chaîne
//  vide s'y écrit sans broncher, l'écran affiche « enregistré », l'agent
//  continue son travail.
//
//  Le refus arrive plus tard, à la remontée : PostgreSQL répond
//  `22P02 invalid input syntax for type uuid`. Et un refus n'abandonne pas
//  seulement CETTE ligne — il abandonne le LOT PowerSync ENTIER. Les présences,
//  les notes, les paiements saisis dans la même fenêtre partent avec, sans le
//  moindre message.
//
//  ── Pourquoi ce fichier existe ─────────────────────────────────────────────
//  Le motif `p?.groupId ?? ''` était répandu dans l'app. Il transforme une
//  ABSENCE en une VALEUR, et fait passer le typage Dart au vert (`String` non
//  nullable) alors que la donnée est invalide. Ici, `''` redevient ce qu'il
//  est : une absence.
//
//  Constat de terrain (audit du 2026-07-18) : 20 comptes enseignants sur 67 ont
//  `school_id` ET `group_id` à NULL en production. Le risque n'était pas
//  théorique.
// ════════════════════════════════════════════════════════════════════════════

/// Vrai si la valeur peut servir d'identifiant dans une colonne `uuid`.
/// Une chaîne vide ou blanche est une ABSENCE, pas un identifiant.
bool isUsableId(String? v) => v != null && v.trim().isNotEmpty;

/// Les identifiants sans lesquels aucune écriture scolaire n'est recevable.
class WriteIdentity {
  const WriteIdentity({
    required this.groupId,
    required this.schoolId,
    required this.actorId,
  });

  final String groupId;
  final String schoolId;

  /// L'agent réellement à l'écran (poste partagé) — `recorded_by`/`created_by`.
  final String actorId;
}

/// Construit l'identité, ou `null` si le moindre identifiant manque.
///
/// Renvoyer `null` plutôt que de lever : l'appelant doit AFFICHER pourquoi il
/// ne peut pas écrire (cf. [missingWriteIds]), pas encaisser une exception.
WriteIdentity? buildWriteIdentity({
  required String? groupId,
  required String? schoolId,
  required String? actorId,
}) {
  if (!isUsableId(groupId) || !isUsableId(schoolId) || !isUsableId(actorId)) {
    return null;
  }
  return WriteIdentity(
    groupId: groupId!.trim(),
    schoolId: schoolId!.trim(),
    actorId: actorId!.trim(),
  );
}

/// Ce qui manque, nommé en clair pour l'utilisateur.
///
/// « Erreur d'enregistrement » n'aide personne ; « votre compte n'est rattaché
/// à aucune école » dit à l'agent quoi faire réparer, et à la direction quoi
/// corriger dans le profil.
List<String> missingWriteIds({
  required String? groupId,
  required String? schoolId,
  required String? actorId,
}) =>
    [
      if (!isUsableId(groupId)) 'groupe',
      if (!isUsableId(schoolId)) 'école',
      if (!isUsableId(actorId)) 'agent',
    ];

/// Message prêt à afficher quand l'écriture est impossible.
String writeIdentityMessage(List<String> missing) => missing.isEmpty
    ? ''
    : 'Enregistrement impossible : votre compte n\'est rattaché à aucun(e) '
        '${missing.join(', ')}. Contactez la direction — sans ce rattachement, '
        'la donnée serait refusée à la synchronisation et perdue.';
