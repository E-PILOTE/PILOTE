part of '../super_dashboard_screen.dart';

// Étincelles : courbe, barres, progression.

class _SparkChart extends StatelessWidget {
  const _SparkChart({required this.pts, required this.color, required this.type});
  final List<MonthlyPoint> pts;
  final Color              color;
  final _SparkType         type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBorderWidth: 0,
        margin: EdgeInsets.zero,
        primaryXAxis: const CategoryAxis(
            isVisible: false, borderColor: Colors.transparent),
        primaryYAxis: const NumericAxis(
            isVisible: false, borderColor: Colors.transparent, minimum: 0),
        series: _series(),
      ),
    );
  }

  List<CartesianSeries> _series() {
    switch (type) {

      // ── Ligne fine seule (Groupes actifs) ─────────────────────────────────
      case _SparkType.spline:
        return [
          SplineSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.85),
            width: 2.0, animationDuration: 1500,
            splineType: SplineType.natural,
            markerSettings: MarkerSettings(
              isVisible: true, shape: DataMarkerType.circle,
              width: 5, height: 5, color: color,
              borderColor: Colors.white, borderWidth: 1.4,
            ),
          ),
        ];

      // ── Zone remplie + ligne (Élèves, Revenus) ────────────────────────────
      case _SparkType.splineArea:
        return [
          SplineAreaSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            animationDuration: 1500, splineType: SplineType.natural,
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.40), color.withValues(alpha: 0.03)],
            ),
            borderColor: Colors.transparent, borderWidth: 0,
          ),
          SplineSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.85),
            width: 1.8, animationDuration: 1500,
            splineType: SplineType.natural,
            markerSettings: MarkerSettings(
              isVisible: true, shape: DataMarkerType.circle,
              width: 4, height: 4, color: color,
              borderColor: Colors.white, borderWidth: 1.2,
            ),
          ),
        ];

      // ── Colonnes verticales (Écoles actives) ──────────────────────────────
      case _SparkType.column:
        final shades = [0.40, 0.52, 0.65, 0.78, 0.90, 1.0];
        return [
          ColumnSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            borderRadius: BorderRadius.circular(3),
            spacing: 0.18, animationDuration: 1400,
            pointColorMapper: (_, i) =>
                color.withValues(alpha: shades[i < shades.length ? i : shades.length - 1]),
          ),
        ];

      default:
        return [];
    }
  }
}

// ─── Sparkline B : barres horizontales custom (Personnel, Abonnements) ───────
class _SparkBarH extends StatefulWidget {
  const _SparkBarH({required this.data, required this.color, this.delayMs = 420});
  final List<MapEntry<String, int>> data;
  final Color color; final int delayMs;
  @override
  State<_SparkBarH> createState() => _SparkBarHState();
}
class _SparkBarHState extends State<_SparkBarH>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.data.fold(0, (m, e) => e.value > m ? e.value : m);
    if (maxVal == 0) return const SizedBox.shrink();
    const shades = [1.0, 0.72, 0.50, 0.34];
    final rows = widget.data.take(4).toList();

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => SizedBox(
        height: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rows.asMap().entries.map((e) {
            final i    = e.key;
            final frac = (e.value.value / maxVal).clamp(0.0, 1.0) * _anim.value;
            final alpha = shades[i < shades.length ? i : shades.length - 1];
            return SizedBox(
              height: 6,
              child: Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(color: widget.color.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: alpha),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ]),
                )),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Sparkline C : barre de progression animée avec glow (Sync, SLA) ─────────
class _SparkProgress extends StatefulWidget {
  const _SparkProgress({required this.value, required this.max,
      required this.color, this.delayMs = 420});
  final double value, max;
  final Color  color;
  final int    delayMs;
  @override
  State<_SparkProgress> createState() => _SparkProgressState();
}
class _SparkProgressState extends State<_SparkProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.value / widget.max).clamp(0.0, 1.0);
    return SizedBox(
      height: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(children: [
            Text('0', style: TextStyle(
                color: widget.color.withValues(alpha: 0.35), fontSize: 7.5)),
            const Spacer(),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, _) => Text(
                '${(widget.value * _anim.value).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: widget.color.withValues(alpha: 0.75),
                    fontSize: 8, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(children: [
                Container(
                  height: 10,
                  color: widget.color.withValues(alpha: 0.10)),
                FractionallySizedBox(
                  widthFactor: pct * _anim.value,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.color.withValues(alpha: 0.60),
                        widget.color,
                      ]),
                      boxShadow: [BoxShadow(
                          color: widget.color.withValues(alpha: 0.55),
                          blurRadius: 8, spreadRadius: 1)],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5 · Graphiques ───────────────────────────────────────────────────────────
