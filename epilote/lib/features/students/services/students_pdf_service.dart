import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/students_registry_provider.dart';
import 'enrollment_pdf_shared.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : EFFECTIF ÉLÈVES (status active) — export officiel groupé par CYCLE
//  puis par CLASSE. Trombinoscope textuel : matricule, identité, sexe, âge,
//  internat / bourse.
// ══════════════════════════════════════════════════════════════════════════════
class StudentsPdfService {
  static Future<Uint8List> buildPdf({
    required List<StudentRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final byCycle = <String, List<StudentRow>>{};
    for (final r in rows) {
      byCycle.putIfAbsent(r.cycleCode ?? 'autre', () => []).add(r);
    }
    final cycleKeys = byCycle.keys.toList()
      ..sort((a, b) => cycleOrderPdf(a).compareTo(cycleOrderPdf(b)));

    final boarders = rows.where((r) => r.isBoarder).length;
    final aided =
        rows.where((r) => r.hasScholarship || r.hasSocialAid).length;
    final girls = rows
        .where((r) => (r.gender ?? '').toLowerCase().startsWith('f'))
        .length;

    final doc = pw.Document(
      title: 'Effectif élèves',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Effectif des élèves par cycle et classe',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'EFFECTIF\nÉLÈVES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'EFFECTIF DES ÉLÈVES',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Liste des élèves par classe',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves', '${rows.length}', kPdfNavy),
          PdfKpi('Filles', '$girls', const PdfColor.fromInt(0xFFEC4899)),
          PdfKpi('Internes', '$boarders', kPdfGreen),
          PdfKpi('Aidés / boursiers', '$aided', kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucun élève à exporter.', f.regular)
        else
          for (final k in cycleKeys) ...[
            ..._cycleSection(k, byCycle[k]!, f),
            pw.SizedBox(height: 14),
          ],
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static List<pw.Widget> _cycleSection(
      String code, List<StudentRow> items, PdfFonts f) {
    final color = cycleColorPdf(code);
    final name = cycleNamePdf(code);
    // Groupement par classe (ordre pédagogique du niveau, puis nom de classe).
    final sorted = [...items]..sort((a, b) {
        final o = a.levelOrder.compareTo(b.levelOrder);
        if (o != 0) return o;
        final c = (a.className ?? '').compareTo(b.className ?? '');
        return c != 0 ? c : a.lastFirst.compareTo(b.lastFirst);
      });
    final byClass = <String, List<StudentRow>>{};
    for (final r in sorted) {
      byClass.putIfAbsent(r.className ?? 'Sans classe', () => []).add(r);
    }

    return enrollmentCycleBlocks(
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
            headers: const ['Matricule', 'Nom & prénom', 'Sexe', 'Âge',
              'Interne', 'Boursier'],
            rows: e.value
                .map((r) => [
                      r.matricule,
                      r.lastFirst,
                      _sex(r.gender),
                      r.age?.toString() ?? '—',
                      r.isBoarder ? 'Oui' : '—',
                      (r.hasScholarship || r.hasSocialAid) ? 'Oui' : '—',
                    ])
                .toList(),
            flex: const [3, 6, 2, 2, 2, 2],
            leftAlignCols: const {1},
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
    required List<StudentRow> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Eleves_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer l\'effectif',
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
