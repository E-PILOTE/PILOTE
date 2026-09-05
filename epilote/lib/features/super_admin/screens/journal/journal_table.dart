part of '../audit_screen.dart';

// Vue tableau.

class _TableView extends StatelessWidget {
  const _TableView({required this.logs, required this.onView});
  final List<AuditLog> logs;
  final ValueChanged<AuditLog> onView;

  static const _actionW  = 96.0;
  static const _timeW    = 140.0;
  static const _actionsW = 52.0;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: TextStyle(color: _kMuted, fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.4), overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const _EmptyState();
    return Container(
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SizedBox(width: _actionW,
                child: Text('Action', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Table', 2),
              _hdr('Utilisateur', 2),
              _hdr('Rôle', 2),
              _hdr('ID enregistrement', 3),
              SizedBox(width: _timeW,
                child: Text('Date & Heure', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              SizedBox(width: _actionsW,
                child: Center(child: Text('', style: TextStyle(color: _kMuted, fontSize: 11)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...logs.asMap().entries.map((e) => _TableRow(
            log: e.value, isOdd: e.key.isOdd,
            actionW: _actionW, timeW: _timeW, actionsW: _actionsW,
            onView: () => onView(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.log, required this.isOdd, required this.actionW,
    required this.timeW, required this.actionsW, required this.onView,
  });
  final AuditLog log;
  final bool isOdd;
  final double actionW, timeW, actionsW;
  final VoidCallback onView;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? _kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
          border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(
            width: widget.actionW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_actionIcon(l.action), size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(l.actionLabel, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.tableLabel, style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w700, color: _kText), overflow: TextOverflow.ellipsis),
                Text(l.tableName, style: TextStyle(fontSize: 10, color: _kMuted,
                    fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
              ]),
            ),
          )),
          Expanded(flex: 2, child: Text(l.userEmail ?? '—',
              style: TextStyle(fontSize: 12, color: _kText), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _RoleBadge(role: l.userRole)),
          Expanded(flex: 3, child: Text(l.recordId ?? '—',
              style: TextStyle(fontSize: 10.5, color: _kMuted, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: widget.timeW,
            child: Text(timeStr, style: TextStyle(fontSize: 11.5, color: _kMuted,
                fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Center(child: _ActionBtn(
              icon: Icons.visibility_rounded, color: _kBlue,
              tooltip: 'Voir le détail', onTap: widget.onView,
            )),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
