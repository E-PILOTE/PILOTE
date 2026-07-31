import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/mention.dart';
import '../providers/passage_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PROCÈS-VERBAL DE PASSAGE EN CLASSE SUPÉRIEURE.
//
//  C'est ce papier qui fait foi, pas l'écran : il est signé, archivé, et c'est
//  lui qu'on ressort quand une famille conteste. Il porte donc, pour chaque
//  élève, la moyenne annuelle ET la décision — les deux ensemble, jamais l'une
//  sans l'autre, sinon la décision n'est plus justifiable.
//
//  Le récapitulatif compte les trois verdicts : c'est le chiffre que le chef
//  d'établissement remonte à sa hiérarchie.
// ══════════════════════════════════════════════════════════════════════════════
class PassagePdfService {
  static Future<Uint8List> build({
    required PassageSession session,
    required String className,
    required String yearLabel,
    required String schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    int count(String code) =>
        session.entries.where((e) => e.decision == code).length;

    final doc = pw.Document(
      title: 'PV Passage — $className',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Procès-verbal de passage en classe supérieure',
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

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => ctx.pageNumber == 1
          ? OfficialPdfKit.header(logo, f,
              badge: 'PROCÈS-VERBAL\nPASSAGE EN CLASSE SUPÉRIEURE')
          : pw.SizedBox(),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: kPdfSurface,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: kPdfBorder)),
                  child: pw.Column(children: [
                    pw.Row(children: [
                      infoCell('Établissement', schoolName.isEmpty ? '—' : schoolName),
                      infoCell('Classe', className),
                      infoCell('Année', yearLabel.isEmpty ? '—' : yearLabel),
                      infoCell('Année d\'accueil', session.nextYearLabel ?? '—'),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Row(children: [
                      infoCell('Effectif', '${session.entries.length} élèves'),
                      infoCell('Passent', '${count('passe')}'),
                      infoCell('Redoublent', '${count('redouble')}'),
                      infoCell('Réorientés', '${count('reoriente')}'),
                    ]),
                  ]),
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: const pw.BoxDecoration(color: kPdfNavy),
                  child: pw.Row(children: [
                    th('Rg', align: pw.TextAlign.center, flex: 0.5),
                    th('Élève', flex: 2.4),
                    th('Matricule', flex: 1.2),
                    th('Moy. annuelle', align: pw.TextAlign.center, flex: 1),
                    th('Mention', flex: 1.2),
                    th('Décision du conseil', flex: 2),
                  ]),
                ),
                for (var i = 0; i < session.entries.length; i++)
                  _row(session.entries[i], i, f),
                pw.SizedBox(height: 18),
                pw.Row(children: [
                  pw.Expanded(child: _sign(f, 'Le Chef d\'établissement')),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _sign(f, 'Le Professeur principal')),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _sign(f, 'Le Secrétaire de séance')),
                ]),
              ]),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _row(PassageEntry e, int i, PdfFonts f) {
    // La moyenne imprimée est celle FIGÉE au vote quand elle existe : c'est
    // elle qui a fondé la décision, même si une note a bougé depuis.
    final avg = e.decidedAverage ?? e.annualAverage;
    final v = verdictFor(e.decision);

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

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : kPdfSurface,
          border: const pw.Border(
              bottom: pw.BorderSide(color: kPdfBorder, width: 0.5))),
      child: pw.Row(children: [
        td(e.rank == 0 ? '—' : '${e.rank}', align: pw.TextAlign.center, flex: 0.5),
        td(e.studentName, flex: 2.4, bold: true),
        td(e.matricule ?? '—', flex: 1.2, color: kPdfMuted),
        td(avg == null ? '—' : '${avg.toStringAsFixed(2)}/20',
            align: pw.TextAlign.center, flex: 1, bold: true),
        td(mentionFor(avg), flex: 1.2),
        td(v?.label ?? 'non délibéré',
            flex: 2,
            bold: v != null,
            color: v == null ? kPdfMuted : kPdfNavy),
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
