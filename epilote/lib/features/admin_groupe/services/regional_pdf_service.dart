import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/admin_regional_provider.dart';

// ─── Couleurs PDF ─────────────────────────────────────────────────────────────
const _navy    = PdfColor.fromInt(0xFF1E3A5F);
const _navyL   = PdfColor.fromInt(0xFF2A4E7A);
const _green   = PdfColor.fromInt(0xFF009A44);
const _gold    = PdfColor.fromInt(0xFFFBBC04);
const _red     = PdfColor.fromInt(0xFFDC143C);
const _orange  = PdfColor.fromInt(0xFFFF6B35);
const _purple  = PdfColor.fromInt(0xFF7C3AED);
const _blue    = PdfColor.fromInt(0xFF0EA5E9);
const _muted   = PdfColor.fromInt(0xFF64748B);
const _border  = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text    = PdfColor.fromInt(0xFF0F172A);

// ─── Service : rapport territorial officiel ──────────────────────────────────
//
// Génère le PDF officiel de la vue régionale (synthèse + répartition par
// département + établissements géolocalisés + projets + qualité des données).
// Style aligné sur les autres documents officiels (subscription_pdf_service) :
// bandeau tricolore, emblème, en-tête « RÉPUBLIQUE DU CONGO », pied paginé.

class RegionalPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required AdminRegionalData data,
    required List<AdminProjectPin> projects,
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();
    final fontMedium  = await PdfGoogleFonts.notoSansMedium();

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now      = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_     = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    // 15 départements officiels (réforme oct. 2024) — source unique partagée.
    final officialDepts = adminMajorAgglomerations.keys.toList();
    final coveredNorm = <String>{
      ...data.allDepts.map((d) => _norm(d.dept)),
      ...data.gpsSchools
          .map((s) => s.department)
          .whereType<String>()
          .map(_norm),
    };
    final nonCovered = officialDepts
        .where((d) => !coveredNorm.contains(_norm(d)))
        .toList();

    final budgetTotal = projects.fold<int>(0, (a, p) => a + (p.budgetXaf ?? 0));
    final beneficiaries =
        projects.fold<int>(0, (a, p) => a + (p.beneficiariesEst ?? 0));

    final doc = pw.Document(
      title: 'Rapport territorial — $groupName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Rapport territorial régional',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _titleBlock(groupName, fmtDateL.format(DateTime.now()),
            fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 16),
        _kpiGrid(data, projects.length, fontBold, fontRegular),
        pw.SizedBox(height: 16),
        _deptSection(data, fontBold, fontMedium, fontRegular),
        if (data.gpsSchools.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _gpsSection(data, fontBold, fontMedium, fontRegular),
        ],
        if (projects.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _projectsSection(projects, budgetTotal, beneficiaries,
              fontBold, fontMedium, fontRegular),
        ],
        pw.SizedBox(height: 14),
        _dataQualitySection(data, nonCovered, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  // ── En-tête officiel ───────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    pw.ImageProvider? logoImage,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 5, color: _green)),
        pw.Expanded(child: pw.Container(height: 5, color: _gold)),
        pw.Expanded(child: pw.Container(height: 5, color: _red)),
      ]),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
        color: PdfColors.white,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            logoImage != null
                ? pw.SizedBox(width: 54, height: 54, child: pw.Image(logoImage))
                : pw.Container(
                    width: 50, height: 50,
                    decoration: pw.BoxDecoration(
                      color: _navy, borderRadius: pw.BorderRadius.circular(10)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('EP',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 18, color: PdfColors.white)),
                  ),
            pw.SizedBox(width: 14),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉPUBLIQUE DU CONGO',
                    style: pw.TextStyle(
                        font: fontMedium, fontSize: 7.5,
                        color: _muted, letterSpacing: 1.5)),
                pw.SizedBox(height: 2),
                pw.Text('E-PILOTE CONGO',
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: _navy)),
                pw.Text('Plateforme Nationale de Gestion Scolaire',
                    style: pw.TextStyle(font: fontRegular, fontSize: 9, color: _muted)),
              ],
            )),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: _surface,
                    border: pw.Border.all(color: _border, width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text('RAPPORT\nTERRITORIAL',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 8,
                          color: _navy, letterSpacing: 0.8)),
                ),
              ],
            ),
          ],
        ),
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

  static pw.Widget _buildFooter(
    pw.Context ctx,
    pw.Font fontRegular,
    pw.Font fontMedium,
    String now,
    String ref_,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(
          'Document officiel généré le $now  •  E-PILOTE CONGO  •  Réf. $ref_',
          style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: _muted),
        )),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: _navy, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: fontMedium, fontSize: 7.5, color: PdfColors.white)),
        ),
      ]),
    );
  }

  // ── Bloc titre ───────────────────────────────────────────────────────────────
  static pw.Widget _titleBlock(
    String groupName,
    String dateLong,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RAPPORT TERRITORIAL RÉGIONAL',
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: _text)),
          pw.SizedBox(height: 4),
          pw.Text(groupName.toUpperCase(),
              style: pw.TextStyle(font: fontMedium, fontSize: 12, color: _navy)),
          pw.SizedBox(height: 6),
          pw.Text('Situation arrêtée au $dateLong',
              style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: _muted)),
          pw.SizedBox(height: 12),
          pw.Divider(color: _border, thickness: 0.8),
        ],
      ),
    );
  }

  // ── Synthèse KPI ─────────────────────────────────────────────────────────────
  static pw.Widget _kpiGrid(
    AdminRegionalData data,
    int projectCount,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    final cells = <List<dynamic>>[
      ['${data.totalSchools}', 'Établissements', _navy],
      ['${data.totalStudents}', 'Élèves actifs', _green],
      ['${data.activeSchools}', 'Écoles actives', _blue],
      ['${data.coveredDepts} / 15', 'Départements couverts', _gold],
      ['${data.gpsCount}', 'Géolocalisées', _purple],
      ['$projectCount', 'Projets scolaires', _orange],
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Wrap(
        spacing: 10, runSpacing: 10,
        children: cells.map((c) {
          final color = c[2] as PdfColor;
          return pw.Container(
            width: 165,
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: pw.BoxDecoration(
              color: _alpha(color, 0.06),
              border: pw.Border.all(color: _alpha(color, 0.25), width: 0.8),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(c[0] as String,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 20, color: color)),
                pw.SizedBox(height: 2),
                pw.Text(c[1] as String,
                    style: pw.TextStyle(
                        font: fontRegular, fontSize: 9, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Répartition par département ───────────────────────────────────────────────
  static pw.Widget _deptSection(
    AdminRegionalData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final rows = data.allDepts.map((d) {
      final rate =
          d.schoolCount > 0 ? (d.activeCount / d.schoolCount * 100).round() : 0;
      return [
        d.dept,
        '${d.schoolCount}',
        '${d.studentCount}',
        '${d.activeCount}',
        '$rate %',
      ];
    }).toList();

    return _sectionFrame(
      title: 'RÉPARTITION PAR DÉPARTEMENT',
      color: _navy,
      fontBold: fontBold,
      child: rows.isEmpty
          ? _emptyNote('Aucune école rattachée à un département.', fontRegular)
          : pw.TableHelper.fromTextArray(
              headers: const [
                'Département', 'Écoles', 'Élèves', 'Actives', 'Taux'
              ],
              data: rows,
              border: null,
              headerStyle: pw.TextStyle(
                  font: fontBold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: pw.TextStyle(
                  font: fontRegular, fontSize: 9, color: _text),
              cellHeight: 20,
              oddRowDecoration: const pw.BoxDecoration(color: _surface),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.3),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.2),
              },
            ),
    );
  }

  // ── Établissements géolocalisés ───────────────────────────────────────────────
  static pw.Widget _gpsSection(
    AdminRegionalData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final rows = data.gpsSchools.map((s) {
      return [
        s.name,
        _typeLabel(s.type),
        s.department ?? '—',
        '${s.students}',
        _sourceLabel(s.locationSource),
      ];
    }).toList();

    return _sectionFrame(
      title: 'ÉTABLISSEMENTS GÉOLOCALISÉS (${data.gpsCount})',
      color: _purple,
      fontBold: fontBold,
      child: pw.TableHelper.fromTextArray(
        headers: const ['Établissement', 'Type', 'Département', 'Élèves', 'Source'],
        data: rows,
        border: null,
        headerStyle: pw.TextStyle(
            font: fontBold, fontSize: 8.5, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _purple),
        cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9, color: _text),
        cellHeight: 20,
        oddRowDecoration: const pw.BoxDecoration(color: _surface),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
        },
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1.2),
        },
      ),
    );
  }

  // ── Projets scolaires ─────────────────────────────────────────────────────────
  static pw.Widget _projectsSection(
    List<AdminProjectPin> projects,
    int budgetTotal,
    int beneficiaries,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final rows = projects.map((p) {
      return [
        p.name,
        _projectStatusLabel(p.status),
        p.department ?? p.city ?? '—',
        p.budgetXaf != null ? '${_money(p.budgetXaf!)} F' : '—',
        p.beneficiariesEst != null ? '${p.beneficiariesEst}' : '—',
      ];
    }).toList();

    return _sectionFrame(
      title: 'PROJETS SCOLAIRES (${projects.length})',
      color: _orange,
      fontBold: fontBold,
      footer: 'Budget cumulé : ${_money(budgetTotal)} FCFA'
          '   •   Bénéficiaires estimés : $beneficiaries',
      fontFooter: fontMedium,
      child: pw.TableHelper.fromTextArray(
        headers: const ['Projet', 'Statut', 'Localisation', 'Budget', 'Bénéf.'],
        data: rows,
        border: null,
        headerStyle: pw.TextStyle(
            font: fontBold, fontSize: 8.5, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _orange),
        cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9, color: _text),
        cellHeight: 20,
        oddRowDecoration: const pw.BoxDecoration(color: _surface),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.center,
        },
        columnWidths: {
          0: const pw.FlexColumnWidth(2.6),
          1: const pw.FlexColumnWidth(1.4),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(1.6),
          4: const pw.FlexColumnWidth(1),
        },
      ),
    );
  }

  // ── Qualité des données ───────────────────────────────────────────────────────
  static pw.Widget _dataQualitySection(
    AdminRegionalData data,
    List<String> nonCovered,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final gpsPct = data.totalSchools > 0
        ? (data.gpsCount / data.totalSchools * 100).round()
        : 0;
    final items = <pw.Widget>[
      _qualityLine(
        'Écoles sans coordonnées GPS',
        '${data.noGpsCount} / ${data.totalSchools}',
        data.noGpsCount == 0 ? _green : _orange,
        fontMedium, fontRegular,
      ),
      _qualityLine(
        'Taux de géolocalisation',
        '$gpsPct %',
        gpsPct >= 80 ? _green : (gpsPct >= 40 ? _orange : _red),
        fontMedium, fontRegular,
      ),
      _qualityLine(
        'Départements sans établissement',
        nonCovered.isEmpty ? 'Aucun — couverture complète' : '${nonCovered.length}',
        nonCovered.isEmpty ? _green : _muted,
        fontMedium, fontRegular,
      ),
    ];

    return _sectionFrame(
      title: 'QUALITÉ DES DONNÉES',
      color: _green,
      fontBold: fontBold,
      child: pw.Column(children: [
        ...items,
        if (nonCovered.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
                'Départements non couverts : ${nonCovered.join(', ')}',
                style: pw.TextStyle(
                    font: fontRegular, fontSize: 8.5, color: _muted)),
          ),
        ],
      ]),
    );
  }

  static pw.Widget _qualityLine(
    String label,
    String value,
    PdfColor color,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(children: [
        pw.Container(width: 7, height: 7,
            decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(label,
            style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: _text))),
        pw.Text(value,
            style: pw.TextStyle(font: fontMedium, fontSize: 9.5, color: color)),
      ]),
    );
  }

  // ── Cadre de section réutilisable ─────────────────────────────────────────────
  static pw.Widget _sectionFrame({
    required String title,
    required PdfColor color,
    required pw.Font fontBold,
    required pw.Widget child,
    String? footer,
    pw.Font? fontFooter,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: pw.Row(children: [
              pw.Container(width: 4, height: 13,
                  decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 7),
              pw.Text(title,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 11,
                      color: _text, letterSpacing: 0.5)),
            ]),
          ),
          child,
          if (footer != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(footer,
                style: pw.TextStyle(
                    font: fontFooter ?? fontBold, fontSize: 9, color: _muted)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _emptyNote(String text, pw.Font font) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _surface, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
      );

  // ── Impression / téléchargement ────────────────────────────────────────────
  static Future<void> printReport({
    required String groupName,
    required AdminRegionalData data,
    required List<AdminProjectPin> projects,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) =>
          buildPdf(groupName: groupName, data: data, projects: projects),
      name: 'Rapport_territorial_${_slug(groupName)}.pdf',
    );
  }

  static Future<String?> downloadReport({
    required String groupName,
    required AdminRegionalData data,
    required List<AdminProjectPin> projects,
  }) async {
    final bytes =
        await buildPdf(groupName: groupName, data: data, projects: projects);
    final fileName = 'Rapport_territorial_${_slug(groupName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport territorial',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (savePath != null) {
        final f = File(savePath);
        if (!await f.exists() || await f.length() == 0) {
          await f.writeAsBytes(bytes);
        }
        return savePath;
      }
    } catch (_) {}

    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<Uint8List?> _rasterizeSvg(String assetPath, double size) async {
  try {
    final raw = await rootBundle.loadString(assetPath);
    final info = await vg.loadPicture(SvgStringLoader(raw), null);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final scale = size / info.size.width;
    canvas.scale(scale);
    canvas.drawPicture(info.picture);
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    info.picture.dispose();
    image.dispose();
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

PdfColor _alpha(PdfColor c, double a) => PdfColor(c.red, c.green, c.blue, a);

String _money(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

String _slug(String s) => s.replaceAll(RegExp(r'[^\w]+'), '_');

// Normalisation accent-insensible pour comparer les noms de départements
// (la colonne `department` en base peut différer de l'orthographe officielle).
String _norm(String s) {
  var r = s.toLowerCase().trim();
  const map = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };
  map.forEach((k, v) => r = r.replaceAll(k, v));
  return r;
}

String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive'  => 'Privé',
      _        => t,
    };

String _projectStatusLabel(String s) => switch (s) {
      'etude'         => 'Étude',
      'validation'    => 'Validation',
      'budgetisation' => 'Budgétisation',
      'construction'  => 'Construction',
      'acheve'        => 'Achevé',
      _               => s,
    };

String _sourceLabel(String? s) => switch (s) {
      'gps'      => 'GPS terrain',
      'geocoded' => 'Géocodé',
      'manual'   => 'Manuel',
      _          => 'Inconnue',
    };
