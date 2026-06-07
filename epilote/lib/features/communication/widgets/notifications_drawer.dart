import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'notification_timeline.dart';
import 'notification_types.dart';
import 'send_notification_dialog.dart';

/// Drawer latéral « Centre de notifications » (style Windows).
/// Surface primaire : récentes + historique scrollable, actions, et
/// **deep-link** au clic (via `data.route` de la notification).
class NotificationsDrawer extends ConsumerStatefulWidget {
  const NotificationsDrawer({super.key});

  @override
  ConsumerState<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends ConsumerState<NotificationsDrawer> {
  bool _unreadOnly = false;

  Future<void> _openNotif(NotificationModel n) async {
    final client = ref.read(supabaseClientProvider);
    if (!n.isRead) {
      await markNotificationRead(client, n.id);
      ref.invalidate(notificationsProvider);
    }
    final route = n.data?['route'] as String?;
    if (!mounted) return;
    Scaffold.of(context).closeEndDrawer();
    if (route != null && route.isNotEmpty) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final data  = async.valueOrNull;
    final unread = data?.unread ?? 0;

    var items = data?.notifications ?? const [];
    if (_unreadOnly) items = items.where((n) => !n.isRead).toList();

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
            // ── Barre d'actions ───────────────────────────────────────────
            Container(
              color: kCommCard,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: !_unreadOnly,
                  onTap: () => setState(() => _unreadOnly = false),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Non lues',
                  selected: _unreadOnly,
                  onTap: () => setState(() => _unreadOnly = true),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tout marquer lu',
                  icon: const Icon(Icons.done_all_rounded, size: 20, color: kCommNavy),
                  onPressed: () async {
                    final client = ref.read(supabaseClientProvider);
                    await markAllNotificationsRead(client);
                    ref.invalidate(notificationsProvider);
                  },
                ),
                IconButton(
                  tooltip: 'Envoyer une notification',
                  icon: const Icon(Icons.add_rounded, size: 20, color: kCommNavy),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SendNotificationDialog(
                        onSent: () => ref.invalidate(notificationsProvider)),
                  ),
                ),
              ]),
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
                    ? NotifEmptyState(hasFilter: _unreadOnly)
                    : NotifTimeline(
                        items: items,
                        onTap: _openNotif,
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
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? kCommNavy : kCommBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? kCommNavy : kCommBorder),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kCommSub,
          )),
    ),
  );
}
