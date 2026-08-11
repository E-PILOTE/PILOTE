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

import '../../../core/services/official_pdf_kit.dart';

import '../providers/admin_reports_provider.dart';

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

// ─── Service : rapport de synthèse officiel ──────────────────────────────────
//
// Génère le PDF officiel des rapports du groupe (synthèse, effectifs, finance,
// répartition par établissement, ressources humaines). Le document reflète la
// PÉRIODE et l'ÉTABLISSEMENT sélectionnés dans l'écran Rapports. Style aligné
// sur les autres documents officiels (regional_pdf_service /
// subscription_pdf_service) : bandeau tricolore, emblème, en-tête « RÉPUBLIQUE
// DU CONGO », pied paginé.

class ReportsPdfService {
  static Future<Uint8List> buildPdf({required ReportData data}) async {
    // Polices EMBARQUÉES (assets/fonts) — cf. OfficialPdfKit.loadFonts().
    // `PdfGoogleFonts` allait les chercher sur fonts.gstatic.com et, en cas
    // d'échec, retombait SANS BRUIT sur Helvetica : sur un poste hors ligne —
    // le cas normal d'une école congolaise — le document officiel sortait dans
    // une police de secours sans Unicode, et nul ne le voyait avant impression.
    final polices = await OfficialPdfKit.loadFonts();
    final fontRegular = polices.regular;
    final fontBold = polices.bold;
    final fontMedium = polices.medium;

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now      = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_     = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final periodRange =
        '${fmtDateL.format(data.periodStart)} au ${fmtDateL.format(data.periodEnd)}';

    final doc = pw.Document(
      title: 'Rapport — ${data.groupName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Rapport de synthèse du groupe scolaire',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _titleBlock(data, periodRange, fmtDateL.format(DateTime.now()),
            fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 16),
        _kpiGrid(data, fontBold, fontRegular),
        pw.SizedBox(height: 16),
        _structureSection(data, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _financeSection(data, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _hrSection(data, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _schoolsSection(data, fontBold, fontMedium, fontRegular),
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
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _border, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text('RAPPORT\nANALYTIQUE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 8,
                      color: _navy, letterSpacing: 0.8)),
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
    ReportData data,
    String periodRange,
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
          pw.Text('RAPPORT ANALYTIQUE',
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: _text)),
          pw.SizedBox(height: 4),
          pw.Text(data.groupName.toUpperCase(),
              style: pw.TextStyle(font: fontMedium, fontSize: 12, color: _navy)),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            children: [
              pw.Text('Édité le $dateLong',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: _muted)),
              _chip('Période : ${data.periodLabel}', fontMedium),
              _chip(periodRange, fontMedium),
              _chip('Périmètre : ${data.scopeLabel}', fontMedium),
              _chip('Plan ${data.planName}', fontMedium),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: _border, thickness: 0.8),
        ],
      ),
    );
  }

  static pw.Widget _chip(String text, pw.Font font) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _surface,
          border: pw.Border.all(color: _border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 8.5, color: _navy)),
      );

  // ── Synthèse KPI ─────────────────────────────────────────────────────────────
  static pw.Widget _kpiGrid(
    ReportData data,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    final cells = <List<dynamic>>[
      ['${data.schoolsTotal}', 'Établissements', _navy],
      [_money(data.elevesTotal), 'Élèves', _green],
      [_money(data.personnelTotal), 'Personnel', _blue],
      ['${data.classesTotal}', 'Classes', _purple],
      [_money(data.elevesNouveaux), 'Nouv. inscrits (période)', _gold],
      ['${data.tauxPaiement.toStringAsFixed(0)} %', 'Taux recouvrement', _orange],
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
                    style: pw.TextStyle(font: fontBold, fontSize: 20, color: color)),
                pw.SizedBox(height: 2),
                pw.Text(c[1] as String,
                    style: pw.TextStyle(font: fontRegular, fontSize: 9, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Structure & effectifs ─────────────────────────────────────────────────────
  static pw.Widget _structureSection(
    ReportData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final eleves = data.elevesTotal;
    final pctG = eleves > 0 ? (data.studentsM * 100 / eleves).round() : 0;
    final pctF = eleves > 0 ? (data.studentsF * 100 / eleves).round() : 0;
    return _sectionFrame(
      title: 'STRUCTURE & EFFECTIFS',
      color: _blue,
      fontBold: fontBold,
      footer: 'Encadrement : 1 agent pour '
          '${data.ratioEncadrement.toStringAsFixed(1)} élève(s)  •  '
          '${data.coveredDepts} département(s) couvert(s)',
      fontFooter: fontMedium,
      child: pw.Column(children: [
        _statLine('Établissements publics', '${data.publicCount}', _navy,
            fontMedium, fontRegular),
        _statLine('Établissements privés', '${data.priveCount}', _navy,
            fontMedium, fontRegular),
        pw.Divider(color: _border, thickness: 0.5),
        _statLine('Élèves — garçons', '${_money(data.studentsM)}  ($pctG %)', _blue,
            fontMedium, fontRegular),
        _statLine('Élèves — filles', '${_money(data.studentsF)}  ($pctF %)', _purple,
            fontMedium, fontRegular),
        _statLine('Nouvelles inscriptions (période)',
            _money(data.elevesNouveaux), _green, fontMedium, fontRegular),
        pw.Divider(color: _border, thickness: 0.5),
        _statLine('Classes ouvertes', _money(data.classesTotal), _orange,
            fontMedium, fontRegular),
      ]),
    );
  }

  // ── Indicateurs financiers ─────────────────────────────────────────────────────
  static pw.Widget _financeSection(
    ReportData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final hasFinance = data.revenusTotal > 0 || data.paiementsCount > 0;
    return _sectionFrame(
      title: 'INDICATEURS FINANCIERS (PÉRIODE)',
      color: _green,
      fontBold: fontBold,
      footer: hasFinance
          ? 'Taux de recouvrement : ${data.tauxPaiement.toStringAsFixed(1)} %  '
              '(${data.elevesAJour} élève(s) à jour sur ${data.elevesTotal})'
          : null,
      fontFooter: fontMedium,
      child: hasFinance
          ? pw.Column(children: [
              _statLine('Revenus de la période',
                  '${_money(data.revenusTotal.round())} FCFA',
                  _green, fontMedium, fontRegular),
              _statLine('Paiements confirmés', '${data.paiementsCount}', _navy,
                  fontMedium, fontRegular),
              _statLine('Revenu moyen / élève',
                  '${_money(data.revenuMoyenParEleve.round())} FCFA',
                  _blue, fontMedium, fontRegular),
              _statLine('Élèves à jour', _money(data.elevesAJour), _green,
                  fontMedium, fontRegular),
              _statLine('Élèves impayés', _money(data.elevesImpayes),
                  data.elevesImpayes > 0 ? _red : _green, fontMedium, fontRegular),
            ])
          : _emptyNote(
              'Aucune donnée financière sur la période sélectionnée.',
              fontRegular),
    );
  }

  // ── Ressources humaines ─────────────────────────────────────────────────────────
  static pw.Widget _hrSection(
    ReportData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final byContract = data.staffByContract.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _sectionFrame(
      title: 'RESSOURCES HUMAINES',
      color: _purple,
      fontBold: fontBold,
      footer: data.personnelTotal == 0
          ? null
          : 'Part des fonctionnaires de l\'État : '
              '${data.tauxFonctionnaires.toStringAsFixed(1)} %',
      fontFooter: fontMedium,
      child: data.personnelTotal == 0
          ? _emptyNote('Aucun personnel enregistré sur ce périmètre.', fontRegular)
          : pw.Column(children: [
              _statLine('Fonctionnaires de l\'État (titulaires)',
                  '${data.fonctionnaires}', _navy, fontMedium, fontRegular),
              _statLine('Personnel non fonctionnaire', '${data.nonFonctionnaires}',
                  _orange, fontMedium, fontRegular),
              _statLine('Recrutements (période)', '${data.personnelNouveau}',
                  _green, fontMedium, fontRegular),
              if (byContract.isNotEmpty) pw.Divider(color: _border, thickness: 0.5),
              ...byContract.map((e) => _statLine(
                  _contractLabel(e.key), '${e.value}', _muted,
                  fontMedium, fontRegular)),
            ]),
    );
  }

  // ── Répartition par établissement ─────────────────────────────────────────────
  static pw.Widget _schoolsSection(
    ReportData data,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final rows = data.schoolRows.map((s) {
      return [
        s.name,
        _typeLabel(s.type),
        '${s.students}',
        '${s.staff}',
        '${s.classes}',
        _money(s.revenue.round()),
        s.isActive ? 'Active' : 'Inactive',
      ];
    }).toList();

    return _sectionFrame(
      title: 'RÉPARTITION PAR ÉTABLISSEMENT (${data.schoolRows.length})',
      color: _navy,
      fontBold: fontBold,
      child: rows.isEmpty
          ? _emptyNote('Aucun établissement sur ce périmètre.', fontRegular)
          : pw.TableHelper.fromTextArray(
              headers: const [
                'Établissement', 'Type', 'Élèves', 'Personnel', 'Classes',
                'Revenus', 'Statut'
              ],
              data: rows,
              border: null,
              headerStyle: pw.TextStyle(
                  font: fontBold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _navy),
              cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9, color: _text),
              cellHeight: 20,
              oddRowDecoration: const pw.BoxDecoration(color: _surface),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(2.6),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.2),
              },
            ),
    );
  }

  static pw.Widget _statLine(
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
                      color: color, borderRadius: pw.BorderRadius.circular(2))),
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
  static Future<void> printReport({required ReportData data}) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(data: data),
      name: 'Rapport_${_slug(data.groupName)}.pdf',
    );
  }

  static Future<String?> downloadReport({required ReportData data}) async {
    final bytes = await buildPdf(data: data);
    final fileName = 'Rapport_${_slug(data.groupName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport',
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

String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive'  => 'Privé',
      _        => t,
    };

String _contractLabel(String c) => switch (c) {
      'permanent'   => 'Titulaires (permanents)',
      'contractuel' => 'Contractuels',
      'vacataire'   => 'Vacataires',
      'stagiaire'   => 'Stagiaires',
      _             => c,
    };
