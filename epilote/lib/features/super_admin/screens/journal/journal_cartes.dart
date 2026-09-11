part of '../audit_screen.dart';

// Vue cartes, badge de rôle, état vide.

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.logs, required this.onView});
  final List<AuditLog> logs;
  final ValueChanged<AuditLog> onView;
  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.7,
      ),
      itemCount: logs.length,
      itemBuilder: (_, i) => _LogCard(log: logs[i], onView: () => onView(logs[i])),
    );
  }
}

class _LogCard extends StatefulWidget {
  const _LogCard({required this.log, required this.onView});
  final AuditLog log;
  final VoidCallback onView;
  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.4) : _kBorder),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_actionIcon(l.action), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.tableLabel, style: TextStyle(color: _kText, fontSize: 13,
                    fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                Text(l.actionLabel, style: TextStyle(color: color, fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _RoleBadge(role: l.userRole),
            ]),
            const Spacer(),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 12, color: _kMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(l.userEmail ?? '—',
                  style: TextStyle(fontSize: 11, color: _kMuted), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 12, color: _kMuted),
              const SizedBox(width: 4),
              Text(timeStr, style: TextStyle(fontSize: 11, color: _kMuted,
                  fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Badges & helpers ─────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String? role;
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    final log = AuditLog(id:'',userId:'',action:'',tableName:'',createdAt:DateTime.now(),userRole:role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(log.userRoleLabel, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64), alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun événement trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres pour afficher les logs.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Helpers dates & sections ─────────────────────────────────────────────────

const _moisFr = [
  'janvier','février','mars','avril','mai','juin',
  'juillet','août','septembre','octobre','novembre','décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year} à '
      '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
}
