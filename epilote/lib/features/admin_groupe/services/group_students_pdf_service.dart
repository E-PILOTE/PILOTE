import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_students_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LISTE D'ÉLÈVES DU RÉSEAU — document de travail du cabinet.
//
//  Le dossier individuel répond « qui est cet élève ? » ; cette liste-ci répond
//  « qui sont-ils, et combien ? ». C'est la pièce qu'on emporte en réunion.
//
//  Deux mentions sont NON NÉGOCIABLES sur ce document :
//   • le PÉRIMÈTRE — les filtres qui l'ont produit, écrits noir sur blanc ;
//   • la TRONCATURE — si la recherche a buté sur le plafond, le total imprimé
//     n'est PAS l'effectif réel, et le document doit le dire lui-même. Une
//     liste tronquée en silence deviendrait un chiffre officiel faux.
// ════════════════════════════════════════════════════════════════════════════
class GroupStudentsPdfService {
  static Future<Uint8List> buildPdf({
    required String groupName,
    required List<GroupStudent> rows,
    required StudentQuery query,
    required bool truncated,
    String? schoolLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final girls = rows.where((s) => s.isFemale).length;
    final unplaced = rows.where((s) => s.isUnplaced).length;
    final schools = rows.map((s) => s.schoolName).toSet().length;
    final share = rows.isEmpty ? null : girls / rows.length * 100;

    final criteria = <(String, String)>[
      ...query.activeFilters,
      if (schoolLabel != null) ('Établissement', schoolLabel),
    ];

    final doc = pw.Document(
      title: 'Élèves du réseau — $groupName',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Liste d\'élèves du réseau',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'ÉLÈVES\nDU RÉSEAU',
          title: 'Liste des élèves — $groupName'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: 'Liste des élèves',
          line1: 'Périmètre : ${_scope(criteria)}',
          line2: query.activeOnly
              ? 'Élèves actifs — situation scolaire de l\'année en cours'
              : 'Élèves actifs et inactifs',
          statusBadge: truncated ? 'EXTRAIT' : '${rows.length} ÉLÈVES',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Élèves listés', '${rows.length}', kPdfNavy),
          PdfKpi('Part de filles',
              share == null ? '—' : '${share.toStringAsFixed(0)} %', kPdfGold),
          PdfKpi('Établissements', '$schools', kPdfNavyL),
          PdfKpi('Sans classe', '$unplaced',
              unplaced == 0 ? kPdfGreen : kPdfRed),
        ]),
        pw.SizedBox(height: 16),
        if (truncated) ...[
          _warning(
            'Liste tronquée : la recherche a dépassé le plafond de '
            '$kStudentSearchLimit résultats. Les ${rows.length} premiers élèves '
            '(ordre alphabétique) figurent seuls ci-dessous — ce total n\'est '
            'pas l\'effectif du périmètre.',
            f,
          ),
          pw.SizedBox(height: 12),
        ],
        if (rows.isEmpty)
          OfficialPdfKit.frame(
            title: 'ÉLÈVES',
            color: kPdfNavy,
            fonts: f,
            child: _note('Aucun élève ne correspond à ce périmètre.', f),
          )
        else
          // Un bloc par page : `frame()` enveloppe la table dans un `Padding`,
          // qui ne sait pas se scinder. Lui passer 200 lignes d'un coup fait
          // boucler `MultiPage` jusqu'à `TooManyPagesException`. On découpe
          // donc nous-mêmes — et l'en-tête de colonnes se répète à chaque page,
          // ce qu'une liste de plusieurs pages exige de toute façon.
          for (final chunk in _paginate(rows)) ...[
            // Saut de page explicite avant chaque bloc de suite : sans lui, le
            // titre « (suite) » reste en bas de la page précédente pendant que
            // son tableau part à la suivante — un intertitre orphelin au-dessus
            // d'une demi-page blanche.
            if (!identical(chunk.first, rows.first)) pw.NewPage(),
            OfficialPdfKit.frame(
              title: identical(chunk.first, rows.first)
                  ? 'ÉLÈVES'
                  : 'ÉLÈVES (suite)',
              color: kPdfNavy,
              fonts: f,
              child: OfficialPdfKit.table(
                headers: const [
                  'Élève',
                  'Matricule',
                  'Établissement',
                  'Filière',
                  'Classe',
                  'Âge',
                ],
                // Le matricule a une longueur fixe (« MAT-04-022ok ») : lui
                // laisser 14 % volait de la place aux noms d'établissements,
                // qui sont la colonne la plus longue du réseau.
                flex: const [23, 11, 27, 19, 13, 7],
                leftAlignCols: const {0, 1, 2, 3, 4},
                fonts: f,
                rows: [
                  for (final s in chunk)
                    [
                      _fit(s.fullName, 23),
                      _fit(s.matricule, 12),
                      _fit(s.schoolName, 26),
                      _fit(s.filiere, 21),
                      _fit(s.className ?? 'sans classe', 12),
                      s.age == null ? '—' : '${s.age}',
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
                    'La classe et la filière indiquées sont celles de '
                    'l\'inscription de l\'année scolaire en cours.',
                    f),
                if (unplaced > 0)
                  _line(
                      '$unplaced élève${unplaced > 1 ? 's' : ''} '
                      '${unplaced > 1 ? 'sont' : 'est'} enregistré'
                      '${unplaced > 1 ? 's' : ''} sans affectation de classe '
                      'pour l\'année en cours.',
                      f,
                      color: kPdfRed),
                _line(
                    'Document de gestion à usage interne. Il ne comporte ni '
                    'donnée médicale, ni donnée disciplinaire.',
                    f),
              ],
            ),
          ),
        ),
      ],
    ));

    return doc.save();
  }

  /// Écrête une cellule à la largeur réelle de sa colonne, avec un « … ».
  ///
  /// Le kit borne déjà chaque cellule à une ligne — sans quoi un cadre trop
  /// haut bloquerait tout le document. Mais cette coupe-là est MUETTE :
  /// « Complexe Scolaire Les Aiglons » ressortait « Complexe Scolaire Les »,
  /// ce qui se lit comme un nom d'école faux. On écrête donc nous-mêmes, un cran
  /// avant, pour que la troncature se voie.
  static String _fit(String? s, int max) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return '—';
    return v.length <= max ? v : '${v.substring(0, max - 1)}…';
  }

  /// Première page réduite (titre, KPI et éventuel avertissement de troncature
  /// l'occupent déjà à moitié), pages suivantes pleines.
  ///
  /// Bornes mesurées, pas estimées : un bloc trop haut ne se scinde pas, il
  /// bloque tout le document (test `group_students_pdf_test.dart`, qui génère
  /// vraiment 200 lignes à rallonge). Les pages suivantes en portent davantage
  /// parce qu'elles n'ont qu'un filet de continuation en tête, pas le bandeau
  /// complet. Marge volontaire de deux lignes.
  static List<List<GroupStudent>> _paginate(List<GroupStudent> rows) =>
      OfficialPdfKit.paginate(rows, first: 12, next: 26);

  static String _scope(List<(String, String)> criteria) => criteria.isEmpty
      ? 'ensemble du réseau'
      : criteria.map((c) => '${c.$1} = ${c.$2}').join('  •  ');

  static pw.Widget _warning(String text, PdfFonts f) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: kPdfGold, width: 0.8),
          ),
          child: pw.Text(text,
              style:
                  pw.TextStyle(font: f.medium, fontSize: 8.5, color: kPdfText)),
        ),
      );

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

  // ── Téléchargement ────────────────────────────────────────────────────────
  static Future<String?> download({
    required String groupName,
    required List<GroupStudent> rows,
    required StudentQuery query,
    required bool truncated,
    String? schoolLabel,
  }) async {
    final bytes = await buildPdf(
      groupName: groupName,
      rows: rows,
      query: query,
      truncated: truncated,
      schoolLabel: schoolLabel,
    );
    final fileName =
        'Eleves_reseau_${_slug(groupName)}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la liste',
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
