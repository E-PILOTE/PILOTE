part of '../invoices_screen.dart';

// Cartouches et squelette de chargement.

class _KD {
  const _KD({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.progress,
  });
  final String  label, value;
  final String? sub;
  final double? progress;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final InvoicesData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total factures', value: '$n',
        sub: '${data.totalPaid} payées · ${data.totalPending} en attente',
        icon: Icons.description_rounded, color: _kNavy,
        progress: n > 0 ? data.totalPaid / n : 0,
      ),
      _KD(
        label: 'Payées', value: '${data.totalPaid}',
        sub: n > 0 ? '${(data.totalPaid * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: _kGreen,
        progress: n > 0 ? data.totalPaid / n : 0,
      ),
      _KD(
        label: 'En attente', value: '${data.totalPending}',
        sub: 'À encaisser',
        icon: Icons.hourglass_top_rounded, color: _kGold,
        progress: n > 0 ? data.totalPending / n : 0,
      ),
      _KD(
        label: 'En retard', value: '${data.totalOverdue}',
        sub: data.totalOverdue > 0 ? '⚠️ Action requise' : 'Aucun retard',
        icon: Icons.warning_amber_rounded, color: _kRed,
        progress: n > 0 ? data.totalOverdue / n : 0,
      ),
      _KD(
        label: 'Montant encaissé', value: '${_money(data.montantEncaisse)} F',
        sub: 'Total payé (XAF)',
        icon: Icons.account_balance_wallet_rounded, color: _kPurple,
        progress: data.montantEncaisse > 0 ? 1.0 : 0,
      ),
      _KD(
        label: 'Montant en attente', value: '${_money(data.montantPending)} F',
        sub: 'Pending + En retard',
        icon: Icons.pending_actions_rounded, color: _kOrange,
        progress: (data.montantEncaisse + data.montantPending) > 0
            ? data.montantPending / (data.montantEncaisse + data.montantPending)
            : 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
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
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        ), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(
                          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progress != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: d.progress!.clamp(0.0, 1.0),
                          backgroundColor: d.color.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                          minHeight: 4,
                        ),
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

// ─── Shimmer ──────────────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8ECF0),
    highlightColor: const Color(0xFFF5F7FA),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14,
            mainAxisSpacing: 14, childAspectRatio: 2.6,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
        ),
        const SizedBox(height: 20),
        _box(double.infinity, 110, r: 12),
        const SizedBox(height: 16),
        _box(160, 18, r: 8),
        const SizedBox(height: 16),
        _box(double.infinity, 44, r: 6),
        const SizedBox(height: 1),
        ...List.generate(7, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 56, r: 0),
        ])),
      ]),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
