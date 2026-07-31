import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ════════════════════════════════════════════════════════════════════════════
//  KIT DOCUMENT OFFICIEL — chrome partagé de tous les exports PDF de l'espace
//  école (bandeau tricolore, emblème, en-tête « RÉPUBLIQUE DU CONGO », pied de
//  page paginé, blocs titre / KPI / cadre / table). Source unique : chaque
//  service PDF n'écrit plus que son CONTENU, pas la mise en page officielle.
// ════════════════════════════════════════════════════════════════════════════

// ─── Palette (alignée sur les documents officiels) ───────────────────────────
const kPdfNavy = PdfColor.fromInt(0xFF1E3A5F);
const kPdfNavyL = PdfColor.fromInt(0xFF2A4E7A);
const kPdfGreen = PdfColor.fromInt(0xFF009A44);
const kPdfGold = PdfColor.fromInt(0xFFFBBC04);
const kPdfRed = PdfColor.fromInt(0xFFDC143C);
const kPdfMuted = PdfColor.fromInt(0xFF64748B);
const kPdfBorder = PdfColor.fromInt(0xFFE2E8F0);
const kPdfSurface = PdfColor.fromInt(0xFFF0F4F8);
const kPdfText = PdfColor.fromInt(0xFF0F172A);

/// Mélange une couleur vers le blanc (l'alpha PDF ne composite pas en aplat :
/// on pré-calcule la teinte). t=0 → blanc, t=1 → couleur pleine.
PdfColor pdfTint(PdfColor c, double t) =>
    PdfColor(c.red * t + (1 - t), c.green * t + (1 - t), c.blue * t + (1 - t));

class PdfFonts {
  const PdfFonts(this.regular, this.medium, this.bold);
  final pw.Font regular, medium, bold;
}

class PdfKpi {
  const PdfKpi(this.label, this.value, this.color);
  final String label, value;
  final PdfColor color;
}

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉMETTEUR DU DOCUMENT
//
//  Un bulletin, une convocation, un procès-verbal sont émis par un
//  ÉTABLISSEMENT — pas par l'éditeur du logiciel. Un parent qui reçoit une
//  fiche d'inscription doit y lire le nom de l'école de son enfant, et un
//  document remonté à la hiérarchie doit porter l'identité de qui le remonte.
//  Tant que l'en-tête annonçait « E-PILOTE CONGO », le papier officiel de
//  chaque école était signé du nom d'un fournisseur.
//
//  E-PILOTE reste mentionné en pied de page : c'est l'outil qui a produit le
//  document, ce n'est pas son auteur.
//
//  L'émetteur est posé UNE FOIS par session (cf. `pdf_issuer.dart`) plutôt que
//  passé aux vingt-trois services d'export : ceux-ci n'ont pas à connaître
//  l'identité de l'établissement pour dessiner leur contenu.
// ════════════════════════════════════════════════════════════════════════════
class PdfIssuer {
  const PdfIssuer({required this.name, this.subtitle, this.logo});

  /// Nom du groupe scolaire (« Groupe Scolaire Bethel »).
  final String name;

  /// Ligne de contexte : l'école, le département, la nature du réseau.
  final String? subtitle;

  /// Logo du groupe, déjà décodé. `null` → l'emblème de l'application sert de
  /// repli : mieux vaut un document sans logo qu'un document qui n'existe pas.
  final pw.MemoryImage? logo;
}

class OfficialPdfKit {
  // ⚠️ Les polices sont EMBARQUÉES, jamais téléchargées.
  //
  //  `PdfGoogleFonts.notoSans*()` va chercher le fichier sur fonts.gstatic.com.
  //  Sur un poste sans réseau — le cas normal d'une école congolaise — et sans
  //  cache, le moteur retombe sur Helvetica, qui NE GÈRE PAS l'Unicode : tous
  //  les accents disparaissent des documents officiels (« Élèves » → « lèves »),
  //  et personne ne s'en aperçoit avant l'impression. Pour un produit
  //  offline-first, la seule position tenable est d'embarquer les fichiers.
  //
  //  Les polices ne sont chargées qu'une fois par session : décoder 1,6 Mo de
  //  TTF à chaque export ralentirait chaque impression pour rien.
  static PdfFonts? _cached;

  static Future<PdfFonts> loadFonts() async {
    final hit = _cached;
    if (hit != null) return hit;

    Future<pw.Font> load(String file) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));

    final fonts = PdfFonts(
      await load('NotoSans-Regular.ttf'),
      await load('NotoSans-Medium.ttf'),
      await load('NotoSans-Bold.ttf'),
    );
    return _cached = fonts;
  }

  static Future<pw.MemoryImage?> loadLogo() async {
    final bytes = await _rasterizeSvg('assets/icons/logo.svg', 320);
    return bytes != null ? pw.MemoryImage(bytes) : null;
  }

  // ── Émetteur courant ───────────────────────────────────────────────────────
  //  Volontairement statique, comme le cache de polices : l'identité de
  //  l'établissement ne change pas d'un export à l'autre au sein d'une session,
  //  et la faire transiter par vingt-trois services d'export n'apporterait rien
  //  qu'une occasion de l'oublier dans l'un d'eux.
  static PdfIssuer? _issuer;

  /// Pose l'émetteur pour toute la session. `null` rétablit l'identité par
  /// défaut (utile au super_admin, qui édite au nom de la plateforme).
  static void setIssuer(PdfIssuer? issuer) => _issuer = issuer;

  static PdfIssuer? get issuer => _issuer;

  static const _kDefaultName = 'E-PILOTE CONGO';
  static const _kDefaultSubtitle = 'Plateforme Nationale de Gestion Scolaire';

  // ── En-tête officiel (bandeau tricolore + emblème + badge) ──────────────────
  static pw.Widget header(pw.ImageProvider? logo, PdfFonts f,
      {required String badge}) {
    // Le logo du groupe prime ; l'emblème passé par le service sert de repli.
    final issuer = _issuer;
    final mark = issuer?.logo ?? logo;
    final name = issuer?.name ?? _kDefaultName;
    final subtitle = issuer?.subtitle ?? _kDefaultSubtitle;
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: pw.Container(height: 5, color: kPdfGreen)),
        pw.Expanded(child: pw.Container(height: 5, color: kPdfGold)),
        pw.Expanded(child: pw.Container(height: 5, color: kPdfRed)),
      ]),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 14),
        color: PdfColors.white,
        child: pw.Row(children: [
          mark != null
              ? pw.SizedBox(width: 54, height: 54, child: pw.Image(mark))
              : pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                      color: kPdfNavy,
                      borderRadius: pw.BorderRadius.circular(10)),
                  alignment: pw.Alignment.center,
                  child: pw.Text('EP',
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 18, color: PdfColors.white)),
                ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RÉPUBLIQUE DU CONGO',
                    style: pw.TextStyle(
                        font: f.medium,
                        fontSize: 7.5,
                        color: kPdfMuted,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 2),
                pw.Text(name,
                    maxLines: 2,
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 16, color: kPdfNavy)),
                pw.Text(subtitle,
                    maxLines: 1,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 9, color: kPdfMuted)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: kPdfSurface,
              border: pw.Border.all(color: kPdfBorder),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(badge,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    font: f.bold,
                    fontSize: 8,
                    color: kPdfNavy,
                    letterSpacing: 0.8)),
          ),
        ]),
      ),
      pw.Container(
        height: 2,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
              colors: [kPdfNavy, kPdfNavyL, PdfColors.white]),
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  // ── En-tête de continuation (pages 2 et suivantes) ──────────────────────────
  //  Répéter l'emblème pleine hauteur sur chaque page mange un quart de la
  //  feuille et fait ressembler une liste de 200 élèves à dix documents
  //  empilés. On ne garde que ce qui rend une page détachée identifiable : le
  //  filet tricolore et l'intitulé du document. La référence et la pagination
  //  restent en pied de page.
  static pw.Widget continuationHeader(PdfFonts f, {required String title}) =>
      pw.Column(children: [
        pw.Row(children: [
          pw.Expanded(child: pw.Container(height: 3, color: kPdfGreen)),
          pw.Expanded(child: pw.Container(height: 3, color: kPdfGold)),
          pw.Expanded(child: pw.Container(height: 3, color: kPdfRed)),
        ]),
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(28, 7, 28, 7),
          decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: kPdfBorder, width: 0.8)),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(title,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                      font: f.medium, fontSize: 8, color: kPdfNavy)),
            ),
            pw.Text(_issuer?.name ?? _kDefaultName,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                    font: f.medium,
                    fontSize: 7,
                    color: kPdfMuted,
                    letterSpacing: 1)),
          ]),
        ),
        pw.SizedBox(height: 8),
      ]);

  /// En-tête à utiliser dans `MultiPage.header` : bandeau complet en première
  /// page, filet de continuation ensuite.
  static pw.Widget headerFor(
    pw.Context ctx,
    pw.ImageProvider? logo,
    PdfFonts f, {
    required String badge,
    required String title,
  }) =>
      ctx.pageNumber <= 1
          ? header(logo, f, badge: badge)
          : continuationHeader(f, title: title);

  static pw.Widget footer(pw.Context ctx, PdfFonts f, String now, String ref) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: kPdfBorder, width: 0.8)),
      ),
      child: pw.Row(children: [
        pw.Expanded(
          // L'émetteur est en tête ; E-PILOTE reste ici, à sa place : l'outil
          // qui a produit le document, pas celui qui le délivre.
          child: pw.Text(
            _issuer == null
                ? 'Document officiel généré le $now  •  $_kDefaultName  •  Réf. $ref'
                : 'Document officiel de ${_issuer!.name} — généré le $now '
                    'via $_kDefaultName  •  Réf. $ref',
            style: pw.TextStyle(font: f.regular, fontSize: 7.5, color: kPdfMuted),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
              color: kPdfNavy, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: f.medium, fontSize: 7.5, color: PdfColors.white)),
        ),
      ]),
    );
  }

  // ── Bloc titre ──────────────────────────────────────────────────────────────
  static pw.Widget titleBlock(PdfFonts f,
      {required String kicker,
      required String title,
      String? line1,
      String? line2,
      String? statusBadge}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: kPdfSurface,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: kPdfBorder),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(kicker,
                      style: pw.TextStyle(
                          font: f.medium,
                          fontSize: 8,
                          color: kPdfMuted,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 3),
                  pw.Text(title,
                      style: pw.TextStyle(
                          font: f.bold, fontSize: 18, color: kPdfNavy)),
                  if (line1 != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(line1,
                        style: pw.TextStyle(
                            font: f.regular, fontSize: 9.5, color: kPdfText)),
                  ],
                  if (line2 != null)
                    pw.Text(line2,
                        style: pw.TextStyle(
                            font: f.regular, fontSize: 8.5, color: kPdfMuted)),
                ],
              ),
            ),
            if (statusBadge != null)
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: pw.BoxDecoration(
                    color: kPdfNavy,
                    borderRadius: pw.BorderRadius.circular(20)),
                child: pw.Text(statusBadge,
                    style: pw.TextStyle(
                        font: f.bold, fontSize: 9, color: PdfColors.white)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Grille KPI ────────────────────────────────────────────────────────────────
  /// [width] à `null` (recommandé) : les cartouches se PARTAGENT la largeur de
  /// la page. Une largeur fixe laissait une bande vide à droite — quatre boîtes
  /// de 118 pt sur 539 pt utiles s'arrêtaient à 37 pt du bord, et le bandeau
  /// paraissait décalé au lieu d'être posé sur la page.
  /// Une valeur explicite conserve l'ancien comportement (retour à la ligne)
  /// pour les documents qui alignent plus de cinq indicateurs.
  static pw.Widget kpiGrid(PdfFonts f, List<PdfKpi> cells, {double? width}) {
    pw.Widget box(PdfKpi c) => pw.Container(
          width: width,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: kPdfBorder),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 22, height: 3, color: c.color),
              pw.SizedBox(height: 8),
              pw.Text(c.value,
                  maxLines: 1,
                  style:
                      pw.TextStyle(font: f.bold, fontSize: 18, color: c.color)),
              pw.SizedBox(height: 2),
              // Une ligne, toujours : un libellé qui passerait sur deux lignes
              // rendrait un cartouche plus haut que ses voisins et ferait
              // onduler le bandeau.
              pw.Text(c.label,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                      font: f.regular, fontSize: 8, color: kPdfMuted)),
            ],
          ),
        );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: width != null
          ? pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cells.map(box).toList(),
            )
          : pw.Row(
              // Surtout PAS `stretch` : dans un `MultiPage`, la hauteur
              // disponible n'est pas bornée, et étirer les cartouches donne une
              // hauteur infinie — le document refuse alors de se générer.
              // Les libellés tenant sur une ligne, les hauteurs s'égalisent
              // d'elles-mêmes.
              children: [
                for (var i = 0; i < cells.length; i++)
                  pw.Expanded(
                    child: pw.Padding(
                      padding: pw.EdgeInsets.only(
                          right: i == cells.length - 1 ? 0 : 10),
                      child: box(cells[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Pagination d'une liste longue ──────────────────────────────────────────
  //  ⚠️ `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
  //  scinder entre deux pages. Lui confier une table plus haute qu'une page
  //  fait boucler `MultiPage` jusqu'à `TooManyPagesException` — le document ne
  //  sort pas du tout. Tout tableau dont le nombre de lignes n'est pas borné à
  //  vue d'œil DOIT donc passer par ici, et être émis en un cadre par bloc.
  static List<List<T>> paginate<T>(List<T> rows,
      {required int first, required int next}) {
    final out = <List<T>>[];
    var i = 0;
    while (i < rows.length) {
      final size = out.isEmpty ? first : next;
      out.add(rows.sublist(i, (i + size).clamp(0, rows.length)));
      i += size;
    }
    return out;
  }

  // ── Cadre de section (filet coloré + titre) ─────────────────────────────────
  static pw.Widget frame(
      {required String title,
      required PdfColor color,
      required PdfFonts fonts,
      required pw.Widget child}) {
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
                      font: fonts.bold,
                      fontSize: 11,
                      color: kPdfText,
                      letterSpacing: 0.5)),
            ]),
          ),
          child,
        ],
      ),
    );
  }

  // ── Table générique ──────────────────────────────────────────────────────────
  // [leftAlignCols] : indices de colonnes alignées à gauche (sinon centrées) ;
  // la colonne 0 est toujours à gauche et en medium.
  static pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> flex,
    required PdfFonts fonts,
    Set<int> leftAlignCols = const {},
  }) {
    pw.TextAlign alignOf(int i, int n) =>
        (i == 0 || leftAlignCols.contains(i))
            ? pw.TextAlign.left
            : pw.TextAlign.center;
    pw.Widget cell(String t, int f, pw.Font font, int i, int n,
        {PdfColor color = kPdfText}) {
      return pw.Expanded(
        flex: f,
        child: pw.Padding(
          // Gouttière entre colonnes : sans elle, une valeur qui remplit sa
          // colonne vient coller à la suivante et les deux se lisent comme un
          // seul mot (« Comptabilité et GestionPool »). Pas de marge après la
          // dernière colonne, qui longe déjà le bord du cadre.
          padding: pw.EdgeInsets.only(right: i == n - 1 ? 0 : 6),
          // `maxLines: 1` n'est pas cosmétique : une cellule qui passe sur deux
          // lignes fait grandir le tableau, et comme `frame()` l'enveloppe dans
          // un `Padding` incapable de se scinder, un tableau plus haut qu'une
          // page fait boucler `MultiPage` jusqu'à `TooManyPagesException` — le
          // document ne sort alors pas du tout. Une ligne du tableau = une
          // ligne de hauteur, quel que soit le contenu.
          child: pw.Text(t,
              textAlign: alignOf(i, n),
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
            color: kPdfSurface, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(
          children: List.generate(
              headers.length,
              (i) => cell(headers[i].toUpperCase(), flex[i], fonts.medium, i,
                  headers.length,
                  color: kPdfMuted)),
        ),
      ),
      ...rows.map((r) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: kPdfBorder, width: 0.6)),
            ),
            child: pw.Row(
              children: List.generate(
                  r.length,
                  (i) => cell(r[i], flex[i], i == 0 ? fonts.medium : fonts.regular,
                      i, r.length,
                      color: i == 0 ? kPdfText : kPdfMuted)),
            ),
          )),
    ]);
  }

  static pw.Widget empty(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: kPdfSurface, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: 9, color: kPdfMuted)),
        ),
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
}
