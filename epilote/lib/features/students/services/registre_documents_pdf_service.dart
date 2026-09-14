import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/registre_provider.dart';
import 'registre_documents.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE DES DÉLIVRANCES, SUR PAPIER
//
//  ⚠️ IL ÉTAIT LE SEUL DES TROIS DOCUMENTS RÉGLEMENTAIRES SANS SORTIE. L'état
//  de rentrée s'imprime, le registre matricule s'imprime — celui-ci, non.
//
//  Or c'est précisément celui qu'on réclame de l'extérieur. Il répond à « qui a
//  délivré ce papier, et quand ? », la question qu'on pose quand un document
//  revient contesté, et celle que l'inspection pose quand elle vient vérifier
//  ce que l'école a émis. Un registre qu'on ne peut pas produire ne prouve rien
//  à celui qui n'a pas accès à l'écran.
//
//  Le document dit CE QUI EST À L'ÉCRAN, filtres compris : un extrait ne doit
//  jamais pouvoir passer pour le registre entier.
// ══════════════════════════════════════════════════════════════════════════════
class RegistreDocumentsPdfService {
  static Future<Uint8List> buildPdf({
    required List<DocumentEmis> lignes,
    String? schoolName,
    String? filtre,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final genDate = DateFormat('dd MMMM yyyy', 'fr').format(DateTime.now());
    final jour = DateFormat('dd/MM/yyyy', 'fr');

    // Le décompte par type : c'est la première question de l'inspection —
    // combien de certificats, combien de cartes.
    final parType = <String, int>{};
    for (final l in lignes) {
      parType[l.documentType] = (parType[l.documentType] ?? 0) + 1;
    }
    final couleurs = [kPdfNavy, kPdfGreen, kPdfGold, kPdfRed];

    final doc = pw.Document(
      title: 'Registre des documents délivrés',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: "Documents officiels émis par l'établissement",
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          OfficialPdfKit.header(logo, f, badge: 'REGISTRE\nDÉLIVRANCES'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'DOCUMENTS DÉLIVRÉS PAR L\'ÉTABLISSEMENT',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Registre des délivrances',
            // ⚠️ Le filtre est ANNONCÉ. Sans cette ligne, un extrait « cartes
            // scolaires, nom contenant Bakala » se présente exactement comme
            // le registre entier — et c'est sur ce papier que quelqu'un
            // conclura qu'un document n'a jamais été délivré.
            line1: filtre?.trim().isNotEmpty ?? false ? filtre!.trim() : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Délivrances', '${lignes.length}', kPdfNavy),
          for (var i = 0; i < parType.length && i < 3; i++)
            PdfKpi(
              libelleTypeDocument(parType.keys.elementAt(i)),
              '${parType.values.elementAt(i)}',
              couleurs[(i + 1) % couleurs.length],
            ),
        ]),
        pw.SizedBox(height: 16),
        // `tableSection` et non `frame(table())` : elle se scinde entre pages
        // et RÉÉMET ses en-têtes à chaque bloc.
        ...OfficialPdfKit.tableSection(
          title: 'REGISTRE DES DÉLIVRANCES',
          color: kPdfNavy,
          fonts: f,
          headers: const [
            'Date',
            'Document',
            'Bénéficiaire',
            'Référence',
            'Délivré par',
            'Motif',
          ],
          rows: [
            for (final l in lignes)
              [
                jour.format(l.issuedAt),
                libelleTypeDocument(l.documentType),
                l.recipientName,
                l.recipientRef ?? '—',
                l.issuedByName ?? '—',
                l.purpose ?? '—',
              ],
          ],
          flex: const [2, 3, 4, 3, 3, 4],
          leftAlignCols: const {1, 2, 3, 4, 5},
          emptyLabel: 'Aucune délivrance sur ce périmètre.',
        ),
        pw.SizedBox(height: 8),
      ],
    ));

    return doc.save();
  }

  static Future<String?> download({
    required List<DocumentEmis> lignes,
    String? schoolName,
    String? filtre,
  }) async {
    final bytes = await buildPdf(
        lignes: lignes, schoolName: schoolName, filtre: filtre);
    final fileName =
        'Registre_delivrances_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le registre des délivrances',
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
