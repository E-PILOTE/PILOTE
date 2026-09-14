part of '../admin_access_screen.dart';

// Cartouches de tete et squelette de chargement.

class _KD {
  const _KD({
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true, this.progressValue,
  });
  final String label, value;
  final String? sub, trend;
  final bool trendUp;
  final double? progressValue;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AdminAccessData data;

  @override
  Widget build(BuildContext context) {
    final n        = data.profiles.length;
    final actifs   = data.activeProfiles;
    final inactifs = data.inactiveProfiles;
    final covered  = data.totalCoveredMembers;
    final without  = data.withoutProfile;
    final accessible = data.accessibleModules;
    final totalMods  = data.totalModules;

    final items = [
      _KD(
        label: 'Profils',
        value: '$n',
        sub: '$actifs actifs · $inactifs inactifs',
        icon: Icons.shield_rounded, color: _kPurple,
        progressValue: n > 0 ? actifs / n : 0,
        trend: n > 0 ? '${(actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Actifs',
        value: '$actifs',
        sub: n > 0 ? '${(actifs * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: kGreen,
        progressValue: n > 0 ? actifs / n : 0,
        trend: actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Inactifs',
        value: '$inactifs',
        sub: inactifs > 0 ? '⚠ Profils bloqués' : '✅ Aucun',
        icon: Icons.block_rounded, color: kRed,
        progressValue: n > 0 ? inactifs / n : 0,
        trend: inactifs > 0 ? '⚠ À vérifier' : '✅ OK',
        trendUp: inactifs == 0,
      ),
      _KD(
        label: 'Modules du plan',
        value: '$accessible/$totalMods',
        sub: 'inclus dans votre abonnement',
        icon: Icons.widgets_rounded, color: kNavy,
        progressValue: totalMods > 0 ? accessible / totalMods : 0,
        trend: totalMods > 0 ? '${(accessible * 100 / totalMods).round()}% couverts' : '—',
      ),
      _KD(
        label: 'Membres couverts',
        value: '$covered',
        sub: 'comptes rattachés à un profil',
        icon: Icons.people_rounded, color: _kBlue,
        progressValue: null,
        trend: covered > 0 ? 'Personnel encadré' : 'Aucun rattachement',
        trendUp: covered > 0,
      ),
      _KD(
        label: 'Sans profil attribué',
        value: '$without',
        sub: without > 0 ? 'Membres à configurer' : '✅ Tous rattachés',
        icon: Icons.person_off_rounded, color: _kOrange,
        progressValue: null,
        trend: without > 0 ? '⚠ À traiter' : '✅ Complet',
        trendUp: without == 0,
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
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
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
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
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
                          color: kTextMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
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
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    Row(children: [
                      if (d.progressValue != null)
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                                d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        ))
                      else
                        const Spacer(),
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

// ─── Shimmer Skeleton ─────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(r)),
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
        _box(double.infinity, 120, r: 8),
        const SizedBox(height: 16),
        _box(200, 18, r: 8),
        const SizedBox(height: 16),
        _box(double.infinity, 48, r: 6),
        ...List.generate(6, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 60, r: 0),
        ])),
      ]),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
