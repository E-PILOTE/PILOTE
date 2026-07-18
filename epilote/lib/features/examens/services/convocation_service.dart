import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/exam_candidates_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CONVOCATIONS AUX ÉPREUVES.
//
//  Le document que l'élève apporte le jour de l'examen. Une école en distribue
//  300 d'un coup : d'où l'impression par CLASSE en un seul PDF, une convocation
//  par page. Les imprimer une par une n'est pas une option réaliste.
//
//  ── Pourquoi on imprime même quand tout n'est pas connu ────────────────────
//  Le numéro de candidat et le centre viennent de la DEC, souvent APRÈS que
//  l'école a commencé à distribuer. Refuser d'imprimer bloquerait l'école ;
//  imprimer un champ vide laisserait croire à un oubli. On écrit donc
//  « à compléter » — l'information manquante est visible en tant que telle.
// ══════════════════════════════════════════════════════════════════════════════

const _kToComplete = 'à compléter';

class ConvocationService {
  static String _fmtDate(DateTime? d) =>
      d == null ? _kToComplete : DateFormat('dd MMMM yyyy', 'fr').format(d);

  static String _or(String? v) =>
      (v?.trim().isNotEmpty ?? false) ? v!.trim() : _kToComplete;

  /// Une convocation par candidat, une page chacune, dans un seul document.
  static Future<Uint8List> buildConvocationsPdf({
    required List<ExamCandidateRow> candidates,
    required String examName,
    required String examShortName,
    required String? yearLabel,
    required String? schoolName,
    String? tutelle,
    DateTime? writtenFrom,
    DateTime? writtenTo,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final doc = pw.Document(
      title: 'Convocations — $examShortName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Convocations aux épreuves de $examName',
    );

    for (final c in candidates) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            OfficialPdfKit.header(logo, f, badge: 'CONVOCATION'),
            pw.SizedBox(height: 16),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _body(
                  f,
                  c,
                  examName: examName,
                  examShortName: examShortName,
                  yearLabel: yearLabel,
                  schoolName: schoolName,
                  tutelle: tutelle,
                  writtenFrom: writtenFrom,
                  writtenTo: writtenTo,
                ),
              ),
            ),
            OfficialPdfKit.footer(ctx, f, now, ref),
          ],
        ),
      ));
    }
    return doc.save();
  }

  static pw.Widget _body(
    PdfFonts f,
    ExamCandidateRow c, {
    required String examName,
    required String examShortName,
    required String? yearLabel,
    required String? schoolName,
    String? tutelle,
    DateTime? writtenFrom,
    DateTime? writtenTo,
  }) {
    final period = writtenFrom == null
        ? _kToComplete
        : (writtenTo == null || writtenTo == writtenFrom
            ? _fmtDate(writtenFrom)
            : 'du ${_fmtDate(writtenFrom)} au ${_fmtDate(writtenTo)}');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        OfficialPdfKit.titleBlock(f,
            kicker: '${tutelle?.toUpperCase() ?? ''} · $examShortName'
                '${yearLabel != null ? ' · SESSION $yearLabel' : ''}',
            title: c.fullName,
            line1: examName,
            line2: _or(schoolName)),
        pw.SizedBox(height: 18),
        OfficialPdfKit.frame(
          title: 'LE CANDIDAT',
          color: kPdfNavy,
          fonts: f,
          child: OfficialPdfKit.table(
            headers: const ['Rubrique', 'Information'],
            rows: [
              ['Nom et prénom', c.fullName],
              ['Matricule', _or(c.matricule)],
              ['Né(e) le', _fmtDate(c.dateOfBirth)],
              ['Sexe', c.gender ?? _kToComplete],
              ['Classe', _or(c.className)],
              ['Numéro de candidat', _or(c.candidateNumber)],
            ],
            fonts: f,
            flex: const [5, 11],
            leftAlignCols: const {0, 1},
          ),
        ),
        pw.SizedBox(height: 12),
        OfficialPdfKit.frame(
          title: 'LES ÉPREUVES',
          color: kPdfGreen,
          fonts: f,
          child: OfficialPdfKit.table(
            headers: const ['Rubrique', 'Information'],
            rows: [
              ['Examen', examName],
              ['Session', _or(yearLabel)],
              ['Centre d\'examen', _or(c.centerName)],
              ['Dates des épreuves', period],
            ],
            fonts: f,
            flex: const [5, 11],
            leftAlignCols: const {0, 1},
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kPdfNavy, width: 0.6),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('À SAVOIR',
                  style: pw.TextStyle(
                      font: f.bold, fontSize: 9, color: kPdfNavy)),
              pw.SizedBox(height: 5),
              pw.Text(
                'Le candidat doit se présenter au centre muni de la présente '
                'convocation et d\'une pièce d\'identité, au moins trente '
                'minutes avant le début de la première épreuve. Toute mention '
                '« $_kToComplete » sera précisée par le centre d\'examen.',
                style: pw.TextStyle(
                    font: f.regular, fontSize: 9.5, lineSpacing: 2),
              ),
            ],
          ),
        ),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signature(f, 'Le candidat'),
            _signature(f, 'Le chef d\'établissement'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _signature(PdfFonts f, String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: f.medium, fontSize: 9.5)),
          pw.SizedBox(height: 34),
          pw.Container(width: 150, height: 0.6, color: PdfColors.grey600),
        ],
      );

  static Future<String?> downloadConvocations({
    required List<ExamCandidateRow> candidates,
    required String examName,
    required String examShortName,
    required String? yearLabel,
    required String? schoolName,
    String? tutelle,
    DateTime? writtenFrom,
    DateTime? writtenTo,
    String? fileLabel,
  }) async {
    final bytes = await buildConvocationsPdf(
      candidates: candidates,
      examName: examName,
      examShortName: examShortName,
      yearLabel: yearLabel,
      schoolName: schoolName,
      tutelle: tutelle,
      writtenFrom: writtenFrom,
      writtenTo: writtenTo,
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer les convocations',
      fileName:
          'Convocations_${fileLabel ?? examShortName}_${yearLabel ?? ''}.pdf'
              .replaceAll(' ', '_'),
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }
}
