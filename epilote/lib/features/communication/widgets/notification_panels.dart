import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notifications_provider.dart';
import 'notification_types.dart';

// ─── Panneau KPI ────────────────────────────────────────────────────────────────
class NotifKpiPanel extends StatelessWidget {
  const NotifKpiPanel({super.key, required this.data});
  final NotificationsData data;

  @override
  Widget build(BuildContext context) {
    final readRate = data.total > 0 ? (data.total - data.unread) / data.total : 0.0;
    return Container(
      color: kCommCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Vue d'ensemble",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCommText)),
          const SizedBox(height: 12),
          _StatRow(label: 'Total',            value: '${data.total}',      color: kCommNavy),
          const SizedBox(height: 8),
          _StatRow(label: 'Non lues',         value: '${data.unread}',     color: const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          _StatRow(label: "Aujourd'hui",      value: '${data.todayCount}', color: kCommGreen),
          const SizedBox(height: 8),
          _StatRow(label: '7 derniers jours', value: '${data.weekCount}',  color: const Color(0xFF7C3AED)),
          const SizedBox(height: 16),
          const Text('Taux de lecture', style: TextStyle(fontSize: 11, color: kCommSub)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: readRate,
              minHeight: 8,
              backgroundColor: kCommBg,
              valueColor: const AlwaysStoppedAnimation(kCommGreen),
            ),
          ),
          const SizedBox(height: 4),
          Text(data.total > 0 ? '${(readRate * 100).toStringAsFixed(0)}% lues' : '—',
              style: const TextStyle(fontSize: 11, color: kCommSub)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: kCommSub)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ],
  );
}

// ─── Panneau filtres ─────────────────────────────────────────────────────────────
class NotifFilterPanel extends ConsumerWidget {
  const NotifFilterPanel({super.key, required this.data});
  final NotificationsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(notifTypeFilterProvider);
    final readFilter = ref.watch(notifReadFilterProvider);

    return Container(
      color: kCommCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statut', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCommText)),
          const SizedBox(height: 8),
          _FilterItem(
            label: 'Toutes', count: data.total, selected: readFilter == 'all',
            color: kCommNavy,
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'all',
          ),
          _FilterItem(
            label: 'Non lues', count: data.unread, selected: readFilter == 'unread',
            color: const Color(0xFFEF4444),
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'unread',
          ),
          _FilterItem(
            label: 'Lues', count: data.total - data.unread, selected: readFilter == 'read',
            color: kCommGreen,
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'read',
          ),
          const SizedBox(height: 16),
          const Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCommText)),
          const SizedBox(height: 8),
          _FilterItem(
            label: 'Tous les types', count: data.total, selected: typeFilter == 'all',
            color: kCommNavy,
            onTap: () => ref.read(notifTypeFilterProvider.notifier).state = 'all',
          ),
          ...(data.byType.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(8)
              .map((e) {
            final info = notifTypeInfo(e.key);
            return _FilterItem(
              label: info.label, count: e.value, selected: typeFilter == e.key,
              color: info.color, icon: info.icon,
              onTap: () => ref.read(notifTypeFilterProvider.notifier).state = e.key,
            );
          }),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.color,
    this.icon,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? color.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: selected ? color : kCommSub),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? color : kCommSub,
              )),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : kCommBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: selected ? color : kCommSub,
              )),
        ),
      ]),
    ),
  );
}
