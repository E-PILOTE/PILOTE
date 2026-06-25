import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../data/models/subject_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : MATIÈRES (référentiel canonique) — export officiel. Liste triée,
//  coefficient par défaut, nombre de classes, niveaux où dispensée.
// ══════════════════════════════════════════════════════════════════════════════
class SubjectsPdfService {
  static Future<Uint8List> buildPdf({
    required List<SubjectModel> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final sorted = [...rows]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final assigned = rows.where((r) => r.isAssigned).length;
    final affectations = rows.fold<int>(0, (s, r) => s + r.classCount);
    final avgCoef = rows.isEmpty
        ? 0.0
        : rows.fold<int>(0, (s, r) => s + r.coefficient) / rows.length;

    final doc = pw.Document(
      title: 'Matières',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Référentiel des matières',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'RÉFÉRENTIEL\nMATIÈRES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RÉFÉRENTIEL DES MATIÈRES',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Matières enseignées',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Matières', '${rows.length}', kPdfNavy),
          PdfKpi('Affectées', '$assigned', kPdfGreen),
          PdfKpi('Affectations', '$affectations', kPdfGold),
          PdfKpi('Coef. moyen', avgCoef.toStringAsFixed(1), kPdfNavy),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucune matière à exporter.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'LISTE DES MATIÈRES',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const ['Matière', 'Coef. déf.', 'Classes', 'Niveaux'],
              rows: sorted
                  .map((s) => [
                        s.name,
                        '${s.coefficient}',
                        '${s.classCount}',
                        s.niveaux.isEmpty ? '—' : s.niveaux.join('  '),
                      ])
                  .toList(),
              fonts: f,
              flex: const [4, 2, 2, 5],
              leftAlignCols: const {3},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> downloadDoc({
    required List<SubjectModel> rows,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes =
        await buildPdf(rows: rows, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Matieres_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les matières',
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
