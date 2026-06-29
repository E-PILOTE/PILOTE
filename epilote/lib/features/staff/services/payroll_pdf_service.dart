import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/payroll_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Services PDF PAIE — chrome officiel partagé (OfficialPdfKit) :
//   • bulletin individuel d'un agent (base/primes/retenues/net, statut, méthode)
//   • état de paie d'une période (tableau de tous les agents + masse salariale)
//  Montants en XAF/FCFA.
// ══════════════════════════════════════════════════════════════════════════════

String _xaf(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${b.toString()} FCFA';
}

class PayrollPdfService {
  // ─── Bulletin individuel ────────────────────────────────────────────────────
  static Future<Uint8List> buildPayslip({
    required PayrollLine line,
    required int month,
    required int year,
    String? schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());
    final period = '${kMonthNames[month - 1]} $year';

    final doc = pw.Document(
      title: 'Bulletin de paie — ${line.staffName}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Bulletin de paie $period',
    );

    pw.Widget row(String label, String value, {PdfColor? color, bool bold = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: kPdfBorder, width: 0.6)),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: bold ? f.bold : f.regular,
                    fontSize: 10,
                    color: kPdfText)),
          ),
          pw.Text(value,
              style: pw.TextStyle(
                  font: f.bold, fontSize: 11, color: color ?? kPdfText)),
        ]),
      );
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'BULLETIN\nDE PAIE'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'BULLETIN DE PAIE',
            title: line.staffName.isEmpty ? 'Agent' : line.staffName,
            line1: (schoolName?.trim().isNotEmpty ?? false)
                ? '${schoolName!.trim()} — période $period'
                : 'Période : $period',
            line2: 'Édité le $genDate',
            statusBadge: payStatusLabel(line.status).toUpperCase()),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Salaire de base', _xaf(line.base), kPdfNavy),
          PdfKpi('Primes', _xaf(line.bonuses), kPdfGreen),
          PdfKpi('Retenues', _xaf(line.deductions),
              line.deductions > 0 ? kPdfRed : kPdfMuted),
          PdfKpi('Net à payer', _xaf(line.net), kPdfGreen),
        ], width: 118),
        pw.SizedBox(height: 16),
        OfficialPdfKit.frame(
          title: 'DÉTAIL DE LA RÉMUNÉRATION',
          color: kPdfNavy,
          fonts: f,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Column(children: [
              row('Salaire de base', _xaf(line.base)),
              row('Primes et indemnités', _xaf(line.bonuses), color: kPdfGreen),
              row('Retenues', '- ${_xaf(line.deductions)}',
                  color: line.deductions > 0 ? kPdfRed : kPdfMuted),
              row('NET À PAYER', _xaf(line.net), color: kPdfGreen, bold: true),
              row('Mode de paiement', payMethodLabel(line.method)),
              if ((line.reference ?? '').isNotEmpty)
                row('Référence', line.reference!),
              row('Statut', payStatusLabel(line.status)),
            ]),
          ),
        ),
        pw.SizedBox(height: 22),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _sign(f, 'L\'agent'),
                _sign(f, 'La direction'),
              ]),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _sign(PdfFonts f, String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: f.medium, fontSize: 9, color: kPdfMuted)),
          pw.SizedBox(height: 34),
          pw.Container(width: 150, height: 0.8, color: kPdfBorder),
        ],
      );

  // ─── État de paie (tous les agents de la période) ───────────────────────────
  static Future<Uint8List> buildRegister({
    required List<PayrollLine> lines,
    required int month,
    required int year,
    String? schoolName,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());
    final period = '${kMonthNames[month - 1]} $year';

    final mass = lines.fold(0, (a, l) => a + l.net);
    final paid = lines.where((l) => l.status == 'confirmed').toList();
    final paidMass = paid.fold(0, (a, l) => a + l.net);

    final doc = pw.Document(
      title: 'État de paie — $period',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'État de paie $period',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'ÉTAT\nDE PAIE'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'ÉTAT DE PAIE',
            title: (schoolName?.trim().isNotEmpty ?? false)
                ? schoolName!.trim()
                : 'État de paie',
            line1: 'Période : $period — ${lines.length} agent'
                '${lines.length > 1 ? 's' : ''}',
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Masse salariale', _xaf(mass), kPdfNavy),
          PdfKpi('Versé', _xaf(paidMass), kPdfGreen),
          PdfKpi('En attente', '${lines.length - paid.length}',
              lines.length - paid.length > 0 ? kPdfGold : kPdfMuted),
          PdfKpi('Agents', '${lines.length}', const PdfColor.fromInt(0xFF0EA5E9)),
        ], width: 130),
        pw.SizedBox(height: 16),
        if (lines.isEmpty)
          OfficialPdfKit.empty('Aucun bulletin pour cette période.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'BULLETINS — $period',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'Agent', 'Base', 'Primes', 'Retenues', 'Net', 'Méthode', 'Statut'
              ],
              rows: [
                for (final l in lines)
                  [
                    l.staffName.isEmpty ? '—' : l.staffName,
                    _xaf(l.base),
                    _xaf(l.bonuses),
                    _xaf(l.deductions),
                    _xaf(l.net),
                    payMethodLabel(l.method),
                    payStatusLabel(l.status),
                  ],
              ],
              fonts: f,
              flex: const [5, 3, 3, 3, 3, 3, 2],
              leftAlignCols: const {0},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));
    return doc.save();
  }

  static Future<String?> _download(Uint8List bytes, String fileName) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le document',
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

  static Future<String?> downloadPayslip({
    required PayrollLine line,
    required int month,
    required int year,
    String? schoolName,
  }) async {
    final bytes = await buildPayslip(
        line: line, month: month, year: year, schoolName: schoolName);
    final safe = line.staffName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return _download(bytes, 'Bulletin_${safe}_$year-$month.pdf');
  }

  static Future<String?> downloadRegister({
    required List<PayrollLine> lines,
    required int month,
    required int year,
    String? schoolName,
  }) async {
    final bytes = await buildRegister(
        lines: lines, month: month, year: year, schoolName: schoolName);
    return _download(bytes, 'Etat_paie_$year-$month.pdf');
  }
}
