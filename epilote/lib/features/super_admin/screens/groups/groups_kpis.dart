part of '../school_groups_screen.dart';

// Cartouches de tête et squelette de chargement.

class _KD {
  const _KD({
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true,
    this.progressValue,
  });
  final String  label, value;
  final String? sub, trend;
  final bool    trendUp;
  final double? progressValue;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final SchoolGroupsData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Groupes',  value: '${data.total}',
        sub:   '${data.actifs} actifs · ${data.enEssai} essai',
        icon:  Icons.school_rounded,          color: _kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Actifs',         value: '${data.actifs}',
        sub:   n > 0 ? '${(data.actifs * 100 / n).round()}% du total' : '—',
        icon:  Icons.check_circle_rounded,    color: _kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Revenus/mois',   value: _fmtXaf(data.revenusTotal),
        sub:   'FCFA · abonnements actifs',
        icon:  Icons.payments_rounded,        color: _kGold,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0
            ? '${data.actifs} payant${data.actifs > 1 ? "s" : ""}' : '0 payant',
      ),
      _KD(
        label: 'Expirant 30j',   value: '${data.expirantBientot}',
        sub:   data.expirantBientot > 0 ? '⚠ Action requise' : '✅ À jour',
        icon:  Icons.timer_rounded,           color: _kOrange,
        progressValue: n > 0 ? data.expirantBientot / n : 0,
        trend: data.expirantBientot > 0 ? '⚠ Urgent' : '✅ Aucun',
        trendUp: data.expirantBientot == 0,
      ),
      _KD(
        label: 'En essai',       value: '${data.enEssai}',
        sub:   'Période gratuite',
        icon:  Icons.hourglass_top_rounded,   color: _kPurple,
        progressValue: n > 0 ? data.enEssai / n : 0,
        trend: data.enEssai > 0 ? 'À convertir' : 'Aucun',
        trendUp: false,
      ),
      _KD(
        label: 'Suspendus',      value: '${data.suspendus}',
        sub:   data.suspendus > 0 ? 'Impayés / bloqués' : '✅ Aucun',
        icon:  Icons.pause_circle_rounded,    color: _kRed,
        progressValue: n > 0 ? data.suspendus / n : 0,
        trend: data.suspendus > 0 ? '⚠ Débloquer' : '✅ OK',
        trendUp: data.suspendus == 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
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
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
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
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hov ? _kBorder : _kBorder,
                width: 1,
              ),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Bande accent colorée en haut ──────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                // ── Corps de la carte ─────────────────────────────────────
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        )),
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
                      // Icône en haut à droite
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
                    // ── Barre de progression + tendance ──────────────────
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: d.trendUp ? d.color : _kOrange,
                            fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ]),
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

// ─── Shimmer Skeleton (chargement initial) ────────────────────────────────────

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
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // KPI skeleton — grille 3×2
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 14,
              mainAxisSpacing: 14, childAspectRatio: 2.6,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 16),
          ),
          const SizedBox(height: 20),

          // FilterBar skeleton
          _box(double.infinity, 120, r: 14),
          const SizedBox(height: 16),

          // Result header skeleton
          _box(180, 18, r: 8),
          const SizedBox(height: 16),

          // Table rows skeleton
          _box(double.infinity, 48, r: 6),
          const SizedBox(height: 1),
          ...List.generate(6, (_) => Column(children: [
            const SizedBox(height: 1),
            _box(double.infinity, 56, r: 0),
          ])),
        ]),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
