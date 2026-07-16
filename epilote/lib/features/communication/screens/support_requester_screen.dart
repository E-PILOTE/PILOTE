import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/support_requester_provider.dart';
import '../providers/ticket_thread_provider.dart';
import '../widgets/support_requester_widgets.dart';
import '../widgets/ticket_thread_view.dart';

/// Espace Tickets — côté DEMANDEUR, partagé admin_groupe + personnel école.
/// Mise en page maître-détail (liste à gauche, conversation inline à droite),
/// identique à l'espace Tickets du super_admin. Le périmètre (online groupe /
/// offline école) est déduit du rôle via `communicationContextProvider`.
class SupportRequesterScreen extends ConsumerWidget {
  const SupportRequesterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportRequesterProvider);
    return AppShell(
      title: 'Tickets',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erreur : $e', style: TextStyle(color: kTextMuted)),
        ),
        data: (data) => _MasterDetail(data: data),
      ),
    );
  }
}

final _fmtDate  = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
final _fmtShort = DateFormat('dd MMM', 'fr_FR');

// Id du ticket sélectionné (pas le modèle → jamais périmé après realtime).
final _selectedReqTicket = StateProvider.autoDispose<String?>((ref) => null);

class _MasterDetail extends ConsumerWidget {
  const _MasterDetail({required this.data});
  final RequesterTicketsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope      = ref.watch(communicationContextProvider).scope;
    final filter     = ref.watch(requesterStatusFilter);
    final sort       = ref.watch(requesterSortProvider);
    final query      = ref.watch(requesterSearchProvider).trim().toLowerCase();
    final selectedId = ref.watch(_selectedReqTicket);
    final categories = requesterCategories(scope);

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
    tickets = sortRequesterTickets(tickets, sort);

    final selected = data.tickets.where((t) => t.id == selectedId).firstOrNull;

    return Row(
      children: [
        // ── Liste gauche ──────────────────────────────────────────────────
        SizedBox(
          width: 360,
          child: Container(
            color: kCardBg,
            child: Column(
              children: [
                _LeftHeader(scope: scope),
                _KpiBar(data: data),
                _FilterBar(filter: filter, sort: sort),
                Expanded(
                  child: tickets.isEmpty
                      ? const _EmptyList()
                      : ListView.builder(
                          itemCount: tickets.length,
                          itemBuilder: (_, i) => _TicketTile(
                            ticket: tickets[i],
                            categories: categories,
                            selected: selectedId == tickets[i].id,
                            onTap: () => ref
                                .read(_selectedReqTicket.notifier)
                                .state = tickets[i].id,
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
              ? const _NoSelection()
              : _TicketDetail(ticket: selected, categories: categories),
        ),
      ],
    );
  }
}

// ─── En-tête liste (titre + Nouvelle demande) ────────────────────────────────
class _LeftHeader extends StatelessWidget {
  const _LeftHeader({required this.scope});
  final CommScope scope;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder))),
      child: Row(children: [
        Expanded(
          child: Text('Mes demandes',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RequesterCreateDialog(scope: scope)),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Nouvelle'),
          style: FilledButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}

// ─── KPI bar ──────────────────────────────────────────────────────────────────
class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.data});
  final RequesterTicketsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder))),
      child: Row(children: [
        _KpiChip(label: 'Total',    value: '${data.total}',      color: kNavy),
        const SizedBox(width: 6),
        _KpiChip(label: 'Ouverts',  value: '${data.open}',       color: kAccent),
        const SizedBox(width: 6),
        _KpiChip(label: 'En cours', value: '${data.inProgress}', color: kNavy),
        const SizedBox(width: 6),
        _KpiChip(label: 'Traités',  value: '${data.resolved}',   color: kGreen),
      ]),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

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
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9, color: kTextMuted, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

// ─── Barre de filtres (recherche + statut + tri) ─────────────────────────────
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(children: [
        SizedBox(
          height: 36,
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) =>
                ref.read(requesterSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: kTextMuted),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final e in const {
                'all': 'Tous',
                'open': 'Ouverts',
                'in_progress': 'En cours',
                'resolved': 'Traités',
              }.entries)
                _Chip(
                  label: e.value,
                  value: e.key,
                  current: widget.filter,
                  onTap: () => ref
                      .read(requesterStatusFilter.notifier)
                      .state = e.key,
                ),
            ]),
          ),
          _SortMenu(sort: widget.sort),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});
  final String label, value, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? kNavy : kSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kTextMuted)),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.sort});
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Trier',
      initialValue: sort,
      onSelected: (v) => ref.read(requesterSortProvider.notifier).state = v,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => [
        for (final e in requesterSortLabels.entries)
          PopupMenuItem(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 13))),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.swap_vert_rounded, size: 16, color: kTextMuted),
      ),
    );
  }
}

// ─── Tuile ticket ─────────────────────────────────────────────────────────────
class _TicketTile extends StatelessWidget {
  const _TicketTile(
      {required this.ticket,
      required this.categories,
      required this.selected,
      required this.onTap});
  final RequesterTicket ticket;
  final Map<String, String> categories;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st  = requesterStatusInfo(ticket.status);
    final cat = categories[ticket.category] ?? ticket.category;
    final date = ticket.createdAt.isNotEmpty
        ? _fmtShort.format(DateTime.tryParse(ticket.createdAt) ?? DateTime.now())
        : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: selected ? kNavy.withValues(alpha: 0.06) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
              const SizedBox(width: 6),
              AdminBadge(st.label, color: st.color),
            ]),
            const SizedBox(height: 4),
            Text(ticket.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: kTextMuted)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(cat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: kTextMuted)),
              ),
              if (ticket.hasResponse) ...[
                Icon(Icons.mark_chat_read_rounded,
                    size: 13, color: kGreen),
                const SizedBox(width: 4),
              ],
              Text(date, style: TextStyle(fontSize: 10, color: kTextMuted)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Détail (en-tête + conversation inline) ──────────────────────────────────
class _TicketDetail extends ConsumerWidget {
  const _TicketDetail({required this.ticket, required this.categories});
  final RequesterTicket ticket;
  final Map<String, String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st  = requesterStatusInfo(ticket.status);
    final pr  = requesterPriorityInfo(ticket.priority);
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final myUid   = ref.watch(currentUserProvider)?.id ?? '';
    final ownerId = ticket.submittedBy ?? myUid;
    final date = ticket.createdAt.isNotEmpty
        ? _fmtDate.format(DateTime.tryParse(ticket.createdAt) ?? DateTime.now())
        : '—';

    return Container(
      color: kSurface,
      child: Column(
        children: [
          // En-tête
          Container(
            color: kCardBg,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(ticket.subject,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                  ),
                  AdminBadge(st.label, color: st.color),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: kTextMuted,
                    onPressed: () =>
                        ref.read(_selectedReqTicket.notifier).state = null,
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  AdminBadge(categories[ticket.category] ?? ticket.category,
                      color: kNavy, icon: Icons.category_rounded),
                  AdminBadge(pr.label, color: pr.color, icon: Icons.flag_rounded),
                  AdminBadge(date, color: kTextMuted, icon: Icons.schedule_rounded),
                ]),
              ],
            ),
          ),
          Divider(height: 1, color: kBorder),
          // Conversation inline
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: TicketThreadView(
                key: ValueKey(ticket.id),
                ticketId: ticket.id,
                ticketOwnerId: ownerId,
                groupId: profile?.groupId,
                originalBody: ticket.body,
                createdAt: ticket.createdAt,
                originalAttachments: ticket.attachments,
                viewerIsSupport: false,
                closed: ticket.isClosed,
                onSend: (body, attachments) => sendRequesterFollowUp(
                  ref,
                  ticketId: ticket.id,
                  ticketOwnerId: ownerId,
                  groupId: profile?.groupId,
                  body: body,
                  currentStatus: ticket.status,
                  attachments: attachments,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── États vides ──────────────────────────────────────────────────────────────
class _NoSelection extends StatelessWidget {
  const _NoSelection();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.confirmation_num_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Sélectionnez une demande',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kTextMuted)),
          const SizedBox(height: 4),
          Text('Cliquez sur un ticket dans la liste pour le suivre',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.support_agent_rounded,
                size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Aucune demande',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextMuted)),
            const SizedBox(height: 4),
            Text('Utilisez « Nouvelle » pour écrire au support',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),
      );
}
