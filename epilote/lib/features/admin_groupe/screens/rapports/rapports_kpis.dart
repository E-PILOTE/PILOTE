part of '../admin_reports_screen.dart';

// Cartouches du rapport.

class _KD {
  const _KD({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.progress,
  });
  final String label, value;
  final String? sub, trend;
  final bool trendUp;
  final double? progress;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<_KD> items;

  @override
  Widget build(BuildContext context) {
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

class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 50 * widget.idx), () {
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
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                  blurRadius: _hov ? 12 : 4,
                  offset: Offset(0, _hov ? 4 : 2),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      d.color,
                      d.color.withValues(alpha: _hov ? 0.9 : 0.4),
                    ])),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: d.color,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(d.label,
                                        style: TextStyle(
                                          color: kTextMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                    if (d.sub != null)
                                      Text(d.sub!,
                                          style: TextStyle(
                                            color:
                                                d.color.withValues(alpha: 0.70),
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child:
                                    Icon(d.icon, color: d.color, size: 18),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(children: [
                            if (d.progress != null)
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: d.progress!.clamp(0.0, 1.0),
                                    backgroundColor:
                                        d.color.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation(
                                        d.color.withValues(
                                            alpha: _hov ? 1.0 : 0.75)),
                                    minHeight: 4,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            if (d.trend != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(d.trend!,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          d.trendUp ? d.color : _kOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · SYNTHÈSE
// ════════════════════════════════════════════════════════════════════════════
