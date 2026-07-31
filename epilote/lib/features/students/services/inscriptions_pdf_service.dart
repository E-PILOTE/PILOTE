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

    // ⚠️ Pas de cartouche « Validées » ici : `inscriptionsDataProvider` exclut
    // `status = 'active'`, donc ce compte vaudrait TOUJOURS zéro. Un document
    // officiel qui annonce « Validées : 0 » en tête se discrédite tout seul.
    // Ce que ce document contient réellement, ce sont les dossiers en instance.
    final rejected = rows.where((r) => r.status == 'rejected').length;
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
      // `headerFor` : l'emblème et le bandeau tricolore n'apparaissent qu'en
      // première page ; les suivantes reçoivent le bandeau de continuation.
      // Répété en entier, l'en-tête officiel mangeait un quart de CHAQUE page
      // et une liste de deux cents élèves ressemblait à dix documents empilés.
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'DOSSIERS\nD\'INSCRIPTION',
          title: yearLabel?.trim().isNotEmpty ?? false
              ? 'Dossiers d\'inscription — ${yearLabel!.trim()}'
              : 'Dossiers d\'inscription'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: 'DOSSIERS D\'INSCRIPTION EN INSTANCE',
            title: schoolName?.trim().isNotEmpty ?? false
                ? schoolName!.trim()
                : 'Dossiers d\'inscription par classe',
            line1: yearLabel?.trim().isNotEmpty ?? false
                ? 'Année scolaire : ${yearLabel!.trim()}'
                : null,
            line2: 'Édité le $genDate'),
        pw.SizedBox(height: 16),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Dossiers', '${rows.length}', kPdfNavy),
          PdfKpi('En attente', '$pending', kPdfGold),
          PdfKpi('Rejetés', '$rejected', kPdfRed),
          PdfKpi('Nouvelles', '$news', const PdfColor.fromInt(0xFF0EA5E9)),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.empty('Aucune inscription à exporter.', f.regular)
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
            flex: const [3, 6, 2, 2, 3, 3],
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
