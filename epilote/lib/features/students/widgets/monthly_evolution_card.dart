import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GRAPHE D'ÉVOLUTION MENSUEL (réutilisable) — barres = flux du mois, courbe =
//  cumul. Pattern analytics standard (flux + stock). Paramétrable (libellés) →
//  utilisé par Inscriptions (rythme), Élèves (croissance effectif), etc.
// ════════════════════════════════════════════════════════════════════════════

class EvoPoint {
  const EvoPoint(this.label, this.count, this.cumul);
  final String label;
  final int count, cumul;
}

class MonthlyEvolutionCard extends StatelessWidget {
  MonthlyEvolutionCard({
    super.key,
    required this.points,
    this.barLabel = 'Entrées du mois',
    this.lineLabel = 'Effectif cumulé',
    Color? barColor,
    Color? lineColor,
  }) : barColor = barColor ?? kNavy, lineColor = lineColor ?? kGreen;
  final List<EvoPoint> points;
  final String barLabel, lineLabel;
  final Color barColor, lineColor;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Row(children: [
              _LegendDot(color: barColor, label: barLabel),
              const SizedBox(width: 16),
              _LegendDot(color: lineColor, label: lineLabel, line: true),
            ]),
          ),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              primaryYAxis: NumericAxis(
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
              ),
              axes: <ChartAxis>[
                NumericAxis(
                  name: 'cumul',
                  opposedPosition: true,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: const MajorGridLines(width: 0),
                  majorTickLines: const MajorTickLines(size: 0),
                  labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<EvoPoint, String>>[
                ColumnSeries<EvoPoint, String>(
                  name: barLabel,
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.count,
                  color: barColor.withValues(alpha: 0.85),
                  width: 0.55,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                SplineSeries<EvoPoint, String>(
                  name: lineLabel,
                  dataSource: points,
                  xValueMapper: (p, _) => p.label,
                  yValueMapper: (p, _) => p.cumul,
                  yAxisName: 'cumul',
                  color: lineColor,
                  width: 2.5,
                  markerSettings: const MarkerSettings(
                      isVisible: true, height: 5, width: 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(
      {required this.color, required this.label, this.line = false});
  final Color color;
  final String label;
  final bool line;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
          children: [
        Container(
          width: line ? 16 : 10,
          height: line ? 3 : 10,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(line ? 2 : 3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: kTextMuted)),
      ]);
}
