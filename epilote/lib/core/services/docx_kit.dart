import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PRODUIRE UN DOCUMENT WORD MODIFIABLE
//
//  ── POURQUOI, ALORS QU'ON SAIT DÉJÀ FAIRE DU PDF ───────────────────────────
//  ⚠️ Un PDF ne se modifie pas. Or il existe une famille de pièces qu'un chef
//  d'établissement doit AMENDER AVANT DE SIGNER : un rapport dont il nuance
//  une conclusion, une attestation dont il précise le motif, un courrier à la
//  tutelle. Pour celles-là, le PDF est un mur — l'agent le réimprime, le
//  rature à la main, ou retape tout dans Word à partir de rien.
//
//  ⚠️ ET SEULEMENT POUR CELLES-LÀ. Un état de trois cents élèves en Word est
//  pire qu'en PDF : il se repagine tout seul chez le lecteur, les colonnes
//  bougent, et deux impressions du même fichier ne donnent pas le même
//  document. Le PDF reste la forme de tout ce qui doit rester STABLE.
//
//  ── POURQUOI CE FICHIER EXISTE PLUTÔT QU'UNE DÉPENDANCE ────────────────────
//  Il n'existe aucune bibliothèque Dart mûre pour écrire du .docx. Mais un
//  .docx n'est pas un format opaque : c'est une ARCHIVE ZIP contenant quelques
//  fichiers XML. On l'écrit donc directement, avec `archive` pour le ZIP.
//
//  Le document produit s'ouvre dans Word, LibreOffice et Google Docs, et il
//  est ENTIÈREMENT modifiable — c'est tout ce qu'on lui demande.
//
//  ── LES QUATRE PIÈCES MINIMALES D'UN .DOCX ─────────────────────────────────
//    [Content_Types].xml        dit à Word ce que contient l'archive
//    _rels/.rels                désigne le document principal
//    word/document.xml          le contenu
//    word/styles.xml            les styles nommés que le contenu référence
//
//  ⚠️ Aucune n'est facultative. Il manque l'une d'elles et Word annonce « le
//  fichier est corrompu » sans dire laquelle — d'où `docx_kit_test.dart`, qui
//  rouvre l'archive produite et vérifie que les quatre y sont.
//
//  ── LA CONTRAINTE QUI SE PAIE CHER SI ON L'OUBLIE ──────────────────────────
//  ⚠️ Le corps du document DOIT se terminer par un paragraphe avant
//  `<w:sectPr>`. Un document qui finit sur un tableau s'ouvre en mode
//  récupération. Le constructeur ajoute donc toujours un paragraphe final, et
//  un paragraphe vide après chaque tableau : sans lui, deux tableaux
//  consécutifs fusionnent en un seul aux yeux de Word.
// ════════════════════════════════════════════════════════════════════════════

/// Échappe ce qui doit l'être, et retire ce que l'XML n'accepte pas.
///
/// ⚠️ Les caractères de contrôle ne sont pas seulement inutiles : un seul
/// suffit à rendre l'archive illisible, et il peut venir d'une saisie collée
/// depuis un autre logiciel. On les retire plutôt que de leur faire confiance.
String _xml(String? v) => (v ?? '')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Un passage de texte, avec le style nommé qui lui est appliqué.
enum DocxStyle {
  titre('TitreDoc'),
  sousTitre('SousTitreDoc'),
  section('SectionDoc'),
  corps('Normal'),
  petit('PetitDoc');

  const DocxStyle(this.id);
  final String id;
}

/// Ce qu'un document sait porter. Volontairement court : chaque bloc de plus
/// est un bloc à maintenir dans quatre logiciels différents.
sealed class _Bloc {
  const _Bloc();
}

class _Para extends _Bloc {
  const _Para(this.texte, this.style, {this.gras = false});
  final String texte;
  final DocxStyle style;
  final bool gras;
}

class _Tableau extends _Bloc {
  const _Tableau(this.entetes, this.lignes);
  final List<String> entetes;
  final List<List<String>> lignes;
}

class _Saut extends _Bloc {
  const _Saut();
}

/// Compose un document Word, puis rend les octets du `.docx`.
class DocxBuilder {
  DocxBuilder({
    required this.titre,
    this.etablissement,
    this.sousTitre,
    this.paysage = false,
  });

  /// Le titre imprimé en tête du document (et non le nom du fichier).
  final String titre;

  /// L'établissement émetteur. ⚠️ Sans lui, une pièce qui sort de l'école ne
  /// dit pas de quelle école elle vient — défaut déjà corrigé sur les PDF.
  final String? etablissement;

  final String? sousTitre;

  /// ⚠️ Le paysage se décide à la CONSTRUCTION : Word le porte dans `sectPr`,
  /// en fin de corps, et non par page.
  final bool paysage;

  final List<_Bloc> _blocs = [];

  /// Un intertitre de section.
  void section(String texte) => _blocs.add(_Para(texte, DocxStyle.section));

  /// Un paragraphe de corps de texte. La chaîne vide produit une ligne vide.
  void paragraphe(String texte, {bool gras = false}) =>
      _blocs.add(_Para(texte, DocxStyle.corps, gras: gras));

  /// Une mention de bas de document — portée, réserve, avertissement.
  void mention(String texte) => _blocs.add(_Para(texte, DocxStyle.petit));

  /// Une ligne « Libellé : valeur », la forme la plus courante d'un état.
  void champ(String libelle, String? valeur) => paragraphe(
        '$libelle : ${(valeur ?? '').trim().isEmpty ? '—' : valeur!.trim()}',
      );

  /// Un tableau à en-têtes. Les lignes plus courtes que les en-têtes sont
  /// complétées : une cellule manquante décale toute la table chez Word.
  void tableau({
    required List<String> entetes,
    required List<List<String>> lignes,
    String siVide = 'Aucune donnée.',
  }) {
    if (lignes.isEmpty) {
      paragraphe(siVide);
      return;
    }
    _blocs.add(_Tableau(entetes, [
      for (final l in lignes)
        [
          for (var i = 0; i < entetes.length; i++) i < l.length ? l[i] : '',
        ],
    ]));
  }

  void saut() => _blocs.add(const _Saut());

  /// Le bloc de signature, avec la place pour signer à la main.
  ///
  /// ⚠️ Trois lignes vides, et pas une bordure : une pièce administrative
  /// congolaise se signe et se tamponne, et le tampon a besoin de place.
  void signature(String qualite, {String? lieu}) {
    saut();
    paragraphe(
      lieu == null ? '' : 'Fait à $lieu, le ……………………………',
    );
    saut();
    paragraphe(qualite, gras: true);
    paragraphe('');
    paragraphe('');
  }

  /// Rend les octets du fichier `.docx`.
  Uint8List construire() {
    final archive = Archive()
      ..addFile(_fichier('[Content_Types].xml', _contentTypes))
      ..addFile(_fichier('_rels/.rels', _rels))
      ..addFile(_fichier('word/_rels/document.xml.rels', _docRels))
      ..addFile(_fichier('word/styles.xml', _styles))
      ..addFile(_fichier('word/document.xml', _document()));

    final zip = ZipEncoder().encode(archive);
    return Uint8List.fromList(zip);
  }

  static ArchiveFile _fichier(String nom, String contenu) {
    final octets = utf8.encode(contenu);
    return ArchiveFile(nom, octets.length, octets);
  }

  // ── Le corps ─────────────────────────────────────────────────────────────

  String _document() {
    final b = StringBuffer()
      ..write(_entete)
      ..write('<w:body>');

    if ((etablissement ?? '').trim().isNotEmpty) {
      b.write(_para(etablissement!.trim(), DocxStyle.sousTitre));
    }
    b.write(_para(titre, DocxStyle.titre));
    if ((sousTitre ?? '').trim().isNotEmpty) {
      b.write(_para(sousTitre!.trim(), DocxStyle.sousTitre));
    }
    b.write(_para('', DocxStyle.corps));

    for (final bloc in _blocs) {
      switch (bloc) {
        case _Para(:final texte, :final style, :final gras):
          b.write(_para(texte, style, gras: gras));
        case _Tableau(:final entetes, :final lignes):
          b.write(_table(entetes, lignes));
          // ⚠️ Le paragraphe vide n'est pas décoratif : sans lui, deux
          // tableaux qui se suivent fusionnent en un seul chez Word.
          b.write(_para('', DocxStyle.corps));
        case _Saut():
          b.write(_para('', DocxStyle.corps));
      }
    }

    // ⚠️ Un corps qui se termine par un tableau ouvre Word en mode
    // récupération. Le paragraphe final n'est pas négociable.
    b
      ..write(_para('', DocxStyle.corps))
      ..write(_sectPr)
      ..write('</w:body></w:document>');
    return b.toString();
  }

  static String _para(String texte, DocxStyle style, {bool gras = false}) {
    final runs = texte.isEmpty
        ? ''
        : texte
            .split('\n')
            .map((l) => '<w:r>${gras ? '<w:rPr><w:b/></w:rPr>' : ''}'
                '<w:t xml:space="preserve">${_xml(l)}</w:t></w:r>')
            .join('<w:r><w:br/></w:r>');
    return '<w:p><w:pPr><w:pStyle w:val="${style.id}"/></w:pPr>$runs</w:p>';
  }

  static String _cellule(String texte, {bool entete = false}) =>
      '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/>'
      '${entete ? '<w:shd w:val="clear" w:fill="E8EEF5"/>' : ''}'
      '</w:tcPr>'
      '<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr>'
      '<w:r>${entete ? '<w:rPr><w:b/></w:rPr>' : ''}'
      '<w:t xml:space="preserve">${_xml(texte)}</w:t></w:r></w:p></w:tc>';

  static String _table(List<String> entetes, List<List<String>> lignes) {
    final b = StringBuffer()
      ..write('<w:tbl><w:tblPr><w:tblStyle w:val="GrilleDoc"/>'
          '<w:tblW w:w="5000" w:type="pct"/><w:tblBorders>'
          '<w:top w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '<w:left w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '<w:bottom w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '<w:right w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '<w:insideH w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '<w:insideV w:val="single" w:sz="4" w:color="C9D4E0"/>'
          '</w:tblBorders></w:tblPr>')
      // `tblHeader` fait répéter la ligne d'en-tête en haut de chaque page :
      // sur un état de plusieurs pages, sans elle, les colonnes deviennent
      // anonymes dès la deuxième.
      ..write('<w:tr><w:trPr><w:tblHeader/></w:trPr>')
      ..writeAll(entetes.map((e) => _cellule(e, entete: true)))
      ..write('</w:tr>');
    for (final l in lignes) {
      b
        ..write('<w:tr>')
        ..writeAll(l.map((c) => _cellule(c)))
        ..write('</w:tr>');
    }
    b.write('</w:tbl>');
    return b.toString();
  }

  String get _sectPr => paysage
      ? '<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
          '<w:pgMar w:top="851" w:right="1134" w:bottom="851" w:left="1134"/>'
          '</w:sectPr>'
      : '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
          '</w:sectPr>';

  // ── Les parties fixes de l'archive ───────────────────────────────────────

  static const _entete =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">';

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/></Relationships>';

  static const _docRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/></Relationships>';

  /// Les styles nommés. ⚠️ Un `pStyle` qui référence un style ABSENT n'est pas
  /// une erreur pour Word : il l'ignore en silence, et le document sort tout
  /// en corps de texte. C'est le genre de défaut qu'on ne voit qu'à
  /// l'impression.
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:docDefaults><w:rPrDefault><w:rPr>'
      '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/>'
      '</w:rPr></w:rPrDefault></w:docDefaults>'
      '<w:style w:type="paragraph" w:styleId="Normal" w:default="1">'
      '<w:name w:val="Normal"/>'
      '<w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>'
      '</w:style>'
      '<w:style w:type="paragraph" w:styleId="TitreDoc"><w:name w:val="Titre document"/>'
      '<w:pPr><w:spacing w:before="120" w:after="60"/><w:jc w:val="center"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="34"/><w:color w:val="1E3A5F"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="SousTitreDoc"><w:name w:val="Sous-titre"/>'
      '<w:pPr><w:spacing w:after="60"/><w:jc w:val="center"/></w:pPr>'
      '<w:rPr><w:sz w:val="22"/><w:color w:val="64748B"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="SectionDoc"><w:name w:val="Section"/>'
      '<w:pPr><w:spacing w:before="240" w:after="80"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="1E3A5F"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="PetitDoc"><w:name w:val="Mention"/>'
      '<w:pPr><w:spacing w:before="160" w:after="60"/></w:pPr>'
      '<w:rPr><w:i/><w:sz w:val="16"/><w:color w:val="64748B"/></w:rPr></w:style>'
      '<w:style w:type="table" w:styleId="GrilleDoc"><w:name w:val="Grille"/>'
      '<w:tblPr><w:tblCellMar>'
      '<w:top w:w="60" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
      '<w:bottom w:w="60" w:type="dxa"/><w:right w:w="90" w:type="dxa"/>'
      '</w:tblCellMar></w:tblPr></w:style>'
      '</w:styles>';
}

/// Ouvre « Enregistrer sous » et écrit le document Word au chemin choisi.
///
/// Retourne le chemin écrit, ou `null` si l'agent a fermé la fenêtre — une
/// annulation n'est pas une erreur et ne doit jamais s'afficher comme telle.
///
/// ⚠️ On réécrit TOUJOURS les octets après le sélecteur. La fenêtre
/// « Enregistrer sous » de Windows ne crée pas le fichier : elle rend un
/// chemin. En écrasant un document plus ancien du même nom, l'agent
/// repartirait sinon avec l'ANCIEN contenu en croyant tenir le nouveau.
Future<String?> enregistrerDocxSous({
  required String nomPropose,
  required Uint8List octets,
  required String titreFenetre,
}) async {
  final chemin = await FilePicker.platform.saveFile(
    dialogTitle: titreFenetre,
    fileName: nomPropose,
    type: FileType.custom,
    allowedExtensions: const ['docx'],
    bytes: octets,
  );
  if (chemin == null) return null;
  await File(chemin).writeAsBytes(octets, flush: true);
  return chemin;
}
