import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/transfers_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : TRANSFERTS — export officiel groupé par STATUT (en attente →
//  approuvé → terminé → rejeté). Mise en page = OfficialPdfKit (chrome partagé).
// ══════════════════════════════════════════════════════════════════════════════
class TransfersPdfService {
  // Ordre et couleur par statut.
  static const _order = ['pending', 'approved', 'completed', 'rejected'];
  static const _names = {
    'pending': 'En attente',
    'approved': 'Approuvés',
    'completed': 'Terminés',
    'rejected': 'Rejetés',
  };
  static PdfColor _color(String s) => switch (s) {
        'pending' => kPdfGold,
        'approved' => const PdfColor.fromInt(0xFF0EA5E9),
        'completed' => kPdfGreen,
        'rejected' => kPdfRed,
        _ => kPdfNavy,
      };

  static Future<Uint8List> buildPdf({
    required List<TransferRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());
    final fmtDate = DateFormat('dd/MM/yyyy', 'fr');

    final byStatus = <String, List<TransferRow>>{};
    for (final r in rows) {
      byStatus.putIfAbsent(r.status, () => []).add(r);
    }
    final keys = _order.where(byStatus.containsKey).toList();

    int countOf(String s) => byStatus[s]?.length ?? 0;

    final doc = pw.Document(
      title: 'Transferts',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Registre des transferts d\'élèves',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'REGISTRE\nTRANSFERTS'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'TRANSFERTS D\'ÉLÈVES',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Registre des transferts',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Transferts', '${rows.length}', kPdfNavy),
          PdfKpi('En attente', '${countOf('pending')}', kPdfGold),
          PdfKpi('Approuvés', '${countOf('approved')}',
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Terminés', '${countOf('completed')}', kPdfGreen),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucun transfert à exporter.', f.regular)
        else
          for (final k in keys) ...[
            OfficialPdfKit.frame(
              title: (_names[k] ?? k).toUpperCase(),
              color: _color(k),
              fonts: f,
              child: OfficialPdfKit.table(
                headers: const ['Élève', 'Classe', 'École destination', 'Date',
                  'Motif'],
                rows: byStatus[k]!
                    .map((t) => [
                          t.lastFirst,
                          t.className ?? '—',
                          t.toSchoolName ?? '—',
                          t.transferDate != null
                              ? fmtDate.format(t.transferDate!)
                              : '—',
                          (t.reason ?? '—').replaceAll('\n', ' '),
                        ])
                    .toList(),
                fonts: f,
                flex: const [4, 2, 4, 2, 4],
                leftAlignCols: const {2, 4},
              ),
            ),
            pw.SizedBox(height: 14),
          ],
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> downloadDoc({
    required List<TransferRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Transferts_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les transferts',
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
