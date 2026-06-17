import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communication/widgets/staff_feed_ui.dart';
import '../../communication/widgets/ticket_thread_view.dart';
import '../providers/staff_support_provider.dart';
import '../widgets/staff_support_widgets.dart';

/// Espace Support du personnel scolaire — OFFLINE-FIRST.
/// La demande est enregistrée en local (PowerSync) et transmise au support
/// E-PILOTE à la prochaine synchronisation ; la réponse redescend de même.
/// Symétrique de l'espace Support admin_groupe.
class StaffSupportScreen extends ConsumerWidget {
  const StaffSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(title: 'Support', child: _Body());
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.id;
    if (uid == null) return const FeedSkeleton(cards: 3);

    final async = ref.watch(staffTicketsProvider(uid));
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const FeedSkeleton(cards: 3, maxWidth: double.infinity),
      error: (e, _) => Center(
        child: Text('Erreur : $e', style: const TextStyle(color: kTextMuted)),
      ),
      data: (data) => _List(data: data),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.data});
  final StaffTicketsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(staffTicketStatusFilter);
    final sort   = ref.watch(staffTicketSortProvider);
    final query  = ref.watch(staffTicketSearchProvider).trim().toLowerCase();

    var tickets = data.tickets;
    if (filter != 'all') {
      tickets = filter == 'resolved'
          ? tickets.where((t) => t.isClosed).toList()
          : tickets.where((t) => t.status == filter).toList();
    }
    if (query.isNotEmpty) {
      tickets = tickets
          .where((t) =>
              t.subject.toLowerCase().contains(query) ||
              t.body.toLowerCase().contains(query))
          .toList();
    }
    tickets = sortStaffTickets(tickets, sort);

    final hasFilters = filter != 'all' || query.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
      children: [
        StaffPageHeader(
          icon: Icons.support_agent_rounded,
          title: 'Support',
          subtitle:
              'Posez vos questions et signalez vos problèmes — même hors ligne, '
              'votre demande sera transmise à la prochaine synchronisation',
          badges: [
            HeaderChip(
                icon: Icons.confirmation_num_outlined,
                label: '${data.total} demande${data.total > 1 ? 's' : ''}'),
            if (data.open + data.inProgress > 0)
              HeaderChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '${data.open + data.inProgress} en attente'),
          ],
          trailing: FilledButton.icon(
            onPressed: () => showDialog<void>(
                context: context, builder: (_) => const CreateTicketDialog()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle demande'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kNavy,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: AdminStatCard(
                  label: 'Total', value: '${data.total}',
                  icon: Icons.confirmation_num_rounded, color: kNavy)),
          const SizedBox(width: 12),
          Expanded(
              child: AdminStatCard(
                  label: 'Ouverts', value: '${data.open}',
                  icon: Icons.markunread_mailbox_rounded, color: kAccent)),
          const SizedBox(width: 12),
          Expanded(
              child: AdminStatCard(
                  label: 'En cours', value: '${data.inProgress}',
                  icon: Icons.autorenew_rounded, color: kNavy)),
          const SizedBox(width: 12),
          Expanded(
              child: AdminStatCard(
                  label: 'Traités', value: '${data.resolved}',
                  icon: Icons.check_circle_rounded, color: kGreen)),
        ]),
        const SizedBox(height: 16),
        if (data.total == 0)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: AdminEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'Aucune demande',
              message:
                  'Vous n\'avez encore envoyé aucune demande au support. '
                  'Utilisez « Nouvelle demande » pour nous écrire — '
                  'cela fonctionne aussi hors ligne.',
            ),
          )
        else ...[
          // Donut statuts + filtres côte à côte sur grand écran.
          if (MediaQuery.sizeOf(context).width >= 1100)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _FilterBar(filter: filter, sort: sort)),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: TicketStatusChart(data: data)),
            ])
          else ...[
            TicketStatusChart(data: data),
            const SizedBox(height: 14),
            _FilterBar(filter: filter, sort: sort),
          ],
          const SizedBox(height: 14),
          StaffResultCount(
              filtered: tickets.length,
              total: data.total,
              singular: 'demande'),
          const SizedBox(height: 12),
          if (tickets.isEmpty && hasFilters)
            StaffNoResults(onReset: () {
              ref.read(staffTicketStatusFilter.notifier).state = 'all';
              ref.read(staffTicketSearchProvider.notifier).state = '';
            })
          else
            ...tickets.map((t) => _TicketCard(
                ticket: t, onTap: () => _openDetail(context, ref, t))),
        ],
      ],
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, StaffTicket t) {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final uid     = ref.read(currentUserProvider)?.id ?? '';
    final st = ticketStatusInfo(t.status);
    final pr = ticketPriorityInfo(t.priority);
    showDialog<void>(
      context: context,
      builder: (_) => TicketThreadDialog(
        ticketId: t.id,
        subject: t.subject,
        statusLabel: st.label,
        statusColor: st.color,
        // Hors-ligne : le demandeur est toujours soi-même.
        ticketOwnerId: uid,
        groupId: profile?.groupId,
        originalBody: t.body,
        createdAt: t.createdAt,
        originalAttachments: t.attachments,
        closed: t.isClosed,
        metaBadges: [
          AdminBadge(staffTicketCategories[t.category] ?? t.category,
              color: kNavy, icon: Icons.category_rounded),
          AdminBadge(pr.label, color: pr.color, icon: Icons.flag_rounded),
          AdminBadge(
              'Envoyée le ${fmtDateFr(DateTime.tryParse(t.createdAt))}',
              color: kTextMuted,
              icon: Icons.schedule_rounded),
        ],
      ),
    );
  }
}

// ─── Barre recherche · statut · tri ──────────────────────────────────────────
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({required this.filter, required this.sort});
  final String filter, sort;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(staffTicketSearchProvider);
    return StaffFilterCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StaffSearchField(
          controller: _ctrl,
          hint: 'Rechercher une demande (objet, description)…',
          onChanged: (v) =>
              ref.read(staffTicketSearchProvider.notifier).state = v,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final e in const {
              'all': 'Tous',
              'open': 'Ouverts',
              'in_progress': 'En cours',
              'resolved': 'Traités',
            }.entries)
              StaffToggleChip(
                icon: switch (e.key) {
                  'open'        => Icons.markunread_mailbox_rounded,
                  'in_progress' => Icons.autorenew_rounded,
                  'resolved'    => Icons.check_circle_rounded,
                  _             => Icons.all_inbox_rounded,
                },
                label: e.value,
                active: widget.filter == e.key,
                onTap: () => ref
                    .read(staffTicketStatusFilter.notifier)
                    .state = e.key,
              ),
            StaffFilterDropdown(
              icon: Icons.sort_rounded,
              items: staffTicketSortLabels,
              value: widget.sort,
              active: widget.sort != 'recent',
              onChanged: (v) =>
                  ref.read(staffTicketSortProvider.notifier).state = v,
            ),
            if (widget.filter != 'all' || query.isNotEmpty)
              StaffResetChip(onTap: () {
                _ctrl.clear();
                ref.read(staffTicketStatusFilter.notifier).state = 'all';
                ref.read(staffTicketSearchProvider.notifier).state = '';
              }),
          ],
        ),
      ]),
    );
  }
}

// ─── Carte demande ────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});
  final StaffTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st  = ticketStatusInfo(ticket.status);
    final pr  = ticketPriorityInfo(ticket.priority);
    final cat = staffTicketCategories[ticket.category] ?? ticket.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        accent: st.color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              const SizedBox(width: 10),
              AdminBadge(st.label, color: st.color),
              const SizedBox(width: 6),
              AdminBadge(pr.label, color: pr.color),
            ]),
            const SizedBox(height: 8),
            Text(ticket.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: kTextMuted, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.category_rounded, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text(cat,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
              const SizedBox(width: 14),
              const Icon(Icons.schedule_rounded, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text(fmtDateFr(DateTime.tryParse(ticket.createdAt)),
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
              const Spacer(),
              if (ticket.hasResponse) ...[
                const Icon(Icons.mark_chat_read_rounded,
                    size: 14, color: kGreen),
                const SizedBox(width: 4),
                const Text('Réponse reçue',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kGreen)),
              ] else
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: kTextMuted),
            ]),
          ],
        ),
      ),
    );
  }
}
