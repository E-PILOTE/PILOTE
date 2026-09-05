part of '../super_dashboard_screen.dart';

// Camembert des formules et graphique par département.

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth > 760) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: _PlanDonut(stats: stats)),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _DeptChart(stats: stats)),
      ]);
    }
    return Column(children: [
      _PlanDonut(stats: stats),
      const SizedBox(height: 16),
      _DeptChart(stats: stats),
    ]);
  });
}

// ─── DonutChart plans ─────────────────────────────────────────────────────────
class _CPt {
  const _CPt(this.label, this.y, this.color);
  final String label; final int y; final Color color;
}

class _PlanDonut extends StatelessWidget {
  const _PlanDonut({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    if (stats.groupesByPlan.isEmpty) {
      return _Card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.donut_large_rounded,
              title: "Plans d'abonnement", sub: 'Répartition des groupes'),
          const SizedBox(height: 24),
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Aucun groupe enregistré',
                style: TextStyle(color: _kMuted, fontSize: 13)),
          )),
        ],
      ));
    }

    final data  = stats.groupesByPlan
        .map((e) => _CPt(e.key, e.value, _planColor(e.key))).toList();
    final total = data.fold(0, (s, d) => s + d.y);

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.donut_large_rounded,
            title: "Plans d'abonnement",
            sub: '$total groupes · ${stats.abonnementsActifs} actifs'),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            SfCircularChart(
              backgroundColor: Colors.transparent,
              margin: EdgeInsets.zero,
              series: <CircularSeries>[
                DoughnutSeries<_CPt, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.y,
                  pointColorMapper: (d, _) => d.color,
                  animationDuration: 1200,
                  innerRadius: '62%', radius: '92%',
                  strokeColor: kCardBg, strokeWidth: 2.5,
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                ),
              ],
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_fmt(total), style: TextStyle(
                  color: _kText, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              Text('groupes', style: TextStyle(
                  color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 8,
            children: data.map((pt) => Row(mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: pt.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(pt.label, style: TextStyle(
                    color: _kText, fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: pt.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${pt.y}', style: TextStyle(
                      color: pt.color, fontSize: 10,
                      fontWeight: FontWeight.w700)),
                ),
              ])).toList()),
      ],
    ));
  }
}

// ─── Graphique Département interactif ─────────────────────────────────────────
class _DeptChart extends StatefulWidget {
  const _DeptChart({required this.stats});
  final SuperDashboardData stats;
  @override
  State<_DeptChart> createState() => _DeptChartState();
}
class _DeptChartState extends State<_DeptChart>
    with SingleTickerProviderStateMixin {
  String? _sel;
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 260));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _tap(String dept) {
    if (_sel == dept) { setState(() => _sel = null); _anim.reverse(); }
    else              { setState(() => _sel = dept);  _anim.forward(from: 0); }
  }

  @override
  Widget build(BuildContext context) {
    final data   = widget.stats.deptStats;
    final maxVal = data.isEmpty ? 1
        : data.fold(0, (m, d) => d.groupCount > m ? d.groupCount : m);
    final totalG = data.fold(0, (s, d) => s + d.groupCount);
    final totalE = data.fold(0, (s, d) => s + d.schoolCount);
    final selGroups = _sel != null
        ? data.firstWhere((d) => d.dept == _sel,
              orElse: () => const DeptStat(dept: '', groups: [])).groups
        : <DeptGroupInfo>[];

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.map_rounded, size: 17, color: _kNavy),
          const SizedBox(width: 8),
          Expanded(child: Text('Par Département', style: TextStyle(
              color: _kText, fontSize: 15, fontWeight: FontWeight.w700))),
          // « Démo » laissait croire que la carte montrait un jeu d'exemple.
          // Elle ne montre rien : il n'y a aucun groupe à répartir.
          if (widget.stats.deptStats.isNotEmpty)
            _Chip('Données réelles', _kGreen)
          else
            _Chip('Aucune donnée', _kMuted),
        ]),
        const SizedBox(height: 2),
        Text('$totalG groupe${totalG != 1 ? 's' : ''} · '
            '$totalE école${totalE != 1 ? 's' : ''}',
            style: TextStyle(color: _kMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text('Cliquez sur un département pour les détails',
            style: TextStyle(color: _kMuted.withValues(alpha: 0.55),
                fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        ...data.map((d) => _DBar(d: d, maxVal: maxVal,
            selected: _sel == d.dept, onTap: () => _tap(d.dept))),
        AnimatedSize(
          duration: const Duration(milliseconds: 290),
          curve: Curves.easeInOut,
          child: _sel != null && selGroups.isNotEmpty
              ? FadeTransition(opacity: _fade,
                  child: _DeptDetail(dept: _sel!, groups: selGroups,
                      onClose: () { setState(() => _sel = null); _anim.reverse(); }))
              : const SizedBox.shrink(),
        ),
      ],
    ));
  }
}
