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

import '../providers/plans_provider.dart';

// ─── Couleurs PDF ──────────────────────────────────────────────────────────────
const _navy    = PdfColor.fromInt(0xFF1E3A5F);
const _navyL   = PdfColor.fromInt(0xFF2A4E7A);
const _green   = PdfColor.fromInt(0xFF009A44);
const _gold    = PdfColor.fromInt(0xFFFBBC04);
const _red     = PdfColor.fromInt(0xFFDC143C);
const _purple  = PdfColor.fromInt(0xFF7C3AED);
const _blue    = PdfColor.fromInt(0xFF0EA5E9);
const _muted   = PdfColor.fromInt(0xFF64748B);
const _border  = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text    = PdfColor.fromInt(0xFF0F172A);

// ─── Service principal ────────────────────────────────────────────────────────

class PlanPdfService {
  static Future<Uint8List> buildPdf(PlanDetail p) async {
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
    final ref_     = p.id.substring(0, 8).toUpperCase();

    final doc = pw.Document(
      title: 'Fiche Plan — ${p.name}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Fiche descriptive du plan d\'abonnement',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(p, logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        _nameBlock(p, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _section(
              title: 'TARIFICATION',
              color: _navy,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Prix mensuel', p.isFree ? 'Gratuit' : '${moneyXaf(p.priceXaf)} FCFA'),
                _Row('Type de plan', p.isPublicPlan ? 'Public' : 'Privé'),
                _Row('Statut', p.isActive ? 'Actif' : 'Inactif'),
              ],
            )),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _section(
              title: 'QUOTAS & LIMITES',
              color: _gold,
              fontBold: fontBold,
              fontRegular: fontRegular,
              rows: [
                _Row('Écoles max', p.unlimited ? 'Illimité' : '${p.maxSchools}'),
                _Row('Élèves max', moneyXaf(p.maxStudents)),
                _Row('Personnel max', moneyXaf(p.maxStaff)),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'MODULES & ADOPTION',
          color: _green,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Modules inclus', '${p.linkedModules} module(s)'),
            _Row('Modules annoncés', '${p.moduleCount}'),
            _Row('Groupes abonnés', '${p.subscribersTotal}'),
            _Row('Groupes actifs', '${p.subscribersActive}'),
            _Row('Revenu mensuel récurrent',
                '${moneyXaf(p.monthlyRevenue)} FCFA'),
          ],
        ),
        if (p.description != null && p.description!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _section(
            title: 'DESCRIPTION',
            color: _blue,
            fontBold: fontBold,
            fontRegular: fontRegular,
            rows: [_Row('Résumé', p.description!.trim())],
          ),
        ],
        pw.SizedBox(height: 12),
        _section(
          title: 'IDENTIFIANTS SYSTÈME',
          color: _purple,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Identifiant unique (UUID)', p.id),
            _Row('Référence fiche', ref_),
            _Row('Créé le', fmtDateL.format(p.createdAt)),
            _Row('Dernière mise à jour', fmtDateL.format(p.updatedAt)),
          ],
        ),
        pw.SizedBox(height: 24),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _buildHeader(
    PlanDetail p,
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
                      color: _navy,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
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
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PLAN D\'ABONNEMENT',
                      style: pw.TextStyle(
                          font: fontMedium, fontSize: 6.5,
                          color: _muted, letterSpacing: 1)),
                  pw.SizedBox(height: 2),
                  pw.Text(p.name.toUpperCase(),
                      style: pw.TextStyle(font: fontBold, fontSize: 12, color: _navy)),
                ],
              ),
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
    PlanDetail p,
    pw.Font fontBold,
    pw.Font fontMedium,
    pw.Font fontRegular,
  ) {
    final statusColor = p.isActive ? _green : _red;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(child: pw.Text(
              p.name.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: _text),
            )),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _alpha(statusColor, 0.12),
                border: pw.Border.all(color: _alpha(statusColor, 0.4), width: 1),
                // 9 et non 20 : la pastille fait ~18 pt de haut, et un rayon
                // supérieur à la DEMI-HAUTEUR fait dégénérer le tracé d'arrondi
                // du paquet `pdf` — deux ergots sombres apparaissent à gauche
                // et à droite, à mi-hauteur.
                borderRadius: pw.BorderRadius.circular(9),
              ),
              child: pw.Row(children: [
                pw.Container(width: 7, height: 7,
                    decoration: pw.BoxDecoration(
                        color: statusColor, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 5),
                pw.Text(p.isActive ? 'ACTIF' : 'INACTIF',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 8,
                        color: statusColor, letterSpacing: 0.5)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 6, runSpacing: 4, children: [
            _badge(p.isFree ? 'GRATUIT' : '${moneyXaf(p.priceXaf)} FCFA / mois',
                _navy, fontMedium),
            _badge(p.isPublicPlan ? 'Plan public' : 'Plan privé', _gold, fontMedium),
            _badge('${p.linkedModules} modules', _blue, fontMedium),
            _badge('${p.subscribersTotal} abonnés', _green, fontMedium),
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
                    pw.SizedBox(width: 140, child: pw.Text(e.value.label,
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

  static Future<void> printPlan(PlanDetail p) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(p),
      name: 'Plan_${p.name.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<String?> downloadPlan(PlanDetail p) async {
    final bytes = await buildPdf(p);
    final fileName =
        'Plan_${p.name.replaceAll(RegExp(r'[^\w]'), '_')}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la fiche PDF',
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

class _Row {
  const _Row(this.label, this.value);
  final String label, value;
}
