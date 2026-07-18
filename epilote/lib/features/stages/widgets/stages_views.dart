import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/stages_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — ton par statut + graphique. Le rendu des lignes (groupé par classe,
//  virtualisé) vit dans stages_grouped.dart et réutilise `stageTone`.
// ════════════════════════════════════════════════════════════════════════════

(Color, String) stageTone(InternshipStatus s) => switch (s) {
      InternshipStatus.enCours => (kGreen, 'En cours'),
      InternshipStatus.valide => (kGreen, 'Validé'),
      InternshipStatus.termine => (kNavy, 'Terminé'),
      InternshipStatus.interrompu => (kRed, 'Interrompu'),
      InternshipStatus.prevu => (kTextMuted, 'Prévu'),
    };

// ─── Graphique : répartition par statut ───────────────────────────────────────
class StagesStatusChart extends StatelessWidget {
  const StagesStatusChart({super.key, required this.internships});
  final List<InternshipRow> internships;

  @override
  Widget build(BuildContext context) {
    final counts = <InternshipStatus, int>{};
    for (final i in internships) {
      counts[i.status] = (counts[i.status] ?? 0) + 1;
    }
    final data = [
      for (final s in InternshipStatus.values)
        if ((counts[s] ?? 0) > 0) (label: stageTone(s).$2, value: counts[s]!, tone: stageTone(s).$1),
    ];

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.insights_rounded, size: 20, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Le graphique se remplira dès le premier stage enregistré.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ]),
      );
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: 'Stages par statut',
          alignment: ChartAlignment.near,
          textStyle: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
        ),
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
        series: <CartesianSeries<({String label, int value, Color tone}), String>>[
          ColumnSeries<({String label, int value, Color tone}), String>(
            dataSource: data,
            xValueMapper: (d, _) => d.label,
            yValueMapper: (d, _) => d.value,
            pointColorMapper: (d, _) => d.tone,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: switch (data.length) {
              1 => 0.12,
              2 => 0.22,
              <= 4 => 0.4,
              _ => 0.6,
            },
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10, color: kTextMuted),
            ),
          ),
        ],
      ),
    );
  }
}
