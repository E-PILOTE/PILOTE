import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/bulletins_provider.dart';
import '../providers/conseils_provider.dart' show awardFor;
import '../../../core/utils/rang.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service PDF : BULLETIN scolaire d'un élève pour un trimestre. Chrome officiel
//  partagé (OfficialPdfKit). Tableau matière × (coeff, moyenne /20, moy×coeff,
//  moyenne de classe, rang) + synthèse (moyenne générale, rang, mention).
// ══════════════════════════════════════════════════════════════════════════════
class BulletinPdfService {
  static String _avg(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  static Future<Uint8List> buildPdf({
    required StudentBulletin student,
    required double? classAverage,
    String? schoolName,
    String? className,
    String? trimesterLabel,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final doc = pw.Document(
      title: 'Bulletin — ${student.studentName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Bulletin scolaire',
    );

    pw.Widget infoCell(String label, String value) => pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(font: f.medium, fontSize: 7, color: kPdfMuted, letterSpacing: 0.8)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(font: f.bold, fontSize: 10, color: kPdfNavy)),
          ]),
        );

    pw.Widget th(String t, {pw.TextAlign align = pw.TextAlign.left, double flex = 1}) =>
        pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(font: f.bold, fontSize: 8, color: PdfColors.white)),
        );

    pw.Widget td(String t, {pw.TextAlign align = pw.TextAlign.left, double flex = 1, bool bold = false}) =>
        pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  font: bold ? f.bold : f.regular, fontSize: 8.5, color: kPdfNavy)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => ctx.pageNumber == 1
          ? OfficialPdfKit.header(logo, f, badge: 'BULLETIN\nSCOLAIRE')
          : pw.SizedBox(),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Bandeau identité.
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: kPdfSurface,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: kPdfBorder)),
              child: pw.Column(children: [
                pw.Row(children: [
                  infoCell('Élève', student.studentName),
                  infoCell('Matricule', student.matricule ?? '—'),
                  infoCell('Classe', className ?? '—'),
                ]),
                pw.SizedBox(height: 10),
                pw.Row(children: [
                  infoCell('Établissement', schoolName ?? '—'),
                  infoCell('Trimestre', trimesterLabel ?? '—'),
                  infoCell('Année', yearLabel ?? '—'),
                ]),
              ]),
            ),
            pw.SizedBox(height: 16),
            // En-tête tableau.
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const pw.BoxDecoration(color: kPdfNavy),
              child: pw.Row(children: [
                th('Matière', flex: 2.6),
                th('Coeff', align: pw.TextAlign.center),
                th('Moy. /20', align: pw.TextAlign.center, flex: 1.2),
                th('Moy×Coeff', align: pw.TextAlign.center, flex: 1.2),
                th('Moy. classe', align: pw.TextAlign.center, flex: 1.2),
                th('Rang', align: pw.TextAlign.center),
              ]),
            ),
            for (var i = 0; i < student.lines.length; i++)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : kPdfSurface,
                    border: const pw.Border(
                        bottom: pw.BorderSide(color: kPdfBorder, width: 0.5))),
                child: pw.Row(children: [
                  td(student.lines[i].subjectName, flex: 2.6, bold: true),
                  td('${student.lines[i].coefficient}', align: pw.TextAlign.center),
                  td(_avg(student.lines[i].average), align: pw.TextAlign.center, flex: 1.2, bold: true),
                  td(_avg(student.lines[i].weighted), align: pw.TextAlign.center, flex: 1.2),
                  td(_avg(student.lines[i].classAverage), align: pw.TextAlign.center, flex: 1.2),
                  td(student.lines[i].rank?.toString() ?? '—', align: pw.TextAlign.center),
                ]),
              ),
            pw.SizedBox(height: 16),
            // Synthèse.
            pw.Row(children: [
              _summaryBox(f, 'MOYENNE GÉNÉRALE',
                  student.overallAverage == null
                      ? '—'
                      : '${student.overallAverage!.toStringAsFixed(2)}/20',
                  kPdfNavy),
              pw.SizedBox(width: 10),
              _summaryBox(f, 'RANG',
                  student.rank == 0
                      ? '—'
                      : '${rangOrdinal(student.rank)} / ${student.totalStudents}',
                  kPdfGreen),
              pw.SizedBox(width: 10),
              _summaryBox(f, 'MENTION', student.mention, kPdfGold),
              pw.SizedBox(width: 10),
              _summaryBox(f, 'MOY. CLASSE', _avg(classAverage), kPdfMuted),
            ]),
            // Assiduité — comptée depuis l'appel quotidien sur la fenêtre du
            // trimestre. Le bulletin écrivait 0 en base sans jamais l'afficher :
            // il affirmait sans rien dire, et sans rien avoir observé.
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Text('ASSIDUITÉ  ',
                  style: pw.TextStyle(
                      font: f.bold, fontSize: 8, color: kPdfMuted)),
              pw.Text(student.assiduiteLabel,
                  style: pw.TextStyle(font: f.regular, fontSize: 9)),
            ]),
            // Décision + appréciation du conseil de classe (si délibéré).
            if (awardFor(student.decision) != null ||
                (student.councilAppreciation ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    color: kPdfSurface,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: kPdfBorder)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CONSEIL DE CLASSE',
                          style: pw.TextStyle(
                              font: f.medium,
                              fontSize: 7,
                              color: kPdfMuted,
                              letterSpacing: 0.8)),
                      if (awardFor(student.decision) != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(awardFor(student.decision)!.label,
                            style: pw.TextStyle(
                                font: f.bold, fontSize: 11, color: kPdfNavy)),
                      ],
                      if ((student.councilAppreciation ?? '').trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(student.councilAppreciation!.trim(),
                            style: pw.TextStyle(
                                font: f.regular, fontSize: 9, color: kPdfText)),
                      ],
                    ]),
              ),
            ],
            pw.SizedBox(height: 18),
            pw.Row(children: [
              pw.Expanded(child: _signatureBox(f, 'Le Professeur principal')),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _signatureBox(f, 'Le Chef d\'établissement')),
            ]),
          ]),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _summaryBox(PdfFonts f, String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: pw.BoxDecoration(
            color: color, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: f.medium, fontSize: 7, color: PdfColors.white, letterSpacing: 0.6)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(font: f.bold, fontSize: 13, color: PdfColors.white)),
        ]),
      ),
    );
  }

  static pw.Widget _signatureBox(PdfFonts f, String label) {
    return pw.Container(
      height: 64,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: kPdfBorder)),
      child: pw.Text(label,
          style: pw.TextStyle(font: f.medium, fontSize: 8.5, color: kPdfMuted)),
    );
  }
}
