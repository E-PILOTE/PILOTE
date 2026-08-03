// ════════════════════════════════════════════════════════════════════════════
//  L'IDENTIFIANT NATIONAL DE L'ÉLÈVE — source unique côté application
//
//  ⚠️ CE FICHIER DOIT RESTER IDENTIQUE À LA MIGRATION 0080.
//  `luhnKey()` reproduit `luhn_cle()` en base. Un identifiant que le serveur
//  accepte et que l'application rejette — ou l'inverse — est indébogable au
//  guichet : l'agent voit « numéro invalide » sur un numéro que le ministère
//  vient d'émettre. Toute modification touche le Dart ET le SQL.
//  Même règle que le barème de mentions (core/utils/mention.dart).
//
//  ── LE FORMAT ──────────────────────────────────────────────────────────────
//    YY NNNNNNNN K   — 11 chiffres, affichés « 26-00000123-4 »
//      YY : deux derniers chiffres de l'année de PREMIÈRE inscription
//      NN… : séquence nationale à 8 chiffres
//      K  : clé de contrôle de Luhn
//
//  Tout en chiffres : un identifiant se dicte au téléphone et se ressaisit
//  depuis un papier. La clé de Luhn fait qu'un chiffre mal recopié est REJETÉ
//  au lieu de désigner silencieusement un autre enfant — ce qui, sur un
//  certificat de scolarité, est la faute qu'on ne veut jamais commettre.
// ════════════════════════════════════════════════════════════════════════════

/// Longueur d'un INE complet, clé comprise.
const int kIneLength = 11;

/// Clé de contrôle de Luhn des [chiffres] donnés (le corps, sans la clé).
///
/// Parcours de DROITE à gauche, un chiffre sur deux doublé : c'est ce qui rend
/// Luhn sensible à l'inversion de deux voisins (« 21 » saisi pour « 12 »), la
/// faute de frappe la plus fréquente sur une suite de chiffres.
int luhnKey(String chiffres) {
  var somme = 0;
  for (var pos = 1; pos <= chiffres.length; pos++) {
    final code = chiffres.codeUnitAt(chiffres.length - pos);
    if (code < 0x30 || code > 0x39) {
      throw ArgumentError('luhnKey attend des chiffres, reçu « $chiffres »');
    }
    var c = code - 0x30;
    if (pos.isOdd) {
      c *= 2;
      if (c > 9) c -= 9;
    }
    somme += c;
  }
  return (10 - (somme % 10)) % 10;
}

/// Vrai si [ine] est un identifiant national bien formé et dont la clé tombe
/// juste. Ne dit PAS que l'élève existe — seulement que le numéro n'a pas été
/// mal recopié.
bool isValidIne(String? ine) {
  final s = normalizeIne(ine);
  if (s == null || s.length != kIneLength) return false;
  return int.parse(s.substring(kIneLength - 1)) ==
      luhnKey(s.substring(0, kIneLength - 1));
}

/// Retire tout ce qui n'est pas un chiffre — tirets, espaces, points.
///
/// Indispensable à la saisie : l'agent recopie ce qu'il a sous les yeux, et ce
/// qu'il a sous les yeux est la forme affichée « 26-00000123-4 ». Refuser ce
/// qu'on lui a soi-même appris à lire serait absurde.
String? normalizeIne(String? raw) {
  if (raw == null) return null;
  final s = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return s.isEmpty ? null : s;
}

/// Forme lisible : « 26-00000123-4 ». Rend [raw] tel quel s'il ne fait pas la
/// bonne longueur — on n'embellit pas une donnée qu'on ne comprend pas.
String formatIne(String? raw) {
  final s = normalizeIne(raw);
  if (s == null) return '—';
  if (s.length != kIneLength) return s;
  return '${s.substring(0, 2)}-${s.substring(2, 10)}-${s.substring(10)}';
}

/// Ce qu'on affiche quand l'élève n'a pas encore d'INE.
///
/// Le cas n'est ni une erreur ni un oubli : une inscription saisie hors ligne
/// n'en a pas tant que le poste n'a pas synchronisé. Le dire ainsi évite qu'un
/// agent cherche un numéro qui n'existe pas encore.
const String kIneEnAttente = 'En attente de synchronisation';
