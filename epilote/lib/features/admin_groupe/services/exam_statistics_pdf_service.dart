import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STATISTIQUES ANNUELLES D'UN EXAMEN D'ÉTAT — document officiel.
//
//  Le format est celui que le ministère publie déjà chaque année : un taux
//  national comparé à la session précédente, puis le CLASSEMENT ORDINAL des
//  départements. On ne réinvente pas une présentation : on rend imprimable
//  celle qui fait foi.
//
//  Trois mentions non négociables, sans lesquelles le document tromperait :
//   • LA SOURCE — ces chiffres viennent de la DEC. La plateforme ne calcule
//     aucun résultat d'examen ; elle transmet la liste des candidats et
//     conserve ce qui est publié en retour.
//   • LE DÉNOMINATEUR — le taux porte sur les PRÉSENTS. Sur les inscrits, le
//     même examen afficherait un autre chiffre.
//   • L'UNITÉ D'ÉVOLUTION — des POINTS de pourcentage, jamais un « % de
//     hausse » qui gonflerait optiquement toute progression.
// ════════════════════════════════════════════════════════════════════════════
class ExamStatisticsPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required ExamHistory history,
    required List<DepartmentStanding> standings,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final last = history.latest;
    final year = last?.yearLabel ?? '—';
    final exam = history.examShortName;
    final gain = history.totalGain;

    final doc = pw.Document(
      title: 'Statistiques $exam $year — $groupName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Résultats officiels publiés par la DEC',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'RÉSULTATS\nOFFICIELS',
          title: 'Statistiques $exam · session $year'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: 'Résultats de l\'examen $exam — session $year',
          line1: 'Chiffres publiés par la Direction des Examens et Concours',
          line2: 'Taux de réussite calculés sur les candidats PRÉSENTS ; '
              'les absents sont exclus du dénominateur',
          statusBadge: 'SESSION $year',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Taux national',
              last == null ? '—' : '${last.rate.toStringAsFixed(2)} %',
              kPdfNavy),
          PdfKpi('Admis', last == null ? '—' : '${last.admitted}', kPdfGreen),
          PdfKpi('Présents', last == null ? '—' : '${last.present}', kPdfNavyL),
          PdfKpi(
              'Évolution',
              last?.deltaPoints == null
                  ? '—'
                  : '${last!.deltaPoints! >= 0 ? '+' : ''}'
                      '${last.deltaPoints!.toStringAsFixed(2)} pt',
              kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        if (history.points.length > 1)
          OfficialPdfKit.frame(
            title: 'TRAJECTOIRE NATIONALE',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'Session',
                'Présents',
                'Admis',
                'Taux',
                'Évolution',
              ],
              flex: const [24, 19, 19, 19, 19],
              leftAlignCols: const {0},
              fonts: f,
              rows: [
                for (final p in history.points)
                  [
                    p.yearLabel,
                    '${p.present}',
                    '${p.admitted}',
                    '${p.rate.toStringAsFixed(2)} %',
                    p.deltaPoints == null
                        // Première session : rien à comparer. « +0,00 » y
                        // ferait croire à une stagnation mesurée.
                        ? 'référence'
                        : '${p.deltaPoints! >= 0 ? '+' : ''}'
                            '${p.deltaPoints!.toStringAsFixed(2)} pt',
                  ],
              ],
            ),
          ),
        pw.SizedBox(height: 14),
        if (standings.isNotEmpty)
          // Un bloc par page : un cadre plus haut qu'une page bloquerait tout
          // le document (cf. OfficialPdfKit.paginate).
          for (final chunk
              in OfficialPdfKit.paginate(standings, first: 16, next: 26)) ...[
            if (!identical(chunk.first, standings.first)) pw.NewPage(),
            OfficialPdfKit.frame(
              title: identical(chunk.first, standings.first)
                  ? 'CLASSEMENT DÉPARTEMENTAL · $year'
                  : 'CLASSEMENT DÉPARTEMENTAL (suite)',
              color: kPdfGold,
              fonts: f,
              child: OfficialPdfKit.table(
                headers: const [
                  'Rang',
                  'Département',
                  'Présents',
                  'Admis',
                  'Taux',
                  'Évolution',
                ],
                flex: const [9, 28, 15, 15, 16, 17],
                leftAlignCols: const {1},
                fonts: f,
                rows: [
                  for (final s in chunk)
                    [
                      '${s.rank}',
                      s.department,
                      s.present == null ? '—' : '${s.present}',
                      s.admitted == null ? '—' : '${s.admitted}',
                      '${s.rate.toStringAsFixed(2)} %',
                      s.deltaPoints == null
                          ? '—'
                          : '${s.deltaPoints! >= 0 ? '+' : ''}'
                              '${s.deltaPoints!.toStringAsFixed(2)} pt',
                    ],
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        pw.SizedBox(height: 4),
        OfficialPdfKit.frame(
          title: 'PORTÉE DU DOCUMENT',
          color: kPdfGreen,
          fonts: f,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: kPdfSurface,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: kPdfBorder),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _line(
                    'Chiffres relevés sur les publications de la Direction des '
                    'Examens et Concours. La plateforme transmet la liste des '
                    'candidats et conserve les résultats proclamés : elle n\'en '
                    'calcule aucun.',
                    f),
                _line(
                    'Les taux portent sur les candidats PRÉSENTS. Rapportés aux '
                    'inscrits, ils désigneraient un autre chiffre.',
                    f),
                _line(
                    'Les évolutions sont exprimées en POINTS de pourcentage. '
                    'Une progression de 43,64 % à 48,49 % vaut +4,85 points — '
                    'l\'annoncer comme « +11 % » serait exact et trompeur.',
                    f),
                if (gain != null)
                  _line(
                      'De ${history.points.first.yearLabel} a $year, '
                      'l\'examen $exam évolue de '
                      '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)} points.',
                      f,
                      color: gain >= 0 ? kPdfGreen : kPdfText),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        _signature(f),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _line(String text, PdfFonts f, {PdfColor color = kPdfText}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 3,
              height: 3,
              margin: const pw.EdgeInsets.only(top: 4, right: 6),
              decoration: pw.BoxDecoration(
                  color: color, borderRadius: pw.BorderRadius.circular(2)),
            ),
            pw.Expanded(
              child: pw.Text(text,
                  style:
                      pw.TextStyle(font: f.regular, fontSize: 8.5, color: color)),
            ),
          ],
        ),
      );

  static pw.Widget _signature(PdfFonts f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 210,
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(top: pw.BorderSide(color: kPdfBorder, width: 0.8)),
              ),
              child: pw.Text('Le Ministre / L\'autorité compétente',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      font: f.medium, fontSize: 8.5, color: kPdfMuted)),
            ),
          ],
        ),
      );

  static Future<String?> download({
    required String groupName,
    required ExamHistory history,
    required List<DepartmentStanding> standings,
  }) async {
    final bytes = await buildPdf(
        groupName: groupName, history: history, standings: standings);
    final fileName = 'Statistiques_${_slug(history.examShortName)}'
        '_${_slug(history.latest?.yearLabel ?? '')}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer les statistiques',
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
        return savePath;
      }
    } catch (_) {}

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');
