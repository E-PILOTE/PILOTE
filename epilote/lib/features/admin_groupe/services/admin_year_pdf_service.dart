import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/official_pdf_kit.dart';

import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_year_analytics_provider.dart';

// ─── Couleurs PDF (alignées sur les autres documents officiels) ───────────────
const _navy = PdfColor.fromInt(0xFF1E3A5F);
const _navyL = PdfColor.fromInt(0xFF2A4E7A);
const _green = PdfColor.fromInt(0xFF009A44);
const _gold = PdfColor.fromInt(0xFFFBBC04);
const _red = PdfColor.fromInt(0xFFDC143C);
const _purple = PdfColor.fromInt(0xFF7C3AED);
const _muted = PdfColor.fromInt(0xFF64748B);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _surface = PdfColor.fromInt(0xFFF0F4F8);
const _text = PdfColor.fromInt(0xFF0F172A);

// ══════════════════════════════════════════════════════════════════════════════
//  Service : BILAN OFFICIEL d'une année scolaire (groupe).
//  Synthèse + évolution pluriannuelle + ventilations département / type / école.
//  Style officiel : bandeau tricolore, emblème, en-tête « RÉPUBLIQUE DU CONGO ».
// ══════════════════════════════════════════════════════════════════════════════
class AcademicYearPdfService {
  static Future<Uint8List> buildPdf({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    // Polices EMBARQUÉES (assets/fonts) — cf. OfficialPdfKit.loadFonts().
    // `PdfGoogleFonts` allait les chercher sur fonts.gstatic.com et, en cas
    // d'échec, retombait SANS BRUIT sur Helvetica : sur un poste hors ligne —
    // le cas normal d'une école congolaise — le document officiel sortait dans
    // une police de secours sans Unicode, et nul ne le voyait avant impression.
    final polices = await OfficialPdfKit.loadFonts();
    final fontRegular = polices.regular;
    final fontBold = polices.bold;
    final fontMedium = polices.medium;

    pw.MemoryImage? logoImage;
    final logoBytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    if (logoBytes != null) logoImage = pw.MemoryImage(logoBytes);

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_ = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final range =
        '${fmtDateL.format(year.startDate)} au ${fmtDateL.format(year.endDate)}';

    final doc = pw.Document(
      title: 'Bilan ${year.label}',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: "Bilan de l'année scolaire ${year.label}",
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) =>
          _header(logoImage, fontBold, fontMedium, fontRegular),
      footer: (ctx) => _footer(ctx, fontRegular, fontMedium, now, ref_),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _titleBlock(year, range, fmtDateL.format(DateTime.now()), fontBold,
            fontMedium, fontRegular),
        pw.SizedBox(height: 16),
        _kpiGrid(year, analytics, fontBold, fontRegular),
        pw.SizedBox(height: 16),
        _evolutionSection(allYears, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        ..._deptSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        _typeSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 14),
        ..._schoolsSection(analytics, fontBold, fontMedium, fontRegular),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  // ── En-tête officiel ───────────────────────────────────────────────────────
  static pw.Widget _header(pw.ImageProvider? logo, pw.Font bold, pw.Font medium,
      pw.Font regular) {
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 5, color: _green)),
        pw.Expanded(child: pw.Container(height: 5, color: _gold)),
        pw.Expanded(child: pw.Container(height: 5, color: _red)),
      ]),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
        color: PdfColors.white,
        child: pw.Row(children: [
          logo != null
              ? pw.SizedBox(width: 54, height: 54, child: pw.Image(logo))
              : pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                      color: _navy,
                      borderRadius: pw.BorderRadius.circular(10)),
                  alignment: pw.Alignment.center,
                  child: pw.Text('EP',
                      style: pw.TextStyle(
                          font: bold, fontSize: 18, color: PdfColors.white)),
                ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉPUBLIQUE DU CONGO',
                    style: pw.TextStyle(
                        font: medium,
                        fontSize: 7.5,
                        color: _muted,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 2),
                pw.Text('E-PILOTE CONGO',
                    style:
                        pw.TextStyle(font: bold, fontSize: 16, color: _navy)),
                pw.Text('Plateforme Nationale de Gestion Scolaire',
                    style: pw.TextStyle(
                        font: regular, fontSize: 9, color: _muted)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _surface,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('BILAN\nANNÉE SCOLAIRE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: _navy,
                    letterSpacing: 0.8)),
          ),
        ]),
      ),
      pw.Container(
        height: 2,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navyL, PdfColors.white]),
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _footer(pw.Context ctx, pw.Font regular, pw.Font medium,
      String now, String ref_) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text(
            'Document officiel généré le $now  •  E-PILOTE CONGO  •  Réf. $ref_',
            style: pw.TextStyle(font: regular, fontSize: 7.5, color: _muted),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
              color: _navy, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: medium, fontSize: 7.5, color: PdfColors.white)),
        ),
      ]),
    );
  }

  // ── Bloc titre ───────────────────────────────────────────────────────────────
  static pw.Widget _titleBlock(AdminYear year, String range, String genDate,
      pw.Font bold, pw.Font medium, pw.Font regular) {
    final status = year.isLocked
        ? 'Archivée'
        : year.isCurrent
            ? 'En cours'
            : year.startDate.isAfter(DateTime.now())
                ? 'À venir'
                : 'Passée';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("BILAN DE L'ANNÉE SCOLAIRE",
                      style: pw.TextStyle(
                          font: medium,
                          fontSize: 8,
                          color: _muted,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 3),
                  pw.Text(year.label,
                      style: pw.TextStyle(
                          font: bold, fontSize: 20, color: _navy)),
                  pw.SizedBox(height: 4),
                  pw.Text('Période : $range',
                      style: pw.TextStyle(
                          font: regular, fontSize: 9.5, color: _text)),
                  pw.Text('Édité le $genDate',
                      style: pw.TextStyle(
                          font: regular, fontSize: 8.5, color: _muted)),
                ],
              ),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                  color: _navy, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text(status,
                  style: pw.TextStyle(
                      font: bold, fontSize: 9, color: PdfColors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grille KPI ─────────────────────────────────────────────────────────────
  static pw.Widget _kpiGrid(AdminYear year, AdminYearAnalytics a, pw.Font bold,
      pw.Font regular) {
    final adopt = year.schoolsTotal == 0
        ? 0
        : (year.schoolsAdopted / year.schoolsTotal * 100).round();
    // Les compteurs viennent de `year`, c'est-à-dire d'un GROUP BY Postgres
    // rendu en UNE ligne — et non de la somme de `a.bySchool`, qui en compte
    // une par établissement et que PostgREST tronque SANS ERREUR au-delà de
    // `max-rows`. Sommer la liste ferait diverger le document officiel de
    // l'écran qui l'a commandé, lequel lit déjà `year`. Un bilan national qui
    // se contredit lui-même vaut moins que pas de bilan du tout.
    final moyenne = year.classes == 0 ? 0.0 : year.eleves / year.classes;
    final cells = <List<dynamic>>[
      ['Élèves inscrits', '${year.eleves}', _green],
      ['Classes ouvertes', '${year.classes}', _navy],
      ['Écoles préparées', '${year.schoolsAdopted}/${year.schoolsTotal}', _gold],
      ["Taux d'adoption", '$adopt %', _navy],
      ['Départements couverts', '${a.departementsCouverts}', _purple],
      ['Moy. élèves / classe', moyenne.toStringAsFixed(1), _green],
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cells.map((c) {
          return pw.Container(
            width: 167,
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 22, height: 3, color: c[2] as PdfColor),
                pw.SizedBox(height: 8),
                pw.Text(c[1] as String,
                    style: pw.TextStyle(
                        font: bold, fontSize: 18, color: c[2] as PdfColor)),
                pw.SizedBox(height: 2),
                pw.Text(c[0] as String,
                    style: pw.TextStyle(
                        font: regular, fontSize: 8.5, color: _muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Évolution pluriannuelle ──────────────────────────────────────────────────
  static pw.Widget _evolutionSection(
      List<AdminYear> years, pw.Font bold, pw.Font medium, pw.Font regular) {
    final chrono = years.reversed.toList();
    return _frame(
      title: 'ÉVOLUTION PLURIANNUELLE',
      color: _navy,
      bold: bold,
      child: _table(
        headers: const ['Année', 'Élèves', 'Classes', 'Écoles préparées'],
        rows: chrono
            .map((y) => [
                  y.label,
                  '${y.eleves}',
                  '${y.classes}',
                  '${y.schoolsAdopted}/${y.schoolsTotal}',
                ])
            .toList(),
        bold: bold,
        medium: medium,
        regular: regular,
        flex: const [3, 2, 2, 3],
      ),
    );
  }

  // ── Pagination des listes longues ────────────────────────────────────────────
  //  ⚠️ `_frame()` enveloppe son contenu dans un `Padding`, et un `Padding` ne
  //  sait PAS se scinder entre deux pages. Confier à un seul cadre un tableau
  //  plus haut qu'une feuille fait boucler `MultiPage` jusqu'à
  //  `TooManyPagesException` : le document ne sort alors pas du tout — pas
  //  « mal paginé », pas « tronqué » : absent, avec un message d'erreur.
  //
  //  Mesuré : le bilan cessait de se générer à partir de 31 établissements.
  //  Les deux plus gros groupes en comptent 14 et 12 aujourd'hui, donc le
  //  défaut ne s'était encore jamais montré ; à la cible de 1 000 écoles, il
  //  aurait rendu le bilan national impossible à éditer. Tout tableau dont le
  //  nombre de lignes n'est pas borné à vue d'œil passe donc par ici et sort en
  //  un cadre par bloc.
  //
  //  28 lignes : la hauteur utile d'une A4 en tient ~32 (ligne ≈ 22,6 pt,
  //  en-tête de tableau et titre de cadre déduits). La marge absorbe les
  //  arrondis de rendu.
  static const int _lignesParBloc = 28;

  static List<List<T>> _paginer<T>(List<T> rows) {
    final out = <List<T>>[];
    for (var i = 0; i < rows.length; i += _lignesParBloc) {
      out.add(rows.sublist(i, (i + _lignesParBloc).clamp(0, rows.length)));
    }
    return out;
  }

  /// Un cadre par bloc. Le titre porte « (2/4) » dès qu'il y en a plusieurs :
  /// une page détachée doit dire de quelle partie du tableau elle vient.
  static List<pw.Widget> _sectionPaginee({
    required String title,
    required PdfColor color,
    required List<String> headers,
    required List<int> flex,
    required List<List<String>> rows,
    required String vide,
    required pw.Font bold,
    required pw.Font medium,
    required pw.Font regular,
  }) {
    if (rows.isEmpty) {
      return [
        _frame(
            title: title,
            color: color,
            bold: bold,
            child: _empty(vide, regular)),
      ];
    }
    final blocs = _paginer(rows);
    return [
      for (var i = 0; i < blocs.length; i++) ...[
        if (i > 0) pw.SizedBox(height: 10),
        _frame(
          title: blocs.length == 1 ? title : '$title (${i + 1}/${blocs.length})',
          color: color,
          bold: bold,
          child: _table(
            headers: headers,
            rows: blocs[i],
            bold: bold,
            medium: medium,
            regular: regular,
            flex: flex,
          ),
        ),
      ],
    ];
  }

  // ── Répartition par département ──────────────────────────────────────────────
  //  Le Congo compte 12 départements : le cas normal tient sur un bloc. La
  //  pagination couvre le cas sale — `schools.department` est du texte libre, et
  //  une poignée de saisies fautives suffirait à en faire lever cinquante.
  static List<pw.Widget> _deptSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    return _sectionPaginee(
      title: 'RÉPARTITION PAR DÉPARTEMENT',
      color: _green,
      headers: const ['Département', 'Écoles préparées', 'Classes', 'Élèves'],
      flex: const [4, 3, 2, 2],
      rows: a.byDepartment
          .map((d) => [
                d.department,
                '${d.ecolesPreparees}/${d.ecoles}',
                '${d.classes}',
                '${d.eleves}',
              ])
          .toList(),
      vide: 'Aucune donnée par département.',
      bold: bold,
      medium: medium,
      regular: regular,
    );
  }

  // ── Type d'établissement ─────────────────────────────────────────────────────
  static pw.Widget _typeSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    String label(String t) => switch (t) {
          'public' => 'Public',
          'prive' => 'Privé',
          _ => t.isEmpty ? 'Autre' : t,
        };
    return _frame(
      title: "TYPE D'ÉTABLISSEMENT",
      color: _gold,
      bold: bold,
      child: a.byType.isEmpty
          ? _empty('Aucune donnée par type.', regular)
          : _table(
              headers: const ['Type', 'Écoles', 'Classes', 'Élèves'],
              rows: a.byType
                  .map((t) => [
                        label(t.type),
                        '${t.ecoles}',
                        '${t.classes}',
                        '${t.eleves}',
                      ])
                  .toList(),
              bold: bold,
              medium: medium,
              regular: regular,
              flex: const [4, 2, 2, 2],
            ),
    );
  }

  // ── Préparation par école ────────────────────────────────────────────────────
  //  La liste qui dicte la taille du document : une ligne par établissement du
  //  groupe, donc jusqu'à 1 000 à la cible nationale.
  static List<pw.Widget> _schoolsSection(AdminYearAnalytics a, pw.Font bold,
      pw.Font medium, pw.Font regular) {
    return _sectionPaginee(
      title: 'PRÉPARATION PAR ÉTABLISSEMENT',
      color: _purple,
      headers: const [
        'Établissement',
        'Département',
        'Classes',
        'Élèves',
        'État',
      ],
      flex: const [5, 4, 2, 2, 3],
      rows: a.bySchool
          .map((s) => [
                s.name,
                s.department,
                '${s.classes}',
                '${s.eleves}',
                s.adopted ? 'Préparée' : 'En attente',
              ])
          .toList(),
      vide: 'Aucune école active.',
      bold: bold,
      medium: medium,
      regular: regular,
    );
  }

  // ── Helpers de mise en page ──────────────────────────────────────────────────
  static pw.Widget _frame({
    required String title,
    required PdfColor color,
    required pw.Font bold,
    required pw.Widget child,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: pw.Row(children: [
              pw.Container(
                  width: 4,
                  height: 13,
                  decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 7),
              pw.Text(title,
                  style: pw.TextStyle(
                      font: bold,
                      fontSize: 11,
                      color: _text,
                      letterSpacing: 0.5)),
            ]),
          ),
          child,
        ],
      ),
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> flex,
    required pw.Font bold,
    required pw.Font medium,
    required pw.Font regular,
  }) {
    pw.Widget cell(String t, int f, pw.Font font, int i, int n,
        {PdfColor color = _text, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Expanded(
        flex: f,
        child: pw.Padding(
          // Gouttière entre colonnes. Sans elle, une valeur qui remplit sa
          // colonne vient coller à la suivante et les deux se lisent comme un
          // seul mot. Rien après la dernière, qui longe déjà le bord du cadre.
          padding: pw.EdgeInsets.only(right: i == n - 1 ? 0 : 6),
          // `maxLines: 1` n'est pas cosmétique. « Complexe Scolaire
          // Départemental Étoile du Nord de Ouesso » ne tient pas dans sa
          // colonne : sans écrêtage il passe sur deux lignes, la ligne du
          // tableau grandit, le bloc dépasse la hauteur d'une page — et comme
          // `_frame()` l'enveloppe dans un `Padding` incapable de se scinder,
          // `MultiPage` boucle jusqu'à `TooManyPagesException`. Le document ne
          // sort alors PAS. Une ligne du tableau = une ligne de hauteur, quel
          // que soit le contenu : c'est ce qui rend la pagination calculable.
          child: pw.Text(t,
              textAlign: align,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(font: font, fontSize: 8.5, color: color)),
        ),
      );
    }

    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
            color: _surface, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
          children: List.generate(headers.length, (i) {
            return cell(headers[i].toUpperCase(), flex[i], medium, i,
                headers.length,
                color: _muted,
                align: i == 0 ? pw.TextAlign.left : pw.TextAlign.center);
          }),
        ),
      ),
      ...rows.map((r) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6)),
            ),
            child: pw.Row(
              children: List.generate(r.length, (i) {
                return cell(r[i], flex[i], i == 0 ? medium : regular, i, r.length,
                    color: i == 0 ? _text : _muted,
                    align: i == 0 ? pw.TextAlign.left : pw.TextAlign.center);
              }),
            ),
          )),
    ]);
  }

  static pw.Widget _empty(String text, pw.Font font) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _surface, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: 9, color: _muted)),
      );

  static Future<Uint8List?> _rasterizeSvg(String asset, double size) async {
    try {
      final raw = await rootBundle.loadString(asset);
      final info = await vg.loadPicture(SvgStringLoader(raw), null);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(size / info.size.width);
      canvas.drawPicture(info.picture);
      final image =
          await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      info.picture.dispose();
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ── Impression / téléchargement ────────────────────────────────────────────
  static Future<void> printReport({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) =>
          buildPdf(year: year, analytics: analytics, allYears: allYears),
      name: 'Bilan_${_slug(year.label)}.pdf',
    );
  }

  static Future<String?> downloadReport({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
  }) async {
    final bytes =
        await buildPdf(year: year, analytics: analytics, allYears: allYears);
    final fileName = 'Bilan_${_slug(year.label)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Enregistrer le bilan de l'année",
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    if (savePath != null) {
      final f = File(savePath);
      if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
    }
    return savePath;
  }
}
