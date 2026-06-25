import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/inscriptions_data_provider.dart';
import 'enrollment_pdf_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : INSCRIPTIONS (pipeline de l'année) — export officiel groupé par
//  CYCLE puis par CLASSE : identité, sexe, âge, type, statut.
// ══════════════════════════════════════════════════════════════════════════════
class InscriptionsPdfService {
  static Future<Uint8List> buildPdf({
    required List<InscriptionRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final byCycle = <String, List<InscriptionRow>>{};
    for (final r in rows) {
      byCycle.putIfAbsent(r.cycle.code, () => []).add(r);
    }
    final cycleKeys = byCycle.keys.toList()
      ..sort((a, b) => cycleOrderPdf(a).compareTo(cycleOrderPdf(b)));

    final validated = rows.where((r) => r.status == 'active').length;
    final pending =
        rows.where((r) => r.status == 'pending_validation').length;
    final news = rows.where((r) => r.inscriptionType == 'new').length;

    final doc = pw.Document(
      title: 'Inscriptions',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Inscriptions de l\'année par cycle et classe',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'LISTE DES\nINSCRIPTIONS'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'INSCRIPTIONS',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Inscriptions par classe',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Inscriptions', '${rows.length}', kPdfNavy),
          PdfKpi('Validées', '$validated', kPdfGreen),
          PdfKpi('En attente', '$pending', kPdfGold),
          PdfKpi('Nouvelles', '$news', const PdfColor.fromInt(0xFF0EA5E9)),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucune inscription à exporter.', f.regular)
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

  static pw.Widget _cycleSection(
      String code, List<InscriptionRow> items, PdfFonts f) {
    final color = cycleColorPdf(code);
    final name = cycleNamePdf(code, items.first.cycle.label);
    final sorted = [...items]..sort((a, b) {
        final o = a.levelOrder.compareTo(b.levelOrder);
        if (o != 0) return o;
        final c = a.className.compareTo(b.className);
        return c != 0 ? c : a.lastFirst.compareTo(b.lastFirst);
      });
    final byClass = <String, List<InscriptionRow>>{};
    for (final r in sorted) {
      byClass.putIfAbsent(
          r.className.isEmpty ? 'Sans classe' : r.className, () => []).add(r);
    }

    return enrollmentCycleSection(
      color: color,
      cycleName: name,
      count: items.length,
      groupCount: byClass.length,
      groupNoun: 'classe',
      fonts: f,
      groups: [
        for (final e in byClass.entries)
          EnrollmentGroup(
            label: e.key,
            table: OfficialPdfKit.table(
              headers: const ['Matricule', 'Nom & prénom', 'Sexe', 'Âge',
                'Type', 'Statut'],
              rows: e.value
                  .map((r) => [
                        r.matricule,
                        r.lastFirst,
                        _sex(r.gender),
                        r.age?.toString() ?? '—',
                        r.typeLabel,
                        r.statusLabel,
                      ])
                  .toList(),
              fonts: f,
              flex: const [3, 6, 2, 2, 3, 3],
              leftAlignCols: const {1},
            ),
          ),
      ],
    );
  }

  static String _sex(String? g) {
    final s = (g ?? '').toLowerCase();
    if (s.startsWith('f')) return 'F';
    if (s.startsWith('m') || s.startsWith('h')) return 'M';
    return '—';
  }

  static Future<String?> downloadDoc({
    required List<InscriptionRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Inscriptions_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les inscriptions',
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
