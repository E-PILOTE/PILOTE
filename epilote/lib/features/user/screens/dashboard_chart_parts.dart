part of 'user_dashboard_screen.dart';

// ─── Rangée de graphes (élèves/classe + répartition genre) ────────────────────
class _ChartsRow extends ConsumerWidget {
  const _ChartsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final gendersAsync = ref.watch(studentsByGenderProvider);
    final classes = classesAsync.valueOrNull ?? const <ClassModel>[];
    final genders = gendersAsync.valueOrNull ?? const [];

    // Distingue le CHARGEMENT initial (skeleton) de l'absence réelle de données
    // (état vide). Sans ça, l'utilisateur croit « aucune donnée » pendant la
    // première synchro offline-first.
    final classesLoading = classesAsync.isLoading && !classesAsync.hasValue;
    final gendersLoading = gendersAsync.isLoading && !gendersAsync.hasValue;

    // Robustesse au grand nombre de classes : au-delà de ~12 classes, les
    // libellés pivotés se tassent → on bascule en défilement horizontal avec une
    // largeur minimale par barre, plutôt que d'écraser le graphe.
    Widget barChart() => SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBorderWidth: 0,
          margin: EdgeInsets.zero,
          primaryXAxis: const CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            axisLine: AxisLine(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
            labelRotation: -35,
            labelIntersectAction: AxisLabelIntersectAction.rotate45,
          ),
          primaryYAxis: const NumericAxis(
            majorGridLines: MajorGridLines(width: 0.5, color: kBorder),
            axisLine: AxisLine(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
          ),
          tooltipBehavior:
              TooltipBehavior(enable: true, format: 'point.x : point.y élèves'),
          series: <CartesianSeries<ClassModel, String>>[
            ColumnSeries<ClassModel, String>(
              dataSource: classes,
              xValueMapper: (c, _) => c.name,
              yValueMapper: (c, _) => c.studentCount ?? 0,
              pointColorMapper: (c, i) => _kPalette[i % _kPalette.length],
              borderRadius: BorderRadius.circular(5),
              width: 0.62,
            ),
          ],
        );

    // Résumé textuel pour lecteur d'écran (un canvas Syncfusion est opaque a11y).
    final classTotal = classes.fold<int>(0, (s, c) => s + (c.studentCount ?? 0));
    final byClass = AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _ChartTitle('Élèves par classe', Icons.bar_chart_rounded),
        const SizedBox(height: 8),
        Semantics(
          label: classes.isEmpty
              ? 'Répartition des élèves par classe : aucune donnée.'
              : 'Répartition des élèves par classe : '
                  '${classes.length} classes, $classTotal élèves au total.',
          child: SizedBox(
            height: 220,
            child: classesLoading
                ? const _ChartLoading()
                : classes.isEmpty
                    ? const _ChartEmpty()
                    : LayoutBuilder(builder: (context, cc) {
                        final needed = classes.length * 46.0;
                        if (needed <= cc.maxWidth) return barChart();
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: needed, child: barChart()),
                        );
                      }),
          ),
        ),
      ]),
    );

    final total = genders.fold<int>(0, (s, g) => s + g.value);
    final genderSummary = genders.map((g) => '${g.value} ${g.label}').join(', ');
    final byGender = AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _ChartTitle('Répartition par genre', Icons.pie_chart_rounded),
        const SizedBox(height: 8),
        Semantics(
          label: total == 0
              ? 'Répartition des élèves par genre : aucune donnée.'
              : 'Répartition des élèves par genre : $genderSummary '
                  '(sur $total élèves).',
          child: SizedBox(
            height: 220,
            child: gendersLoading
                ? const _ChartLoading()
                : total == 0
                    ? const _ChartEmpty()
                    : SfCircularChart(
                  margin: EdgeInsets.zero,
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(fontSize: 11, color: kTextMuted),
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$total',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary)),
                        const Text('élèves',
                            style: TextStyle(fontSize: 10, color: kTextMuted)),
                      ]),
                    ),
                  ],
                  series: <CircularSeries<DashboardSlice, String>>[
                    DoughnutSeries<DashboardSlice, String>(
                      dataSource: genders,
                      xValueMapper: (g, _) => g.label,
                      yValueMapper: (g, _) => g.value,
                      pointColorMapper: (g, _) => _genderColor(g.label),
                      innerRadius: '64%',
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    ),
                  ],
                ),
          ),
        ),
      ]),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth > 720) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: byClass),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: byGender),
        ]);
      }
      return Column(children: [byClass, const SizedBox(height: 14), byGender]);
    });
  }

  static Color _genderColor(String label) => switch (label) {
        'Garçons' => kNavy,
        'Filles' => const Color(0xFFDB2777),
        _ => kTextMuted,
      };
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17, color: kNavy),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]);
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, size: 36, color: kBorder),
          SizedBox(height: 8),
          Text('Aucune donnée pour cette année',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

// État de CHARGEMENT (≠ vide) : pendant la 1ʳᵉ synchro offline-first.
class _ChartLoading extends StatelessWidget {
  const _ChartLoading();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: kNavy)),
          SizedBox(height: 10),
          Text('Chargement des données…',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}
