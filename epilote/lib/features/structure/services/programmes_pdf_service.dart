import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/official_pdf_kit.dart';
import '../providers/programmes_provider.dart';

// Accent par cycle (cohérent avec l'écran Programmes).
const _cycleColorsPdf = <String, PdfColor>{
  'prescolaire': PdfColor.fromInt(0xFFEC4899),
  'primaire': PdfColor.fromInt(0xFF0EA5E9),
  'college': kPdfGreen,
  'lycee': kPdfNavy,
  'formation_pro': PdfColor.fromInt(0xFFF59E0B),
  'fp': PdfColor.fromInt(0xFFF59E0B),
};
const _cycleOrderPdf = <String, int>{
  'prescolaire': 1,
  'primaire': 2,
  'college': 3,
  'lycee': 4,
  'formation_pro': 5,
  'fp': 5,
};
const _cycleNamesPdf = <String, String>{
  'prescolaire': 'Préscolaire',
  'primaire': 'Primaire',
  'college': 'Collège',
  'lycee': 'Lycée',
  'formation_pro': 'Formation Professionnelle',
  'fp': 'Formation Professionnelle',
};

// ══════════════════════════════════════════════════════════════════════════════
//  Service : PROGRAMMES PÉDAGOGIQUES (syllabus) — export officiel par CYCLE puis
//  par NIVEAU. Mise en page = OfficialPdfKit (chrome partagé).
// ══════════════════════════════════════════════════════════════════════════════
class ProgrammesPdfService {
  static Future<Uint8List> buildPdf({
    required List<ProgrammeRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final byCycle = <String, List<ProgrammeRow>>{};
    for (final p in rows) {
      byCycle.putIfAbsent(p.cycleCode ?? 'autre', () => []).add(p);
    }
    final cycleKeys = byCycle.keys.toList()
      ..sort(
          (a, b) => (_cycleOrderPdf[a] ?? 9).compareTo(_cycleOrderPdf[b] ?? 9));

    final official = rows.where((r) => r.isOfficial).length;
    final subjects = rows.map((r) => r.subjectId).toSet().length;
    final levels = rows.map((r) => r.levelId).toSet().length;

    final doc = pw.Document(
      title: 'Programmes pédagogiques',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Programmes pédagogiques (syllabus) par cycle et niveau',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'PROGRAMMES\nPÉDAGOGIQUES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'PROGRAMMES PÉDAGOGIQUES',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Syllabus par cycle et niveau',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Programmes', '${rows.length}', kPdfNavy),
          PdfKpi('Officiels', '$official', kPdfGreen),
          PdfKpi('Personnalisés', '${rows.length - official}', kPdfGold),
          PdfKpi('Matières couvertes', '$subjects', kPdfNavy),
          PdfKpi('Niveaux couverts', '$levels', kPdfGreen),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucun programme à exporter.', f.regular)
        else
          for (final k in cycleKeys) ...[
            _cycleSection(k, byCycle[k]!, f),
            pw.SizedBox(height: 14),
          ],
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  // ── Section d'un cycle ────────────────────────────────────────────────────────
  static pw.Widget _cycleSection(
      String code, List<ProgrammeRow> items, PdfFonts f) {
    final color = _cycleColorsPdf[code] ?? kPdfNavy;
    final name = _cycleNamesPdf[code] ??
        (items.first.cycleName?.trim().isNotEmpty ?? false
            ? items.first.cycleName!.trim()
            : 'Autres');
    final niveaux = items.map((p) => p.levelLabel).toSet().length;

    final sorted = [...items]..sort((a, b) {
        final o = a.levelOrder.compareTo(b.levelOrder);
        return o != 0
            ? o
            : a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
      });
    final byLevel = <String, List<ProgrammeRow>>{};
    for (final p in sorted) {
      byLevel.putIfAbsent(p.levelLabel, () => []).add(p);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                      color: color,
                      borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 8),
              pw.Text(name.toUpperCase(),
                  style: pw.TextStyle(
                      font: f.bold,
                      fontSize: 11.5,
                      color: color,
                      letterSpacing: 0.5)),
              pw.Spacer(),
              pw.Text(
                  '${items.length} programme${items.length > 1 ? 's' : ''} · '
                  '$niveaux niveau${niveaux > 1 ? 'x' : ''}',
                  style: pw.TextStyle(
                      font: f.medium, fontSize: 8.5, color: kPdfMuted)),
            ]),
          ),
          pw.SizedBox(height: 8),
          for (final entry in byLevel.entries) ...[
            _levelGroup(entry.key, entry.value, color, f),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static pw.Widget _levelGroup(
      String levelLabel, List<ProgrammeRow> items, PdfColor color, PdfFonts f) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Container(width: 3, height: 11, color: color),
        pw.SizedBox(width: 6),
        pw.Text(levelLabel.toUpperCase(),
            style: pw.TextStyle(
                font: f.bold, fontSize: 9, color: kPdfText, letterSpacing: 0.5)),
      ]),
      pw.SizedBox(height: 5),
      OfficialPdfKit.table(
        headers: const ['Matière', 'Trimestre', 'Type', 'Titre du programme'],
        rows: items
            .map((p) => [
                  p.subjectName,
                  p.trimesterLabelOrAll,
                  p.isOfficial ? 'Officiel' : 'Personnalisé',
                  p.title,
                ])
            .toList(),
        fonts: f,
        flex: const [3, 2, 2, 5],
        leftAlignCols: const {3},
      ),
    ]);
  }

  // ── Impression / téléchargement ────────────────────────────────────────────
  static Future<void> printDoc({
    required List<ProgrammeRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) =>
          buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel),
      name: 'Programmes_pedagogiques.pdf',
    );
  }

  static Future<String?> downloadDoc({
    required List<ProgrammeRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Programmes_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les programmes',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    if (savePath != null) {
      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
    }
    return savePath;
  }
}
