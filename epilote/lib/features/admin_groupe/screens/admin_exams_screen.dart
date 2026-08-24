import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/exam_archives_provider.dart';
import '../providers/ministry_exam_rows.dart';
import '../providers/national_reference.dart';
import '../services/exam_axis_pdf_service.dart';
import '../widgets/admin_exams_breakdown.dart';
import '../widgets/admin_exams_views.dart';
import '../widgets/exam_axis_drilldown_modal.dart';
import '../widgets/exam_national_reference_strip.dart';
import '../widgets/exam_scope_chips.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EXAMENS NATIONAUX — cockpit du MINISTÈRE (espace admin_groupe, online).
//
//  Ce que l'espace ministère ne montrait PAS : la couverture des examens sur
//  TOUT le réseau. Une école voit ses candidats ; le ministère voit lesquelles
//  de ses écoles ont inscrit, déposé, obtenu des résultats — et lesquelles ont
//  des candidats SANS aucune transmission (le point chaud, irrattrapable après
//  la clôture). Même grammaire visuelle que les listes super_admin (chrome
//  partagé `core/widgets/list_chrome.dart`) pour un système cohérent.
// ════════════════════════════════════════════════════════════════════════════
class AdminExamsScreen extends ConsumerStatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  ConsumerState<AdminExamsScreen> createState() => _State();
}

class _State extends ConsumerState<AdminExamsScreen> {
  final _search = TextEditingController();
  bool _isTable = true;
  bool _onlyAtRisk = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MinistrySchoolExam> _filter(List<MinistrySchoolExam> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((r) {
      if (_onlyAtRisk && !r.hasCandidatesNotTransmitted) return false;
      if (q.isEmpty) return true;
      return r.schoolName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminExamsProvider);

    return AppShell(
      // Le titre nomme ce que la page FAIT — suivre la campagne pendant qu'elle
      // tourne — et non le domaine entier. « Examens nationaux » se lisait comme
      // un parapluie au-dessus des quatre autres pages de la section.
      title: 'Campagne d\'examens en cours',
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const ListShimmer(),
        error: (e, _) => ExamsErrorView(
            message: '$e', onRetry: () => ref.invalidate(adminExamsProvider)),
        data: (all) {
          // Le périmètre se recompose EN MÉMOIRE : changer d'examen ne
          // redemande rien au serveur.
          final code = ref.watch(examFilterProvider);
          final d = all.forExam(code);
          final filtered = _filter(d.schools);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (all.examOptions.length > 1) ...[
                  ExamScopeChips(
                    options: all.examOptions,
                    selected: code,
                    onChanged: (v) =>
                        ref.read(examFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(height: 18),
                ],
                KpiGrid(items: _kpis(d)),
                // L'étalon national, quand on regarde UN examen et que le
                // chiffre de la DEC a été relevé. Il transforme « 50,6 % » en
                // « 50,6 % contre 51,6 % au national » — la seule forme sous
                // laquelle un taux de réseau se défend devant un ministère.
                ?_nationalStrip(d, code),
                const SizedBox(height: 20),
                ExamChart(
                  // Sur « Tous », un groupe par examen : on voit où la
                  // campagne fuit. Sur un examen, par département — une barre
                  // unique ne compare rien.
                  bars: code == null
                      ? funnelByExam(d.rows)
                      : funnelByDepartment(scopeRows(d.rows, code)),
                  yearLabel: d.yearLabel,
                  byDepartment: code != null,
                ),
                const SizedBox(height: 20),
                if (d.byFiliere.isNotEmpty || d.byDepartment.isNotEmpty) ...[
                  // Chiffres de la PLATEFORME : ce que nos écoles ont saisi,
                  // sur nos seuls établissements. Les résultats proclamés par
                  // la DEC vivent sur « Résultats & archives » — deux pages,
                  // pour que deux « réussites par département » aux valeurs
                  // différentes ne se touchent jamais.
                  ExamBreakdownRow(
                    filiere: d.byFiliere,
                    departement: d.byDepartment,
                    onTapFiliere: (l) =>
                        _openAxis(context, d, code, ExamAxis.filiere, l.label),
                    onTapDepartement: (l) => _openAxis(
                        context, d, code, ExamAxis.departement, l.label),
                  ),
                  const SizedBox(height: 20),
                ],
                ListFilterBar(
                  searchCtrl: _search,
                  searchHint: 'Rechercher une école…',
                  isTableView: _isTable,
                  addLabel: '',
                  addIcon: Icons.add,
                  onAdd: null, // lecture seule : le ministère pilote, ne saisit pas
                  onSearchChange: (_) => setState(() {}),
                  onToggleView: () => setState(() => _isTable = !_isTable),
                  onReset: () => setState(() {
                    _search.clear();
                    _onlyAtRisk = false;
                  }),
                  filters: [
                    ListFilterDropdown(
                      icon: Icons.warning_amber_rounded,
                      label: 'Filtre',
                      value: _onlyAtRisk ? 'risque' : 'toutes',
                      items: const {
                        'toutes': 'Toutes les écoles',
                        'risque': 'À risque (rien transmis)',
                      },
                      onChanged: (v) =>
                          setState(() => _onlyAtRisk = v == 'risque'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ListResultHeader(
                        total: d.schools.length,
                        filtered: filtered.length,
                        noun: 'école'),
                  ),
                  // La seule action du cockpit : relancer celles qui n'ont
                  // rien transmis. Constater un risque irrattrapable sans
                  // pouvoir agir dessus n'était pas du pilotage.
                  // Exporter ce qu'on regarde : le périmètre courant, tel
                  // qu'il est à l'écran.
                  _ExportButton(
                    label: 'Exporter',
                    title: 'Campagne examens'
                        '${_examLabel(d, code) != null ? ' · ${_examLabel(d, code)}' : ''}',
                    fileName: 'campagne-examens-${code ?? 'tous'}',
                    buildPdf: (groupName) => ExamAxisPdfService.buildScopePdf(
                      groupName: groupName,
                      data: d,
                      examLabel: _examLabel(d, code),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (d.schoolsAtRisk > 0)
                    ExamsRemindButton(
                      schools: d.schools
                          .where((s) => s.hasCandidatesNotTransmitted)
                          .toList(),
                    ),
                ]),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  ExamsEmptyView(hasData: d.totalCandidates > 0)
                else if (_isTable)
                  SchoolsTable(rows: filtered)
                else
                  SchoolsCards(rows: filtered),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Ouvre les écoles d'un axe. Les lignes viennent de la mémoire : le
  /// drill-down ne coûte aucune requête.
  void _openAxis(
    BuildContext context,
    MinistryExamsData d,
    String? code,
    ExamAxis axis,
    String label,
  ) {
    final rows = scopeRows(d.rows, code);
    final examLabel = _examLabel(d, code);
    final schools = schoolsForAxis(
      rows,
      axis: axis,
      label: label,
      transmittedSchoolIds: d.transmittedSchoolIds,
    );
    showExamAxisDrilldown(
      context,
      axis: axis,
      label: label,
      examLabel: examLabel,
      schools: schools,
      // Un seul bouton : l'aperçu porte déjà imprimer et enregistrer.
      exportButton: _ExportButton(
        label: 'Exporter',
        title: 'Réussite par ${axis.label} · $label',
        fileName: 'reussite-${axis.name}-$label',
        buildPdf: (groupName) => ExamAxisPdfService.buildAxisPdf(
          groupName: groupName,
          axis: axis,
          label: label,
          examLabel: examLabel,
          yearLabel: d.yearLabel,
          schools: schools,
        ),
      ),
    );
  }

  /// La bande « réseau vs national ». `null` — donc rien à l'écran — sur
  /// « Tous les examens » (aucun taux national ne les agrège) et tant que le
  /// chiffre officiel n'a pas été relevé sur « Résultats & archives ».
  Widget? _nationalStrip(MinistryExamsData d, String? code) {
    if (code == null) return null;
    final figures = ref.watch(officialFiguresProvider).valueOrNull;
    if (figures == null) return null;
    final reference = nationalReferenceFor(
      figures,
      examCode: code,
      currentYearLabel: d.yearLabel,
    );
    if (reference == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ExamNationalReferenceStrip(
        reference: reference,
        examLabel: _examLabel(d, code),
        networkRate: d.successRate,
        admitted: d.totalAdmitted,
        known: d.totalWithResult,
      ),
    );
  }

  String? _examLabel(MinistryExamsData d, String? code) => code == null
      ? null
      : d.examOptions
          .where((o) => o.code == code)
          .map((o) => o.shortName)
          .firstOrNull;

  // ════════════════════════════════════════════════════════════════════════
  //  LES INDICATEURS SE LISENT COMME UNE CHAÎNE, PAS COMME HUIT MESURES.
  //
  //  Une candidature suit toujours le même parcours : déclarée, complétée,
  //  déposée par le chef d'établissement, transmise à la DEC, puis proclamée.
  //  Les cartes étaient rangées dans un ordre arbitraire — les transmissions
  //  avant les dépôts, les résultats avant les dossiers déposés — de sorte
  //  qu'on lisait huit chiffres indépendants là où il y a une progression.
  //
  //  Rangées dans l'ordre, elles disent aussi ce qu'elles ne disaient pas : le
  //  DÉCHET à chaque étape. « 80 déclarés, 55 complets » devient « −25 ».
  //
  //  Et le taux de réussite porte désormais TOUJOURS son assiette, comme les
  //  ventilations le font déjà. « 74 % » seul n'est pas vérifiable ; « 74 % ·
  //  59 admis / 80 connus » se recoupe avec la publication de la DEC.
  // ════════════════════════════════════════════════════════════════════════
  List<KpiData> _kpis(MinistryExamsData d) {
    final completeRate =
        d.totalCandidates == 0 ? 0.0 : d.totalComplete / d.totalCandidates;
    final incomplete = d.totalCandidates - d.totalComplete;
    final notSubmitted = d.totalComplete - d.totalSubmitted;
    final pending = d.totalCandidates - d.totalWithResult;
    final success = d.successRate;

    return [
      // 1 ─ Ce que les écoles ont déclaré.
      KpiData(
        label: '1 · Candidats déclarés',
        value: '${d.totalCandidates}',
        sub: '${d.schoolsWithCandidates} école(s) · ${d.sessionCount} session(s)',
        icon: Icons.groups_rounded,
        color: kNavy,
        progressValue: d.totalCandidates > 0 ? 1 : 0,
        trend: d.yearLabel ?? '—',
      ),
      // 2 ─ Dont le dossier tient debout.
      KpiData(
        label: '2 · Dossiers complets',
        value: '${d.totalComplete}',
        sub: incomplete == 0
            ? 'aucun dossier incomplet'
            : '$incomplete incomplet(s) — pièces manquantes',
        icon: Icons.folder_shared_rounded,
        color: completeRate >= 0.8
            ? kGreen
            : (completeRate >= 0.5 ? kListOrange : kRed),
        progressValue: completeRate,
        trend: incomplete == 0 ? 'complet' : '−$incomplete',
        trendUp: incomplete == 0,
      ),
      // 3 ─ Que le chef d'établissement a validés.
      KpiData(
        label: '3 · Dossiers déposés',
        value: '${d.totalSubmitted}',
        sub: notSubmitted <= 0
            ? 'tous les dossiers complets sont déposés'
            : '$notSubmitted complet(s) pas encore déposé(s)',
        icon: Icons.assignment_turned_in_rounded,
        color: notSubmitted <= 0 ? kGreen : kAccent,
        progressValue:
            d.totalCandidates == 0 ? 0 : d.totalSubmitted / d.totalCandidates,
        trend: notSubmitted <= 0 ? 'à jour' : '−$notSubmitted',
        trendUp: notSubmitted <= 0,
      ),
      // 4 ─ Et qui sont réellement partis à la DEC.
      KpiData(
        label: '4 · Transmissions DEC',
        value: '${d.transmissionCount}',
        sub: d.transmissionsAcknowledged > 0
            ? '${d.transmissionsAcknowledged} accusé(s) de réception'
            : 'dépôts opposables à la DEC',
        icon: Icons.outbox_rounded,
        color: d.transmissionCount > 0 ? kGreen : kTextMuted,
        progressValue: d.transmissionCount > 0 ? 1 : 0,
        trend: d.transmissionCount > 0 ? 'transmis' : 'aucun dépôt',
        trendUp: d.transmissionCount > 0,
      ),
      // 5 ─ Ce que la DEC a proclamé en retour.
      KpiData(
        label: '5 · Résultats proclamés',
        value: '${d.totalWithResult}',
        // Le taux ne s'affiche JAMAIS sans son dénominateur : « 74 % » seul
        // ne se recoupe avec aucune publication.
        sub: success == null
            ? 'en attente de la DEC'
            : '${d.totalAdmitted} admis / ${d.totalWithResult} connus',
        icon: Icons.workspace_premium_rounded,
        color: kListPurple,
        progressValue:
            d.totalCandidates == 0 ? 0 : d.totalWithResult / d.totalCandidates,
        trend: success == null
            ? (pending > 0 ? '$pending en attente' : '—')
            : '${success.toStringAsFixed(1)} % de réussite',
        trendUp: true,
      ),
      // ── Alerte : le seul risque irrattrapable de la campagne ────────────
      KpiData(
        label: 'Écoles à risque',
        value: '${d.schoolsAtRisk}',
        sub: d.schoolsAtRisk > 0
            ? 'des candidats, aucune transmission'
            : '✅ toutes ont transmis',
        icon: Icons.report_problem_rounded,
        color: d.schoolsAtRisk > 0 ? kRed : kGreen,
        progressValue: d.schoolsWithCandidates == 0
            ? 0
            : 1 - (d.schoolsAtRisk / d.schoolsWithCandidates),
        trend: d.schoolsAtRisk > 0 ? '⚠ à relancer' : 'sous contrôle',
        trendUp: d.schoolsAtRisk == 0,
      ),
      // ── Module STAGES : le ministère pilote les deux modules ─────────────
      // Mais l'attestation ne conditionne QUE les bacs technique et
      // professionnel. Ces deux indicateurs disparaissent donc dès qu'on
      // regarde un autre examen : promener « Bacs bloqués » devant un
      // candidat au BET, c'est fabriquer une alerte qu'on apprend à ignorer.
      if (d.showsInternshipKpis) ...[
      KpiData(
        label: 'Stages du réseau',
        value: '${d.internshipsTotal}',
        sub: '${d.attestationsTotal} attestation(s) délivrée(s)',
        icon: Icons.engineering_rounded,
        color: kGreen,
        progressValue: d.internshipsTotal == 0
            ? 0
            : d.attestationsTotal / d.internshipsTotal,
        trend: d.internshipsTotal > 0
            ? '${(d.attestationsTotal * 100 / d.internshipsTotal).round()}% attestées'
            : '—',
      ),
      KpiData(
        label: 'Bacs bloqués',
        // Candidats de bac technique/pro sans attestation : dossier irrecevable.
        value: '${d.bacBlocked}',
        sub: d.bacBlocked == 0
            ? '✅ tous les bacs pro couverts'
            : 'stage manquant — dossier irrecevable',
        icon: Icons.gpp_maybe_rounded,
        color: d.bacBlocked == 0 ? kGreen : kRed,
        progressValue: d.bacBlocked == 0 ? 1 : 0,
        trend: d.bacBlocked == 0 ? 'OK' : '⚠ à traiter',
        trendUp: d.bacBlocked == 0,
      ),
      ],
    ];
  }
}

// ─── Graphique ────────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════════════════════
//  UN SEUL BOUTON D'EXPORT.
//
//  L'aperçu PDF porte déjà « Imprimer » et « Enregistrer » : ajouter ces deux
//  actions à côté ferait trois boutons pour un seul geste. Et pas de
//  « partager » — l'application n'a aucun canal sortant réel ; la relance par
//  notification reste le seul envoi de cet écran, et elle a son propre bouton.
// ════════════════════════════════════════════════════════════════════════════
class _ExportButton extends ConsumerWidget {
  const _ExportButton({
    required this.label,
    required this.title,
    required this.fileName,
    required this.buildPdf,
  });

  final String label;
  final String title;
  final String fileName;

  /// Nommé `buildPdf` et non `build` : un champ `build` entrerait en collision
  /// avec la méthode du widget.
  final Future<Uint8List> Function(String groupName) buildPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
        onPressed: () {
          final groupName =
              ref.read(adminDashboardProvider).valueOrNull?.groupName ??
                  'Ministère';
          showPdfPreviewDialog(
            context,
            title: title,
            subtitle: 'Chiffres de la plateforme — distincts des résultats '
                'proclamés par la DEC',
            pdfFileName: '$fileName.pdf',
            build: (_) => buildPdf(groupName),
          );
        },
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: kNavy,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
