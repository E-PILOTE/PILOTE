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

import '../providers/subscriptions_provider.dart';

// ─── Couleurs PDF ──────────────────────────────────────────────────────────────
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

PdfColor _statusColor(String status) => switch (status) {
  'active'    => _green,
  'trial'     => _blue,
  'suspended' => _orange,
  'expired'   => _red,
  'cancelled' => _muted,
  _           => _muted,
};

// ─── Service principal ────────────────────────────────────────────────────────

class SubscriptionPdfService {
  static Future<Uint8List> buildPdf(SubscriptionDetail s) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold    = await PdfGoogleFonts.notoSansBold();
    final fontMedium  = await PdfGoogleFonts.notoSansMedium();

    pw.ImageProvider? logoGroup;
    if (s.groupLogo != null && s.groupLogo!.startsWith('http')) {
      try {
        logoGroup = await networkImage(s.groupLogo!);
      } catch (_) {}
    }

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now      = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_     = s.id.substring(0, 8).toUpperCase();

    final doc = pw.Document(
      title: 'Attestation d\'abonnement — ${s.groupName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Attestation d\'abonnement',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(s, logoGroup, logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        _nameBlock(s, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _section(
              title: 'GROUPE SCOLAIRE',
              color: _navy,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Nom', s.groupName),
                _Row('Type', s.groupTypeLabel),
                _Row('Département', s.department ?? '—'),
                _Row('Écoles', '${s.schoolsCount}'),
              ],
            )),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _section(
              title: 'CONTACT',
              color: _gold,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Email admin', s.adminEmail),
                _Row('Téléphone', s.phone ?? '—'),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'ABONNEMENT',
          color: _green,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Plan souscrit', s.planName ?? 'Aucun plan'),
            _Row('Tarif mensuel',
                s.priceXaf <= 0 ? 'Gratuit' : '${_money(s.priceXaf)} FCFA'),
            _Row('Statut', s.statusLabel),
            _Row('Date de début',
                s.start != null ? fmtDateL.format(s.start!) : '—'),
            _Row('Date de fin',
                s.end != null ? fmtDateL.format(s.end!) : '—'),
            _Row('Échéance', s.remainingLabel),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'IDENTIFIANTS SYSTÈME',
          color: _purple,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Identifiant unique (UUID)', s.id),
            _Row('Référence', ref_),
            _Row('Créé le', fmtDateL.format(s.createdAt)),
            _Row('Mis à jour le', fmtDateL.format(s.updatedAt)),
          ],
        ),
        pw.SizedBox(height: 24),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _buildHeader(
    SubscriptionDetail s,
    pw.ImageProvider? logoGroup,
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
                  width: 58, height: 58,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border, width: 1.5),
                    shape: pw.BoxShape.circle,
                    color: _surface,
                  ),
                  child: logoGroup != null
                      ? pw.ClipOval(child: pw.Image(logoGroup, fit: pw.BoxFit.cover))
                      : pw.Center(child: pw.Text(s.initials,
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 18, color: _navy))),
                ),
                pw.SizedBox(height: 3),
                pw.Text('GROUPE SCOLAIRE',
                    style: pw.TextStyle(
                        font: fontMedium, fontSize: 6.5,
                        color: _muted, letterSpacing: 1)),
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

  static pw.Widget _nameBlock(
    SubscriptionDetail s,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final sc = _statusColor(s.status);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(child: pw.Text(
              s.groupName.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: _text),
            )),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _alpha(sc, 0.12),
                border: pw.Border.all(color: _alpha(sc, 0.4), width: 1),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Row(children: [
                pw.Container(width: 7, height: 7,
                    decoration: pw.BoxDecoration(
                        color: sc, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 5),
                pw.Text(s.statusLabel.toUpperCase(),
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 8, color: sc, letterSpacing: 0.5)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 6, runSpacing: 4, children: [
            _badge(s.planName ?? 'Aucun plan', _navy, fontMedium),
            _badge(s.priceXaf <= 0 ? 'Gratuit' : '${_money(s.priceXaf)} FCFA / mois',
                _green, fontMedium),
            _badge(s.groupTypeLabel, _gold, fontMedium),
            _badge('${s.schoolsCount} école(s)', _blue, fontMedium),
          ]),
          pw.SizedBox(height: 12),
          pw.Divider(color: _border, thickness: 0.8),
        ],
      ),
    );
  }

  static pw.Widget _section({
    required String      title,
    required PdfColor    color,
    required pw.Font     fontBold,
    required pw.Font     fontRegular,
    required List<_Row>  rows,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: pw.BoxDecoration(
                color: _alpha(color, 0.08),
                border: pw.Border(
                    bottom: pw.BorderSide(color: _alpha(color, 0.2), width: 0.8)),
              ),
              child: pw.Text(title,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9, color: color, letterSpacing: 0.8)),
            ),
            ...rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: pw.BoxDecoration(
                  border: isLast ? null : const pw.Border(
                      bottom: pw.BorderSide(color: _border, width: 0.5)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 120, child: pw.Text(e.value.label,
                        style: pw.TextStyle(
                            font: fontRegular, fontSize: 9, color: _muted))),
                    pw.Expanded(child: pw.Text(e.value.value,
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 9.5, color: _text))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static pw.Widget _badge(String label, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _alpha(color, 0.10),
        border: pw.Border.all(color: _alpha(color, 0.3), width: 0.8),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(font: font, fontSize: 8.5, color: color)),
    );
  }

  static Future<void> printSubscription(SubscriptionDetail s) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(s),
      name: 'Abonnement_${s.groupName.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<String?> downloadSubscription(SubscriptionDetail s) async {
    final bytes = await buildPdf(s);
    final fileName =
        'Abonnement_${s.groupName.replaceAll(RegExp(r'[^\w]'), '_')}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer l\'attestation PDF',
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

class _Row {
  const _Row(this.label, this.value);
  final String label, value;
}
