import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_academic_year_provider.dart';
import '../providers/admin_year_analytics_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  BILAN OFFICIEL D'UNE ANNÉE SCOLAIRE (niveau groupe).
//
//  ⚠️ CE DOCUMENT EST ÉMIS PAR LE MINISTÈRE, PAS PAR NOUS.
//  Ce service portait sa PROPRE copie de l'en-tête officiel, laquelle écrivait
//  « E-PILOTE CONGO / Plateforme Nationale de Gestion Scolaire » sous les
//  armoiries. Le bilan du METP déposé au ministère était donc signé du nom du
//  fournisseur du logiciel. `OfficialPdfKit` + `PdfIssuer` traitent exactement
//  ce problème — vingt-sept services les utilisent — et ce service ne leur
//  était jamais passé. En les adoptant, l'en-tête prend le nom du groupe
//  connecté et E-PILOTE retourne à sa place : le pied de page, comme outil qui
//  a produit le document et non comme auteur.
//
//  L'émetteur est posé une fois par session par `pdfIssuerProvider`, surveillé
//  depuis `AppShell` : aucun service d'export n'a à s'en occuper.
// ══════════════════════════════════════════════════════════════════════════════
class AcademicYearPdfService {
  static Future<Uint8List> buildPdf({
    required AdminYear year,
    required AdminYearAnalytics analytics,
    required List<AdminYear> allYears,
    String? signataire,
    String? fonctionSignataire,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();

    final fmtDateL = DateFormat('dd MMMM yyyy', 'fr');
    final maintenant = DateTime.now();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(maintenant);
    final ref = DateFormat('yyyyMMdd-HHmm').format(maintenant);
    final periode =
        '${fmtDateL.format(year.startDate)} au ${fmtDateL.format(year.endDate)}';
    final titre = "Bilan de l'année scolaire ${year.label}";

    final doc = pw.Document(
      title: 'Bilan ${year.label}',
      author: OfficialPdfKit.issuer?.name ?? 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: titre,
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'BILAN\nANNÉE SCOLAIRE', title: titre),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        OfficialPdfKit.titleBlock(f,
            kicker: "BILAN DE L'ANNÉE SCOLAIRE",
            title: year.label,
            line1: 'Période : $periode',
            line2: 'Édité le ${fmtDateL.format(maintenant)}',
            statusBadge: _statut(year)),
        pw.SizedBox(height: 16),
        _kpis(year, analytics, f),
        pw.SizedBox(height: 18),
        ..._evolution(allYears, year, f),
        pw.SizedBox(height: 14),
        ..._parDepartement(analytics, f),
        pw.SizedBox(height: 14),
        ..._parType(analytics, f),
        pw.SizedBox(height: 14),
        ..._parEtablissement(analytics, f),
        pw.SizedBox(height: 26),
        // La signature vient APRÈS ce qu'elle authentifie — un bilan signé au
        // milieu du document n'engage rien. `MultiPage` la reporte d'elle-même
        // sur la page suivante si elle ne tient pas ici.
        AttestationKit.signature(
            f, null, maintenant, signataire, fonctionSignataire ?? _kFonction),
        pw.SizedBox(height: 20),
      ],
    ));

    return doc.save();
  }

  /// Qualité du signataire. Neutre à dessein : l'émetteur peut être un ministère
  /// comme un réseau privé, et « Le chef d'établissement » — le défaut du kit —
  /// serait faux dans les deux cas pour un document de niveau groupe.
  /// À terme, ce libellé a sa place dans les paramètres du groupe.
  static const _kFonction = 'Le responsable du groupe scolaire';

  static String _statut(AdminYear y) => y.isLocked
      ? 'Archivée'
      : y.isCurrent
          ? 'En cours'
          : y.startDate.isAfter(DateTime.now())
              ? 'À venir'
              : 'Passée';

  // ── Indicateurs ─────────────────────────────────────────────────────────────
  //  Les compteurs viennent de `year`, c'est-à-dire d'un GROUP BY Postgres rendu
  //  en UNE ligne — et non de la somme de `a.bySchool`, qui en compte une par
  //  établissement et que PostgREST tronque SANS ERREUR au-delà de `max-rows`.
  //  Sommer la liste ferait diverger le document officiel de l'écran qui l'a
  //  commandé, lequel lit déjà `year`.
  static pw.Widget _kpis(AdminYear year, AdminYearAnalytics a, PdfFonts f) {
    final adopt = year.schoolsTotal == 0
        ? 0
        : (year.schoolsAdopted / year.schoolsTotal * 100).round();
    final moyenne = year.classes == 0 ? 0.0 : year.eleves / year.classes;

    // 173 pt × 3 + 2 gouttières de 10 = 539 pt, la largeur utile exacte d'une
    // A4 à marges de 28. Deux rangées de trois qui touchent les deux bords :
    // une largeur choisie au hasard laissait une bande blanche à droite.
    return OfficialPdfKit.kpiGrid(
      f,
      [
        PdfKpi('Élèves inscrits', '${year.eleves}', kPdfGreen),
        PdfKpi('Classes ouvertes', '${year.classes}', kPdfNavy),
        PdfKpi('Écoles préparées',
            '${year.schoolsAdopted}/${year.schoolsTotal}', kPdfGold),
        PdfKpi("Taux d'adoption", '$adopt %', kPdfNavy),
        PdfKpi('Départements couverts', '${a.departementsCouverts}',
            const PdfColor.fromInt(0xFF7C3AED)),
        PdfKpi('Moy. élèves / classe', moyenne.toStringAsFixed(1), kPdfGreen),
      ],
      width: 173,
    );
  }

  // ── Évolution pluriannuelle : une figure, pas seulement des chiffres ────────
  //  « 1612 puis 1773 » est une trajectoire ; alignée en colonnes, elle se lit
  //  comme deux nombres sans rapport. Des barres proportionnelles la rendent
  //  saisissable d'un coup d'œil — ce qu'attend un cabinet ministériel d'un
  //  bilan. Barres dessinées à la main plutôt qu'un moteur de graphes : trois à
  //  dix années tiennent en quelques rectangles, et rien ne peut déborder.
  static List<pw.Widget> _evolution(
      List<AdminYear> years, AdminYear courante, PdfFonts f) {
    final chrono = years.reversed.toList();
    if (chrono.isEmpty) return const [];

    final maxEleves =
        chrono.map((y) => y.eleves).fold<int>(0, (a, b) => a > b ? a : b);

    pw.Widget barre(AdminYear y) {
      final part = maxEleves == 0 ? 0.0 : y.eleves / maxEleves;
      final actuelle = y.id == courante.id;
      // Une année à venir n'a pas encore d'inscrits : la montrer comme une barre
      // à zéro se lit comme un effondrement. On la nomme pour ce qu'elle est.
      final aVenir = y.eleves == 0 && y.startDate.isAfter(DateTime.now());
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 62,
            child: pw.Text(y.label,
                maxLines: 1,
                style: pw.TextStyle(
                    font: actuelle ? f.bold : f.regular,
                    fontSize: 8.5,
                    color: kPdfText)),
          ),
          // Proportion par deux `Expanded` à flex entiers : le paquet `pdf` n'a
          // pas de `FractionallySizedBox`, et la répartition par flex donne le
          // même résultat au pixel près sans dépendre de la largeur disponible,
          // inconnue ici puisqu'elle varie avec le format de page.
          pw.Expanded(
            child: pw.Container(
              height: 14,
              decoration: pw.BoxDecoration(
                  color: kPdfSurface,
                  borderRadius: pw.BorderRadius.circular(3)),
              child: aVenir
                  ? null
                  : pw.Row(children: [
                      pw.Expanded(
                        // Au moins 1/1000 : une année à un seul élève doit
                        // rester visible, pas disparaître dans le fond.
                        flex: (part * 1000).round().clamp(1, 1000),
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                              color: actuelle
                                  ? kPdfGreen
                                  : pdfTint(kPdfNavy, 0.55),
                              borderRadius: pw.BorderRadius.circular(3)),
                        ),
                      ),
                      if ((part * 1000).round().clamp(1, 1000) < 1000)
                        pw.Expanded(
                          flex: 1000 - (part * 1000).round().clamp(1, 1000),
                          child: pw.SizedBox(),
                        ),
                    ]),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 92,
            child: pw.Text(
                aVenir
                    ? 'à venir'
                    : '${y.eleves} élèves · ${y.classes} cl.',
                maxLines: 1,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    font: actuelle ? f.medium : f.regular,
                    fontSize: 8.5,
                    color: aVenir ? kPdfMuted : kPdfText)),
          ),
        ]),
      );
    }

    return [
      OfficialPdfKit.frame(
        title: 'ÉVOLUTION PLURIANNUELLE',
        color: kPdfNavy,
        fonts: f,
        child: pw.Column(children: chrono.map(barre).toList()),
      ),
    ];
  }

  // ── Répartition par département ─────────────────────────────────────────────
  //  Le Congo compte douze départements : le cas normal tient sur un bloc. La
  //  pagination couvre le cas sale — `schools.department` est du texte libre, et
  //  quelques saisies fautives suffiraient à en faire lever cinquante.
  static List<pw.Widget> _parDepartement(AdminYearAnalytics a, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'RÉPARTITION PAR DÉPARTEMENT',
        color: kPdfGreen,
        fonts: f,
        headers: const [
          'Département',
          'Écoles préparées',
          'Classes',
          'Élèves',
        ],
        flex: const [4, 3, 2, 2],
        rows: a.byDepartment
            .map((d) => [
                  d.department,
                  '${d.ecolesPreparees}/${d.ecoles}',
                  '${d.classes}',
                  '${d.eleves}',
                ])
            .toList(),
        emptyLabel: 'Aucune donnée par département.',
      );

  static List<pw.Widget> _parType(AdminYearAnalytics a, PdfFonts f) {
    String label(String t) => switch (t) {
          'public' => 'Public',
          'prive' => 'Privé',
          _ => t.isEmpty ? 'Autre' : t,
        };
    return OfficialPdfKit.tableSection(
      title: "TYPE D'ÉTABLISSEMENT",
      color: kPdfGold,
      fonts: f,
      headers: const ['Type', 'Écoles', 'Classes', 'Élèves'],
      flex: const [4, 2, 2, 2],
      rows: a.byType
          .map((t) => [
                label(t.type),
                '${t.ecoles}',
                '${t.classes}',
                '${t.eleves}',
              ])
          .toList(),
      emptyLabel: 'Aucune donnée par type.',
    );
  }

  // ── Préparation par établissement ───────────────────────────────────────────
  //  La liste qui dicte la taille du document : une ligne par établissement du
  //  groupe, donc jusqu'à 1 000 à la cible nationale.
  //
  //  Colonne des noms très large (9/20 de la page) et deux lignes autorisées :
  //  les intitulés congolais sont longs — « Collège d'Enseignement Technique
  //  de … » fait à lui seul trente-cinq caractères avant la commune. Écrêtés,
  //  trois établissements devenaient indiscernables.
  //
  //  ⚠️ La pagination n'est pas cosmétique : `OfficialPdfKit.frame()` enveloppe
  //  son contenu dans un `Padding`, qui ne sait pas se scinder entre deux pages.
  //  Confier à un seul cadre un tableau plus haut qu'une feuille fait boucler
  //  `MultiPage` jusqu'à `TooManyPagesException` : le document ne sort alors pas
  //  du tout — pas « mal paginé », pas « tronqué » : absent. Mesuré avant
  //  correction : le bilan cessait de se générer à 31 établissements.
  static List<pw.Widget> _parEtablissement(
          AdminYearAnalytics a, PdfFonts f) =>
      OfficialPdfKit.tableSection(
        title: 'PRÉPARATION PAR ÉTABLISSEMENT',
        color: const PdfColor.fromInt(0xFF7C3AED),
        fonts: f,
        headers: const [
          'Établissement',
          'Département',
          'Classes',
          'Élèves',
          'État',
        ],
        flex: const [9, 4, 2, 2, 3],
        rows: a.bySchool
            .map((s) => [
                  s.name,
                  s.department,
                  '${s.classes}',
                  '${s.eleves}',
                  s.adopted ? 'Préparée' : 'En attente',
                ])
            .toList(),
        emptyLabel: 'Aucune école active.',
        perBlock: OfficialPdfKit.kTallRowsPerBlock,
        maxLines: 2,
        rowHeight: OfficialPdfKit.kTallRowHeight,
      );

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ── Impression / enregistrement ─────────────────────────────────────────────
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
    Uint8List? bytes,
  }) async {
    // `bytes` permet d'enregistrer un document DÉJÀ construit — celui que
    // l'aperçu affiche. Sans cela, valider l'aperçu regénérerait le PDF, et
    // l'agent enregistrerait un document qu'il n'a, à la lettre, pas vu.
    final octets = bytes ??
        await buildPdf(year: year, analytics: analytics, allYears: allYears);
    final fileName = 'Bilan_${_slug(year.label)}'
        '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Enregistrer le bilan de l'année",
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: octets,
    );
    if (savePath != null) {
      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(octets);
      }
    }
    return savePath;
  }
}
