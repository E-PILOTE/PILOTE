part of '../super_dashboard_screen.dart';

// Détail d’un département et badges.

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w600)));
}

class _DBar extends StatefulWidget {
  const _DBar({required this.d, required this.maxVal,
      required this.selected, required this.onTap});
  final DeptStat d; final int maxVal;
  final bool selected; final VoidCallback onTap;
  @override
  State<_DBar> createState() => _DBarState();
}
class _DBarState extends State<_DBar> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final d   = widget.d;
    final frc = widget.maxVal > 0 ? d.groupCount / widget.maxVal : 0.0;
    final col = _deptColor(d.dept);
    final sel = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = true),
        onExit:  (_) => setState(() => _hov = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? col.withValues(alpha: 0.07)
                  : _hov ? Colors.grey.withValues(alpha: 0.04) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? col.withValues(alpha: 0.28) : Colors.transparent),
            ),
            child: Column(children: [
              Row(children: [
                SizedBox(width: 96, child: Text(d.dept, style: TextStyle(
                    color: sel ? col : _kText, fontSize: 12,
                    fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 11, color: col.withValues(alpha: 0.10)),
                    FractionallySizedBox(widthFactor: frc,
                        child: Container(height: 11,
                            decoration: BoxDecoration(color: col,
                                borderRadius: BorderRadius.circular(4)))),
                  ]),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 22, child: Text('${d.groupCount}',
                    textAlign: TextAlign.right, style: TextStyle(
                        color: col, fontSize: 12, fontWeight: FontWeight.w700))),
                const SizedBox(width: 4),
                Icon(sel ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 15, color: _kMuted),
              ]),
              Row(children: [
                const SizedBox(width: 96),
                Text('${d.schoolCount} école${d.schoolCount != 1 ? 's' : ''}',
                    style: TextStyle(
                        color: _kMuted.withValues(alpha: 0.65), fontSize: 10)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DeptDetail extends StatelessWidget {
  const _DeptDetail({required this.dept, required this.groups,
      required this.onClose});
  final String dept; final List<DeptGroupInfo> groups;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _deptColor(dept).withValues(alpha: 0.25))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: Row(children: [
            Container(width: 4, height: 18,
                decoration: BoxDecoration(color: _deptColor(dept),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Groupes · $dept', style: TextStyle(
                color: _deptColor(dept), fontSize: 12.5,
                fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${groups.length} groupe${groups.length > 1 ? 's' : ''}',
                style: TextStyle(color: _kMuted, fontSize: 11)),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onClose,
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted))),
          ]),
        ),
        Divider(height: 1, color: kBorder),
        ...groups.map((g) => _GRow(g: g)),
      ]),
    );
  }
}

class _GRow extends StatefulWidget {
  const _GRow({required this.g});
  final DeptGroupInfo g;
  @override
  State<_GRow> createState() => _GRowState();
}
class _GRowState extends State<_GRow> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final g  = widget.g;
    final pc = _planColor(g.planName);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => context.go(Routes.superGroupes),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          color: _hov ? _kNavy.withValues(alpha: 0.03) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    color: pc.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(Icons.school_rounded, size: 15, color: pc)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: TextStyle(
                    color: _kText, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  _PBadge(g.planName), const SizedBox(width: 6),
                  Text('${g.schoolsCount} école${g.schoolsCount != 1 ? 's' : ''}',
                      style: TextStyle(color: _kMuted, fontSize: 10)),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _SBadge(g.status),
              if (g.subscriptionEnd != null) ...[
                const SizedBox(height: 2),
                Text('exp. ${DateFormat('dd/MM/yy').format(g.subscriptionEnd!)}',
                    style: TextStyle(
                        color: g.expiresBientot ? _kOrange : _kMuted,
                        fontSize: 9.5, fontWeight: FontWeight.w500)),
              ],
            ]),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kMuted),
          ]),
        ),
      ),
    );
  }
}

class _PBadge extends StatelessWidget {
  const _PBadge(this.p);
  final String p;
  @override
  Widget build(BuildContext context) {
    final c = _planColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(p, style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w700)));
  }
}

class _SBadge extends StatelessWidget {
  const _SBadge(this.s);
  final String s;
  static Map<String, (String, Color)> get _map => {
    'active':    ('Actif',    _kGreen),
    'trial':     ('Essai',    _kBlue),
    'expired':   ('Expiré',   _kRed),
    'suspended': ('Suspendu', _kOrange),
  };
  @override
  Widget build(BuildContext context) {
    final (label, color) = _map[s] ?? ('—', _kMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ]));
  }
}

// ─── 6 · Bas de page ──────────────────────────────────────────────────────────
