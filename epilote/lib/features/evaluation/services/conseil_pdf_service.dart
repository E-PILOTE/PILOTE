import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/conseils_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service PDF : PROCÈS-VERBAL du conseil de classe. Chrome officiel partagé
//  (OfficialPdfKit). Bandeau identité (classe, trimestre, moyenne, effectif) +
//  tableau récapitulatif (rang, élève, moyenne, mention, distinction,
//  appréciation) + synthèse du conseil + signatures (président, professeur
//  principal, secrétaire).
// ══════════════════════════════════════════════════════════════════════════════
class ConseilPdfService {
  static Future<Uint8List> buildPv({
    required CouncilSession session,
    String? schoolName,
    String? className,
    String? trimesterLabel,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final positives = session.entries
        .where((e) => awardFor(e.award)?.positive == true)
        .length;

    final doc = pw.Document(
      title: 'PV Conseil de classe — ${className ?? ''}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Procès-verbal du conseil de classe',
    );

    pw.Widget infoCell(String label, String value) => pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label.toUpperCase(),
                    style: pw.TextStyle(
                        font: f.medium,
                        fontSize: 7,
                        color: kPdfMuted,
                        letterSpacing: 0.8)),
                pw.SizedBox(height: 2),
                pw.Text(value,
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 10, color: kPdfNavy)),
              ]),
        );

    pw.Widget th(String t,
            {pw.TextAlign align = pw.TextAlign.left, double flex = 1}) =>
        pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  font: f.bold, fontSize: 8, color: PdfColors.white)),
        );

    pw.Widget td(String t,
            {pw.TextAlign align = pw.TextAlign.left,
            double flex = 1,
            bool bold = false,
            PdfColor? color}) =>
        pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  font: bold ? f.bold : f.regular,
                  fontSize: 8,
                  color: color ?? kPdfNavy)),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => ctx.pageNumber == 1
          ? OfficialPdfKit.header(logo, f,
              badge: 'PROCÈS-VERBAL\nCONSEIL DE CLASSE')
          : pw.SizedBox(),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bandeau identité.
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: kPdfSurface,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: kPdfBorder)),
                  child: pw.Column(children: [
                    pw.Row(children: [
                      infoCell('Établissement', schoolName ?? '—'),
                      infoCell('Classe', className ?? '—'),
                      infoCell('Trimestre', trimesterLabel ?? '—'),
                      infoCell('Année', yearLabel ?? '—'),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Row(children: [
                      infoCell(
                          'Moyenne de classe',
                          session.classAverage == null
                              ? '—'
                              : '${session.classAverage!.toStringAsFixed(2)}/20'),
                      infoCell('Effectif', '${session.entries.length} élèves'),
                      infoCell('Distinctions', '$positives'),
                      infoCell('Date du conseil',
                          DateFormat('dd/MM/yyyy', 'fr').format(DateTime.now())),
                    ]),
                  ]),
                ),
                pw.SizedBox(height: 14),
                // En-tête tableau.
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: const pw.BoxDecoration(color: kPdfNavy),
                  child: pw.Row(children: [
                    th('Rg', align: pw.TextAlign.center, flex: 0.5),
                    th('Élève', flex: 2.2),
                    th('Moy.', align: pw.TextAlign.center, flex: 0.8),
                    th('Mention', flex: 1.2),
                    th('Distinction', flex: 1.4),
                    th('Appréciation du conseil', flex: 2.4),
                  ]),
                ),
                for (var i = 0; i < session.entries.length; i++)
                  _rowFor(session.entries[i], i, td),
                pw.SizedBox(height: 14),
                // Synthèse.
                if ((session.directorComment ?? '').trim().isNotEmpty) ...[
                  pw.Text('SYNTHÈSE DU CONSEIL',
                      style: pw.TextStyle(
                          font: f.bold,
                          fontSize: 8,
                          color: kPdfMuted,
                          letterSpacing: 0.8)),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                        color: kPdfSurface,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: kPdfBorder)),
                    child: pw.Text(session.directorComment!.trim(),
                        style: pw.TextStyle(
                            font: f.regular, fontSize: 9, color: kPdfText)),
                  ),
                  pw.SizedBox(height: 16),
                ],
                pw.Row(children: [
                  pw.Expanded(child: _sign(f, 'Le Président du conseil')),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _sign(f, 'Le Professeur principal')),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _sign(f, 'Le Secrétaire')),
                ]),
              ]),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _rowFor(CouncilEntry e, int i, pw.Widget Function(String,
          {pw.TextAlign align, double flex, bool bold, PdfColor? color}) td) {
    final award = awardFor(e.award);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : kPdfSurface,
          border: const pw.Border(
              bottom: pw.BorderSide(color: kPdfBorder, width: 0.5))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        td(e.rank == 0 ? '—' : '${e.rank}', align: pw.TextAlign.center, flex: 0.5),
        td(e.studentName, flex: 2.2, bold: true),
        td(e.average == null ? '—' : e.average!.toStringAsFixed(2),
            align: pw.TextAlign.center, flex: 0.8, bold: true),
        td(e.mention, flex: 1.2),
        td(award?.label ?? '—',
            flex: 1.4,
            bold: award != null,
            color: award == null ? kPdfMuted : kPdfNavy),
        td((e.appreciation ?? '').trim().isEmpty ? '—' : e.appreciation!.trim(),
            flex: 2.4),
      ]),
    );
  }

  static pw.Widget _sign(PdfFonts f, String label) => pw.Container(
        height: 60,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: kPdfBorder)),
        child: pw.Text(label,
            style: pw.TextStyle(font: f.medium, fontSize: 8, color: kPdfMuted)),
      );
}
