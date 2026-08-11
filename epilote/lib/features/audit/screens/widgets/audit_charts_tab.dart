import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/audit_data.dart';
import '../../../../core/utils/message_erreur.dart';

/// Onglet « Graphiques » : timeline 30 j, répartition par action, top entités,
/// et — périmètre groupe uniquement — top écoles + top acteurs.
class AuditChartsTab extends ConsumerWidget {
  const AuditChartsTab(
      {super.key, required this.timelineAsync, required this.showSchools});
  final AsyncValue<AuditTimeline> timelineAsync;
  final bool showSchools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return timelineAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(color: kNavy),
        ),
      ),
      error: (e, _) =>
          Center(child: AdminErrorBanner(message: messageErreur(e, contexte: 'Graphiques'))),
      data: (timeline) {
        if (timeline.buckets.every((b) => b.total == 0)) {
          return const Padding(
            padding: EdgeInsets.only(top: 60),
            child: AdminEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Aucune donnée (30 derniers jours)',
              message:
                  'Les graphiques se rempliront dès que des événements auront été enregistrés.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ChartCard(
              title: 'Activité des 30 derniers jours',
              subtitle: 'Créations · Modifications · Suppressions par jour',
              child: SizedBox(
                height: 220,
                child: _TimelineChart(buckets: timeline.buckets),
              ),
            ),
            const SizedBox(height: 16),

            // Distribution + Top entités
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 700;
              final row = <Widget>[
                _ChartCard(
                  title: 'Répartition par action',
                  subtitle: '% Créations / Modifs / Suppressions',
                  child: SizedBox(
                    height: 200,
                    child: _DonutActionChart(buckets: timeline.buckets),
                  ),
                ),
                const SizedBox(width: 16, height: 16),
                _ChartCard(
                  title: 'Top entités',
                  subtitle: '5 entités les plus fréquentes',
                  child: SizedBox(
                    height: 200,
                    child: _TopEntitiesChart(entities: timeline.topEntities),
                  ),
                ),
              ];
              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: row[0]),
                      row[1],
                      Expanded(child: row[2]),
                    ],
                  ),
                );
              }
              return Column(children: row);
            }),
            const SizedBox(height: 16),

            // Top écoles (groupe) + Top acteurs
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 700;
              final actors = _RankingCard(
                title: 'Top acteurs (activité 30 j)',
                icon: Icons.person_rounded,
                items: timeline.topActors
                    .map((a) => (label: a.name, count: a.count))
                    .toList(),
                maxCount: timeline.topActors.isEmpty
                    ? 1
                    : timeline.topActors.first.count,
                barColor: const Color(0xFF6366F1),
                emptyMessage: 'Aucun acteur identifié',
              );
              if (!showSchools) return actors;

              final schools = _RankingCard(
                title: 'Top écoles (activité 30 j)',
                icon: Icons.school_rounded,
                items: timeline.topSchools
                    .map((s) => (label: s.name, count: s.count))
                    .toList(),
                maxCount: timeline.topSchools.isEmpty
                    ? 1
                    : timeline.topSchools.first.count,
                barColor: kNavy,
                emptyMessage: 'Aucune école dans les logs',
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: schools),
                    const SizedBox(width: 16),
                    Expanded(child: actors),
                  ],
                );
              }
              return Column(children: [schools, const SizedBox(height: 16), actors]);
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.buckets});
  final List<AuditDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final labeledIndices = <int>{0, 6, 13, 20, 27, buckets.length - 1};

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        labelPlacement: LabelPlacement.onTicks,
        axisLabelFormatter: (details) {
          final idx = details.value.toInt();
          if (!labeledIndices.contains(idx) ||
              idx < 0 ||
              idx >= buckets.length) {
            return ChartAxisLabel('', null);
          }
          return ChartAxisLabel(buckets[idx].dayLabel, null);
        },
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(
            width: 0.5, color: kBorder, dashArray: const [4, 4]),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        minimum: 0,
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(fontSize: 11, color: kTextMuted),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Créations',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.inserts.toDouble(),
          color: kGreen.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: BorderRadius.zero,
        ),
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Modifications',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.updates.toDouble(),
          color: kAccent.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: BorderRadius.zero,
        ),
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Suppressions',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.deletes.toDouble(),
          color: kRed.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
      ],
    );
  }
}

class _DonutActionChart extends StatelessWidget {
  const _DonutActionChart({required this.buckets});
  final List<AuditDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold(0, (s, b) => s + b.total);
    final inserts = buckets.fold(0, (s, b) => s + b.inserts);
    final updates = buckets.fold(0, (s, b) => s + b.updates);
    final deletes = buckets.fold(0, (s, b) => s + b.deletes);

    if (total == 0) {
      return Center(
          child: Text('Aucune donnée', style: TextStyle(color: kTextMuted)));
    }

    final data = [
      _ActionPct('Créations', inserts.toDouble(), kGreen),
      _ActionPct('Modifs', updates.toDouble(), kAccent),
      _ActionPct('Suppr.', deletes.toDouble(), kRed),
    ].where((d) => d.value > 0).toList();

    return SfCircularChart(
      margin: EdgeInsets.zero,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(fontSize: 11, color: kTextMuted),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        DoughnutSeries<_ActionPct, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, _) => d.color,
          innerRadius: '55%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ActionPct {
  const _ActionPct(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _TopEntitiesChart extends StatelessWidget {
  const _TopEntitiesChart({required this.entities});
  final List<AuditEntityStat> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return Center(
          child: Text('Aucune donnée', style: TextStyle(color: kTextMuted)));
    }
    return SfCartesianChart(
      margin: const EdgeInsets.all(0),
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(
            width: 0.5, color: kBorder, dashArray: const [4, 4]),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        BarSeries<AuditEntityStat, String>(
          dataSource: entities,
          xValueMapper: (e, _) => e.label,
          yValueMapper: (e, _) => e.count.toDouble(),
          color: kNavy.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(fontSize: 10),
          ),
          width: 0.5,
        ),
      ],
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.maxCount,
    required this.barColor,
    required this.emptyMessage,
  });
  final String title;
  final IconData icon;
  final List<({String label, int count})> items;
  final int maxCount;
  final Color barColor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyMessage,
                style: TextStyle(fontSize: 12.5, color: kTextMuted))
          else
            for (int i = 0; i < items.length; i++) ...[
              _RankingRow(
                rank: i + 1,
                label: items[i].label,
                count: items[i].count,
                maxCount: maxCount,
                barColor: barColor,
              ),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.label,
    required this.count,
    required this.maxCount,
    required this.barColor,
  });
  final int rank;
  final String label;
  final int count;
  final int maxCount;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final pct = maxCount > 0 ? count / maxCount : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(
            width: 20,
            child: Text('$rank.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted)),
          ),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: kSurface,
          valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: 0.7)),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}
