// ══════════════════════════════════════════════════════════════════════════════
//  APPARIER DES FICHIERS À DES ÉLÈVES — la moitié dangereuse de l'import
//
//  Une école photographie une classe et se retrouve avec un dossier de
//  fichiers. Les rattacher un par un à six cents élèves à la main, personne ne
//  le fait : c'est pour cela que la base compte 9 106 élèves et zéro photo.
//
//  ── LA RÈGLE QUI COMMANDE TOUT : JAMAIS D'À-PEU-PRÈS ───────────────────────
//  Une photo attribuée au mauvais élève est PIRE que pas de photo du tout. La
//  carte devient un faux qui circule : un visage, un autre nom, et personne
//  pour s'en apercevoir avant le portail. Un rapprochement approximatif
//  (« NGOMA Jean » ≈ « NGOMA Jeanne ») produit exactement cela.
//
//  D'où : correspondance EXACTE, et rien d'autre. Pas de distance d'édition,
//  pas de préfixe, pas de « meilleur candidat ». Ce qui ne s'apparie pas avec
//  certitude est ÉCARTÉ, avec sa raison — et se règle à la main, où l'agent
//  voit le visage à côté du nom.
//
//  C'est la même règle que l'import de listes (`import_eleves_provider.dart`) :
//  « une ligne douteuse est rejetée, jamais rapprochée d'office ».
//
//  ── L'UNICITÉ EST SYMÉTRIQUE ──────────────────────────────────────────────
//  Il ne suffit pas qu'un fichier désigne un seul élève : il faut aussi
//  qu'aucun autre fichier ne désigne le même. Deux photos nommées « NGOMA
//  Jean » dans un dossier, ce sont deux enfants homonymes ou deux prises du
//  même — on ne peut pas le savoir, donc on n'en attribue AUCUNE.
//
//  ── CE QU'ON NE FAIT PAS NON PLUS ─────────────────────────────────────────
//  On n'écrase pas une photo existante sans le dire. Une école qui réimporte
//  le dossier de l'an dernier remplacerait sinon les visages de l'année en
//  cours par ceux d'avant, en silence.
// ══════════════════════════════════════════════════════════════════════════════

import '../../students/services/import_liste_eleves.dart' show normaliserEntete;
import '../providers/cartes_provider.dart' show CarteEleveRow;

/// Extensions d'image acceptées — celles que `compressAvatar` sait décoder.
const List<String> kExtensionsPhoto = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];

/// Poids maximal accepté pour UN fichier d'un import de masse.
///
/// ── POURQUOI UN PLAFOND ICI, ALORS QU'IL N'Y EN A PAS À L'UNITÉ ────────────
/// `compressAvatar` retombe silencieusement sur les octets d'origine quand elle
/// ne sait pas décoder l'image (fichier tronqué, format exotique). À l'unité
/// c'est le bon choix : mieux vaut une photo lourde que pas de photo. Sur six
/// cents fichiers, le même repli installe des gigaoctets sur le disque d'un
/// poste d'école, qui repartiront sur une connexion payée au volume.
///
/// 15 Mo laisse passer toute photo de téléphone ou d'appareil compact ; au-delà
/// on est dans le scan haute définition, qui n'a rien à faire sur une vignette
/// de 22 × 28 mm.
const int kPoidsMaxPhotoImport = 15 * 1024 * 1024;

/// Un fichier proposé à l'import.
class FichierPhoto {
  const FichierPhoto({required this.chemin, required this.nom, this.taille});

  /// Chemin sur le disque. Les octets ne sont PAS chargés ici : six cents
  /// photos de téléphone tiennent plusieurs gigaoctets, et l'appariement n'a
  /// besoin que du nom.
  final String chemin;

  /// Nom du fichier, extension comprise.
  final String nom;
  final int? taille;

  /// Le nom sans son extension — ce qui porte l'identité, quand elle y est.
  String get radical {
    final i = nom.lastIndexOf('.');
    return i <= 0 ? nom : nom.substring(0, i);
  }

  String get extension {
    final i = nom.lastIndexOf('.');
    return i < 0 || i == nom.length - 1
        ? 'jpg'
        : nom.substring(i + 1).toLowerCase();
  }

  bool get estUneImage => kExtensionsPhoto.contains(extension);

  /// Contrôlé sur la taille annoncée par le sélecteur, AVANT toute lecture :
  /// inutile de charger le fichier en mémoire pour décider qu'on n'en veut pas.
  bool get poidsPlausible => taille == null || taille! <= kPoidsMaxPhotoImport;
}

/// Pourquoi un fichier n'a pas été rattaché.
enum RaisonEcart {
  pasUneImage,
  tropLourd,
  aucuneCorrespondance,
  plusieursEleves,
  plusieursFichiers,
  photoDejaPresente,
}

String libelleRaison(RaisonEcart r) => switch (r) {
      RaisonEcart.pasUneImage => 'Pas une image',
      RaisonEcart.tropLourd => 'Fichier trop lourd (> 15 Mo)',
      RaisonEcart.aucuneCorrespondance => 'Aucun élève de ce nom',
      RaisonEcart.plusieursEleves => 'Plusieurs élèves possibles',
      RaisonEcart.plusieursFichiers => 'Plusieurs fichiers pour cet élève',
      RaisonEcart.photoDejaPresente => 'A déjà une photo',
    };

/// Par quoi la correspondance a été établie — affiché à l'agent, qui n'accorde
/// pas la même confiance à un matricule qu'à un nom.
enum CleAppariement { identifiantNational, matricule, nom }

String libelleCle(CleAppariement c) => switch (c) {
      CleAppariement.identifiantNational => 'Identifiant national',
      CleAppariement.matricule => 'Matricule',
      CleAppariement.nom => 'Nom',
    };

class PhotoAppariee {
  const PhotoAppariee(this.fichier, this.eleve, this.cle);
  final FichierPhoto fichier;
  final CarteEleveRow eleve;
  final CleAppariement cle;
}

class PhotoEcartee {
  const PhotoEcartee(this.fichier, this.raison, {this.eleve});
  final FichierPhoto fichier;
  final RaisonEcart raison;

  /// L'élève concerné, quand on sait de qui il s'agit mais qu'on refuse
  /// d'écrire (photo déjà présente, deux fichiers pour lui).
  final CarteEleveRow? eleve;
}

class ResultatAppariement {
  const ResultatAppariement({
    required this.apparies,
    required this.ecartes,
    required this.elevesRestants,
  });

  final List<PhotoAppariee> apparies;
  final List<PhotoEcartee> ecartes;

  /// Élèves de la classe encore sans photo après cet import — la liste qui
  /// reste à faire à la main.
  final List<CarteEleveRow> elevesRestants;

  bool get vide => apparies.isEmpty;
}

/// Les clés sous lesquelles un élève peut être désigné par un nom de fichier.
///
/// Chaque clé est rendue sous deux formes : avec séparateurs normalisés en
/// espaces, et compactée. « M-2024/0137 », « M 2024 0137 » et « m20240137 »
/// désignent alors le même élève — ce n'est pas de l'approximation, c'est la
/// même chaîne écrite avec d'autres séparateurs.
Map<CleAppariement, Set<String>> clesEleve(CarteEleveRow e) {
  Set<String> deux(String? brut) {
    final n = normaliserEntete(brut ?? '');
    if (n.isEmpty) return const {};
    return {n, n.replaceAll(' ', '')};
  }

  return {
    CleAppariement.identifiantNational: deux(e.ine),
    CleAppariement.matricule: deux(e.matricule),
    CleAppariement.nom: {
      ...deux('${e.lastName} ${e.firstName}'),
      ...deux('${e.firstName} ${e.lastName}'),
    },
  };
}

/// Rattache des fichiers à des élèves — exactement, ou pas du tout.
///
/// [remplacerExistantes] autorise l'écrasement d'une photo déjà présente. Faux
/// par défaut : réimporter le dossier de l'an dernier ne doit pas remplacer les
/// visages de cette année sans qu'on l'ait demandé.
ResultatAppariement apparierPhotos({
  required List<FichierPhoto> fichiers,
  required List<CarteEleveRow> eleves,
  bool remplacerExistantes = false,
}) {
  // ── 1. Index clé → élèves. Une clé peut en désigner plusieurs : deux
  //    homonymes existent dans toute école un peu grande.
  final index = <String, List<(CarteEleveRow, CleAppariement)>>{};
  for (final e in eleves) {
    clesEleve(e).forEach((cle, valeurs) {
      for (final v in valeurs) {
        (index[v] ??= []).add((e, cle));
      }
    });
  }

  // ── 2. Premier passage : chaque fichier propose un élève, ou une raison.
  final propositions = <String, List<PhotoAppariee>>{}; // studentId → fichiers
  final ecartes = <PhotoEcartee>[];

  for (final f in fichiers) {
    if (!f.estUneImage) {
      ecartes.add(PhotoEcartee(f, RaisonEcart.pasUneImage));
      continue;
    }
    if (!f.poidsPlausible) {
      ecartes.add(PhotoEcartee(f, RaisonEcart.tropLourd));
      continue;
    }

    final cle = normaliserEntete(f.radical);
    final trouves = index[cle] ?? index[cle.replaceAll(' ', '')] ?? const [];

    if (trouves.isEmpty) {
      ecartes.add(PhotoEcartee(f, RaisonEcart.aucuneCorrespondance));
      continue;
    }

    // Plusieurs ENTRÉES pour un seul élève (son matricule vaut aussi son nom)
    // n'est pas une ambiguïté : c'est le même enfant.
    final distincts = <String, (CarteEleveRow, CleAppariement)>{};
    for (final t in trouves) {
      // La clé la plus forte gagne : identifiant national, puis matricule.
      final actuel = distincts[t.$1.studentId];
      if (actuel == null || t.$2.index < actuel.$2.index) {
        distincts[t.$1.studentId] = t;
      }
    }

    if (distincts.length > 1) {
      ecartes.add(PhotoEcartee(f, RaisonEcart.plusieursEleves));
      continue;
    }

    final (eleve, parQuoi) = distincts.values.first;
    (propositions[eleve.studentId] ??= [])
        .add(PhotoAppariee(f, eleve, parQuoi));
  }

  // ── 3. Second passage : l'unicité dans l'autre sens.
  final apparies = <PhotoAppariee>[];
  final servis = <String>{};

  for (final entry in propositions.entries) {
    final lot = entry.value;
    if (lot.length > 1) {
      // Deux fichiers pour le même élève : homonymes, ou deux prises. On ne
      // peut pas trancher, donc on n'en écrit aucune.
      for (final p in lot) {
        ecartes.add(
            PhotoEcartee(p.fichier, RaisonEcart.plusieursFichiers, eleve: p.eleve));
      }
      continue;
    }

    final p = lot.first;
    if (p.eleve.aUnePhoto && !remplacerExistantes) {
      ecartes.add(PhotoEcartee(p.fichier, RaisonEcart.photoDejaPresente,
          eleve: p.eleve));
      continue;
    }

    apparies.add(p);
    servis.add(p.eleve.studentId);
  }

  // ── 4. Ce qui reste à faire.
  final restants = [
    for (final e in eleves)
      if (!e.aUnePhoto && !servis.contains(e.studentId)) e,
  ];

  return ResultatAppariement(
    apparies: apparies,
    ecartes: ecartes,
    elevesRestants: restants,
  );
}
