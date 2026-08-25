import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../providers/import_eleves_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE MODÈLE À REMPLIR — pour l'école qui n'a PAS déjà de liste
//
//  ── CE QUE CE FICHIER N'EST PAS ────────────────────────────────────────────
//  ⚠️ Ce n'est PAS le format obligatoire de l'import. Le lecteur
//  (`import_liste_eleves.dart`) est écrit pour accepter la liste que l'école a
//  DÉJÀ : il reconnaît « nom », « noms », « patronyme », devine le séparateur,
//  rattrape l'encodage d'Excel FR et sait même découper « NGOMA Aïcha » en une
//  seule colonne. Une école qui tient trois cents élèves dans un classeur ne
//  doit surtout pas les retaper ici — ce serait deux jours de travail et une
//  centaine de fautes de frappe, précisément ce que l'import évite.
//
//  Le modèle est donc un SECOND RECOURS, proposé à côté de l'aide, jamais à la
//  place du fichier existant.
//
//  ── POURQUOI IL EXISTE QUAND MÊME ──────────────────────────────────────────
//  Parce que le point qui casse réellement un import n'est pas le nom des
//  colonnes — c'est le LIBELLÉ DE CLASSE. À la résolution, le nom de classe du
//  fichier doit correspondre à une classe existante de l'établissement, et le
//  code refuse délibérément de rapprocher une classe qui « ressemble » : mettre
//  un enfant en 6ᵉ B au lieu de 6ᵉ A ne se découvre qu'au conseil de classe.
//  Toute ligne dont la classe n'est pas reconnue est REJETÉE.
//
//  D'où le second fichier : la liste des classes RÉELLES de l'école, avec leur
//  niveau et leur filière. Le rejet « classe inconnue » devient un copier-coller.
//
//  ── DEUX FICHIERS, ET PAS UN SEUL ──────────────────────────────────────────
//  ⚠️ La liste des classes ne peut pas vivre dans le modèle lui-même. Toute
//  ligne du fichier importé est lue comme un élève : un bloc de référence en bas
//  du modèle reviendrait à faire entrer les noms de classes dans le registre des
//  élèves, ou à noyer l'écran de contrôle sous des lignes rejetées. Deux
//  fichiers nommés clairement coûtent un clic et ne polluent rien.
//
//  ── ENCODAGE ───────────────────────────────────────────────────────────────
//  ⚠️ Séparateur « ; » et BOM UTF-8, comme l'export du guichet. Sans eux, Excel
//  en français rouvre notre propre modèle en « PrÃ©nom » et en une seule
//  colonne — c'est-à-dire exactement les deux pièges que l'import documente. On
//  ne peut pas livrer un modèle qui tombe dedans.
// ════════════════════════════════════════════════════════════════════════════

/// Ce qui a été écrit, et où.
class ModeleImport {
  const ModeleImport({required this.modele, required this.classes});

  /// Chemin du modèle d'élèves à remplir.
  final String modele;

  /// Chemin de la liste des classes de l'école. `null` si l'école n'a encore
  /// aucune classe ouverte — il n'y a alors rien à recopier.
  final String? classes;
}

/// Toujours entre guillemets : un nom composé, un lieu de naissance ou un
/// libellé de filière peut contenir le séparateur.
String _cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

/// Les en-têtes que le lecteur reconnaît, dans l'ordre où une secrétaire les
/// remplit. Les quatre premières sont celles qui décident qu'une ligne est
/// écrivable ; les suivantes enrichissent la fiche sans jamais la bloquer.
const _entetes = <String>[
  'Nom',
  'Prénom',
  'Date de naissance',
  'Sexe',
  'Classe',
  'Lieu de naissance',
  'Nationalité',
];

/// Écrit le modèle d'import et, si l'école a des classes, leur liste.
///
/// [classes] vient de `classesImportProvider` : les classes ouvertes pour
/// l'année courante, c'est-à-dire les seules destinations qu'un import peut
/// viser.
Future<ModeleImport> genererModeleImport(List<ClasseCible> classes) async {
  final dir = await getApplicationDocumentsDirectory();

  // La classe d'exemple est une VRAIE classe de l'école quand il y en a une :
  // la ligne d'exemple montre alors le libellé exact à recopier, au lieu d'un
  // « 6e A » qui n'existe peut-être pas ici.
  final exemple = classes.isEmpty ? '6e A' : classes.first.nom;

  final m = StringBuffer()
    ..writeln(_entetes.map(_cell).join(';'))
    // ⚠️ Les lignes d'exemple se nomment elles-mêmes « À SUPPRIMER ». Un
    // exemple crédible laissé dans le fichier entrerait au registre comme un
    // vrai élève ; celui-ci saute aux yeux sur l'écran de contrôle, qui montre
    // chaque ligne avant le moindre enregistrement.
    ..writeln([
      'EXEMPLE — À SUPPRIMER',
      'Prénoms de l\'élève',
      '12/03/2011',
      'F',
      exemple,
      'Brazzaville',
      'Congolaise',
    ].map(_cell).join(';'))
    ..writeln([
      'EXEMPLE — À SUPPRIMER',
      'Prénoms de l\'élève',
      '05/09/2010',
      'M',
      exemple,
      'Pointe-Noire',
      'Congolaise',
    ].map(_cell).join(';'));

  final fModele = File('${dir.path}/modele-import-eleves.csv');
  await _ecrireAvecBom(fModele, m.toString());

  if (classes.isEmpty) {
    return ModeleImport(modele: fModele.path, classes: null);
  }

  final c = StringBuffer()
    ..writeln(['Classe', 'Niveau', 'Filière'].map(_cell).join(';'));
  for (final cl in classes) {
    c.writeln([cl.nom, cl.niveau ?? '', cl.filiere ?? ''].map(_cell).join(';'));
  }

  final fClasses = File('${dir.path}/classes-de-mon-ecole.csv');
  await _ecrireAvecBom(fClasses, c.toString());

  return ModeleImport(modele: fModele.path, classes: fClasses.path);
}

/// Écrit avec le BOM UTF-8 en tête — sans lui, Excel FR mange les accents.
Future<void> _ecrireAvecBom(File f, String contenu) =>
    f.writeAsString('﻿$contenu');
