import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/documents_provider.dart';
import '../providers/student_documents_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : DOSSIERS DOCUMENTAIRES — état de conformité par élève (pièces
//  exigées présentes / vérifiées / dossier complet). Chrome partagé OfficialPdfKit.
// ══════════════════════════════════════════════════════════════════════════════
class DocumentsPdfService {
  static Future<Uint8List> buildPdf({
    required List<StudentDossier> dossiers,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final required = studentDocTypes.entries
        .where((e) => kRequiredDocTypes.contains(e.key))
        .toList();

    final total = dossiers.length;
    final complete = dossiers.where((d) => d.isComplete).length;
    final docCount = dossiers.fold<int>(0, (s, d) => s + d.docs.length);
    final verified =
        dossiers.fold<int>(0, (s, d) => s + d.verifiedCount);

    final doc = pw.Document(
      title: 'Dossiers documentaires',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Conformité des dossiers d\'élèves',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.header(logo, f, badge: 'DOSSIERS\nÉLÈVES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'CONFORMITÉ DES DOSSIERS',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Dossiers documentaires',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves', '$total', kPdfNavy),
          PdfKpi('Dossiers complets', '$complete', kPdfGreen),
          PdfKpi('Pièces déposées', '$docCount',
              const PdfColor.fromInt(0xFF0EA5E9)),
          PdfKpi('Pièces vérifiées', '$verified', kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        if (dossiers.isEmpty)
          OfficialPdfKit.empty('Aucun élève à exporter.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'REGISTRE DE CONFORMITÉ',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: [
                'Élève',
                'Classe',
                for (final e in required) _short(e.value),
                'Dossier',
              ],
              rows: [
                for (final d in dossiers)
                  [
                    d.student.lastFirst,
                    d.student.className ?? '—',
                    for (final e in required)
                      d.presentTypes.contains(e.key)
                          ? (d.docs.any((x) =>
                                  x.documentType == e.key && x.isVerified)
                              ? '✓ vérifié'
                              : 'déposé')
                          : '—',
                    d.isComplete ? 'COMPLET' : 'Incomplet',
                  ],
              ],
              fonts: f,
              flex: [4, 2, for (final _ in required) 2, 2],
              leftAlignCols: const {0},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  // Libellé court pour l'en-tête de colonne (pièce exigée).
  static String _short(String label) => switch (label) {
        "Extrait d'acte de naissance" => 'Acte naiss.',
        "Photo d'identité" => 'Photo',
        'Certificat médical de bonne santé' => 'Cert. méd.',
        _ => label,
      };

  static Future<String?> downloadDoc({
    required List<StudentDossier> dossiers,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes = await buildPdf(
        dossiers: dossiers, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Dossiers_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les dossiers',
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
