import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/examens_provider.dart';
import '../widgets/examens_widgets.dart';

const _kSlug = 'examens';

// ════════════════════════════════════════════════════════════════════════════
//  EXAMENS D'ÉTAT — espace école, offline-first.
//
//  Lecture de haut en bas : sessions ouvertes (ce qui presse) → KPI → classes
//  d'examen groupées par diplôme → anomalies à qualifier.
//
//  Les classes de PASSAGE ne sont pas affichées : ce sont 32 classes sur 44 dans
//  le parc réel, sans aucun enjeu d'examen. Les lister noierait le signal.
// ════════════════════════════════════════════════════════════════════════════
class ExamensScreen extends ConsumerWidget {
  const ExamensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Examens',
        child: _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examOverviewProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const ListShimmer(kpiCount: 4, rowCount: 4),
      error: (e, _) => ExamErrorCard(message: '$e'),
      data: (o) {
        if (o.examClasses.isEmpty && o.anomalies.isEmpty) {
          return const ExamEmptyState();
        }

        final byExam = <String, List<ExamClassRow>>{};
        for (final c in o.examClasses) {
          byExam.putIfAbsent(c.examCode ?? '—', () => []).add(c);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Sessions : l'information périssable d'abord ────────────────
            for (final s in o.relevantSessions) ...[
              ExamSessionBanner(
                session: s,
                // Le bandeau mène à la page qui PRODUIT : candidats, couverture
                // par cycle/niveau/classe, liste officielle en PDF, export CSV.
                onTap: () => context.go(
                    Routes.examenSession.replaceFirst(':id', s.id)),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 4),
            _Kpis(
              overview: o,
              // KPI selon le profil d'accès : le socle (classes/élèves/candidats)
              // pour tout lecteur ; le KPI d'ACTION « restent à inscrire » n'a de
              // sens que pour qui peut inscrire.
              canRegister: () {
                final p = ref.watch(modulePermissionProvider(_kSlug));
                return (p?.canCreate ?? false) || (p?.canUpdate ?? false);
              }(),
            ),
            const SizedBox(height: 20),
            if (o.examClasses.isNotEmpty) ...[
              _CoverageChart(rows: o.examClasses),
              const SizedBox(height: 24),
            ],

            // ── Anomalies : avant les classes, car elles appellent une action ─
            if (o.anomalies.isNotEmpty) ...[
              ExamAnomalyCard(rows: o.anomalies),
              const SizedBox(height: 24),
            ],

            if (o.examClasses.isNotEmpty) ...[
              ExamSectionLabel(
                'Classes d\'examen',
                trailing: '${o.examClasses.length} classe(s)',
              ),
              const SizedBox(height: 12),
              for (final entry in byExam.entries) ...[
                ExamGroupCard(
                  examCode: entry.key,
                  examName: entry.value.first.examName ?? entry.key,
                  rows: entry.value,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.overview, required this.canRegister});
  final ExamOverview overview;

  /// Le profil peut-il inscrire ? Décide de faire ressortir le KPI d'action.
  final bool canRegister;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final coverage =
        o.studentsTotal == 0 ? 0.0 : o.candidatesTotal / o.studentsTotal;
    return KpiGrid(items: [
      // ── Socle : visible par tout profil qui accède au module ──────────────
      KpiData(
        label: 'Classes d\'examen',
        value: '${o.examClasses.length}',
        sub: o.anomalies.isEmpty
            ? 'toutes qualifiées'
            : '${o.anomalies.length} à qualifier',
        icon: Icons.workspace_premium_rounded,
        color: kNavy,
        progressValue: o.examClasses.isEmpty
            ? 0
            : 1 - (o.anomalies.length / o.examClasses.length),
        trend: o.anomalies.isEmpty ? '✅ OK' : '⚠ anomalies',
        trendUp: o.anomalies.isEmpty,
      ),
      KpiData(
        label: 'Élèves concernés',
        value: '${o.studentsTotal}',
        sub: 'en classe terminale',
        icon: Icons.groups_rounded,
        color: kGreen,
        progressValue: o.studentsTotal > 0 ? 1 : 0,
        trend: '${o.examClasses.length} classe(s)',
      ),
      KpiData(
        label: 'Candidats inscrits',
        value: '${o.candidatesTotal}',
        sub: 'sur ${o.studentsTotal} élève(s)',
        icon: Icons.how_to_reg_rounded,
        color: o.candidatesTotal == 0 ? kTextMuted : kAccent,
        progressValue: coverage,
        trend: '${(coverage * 100).round()}% couverts',
        trendUp: coverage >= 0.5,
      ),
      // ── Action : réservé à qui peut inscrire (create/update) ──────────────
      if (canRegister)
        KpiData(
          label: 'Restent à inscrire',
          value: '${o.missingTotal}',
          sub: o.missingTotal == 0
              ? 'tout le monde est inscrit'
              : 'élève(s) sans candidature',
          icon: Icons.pending_actions_rounded,
          color: o.missingTotal == 0 ? kGreen : kRed,
          progressValue: o.studentsTotal == 0
              ? 1
              : 1 - (o.missingTotal / o.studentsTotal),
          trend: o.missingTotal == 0 ? '✅ complet' : 'à inscrire',
          trendUp: o.missingTotal == 0,
        )
      else
        // Lecteur seul : une lecture NEUTRE de la couverture, pas une consigne.
        KpiData(
          label: 'Couverture',
          value: '${(coverage * 100).round()} %',
          sub: '${o.candidatesTotal}/${o.studentsTotal} inscrits',
          icon: Icons.donut_large_rounded,
          color: coverage >= 0.8 ? kGreen : (coverage >= 0.5 ? kAccent : kRed),
          progressValue: coverage,
          trend: coverage >= 0.8 ? 'bonne' : 'partielle',
          trendUp: coverage >= 0.5,
        ),
    ]);
  }
}

/// Couverture d'inscription par examen : inscrits vs effectif. Le déficit saute
/// aux yeux — c'est ce qu'on doit combler avant la clôture.
class _CoverageChart extends StatelessWidget {
  const _CoverageChart({required this.rows});
  final List<ExamClassRow> rows;

  @override
  Widget build(BuildContext context) {
    final byExam = <String, ({int effectif, int candidates})>{};
    for (final c in rows) {
      final k = c.examShortName ?? c.examCode ?? '—';
      final cur = byExam[k] ?? (effectif: 0, candidates: 0);
      byExam[k] =
          (effectif: cur.effectif + c.effectif, candidates: cur.candidates + c.candidates);
    }
    final data = [
      for (final e in byExam.entries)
        (exam: e.key, effectif: e.value.effectif, candidates: e.value.candidates),
    ]..sort((a, b) => b.effectif.compareTo(a.effectif));

    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: 'Couverture d\'inscription par examen',
          alignment: ChartAlignment.near,
          textStyle: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
        ),
        legend: Legend(
            isVisible: true,
            position: LegendPosition.top,
            textStyle: TextStyle(fontSize: 11, color: kTextMuted)),
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
          axisLine: AxisLine(color: kBorder),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(width: 0.5, color: kBorder),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<({String exam, int effectif, int candidates}), String>>[
          ColumnSeries<({String exam, int effectif, int candidates}), String>(
            name: 'Effectif',
            dataSource: data,
            xValueMapper: (d, _) => d.exam,
            yValueMapper: (d, _) => d.effectif,
            color: kTextMuted.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            width: data.length <= 3 ? 0.4 : 0.6,
          ),
          ColumnSeries<({String exam, int effectif, int candidates}), String>(
            name: 'Inscrits',
            dataSource: data,
            xValueMapper: (d, _) => d.exam,
            yValueMapper: (d, _) => d.candidates,
            color: kAccent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            width: data.length <= 3 ? 0.4 : 0.6,
          ),
        ],
      ),
    );
  }
}
