// ════════════════════════════════════════════════════════════════════════════
//  RECONNAÎTRE DEUX ÉCRITURES DE LA MÊME ANNÉE
//
//  Le référentiel national écrit « Sixième (6e) ». Le METP a créé « 6ème ». Une
//  comparaison de chaînes les croit différents — et c'est exactement le cas
//  réel : sur quatre collèges du METP, trois rattachent leur 6e au national et
//  le quatrième à l'entrée du groupe. Un tarif réseau posé sur « Sixième (6e) »
//  atteint trois écoles et manque la quatrième, EN SILENCE.
//
//  Ce fichier ne tranche rien : il dit seulement « ces deux libellés désignent
//  la même année ». Décider si une 6e technique EST une 6e reste à l'humain —
//  d'où un avertissement, jamais un blocage.
// ════════════════════════════════════════════════════════════════════════════

/// Les ordinaux français tels qu'ils s'écrivent dans les référentiels.
/// `terminale` vaut 100 : elle n'a pas de rang chiffré mais doit se comparer à
/// elle-même, et rester au-dessus des autres années du lycée.
const _motsOrdinaux = <String, int>{
  'premiere': 1, '1ere': 1, '1er': 1,
  'seconde': 2, '2nde': 2, 'deuxieme': 2,
  'troisieme': 3,
  'quatrieme': 4,
  'cinquieme': 5,
  'sixieme': 6,
  'septieme': 7,
  'huitieme': 8,
  'neuvieme': 9,
  'dixieme': 10,
  'onzieme': 11,
  'douzieme': 12,
  'terminale': 100,
};

/// Retire les accents : « Sixième » et « Sixieme » doivent se rencontrer.
String _sansAccent(String s) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    final i = avec.indexOf(String.fromCharCode(c));
    b.write(i < 0 ? String.fromCharCode(c) : sans[i]);
  }
  return b.toString();
}

/// Forme comparable d'un libellé : sans accent, sans casse, sans ponctuation
/// ni espaces multiples. « B.T.P. » et « btp » se rencontrent.
///
/// Sert aux FILIÈRES, qui n'ont pas de rang : deux filières ne se comparent que
/// par leur nom.
String libelleNormalise(String s) => _sansAccent(s)
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Le rang de l'année exprimée par ce libellé, ou `null` si on n'en lit aucun.
///
/// Reconnaît le chiffre (« 6ème », « 1ère année ») comme le mot (« Sixième »),
/// et se moque de la ponctuation autour (« Sixième (6e) »).
///
/// Renvoie `null` plutôt que de deviner : un libellé qu'on ne sait pas lire ne
/// doit produire AUCUN rapprochement — un faux avertissement apprend vite à
/// cliquer « continuer » sans lire.
int? rangDuNiveau(String libelle) {
  final t = _sansAccent(libelle);

  // Le mot d'abord : « Sixième (6e) » contient les deux, ils concordent, mais
  // « Première année du BTP 3 » ne doit pas se laisser prendre par le 3.
  for (final e in _motsOrdinaux.entries) {
    if (RegExp('(^|[^a-z])${e.key}([^a-z]|\$)').hasMatch(t)) return e.value;
  }

  // Sinon le chiffre, s'il porte bien une marque d'ordinal (« 6e », « 6ème »,
  // « 3eme annee »). Un nombre nu (« Groupe 3 ») n'est pas un rang d'année.
  final m = RegExp(r'(^|[^0-9])([0-9]{1,2})\s*(e|er|ere|eme|nde)([^a-z]|$)')
      .firstMatch(t);
  if (m != null) return int.parse(m.group(2)!);

  return null;
}

/// Deux libellés désignent-ils la même année ?
///
/// Faux dès qu'un des deux rangs est illisible : mieux vaut ne rien dire que
/// crier au doublon sur « Section d'adaptation » et « Classe passerelle ».
bool memeAnnee(String a, String b) {
  final ra = rangDuNiveau(a);
  final rb = rangDuNiveau(b);
  return ra != null && rb != null && ra == rb;
}
