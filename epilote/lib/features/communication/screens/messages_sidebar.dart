part of 'messages_screen.dart';

// ─── Sidebar (dossiers + statistiques) ────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.data});
  final MessagesData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(messagesFilterProvider);

    return Container(
      width: 220,
      color: _kCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: FilledButton.icon(
              onPressed: () => _showCompose(context, ref),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Nouveau message'),
              style: FilledButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),
          _FolderItem(
            icon: Icons.inbox_rounded,
            label: 'Boîte de réception',
            value: 'inbox',
            current: folder,
            badge: data.unreadCount,
            badgeColor: _kNavy,
            onTap: () => _select(ref, 'inbox'),
          ),
          _FolderItem(
            icon: Icons.mark_email_unread_rounded,
            label: 'Non lus',
            value: 'unread',
            current: folder,
            badge: data.unreadCount,
            badgeColor: _kRed,
            onTap: () => _select(ref, 'unread'),
          ),
          _FolderItem(
            icon: Icons.send_rounded,
            label: 'Envoyés',
            value: 'sent',
            current: folder,
            onTap: () => _select(ref, 'sent'),
          ),
          _FolderItem(
            icon: Icons.all_inbox_rounded,
            label: 'Tous les messages',
            value: 'all',
            current: folder,
            badge: data.totalCount,
            badgeColor: _kSub,
            onTap: () => _select(ref, 'all'),
          ),
          _FolderItem(
            icon: Icons.archive_rounded,
            label: 'Archives',
            value: 'archived',
            current: folder,
            badge: data.archivedCount,
            badgeColor: _kSub,
            onTap: () => _select(ref, 'archived'),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Vue d'ensemble",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kSub,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                _SidebarStat(label: 'Total messages', value: '${data.totalCount}', color: _kNavy),
                const SizedBox(height: 6),
                _SidebarStat(label: 'Non lus', value: '${data.unreadCount}', color: _kRed),
                const SizedBox(height: 6),
                _SidebarStat(label: 'Archivés', value: '${data.archivedCount}', color: _kSub),
                const SizedBox(height: 12),
                const Text('Taux de lecture', style: TextStyle(fontSize: 10, color: _kSub)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.totalCount > 0
                        ? (data.totalCount - data.unreadCount) / data.totalCount
                        : 0,
                    minHeight: 6,
                    backgroundColor: _kBg,
                    valueColor: const AlwaysStoppedAnimation(_kGreen),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.totalCount > 0
                      ? '${(((data.totalCount - data.unreadCount) / data.totalCount) * 100).toStringAsFixed(0)}% lus'
                      : '—',
                  style: const TextStyle(fontSize: 10, color: _kSub),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(messagesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Actualiser', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, String folder) {
    ref.read(messagesFilterProvider.notifier).state = folder;
    ref.read(_selectedProv.notifier).state = null;
  }

  void _showCompose(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ComposeDialog(onSent: () => ref.invalidate(messagesProvider)),
    );
  }
}

class _FolderItem extends StatelessWidget {
  const _FolderItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  final int? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kNavy.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? _kNavy : _kSub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? _kNavy : _kText,
                )),
          ),
          if (badge != null && badge! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? _kSub).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? _kSub)),
            ),
        ]),
      ),
    );
  }
}

class _SidebarStat extends StatelessWidget {
  const _SidebarStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      );
}
