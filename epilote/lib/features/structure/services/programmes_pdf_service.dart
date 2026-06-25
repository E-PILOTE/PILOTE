import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/programmes_provider.dart';

// ─── Couleurs PDF (alignées sur les autres documents officiels) ───────────────
const _navy = PdfColor.fromInt(0xFF1E3A5F);
const _navyL = PdfColor.fromInt(0xFF2A4E7A);
const _green = PdfColor.fromInt(0xFF009A44);
const _gold = PdfColor.fromInt(0xFFFBBC04);
const _red = PdfColor.fromInt(0xFFDC143C);
const _muted = PdfColor.fromInt(0xFF64748B);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text = PdfColor.fromInt(0xFF0F172A);

// Accent par cycle (cohérent avec l'écran Programmes).
const _cycleColorsPdf = <String, PdfColor>{
  'prescolaire': PdfColor.fromInt(0xFFEC4899),
  'primaire': PdfColor.fromInt(0xFF0EA5E9),
  'college': _green,
  'lycee': _navy,
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
//  par NIVEAU. Style officiel : bandeau tricolore, emblème, en-tête
//  « RÉPUBLIQUE DU CONGO ». Réutilise la matière CANONIQUE + la structure.
// ══════════════════════════════════════════════════════════════════════════════
class ProgrammesPdfService {
  static Future<Uint8List> buildPdf({
    required List<ProgrammeRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontMedium = await PdfGoogleFonts.notoSansMedium();

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_ = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    // Regroupement par cycle (ordre pédagogique).
    final byCycle = <String, List<ProgrammeRow>>{};
    for (final p in rows) {
      byCycle.putIfAbsent(p.cycleCode ?? 'autre', () => []).add(p);
    }
    final cycleKeys = byCycle.keys.toList()
      ..sort((a, b) => (_cycleOrderPdf[a] ?? 9).compareTo(_cycleOrderPdf[b] ?? 9));

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
      header: (ctx) => _header(logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _footer(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _titleBlock(schoolName, yearLabel, genDate, fontBold, fontMedium,
            fontRegular),
        pw.SizedBox(height: 16),
        _kpiGrid(rows.length, official, rows.length - official, subjects,
            levels, fontBold, fontRegular),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          _empty('Aucun programme à exporter.', fontRegular)
        else
          for (final k in cycleKeys) ...[
            _cycleSection(k, byCycle[k]!, fontBold, fontMedium, fontRegular),
            pw.SizedBox(height: 14),
          ],
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  // ── En-tête officiel ───────────────────────────────────────────────────────
  static pw.Widget _header(
      pw.ImageProvider? logo, pw.Font bold, pw.Font medium, pw.Font regular) {
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 5, color: _green)),
        pw.Expanded(child: pw.Container(height: 5, color: _gold)),
        pw.Expanded(child: pw.Container(height: 5, color: _red)),
      ]),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
        color: PdfColors.white,
        child: pw.Row(children: [
          logo != null
              ? pw.SizedBox(width: 54, height: 54, child: pw.Image(logo))
              : pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                      color: _navy,
                      borderRadius: pw.BorderRadius.circular(10)),
                  alignment: pw.Alignment.center,
                  child: pw.Text('EP',
                      style: pw.TextStyle(
                          font: bold, fontSize: 18, color: PdfColors.white)),
                ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉPUBLIQUE DU CONGO',
                    style: pw.TextStyle(
                        font: medium,
                        fontSize: 7.5,
                        color: _muted,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 2),
                pw.Text('E-PILOTE CONGO',
                    style:
                        pw.TextStyle(font: bold, fontSize: 16, color: _navy)),
                pw.Text('Plateforme Nationale de Gestion Scolaire',
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: _muted)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _surface,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('PROGRAMMES\nPÉDAGOGIQUES',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: bold, fontSize: 8, color: _navy, letterSpacing: 0.8)),
          ),
        ]),
      ),
      pw.Container(
        height: 2,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navyL, PdfColors.white]),
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _footer(pw.Context ctx, pw.Font regular, pw.Font medium,
      String now, String ref_) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text(
            'Document officiel généré le $now  •  E-PILOTE CONGO  •  Réf. $ref_',
            style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
              color: _navy, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: medium, fontSize: 7.5, color: PdfColors.white)),
        ),
      ]),
    );
  }

  // ── Bloc titre ───────────────────────────────────────────────────────────────
  static pw.Widget _titleBlock(String? schoolName, String? yearLabel,
      String genDate, pw.Font bold, pw.Font medium, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PROGRAMMES PÉDAGOGIQUES',
                style: pw.TextStyle(
                    font: medium, fontSize: 8, color: _muted, letterSpacing: 1)),
            pw.SizedBox(height: 3),
            pw.Text(
                schoolName?.trim().isNotEmpty ?? false
                    ? schoolName!.trim()
                    : 'Syllabus par cycle et niveau',
                style: pw.TextStyle(font: bold, fontSize: 18, color: _navy)),
            pw.SizedBox(height: 4),
            if (yearLabel?.trim().isNotEmpty ?? false)
              pw.Text('Année scolaire : ${yearLabel!.trim()}',
                  style:
                      pw.TextStyle(font: regular, fontSize: 9.5, color: _text)),
            pw.Text('Édité le $genDate',
                style: pw.TextStyle(font: regular, fontSize: 8.5, color: _muted)),
          ],
        ),
      ),
    );
  }

  // ── Grille KPI ─────────────────────────────────────────────────────────────
  static pw.Widget _kpiGrid(int total, int official, int custom, int subjects,
      int levels, pw.Font bold, pw.Font regular) {
    final cells = <List<dynamic>>[
      ['Programmes', '$total', _navy],
      ['Officiels', '$official', _green],
      ['Personnalisés', '$custom', _gold],
      ['Matières couvertes', '$subjects', _navy],
      ['Niveaux couverts', '$levels', _green],
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cells.map((c) {
          return pw.Container(
            width: 100,
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 22, height: 3, color: c[2] as PdfColor),
                pw.SizedBox(height: 8),
                pw.Text(c[1] as String,
                    style: pw.TextStyle(
                        font: bold, fontSize: 18, color: c[2] as PdfColor)),
                pw.SizedBox(height: 2),
                pw.Text(c[0] as String,
                    style: pw.TextStyle(
                        font: regular, fontSize: 8, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section d'un cycle ────────────────────────────────────────────────────────
  static pw.Widget _cycleSection(String code, List<ProgrammeRow> items,
      pw.Font bold, pw.Font medium, pw.Font regular) {
    final color = _cycleColorsPdf[code] ?? _navy;
    final name = _cycleNamesPdf[code] ??
        (items.first.cycleName?.trim().isNotEmpty ?? false
            ? items.first.cycleName!.trim()
            : 'Autres');
    final niveaux = items.map((p) => p.levelLabel).toSet().length;

    // Tri pédagogique (niveau puis matière), puis regroupement par niveau.
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
          // En-tête de cycle.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColor(color.red, color.green, color.blue, 0.10),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: PdfColor(color.red, color.green, color.blue, 0.35)),
            ),
            child: pw.Row(children: [
              pw.Container(
                  width: 4,
                  height: 14,
                  decoration: pw.BoxDecoration(
                      color: color, borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 8),
              pw.Text(name.toUpperCase(),
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 11.5,
                      color: color,
                      letterSpacing: 0.5)),
              pw.Spacer(),
              pw.Text(
                  '${items.length} programme${items.length > 1 ? 's' : ''} · '
                  '$niveaux niveau${niveaux > 1 ? 'x' : ''}',
                  style: pw.TextStyle(font: medium, fontSize: 8.5, color: _muted)),
            ]),
          ),
          pw.SizedBox(height: 8),
          for (final entry in byLevel.entries) ...[
            _levelGroup(entry.key, entry.value, color, bold, medium, regular),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Sous-groupe par niveau ────────────────────────────────────────────────────
  static pw.Widget _levelGroup(String levelLabel, List<ProgrammeRow> items,
      PdfColor color, pw.Font bold, pw.Font medium, pw.Font regular) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Container(width: 3, height: 11, color: color),
        pw.SizedBox(width: 6),
        pw.Text(levelLabel.toUpperCase(),
            style: pw.TextStyle(
                font: bold, fontSize: 9, color: _text, letterSpacing: 0.5)),
      ]),
      pw.SizedBox(height: 5),
      _table(
        headers: const ['Matière', 'Trimestre', 'Type', 'Titre du programme'],
        rows: items
            .map((p) => [
                  p.subjectName,
                  p.trimesterLabelOrAll,
                  p.isOfficial ? 'Officiel' : 'Personnalisé',
                  p.title,
                ])
            .toList(),
        bold: bold,
        medium: medium,
        regular: regular,
        flex: const [3, 2, 2, 5],
      ),
    ]);
  }

  // ── Helpers de mise en page ──────────────────────────────────────────────────
  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> flex,
    required pw.Font bold,
    required pw.Font medium,
    required pw.Font regular,
  }) {
    pw.Widget cell(String t, int f, pw.Font font,
        {PdfColor color = _text, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Expanded(
        flex: f,
        child: pw.Text(t,
            textAlign: align,
            style: pw.TextStyle(font: font, fontSize: 8.5, color: color)),
      );
    }

    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
            color: _surface, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
          children: List.generate(headers.length, (i) {
            return cell(headers[i].toUpperCase(), flex[i], medium,
                color: _muted,
                align: i == 0 || i == headers.length - 1
                    ? pw.TextAlign.left
                    : pw.TextAlign.center);
          }),
        ),
      ),
      ...rows.map((r) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6)),
            ),
            child: pw.Row(
              children: List.generate(r.length, (i) {
                return cell(r[i], flex[i], i == 0 ? medium : regular,
                    color: i == 0 ? _text : _muted,
                    align: i == 0 || i == r.length - 1
                        ? pw.TextAlign.left
                        : pw.TextAlign.center);
              }),
            ),
          )),
    ]);
  }

  static pw.Widget _empty(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: _surface, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
        ),
      );

  static Future<Uint8List?> _rasterizeSvg(String asset, double size) async {
    try {
      final raw = await rootBundle.loadString(asset);
      final info = await vg.loadPicture(SvgStringLoader(raw), null);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(size / info.size.width);
      canvas.drawPicture(info.picture);
      final image =
          await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      info.picture.dispose();
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
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
      final f = File(savePath);
      if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
    }
    return savePath;
  }
}
