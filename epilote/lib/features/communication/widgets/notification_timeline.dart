import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'notification_types.dart';

final _fmtFull = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtDay  = DateFormat('EEEE d MMMM', 'fr_FR');

// ─── Timeline groupée par jour ───────────────────────────────────────────────────
class NotifTimeline extends StatelessWidget {
  const NotifTimeline({
    super.key,
    required this.items,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });
  final List<NotificationModel> items;
  /// Optionnel : action au clic (ex. deep-link). Si null, marque seulement lu.
  final void Function(NotificationModel)? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<NotificationModel>> grouped = {};
    for (final n in items) {
      final dt = DateTime.tryParse(n.createdAt) ?? DateTime.now();
      grouped.putIfAbsent('${dt.year}-${dt.month}-${dt.day}', () => []).add(n);
    }
    final days = grouped.entries.toList();

    return ListView.builder(
      padding: padding,
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final dt  = DateTime.tryParse(day.value.first.createdAt) ?? DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(date: dt),
            ...day.value.map((n) => NotifCard(
                  notif: n,
                  onTap: onTap == null ? null : () => onTap!(n),
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);

    String label;
    if (d == today) {
      label = "Aujourd'hui";
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Hier';
    } else {
      label = _fmtDay.format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kCommNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCommNavy)),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: kCommBorder)),
      ]),
    );
  }
}

// ─── Carte notification ──────────────────────────────────────────────────────────
class NotifCard extends ConsumerWidget {
  const NotifCard({super.key, required this.notif, this.onTap});
  final NotificationModel notif;
  /// Si fourni, remplace le comportement par défaut (qui marque seulement lu).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = notifTypeInfo(notif.type);
    final dateStr = notif.createdAt.isNotEmpty
        ? _fmtFull.format(DateTime.tryParse(notif.createdAt)?.toLocal() ?? DateTime.now())
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCommCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead ? kCommBorder : info.color.withValues(alpha: 0.25),
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: notif.isRead ? 0.03 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () async {
          if (!notif.isRead) {
            final client = ref.read(supabaseClientProvider);
            await markNotificationRead(client, notif.id);
            ref.invalidate(notificationsProvider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, size: 18, color: info.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(info.label,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: info.color)),
                      ),
                      if (notif.groupName != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.school_outlined, size: 10, color: kCommSub),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(notif.groupName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: kCommSub)),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: kCommSub)),
                    ]),
                    const SizedBox(height: 5),
                    Text(notif.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: kCommText,
                        )),
                    if (notif.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(notif.body,
                          style: const TextStyle(fontSize: 12, color: kCommSub, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!notif.isRead)
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── États ───────────────────────────────────────────────────────────────────────
class NotifEmptyState extends StatelessWidget {
  const NotifEmptyState({super.key, required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(hasFilter ? Icons.filter_list_off_rounded : Icons.notifications_off_outlined,
          size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(hasFilter ? 'Aucun résultat pour ce filtre' : 'Aucune notification',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kCommSub)),
      const SizedBox(height: 4),
      const Text('Les notifications apparaîtront ici',
          style: TextStyle(fontSize: 12, color: kCommSub)),
    ]),
  );
}

