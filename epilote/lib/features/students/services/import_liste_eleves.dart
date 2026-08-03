// ════════════════════════════════════════════════════════════════════════════
//  LIRE LA LISTE QUE L'ÉCOLE A DÉJÀ
//
//  Aucun fichier ministériel n'existe : chaque établissement saisit ses élèves.
//  Mais presque tous tiennent déjà une liste — un classeur Excel, un tableau
//  Word, parfois un cahier recopié. Retaper trois cents noms un par un dans un
//  formulaire, c'est deux jours de travail et une centaine de fautes de frappe.
//
//  ── LES PIÈGES QUI CASSENT UN IMPORT AU CONGO ─────────────────────────────
//  1. Excel en français sur Windows enregistre le CSV avec le point-virgule
//     comme séparateur, PAS la virgule. Un lecteur qui ne teste que la virgule
//     voit un fichier d'une seule colonne et rejette tout.
//  2. Il l'enregistre en Windows-1252, pas en UTF-8. « Prénom » devient
//     « PrÃ©nom », « NGOMA Aïcha » devient illisible. On décode donc en UTF-8
//     et, si cela échoue, en Windows-1252 — jamais l'inverse.
//  3. Les dates s'écrivent 12/03/2011, 12-03-2011 ou 2011-03-12 selon qui a
//     tapé. Le jour vient toujours en premier dans les deux premières formes.
//  4. Le sexe s'écrit M, F, G, Masculin, Garçon, Fille…
//
//  ── CE QUE CE FICHIER NE FAIT PAS ─────────────────────────────────────────
//  Il ne touche pas la base. Il lit des octets et rend des lignes jugées, avec
//  pour chacune ce qui va et ce qui bloque. L'écriture, la recherche de
//  doublons en base et le rattachement aux classes sont ailleurs — ici tout
//  est pur, donc entièrement testable sans appareil ni réseau.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

/// Un champ que l'on sait reconnaître dans un en-tête de colonne.
enum ChampImport {
  nom,
  prenom,
  nomComplet,
  dateNaissance,
  lieuNaissance,
  sexe,
  classe,
  ine,
  nationalite,
  adresse,
  redoublant,
}

/// Synonymes rencontrés sur le terrain, sous forme NORMALISÉE (minuscules,
/// sans accent, ponctuation réduite à un espace).
///
/// On ne met ici que des libellés sans ambiguïté. « N° » ou « Num » désignent
/// aussi bien un rang dans la liste qu'un matricule : deviner ferait entrer un
/// numéro d'ordre dans un champ d'identité.
const _synonymes = <ChampImport, List<String>>{
  ChampImport.nom: [
    'nom', 'noms', 'nom de famille', 'nom eleve', 'nom de l eleve',
    'patronyme', 'nom de famille de l eleve',
  ],
  ChampImport.prenom: [
    'prenom', 'prenoms', 'prenom eleve', 'prenom s', 'prenom de l eleve',
  ],
  ChampImport.nomComplet: [
    'nom et prenom', 'nom et prenoms', 'nom prenom', 'nom prenoms',
    'nom complet', 'eleve', 'eleves', 'identite', 'nom et prenom de l eleve',
  ],
  ChampImport.dateNaissance: [
    'date de naissance', 'date naissance', 'naissance', 'ne le', 'nee le',
    'ne e le', 'date de nais', 'dn',
  ],
  ChampImport.lieuNaissance: [
    'lieu de naissance', 'lieu naissance', 'ne a', 'nee a', 'ne e a',
  ],
  ChampImport.sexe: ['sexe', 'genre', 'm f', 'g f'],
  ChampImport.classe: ['classe', 'classe actuelle', 'division', 'section'],
  ChampImport.ine: [
    'ine', 'identifiant national', 'identifiant national eleve',
    'numero national',
  ],
  ChampImport.nationalite: ['nationalite'],
  ChampImport.adresse: ['adresse', 'domicile', 'quartier'],
  ChampImport.redoublant: ['redoublant', 'redouble', 'redoublement'],
};

/// Réduit un libellé à sa forme comparable : minuscules, sans accent, sans
/// ponctuation. « Date de naissance* » et « DATE-DE-NAISSANCE » deviennent la
/// même chaîne.
String normaliserEntete(String brut) {
  const accents = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
  const plats = 'aaaaaceeeeiiiinooooouuuuyy';
  final sb = StringBuffer();
  for (final c in brut.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = accents.indexOf(ch);
    if (i >= 0) {
      sb.write(plats[i]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      sb.write(ch);
    } else {
      sb.write(' ');
    }
  }
  return sb.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Le champ que désigne cet en-tête, ou `null` si on ne le reconnaît pas.
ChampImport? champPour(String entete) {
  final n = normaliserEntete(entete);
  if (n.isEmpty) return null;
  for (final e in _synonymes.entries) {
    if (e.value.contains(n)) return e.key;
  }
  return null;
}

// ─── Décodage du fichier ────────────────────────────────────────────────────

/// Décode les octets d'un fichier texte.
///
/// UTF-8 d'abord (avec retrait du BOM que Windows ajoute volontiers), puis
/// Windows-1252 en repli. L'inverse serait faux : le latin-1 accepte n'importe
/// quelle séquence d'octets, il ne échouerait jamais et transformerait
/// silencieusement tous les accents d'un fichier UTF-8 en charabia.
String decoderTexte(List<int> octets) {
  var o = octets;
  if (o.length >= 3 && o[0] == 0xEF && o[1] == 0xBB && o[2] == 0xBF) {
    o = o.sublist(3);
  }
  try {
    return utf8.decode(o);
  } on FormatException {
    return latin1.decode(o, allowInvalid: true);
  }
}

/// Devine le séparateur d'après la ligne d'en-tête.
///
/// Excel francophone écrit des point-virgules ; les exports anglophones et les
/// outils en ligne écrivent des virgules ; certains tableurs sortent des
/// tabulations. On prend celui qui découpe le plus de colonnes.
String detecterSeparateur(String ligneEntete) {
  var meilleur = ';';
  var maxi = 0;
  for (final sep in [';', ',', '\t', '|']) {
    final n = _decouper(ligneEntete, sep).length;
    if (n > maxi) {
      maxi = n;
      meilleur = sep;
    }
  }
  return meilleur;
}

/// Découpe une ligne CSV en respectant les guillemets (RFC 4180) : un nom
/// comme `"MBEMBA, Jean"` reste une seule cellule.
List<String> _decouper(String ligne, String sep) {
  final cellules = <String>[];
  final sb = StringBuffer();
  var entreGuillemets = false;
  for (var i = 0; i < ligne.length; i++) {
    final c = ligne[i];
    if (entreGuillemets) {
      if (c == '"') {
        if (i + 1 < ligne.length && ligne[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          entreGuillemets = false;
        }
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      entreGuillemets = true;
    } else if (c == sep) {
      cellules.add(sb.toString().trim());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  cellules.add(sb.toString().trim());
  return cellules;
}

/// Découpe un fichier entier en lignes de cellules.
///
/// Les sauts de ligne à l'intérieur des guillemets sont préservés — une adresse
/// sur deux lignes ne doit pas décaler tout le reste du fichier.
List<List<String>> decouperCsv(String texte, String sep) {
  final lignes = <List<String>>[];
  final courante = StringBuffer();
  var entreGuillemets = false;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if (c == '"') entreGuillemets = !entreGuillemets;
    if (!entreGuillemets && (c == '\n' || c == '\r')) {
      if (c == '\r' && i + 1 < texte.length && texte[i + 1] == '\n') i++;
      final l = courante.toString();
      if (l.trim().isNotEmpty) lignes.add(_decouper(l, sep));
      courante.clear();
    } else {
      courante.write(c);
    }
  }
  if (courante.toString().trim().isNotEmpty) {
    lignes.add(_decouper(courante.toString(), sep));
  }
  return lignes;
}

// ─── Lecture des valeurs ────────────────────────────────────────────────────

/// Lit une date de naissance. `null` si la valeur n'est pas une date sûre.
///
/// On refuse les années sur deux chiffres : « 12/03/11 » peut vouloir dire 2011
/// ou 1911, et un élève né en 1911 passerait sans bruit dans le registre.
DateTime? lireDate(String? brut) {
  final v = brut?.trim() ?? '';
  if (v.isEmpty) return null;

  // 2011-03-12 (ISO)
  final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(v);
  if (iso != null) {
    return _dateSure(
        int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }
  // 12/03/2011 — jour d'abord, comme partout en Afrique francophone.
  final fr = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(v);
  if (fr != null) {
    return _dateSure(
        int.parse(fr[3]!), int.parse(fr[2]!), int.parse(fr[1]!));
  }
  return null;
}

DateTime? _dateSure(int annee, int mois, int jour) {
  if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
  final d = DateTime(annee, mois, jour);
  // DateTime déborde silencieusement : le 31 février devient le 3 mars. On
  // refuse plutôt que d'inscrire une date que personne n'a écrite.
  if (d.year != annee || d.month != mois || d.day != jour) return null;
  return d;
}

/// Lit le sexe. Renvoie `'M'`, `'F'` ou `null`.
String? lireSexe(String? brut) {
  final v = normaliserEntete(brut ?? '');
  if (v.isEmpty) return null;
  const masculin = {'m', 'g', 'masculin', 'garcon', 'garcons', 'homme', 'male'};
  const feminin = {'f', 'feminin', 'fille', 'filles', 'femme', 'female'};
  if (masculin.contains(v)) return 'M';
  if (feminin.contains(v)) return 'F';
  return null;
}

/// Lit un oui/non (redoublant). Absence = non.
bool lireOuiNon(String? brut) {
  final v = normaliserEntete(brut ?? '');
  return const {'oui', 'o', 'yes', 'y', '1', 'vrai', 'x', 'redoublant'}
      .contains(v);
}

/// Sépare un « NOM Prénom » collé en une seule colonne.
///
/// Convention congolaise : le nom de famille s'écrit en premier, souvent en
/// capitales. On rend `(nom, prénoms)` et le drapeau [devine] : l'écran doit
/// dire que cette ligne a été coupée par la machine, car « MAKAYA Jean Pierre »
/// et « MAKAYA JEAN Pierre » ne se distinguent pas.
({String nom, String prenom, bool devine}) separerNomComplet(String brut) {
  final mots = brut.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
  if (mots.isEmpty) return (nom: '', prenom: '', devine: false);
  if (mots.length == 1) return (nom: mots.first, prenom: '', devine: false);

  // Si le fichier distingue les capitales, on lui fait confiance : tous les
  // mots en majuscules forment le nom.
  final capitales = mots
      .takeWhile((m) => m == m.toUpperCase() && m != m.toLowerCase())
      .toList();
  if (capitales.isNotEmpty && capitales.length < mots.length) {
    return (
      nom: capitales.join(' '),
      prenom: mots.skip(capitales.length).join(' '),
      devine: false,
    );
  }
  return (
    nom: mots.first,
    prenom: mots.skip(1).join(' '),
    devine: true,
  );
}

// ─── Une ligne, jugée ───────────────────────────────────────────────────────

/// Ce qui empêche une ligne d'entrer, dit dans les mots de la secrétaire.
class MotifRejet {
  const MotifRejet(this.texte);
  final String texte;
  @override
  String toString() => texte;
}

class LigneImport {
  LigneImport({
    required this.numero,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.sexe,
    this.lieuNaissance,
    this.classeTexte,
    this.ine,
    this.nationalite,
    this.adresse,
    this.redoublant = false,
    this.nomDevine = false,
    List<MotifRejet>? rejets,
  }) : rejets = rejets ?? [];

  /// Numéro de ligne DANS LE FICHIER, en-tête comprise — c'est ce que la
  /// secrétaire voit dans Excel, et le seul repère qui lui serve à corriger.
  final int numero;

  final String nom;
  final String prenom;
  final DateTime? dateNaissance;
  final String? sexe;
  final String? lieuNaissance;
  final String? classeTexte;
  final String? ine;
  final String? nationalite;
  final String? adresse;
  final bool redoublant;

  /// Le nom et le prénom ont été séparés automatiquement : à vérifier.
  final bool nomDevine;

  final List<MotifRejet> rejets;

  bool get retenue => rejets.isEmpty;
  String get nomAffiche => '$nom $prenom'.trim();

  /// Clé de comparaison entre deux personnes : nom, prénom et date. Deux
  /// homonymes nés le même jour dans la même école, c'est un doublon.
  String get empreinte =>
      '${normaliserEntete(nom)}|${normaliserEntete(prenom)}|'
      '${dateNaissance?.toIso8601String().substring(0, 10) ?? ''}';
}

/// Le résultat de la lecture d'un fichier, avant toute écriture.
class LectureImport {
  const LectureImport({
    required this.lignes,
    required this.colonnesReconnues,
    required this.colonnesIgnorees,
    required this.separateur,
  });

  final List<LigneImport> lignes;

  /// Ce qu'on a su lire — l'utilisateur doit pouvoir vérifier qu'on n'a pas
  /// pris la colonne « classe » pour la colonne « sexe ».
  final Map<String, ChampImport> colonnesReconnues;

  /// Ce qu'on laisse de côté. On le NOMME : une colonne « Téléphone parent »
  /// abandonnée en silence fait croire que les numéros sont entrés.
  final List<String> colonnesIgnorees;

  final String separateur;

  List<LigneImport> get retenues =>
      lignes.where((l) => l.retenue).toList(growable: false);
  List<LigneImport> get rejetees =>
      lignes.where((l) => !l.retenue).toList(growable: false);
}

/// Erreur de forme du fichier — rien n'est lisible, on n'affiche aucun tableau.
class FichierIllisible implements Exception {
  const FichierIllisible(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lit un fichier CSV et juge chaque ligne.
///
/// [anneeReference] sert au contrôle de vraisemblance des dates : un élève né
/// après la rentrée, ou il y a plus de 40 ans, vient d'une faute de frappe —
/// pas d'un dossier. On la passe en paramètre plutôt que d'appeler l'horloge,
/// pour que le comportement reste vérifiable.
LectureImport lireFichierEleves(
  List<int> octets, {
  required int anneeReference,
}) {
  final texte = decoderTexte(octets);
  if (texte.trim().isEmpty) {
    throw const FichierIllisible('Le fichier est vide.');
  }

  final premiere = texte.split(RegExp(r'\r?\n')).firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  final sep = detecterSeparateur(premiere);
  final grille = decouperCsv(texte, sep);
  if (grille.length < 2) {
    throw const FichierIllisible(
        'Le fichier ne contient qu\'une ligne. Il faut une ligne d\'en-tête '
        'suivie des élèves.');
  }

  final entetes = grille.first;
  final reconnues = <String, ChampImport>{};
  final ignorees = <String>[];
  final parIndex = <int, ChampImport>{};
  for (var i = 0; i < entetes.length; i++) {
    final champ = champPour(entetes[i]);
    if (champ == null) {
      if (entetes[i].trim().isNotEmpty) ignorees.add(entetes[i].trim());
    } else if (reconnues.containsValue(champ)) {
      // Deux colonnes pour le même champ : on garde la première et on signale
      // la seconde, plutôt que d'écraser sans le dire.
      ignorees.add('${entetes[i].trim()} (déjà lu)');
    } else {
      reconnues[entetes[i].trim()] = champ;
      parIndex[i] = champ;
    }
  }

  final champs = parIndex.values.toSet();
  final aUnNom = champs.contains(ChampImport.nom) ||
      champs.contains(ChampImport.nomComplet);
  if (!aUnNom) {
    throw FichierIllisible(
        'Aucune colonne de nom trouvée. Attendu : « Nom » et « Prénom », ou '
        '« Nom et prénom ». Colonnes lues : ${entetes.join(", ")}.');
  }

  final lignes = <LigneImport>[];
  for (var i = 1; i < grille.length; i++) {
    lignes.add(_jugerLigne(
      numero: i + 1, // +1 : Excel numérote à partir de 1, en-tête comprise
      cellules: grille[i],
      parIndex: parIndex,
      anneeReference: anneeReference,
    ));
  }

  return LectureImport(
    lignes: lignes,
    colonnesReconnues: reconnues,
    colonnesIgnorees: ignorees,
    separateur: sep,
  );
}

LigneImport _jugerLigne({
  required int numero,
  required List<String> cellules,
  required Map<int, ChampImport> parIndex,
  required int anneeReference,
}) {
  String? val(ChampImport c) {
    for (final e in parIndex.entries) {
      if (e.value == c && e.key < cellules.length) {
        final v = cellules[e.key].trim();
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }

  var nom = val(ChampImport.nom) ?? '';
  var prenom = val(ChampImport.prenom) ?? '';
  var devine = false;

  final complet = val(ChampImport.nomComplet);
  if (nom.isEmpty && complet != null) {
    final s = separerNomComplet(complet);
    nom = s.nom;
    prenom = s.prenom;
    devine = s.devine;
  }

  final date = lireDate(val(ChampImport.dateNaissance));
  final sexe = lireSexe(val(ChampImport.sexe));
  final rejets = <MotifRejet>[];

  if (nom.trim().isEmpty) {
    rejets.add(const MotifRejet('Nom manquant'));
  }
  // La date de naissance et le sexe sont OBLIGATOIRES en base. Une ligne
  // incomplète acceptée ici serait acceptée sur l'appareil puis refusée par le
  // serveur, et c'est le LOT ENTIER de la synchronisation qui serait perdu —
  // pas seulement cette ligne. On refuse donc tout de suite, et on le dit.
  if (date == null) {
    rejets.add(MotifRejet(val(ChampImport.dateNaissance) == null
        ? 'Date de naissance manquante'
        : 'Date de naissance illisible : « ${val(ChampImport.dateNaissance)} » '
            '(attendu 12/03/2011)'));
  } else if (date.year > anneeReference || date.year < anneeReference - 40) {
    rejets.add(MotifRejet(
        'Date de naissance invraisemblable : ${date.year}'));
  }
  if (sexe == null) {
    rejets.add(MotifRejet(val(ChampImport.sexe) == null
        ? 'Sexe manquant'
        : 'Sexe non compris : « ${val(ChampImport.sexe)} » (attendu M ou F)'));
  }

  return LigneImport(
    numero: numero,
    nom: nom.trim(),
    prenom: prenom.trim(),
    dateNaissance: date,
    sexe: sexe,
    lieuNaissance: val(ChampImport.lieuNaissance),
    classeTexte: val(ChampImport.classe),
    ine: val(ChampImport.ine),
    nationalite: val(ChampImport.nationalite),
    adresse: val(ChampImport.adresse),
    redoublant: lireOuiNon(val(ChampImport.redoublant)),
    nomDevine: devine,
    rejets: rejets,
  );
}

/// Marque les doublons INTERNES au fichier : la même personne écrite deux fois.
///
/// Cela arrive quand deux classes ont été collées dans le même tableau, ou
/// qu'une ligne a été recopiée. On garde la première occurrence et on rejette
/// les suivantes en nommant la ligne d'origine.
void marquerDoublonsInternes(List<LigneImport> lignes) {
  final vues = <String, int>{};
  for (final l in lignes) {
    if (!l.retenue) continue;
    final vu = vues[l.empreinte];
    if (vu != null) {
      l.rejets.add(MotifRejet('Déjà présent ligne $vu du fichier'));
    } else {
      vues[l.empreinte] = l.numero;
    }
  }
}
