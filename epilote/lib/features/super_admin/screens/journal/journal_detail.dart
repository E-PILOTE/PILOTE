part of '../audit_screen.dart';

// Fiche détaillée d’une entrée et onglet JSON.

class _SubSectionTitle extends StatelessWidget {
  const _SubSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(this.rows);
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11 : 13, fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(message: 'Copier', child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copié : $value'), backgroundColor: _kNavy,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy)),
          )),
        ),
      ],
    ]),
  );
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({required this.icon, required this.color,
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
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

// ─── Modal détail du log ──────────────────────────────────────────────────────

class _AuditDetailModal extends StatefulWidget {
  const _AuditDetailModal({required this.log});
  final AuditLog log;
  @override
  State<_AuditDetailModal> createState() => _AuditDetailModalState();
}

class _AuditDetailModalState extends State<_AuditDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_actionIcon(l.action), color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l.actionLabel} · ${l.tableLabel}', style: TextStyle(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  _ActionBadge(action: l.action),
                  _RoleBadge(role: l.userRole),
                ]),
                const SizedBox(height: 4),
                Text(timeStr, style: TextStyle(color: _kMuted, fontSize: 11.5)),
              ])),
              _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
          // Tabs
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: 'Détail'), Tab(text: 'Valeurs JSON')],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _AuditDetailTab(log: l),
            _AuditJsonTab(log: l),
          ])),
          // Footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Fermer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});
  final String action;
  @override
  Widget build(BuildContext context) {
    final color = _actionColor(action);
    final log = AuditLog(id:'',userId:'',action:action,tableName:'',createdAt:DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_actionIcon(action), size: 11, color: color),
        const SizedBox(width: 4),
        Text(log.actionLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── Onglet Détail ────────────────────────────────────────────────────────────

class _AuditDetailTab extends StatelessWidget {
  const _AuditDetailTab({required this.log});
  final AuditLog log;
  @override
  Widget build(BuildContext context) {
    final l = log;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SubSectionTitle('Événement'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.flash_on_rounded, 'Action', l.actionLabel),
          _DetailRow(Icons.table_chart_rounded, 'Table', '${l.tableLabel} (${l.tableName})'),
          _DetailRow(Icons.calendar_today_rounded, 'Horodatage', _fmtDate(l.createdAt), last: true),
        ]),
        const SizedBox(height: 14),
        const _SubSectionTitle('Utilisateur'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.tag_rounded, 'User ID', l.userId, copyable: true, mono: true),
          _DetailRow(Icons.email_outlined, 'E-mail', l.userEmail ?? '—'),
          _DetailRow(Icons.badge_rounded, 'Rôle', l.userRoleLabel,
              last: l.ipAddress == null && l.recordId == null),
          if (l.ipAddress != null)
            _DetailRow(Icons.router_rounded, 'Adresse IP', l.ipAddress!,
                last: l.recordId == null),
          if (l.recordId != null)
            _DetailRow(Icons.fingerprint_rounded, 'ID enregistrement',
                l.recordId!, copyable: true, mono: true, last: true),
        ]),
        if (l.userAgent != null) ...[
          const SizedBox(height: 14),
          const _SubSectionTitle('Contexte technique'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder)),
            child: Text(l.userAgent!, style: TextStyle(
                fontSize: 11, color: _kMuted, fontFamily: 'monospace', height: 1.5)),
          ),
        ],
      ]),
    );
  }
}

// ─── Onglet Valeurs JSON ──────────────────────────────────────────────────────

class _AuditJsonTab extends StatelessWidget {
  const _AuditJsonTab({required this.log});
  final AuditLog log;

  String _prettyJson(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return '(aucune donnée)';
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  @override
  Widget build(BuildContext context) {
    final l = log;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (l.oldValues != null) ...[
          Row(children: [
            const _SubSectionTitle('Anciennes valeurs'),
            const Spacer(),
            _CopyBtn(text: _prettyJson(l.oldValues)),
          ]),
          const SizedBox(height: 8),
          _JsonBox(content: _prettyJson(l.oldValues), color: _kRed),
          const SizedBox(height: 16),
        ],
        if (l.newValues != null) ...[
          Row(children: [
            const _SubSectionTitle('Nouvelles valeurs'),
            const Spacer(),
            _CopyBtn(text: _prettyJson(l.newValues)),
          ]),
          const SizedBox(height: 8),
          _JsonBox(content: _prettyJson(l.newValues), color: _kGreen),
        ],
        if (l.oldValues == null && l.newValues == null)
          Container(
            padding: const EdgeInsets.all(24), alignment: Alignment.center,
            child: Text('Aucune donnée JSON disponible pour cet événement.',
                style: TextStyle(color: _kMuted, fontSize: 13)),
          ),
      ]),
    );
  }
}

class _JsonBox extends StatelessWidget {
  const _JsonBox({required this.content, required this.color});
  final String content;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: SelectableText(content, style: TextStyle(
        fontSize: 11.5, color: _kText, fontFamily: 'monospace',
        height: 1.6)),
  );
}

class _CopyBtn extends StatelessWidget {
  const _CopyBtn({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Tooltip(
      message: 'Copier JSON',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('JSON copié'), backgroundColor: _kNavy,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _kSurface, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.copy_rounded, size: 12, color: _kNavy),
            const SizedBox(width: 4),
            Text('Copier', style: TextStyle(fontSize: 11, color: _kNavy, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ),
  );
}
