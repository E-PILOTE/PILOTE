import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques PDF partagées entre Élèves et Inscriptions : couleurs/noms/ordre de
//  cycle + section « cycle » dépliée en sous-groupes (classe) avec tables.
// ════════════════════════════════════════════════════════════════════════════

const _cycleColors = <String, PdfColor>{
  'prescolaire': PdfColor.fromInt(0xFFEC4899),
  'primaire': PdfColor.fromInt(0xFF0EA5E9),
  'college': kPdfGreen,
  'lycee': kPdfNavy,
  'formation_pro': PdfColor.fromInt(0xFFF59E0B),
  'fp': PdfColor.fromInt(0xFFF59E0B),
};
const _cycleOrder = <String, int>{
  'prescolaire': 1,
  'primaire': 2,
  'college': 3,
  'lycee': 4,
  'formation_pro': 5,
  'fp': 5,
};
const _cycleNames = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Professionnelle',
  'fp': 'Formation Professionnelle',
};

PdfColor cycleColorPdf(String? code) => _cycleColors[code ?? ''] ?? kPdfNavy;
int cycleOrderPdf(String? code) => _cycleOrder[code ?? ''] ?? 9;
String cycleNamePdf(String? code, [String? fallback]) =>
    _cycleNames[code ?? ''] ??
    ((fallback?.trim().isNotEmpty ?? false) ? fallback!.trim() : 'Autres');

/// Un sous-groupe (une classe) : son intitulé et les LIGNES du tableau.
///
/// Les lignes arrivent brutes, pas déjà montées en widget : c'est ce qui permet
/// de les découper en blocs d'une page (cf. [enrollmentCycleBlocks]). Un tableau
/// livré tout monté ne peut plus être scindé — c'était le défaut de l'ancienne
/// signature.
class EnrollmentGroup {
  const EnrollmentGroup({
    required this.label,
    required this.headers,
    required this.rows,
    required this.flex,
    this.leftAlignCols = const {},
  });
  final String label;
  final List<String> headers;
  final List<List<String>> rows;
  final List<int> flex;
  final Set<int> leftAlignCols;
}

const _kEnrollmentPad = pw.EdgeInsets.symmetric(horizontal: 28);

/// Lignes par bloc.
///
/// Une page A4 tient une trentaine de lignes. Le premier bloc arrive sous le
/// bloc titre et la grille d'indicateurs : il doit donc rester petit pour tenir
/// dans ce qu'il reste de la première page. Les suivants sont bornés à moins
/// d'une page pleine — condition NÉCESSAIRE, car un bloc insécable plus haut
/// qu'une page fait échouer tout le document (cf. `enrollmentCycleBlocks`).
const _kFirstRows = 10;
const _kNextRows = 26;

/// La section d'un cycle, découpée en blocs dont AUCUN ne dépasse une page.
///
/// ⚠️ POURQUOI UNE LISTE ET NON UN WIDGET.
/// La version précédente rendait toute la section dans un unique `pw.Padding`.
/// Un `Padding` ne sait pas se scinder entre deux pages : dès qu'il devient plus
/// haut qu'une page, `MultiPage` boucle jusqu'à `TooManyPagesException` et le
/// document NE SORT PAS DU TOUT — pas tronqué, absent. `official_pdf_kit.dart`
/// documente ce piège à propos de `frame()` ; il valait ici tout autant.
///
/// Le seuil se franchissait à ~29 élèves dans une même classe. Une classe
/// congolaise en compte quarante à soixante : l'export des inscriptions ET
/// celui de l'effectif étaient donc cassés pour presque toutes les classes
/// réelles. Verrouillé par `test/enrollment_pdf_pagination_test.dart`.
///
/// Chaque bloc reste padé à l'identique, si bien que la mise en page est la
/// même qu'avant — seule la capacité à changer de page est gagnée.
List<pw.Widget> enrollmentCycleBlocks({
  required PdfColor color,
  required String cycleName,
  required int count,
  required int groupCount,
  required String groupNoun, // « classe »
  required PdfFonts fonts,
  required List<EnrollmentGroup> groups,
}) {
  pw.Widget groupLabel(String label, {required bool suite}) => pw.Row(children: [
        pw.Container(width: 3, height: 11, color: color),
        pw.SizedBox(width: 6),
        pw.Text(suite ? '${label.toUpperCase()} (SUITE)' : label.toUpperCase(),
            style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 9,
                color: kPdfText,
                letterSpacing: 0.5)),
      ]);

  return [
    // En-tête de cycle (teinte pré-calculée, jamais d'aplat).
    pw.Padding(
      padding: _kEnrollmentPad,
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: pdfTint(color, 0.12),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: pdfTint(color, 0.4)),
        ),
        child: pw.Row(children: [
          pw.Container(
              width: 4,
              height: 14,
              decoration: pw.BoxDecoration(
                  color: color, borderRadius: pw.BorderRadius.circular(2))),
          pw.SizedBox(width: 8),
          pw.Text(cycleName.toUpperCase(),
              style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 11.5,
                  color: color,
                  letterSpacing: 0.5)),
          pw.Spacer(),
          pw.Text('$count · $groupCount $groupNoun${groupCount > 1 ? 's' : ''}',
              style: pw.TextStyle(
                  font: fonts.medium, fontSize: 8.5, color: kPdfMuted)),
        ]),
      ),
    ),
    pw.SizedBox(height: 8),
    for (final g in groups)
      for (final (i, chunk) in OfficialPdfKit.paginate(g.rows,
              first: _kFirstRows, next: _kNextRows)
          .indexed)
        // ⚠️ `Inseparable` n'est pas décoratif.
        // Dans le paquet `pdf`, un `SingleChildWidget` — donc un `Padding` —
        // délègue `canSpan` à son enfant, et un `Column` vertical, lui, se
        // scinde volontiers ENTRE ses enfants. Sans ce garde-fou, l'intitulé de
        // la classe restait seul en bas d'une page et son tableau partait sur
        // la suivante : chaque page se terminait sur un titre orphelin suivi
        // d'un grand vide. `Inseparable` rend le bloc atomique — il tient d'un
        // seul tenant ou passe entier à la page suivante.
        //
        // La contrepartie, c'est la contrainte ci-dessus : un bloc insécable
        // plus haut qu'une page ne peut aller nulle part et fait échouer tout
        // le document. D'où le découpage en petits blocs, jamais l'inverse.
        pw.Inseparable(
          child: pw.Padding(
            padding: _kEnrollmentPad,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                groupLabel(g.label, suite: i > 0),
                pw.SizedBox(height: 5),
                OfficialPdfKit.table(
                  headers: g.headers,
                  rows: chunk,
                  fonts: fonts,
                  flex: g.flex,
                  leftAlignCols: g.leftAlignCols,
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
        ),
  ];
}
