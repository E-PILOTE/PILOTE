// ══════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE MATRICULE — le grand livre réglementaire
//
//  ── POURQUOI `MultiPage` ICI, ALORS QU'UNE ATTESTATION L'INTERDIT ─────────
//  `AttestationKit` impose `pw.Page` : une attestation dont la signature
//  basculerait sur la page suivante n'authentifierait plus rien. Un registre
//  est l'inverse — il est fait pour courir sur cent pages, chacune reprenant
//  son en-tête et son numéro. `MultiPage` est donc le bon outil, et la règle
//  d'en face reste vraie pour ce qu'elle garde.
//
//  ── PAYSAGE, ET DOUZE COLONNES QUI TIENNENT ───────────────────────────────
//  Les largeurs sont fixées en points et leur somme est VÉRIFIÉE par un test.
//  Une colonne qui déborde ne se voit pas à l'aperçu de la première page : elle
//  se découvre à la centième, quand un nom long pousse la ligne — et le
//  registre est alors déjà relié.
//
//  ── LE NOMBRE D'INSCRITS EST ARRÊTÉ EN FIN DE LIVRE ───────────────────────
//  La formule traditionnelle l'écrit « en toutes lettres », parce que sur du
//  papier un chiffre se rature et un mot beaucoup moins. Ici le document se
//  régénère depuis la base à chaque impression : la protection n'a plus d'objet,
//  et un nombre épelé à moitié juste vaudrait moins que le chiffre.
//
//  ── ET LES LACUNES SONT ÉCRITES, PAS TUES ─────────────────────────────────
//  Si le poste ne voit pas tout, le registre le DIT, en tête et à l'arrêté. Une
//  pièce réglementaire qui se prétend complète sans l'être est pire qu'une
//  pièce qui déclare sa limite : la seconde se complète, la première trompe.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/ine.dart';
import '../../../core/utils/sortie_motif.dart';
import '../providers/registre_matricule_provider.dart';

/// Largeurs des colonnes, en points. Leur somme doit tenir dans la largeur
/// utile d'une A4 paysage (842 pt moins deux marges de 28 pt = 786 pt).
const List<double> kColonnesRegistre = [
  26, // N° d'ordre
  68, // Matricule
  72, // Identifiant national
  132, // Nom et prénoms
  16, // Sexe
  56, // Né(e) le
  68, // à
  96, // Père, mère ou tuteur
  56, // Entré le
  54, // Classe d'entrée
  56, // Sorti le
  70, // Motif de sortie
];

const List<String> kEntetesRegistre = [
  'N°',
  'Matricule',
  'Identifiant nat.',
  'Nom et prénoms',
  'S',
  'Né(e) le',
  'à',
  'Père, mère ou tuteur',
  'Entré le',
  'Classe',
  'Sorti le',
  'Motif de sortie',
];

/// Largeur utile d'une A4 paysage avec les marges du document.
const double kLargeurUtileRegistre = 842 - 2 * 28;

String _jour(DateTime? d) =>
    d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

class RegistreMatriculePdfService {
  static Future<Uint8List> build({
    required Registre registre,
    required String schoolName,
    String? city,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
      header: (ctx) => OfficialPdfKit.headerFor(
        ctx,
        logo,
        f,
        badge: 'REGISTRE\nMATRICULE',
        title: 'Registre matricule — $schoolName',
      ),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        _titre(f, schoolName, yearLabel),
        if (!registre.complet) ...[
          pw.SizedBox(height: 8),
          _avertissementLacunes(f, registre.lacunes),
        ],
        pw.SizedBox(height: 10),
        _table(f, registre.lignes),
        pw.SizedBox(height: 16),
        _arrete(f, registre, city),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _titre(PdfFonts f, String schoolName, String? yearLabel) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('REGISTRE MATRICULE',
            style: pw.TextStyle(
                font: f.bold, fontSize: 13, color: kPdfNavy, letterSpacing: 1)),
        pw.SizedBox(height: 2),
        pw.Text(
          yearLabel == null || yearLabel.isEmpty
              ? schoolName
              : '$schoolName — arrêté au titre de l’année scolaire $yearLabel',
          style: pw.TextStyle(font: f.regular, fontSize: 8.5, color: kPdfMuted),
        ),
      ]);

  static pw.Widget _avertissementLacunes(PdfFonts f, int lacunes) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: pdfTint(kPdfRed, 0.10),
          border: pw.Border.all(color: kPdfRed, width: 0.6),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          'REGISTRE INCOMPLET — $lacunes inscription'
          '${lacunes > 1 ? 's' : ''} sans élève correspondant sur ce poste. '
          'Les lignes manquantes existent au serveur ; ce poste ne les a pas '
          'reçues. Ne pas produire ce document comme complet : reconnectez le '
          'poste et réimprimez.',
          style: pw.TextStyle(font: f.medium, fontSize: 8, color: kPdfRed),
        ),
      );

  static pw.Widget _table(PdfFonts f, List<LigneRegistre> lignes) {
    pw.Widget cellule(String texte, double largeur,
            {bool gras = false, bool centre = false}) =>
        pw.Container(
          width: largeur,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            texte,
            maxLines: 2,
            textAlign: centre ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
                font: gras ? f.bold : f.regular,
                fontSize: 6.5,
                color: kPdfText),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: kPdfBorder, width: 0.4),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: kPdfSurface),
          children: [
            for (var i = 0; i < kEntetesRegistre.length; i++)
              cellule(kEntetesRegistre[i], kColonnesRegistre[i],
                  gras: true, centre: i == 0 || i == 4),
          ],
        ),
        for (var i = 0; i < lignes.length; i++)
          pw.TableRow(children: _ligne(f, cellule, lignes[i], i + 1)),
      ],
    );
  }

  static List<pw.Widget> _ligne(
    PdfFonts f,
    pw.Widget Function(String, double, {bool gras, bool centre}) cellule,
    LigneRegistre l,
    int rang,
  ) {
    final valeurs = <String>[
      '$rang',
      l.matricule,
      l.ine == null || l.ine!.isEmpty ? '—' : formatIne(l.ine),
      // L'archivage se lit sur la ligne : un élève retiré du registre actif
      // reste au grand livre, et le document doit dire lequel.
      l.archive ? '${l.nomComplet} (archivé)' : l.nomComplet,
      l.gender ?? '',
      _jour(l.dateOfBirth),
      l.placeOfBirth ?? '',
      l.tuteur ?? '',
      _jour(l.entreeLe),
      l.classeEntree ?? '',
      _jour(l.sortieLe),
      l.motifSortie == null || l.motifSortie!.isEmpty
          ? ''
          : sortieMotifLabel(l.motifSortie!),
    ];
    return [
      for (var i = 0; i < valeurs.length; i++)
        cellule(valeurs[i], kColonnesRegistre[i],
            gras: i == 1, centre: i == 0 || i == 4),
    ];
  }

  /// L'arrêté de fin de livre — la formule qui clôt un registre.
  static pw.Widget _arrete(PdfFonts f, Registre r, String? city) {
    final sortis = r.lignes.where((l) => l.sorti).length;
    final presents = r.lignes.length - sortis;
    final quand = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: kPdfNavy, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('ARRÊTÉ DU PRÉSENT REGISTRE',
            style: pw.TextStyle(
                font: f.bold, fontSize: 9, color: kPdfNavy, letterSpacing: 0.6)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Le présent registre est arrêté au nombre de ${r.lignes.length} '
          'élève${r.lignes.length > 1 ? 's' : ''} inscrit'
          '${r.lignes.length > 1 ? 's' : ''}, dont $presents encore présent'
          '${presents > 1 ? 's' : ''} et $sortis sorti'
          '${sortis > 1 ? 's' : ''} des effectifs.'
          '${r.complet ? '' : ' Il est déclaré INCOMPLET : ${r.lacunes} '
              'inscription${r.lacunes > 1 ? 's' : ''} n’a pas pu être '
              'rattachée à un élève sur ce poste.'}',
          style: pw.TextStyle(
              font: f.regular, fontSize: 8.5, color: kPdfText, lineSpacing: 2),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(
                  city == null || city.isEmpty
                      ? 'Le $quand'
                      : 'Fait à $city, le $quand',
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 8, color: kPdfMuted)),
              pw.SizedBox(height: 26),
              pw.Container(width: 150, height: 0.6, color: kPdfBorder),
              pw.SizedBox(height: 3),
              pw.Text('Le Chef d’établissement',
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 7.5, color: kPdfMuted)),
            ]),
          ],
        ),
      ]),
    );
  }
}
