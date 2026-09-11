import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/fiche_detail_model.dart';
import 'official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  IMPRIMER UNE FICHE DE DÉTAIL — un seul document pour toutes les fiches
//
//  ── POURQUOI UN SEUL ──────────────────────────────────────────────────────
//  Six KPI cliquables, plus les départements, plus ce qui viendra : autant de
//  services PDF à écrire, à styler et à corriger un par un. Puisqu'une fiche
//  est une donnée (`fiche_detail_model.dart`), un seul builder les imprime
//  toutes — et toute fiche future naît imprimable.
//
//  ── ⚠️ CE QUI REND CE DOCUMENT SÛR À GRANDE ÉCHELLE ───────────────────────
//  `OfficialPdfKit.tableSection` découpe chaque section en blocs de lignes
//  calibrés pour la feuille. Sans lui, une section de mille écoles fait boucler
//  `MultiPage` jusqu'à `TooManyPagesException` : pas un document tronqué — pas
//  de document du tout, à l'instant précis où le réseau devient intéressant.
//
//  ⚠️ UN FILTRE ACTIF EST ÉCRIT SUR LE DOCUMENT. Une liste partielle qui ne
//  s'annonce pas est le plus court chemin vers un chiffre faux dans un état
//  ministériel.
// ════════════════════════════════════════════════════════════════════════════

class FicheDetailPdf {
  static Future<Uint8List> build(FicheDetail f) async {
    // Polices EMBARQUÉES : hors ligne, `PdfGoogleFonts` retombe sans bruit sur
    // Helvetica — et l'accentuation française part avec.
    final fonts = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateTime.now();
    final horodatage = DateFormat('dd/MM/yyyy à HH:mm').format(now);
    final reference = 'DET-${DateFormat('yyyyMMdd-HHmm').format(now)}';
    final couleur = PdfColor.fromInt(f.couleur.toARGB32());

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, fonts,
          badge: 'FICHE DE\nDÉTAIL', title: f.titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, fonts, horodatage, reference),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(
          fonts,
          kicker: f.totalLabel.toUpperCase(),
          title: f.titre,
          line1: f.sousTitre,
          line2: 'Situation arrêtée au $horodatage',
          statusBadge: f.total,
        ),
        pw.SizedBox(height: 14),
        if (f.filtre.isNotEmpty) ...[
          _avertissementFiltre(fonts, f),
          pw.SizedBox(height: 12),
        ],
        if (f.chiffres.isNotEmpty) ...[
          OfficialPdfKit.kpiGrid(fonts, [
            for (final (label, valeur) in f.chiffres)
              PdfKpi(label, valeur, couleur),
          ]),
          pw.SizedBox(height: 16),
        ],
        if (f.barres.isNotEmpty) ...[
          ..._barres(fonts, f),
          pw.SizedBox(height: 14),
        ],
        for (final s in f.sections) ...[
          ..._section(fonts, s, couleur),
          pw.SizedBox(height: 14),
        ],
        if (f.notes.isNotEmpty) _notes(fonts, f.notes),
      ],
    ));
    return doc.save();
  }

  // ── Une section = un tableau paginé ───────────────────────────────────────
  static List<pw.Widget> _section(
      PdfFonts fonts, SectionFiche s, PdfColor couleur) {
    final deuxLignes = s.libelleSurDeuxLignes;
    return OfficialPdfKit.tableSection(
      title: s.titre.toUpperCase(),
      color: couleur,
      fonts: fonts,
      headers: s.enTetesEffectifs,
      flex: s.flexEffectif,
      rows: [
        for (final l in s.lignes)
          [
            // Le sous-titre rejoint le libellé quand il n'y a pas de colonne
            // pour le porter : sur le papier, « Pointe-Noire » sans « 42 % de
            // filles » perd ce qui justifiait la ligne.
            deuxLignes && (l.sousTitre ?? '').isNotEmpty
                ? '${l.titre}\n${l.sousTitre}'
                : l.titre,
            ...l.colonnes,
            l.valeur,
          ],
      ],
      emptyLabel: s.videLabel,
      leftAlignCols: const {0},
      // La colonne 0 a droit d'office à [maxLines] lignes — mais deux lignes
      // EXIGENT une hauteur fixe : c'est elle qui rend la pagination calculable
      // (cf. `OfficialPdfKit.table`).
      maxLines: deuxLignes ? 2 : 1,
      rowHeight: deuxLignes ? OfficialPdfKit.kTallRowHeight : null,
      perBlock: deuxLignes
          ? OfficialPdfKit.kTallRowsPerBlock
          : OfficialPdfKit.kRowsPerBlock,
      note: s.note,
    );
  }

  // ── Les barres d'exécution ────────────────────────────────────────────────
  static List<pw.Widget> _barres(PdfFonts fonts, FicheDetail f) => [
        OfficialPdfKit.frame(
          title: 'OÙ EN EST L’EXÉCUTION',
          color: PdfColor.fromInt(f.couleur.toARGB32()),
          fonts: fonts,
          child: pw.Column(children: [
            for (final b in f.barres) ...[
              _barre(fonts, b),
              pw.SizedBox(height: 8),
            ],
          ]),
        ),
      ];

  static pw.Widget _barre(PdfFonts f, BarreFiche b) {
    final part = b.valeur.clamp(0.0, 1.0);
    final couleur = PdfColor.fromInt(b.couleur.toARGB32());
    // ⚠️ `pw.FractionallySizedBox` n'existe PAS dans le paquet `pdf`. Deux
    // `Expanded` à flex entiers font la même chose et compilent.
    final plein = (part * 1000).round();
    return pw.Row(children: [
      pw.SizedBox(
        width: 120,
        child: pw.Text(b.label,
            maxLines: 1,
            style:
                pw.TextStyle(font: f.regular, fontSize: 8.5, color: kPdfMuted)),
      ),
      pw.Expanded(
        child: pw.Container(
          height: 9,
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(children: [
            if (plein > 0)
              pw.Expanded(
                flex: plein,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: couleur,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
              ),
            if (plein < 1000) pw.Expanded(flex: 1000 - plein, child: pw.SizedBox()),
          ]),
        ),
      ),
      pw.SizedBox(width: 10),
      pw.SizedBox(
        width: 34,
        child: pw.Text('${(part * 100).round()} %',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: f.bold, fontSize: 8.5, color: kPdfText)),
      ),
      if ((b.legende ?? '').isNotEmpty) ...[
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 150,
          child: pw.Text(b.legende!,
              maxLines: 1,
              style: pw.TextStyle(
                  font: f.regular, fontSize: 8, color: kPdfMuted)),
        ),
      ],
    ]);
  }

  static pw.Widget _avertissementFiltre(PdfFonts f, FicheDetail fiche) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: kPdfSurface,
            border: pw.Border.all(color: kPdfGold),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
              'Vue filtrée sur « ${fiche.filtre} » — ${fiche.nbLignes} ligne(s) '
              'retenue(s). Ce document ne présente pas l’intégralité des '
              'données.',
              style:
                  pw.TextStyle(font: f.medium, fontSize: 9, color: kPdfText)),
        ),
      );

  static pw.Widget _notes(PdfFonts f, List<String> notes) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kPdfBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final n in notes) ...[
                pw.Text(n,
                    style: pw.TextStyle(
                        font: f.regular, fontSize: 8.5, color: kPdfMuted)),
                pw.SizedBox(height: 5),
              ],
            ],
          ),
        ),
      );
}
