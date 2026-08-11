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

import '../providers/invoices_provider.dart';
import '../providers/receipts_provider.dart';

// ─── Couleurs PDF ──────────────────────────────────────────────────────────────
const _navy    = PdfColor.fromInt(0xFF1E3A5F);
const _navyL   = PdfColor.fromInt(0xFF2A4E7A);
const _green   = PdfColor.fromInt(0xFF009A44);
const _gold    = PdfColor.fromInt(0xFFFBBC04);
const _red     = PdfColor.fromInt(0xFFDC143C);
const _orange  = PdfColor.fromInt(0xFFFF6B35);
const _purple  = PdfColor.fromInt(0xFF7C3AED);
const _muted   = PdfColor.fromInt(0xFF64748B);
const _border  = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text    = PdfColor.fromInt(0xFF0F172A);

PdfColor _invoiceColor(String status) => switch (status) {
  'paid'      => _green,
  'pending'   => _orange,
  'overdue'   => _red,
  'cancelled' => _muted,
  _           => _muted,
};

String _invoiceLabel(String status) => switch (status) {
  'paid'      => 'Payée',
  'pending'   => 'En attente',
  'overdue'   => 'En retard',
  'cancelled' => 'Annulée',
  _           => status,
};

String _methodLabel(String? m) => switch (m) {
  'especes'      => 'Espèces',
  'mtn_money'    => 'MTN Money',
  'airtel_money' => 'Airtel Money',
  'visa'         => 'Visa / Carte',
  'virement'     => 'Virement bancaire',
  null           => '—',
  ''             => '—',
  _              => m,
};

// ─── Service Reçu ───────────────────────────────────────────────────────────────

class ReceiptPdfService {
  static Future<Uint8List> buildPdf(ReceiptModel r) async {
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
    final ref_     = r.receiptNumber;

    final paidDate   = DateTime.tryParse(r.paidAt);
    final pStart     = DateTime.tryParse(r.periodStart);
    final pEnd       = DateTime.tryParse(r.periodEnd);

    final doc = pw.Document(
      title: 'Reçu de paiement — ${r.groupName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Reçu de paiement',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(r.groupName, logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        _titleBlock(
          docType: 'REÇU DE PAIEMENT',
          number: r.receiptNumber,
          groupName: r.groupName,
          statusLabel: 'PAYÉ',
          statusColor: _green,
          fontBold: fontBold,
          fontMedium: fontMedium,
          fontRegular: fontRegular,
        ),
        pw.SizedBox(height: 16),
        _amountBox(r.amountXaf, _green, 'Montant réglé', fontBold, fontRegular),
        pw.SizedBox(height: 18),
        _section(
          title: 'GROUPE SCOLAIRE',
          color: _navy,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Nom du groupe', r.groupName),
            _Row('Formule', r.planName),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'DÉTAILS DU PAIEMENT',
          color: _green,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Mode de paiement', _methodLabel(r.paymentMethod)),
            _Row('Référence', r.paymentReference.isEmpty ? '—' : r.paymentReference),
            _Row('Réglé le', paidDate != null ? fmtDateL.format(paidDate) : '—'),
            if (pStart != null && pEnd != null)
              _Row('Période couverte',
                  '${fmtDateL.format(pStart)} → ${fmtDateL.format(pEnd)}'),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'IDENTIFIANTS SYSTÈME',
          color: _purple,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('N° de reçu', r.receiptNumber),
            _Row('Facture liée', r.invoiceNumber),
            _Row('Identifiant unique', r.id),
          ],
        ),
        pw.SizedBox(height: 22),
        _legalNote(fontRegular),
      ],
    ));

    return doc.save();
  }

  static Future<void> printReceipt(ReceiptModel r) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(r),
      name: 'Recu_${r.receiptNumber}.pdf',
    );
  }

  static Future<void> shareReceipt(ReceiptModel r) async {
    final bytes = await buildPdf(r);
    await Printing.sharePdf(bytes: bytes, filename: 'Recu_${r.receiptNumber}.pdf');
  }

  static Future<String?> downloadReceipt(ReceiptModel r) async {
    final bytes = await buildPdf(r);
    final fileName =
        'Recu_${r.receiptNumber.replaceAll(RegExp(r'[^\w]'), '_')}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    return _savePdf(bytes, fileName, 'Enregistrer le reçu PDF');
  }
}

// ─── Service Facture ──────────────────────────────────────────────────────────

class InvoicePdfService {
  static Future<Uint8List> buildPdf(InvoiceDetail inv) async {
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
    final color    = _invoiceColor(inv.status);

    final doc = pw.Document(
      title: 'Facture ${inv.invoiceNumber} — ${inv.groupName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Facture d\'abonnement',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _buildHeader(inv.groupName, logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _buildFooter(ctx, fontRegular, fontMedium, now, inv.invoiceNumber),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        _titleBlock(
          docType: 'FACTURE',
          number: inv.invoiceNumber,
          groupName: inv.groupName,
          statusLabel: _invoiceLabel(inv.status).toUpperCase(),
          statusColor: color,
          fontBold: fontBold,
          fontMedium: fontMedium,
          fontRegular: fontRegular,
        ),
        pw.SizedBox(height: 16),
        _amountBox(inv.amountXaf, color,
            inv.isPaid ? 'Montant réglé' : 'Montant dû', fontBold, fontRegular),
        pw.SizedBox(height: 18),
        _section(
          title: 'GROUPE SCOLAIRE',
          color: _navy,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Nom du groupe', inv.groupName),
            _Row('Formule', inv.planName ?? 'Sans plan'),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'PÉRIODE DE FACTURATION',
          color: _gold,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Début de période', fmtDateL.format(inv.periodStart)),
            _Row('Fin de période', fmtDateL.format(inv.periodEnd)),
            _Row('Émise le', fmtDateL.format(inv.createdAt)),
          ],
        ),
        pw.SizedBox(height: 12),
        _section(
          title: 'PAIEMENT',
          color: inv.isPaid ? _green : _orange,
          fontBold: fontBold,
          fontRegular: fontRegular,
          rows: [
            _Row('Statut', _invoiceLabel(inv.status)),
            _Row('Mode de paiement', _methodLabel(inv.paymentMethod)),
            _Row('Référence', inv.paymentReference ?? '—'),
            _Row('Payée le',
                inv.paidAt != null ? fmtDateL.format(inv.paidAt!) : '—'),
          ],
        ),
        if (inv.notes != null && inv.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _section(
            title: 'NOTES',
            color: _purple,
            fontBold: fontBold,
            fontRegular: fontRegular,
            rows: [_Row('', inv.notes!)],
          ),
        ],
        pw.SizedBox(height: 22),
        _legalNote(fontRegular),
      ],
    ));

    return doc.save();
  }

  static Future<void> printInvoice(InvoiceDetail inv) async {
    await Printing.layoutPdf(
      onLayout: (_) => buildPdf(inv),
      name: 'Facture_${inv.invoiceNumber}.pdf',
    );
  }

  static Future<void> shareInvoice(InvoiceDetail inv) async {
    final bytes = await buildPdf(inv);
    await Printing.sharePdf(bytes: bytes, filename: 'Facture_${inv.invoiceNumber}.pdf');
  }

  static Future<String?> downloadInvoice(InvoiceDetail inv) async {
    final bytes = await buildPdf(inv);
    final fileName =
        'Facture_${inv.invoiceNumber.replaceAll(RegExp(r'[^\w]'), '_')}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    return _savePdf(bytes, fileName, 'Enregistrer la facture PDF');
  }
}

// ─── Composants partagés ──────────────────────────────────────────────────────

pw.Widget _buildHeader(
  String groupName,
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
                child: pw.Center(child: pw.Text(_initials(groupName),
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

pw.Widget _buildFooter(
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

pw.Widget _titleBlock({
  required String docType,
  required String number,
  required String groupName,
  required String statusLabel,
  required PdfColor statusColor,
  required pw.Font fontBold,
  required pw.Font fontMedium,
  required pw.Font fontRegular,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(docType,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 22, color: _text, letterSpacing: 0.5)),
                pw.SizedBox(height: 3),
                pw.Text('N° $number',
                    style: pw.TextStyle(font: fontMedium, fontSize: 11, color: _muted)),
              ],
            )),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                pw.Text(statusLabel,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 8.5, color: statusColor, letterSpacing: 0.5)),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _border, thickness: 0.8),
      ],
    ),
  );
}

pw.Widget _amountBox(
  int amountXaf,
  PdfColor color,
  String label,
  pw.Font fontBold,
  pw.Font fontRegular,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
    child: pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _alpha(color, 0.06),
        border: pw.Border.all(color: _alpha(color, 0.25), width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  font: fontRegular, fontSize: 9, color: _muted, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text('${_money(amountXaf)} FCFA',
              style: pw.TextStyle(font: fontBold, fontSize: 30, color: color)),
        ],
      ),
    ),
  );
}

pw.Widget _section({
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
              child: e.value.label.isEmpty
                  ? pw.Text(e.value.value,
                      style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: _text))
                  : pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(width: 130, child: pw.Text(e.value.label,
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

pw.Widget _legalNote(pw.Font fontRegular) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
    child: pw.Text(
      'Ce document est généré automatiquement par la plateforme E-PILOTE CONGO. '
      'Il atteste de la transaction enregistrée dans le système et ne nécessite '
      'pas de signature manuscrite. Pour toute vérification, conservez la référence indiquée.',
      style: pw.TextStyle(font: fontRegular, fontSize: 8, color: _muted),
      textAlign: pw.TextAlign.justify,
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<String?> _savePdf(Uint8List bytes, String fileName, String dialogTitle) async {
  try {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

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
