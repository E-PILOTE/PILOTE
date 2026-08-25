import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notifications_provider.dart';
import 'comm_text.dart' show fmtRelativeFr;
import 'notification_types.dart';

/// Cloche de notification du header avec **dropdown** : aperçu des dernières
/// notifications + bouton « Tout afficher » qui ouvre le drawer complet.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, required this.onSeeAll});

  /// Appelé par « Tout afficher » → ouvre le drawer (`openEndDrawer`).
  final VoidCallback onSeeAll;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  // Capturé depuis le builder du MenuAnchor → permet de FERMER le dropdown au
  // clic (deep-link / Tout afficher) sans passer un controller explicite (qui
  // empêchait l'ouverture). Évalué paresseusement au moment du tap.
  MenuController? _ctrl;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(notifBadgeProvider);

    return MenuAnchor(
      alignmentOffset: const Offset(-300, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(kCommBg),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: kCommBorder),
          ),
        ),
      ),
      menuChildren: [
        _NotifDropdownPanel(
          onClose: () => _ctrl?.close(),
          onSeeAll: () {
            _ctrl?.close();
            widget.onSeeAll();
          },
        ),
      ],
      builder: (context, controller, child) {
        _ctrl = controller;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined,
                  color: kTextMuted, size: 22),
              tooltip: 'Notifications',
              // Curseur main au survol (desktop) pour signaler le clic.
              mouseCursor: SystemMouseCursors.click,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
            if (unread > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotifDropdownPanel extends ConsumerWidget {
  const _NotifDropdownPanel({required this.onSeeAll, required this.onClose});
  final VoidCallback onSeeAll;
  final VoidCallback onClose;

  static const _maxPreview = 5;

  Future<void> _open(BuildContext context, WidgetRef ref, NotificationModel n) async {
    if (!n.isRead) {
      await markNotifRead(ref, n.id);
    }
    final route = n.data?['route'] as String?;
    if (!context.mounted) return;
    // Toujours fermer le dropdown au clic ; naviguer si la notif est ouvrable.
    onClose();
    if (route != null && route.isNotEmpty) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final data = async.valueOrNull;
    final unread = data?.unread ?? 0;
    final items = (data?.notifications ?? const <NotificationModel>[])
        .take(_maxPreview)
        .toList();

    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            decoration: BoxDecoration(
              color: kCommCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: kCommBorder)),
            ),
            child: Row(children: [
              Icon(Icons.notifications_rounded, color: kCommNavy, size: 18),
              const SizedBox(width: 8),
              Text('Notifications',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: kCommNavy)),
              const SizedBox(width: 6),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              if (unread > 0)
                TextButton(
                  onPressed: () => markAllNotifRead(ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Tout lire',
                      style: TextStyle(fontSize: 11, color: kCommNavy)),
                ),
            ]),
          ),
          // ── Aperçu ─────────────────────────────────────────────────────
          if (async.isLoading && data == null)
            const Padding(
              padding: EdgeInsets.all(28),
              child: SizedBox(
                  height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(children: [
                Icon(Icons.notifications_off_outlined, size: 40, color: kCommBorder),
                const SizedBox(height: 10),
                Text('Aucune notification',
                    style: TextStyle(fontSize: 13, color: kCommSub)),
              ]),
            )
          else
            ...items.map((n) => _PreviewTile(
                  notif: n,
                  onTap: () => _open(context, ref, n),
                )),
          // ── Pied : tout afficher ───────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: kCommCard,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: kCommBorder)),
            ),
            child: TextButton.icon(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
              ),
              icon: Icon(Icons.open_in_full_rounded, size: 15, color: kCommNavy),
              label: Text('Tout afficher',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: kCommNavy)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.notif, required this.onTap});
  final NotificationModel notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = notifTypeInfo(notif.type);
    final dateStr = notif.createdAt.isNotEmpty
        ? fmtRelativeFr(DateTime.tryParse(notif.createdAt))
        : '';
    final hasRoute = (notif.data?['route'] as String?)?.isNotEmpty ?? false;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notif.isRead ? kCommCard : info.color.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(info.icon, size: 15, color: info.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: kCommText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: TextStyle(fontSize: 10, color: kCommSub)),
                  ]),
                  if (notif.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notif.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: kCommSub, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 6, top: 4),
                decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
              ),
            if (hasRoute)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 1),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: info.color),
              ),
          ],
        ),
      ),
    );
  }
}
