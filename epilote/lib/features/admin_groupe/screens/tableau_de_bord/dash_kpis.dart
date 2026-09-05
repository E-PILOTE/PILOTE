part of '../admin_dashboard_screen.dart';

// Section des cartouches, compteurs animés, étincelles.

class _KpiSection extends ConsumerWidget {
  const _KpiSection({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = <_Kpi>[
      _Kpi(
        icon: Icons.account_balance_rounded,
        color: kNavy,
        rawValue: data.ecolesTotal,
        fmt: fmtInt,
        label: 'Écoles',
        sub: '${data.ecolesActives} active(s) · '
            '${data.publicCount} pub · ${data.priveCount} priv',
        spark: _Spark.progress,
        progress: data.ecolesTotal == 0 ? 0 : data.ecolesActives / data.ecolesTotal,
        onTap: () => context.go(Routes.adminEcoles),
      ),
      _Kpi(
        icon: Icons.groups_2_rounded,
        color: kGreen,
        rawValue: data.elevesTotal,
        fmt: fmtInt,
        label: 'Élèves',
        sub: '${data.studentsM} G · ${data.studentsF} F',
        trend: _pct(data.enrollmentGrowth),
        trendUp: data.enrollmentGrowth >= 0,
        spark: _Spark.area,
        areaPts: data.enrollmentTrend,
      ),
      _Kpi(
        icon: Icons.badge_rounded,
        color: _kBlue,
        rawValue: data.personnelTotal,
        fmt: fmtInt,
        label: 'Personnel',
        sub: '${data.enseignantsTotal} enseignant(s)',
        spark: _Spark.bars,
        bars: [for (final s in data.schools) MapEntry(s.name, s.staff)],
        onTap: () => context.go(Routes.adminUtilisateurs),
      ),
      _Kpi(
        icon: Icons.meeting_room_rounded,
        color: _kPurple,
        rawValue: data.classesTotal,
        fmt: fmtInt,
        label: 'Classes',
        sub: '${data.ecolesActives} école(s) active(s)',
        spark: _Spark.bars,
        bars: [for (final s in data.schools) MapEntry(s.name, s.classes)],
      ),
      _Kpi(
        icon: Icons.map_rounded,
        color: _kTeal,
        rawValue: data.coveredDepts,
        fmt: fmtInt,
        label: 'Départements couverts',
        sub: 'sur 15 au Congo',
        spark: _Spark.bars,
        bars: data.schoolsByDept.entries.toList(),
        onTap: () => ref.read(_adminTabProv.notifier).state = 1,
      ),
      _Kpi(
        icon: Icons.verified_rounded,
        color: kAccent,
        rawValue: data.tauxPaiement,
        fmt: (v) => '${v.round()} %',
        label: 'Taux de paiement',
        // « À jour » = a réglé au moins une tranche depuis la rentrée. Le
        // dire, sans quoi on croit lire un état au jour le jour.
        sub: '${data.elevesAJour}/${data.elevesTotal} depuis la rentrée',
        spark: _Spark.progress,
        progress: (data.tauxPaiement / 100).clamp(0, 1),
        onTap: () => context.go(Routes.adminRapports),
      ),
      _Kpi(
        icon: Icons.payments_rounded,
        color: _kOrange,
        rawValue: data.revenusMois,
        fmt: fmtCompact,
        label: data.revenusMoisLabel == null
            ? 'Revenus du mois'
            : 'Revenus · ${data.revenusMoisLabel}',
        sub: '${data.paiementsMoisCount} paiement(s)'
            '${data.revenusMoisLabel == null ? '' : ' · dernier mois encaissé'}',
        spark: _Spark.area,
        areaPts: data.revenueTrend,
        onTap: () => context.go(Routes.adminAbonnement),
      ),
      _Kpi(
        icon: Icons.donut_large_rounded,
        color: kRed,
        rawValue: data.tauxOccupationEleves,
        fmt: (v) => '${v.round()} %',
        label: 'Quota élèves',
        // `-1` = illimité : l'afficher tel quel donnerait « 1 234/-1 ».
        sub: data.maxStudents <= 0
            ? '${fmtInt(data.elevesTotal)}/∞'
            : '${fmtInt(data.elevesTotal)}/${fmtInt(data.maxStudents)}',
        spark: _Spark.progress,
        progress: (data.tauxOccupationEleves / 100).clamp(0, 1),
        onTap: () => context.go(Routes.adminAbonnement),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        final cols = w >= 1920 ? 8 : (w >= 1280 ? 4 : (w >= 920 ? 3 : (w >= 600 ? 2 : 1)));
        const gap = 16.0;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < kpis.length; i++)
              SizedBox(width: itemW, child: _KpiCard(kpi: kpis[i], index: i)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.kpi, required this.index});
  final _Kpi kpi;
  final int index;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kpi;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _hover ? k.color.withValues(alpha: 0.5) : kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04),
            blurRadius: _hover ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: k.color),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: k.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(k.icon, color: k.color, size: 22),
                      ),
                      if (k.trend != null)
                        _TrendPill(text: k.trend!, up: k.trendUp)
                      else if (k.onTap != null)
                        Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CountUp(
                    value: k.rawValue,
                    fmt: k.fmt,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(k.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600)),
                  if (k.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(k.sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 36, child: _spark(k)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final interactive = MouseRegion(
      cursor:
          k.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: k.onTap != null
          ? GestureDetector(onTap: k.onTap, child: card)
          : card,
    );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: interactive),
    );
  }

  Widget _spark(_Kpi k) => switch (k.spark) {
        _Spark.area => _SparkArea(pts: k.areaPts, color: k.color),
        _Spark.bars => _SparkBars(bars: k.bars, color: k.color),
        _Spark.progress => _SparkProgress(value: k.progress, color: k.color),
      };
}

class _CountUp extends StatefulWidget {
  const _CountUp({required this.value, required this.fmt, required this.style});
  final num value;
  final String Function(num) fmt;
  final TextStyle style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Text(
          widget.fmt(widget.value * t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.text, required this.up});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = up ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 12, color: c),
          const SizedBox(width: 3),
          Text(text,
              style:
                  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}

class _SparkArea extends StatelessWidget {
  const _SparkArea({required this.pts, required this.color});
  final List<MonthlyPoint> pts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = pts.fold<int>(0, (a, b) => a + b.value);
    if (pts.isEmpty || total == 0) return _FlatSpark(color: color);
    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      primaryXAxis: const CategoryAxis(isVisible: false),
      primaryYAxis: const NumericAxis(isVisible: false, minimum: 0),
      series: <CartesianSeries<MonthlyPoint, String>>[
        SplineAreaSeries<MonthlyPoint, String>(
          dataSource: pts,
          xValueMapper: (p, _) => p.month,
          yValueMapper: (p, _) => p.value,
          animationDuration: 1100,
          splineType: SplineType.natural,
          borderColor: color,
          borderWidth: 2,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ],
    );
  }
}

class _SparkBars extends StatelessWidget {
  const _SparkBars({required this.bars, required this.color});
  final List<MapEntry<String, int>> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxV = bars.isEmpty
        ? 0
        : bars.map((e) => e.value).reduce(math.max);
    if (bars.isEmpty || maxV == 0) return _FlatSpark(color: color);
    final show = bars.length > 12 ? bars.sublist(0, 12) : bars;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in show)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: ((e.value / maxV) * t).clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(
                            alpha: 0.45 + 0.55 * (e.value / maxV)),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
