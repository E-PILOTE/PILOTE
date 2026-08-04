// ════════════════════════════════════════════════════════════════════════════
//  LE NUMÉRO DE REÇU — décisions pures
//
//  Un reçu est une pièce comptable : son numéro doit être unique, et il doit
//  l'être SANS RÉSEAU. L'ancien numéro (`REC-` + 6 derniers chiffres de
//  l'horloge) recommençait toutes les 16 min 40 s sous une contrainte
//  d'unicité nationale ; la collision faisait abandonner la transaction
//  PowerSync et perdait l'encaissement (cf. spec §6.1).
//
//  L'unicité repose désormais sur deux choses que le poste possède seul :
//  son ÉTIQUETTE D'APPAREIL, et une SÉQUENCE qu'il relit dans sa propre base.
//  Le code de l'école n'entre pas dans l'unicité — la contrainte est passée à
//  (school_id, receipt_number) — il n'est là que pour la lisibilité du papier.
// ════════════════════════════════════════════════════════════════════════════

/// Longueur maximale de `student_payments.receipt_number` en base.
const int kReceiptMaxLength = 50;

/// Nombre de caractères du code d'école conservés dans le numéro.
///
/// On garde la FIN du code, pas le début : les codes officiels commencent par
/// le préfixe de tutelle (« METPLTAOWANDO »), qui est justement la partie non
/// discriminante.
const int _kCodeLength = 10;

const String _kCodeSansEcole = 'ECOLE';

String _codeCourt(String? schoolCode) {
  final brut =
      (schoolCode ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (brut.isEmpty) return _kCodeSansEcole;
  return brut.length <= _kCodeLength
      ? brut
      : brut.substring(brut.length - _kCodeLength);
}

/// Tout ce qui précède la séquence. Deux reçus de même préfixe viennent du même
/// poste, de la même école et de la même année.
String prefixeRecu({
  required String? schoolCode,
  required int year,
  required String posteTag,
}) =>
    'REC-${_codeCourt(schoolCode)}-'
    '${(year % 100).toString().padLeft(2, '0')}-'
    '${posteTag.toUpperCase()}-';

/// Le numéro tel qu'il s'imprime sur le papier du parent.
String formatReceiptNumber({
  required String? schoolCode,
  required int year,
  required String posteTag,
  required int sequence,
}) =>
    prefixeRecu(schoolCode: schoolCode, year: year, posteTag: posteTag) +
    sequence.toString().padLeft(6, '0');

/// La séquence portée par ce reçu, ou `null` s'il ne vient pas de ce préfixe
/// (autre poste, autre année, ou ancien format horodaté).
int? sequenceDansRecu(String receipt, {required String prefixe}) {
  if (!receipt.startsWith(prefixe)) return null;
  return int.tryParse(receipt.substring(prefixe.length));
}

/// La prochaine séquence libre, déduite des reçus DÉJÀ présents en base locale.
///
/// Relire la base plutôt que tenir un compteur à part est délibéré : après une
/// purge du poste, les paiements redescendent par la synchro. Un compteur
/// reparti à zéro rééditerait des numéros déjà émis par ce même poste — et
/// chaque doublon coûterait un paiement.
int prochaineSequence(Iterable<String?> recusExistants,
    {required String prefixe}) {
  var max = 0;
  for (final r in recusExistants) {
    if (r == null || r.isEmpty) continue;
    final n = sequenceDansRecu(r, prefixe: prefixe);
    if (n != null && n > max) max = n;
  }
  return max + 1;
}
