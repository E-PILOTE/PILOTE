import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_panels.dart';
import '../widgets/notification_timeline.dart';
import '../widgets/notification_types.dart';
import '../widgets/send_notification_dialog.dart';

/// Écran Notifications — partagé scope-aware (super_admin / admin_groupe).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return AppShell(
      title: 'Notifications',
      child: Column(
        children: [
          _ActionBar(onRefresh: () => ref.invalidate(notificationsProvider)),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const NotifSkeleton(),
              error: (e, _) => NotifErrorView(
                error: e.toString(),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
              data: (data) => _Body(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barre d'action ──────────────────────────────────────────────────────────────
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: kCommCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => ref.read(notifSearchProvider.notifier).state = v,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les notifications…',
                  hintStyle: const TextStyle(fontSize: 12, color: kCommSub),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kCommSub),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCommBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCommBorder)),
                  filled: true, fillColor: kCommBg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              await markAllNotificationsRead(client);
              ref.invalidate(notificationsProvider);
            },
            icon: const Icon(Icons.done_all_rounded, size: 14),
            label: const Text('Tout marquer lu', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCommNavy,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SendNotificationDialog(
                  onSent: () => ref.invalidate(notificationsProvider)),
            ),
            icon: const Icon(Icons.notifications_active_rounded, size: 15),
            label: const Text('Envoyer'),
            style: FilledButton.styleFrom(
              backgroundColor: kCommNavy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            color: kCommNavy,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ─── Corps : filtres (gauche) + timeline (droite) ───────────────────────────────
class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final NotificationsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(notifTypeFilterProvider);
    final readFilter = ref.watch(notifReadFilterProvider);
    final search     = ref.watch(notifSearchProvider);

    var items = data.notifications;
    if (typeFilter != 'all') items = items.where((n) => n.type == typeFilter).toList();
    if (readFilter == 'unread') items = items.where((n) => !n.isRead).toList();
    if (readFilter == 'read')   items = items.where((n) => n.isRead).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q) ||
          (n.groupName?.toLowerCase().contains(q) ?? false)).toList();
    }

    final hasFilter = typeFilter != 'all' || readFilter != 'all' || search.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: Column(children: [
              NotifKpiPanel(data: data),
              const Divider(height: 1, color: kCommBorder),
              NotifFilterPanel(data: data),
            ]),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: items.isEmpty
              ? NotifEmptyState(hasFilter: hasFilter)
              : NotifTimeline(items: items),
        ),
      ],
    );
  }
}
