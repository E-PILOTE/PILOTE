part of '../admin_reports_screen.dart';

// Courbes, camemberts, barres et état vide.

class _TrendChart extends StatefulWidget {
  const _TrendChart({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
    this.icon = Icons.show_chart_rounded,
    this.money = false,
  });
  final String title, subtitle;
  final List<ReportTrendPoint> points;
  final Color color;
  final IconData icon;
  final bool money;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  late final TooltipBehavior _tt = TooltipBehavior(
    enable: true,
    color: kNavyDark,
    textStyle: const TextStyle(color: Colors.white),
    builder: (data, point, series, pointIndex, seriesIndex) {
      final p = data as ReportTrendPoint;
      final txt = widget.money ? fmtXaf(p.amount) : '${p.value}';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kNavyDark,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('${p.label} · $txt',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final total = widget.money
        ? pts.fold<double>(0, (a, b) => a + b.amount)
        : pts.fold<int>(0, (a, b) => a + b.value).toDouble();

    num yOf(ReportTrendPoint p) => widget.money ? p.amount : p.value;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(widget.title,
              icon: widget.icon, subtitle: widget.subtitle),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: total == 0
                ? const _ChartEmpty(
                    message: 'Aucune donnée sur la période sélectionnée.')
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
                      labelRotation: -35,
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
                      axisLabelFormatter: widget.money
                          ? (details) => ChartAxisLabel(
                              _compactXaf(details.value), details.textStyle)
                          : null,
                    ),
                    series: <CartesianSeries<ReportTrendPoint, String>>[
                      SplineAreaSeries<ReportTrendPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => yOf(p),
                        name: widget.title,
                        animationDuration: 1200,
                        splineType: SplineType.natural,
                        borderColor: widget.color,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.color.withValues(alpha: 0.28),
                            widget.color.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      SplineSeries<ReportTrendPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => yOf(p),
                        name: widget.title,
                        animationDuration: 1200,
                        color: widget.color,
                        width: 2.5,
                        splineType: SplineType.natural,
                        markerSettings: MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 7,
                          width: 7,
                          borderWidth: 2,
                          borderColor: widget.color,
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

// ════════════════════════════════════════════════════════════════════════════
//  DONUT CATÉGORIES (Syncfusion)
// ════════════════════════════════════════════════════════════════════════════
class _Slice {
  const _Slice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _CategoryDonut extends StatefulWidget {
  const _CategoryDonut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
  });
  final String title, subtitle, centerValue, centerLabel;
  final IconData icon;
  final List<_Slice> slices;

  @override
  State<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<_CategoryDonut> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, format: 'point.x : point.y');

  @override
  Widget build(BuildContext context) {
    final pts = widget.slices.where((s) => s.value > 0).toList();
    final hasData = pts.isNotEmpty;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(widget.title,
              icon: widget.icon, subtitle: widget.subtitle),
          const SizedBox(height: 14),
          if (!hasData)
            const SizedBox(
              height: 168,
              child: _ChartEmpty(message: 'Aucune donnée à répartir.'),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SfCircularChart(
                    backgroundColor: Colors.transparent,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    series: <CircularSeries<_Slice, String>>[
                      DoughnutSeries<_Slice, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.value,
                        pointColorMapper: (p, _) => p.color,
                        animationDuration: 1000,
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
                      Text(widget.centerValue,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(widget.centerLabel,
                          style: TextStyle(
                              fontSize: 11, color: kTextMuted)),
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
                for (final p in widget.slices)
                  _LegendDot(color: p.color, text: '${p.label} ${p.value}'),
              ],
            ),
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  BARRES DE DISTRIBUTION (catégories triées)
// ════════════════════════════════════════════════════════════════════════════
class _DistributionBars extends StatelessWidget {
  const _DistributionBars({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.data,
    required this.emptyMessage,
  });
  final String title, subtitle, emptyMessage;
  final IconData icon;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    const maxItems = 8;
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, int>> shown = entries;
    int autres = 0;
    if (entries.length > maxItems) {
      shown = entries.take(maxItems).toList();
      autres = entries.skip(maxItems).fold(0, (a, b) => a + b.value);
    }
    final maxV =
        shown.isEmpty ? 1 : shown.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(title, icon: icon, subtitle: subtitle),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            SizedBox(height: 120, child: _ChartEmpty(message: emptyMessage))
          else ...[
            ...shown.asMap().entries.map((e) {
              final color = _kPalette[e.key % _kPalette.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BarRow(
                    label: e.value.key,
                    value: e.value.value,
                    max: maxV,
                    color: color),
              );
            }),
            if (autres > 0)
              _BarRow(
                  label: 'Autres',
                  value: autres,
                  max: maxV,
                  color: kTextMuted),
          ],
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });
  final String label;
  final int value, max;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            Text(fmtInt(value),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 6),
          AdminProgressBar(
              value: value, max: max <= 0 ? 1 : max, height: 8, color: color),
        ],
      );
}

// ─── État vide graphique ────────────────────────────────────────────────────
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
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

// ════════════════════════════════════════════════════════════════════════════
//  SHIMMER (chargement)
// ════════════════════════════════════════════════════════════════════════════
