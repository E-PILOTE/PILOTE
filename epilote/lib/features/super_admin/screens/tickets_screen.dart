import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../communication/providers/ticket_thread_provider.dart';
import '../../communication/widgets/ticket_thread_view.dart';
import '../providers/tickets_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBg     = Color(0xFFF0F4F8);

final _fmtDate  = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtShort = DateFormat('dd MMM', 'fr_FR');

// ─── Local state ──────────────────────────────────────────────────────────────
final _ticketSearchProv   = StateProvider.autoDispose<String>((ref) => '');
// Id du ticket sélectionné (pas le modèle → jamais périmé après realtime).
final _selectedTicketProv = StateProvider.autoDispose<String?>((ref) => null);
// 'recent' | 'old' | 'priority'
final _ticketSortProv     = StateProvider.autoDispose<String>((ref) => 'recent');

int _priorityRank(String p) {
  switch (p) {
    case 'urgent': return 0;
    case 'high':   return 1;
    case 'medium': return 2;
    default:       return 3;
  }
}

DateTime _ticketDate(TicketModel t) =>
    DateTime.tryParse(t.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ticketsProvider);

    return AppShell(
      title: 'Tickets Support',
      child: Column(
        children: [
          _TopBar(onRefresh: () => ref.invalidate(ticketsProvider)),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true, skipLoadingOnRefresh: true,
              loading: () => const _Skeleton(),
              error:   (e, _) => _Err(error: e.toString(), onRetry: () => ref.invalidate(ticketsProvider)),
              data:    (data) => _Body(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => ref.read(_ticketSearchProv.notifier).state = v,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher un ticket…',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kSub),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true, fillColor: _kBg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SortMenu(),
          const SizedBox(width: 4),
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

class _SortMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(_ticketSortProv);
    const items = {
      'recent':   ('Plus récents',  Icons.arrow_downward_rounded),
      'old':      ('Plus anciens',  Icons.arrow_upward_rounded),
      'priority': ('Priorité',      Icons.flag_rounded),
    };
    return PopupMenuButton<String>(
      tooltip: 'Trier',
      initialValue: sort,
      onSelected: (v) => ref.read(_ticketSortProv.notifier).state = v,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(children: [
              Icon(e.value.$2, size: 16, color: _kNavy),
              const SizedBox(width: 8),
              Text(e.value.$1, style: const TextStyle(fontSize: 13)),
            ]),
          ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          const Icon(Icons.swap_vert_rounded, size: 16, color: _kSub),
          const SizedBox(width: 6),
          Text(items[sort]!.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy)),
        ]),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final TicketsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search     = ref.watch(_ticketSearchProv);
    final selectedId = ref.watch(_selectedTicketProv);
    final status     = ref.watch(ticketsStatusFilter);
    final priority   = ref.watch(ticketsPriorityFilter);
    final sort       = ref.watch(_ticketSortProv);
    final selected   =
        data.tickets.where((t) => t.id == selectedId).firstOrNull;

    var tickets = data.tickets;
    if (status   != 'all') tickets = tickets.where((t) => t.status == status).toList();
    if (priority != 'all') tickets = tickets.where((t) => t.priority == priority).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      tickets = tickets.where((t) =>
          t.subject.toLowerCase().contains(q) ||
          t.groupName.toLowerCase().contains(q) ||
          t.body.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q)).toList();
    }
    tickets = [...tickets];
    switch (sort) {
      case 'old':      tickets.sort((a, b) => _ticketDate(a).compareTo(_ticketDate(b))); break;
      case 'priority': tickets.sort((a, b) {
          final r = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
          return r != 0 ? r : _ticketDate(b).compareTo(_ticketDate(a));
        }); break;
      default:         tickets.sort((a, b) => _ticketDate(b).compareTo(_ticketDate(a)));
    }

    return Row(
      children: [
        // ── Liste gauche ──────────────────────────────────────────────────
        SizedBox(
          width: 340,
          child: Container(
            color: _kCard,
            child: Column(
              children: [
                _KpiBar(data: data),
                _FilterBar(),
                Expanded(
                  child: tickets.isEmpty
                      ? _EmptyList()
                      : ListView.builder(
                          itemCount: tickets.length,
                          itemBuilder: (_, i) => _TicketTile(
                            ticket: tickets[i],
                            isSelected: selectedId == tickets[i].id,
                            onTap: () => ref.read(_selectedTicketProv.notifier).state = tickets[i].id,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // ── Détail droite ─────────────────────────────────────────────────
        Expanded(
          child: selected == null
              ? _NoSelection()
              : _TicketDetail(ticket: selected),
        ),
      ],
    );
  }
}

// ─── KPI bar ──────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.data});
  final TicketsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          _KpiChip(label: 'Total',       value: '${data.total}',      color: _kNavy),
          const SizedBox(width: 6),
          _KpiChip(label: 'Ouverts',     value: '${data.open}',       color: const Color(0xFFEF4444)),
          const SizedBox(width: 6),
          _KpiChip(label: 'En cours',    value: '${data.inProgress}', color: const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _KpiChip(label: 'Résolus',     value: '${data.resolved}',   color: _kGreen),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value, required this.color});
  final String label; final String value; final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: _kSub, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status   = ref.watch(ticketsStatusFilter);
    final priority = ref.watch(ticketsPriorityFilter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        children: [
          Row(children: [
            const Text('Statut :', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
            const SizedBox(width: 6),
            _FilterChip(label: 'Tous',      value: 'all',         current: status,   onTap: () => ref.read(ticketsStatusFilter.notifier).state = 'all'),
            const SizedBox(width: 4),
            _FilterChip(label: 'Ouverts',   value: 'open',        current: status,   onTap: () => ref.read(ticketsStatusFilter.notifier).state = 'open'),
            const SizedBox(width: 4),
            _FilterChip(label: 'En cours',  value: 'in_progress', current: status,   onTap: () => ref.read(ticketsStatusFilter.notifier).state = 'in_progress'),
            const SizedBox(width: 4),
            _FilterChip(label: 'Résolus',   value: 'resolved',    current: status,   onTap: () => ref.read(ticketsStatusFilter.notifier).state = 'resolved'),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Text('Priorité :', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
            const SizedBox(width: 6),
            _FilterChip(label: 'Toutes',  value: 'all',    current: priority, onTap: () => ref.read(ticketsPriorityFilter.notifier).state = 'all'),
            const SizedBox(width: 4),
            _FilterChip(label: 'Urgente', value: 'urgent', current: priority, onTap: () => ref.read(ticketsPriorityFilter.notifier).state = 'urgent', color: const Color(0xFFEF4444)),
            const SizedBox(width: 4),
            _FilterChip(label: 'Haute',   value: 'high',   current: priority, onTap: () => ref.read(ticketsPriorityFilter.notifier).state = 'high',   color: const Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            _FilterChip(label: 'Moyenne', value: 'medium', current: priority, onTap: () => ref.read(ticketsPriorityFilter.notifier).state = 'medium'),
          ]),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.current, required this.onTap, this.color});
  final String label; final String value; final String current; final VoidCallback onTap; final Color? color;

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    final c   = color ?? _kNavy;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: sel ? c : _kBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : _kSub)),
      ),
    );
  }
}

// ─── Ticket tile ──────────────────────────────────────────────────────────────

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.isSelected, required this.onTap});
  final TicketModel ticket; final bool isSelected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = ticket.createdAt.isNotEmpty
        ? _fmtShort.format(DateTime.tryParse(ticket.createdAt) ?? DateTime.now()) : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isSelected ? _kNavy.withValues(alpha: 0.06) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(children: [
                    _PriorityDot(priority: ticket.priority),
                    const SizedBox(width: 6),
                    Expanded(child: Text(ticket.groupName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                _StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(ticket.subject,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(ticket.category,
                    style: const TextStyle(fontSize: 10, color: _kSub),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(date, style: const TextStyle(fontSize: 10, color: _kSub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final String priority;

  Color get _color {
    switch (priority) {
      case 'urgent': return const Color(0xFFEF4444);
      case 'high':   return const Color(0xFFF59E0B);
      case 'low':    return _kGreen;
      default:       return _kNavy;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open'        => ('Ouvert',   const Color(0xFFEF4444)),
      'in_progress' => ('En cours', const Color(0xFFF59E0B)),
      'resolved'    => ('Résolu',   _kGreen),
      'closed'      => ('Fermé',    _kSub),
      _             => ('Inconnu',  _kSub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Ticket detail ────────────────────────────────────────────────────────────

class _TicketDetail extends ConsumerStatefulWidget {
  const _TicketDetail({required this.ticket});
  final TicketModel ticket;

  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  @override
  Widget build(BuildContext context) {
    final t    = widget.ticket;
    final date = t.createdAt.isNotEmpty
        ? _fmtDate.format(DateTime.tryParse(t.createdAt) ?? DateTime.now()) : '—';

    return Container(
      color: _kBg,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: _kCard,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(t.subject,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kText))),
                  _StatusBadge(status: t.status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: _kSub,
                    onPressed: () => ref.read(_selectedTicketProv.notifier).state = null,
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _MetaBadge(icon: Icons.corporate_fare_rounded, label: t.groupName),
                  _MetaBadge(icon: Icons.label_rounded,          label: t.category),
                  _MetaBadge(icon: Icons.flag_rounded,           label: _priorityLabel(t.priority)),
                  _MetaBadge(icon: Icons.schedule_rounded,       label: date),
                ]),
                const SizedBox(height: 10),
                // Statut modifiable en un clic — répercuté en temps réel.
                _StatusChips(ticket: t),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Conversation temps réel ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: TicketThreadView(
                key: ValueKey(t.id),
                ticketId: t.id,
                ticketOwnerId: t.submittedBy ?? '',
                groupId: t.groupId,
                originalBody: t.body,
                createdAt: t.createdAt,
                originalAttachments: t.attachments,
                viewerIsSupport: true,
                closed: t.isClosed,
                onSend: (body, attachments) async {
                  // Première réponse sur un ticket ouvert → passe « En cours ».
                  final newStatus =
                      t.status == 'open' ? 'in_progress' : t.status;
                  await sendSupportReply(
                    ref,
                    ticketId: t.id,
                    ticketOwnerId: t.submittedBy ?? '',
                    groupId: t.groupId,
                    body: body,
                    status: newStatus,
                    attachments: attachments,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'urgent': return 'Urgente';
      case 'high':   return 'Haute';
      case 'low':    return 'Faible';
      default:       return 'Moyenne';
    }
  }
}

// ─── Chips de statut (mise à jour directe, realtime) ──────────────────────────

class _StatusChips extends ConsumerWidget {
  const _StatusChips({required this.ticket});
  final TicketModel ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(spacing: 8, children: [
      for (final (val, lbl, clr) in [
        ('open',        'Ouvert',   const Color(0xFFEF4444)),
        ('in_progress', 'En cours', const Color(0xFFF59E0B)),
        ('resolved',    'Résolu',   _kGreen),
        ('closed',      'Fermé',    _kSub),
      ])
        ChoiceChip(
          label: Text(lbl,
              style: TextStyle(
                  fontSize: 11,
                  color: ticket.status == val ? Colors.white : _kSub)),
          selected: ticket.status == val,
          selectedColor: clr,
          backgroundColor: _kBg,
          onSelected: (_) async {
            if (ticket.status == val) return;
            await updateTicketStatus(
                ref.read(supabaseClientProvider), ticket.id, val);
          },
          side: BorderSide(
              color: ticket.status == val ? clr : const Color(0xFFE2E8F0)),
          showCheckmark: false,
        ),
    ]);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: _kSub),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
    ],
  );
}

class _NoSelection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.confirmation_num_outlined, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Sélectionnez un ticket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kSub)),
      const SizedBox(height: 4),
      const Text('Cliquez sur un ticket dans la liste pour le traiter', style: TextStyle(fontSize: 12, color: _kSub)),
    ]),
  );
}

class _EmptyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 10),
      const Text('Aucun ticket', style: TextStyle(fontSize: 14, color: _kSub)),
    ]),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 340, child: ListView.builder(
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 76, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      ),
    )),
    const VerticalDivider(width: 1),
    const Expanded(child: SizedBox()),
  ]);
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
    const SizedBox(height: 12),
    Text(error, style: const TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
  ]));
}
