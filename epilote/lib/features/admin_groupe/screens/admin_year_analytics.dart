part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANALYSES — évolution pluriannuelle, ventilation département / type, écoles.
// ════════════════════════════════════════════════════════════════════════════

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 38, color: kTextMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          ],
        ),
      );
}

// ─── Évolution pluriannuelle (élèves + classes) ────────────────────────────────
class _EvoPoint {
  const _EvoPoint(this.label, this.eleves, this.classes);
  final String label;
  final int eleves, classes;
}

class _EvolutionCard extends StatefulWidget {
  const _EvolutionCard({required this.years});
  final List<AdminYear> years;
  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, shared: true);

  @override
  Widget build(BuildContext context) {
    // Ordre chronologique (la liste source est triée DESC).
    final pts = widget.years.reversed
        .map((y) => _EvoPoint(y.label, y.eleves, y.classes))
        .toList();
    final hasData = pts.any((p) => p.eleves > 0 || p.classes > 0);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Évolution des effectifs',
              icon: Icons.show_chart_rounded,
              subtitle: 'Élèves inscrits et classes ouvertes par année scolaire'),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: !hasData
                ? const _ChartEmpty(
                    message: 'Les effectifs apparaîtront dès la préparation '
                        'des classes par les écoles.')
                : SfCartesianChart(
                    backgroundColor: Colors.transparent,
                    plotAreaBorderWidth: 0,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.top,
                      overflowMode: LegendItemOverflowMode.wrap,
                      textStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                      majorTickLines: MajorTickLines(size: 0),
                      labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: 0,
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      majorGridLines: MajorGridLines(
                        width: 1,
                        color: kBorder.withValues(alpha: 0.7),
                        dashArray: const <double>[4, 4],
                      ),
                      labelStyle:
                          const TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    axes: const <ChartAxis>[
                      NumericAxis(
                        name: 'yClasses',
                        opposedPosition: true,
                        minimum: 0,
                        axisLine: AxisLine(width: 0),
                        majorTickLines: MajorTickLines(size: 0),
                        majorGridLines: MajorGridLines(width: 0),
                        labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
                      ),
                    ],
                    series: <CartesianSeries<_EvoPoint, String>>[
                      SplineAreaSeries<_EvoPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.eleves,
                        name: 'Élèves',
                        animationDuration: 1000,
                        splineType: SplineType.natural,
                        borderColor: kGreen,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            kGreen.withValues(alpha: 0.26),
                            kGreen.withValues(alpha: 0.02),
                          ],
                        ),
                        markerSettings: const MarkerSettings(
                            isVisible: true,
                            height: 6,
                            width: 6,
                            color: kGreen),
                      ),
                      ColumnSeries<_EvoPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.classes,
                        name: 'Classes',
                        yAxisName: 'yClasses',
                        width: 0.32,
                        animationDuration: 1000,
                        color: kNavy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Ligne : département (barres) + type d'établissement (donut) ───────────────
class _AnalyticsRow extends ConsumerWidget {
  const _AnalyticsRow({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearAnalyticsProvider(year.id));
    final a = async.valueOrNull;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final dept = _DepartmentChart(analytics: a, loading: async.isLoading);
        final type = _TypeDonut(analytics: a, loading: async.isLoading);
        if (wide) {
          // ⚠️ Pas de CrossAxisAlignment.stretch ici : la Row est dans un
          // ListView (hauteur non bornée) → stretch force h=∞ et casse le rendu.
          // Les cartes s'auto-dimensionnent (alignées en haut) — Syncfusion ne
          // supporte pas les intrinsèques, donc IntrinsicHeight est exclu.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: dept),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: type),
            ],
          );
        }
        return Column(children: [dept, const SizedBox(height: 16), type]);
      },
    );
  }
}

class _DepartmentChart extends StatelessWidget {
  const _DepartmentChart({required this.analytics, required this.loading});
  final AdminYearAnalytics? analytics;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final data =
        (analytics?.byDepartment ?? const <YearDeptStat>[]).take(8).toList();
    final hasData = data.any((d) => d.eleves > 0);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Répartition par département',
              icon: Icons.map_rounded,
              subtitle: 'Élèves inscrits par département (année sélectionnée)'),
          const SizedBox(height: 14),
          SizedBox(
            height: 270,
            child: loading
                ? const Center(child: CircularProgressIndicator(color: kNavy))
                : !hasData
                    ? const _ChartEmpty(
                        message: 'Aucun élève inscrit sur cette année.')
                    : SfCartesianChart(
                        backgroundColor: Colors.transparent,
                        plotAreaBorderWidth: 0,
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(
                            enable: true, format: 'point.x : point.y élèves'),
                        primaryXAxis: const CategoryAxis(
                          majorGridLines: MajorGridLines(width: 0),
                          axisLine: AxisLine(width: 0),
                          majorTickLines: MajorTickLines(size: 0),
                          labelStyle:
                              TextStyle(fontSize: 11, color: kTextPrimary),
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          majorGridLines: MajorGridLines(
                            width: 1,
                            color: kBorder.withValues(alpha: 0.7),
                            dashArray: const <double>[4, 4],
                          ),
                          labelStyle:
                              const TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                        series: <CartesianSeries<YearDeptStat, String>>[
                          BarSeries<YearDeptStat, String>(
                            dataSource: data,
                            xValueMapper: (d, _) => d.department,
                            yValueMapper: (d, _) => d.eleves,
                            pointColorMapper: (d, i) => _palAt(i),
                            width: 0.66,
                            spacing: 0.2,
                            animationDuration: 900,
                            borderRadius: BorderRadius.circular(5),
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kTextMuted),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _TypeDonut extends StatelessWidget {
  const _TypeDonut({required this.analytics, required this.loading});
  final AdminYearAnalytics? analytics;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final data = (analytics?.byType ?? const <YearTypeStat>[])
        .where((t) => t.eleves > 0)
        .toList();
    final total = data.fold<int>(0, (a, t) => a + t.eleves);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle("Type d'établissement",
              icon: Icons.account_balance_rounded,
              subtitle: 'Élèves par statut'),
          const SizedBox(height: 6),
          SizedBox(
            height: 230,
            child: loading
                ? const Center(child: CircularProgressIndicator(color: kNavy))
                : total == 0
                    ? const _ChartEmpty(message: 'Aucune donnée.')
                    : SfCircularChart(
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(enable: true),
                        annotations: <CircularChartAnnotation>[
                          CircularChartAnnotation(
                            widget: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$total',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: kTextPrimary)),
                                const Text('élèves',
                                    style: TextStyle(
                                        fontSize: 11, color: kTextMuted)),
                              ],
                            ),
                          ),
                        ],
                        series: <CircularSeries<YearTypeStat, String>>[
                          DoughnutSeries<YearTypeStat, String>(
                            dataSource: data,
                            xValueMapper: (t, _) => _typeLabel(t.type),
                            yValueMapper: (t, _) => t.eleves,
                            pointColorMapper: (t, _) => _typeColor(t.type),
                            innerRadius: '66%',
                            animationDuration: 900,
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 8),
          ...data.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _typeColor(t.type),
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_typeLabel(t.type),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                    Text('${t.ecoles} écoles · ${t.classes} cl.',
                        style:
                            const TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Adoption par école (table) ────────────────────────────────────────────────
class _SchoolAdoptionCard extends ConsumerWidget {
  const _SchoolAdoptionCard({required this.year});
  final AdminYear year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminYearAnalyticsProvider(year.id));
    final a = async.valueOrNull;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle('Préparation par école',
              icon: Icons.account_tree_rounded,
              subtitle:
                  'État d\'adoption de l\'année ${year.label} par établissement',
              trailing: a == null
                  ? null
                  : AdminBadge('${a.ecolesPreparees}/${a.ecolesTotal} prêtes',
                      color: a.ecolesPreparees == a.ecolesTotal
                          ? kGreen
                          : kAccent)),
          const SizedBox(height: 12),
          if (async.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: kNavy)),
            )
          else if (a == null || a.bySchool.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: _ChartEmpty(message: 'Aucune école active dans le groupe.'),
            )
          else ...[
            const _AdoptionHeaderRow(),
            const Divider(height: 14, color: kBorder),
            ...a.bySchool.map((s) => _AdoptionRow(school: s)),
          ],
        ],
      ),
    );
  }
}

class _AdoptionHeaderRow extends StatelessWidget {
  const _AdoptionHeaderRow();
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted);
    return const Row(
      children: [
        Expanded(flex: 4, child: Text('Établissement', style: st)),
        Expanded(flex: 3, child: Text('Département', style: st)),
        Expanded(
            flex: 2,
            child:
                Text('Classes', style: st, textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Text('Élèves', style: st, textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Text('État', style: st, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _AdoptionRow extends StatelessWidget {
  const _AdoptionRow({required this.school});
  final YearSchoolStat school;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: school.adopted ? kGreen : kBorder,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(school.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(school.department,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text('${school.classes}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text('${school.eleves}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: AdminBadge(school.adopted ? 'Préparée' : 'En attente',
                  color: school.adopted ? kGreen : kTextMuted),
            ),
          ),
        ],
      ),
    );
  }
}
