import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_exams_provider.dart';
import '../widgets/admin_exams_breakdown.dart';
import '../widgets/admin_exams_views.dart';

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
      title: 'Examens nationaux',
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const ListShimmer(),
        error: (e, _) => ExamsErrorView(
            message: '$e', onRetry: () => ref.invalidate(adminExamsProvider)),
        data: (d) {
          final filtered = _filter(d.schools);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KpiGrid(items: _kpis(d)),
                const SizedBox(height: 20),
                ExamChart(bars: d.byExam, yearLabel: d.yearLabel),
                const SizedBox(height: 20),
                if (d.byFiliere.isNotEmpty || d.byDepartment.isNotEmpty) ...[
                  // Chiffres de la PLATEFORME : ce que nos écoles ont saisi,
                  // sur nos seuls établissements. Les résultats proclamés par
                  // la DEC vivent sur « Résultats & archives » — deux pages,
                  // pour que deux « réussites par département » aux valeurs
                  // différentes ne se touchent jamais.
                  ExamBreakdownRow(
                      filiere: d.byFiliere, departement: d.byDepartment),
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

  List<KpiData> _kpis(MinistryExamsData d) {
    final rate = d.totalCandidates == 0
        ? 0.0
        : d.totalComplete / d.totalCandidates;
    return [
      KpiData(
        label: 'Candidats déclarés',
        value: '${d.totalCandidates}',
        sub: '${d.schoolsWithCandidates} école(s) · ${d.sessionCount} session(s)',
        icon: Icons.groups_rounded,
        color: kNavy,
        progressValue: d.totalCandidates > 0 ? 1 : 0,
        trend: d.yearLabel ?? '—',
      ),
      KpiData(
        label: 'Dossiers complets',
        value: '${d.totalComplete}',
        sub: '${d.totalCandidates - d.totalComplete} incomplet(s)',
        icon: Icons.folder_shared_rounded,
        color: rate >= 0.8 ? kGreen : (rate >= 0.5 ? kListOrange : kRed),
        progressValue: rate,
        trend: '${(rate * 100).round()}% complets',
        trendUp: rate >= 0.5,
      ),
      KpiData(
        label: 'Transmissions DEC',
        value: '${d.transmissionCount}',
        sub: d.transmissionsAcknowledged > 0
            ? '${d.transmissionsAcknowledged} accusé(s) reçu(s)'
            : 'dépôts opposables',
        icon: Icons.outbox_rounded,
        color: d.transmissionCount > 0 ? kGreen : kTextMuted,
        progressValue: d.transmissionCount > 0 ? 1 : 0,
        trend: d.transmissionCount > 0 ? 'déposé' : 'aucun dépôt',
        trendUp: d.transmissionCount > 0,
      ),
      KpiData(
        label: 'Écoles à risque',
        value: '${d.schoolsAtRisk}',
        // Candidats déclarés mais AUCUNE transmission : après la clôture, une
        // année perdue. La seule alerte irrattrapable du pilotage.
        sub: d.schoolsAtRisk > 0
            ? 'candidats non transmis'
            : '✅ toutes ont transmis',
        icon: Icons.report_problem_rounded,
        color: d.schoolsAtRisk > 0 ? kRed : kGreen,
        progressValue: d.schoolsWithCandidates == 0
            ? 0
            : 1 - (d.schoolsAtRisk / d.schoolsWithCandidates),
        trend: d.schoolsAtRisk > 0 ? '⚠ à relancer' : 'sous contrôle',
        trendUp: d.schoolsAtRisk == 0,
      ),
      KpiData(
        label: 'Résultats reçus',
        value: '${d.totalWithResult}',
        sub: d.successRate == null
            ? 'en attente de la DEC'
            : '${d.successRate!.round()}% de réussite',
        icon: Icons.workspace_premium_rounded,
        color: kListPurple,
        progressValue:
            d.totalCandidates == 0 ? 0 : d.totalWithResult / d.totalCandidates,
        trend: d.totalWithResult > 0 ? '${d.totalAdmitted} admis' : '—',
        trendUp: true,
      ),
      KpiData(
        label: 'Dossiers déposés',
        value: '${d.totalSubmitted}',
        sub: 'validés par les chefs d\'établissement',
        icon: Icons.assignment_turned_in_rounded,
        color: kAccent,
        progressValue:
            d.totalCandidates == 0 ? 0 : d.totalSubmitted / d.totalCandidates,
        trend: d.totalCandidates > 0
            ? '${(d.totalSubmitted * 100 / d.totalCandidates).round()}%'
            : '—',
      ),
      // ── Module STAGES : le ministère pilote les deux modules ─────────────
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
    ];
  }
}

// ─── Graphique ────────────────────────────────────────────────────────────────
