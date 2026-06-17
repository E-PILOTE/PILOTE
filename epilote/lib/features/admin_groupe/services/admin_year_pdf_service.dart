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

import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_year_analytics_provider.dart';

// ─── Couleurs PDF (alignées sur les autres documents officiels) ───────────────
const _navy = PdfColor.fromInt(0xFF1E3A5F);
const _navyL = PdfColor.fromInt(0xFF2A4E7A);
const _green = PdfColor.fromInt(0xFF009A44);
const _gold = PdfColor.fromInt(0xFFFBBC04);
const _red = PdfColor.fromInt(0xFFDC143C);
const _purple = PdfColor.fromInt(0xFF7C3AED);
const _muted = PdfColor.fromInt(0xFF64748B);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text = PdfColor.fromInt(0xFF0F172A);

// ══════════════════════════════════════════════════════════════════════════════
//  Service : BILAN OFFICIEL d'une année scolaire (groupe).
//  Synthèse + évolution pluriannuelle + ventilations département / type / école.
//  Style officiel : bandeau tricolore, emblème, en-tête « RÉPUBLIQUE DU CONGO ».
// ══════════════════════════════════════════════════════════════════════════════
class AcademicYearPdfService {
  static Future<Uint8List> buildPdf({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontMedium = await PdfGoogleFonts.notoSansMedium();

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_ = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final range =
        '${fmtDateL.format(year.startDate)} → ${fmtDateL.format(year.endDate)}';

    final doc = pw.Document(
      title: 'Bilan ${year.label}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: "Bilan de l'année scolaire ${year.label}",
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          _header(logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _footer(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _titleBlock(year, range, fmtDateL.format(DateTime.now()), fontBold,
            fontMedium, fontRegular),
        pw.SizedBox(height: 16),
        _kpiGrid(year, analytics, fontBold, fontRegular),
        pw.SizedBox(height: 16),
        _evolutionSection(allYears, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _deptSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _typeSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _schoolsSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  // ── En-tête officiel ───────────────────────────────────────────────────────
  static pw.Widget _header(pw.ImageProvider? logo, pw.Font bold, pw.Font medium,
      pw.Font regular) {
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
            child: pw.Text('BILAN\nANNÉE SCOLAIRE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: _navy,
                    letterSpacing: 0.8)),
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
  static pw.Widget _titleBlock(AdminYear year, String range, String genDate,
      pw.Font bold, pw.Font medium, pw.Font regular) {
    final status = year.isLocked
        ? 'Archivée'
        : year.isCurrent
            ? 'En cours'
            : year.startDate.isAfter(DateTime.now())
                ? 'À venir'
                : 'Passée';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("BILAN DE L'ANNÉE SCOLAIRE",
                      style: pw.TextStyle(
                          font: medium,
                          fontSize: 8,
                          color: _muted,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 3),
                  pw.Text(year.label,
                      style: pw.TextStyle(
                          font: bold, fontSize: 20, color: _navy)),
                  pw.SizedBox(height: 4),
                  pw.Text('Période : $range',
                      style: pw.TextStyle(
                          font: regular, fontSize: 9.5, color: _text)),
                  pw.Text('Édité le $genDate',
                      style: pw.TextStyle(
                          font: regular, fontSize: 8.5, color: _muted)),
                ],
              ),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                  color: _navy, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text(status,
                  style: pw.TextStyle(
                      font: bold, fontSize: 9, color: PdfColors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grille KPI ─────────────────────────────────────────────────────────────
  static pw.Widget _kpiGrid(AdminYear year, AdminYearAnalytics a, pw.Font bold,
      pw.Font regular) {
    final adopt = year.schoolsTotal == 0
        ? 0
        : (year.schoolsAdopted / year.schoolsTotal * 100).round();
    final cells = <List<dynamic>>[
      ['Élèves inscrits', '${a.eleves}', _green],
      ['Classes ouvertes', '${a.classes}', _navy],
      ['Écoles préparées', '${year.schoolsAdopted}/${year.schoolsTotal}', _gold],
      ["Taux d'adoption", '$adopt %', _navy],
      ['Départements couverts', '${a.departementsCouverts}', _purple],
      [
        'Moy. élèves / classe',
        a.moyenneElevesParClasse.toStringAsFixed(1),
        _green
      ],
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cells.map((c) {
          return pw.Container(
            width: 167,
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
                        font: regular, fontSize: 8.5, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Évolution pluriannuelle ──────────────────────────────────────────────────
  static pw.Widget _evolutionSection(
      List<AdminYear> years, pw.Font bold, pw.Font medium, pw.Font regular) {
    final chrono = years.reversed.toList();
    return _frame(
      title: 'ÉVOLUTION PLURIANNUELLE',
      color: _navy,
      bold: bold,
      child: _table(
        headers: const ['Année', 'Élèves', 'Classes', 'Écoles préparées'],
        rows: chrono
            .map((y) => [
                  y.label,
                  '${y.eleves}',
                  '${y.classes}',
                  '${y.schoolsAdopted}/${y.schoolsTotal}',
                ])
            .toList(),
        bold: bold,
        medium: medium,
        regular: regular,
        flex: const [3, 2, 2, 3],
      ),
    );
  }

  // ── Répartition par département ──────────────────────────────────────────────
  static pw.Widget _deptSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    return _frame(
      title: 'RÉPARTITION PAR DÉPARTEMENT',
      color: _green,
      bold: bold,
      child: a.byDepartment.isEmpty
          ? _empty('Aucune donnée par département.', regular)
          : _table(
              headers: const [
                'Département',
                'Écoles préparées',
                'Classes',
                'Élèves'
              ],
              rows: a.byDepartment
                  .map((d) => [
                        d.department,
                        '${d.ecolesPreparees}/${d.ecoles}',
                        '${d.classes}',
                        '${d.eleves}',
                      ])
                  .toList(),
              bold: bold,
              medium: medium,
              regular: regular,
              flex: const [4, 3, 2, 2],
            ),
    );
  }

  // ── Type d'établissement ─────────────────────────────────────────────────────
  static pw.Widget _typeSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    String label(String t) => switch (t) {
          'public' => 'Public',
          'prive' => 'Privé',
          'mixte' => 'Mixte',
          _ => t.isEmpty ? 'Autre' : t,
        };
    return _frame(
      title: "TYPE D'ÉTABLISSEMENT",
      color: _gold,
      bold: bold,
      child: a.byType.isEmpty
          ? _empty('Aucune donnée par type.', regular)
          : _table(
              headers: const ['Type', 'Écoles', 'Classes', 'Élèves'],
              rows: a.byType
                  .map((t) => [
                        label(t.type),
                        '${t.ecoles}',
                        '${t.classes}',
                        '${t.eleves}',
                      ])
                  .toList(),
              bold: bold,
              medium: medium,
              regular: regular,
              flex: const [4, 2, 2, 2],
            ),
    );
  }

  // ── Préparation par école ────────────────────────────────────────────────────
  static pw.Widget _schoolsSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    return _frame(
      title: 'PRÉPARATION PAR ÉTABLISSEMENT',
      color: _purple,
      bold: bold,
      child: a.bySchool.isEmpty
          ? _empty('Aucune école active.', regular)
          : _table(
              headers: const [
                'Établissement',
                'Département',
                'Classes',
                'Élèves',
                'État'
              ],
              rows: a.bySchool
                  .map((s) => [
                        s.name,
                        s.department,
                        '${s.classes}',
                        '${s.eleves}',
                        s.adopted ? 'Préparée' : 'En attente',
                      ])
                  .toList(),
              bold: bold,
              medium: medium,
              regular: regular,
              flex: const [5, 4, 2, 2, 3],
            ),
    );
  }

  // ── Helpers de mise en page ──────────────────────────────────────────────────
  static pw.Widget _frame({
    required String title,
    required PdfColor color,
    required pw.Font bold,
    required pw.Widget child,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: pw.Row(children: [
              pw.Container(
                  width: 4,
                  height: 13,
                  decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 7),
              pw.Text(title,
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 11,
                      color: _text,
                      letterSpacing: 0.5)),
            ]),
          ),
          child,
        ],
      ),
    );
  }

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
                align: i == 0 ? pw.TextAlign.left : pw.TextAlign.center);
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
                    align: i == 0 ? pw.TextAlign.left : pw.TextAlign.center);
              }),
            ),
          )),
    ]);
  }

  static pw.Widget _empty(String text, pw.Font font) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _surface, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
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

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ── Impression / téléchargement ────────────────────────────────────────────
  static Future<void> printReport({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) =>
          buildPdf(year: year, analytics: analytics, allYears: allYears),
      name: 'Bilan_${_slug(year.label)}.pdf',
    );
  }

  static Future<String?> downloadReport({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    final bytes =
        await buildPdf(year: year, analytics: analytics, allYears: allYears);
    final fileName = 'Bilan_${_slug(year.label)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Enregistrer le bilan de l'année",
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
