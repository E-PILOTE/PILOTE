import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/ministry_exam_rows.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EXPORTER CE QU'ON REGARDE — un axe, ou le périmètre entier du cockpit.
//
//  ── UN SEUL BOUTON ──────────────────────────────────────────────────────────
//  « Exporter » ouvre l'aperçu, qui porte déjà imprimer et enregistrer : trois
//  boutons deviennent un. Pas de « partager » — l'application n'a aucun canal
//  sortant réel, et la relance par notification reste le seul geste qui sort de
//  cet écran.
//
//  ── LA MENTION QUI N'EST PAS DÉCORATIVE ─────────────────────────────────────
//  Ces chiffres viennent de NOS écoles, pas de la DEC. Un tableau sorti du
//  cockpit circule, se photocopie, et finit par faire autorité à la place du
//  chiffre proclamé. Chaque page le dit donc explicitement.
//
//  ── LA PAGINATION N'EST PAS UN DÉTAIL ───────────────────────────────────────
//  `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
//  scinder entre deux pages : lui confier une liste de soixante écoles fait
//  boucler `MultiPage` jusqu'à `TooManyPagesException`, et le document ne sort
//  pas du tout. D'où `OfficialPdfKit.paginate` — un cadre par bloc.
// ════════════════════════════════════════════════════════════════════════════
class ExamAxisPdfService {
  /// La mention qui distingue ce document d'une publication de la DEC.
  static const _provenance =
      'Chiffres établis à partir des saisies des établissements du réseau. '
      'Ils ne se substituent pas aux résultats proclamés par la Direction des '
      'Examens et Concours.';

  /// Le taux ne s'écrit jamais seul : sans son dénominateur, « 100 % » sur
  /// deux résultats connus pour trente candidats est un mensonge de mise en
  /// page.
  static String _rate(int admitted, int known) =>
      known == 0 ? 'en attente' : '${(admitted / known * 100).toStringAsFixed(1)} %';

  // ── Un axe : les écoles d'une filière ou d'un département ─────────────────
  static Future<Uint8List> buildAxisPdf({
    required String groupName,
    required ExamAxis axis,
    required String label,
    required String? examLabel,
    required String? yearLabel,
    required List<AxisSchoolLine> schools,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final candidates = schools.fold<int>(0, (s, e) => s + e.candidates);
    final known = schools.fold<int>(0, (s, e) => s + e.known);
    final admitted = schools.fold<int>(0, (s, e) => s + e.admitted);
    final atRisk = schools.where((s) => !s.transmitted).length;
    final scope = examLabel ?? 'tous examens';

    final doc = pw.Document(
      title: 'Réussite par ${axis.label} — $label',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Suivi de campagne — chiffres de la plateforme',
    );

    final blocks = OfficialPdfKit.paginate(schools, first: 18, next: 26);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'SUIVI DE\nCAMPAGNE',
          title: 'Réussite par ${axis.label} · $label'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: '$label — $scope',
          line1: _provenance,
          line2: 'Taux calculés sur les résultats CONNUS ; un établissement '
              'dont rien n\'est proclamé n\'a pas de taux — il n\'a pas zéro',
          statusBadge: yearLabel ?? 'SESSION',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Établissements', '${schools.length}', kPdfNavy),
          PdfKpi('Candidats', '$candidates', kPdfNavyL),
          PdfKpi('Admis / connus', '$admitted / $known', kPdfGreen),
          PdfKpi('Taux', _rate(admitted, known), kPdfGold),
        ]),
        pw.SizedBox(height: 16),
        for (var i = 0; i < blocks.length; i++) ...[
          OfficialPdfKit.frame(
            title: i == 0
                ? 'ÉTABLISSEMENTS, DU MEILLEUR TAUX AU PLUS FAIBLE'
                : 'ÉTABLISSEMENTS (SUITE)',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'ÉTABLISSEMENT',
                'DÉPARTEMENT',
                'CAND.',
                'CONNUS',
                'ADMIS',
                'TAUX',
                'DEC',
              ],
              flex: const [30, 18, 9, 10, 9, 12, 12],
              fonts: f,
              leftAlignCols: const {1},
              rows: [
                for (final s in blocks[i])
                  [
                    s.schoolName,
                    s.department ?? '—',
                    '${s.candidates}',
                    '${s.known}',
                    '${s.admitted}',
                    _rate(s.admitted, s.known),
                    s.transmitted ? 'transmis' : 'RIEN TRANSMIS',
                  ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (atRisk > 0)
          OfficialPdfKit.frame(
            title: 'ALERTE',
            color: kPdfRed,
            fonts: f,
            child: pw.Text(
              '$atRisk établissement(s) de cet axe n\'ont transmis aucun '
              'dossier à la DEC. Après la clôture des dépôts, ces candidatures '
              'sont perdues pour l\'année : c\'est la seule alerte '
              'irrattrapable de la campagne.',
              style: pw.TextStyle(font: f.regular, fontSize: 9.5),
            ),
          ),
      ],
    ));

    return doc.save();
  }

  // ── Le périmètre entier du cockpit ────────────────────────────────────────
  static Future<Uint8List> buildScopePdf({
    required String groupName,
    required MinistryExamsData data,
    required String? examLabel,
  }) async {
    final f = await OfficialPdfKit.loadFonts();
    final logo = await OfficialPdfKit.loadLogo();
    final now = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    final d = data;
    final scope = examLabel ?? 'tous examens';
    final rate = d.successRate;

    final doc = pw.Document(
      title: 'Campagne examens — $scope',
      author: 'E-PILOTE CONGO',
      creator: 'E-PILOTE CONGO',
      subject: 'Suivi de campagne — chiffres de la plateforme',
    );

    final blocks = OfficialPdfKit.paginate(d.schools, first: 14, next: 26);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => OfficialPdfKit.headerFor(ctx, logo, f,
          badge: 'SUIVI DE\nCAMPAGNE', title: 'Campagne examens · $scope'),
      footer: (ctx) => OfficialPdfKit.footer(ctx, f, now, ref),
      build: (_) => [
        OfficialPdfKit.titleBlock(
          f,
          kicker: groupName.toUpperCase(),
          title: 'Suivi de la campagne — $scope',
          line1: _provenance,
          line2: 'Dossiers, dépôts et transmissions à la date d\'édition',
          statusBadge: d.yearLabel ?? 'SESSION',
        ),
        pw.SizedBox(height: 14),
        OfficialPdfKit.kpiGrid(f, [
          PdfKpi('Candidats', '${d.totalCandidates}', kPdfNavy),
          PdfKpi('Dossiers complets', '${d.totalComplete}', kPdfNavyL),
          PdfKpi('Déposés', '${d.totalSubmitted}', kPdfGold),
          PdfKpi('Écoles à risque', '${d.schoolsAtRisk}',
              d.schoolsAtRisk == 0 ? kPdfGreen : kPdfRed),
          PdfKpi('Réussite',
              rate == null ? 'en attente' : '${rate.toStringAsFixed(1)} %',
              kPdfGreen),
        ]),
        pw.SizedBox(height: 16),
        if (d.byFiliere.isNotEmpty) ...[
          OfficialPdfKit.frame(
            title: 'RÉUSSITE PAR FILIÈRE',
            color: kPdfNavy,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const ['FILIÈRE', 'INSCRITS', 'CONNUS', 'ADMIS', 'TAUX'],
              flex: const [40, 15, 15, 15, 15],
              fonts: f,
              rows: [
                for (final l in d.byFiliere.take(14))
                  [
                    l.label,
                    '${l.total}',
                    '${l.known}',
                    '${l.admitted}',
                    _rate(l.admitted, l.known),
                  ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (d.byDepartment.isNotEmpty) ...[
          OfficialPdfKit.frame(
            title: 'RÉUSSITE PAR DÉPARTEMENT',
            color: kPdfGreen,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'DÉPARTEMENT',
                'INSCRITS',
                'CONNUS',
                'ADMIS',
                'TAUX'
              ],
              flex: const [40, 15, 15, 15, 15],
              fonts: f,
              rows: [
                for (final l in d.byDepartment.take(16))
                  [
                    l.label,
                    '${l.total}',
                    '${l.known}',
                    '${l.admitted}',
                    _rate(l.admitted, l.known),
                  ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        for (var i = 0; i < blocks.length; i++) ...[
          OfficialPdfKit.frame(
            title: i == 0 ? 'ÉTABLISSEMENTS DU RÉSEAU' : 'ÉTABLISSEMENTS (SUITE)',
            color: kPdfNavyL,
            fonts: f,
            child: OfficialPdfKit.table(
              headers: const [
                'ÉTABLISSEMENT',
                'CAND.',
                'COMPL.',
                'DÉPOSÉS',
                'TRANSM.',
                'RÉSULTATS',
              ],
              flex: const [34, 11, 11, 12, 12, 20],
              fonts: f,
              rows: [
                for (final s in blocks[i])
                  [
                    s.schoolName,
                    '${s.candidates}',
                    '${s.complete}',
                    '${s.submitted}',
                    s.transmissions == 0 ? 'AUCUNE' : '${s.transmissions}',
                    s.withResult == 0
                        ? 'en attente'
                        : '${s.admitted}/${s.withResult} connus',
                  ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      ],
    ));

    return doc.save();
  }
}
