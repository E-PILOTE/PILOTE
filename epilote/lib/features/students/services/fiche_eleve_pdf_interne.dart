import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/official_pdf_kit.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/discipline_vocab.dart';
import '../../../core/utils/scolarite_libelles.dart';
import 'fiche_eleve_pdf_data.dart';


// ════════════════════════════════════════════════════════════════════════════
//  LES BLOCS QUI NE SORTENT JAMAIS DE L'ÉTABLISSEMENT
//
//  ── POURQUOI CES TROIS-LÀ SONT ENSEMBLE, ET SÉPARÉS ────────────────────────
//  Santé, conduite et finances ne sont pas trois rubriques de plus : ce sont
//  les SEULES que la fiche administrative laisse volontairement de côté, parce
//  que le papier qu'on remet à un employeur, à une administration ou à une
//  autre école n'a pas à les porter.
//
//  Les tenir dans un fichier à part n'est donc pas une commodité de découpe :
//  c'est la frontière du document rendue visible dans l'arborescence. Le jour
//  où l'on ajoutera un bloc, la question « celui-ci sort-il de l'école ? » sera
//  posée par l'endroit même où on l'écrit.
//
//  ⚠️ Chacun de ces blocs porte « USAGE INTERNE » dans son titre. Un dossier
//  complet peut être photocopié ; le titre part avec la photocopie.
// ════════════════════════════════════════════════════════════════════════════

List<pw.Widget> blocSante(PdfFonts f, FicheElevePdfMatiere m) {
  final d = m.dossier;
  return [
    ...OfficialPdfKit.tableSection(
      title: 'SANTÉ — USAGE INTERNE',
      color: kPdfRed,
      fonts: f,
      headers: const ['Rubrique', 'Valeur'],
      rows: [
        ['Groupe sanguin', fmtOuTiret(d.s('blood_group'))],
        ['Allergies et antécédents', fmtOuTiret(d.s('allergies'))],
        ['Passages à l\'infirmerie', '${m.visites.length}'],
      ],
      flex: const [3, 5],
      leftAlignCols: const {0, 1},
      emptyLabel: '—',
    ),
    if (m.visites.isNotEmpty) ...[
      pw.SizedBox(height: 10),
      ...OfficialPdfKit.tableSection(
        title: 'INFIRMERIE — USAGE INTERNE',
        color: kPdfRed,
        fonts: f,
        headers: const ['Date', 'Motif', 'Diagnostic', 'Soins'],
        rows: [
          for (final v in m.visites)
            [
              fmtDatePdf(v.date),
              fmtOuTiret(v.symptomes),
              fmtOuTiret(v.diagnostic),
              fmtOuTiret(v.traitement),
            ],
        ],
        flex: const [2, 4, 4, 4],
        leftAlignCols: const {1, 2, 3},
        emptyLabel: 'Aucun passage.',
      ),
    ],
  ];
}

List<pw.Widget> blocConduite(PdfFonts f, FicheElevePdfMatiere m) {
  final a = m.assiduite;
  return [
    if (a != null && !a.vide) ...[
      OfficialPdfKit.kpiGrid(f, [
        PdfKpi('Séances relevées', '${a.seances}', kPdfNavy),
        PdfKpi('Absences', '${a.absences}', kPdfRed),
        PdfKpi('Retards', '${a.retards}', kPdfGold),
        PdfKpi(
          'Présence',
          a.tauxPresence == null
              ? '—'
              : '${a.tauxPresence!.toStringAsFixed(1)} %',
          kPdfGreen,
        ),
      ]),
      pw.SizedBox(height: 10),
    ],
    ...OfficialPdfKit.tableSection(
      title: 'CONDUITE — USAGE INTERNE',
      color: kPdfRed,
      fonts: f,
      headers: const ['Date', 'Fait', 'Sanction', 'Suivi'],
      rows: [
        for (final i in m.incidents)
          [
            fmtDatePdf(i.date),
            [
              incidentTypeLabel(i.type),
              if (i.description.isNotEmpty) '— ${i.description}',
            ].join(' '),
            fmtOuTiret(sanctionLabel(i.sanction)),
            fmtOuTiret(i.suivi),
          ],
      ],
      flex: const [2, 5, 3, 4],
      leftAlignCols: const {1, 2, 3},
      emptyLabel: 'Aucun fait de conduite enregistré.',
    ),
  ];
}

List<pw.Widget> blocFinances(PdfFonts f, FicheElevePdfMatiere m) {
  final d = m.decompte;
  return [
    if (d != null && !d.vide) ...[
      OfficialPdfKit.kpiGrid(f, [
        PdfKpi('Net dû', CurrencyFormatter.format(d.net), kPdfNavy),
        PdfKpi('Encaissé', CurrencyFormatter.format(d.verse), kPdfGreen),
        PdfKpi(
          'Reste dû',
          CurrencyFormatter.format(d.reste),
          d.reste > 0 ? kPdfRed : kPdfGreen,
        ),
      ]),
      pw.SizedBox(height: 10),
    ],
    ...OfficialPdfKit.tableSection(
      title: 'VERSEMENTS — USAGE INTERNE',
      color: kPdfGreen,
      fonts: f,
      headers: const ['Date', 'Poste', 'Montant', 'Reçu', 'État'],
      rows: [
        for (final v in m.versements)
          [
            fmtDatePdf(v.date),
            [
              fmtOuTiret(v.libelle),
              if (v.periode.isNotEmpty) '(${v.periode})',
            ].join(' '),
            CurrencyFormatter.format(v.montant),
            fmtOuTiret(v.recu),
            paiementStatutLabel(v.statut),
          ],
      ],
      flex: const [2, 5, 3, 3, 3],
      leftAlignCols: const {1, 3, 4},
      emptyLabel: 'Aucun versement enregistré.',
    ),
  ];
}
