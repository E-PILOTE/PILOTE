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

class EnrollmentGroup {
  const EnrollmentGroup({required this.label, required this.table});
  final String label;
  final pw.Widget table;
}

pw.Widget enrollmentCycleSection({
  required PdfColor color,
  required String cycleName,
  required int count,
  required int groupCount,
  required String groupNoun, // « classe »
  required PdfFonts fonts,
  required List<EnrollmentGroup> groups,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // En-tête de cycle (teinte pré-calculée, jamais d'aplat).
        pw.Container(
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
            pw.Text(
                '$count · $groupCount $groupNoun${groupCount > 1 ? 's' : ''}',
                style: pw.TextStyle(
                    font: fonts.medium, fontSize: 8.5, color: kPdfMuted)),
          ]),
        ),
        pw.SizedBox(height: 8),
        for (final g in groups) ...[
          pw.Row(children: [
            pw.Container(width: 3, height: 11, color: color),
            pw.SizedBox(width: 6),
            pw.Text(g.label.toUpperCase(),
                style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 9,
                    color: kPdfText,
                    letterSpacing: 0.5)),
          ]),
          pw.SizedBox(height: 5),
          g.table,
          pw.SizedBox(height: 8),
        ],
      ],
    ),
  );
}
