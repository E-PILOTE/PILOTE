import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_merit_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PALMARÈS NATIONAL — document officiel.
//
//  C'est la pièce qu'une commission de bourses emporte en séance : elle doit
//  porter son PÉRIMÈTRE (quel examen, quelle filière, quel département) et son
//  ASSIETTE (combien d'admis au total, combien de non classés). Un classement
//  sans ces deux mentions n'est pas opposable — on ne saurait pas ce qu'il
//  compare ni qui il a écarté.
// ════════════════════════════════════════════════════════════════════════════
class MeritPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required List<RankedMerit> rows,
    required MeritFilter filter,
    required MeritData data,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final share = femaleShare(rows);
    final schools = rows.map((r) => r.entry.schoolId).toSet().length;

    final doc = pw.Document(
      title: 'Palmarès national — $groupName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Palmarès des lauréats aux examens d\'État',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'PALMARÈS\nNATIONAL',
          title: 'Palmarès des lauréats — $groupName'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: 'Palmarès des lauréats',
          line1: 'Périmètre : ${filter.scopeLabel}',
          line2: data.yearLabel == null
              ? 'Classement établi sur la moyenne obtenue à l\'examen d\'État'
              : 'Session ${data.yearLabel} — classement établi sur la moyenne '
                  'obtenue à l\'examen d\'État',
          statusBadge: 'TOP ${filter.topN}',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Lauréats classés', '${rows.length}', kPdfNavy),
          PdfKpi('Admis du réseau', '${data.admittedTotal}', kPdfGreen),
          PdfKpi('Établissements', '$schools', kPdfNavyL),
          PdfKpi('Part de filles',
              share == null ? '—' : '${share.toStringAsFixed(0)} %', kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        if (rows.isEmpty)
          OfficialPdfKit.frame(
            title: 'CLASSEMENT',
            color: kPdfNavy,
            fonts: f,
            child: _note('Aucun lauréat ne correspond à ce périmètre.', f),
          )
        else
          // Un « Top 50 » dépasse la page : sans découpage, `MultiPage` boucle
          // et le palmarès ne s'imprime pas du tout (cf. OfficialPdfKit.paginate).
          for (final chunk
              in OfficialPdfKit.paginate(rows, first: 10, next: 26)) ...[
            // Cf. group_students_pdf_service : sans saut explicite, l'intertitre
            // « (suite) » reste orphelin en bas de la page précédente.
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
                  'Lauréat',
                  'Établissement',
                  'Filière',
                  'Dépt.',
                  'Moy.',
                  'Mention',
                ],
                flex: const [7, 22, 24, 20, 13, 8, 14],
                leftAlignCols: const {1, 2, 3, 4},
                fonts: f,
                rows: [
                  for (final r in chunk)
                    [
                      r.exAequo ? '${r.rank} ex æquo' : '${r.rank}',
                      // Écrêtage : une cellule qui passe sur deux lignes fait
                      // déborder le cadre, et un cadre qui déborde bloque tout
                      // le document (cf. OfficialPdfKit.paginate).
                      _fit(r.entry.fullName, 21),
                      _fit(r.entry.schoolName, 23),
                      _fit(r.entry.filiere, 19),
                      _fit(r.entry.department, 12),
                      r.entry.average.toStringAsFixed(2),
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
                    'Le classement repose sur la moyenne obtenue à l\'examen '
                    'd\'État — épreuve commune à tous les établissements, donc '
                    'seule base comparable entre eux.',
                    f),
                _line(
                    'Les moyennes de contrôle continu ne sont pas retenues : '
                    'elles ne sont pas comparables d\'un établissement à '
                    'l\'autre.',
                    f),
                _line(
                    'Ce palmarès ne porte que sur ${filter.exam ?? 'un examen'} : '
                    'les moyennes d\'examens différents ne se comparent pas '
                    'entre elles. Un classement par examen fait l\'objet d\'un '
                    'document distinct.',
                    f),
                if (data.unranked > 0)
                  _line(
                      '${data.unranked} admis ne figurent pas au classement : '
                      'leur moyenne n\'est pas encore saisie.',
                      f,
                      color: kPdfRed),
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

  /// Écrête une cellule pour qu'elle tienne sur UNE ligne — la hauteur d'un
  /// bloc doit rester prévisible.
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

  // ── Téléchargement ──────────────────────────────────────────────────────────
  static Future<String?> download({
    required String groupName,
    required List<RankedMerit> rows,
    required MeritFilter filter,
    required MeritData data,
  }) async {
    final bytes = await buildPdf(
        groupName: groupName, rows: rows, filter: filter, data: data);
    final fileName =
        'Palmares_national_${_slug(groupName)}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le palmarès',
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
