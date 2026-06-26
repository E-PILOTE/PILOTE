import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/annuaire_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Service : ANNUAIRE — répertoire des familles (élève · classe · tuteur
//  principal · lien · téléphones). Chrome partagé OfficialPdfKit.
// ══════════════════════════════════════════════════════════════════════════════
class AnnuairePdfService {
  static Future<Uint8List> buildPdf({
    required List<FamilyRow> families,
    String? schoolName,
    String? yearLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());

    final withContact = families.where((x) => x.hasContact).length;
    final tutorsTotal =
        families.fold<int>(0, (s, x) => s + x.tutorCount);

    final doc = pw.Document(
      title: 'Annuaire des familles',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Répertoire des familles et contacts',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'ANNUAIRE\nFAMILLES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'RÉPERTOIRE DES FAMILLES',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Annuaire des familles',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves', '${families.length}', kPdfNavy),
          PdfKpi('Avec contact', '$withContact', kPdfGreen),
          PdfKpi('Sans contact', '${families.length - withContact}',
              families.length - withContact > 0 ? kPdfRed : kPdfMuted),
          PdfKpi('Tuteurs', '$tutorsTotal',
              const PdfColor.fromInt(0xFF0EA5E9)),
        ]),
        pw.SizedBox(height: 16),
        if (families.isEmpty)
          OfficialPdfKit.empty('Aucune famille à exporter.', f.regular)
        else
          OfficialPdfKit.frame(
            title: 'RÉPERTOIRE',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'Élève',
                'Classe',
                'Contact principal',
                'Lien',
                'Téléphone(s)'
              ],
              rows: [
                for (final x in families)
                  [
                    x.student.lastFirst,
                    x.student.className ?? '—',
                    x.primary?.fullName ?? '— aucun —',
                    x.primary?.relationshipLabel ?? '—',
                    x.phones.isEmpty ? '—' : x.phones.join(' · '),
                  ],
              ],
              fonts: f,
              flex: const [4, 2, 4, 2, 4],
              leftAlignCols: const {0, 2, 4},
            ),
          ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> downloadDoc({
    required List<FamilyRow> families,
    String? schoolName,
    String? yearLabel,
  }) async {
    final bytes = await buildPdf(
        families: families, schoolName: schoolName, yearLabel: yearLabel);
    final fileName =
        'Annuaire_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer l\'annuaire',
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
