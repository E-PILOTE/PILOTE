part of '../admin_subscription_screen.dart';

// Quotas : grille, cartes et graphique.

class _QuotaGrid extends StatelessWidget {
  const _QuotaGrid({required this.sub});
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    double ratioOf(int used, int max) =>
        max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    String subOf(int used, int max) => max <= 0 ? 'Illimité' : '$used / $max';
    String trendOf(int used, int max) =>
        max <= 0 ? 'Illimité' : '${(used * 100 / max).round()}% utilisé';
    bool nearOf(int used, int max) => max > 0 && (used / max) >= 0.9;

    final items = <_QKD>[
      _QKD(
        label: 'Écoles', value: '${sub.schoolsUsed}',
        sub: subOf(sub.schoolsUsed, sub.maxSchools),
        icon: Icons.school_rounded, color: kNavy,
        progressValue: ratioOf(sub.schoolsUsed, sub.maxSchools),
        trend: trendOf(sub.schoolsUsed, sub.maxSchools),
        near: nearOf(sub.schoolsUsed, sub.maxSchools),
      ),
      _QKD(
        label: 'Élèves', value: '${sub.studentsUsed}',
        sub: subOf(sub.studentsUsed, sub.maxStudents),
        icon: Icons.groups_rounded, color: kGreen,
        progressValue: ratioOf(sub.studentsUsed, sub.maxStudents),
        trend: trendOf(sub.studentsUsed, sub.maxStudents),
        near: nearOf(sub.studentsUsed, sub.maxStudents),
      ),
      _QKD(
        label: 'Personnel', value: '${sub.staffUsed}',
        sub: subOf(sub.staffUsed, sub.maxStaff),
        icon: Icons.badge_rounded, color: kAccent,
        progressValue: ratioOf(sub.staffUsed, sub.maxStaff),
        trend: trendOf(sub.staffUsed, sub.maxStaff),
        near: nearOf(sub.staffUsed, sub.maxStaff),
      ),
      _QKD(
        label: 'Modules', value: '${sub.moduleCount}',
        sub: 'Modules actifs',
        icon: Icons.extension_rounded, color: const Color(0xFF7C3AED),
        trend: sub.estMinistere ? 'Inclus à la licence' : 'Inclus au plan',
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 14,
          mainAxisSpacing: 14, mainAxisExtent: 110,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _QuotaCard(d: items[i], idx: i),
      );
    });
  }
}

class _QKD {
  const _QKD({
    required this.label, required this.value, required this.icon, required this.color,
    this.sub, this.trend, this.progressValue, this.near = false,
  });
  final String label, value;
  final String? sub, trend;
  final bool near;
  final double? progressValue;
  final IconData icon;
  final Color color;
}

/// Carte KPI animée — design et dimensions identiques à la page Utilisateurs.
class _QuotaCard extends StatefulWidget {
  const _QuotaCard({required this.d, required this.idx});
  final _QKD d;
  final int idx;
  @override
  State<_QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<_QuotaCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final color = d.near ? kRed : d.color;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        )),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(
                          color: kTextMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Icon(d.near ? Icons.warning_amber_rounded : d.icon,
                            color: color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                                color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ])
                    else if (d.trend != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(d.trend!, style: TextStyle(
                          color: color, fontSize: 10, fontWeight: FontWeight.w600,
                        )),
                      ),
                  ]),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Graphe de consommation des quotas ────────────────────────────────────────
class _QChartData {
  const _QChartData(this.label, this.used, this.maxVal, this.color);
  final String label;
  final int used;
  final int maxVal; // 0 = illimité
  final Color color;

  double get pct => maxVal > 0 ? (used / maxVal * 100).clamp(0.0, 100.0) : 0.0;
  bool get unlimited => maxVal <= 0;
  String get displayMax => maxVal <= 0 ? '∞' : fmtInt(maxVal);
}

class _QuotaChart extends StatelessWidget {
  const _QuotaChart({required this.sub});
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    // Données : quotas avec une limite définie EN PREMIER (pour les barres),
    // quotas illimités affichés en chip séparé.
    final limited = <_QChartData>[
      if (sub.maxStudents > 0)
        _QChartData('Élèves', sub.studentsUsed, sub.maxStudents, kGreen),
      if (sub.maxStaff > 0)
        _QChartData('Personnel', sub.staffUsed, sub.maxStaff, kAccent),
      if (sub.maxSchools > 0)
        _QChartData('Écoles', sub.schoolsUsed, sub.maxSchools, kNavy),
    ];
    final unlimited = <_QChartData>[
      if (sub.maxStudents <= 0)
        _QChartData('Élèves', sub.studentsUsed, 0, kGreen),
      if (sub.maxStaff <= 0)
        _QChartData('Personnel', sub.staffUsed, 0, kAccent),
      if (sub.maxSchools <= 0)
        _QChartData('Écoles', sub.schoolsUsed, 0, kNavy),
    ];

    // Axe X : plage intelligente — zoom sur les valeurs réelles (min 5%)
    final maxPct = limited.fold<double>(0, (m, d) => max(m, d.pct));
    final xMax = max(5.0, maxPct * 1.5).ceilToDouble();

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── En-tête ──
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.bar_chart_rounded, color: kNavy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Analyse de consommation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
              Text('Utilisation de vos ressources par rapport aux limites du plan',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ]),
          ),
        ]),

        // ── Chips quotas illimités ──
        if (unlimited.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final d in unlimited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: d.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: d.color.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.all_inclusive_rounded, size: 13, color: d.color),
                  const SizedBox(width: 5),
                  Text('${d.label} : ${fmtInt(d.used)} (Illimité)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.color)),
                ]),
              ),
          ]),
        ],

        if (limited.isEmpty) ...[
          const SizedBox(height: 16),
          Center(child: Text('Tous les quotas de ce plan sont illimités.',
              style: TextStyle(fontSize: 13, color: kTextMuted))),
          const SizedBox(height: 8),
        ] else ...[
          // ── Légende ──
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final d in limited) ...[
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: d.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text('${d.label} : ${fmtInt(d.used)} / ${d.displayMax}  (${d.pct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
          // ── Graphe Syncfusion ──
          const SizedBox(height: 8),
          SizedBox(
            height: max(120.0, limited.length * 58.0 + 40),
            child: SfCartesianChart(
              plotAreaBackgroundColor: Colors.transparent,
              borderWidth: 0,
              margin: const EdgeInsets.only(bottom: 0),
              // BarSeries transpose le rendu : primaryXAxis = catégories (labels String),
              // primaryYAxis = valeurs numériques. Ne pas inverser — erreur type cast.
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w700),
              ),
              primaryYAxis: NumericAxis(
                minimum: 0,
                maximum: xMax,
                labelFormat: '{value}%',
                majorGridLines: MajorGridLines(color: kBorder, width: 0.6),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.x : point.y%',
                color: kNavy,
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              series: <CartesianSeries>[
                // Barre "utilisé"
                BarSeries<_QChartData, String>(
                  dataSource: limited,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.pct,
                  pointColorMapper: (d, _) => d.color,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  width: 0.45,
                  animationDuration: 700,
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    labelAlignment: ChartDataLabelAlignment.outer,
                    textStyle: TextStyle(fontSize: 11, color: kTextPrimary, fontWeight: FontWeight.w800),
                  ),
                  dataLabelMapper: (d, _) => '${d.pct.toStringAsFixed(1)}%',
                ),
                // Barre "disponible" (fond clair)
                BarSeries<_QChartData, String>(
                  dataSource: limited,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => xMax - d.pct,
                  pointColorMapper: (d, _) => d.color.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  width: 0.45,
                  animationDuration: 700,
                  isVisibleInLegend: false,
                  enableTooltip: false,
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Grille des plans ─────────────────────────────────────────────────────────
