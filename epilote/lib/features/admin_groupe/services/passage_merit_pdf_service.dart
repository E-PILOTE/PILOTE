import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/passage_merit_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES DES CLASSES DE PASSAGE — document officiel.
//
//  La pièce qu'une commission emporte en séance. Trois mentions y sont NON
//  NÉGOCIABLES, parce que sans elles le classement n'est pas interprétable :
//
//   • LA PÉRIODE — une moyenne n'existe pas hors d'un trimestre. Un tableau
//     sans période ne se rejoue pas et ne se vérifie pas.
//   • LA BASE — ces moyennes sont calculées par les ÉTABLISSEMENTS. Elles ne
//     sont pas des notes d'examen national, et le document doit le dire avant
//     qu'un lecteur ne l'oublie.
//   • LA MOYENNE DE LA CLASSE — colonne obligatoire : 16/20 dans une classe à
//     15 et 16/20 dans une classe à 9 ne désignent pas le même élève.
// ════════════════════════════════════════════════════════════════════════════
class PassageMeritPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required List<RankedPassage> rows,
    required String periodLabel,
    required int evaluatedTotal,
    String? levelCode,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final share = passageFemaleShare(rows);
    final schools = rows.map((r) => r.entry.schoolName).toSet().length;
    final scope = levelCode == null
        ? periodLabel
        : '$periodLabel  •  niveau $levelCode';

    final doc = pw.Document(
      title: 'Meilleurs élèves des classes de passage — $groupName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Classement des classes de passage',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'CLASSES\nDE PASSAGE',
          title: 'Meilleurs élèves des classes de passage — $groupName'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: 'Meilleurs élèves des classes de passage',
          line1: 'Période : $scope',
          line2: 'Moyennes calculées à partir des évaluations publiées par les '
              'établissements — hors classes d\'examen',
          statusBadge: 'TOP ${rows.length}',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves classés', '${rows.length}', kPdfNavy),
          PdfKpi('Évalués', '$evaluatedTotal', kPdfNavyL),
          PdfKpi('Établissements', '$schools', kPdfGreen),
          PdfKpi('Part de filles',
              share == null ? '—' : '${share.toStringAsFixed(0)} %', kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.frame(
            title: 'CLASSEMENT',
            color: kPdfNavy,
            fonts: f,
            child: _note('Aucun élève classé sur ce périmètre.', f),
          )
        else
          // Un bloc par page : cf. OfficialPdfKit.paginate — un cadre plus haut
          // qu'une page bloquerait tout le document.
          for (final chunk
              in OfficialPdfKit.paginate(rows, first: 10, next: 26)) ...[
            if (!identical(chunk.first, rows.first)) pw.NewPage(),
            OfficialPdfKit.frame(
              title: identical(chunk.first, rows.first)
                  ? 'CLASSEMENT'
                  : 'CLASSEMENT (suite)',
              color: kPdfNavy,
              fonts: f,
              child: OfficialPdfKit.table(
                headers: const [
                  'Rang',
                  'Élève',
                  'Établissement',
                  'Classe',
                  'Moy.',
                  'Moy. cl.',
                  'Mention',
                ],
                flex: const [7, 22, 24, 15, 9, 10, 13],
                leftAlignCols: const {1, 2, 3},
                fonts: f,
                rows: [
                  for (final r in chunk)
                    [
                      r.exAequo ? '${r.rank} ex æquo' : '${r.rank}',
                      _fit(r.entry.fullName, 21),
                      _fit(r.entry.schoolName, 23),
                      _fit(r.entry.className, 14),
                      r.entry.average.toStringAsFixed(2),
                      r.entry.classAverage?.toStringAsFixed(2) ?? '—',
                      r.entry.mention,
                    ],
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        pw.SizedBox(height: 4),
        OfficialPdfKit.frame(
          title: 'PORTÉE DU DOCUMENT',
          color: kPdfGold,
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
                    'Classement établi sur $scope, à partir des seules '
                    'évaluations PUBLIÉES par les établissements. Les absences '
                    'sont exclues du calcul, jamais comptées zéro.',
                    f),
                _line(
                    'Ces moyennes sont calculées par les établissements '
                    'eux-mêmes : enseignants, sujets et exigences y diffèrent. '
                    'La moyenne de la classe figure en regard de chaque élève '
                    'pour cette raison — elle seule permet de situer une note.',
                    f),
                _line(
                    'Les classes d\'examen (CM2, 3e, Terminale) ne figurent pas '
                    'ici : leur passage se joue à l\'examen d\'État, dont la '
                    'plateforme transmet la liste des candidats à la DEC sans '
                    'en calculer les résultats.',
                    f),
                _line(
                    'Les ex æquo partagent le même rang ; aucun départage '
                    'arbitraire n\'est opéré.',
                    f),
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

  /// Écrête une cellule pour qu'elle tienne sur une ligne — la hauteur d'un
  /// bloc doit rester prévisible (cf. OfficialPdfKit.paginate).
  static String _fit(String? s, int max) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return '—';
    return v.length <= max ? v : '${v.substring(0, max - 1)}…';
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

  static pw.Widget _note(String text, PdfFonts f) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: kPdfSurface, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(text,
            style: pw.TextStyle(font: f.regular, fontSize: 9, color: kPdfMuted)),
      );

  static pw.Widget _signature(PdfFonts f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 200,
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

  // ── Téléchargement ────────────────────────────────────────────────────────
  static Future<String?> download({
    required String groupName,
    required List<RankedPassage> rows,
    required String periodLabel,
    required int evaluatedTotal,
    String? levelCode,
  }) async {
    final bytes = await buildPdf(
      groupName: groupName,
      rows: rows,
      periodLabel: periodLabel,
      evaluatedTotal: evaluatedTotal,
      levelCode: levelCode,
    );
    final fileName = 'Meilleurs_eleves_passage_${_slug(groupName)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le classement',
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
