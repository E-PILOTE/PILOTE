import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/notifications_provider.dart';
import '../providers/school_groups_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBg     = Color(0xFFF0F4F8);

final _fmtFull  = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtDay   = DateFormat('EEEE d MMMM', 'fr_FR');

// ─── Type config ──────────────────────────────────────────────────────────────
const _typeConfig = {
  'payment':      (icon: Icons.payment_rounded,             color: Color(0xFF009A44), label: 'Paiement'),
  'invoice':      (icon: Icons.description_rounded,          color: Color(0xFF0EA5E9), label: 'Facture'),
  'subscription': (icon: Icons.card_membership_rounded,     color: Color(0xFF7C3AED), label: 'Abonnement'),
  'alert':        (icon: Icons.warning_amber_rounded,        color: Color(0xFFF59E0B), label: 'Alerte'),
  'system':       (icon: Icons.settings_rounded,            color: Color(0xFF64748B), label: 'Système'),
  'group':        (icon: Icons.school_rounded,              color: Color(0xFF1E3A5F), label: 'Groupe'),
  'security':     (icon: Icons.security_rounded,            color: Color(0xFFEF4444), label: 'Sécurité'),
};

({IconData icon, Color color, String label}) _typeInfo(String type) =>
    _typeConfig[type] ??
    (icon: Icons.notifications_rounded, color: _kSub, label: type);

// ─── Screen ───────────────────────────────────────────────────────────────────

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
              loading: () => const _Skeleton(),
              error:   (e, _) => _ErrView(
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

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => ref.read(notifSearchProvider.notifier).state = v,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les notifications…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kSub),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true, fillColor: _kBg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Mark all read
          _OutlineBtn(
            icon: Icons.done_all_rounded,
            label: 'Tout marquer lu',
            onTap: () async {
              final client = ref.read(supabaseClientProvider);
              await markAllNotificationsRead(client);
              ref.invalidate(notificationsProvider);
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showSendNotifDialog(context, ref),
            icon: const Icon(Icons.notifications_active_rounded, size: 15),
            label: const Text('Envoyer'),
            style: FilledButton.styleFrom(
              backgroundColor: _kNavy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            color: _kNavy,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

void _showSendNotifDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => _SendNotifDialog(onSent: () => ref.invalidate(notificationsProvider)),
  );
}

class _SendNotifDialog extends ConsumerStatefulWidget {
  const _SendNotifDialog({required this.onSent});
  final VoidCallback onSent;
  @override
  ConsumerState<_SendNotifDialog> createState() => _SendNotifDialogState();
}

class _SendNotifDialogState extends ConsumerState<_SendNotifDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _type     = 'system';
  String _target   = 'all';
  bool   _sending  = false;

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.notifications_active_rounded, color: _kNavy, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Envoyer une notification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                    Text('Diffusion ciblée : plateforme entière ou groupe', style: TextStyle(fontSize: 11, color: _kSub)),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: _kSub),
              ]),
              const SizedBox(height: 20),
              const Text('Destinataire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final groups = ref.watch(schoolGroupsProvider).valueOrNull?.groups ?? [];
                return DropdownButtonFormField<String>(
                  value: _target,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _target = v ?? _target),
                  items: [
                    const DropdownMenuItem(value: 'all',
                        child: Text('Toute la plateforme', style: TextStyle(fontSize: 12))),
                    ...groups.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  ],
                  decoration: InputDecoration(
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    filled: true, fillColor: const Color(0xFFF8FAFC),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _type,
                onChanged: (v) => setState(() => _type = v ?? _type),
                items: const [
                  DropdownMenuItem(value: 'system',       child: Text('Système',      style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'alert',        child: Text('Alerte',       style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'subscription', child: Text('Abonnement',   style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'invoice',      child: Text('Facture',      style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'group',        child: Text('Groupe',       style: TextStyle(fontSize: 12))),
                ],
                decoration: InputDecoration(
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Titre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Titre de la notification…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Corps de la notification…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub, side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le titre est requis')));
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(supabaseClientProvider);

      // Résout les destinataires : profils actifs rattachés à un groupe
      final base = client
          .from('profiles')
          .select('id, group_id')
          .eq('is_active', true)
          .not('group_id', 'is', null);
      final profiles = _target == 'all'
          ? await base
          : await base.eq('group_id', _target);
      final recipients = (profiles as List).cast<Map>();

      if (recipients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucun destinataire actif pour cette cible')));
          setState(() => _sending = false);
        }
        return;
      }

      final now = DateTime.now().toIso8601String();
      final payload = recipients.map((p) => {
        'group_id':     p['group_id'],
        'recipient_id': p['id'],
        'type':         _type,
        'title':        _titleCtrl.text.trim(),
        'body':         _bodyCtrl.text.trim(),
        'is_read':      false,
        'created_at':   now,
        'updated_at':   now,
      }).toList();
      await client.from('notifications').insert(payload);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification envoyée à ${recipients.length} destinataire(s) !'),
                backgroundColor: _kGreen));
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: _kNavy,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─── Body ─────────────────────────────────────────────────────────────────────

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panneau gauche filtres + stats ────────────────────────────
        SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: Column(children: [
              _KpiPanel(data: data),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _FilterPanel(data: data),
            ]),
          ),
        ),
        const VerticalDivider(width: 1),
        // ── Timeline principale ────────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? _EmptyState(hasFilter: typeFilter != 'all' || readFilter != 'all' || search.isNotEmpty)
              : _Timeline(items: items),
        ),
      ],
    );
  }
}

// ─── KPI Panel ────────────────────────────────────────────────────────────────

class _KpiPanel extends StatelessWidget {
  const _KpiPanel({required this.data});
  final NotificationsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vue d\'ensemble', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 12),
          _StatRow(label: 'Total',       value: '${data.total}',      color: _kNavy),
          const SizedBox(height: 8),
          _StatRow(label: 'Non lues',    value: '${data.unread}',     color: const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          _StatRow(label: "Aujourd'hui", value: '${data.todayCount}', color: _kGreen),
          const SizedBox(height: 8),
          _StatRow(label: '7 derniers jours', value: '${data.weekCount}', color: const Color(0xFF7C3AED)),
          const SizedBox(height: 16),

          // Taux de lecture
          const Text('Taux de lecture', style: TextStyle(fontSize: 11, color: _kSub)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: data.total > 0 ? (data.total - data.unread) / data.total : 0,
              minHeight: 8,
              backgroundColor: _kBg,
              valueColor: const AlwaysStoppedAnimation(_kGreen),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.total > 0
                ? '${(((data.total - data.unread) / data.total) * 100).toStringAsFixed(0)}% lues'
                : '—',
            style: const TextStyle(fontSize: 11, color: _kSub),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(value, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ],
  );
}

// ─── Filter Panel ─────────────────────────────────────────────────────────────

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({required this.data});
  final NotificationsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(notifTypeFilterProvider);
    final readFilter = ref.watch(notifReadFilterProvider);

    return Container(
      color: _kCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statut', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 8),
          _FilterItem(
            label: 'Toutes',
            count: data.total,
            selected: readFilter == 'all',
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'all',
            color: _kNavy,
          ),
          _FilterItem(
            label: 'Non lues',
            count: data.unread,
            selected: readFilter == 'unread',
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'unread',
            color: const Color(0xFFEF4444),
          ),
          _FilterItem(
            label: 'Lues',
            count: data.total - data.unread,
            selected: readFilter == 'read',
            onTap: () => ref.read(notifReadFilterProvider.notifier).state = 'read',
            color: _kGreen,
          ),

          const SizedBox(height: 16),
          const Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText)),
          const SizedBox(height: 8),
          _FilterItem(
            label: 'Tous les types',
            count: data.total,
            selected: typeFilter == 'all',
            onTap: () => ref.read(notifTypeFilterProvider.notifier).state = 'all',
            color: _kNavy,
          ),
          ...(() {
            final sorted = data.byType.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return sorted.take(8).map((e) {
              final info = _typeInfo(e.key);
              return _FilterItem(
                label: info.label,
                count: e.value,
                selected: typeFilter == e.key,
                onTap: () => ref.read(notifTypeFilterProvider.notifier).state = e.key,
                color: info.color,
                icon: info.icon,
              );
            });
          })(),
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
  final String label; final int count; final bool selected;
  final VoidCallback onTap; final Color color; final IconData? icon;

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
          Icon(icon, size: 13, color: selected ? color : _kSub),
          const SizedBox(width: 7),
        ],
        Expanded(child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? color : _kSub,
            ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : _kBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: selected ? color : _kSub,
          )),
        ),
      ]),
    ),
  );
}

// ─── Timeline ─────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});
  final List<NotificationModel> items;

  @override
  Widget build(BuildContext context) {
    // Group by date
    final Map<String, List<NotificationModel>> grouped = {};
    for (final n in items) {
      final dt  = DateTime.tryParse(n.createdAt) ?? DateTime.now();
      final key = _dayKey(dt);
      grouped.putIfAbsent(key, () => []).add(n);
    }
    final days = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final dt  = DateTime.tryParse(day.value.first.createdAt) ?? DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(date: dt),
            ...day.value.map((n) => _NotifCard(notif: n)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
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
    } else if (d == today.subtract(const Duration(days: 1))) label = 'Hier';
    else                                          label = _fmtDay.format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ]),
    );
  }
}

// ─── Notification card ────────────────────────────────────────────────────────

class _NotifCard extends ConsumerWidget {
  const _NotifCard({required this.notif});
  final NotificationModel notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info    = _typeInfo(notif.type);
    final dateStr = notif.createdAt.isNotEmpty
        ? _fmtFull.format(DateTime.tryParse(notif.createdAt)?.toLocal() ?? DateTime.now())
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead
              ? const Color(0xFFE2E8F0)
              : info.color.withValues(alpha: 0.25),
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
        onTap: () async {
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
              // Icon badge
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, size: 18, color: info.color),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Type chip
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
                        const Icon(Icons.school_outlined, size: 10, color: _kSub),
                        const SizedBox(width: 3),
                        Text(notif.groupName!, style: const TextStyle(fontSize: 10, color: _kSub)),
                      ],
                      const Spacer(),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: _kSub)),
                    ]),
                    const SizedBox(height: 5),
                    Text(notif.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: _kText,
                        )),
                    if (notif.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(notif.body,
                          style: const TextStyle(fontSize: 12, color: _kSub, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              // Unread dot
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        hasFilter ? Icons.filter_list_off_rounded : Icons.notifications_off_outlined,
        size: 56, color: Colors.grey.shade300,
      ),
      const SizedBox(height: 12),
      Text(
        hasFilter ? 'Aucun résultat pour ce filtre' : 'Aucune notification',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kSub),
      ),
      const SizedBox(height: 4),
      const Text('Les notifications système apparaîtront ici',
          style: TextStyle(fontSize: 12, color: _kSub)),
    ]),
  );
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 240,
      child: Container(color: _kCard),
    ),
    const VerticalDivider(width: 1),
    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 8,
        itemBuilder: (_, _) => Container(
          height: 80, margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  ]);
}

class _ErrView extends StatelessWidget {
  const _ErrView({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
    const SizedBox(height: 12),
    Text(error, style: const TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Réessayer'),
      style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white),
    ),
  ]));
}
