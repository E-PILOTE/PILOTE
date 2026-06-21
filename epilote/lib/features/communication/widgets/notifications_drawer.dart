import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notifications_provider.dart';
import 'notification_timeline.dart';
import 'notification_types.dart';

/// Drawer latéral « Centre de notifications » (style Windows).
/// Surface **en lecture seule** : les notifications sont émises par le système
/// (paiements, absences, bulletins, échéances…), jamais saisies à la main.
/// Actions : filtrer, marquer lu, et **deep-link** au clic (via `data.route`).
class NotificationsDrawer extends ConsumerStatefulWidget {
  const NotificationsDrawer({super.key});

  @override
  ConsumerState<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends ConsumerState<NotificationsDrawer> {
  Future<void> _openNotif(NotificationModel n) async {
    if (!n.isRead) {
      await markNotifRead(ref, n.id);
    }
    final route = n.data?['route'] as String?;
    if (!mounted) return;
    Scaffold.of(context).closeEndDrawer();
    if (route != null && route.isNotEmpty) context.go(route);
  }

  Future<void> _confirmClearAll(int total) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: Text(
            'Supprimer définitivement vos $total notification(s) ? '
            'Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (ok == true) await clearAllNotif(ref);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final data  = async.valueOrNull;
    final unread = data?.unread ?? 0;
    final total  = data?.total ?? 0;
    final byType = data?.byType ?? const <String, int>{};

    final readFilter = ref.watch(notifReadFilterProvider);   // 'all' | 'unread'
    final typeFilter = ref.watch(notifTypeFilterProvider);   // 'all' | <type>
    final hasFilter  = readFilter != 'all' || typeFilter != 'all';

    var items = data?.notifications ?? const [];
    if (readFilter == 'unread') items = items.where((n) => !n.isRead).toList();
    if (typeFilter != 'all') {
      items = items.where((n) => n.type == typeFilter).toList();
    }

    return Drawer(
      width: 400,
      backgroundColor: kCommBg,
      child: SafeArea(
        child: Column(
          children: [
            // ── En-tête ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              decoration: const BoxDecoration(
                color: kCommCard,
                border: Border(bottom: BorderSide(color: kCommBorder)),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_rounded, color: kCommNavy, size: 20),
                const SizedBox(width: 8),
                const Text('Notifications',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kCommNavy)),
                const SizedBox(width: 8),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close_rounded, color: kCommSub),
                  onPressed: () => Scaffold.of(context).closeEndDrawer(),
                ),
              ]),
            ),
            // ── Barre d'actions (filtre lu/non-lu + actions globales) ─────
            Container(
              color: kCommCard,
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
              child: Row(children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: readFilter == 'all',
                  onTap: () =>
                      ref.read(notifReadFilterProvider.notifier).state = 'all',
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Non lues',
                  selected: readFilter == 'unread',
                  onTap: () =>
                      ref.read(notifReadFilterProvider.notifier).state = 'unread',
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tout marquer lu',
                  onPressed: unread == 0 ? null : () => markAllNotifRead(ref),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  color: kCommNavy,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Tout effacer',
                  onPressed: total == 0 ? null : () => _confirmClearAll(total),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  color: const Color(0xFFEF4444),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),
            // ── Filtre par TYPE (uniquement si ≥ 2 types présents) ────────
            if (byType.length >= 2)
              Container(
                color: kCommCard,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: typeFilter == 'all',
                        onTap: () => ref
                            .read(notifTypeFilterProvider.notifier)
                            .state = 'all',
                      ),
                      for (final entry in byType.entries) ...[
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '${notifTypeInfo(entry.key).label} (${entry.value})',
                          selected: typeFilter == entry.key,
                          color: notifTypeInfo(entry.key).color,
                          onTap: () => ref
                              .read(notifTypeFilterProvider.notifier)
                              .state = entry.key,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            // ── Liste ─────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Erreur : $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kCommSub, fontSize: 12)),
                  ),
                ),
                data: (_) => items.isEmpty
                    ? NotifEmptyState(hasFilter: hasFilter)
                    : NotifTimeline(
                        items: items,
                        onTap: _openNotif,
                        onDelete: (n) => deleteNotif(ref, n.id),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = kCommNavy,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color : kCommBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? color : kCommBorder),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : kCommSub,
                  )),
            ),
          ),
        ),
      );
}
