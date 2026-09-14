part of '../admin_dashboard_screen.dart';

// Courbe des effectifs, camembert des types, répartition.

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final ench = _EnrollmentChart(data: data);
        final donut = _TypeDonut(data: data);
        if (c.maxWidth < 840) {
          return Column(children: [ench, const SizedBox(height: 18), donut]);
        }
        // IntrinsicHeight borne la hauteur (sinon « stretch » dans un ListView
        // vertical = contrainte infinie → le contenu disparaît sur grand écran).
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: ench),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: donut),
            ],
          ),
        );
      },
    );
  }
}

class _EnrollmentChart extends StatefulWidget {
  const _EnrollmentChart({required this.data});
  final AdminDashboardData data;

  @override
  State<_EnrollmentChart> createState() => _EnrollmentChartState();
}

class _EnrollmentChartState extends State<_EnrollmentChart> {
  late final TooltipBehavior _tt = TooltipBehavior(
    enable: true,
    color: kNavyDark,
    textStyle: const TextStyle(color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final pts = widget.data.enrollmentTrend;
    final total = pts.fold<int>(0, (a, b) => a + b.value);
    final growth = widget.data.enrollmentGrowth;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Évolution des inscriptions',
            icon: Icons.show_chart_rounded,
            subtitle: '6 derniers mois',
            trailing: total == 0
                ? null
                : _TrendPill(text: _pct(growth), up: growth >= 0),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: total == 0
                ? const _ChartEmpty(
                    message:
                        "Les inscriptions s'afficheront ici dès l'arrivée de vos premiers élèves.",
                  )
                : SfCartesianChart(
                    backgroundColor: Colors.transparent,
                    plotAreaBorderWidth: 0,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      labelStyle:
                          TextStyle(fontSize: 11, color: kTextMuted),
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
                          TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    series: <CartesianSeries<MonthlyPoint, String>>[
                      SplineAreaSeries<MonthlyPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.month,
                        yValueMapper: (p, _) => p.value,
                        name: 'Inscriptions',
                        animationDuration: 1400,
                        splineType: SplineType.natural,
                        borderColor: kGreen,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            kGreen.withValues(alpha: 0.28),
                            kGreen.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      SplineSeries<MonthlyPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.month,
                        yValueMapper: (p, _) => p.value,
                        name: 'Inscriptions',
                        animationDuration: 1400,
                        color: kGreen,
                        width: 2.5,
                        splineType: SplineType.natural,
                        markerSettings: MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 7,
                          width: 7,
                          borderWidth: 2,
                          borderColor: kGreen,
                          color: Colors.white,
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

class _Pt {
  const _Pt(this.label, this.y, this.color);
  final String label;
  final int y;
  final Color color;
}

class _TypeDonut extends StatefulWidget {
  const _TypeDonut({required this.data});
  final AdminDashboardData data;

  @override
  State<_TypeDonut> createState() => _TypeDonutState();
}

class _TypeDonutState extends State<_TypeDonut> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, format: 'point.x : point.y');

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final all = <_Pt>[
      _Pt('Public', d.publicCount, _kBlue),
      _Pt('Privé', d.priveCount, kGreen),
    ];
    final pts = all.where((p) => p.y > 0).toList();
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle(
            'Répartition & parité',
            icon: Icons.pie_chart_rounded,
            subtitle: 'Écoles par type · élèves par sexe',
          ),
          const SizedBox(height: 14),
          if (d.ecolesTotal == 0)
            const SizedBox(
              height: 150,
              child: _ChartEmpty(
                  message: 'Ajoutez vos écoles pour visualiser leur répartition.'),
            )
          else ...[
            SizedBox(
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SfCircularChart(
                    backgroundColor: Colors.transparent,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    series: <CircularSeries<_Pt, String>>[
                      DoughnutSeries<_Pt, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.y,
                        pointColorMapper: (p, _) => p.color,
                        animationDuration: 1100,
                        innerRadius: '64%',
                        radius: '92%',
                        strokeColor: kCardBg,
                        strokeWidth: 2.5,
                        dataLabelSettings:
                            const DataLabelSettings(isVisible: false),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtInt(d.ecolesTotal),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text('écoles',
                          style: TextStyle(fontSize: 11, color: kTextMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final p in all)
                  _LegendDot(color: p.color, text: '${p.label} ${p.y}'),
              ],
            ),
            Divider(height: 26, color: kBorder),
            Text('Parité élèves',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 10),
            _GenderRow(
                label: 'Garçons',
                count: d.studentsM,
                total: d.elevesTotal,
                color: _kBlue),
            const SizedBox(height: 8),
            _GenderRow(
                label: 'Filles',
                count: d.studentsF,
                total: d.elevesTotal,
                color: _kPink),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }
}

class _GenderRow extends StatelessWidget {
  const _GenderRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
        ),
        Expanded(
          child: AdminProgressBar(
              value: count, max: total <= 0 ? 1 : total, height: 8, color: color),
        ),
        const SizedBox(width: 10),
        Text('$count',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        if (total > 0)
          Text('  ·  $pct%',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded,
              size: 34, color: kTextMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ─── Ressources humaines · statut d'emploi (fonctionnaires / non) ───────────
// Nomenclature métier (fonction publique congolaise) :
//   • « Fonctionnaires de l'État » = agents titulaires (contrat permanent).
//   • « Personnel non fonctionnaire » = contractuels, vacataires, stagiaires.
