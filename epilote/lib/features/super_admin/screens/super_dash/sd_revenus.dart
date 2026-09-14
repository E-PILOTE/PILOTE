part of '../super_dashboard_screen.dart';

// Section revenus et sélecteur de période.

class _RevenueSection extends StatefulWidget {
  const _RevenueSection({required this.stats});
  final SuperDashboardData stats;
  @override
  State<_RevenueSection> createState() => _RevenueSectionState();
}

class _RevenueSectionState extends State<_RevenueSection> {
  int _preset = 6;

  List<MonthlyRevenue> get _shown {
    final all = widget.stats.revenueMonthly;
    return all.length >= _preset ? all.sublist(all.length - _preset) : all;
  }

  String get _periodLabel => _preset == 12 ? '12 mois' : '$_preset mois';

  @override
  Widget build(BuildContext context) {
    final shown      = _shown;
    final total      = shown.fold(0.0, (s, r) => s + r.amount);
    final hasData    = shown.any((r) => r.amount > 0);
    final isEstimate = widget.stats.revenueMonthly.every((r) => r.subscriptions == 0);

    // Variation vs période précédente (uniquement pour les presets fixes)
    double? variation;
    if (_preset > 0) {
      final all = widget.stats.revenueMonthly;
      if (all.length >= _preset * 2) {
        final prev      = all.sublist(all.length - _preset * 2, all.length - _preset);
        final prevTotal = prev.fold(0.0, (s, r) => s + r.amount);
        if (prevTotal > 0) variation = (total - prevTotal) / prevTotal * 100;
      }
    }

    final tooltipBehavior = TooltipBehavior(
      enable: true,
      color: _kNavy,
      header: '',
      format: 'point.x',
      builder: (data, point, series, pointIndex, seriesIndex) {
        final r = data as MonthlyRevenue;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kNavy, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.35),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.label} ${r.year}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10)),
              const SizedBox(height: 3),
              Text(_fmtRevenu(r.amount),
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800)),
              if (r.subscriptions > 0) ...[
                const SizedBox(height: 2),
                Text('${r.subscriptions} abonnement${r.subscriptions > 1 ? 's' : ''}',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10)),
              ],
            ],
          ),
        );
      },
    );

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ En-tête ────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_kGold, const Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Revenus & Abonnements', style: TextStyle(
                color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(isEstimate ? 'Projection estimée' : 'Données réelles Supabase',
                style: TextStyle(
                    color: isEstimate ? _kGold : _kGreen, fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ])),
          // Sélecteur de période
          _RevPeriodSelector(
            preset: _preset,
            onSelect: (m) => setState(() => _preset = m),
          ),
        ]),
        const SizedBox(height: 14),
        // ─ Total + variation ──────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmtRevenuFull(total), style: TextStyle(
                color: _kText, fontSize: 26, fontWeight: FontWeight.w900,
                letterSpacing: -0.8)),
            Text('Total · $_periodLabel · FCFA',
                style: TextStyle(color: _kMuted, fontSize: 11)),
          ]),
          const SizedBox(width: 12),
          if (variation != null) _VariationBadge(variation),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtRevenuFull(widget.stats.revenusXafMois),
                style: TextStyle(color: _kGold, fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text('MRR actuel', style: TextStyle(color: _kMuted, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 16),
        // ─ Graphique ──────────────────────────────────────────────────────
        SizedBox(
          height: 200,
          child: !hasData && shown.isNotEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text('Aucun revenu sur cette période',
                      style: TextStyle(color: _kMuted, fontSize: 13))))
              : shown.isEmpty
                  ? Center(child: CircularProgressIndicator(color: _kGold))
                  : SfCartesianChart(
                      backgroundColor: Colors.transparent,
                      plotAreaBorderWidth: 0,
                      margin: EdgeInsets.zero,
                      tooltipBehavior: tooltipBehavior,
                      primaryXAxis: CategoryAxis(
                        labelStyle: TextStyle(color: _kMuted, fontSize: 9.5,
                            fontWeight: FontWeight.w500),
                        majorGridLines: const MajorGridLines(width: 0),
                        axisLine: AxisLine(
                            color: _kMuted.withValues(alpha: 0.15), width: 1),
                        majorTickLines: const MajorTickLines(size: 0),
                      ),
                      primaryYAxis: const NumericAxis(
                        isVisible: false, minimum: 0,
                        borderColor: Colors.transparent,
                      ),
                      series: [
                        ColumnSeries<MonthlyRevenue, String>(
                          dataSource: shown,
                          xValueMapper: (r, _) => r.label,
                          yValueMapper: (r, _) => r.amount,
                          animationDuration: 1200,
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [_kGold, _kGold.withValues(alpha: 0.50)],
                          ),
                          spacing: 0.25, enableTooltip: true,
                        ),
                        SplineSeries<MonthlyRevenue, String>(
                          dataSource: shown,
                          xValueMapper: (r, _) => r.label,
                          yValueMapper: (r, _) => r.amount,
                          color: _kNavy.withValues(alpha: 0.70),
                          width: 2.0, animationDuration: 1500,
                          splineType: SplineType.natural,
                          enableTooltip: false,
                          markerSettings: MarkerSettings(
                            isVisible: true, shape: DataMarkerType.circle,
                            width: 7, height: 7, color: _kNavy,
                            borderColor: Colors.white, borderWidth: 2.0,
                          ),
                        ),
                      ],
                    ),
        ),
        const SizedBox(height: 10),
        // ─ Légende ────────────────────────────────────────────────────────
        Row(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_kGold, const Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('Revenus mensuels (FCFA)',
                style: TextStyle(color: _kMuted, fontSize: 10.5)),
          ]),
          const SizedBox(width: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 16, height: 2.5,
                color: _kNavy.withValues(alpha: 0.65)),
            const SizedBox(width: 2),
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: _kNavy, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Tendance', style: TextStyle(color: _kMuted, fontSize: 10.5)),
          ]),
        ]),
      ],
    ));
  }
}

// ─── Sélecteur de période (presets + date personnalisée) ─────────────────────
class _RevPeriodSelector extends StatelessWidget {
  const _RevPeriodSelector({required this.preset, required this.onSelect});
  final int preset;
  final ValueChanged<int> onSelect;

  static const _options = [1, 2, 3, 4, 5, 6, 12];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kMuted.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in _options)
        _RevPeriodChip(
          label: m == 12 ? '1A' : '${m}M',
          active: preset == m,
          onTap: () => onSelect(m),
        ),
    ]),
  );
}

class _RevPeriodChip extends StatelessWidget {
  const _RevPeriodChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool   active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : _kMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        )),
      ),
    ),
  );
}

// ─── Badge variation ──────────────────────────────────────────────────────────
class _VariationBadge extends StatelessWidget {
  const _VariationBadge(this.pct);
  final double pct;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (up ? _kGreen : _kRed).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (up ? _kGreen : _kRed).withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14, color: up ? _kGreen : _kRed),
        const SizedBox(width: 4),
        Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                color: up ? _kGreen : _kRed,
                fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Formatage ────────────────────────────────────────────────────────────────
String _fmt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtLg(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)} K';
  return _fmt(n);
}

String _fmtRevenu(double x) {
  if (x >= 1000000) return '${(x / 1000000).toStringAsFixed(1)} M';
  if (x >= 1000)    return '${(x / 1000).toStringAsFixed(0)} K';
  if (x == 0)       return '—';
  return _fmt(x.round());
}

String _fmtRevenuFull(double x) {
  if (x == 0)       return '0 FCFA';
  if (x >= 1000000) return '${(x / 1000000).toStringAsFixed(x >= 10000000 ? 1 : 2)} M FCFA';
  if (x >= 1000)    return '${(x / 1000).toStringAsFixed(0)} K FCFA';
  return '${x.round()} FCFA';
}
