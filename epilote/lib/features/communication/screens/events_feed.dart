import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/staff_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/announcement_interactions_provider.dart';
import '../providers/announcements_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/events_provider.dart';
import '../widgets/feed_left_rail.dart';
import '../widgets/feed_right_rail.dart';
import '../widgets/feed_scaffold.dart';
import '../widgets/staff_event_calendar.dart';
import '../widgets/staff_feed_ui.dart';
import 'events_feed_cards.dart';
import 'events_feed_form.dart';

/// Agenda partagé scope-aware (onglet « Agenda » du module Annonces).
/// • École → offline-first (`schoolEventsProvider`, SQLite local).
/// • super_admin / admin_groupe → online Supabase (`eventsProvider`).
/// Liste + calendrier, filtrage 100 % en mémoire. Réutilisé partout (zéro
/// page Événements dupliquée). Voir [scopedEventsProvider].
class EventsAgendaBody extends ConsumerStatefulWidget {
  const EventsAgendaBody({super.key, this.onBackToFeed});

  /// Retour au fil d'actualité (raccourcis du rail gauche en mode Agenda).
  final VoidCallback? onBackToFeed;

  @override
  ConsumerState<EventsAgendaBody> createState() => _EventsAgendaBodyState();
}

class _EventsAgendaBodyState extends ConsumerState<EventsAgendaBody> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _period = 'upcoming'; // upcoming | past | all
  String _location = 'tous';
  bool _calendarView = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _search.isNotEmpty || _period != 'upcoming' || _location != 'tous';

  void _reset() => setState(() {
        _searchCtrl.clear();
        _search = '';
        _period = 'upcoming';
        _location = 'tous';
      });

  /// Recherche + lieu (partagés liste/calendrier). Le filtre de période ne
  /// s'applique qu'à la liste — le calendrier navigue librement dans le temps.
  List<EventModel> _searchAndLocation(List<EventModel> events) {
    final q = _search.trim().toLowerCase();
    return events.where((e) {
      if (_location != 'tous' && (e.location ?? '') != _location) return false;
      if (q.isNotEmpty &&
          !e.title.toLowerCase().contains(q) &&
          !e.description.toLowerCase().contains(q) &&
          !(e.location ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Liste finale : période appliquée, à-venir croissant puis passés décroissant.
  List<EventModel> _applyPeriod(List<EventModel> events) {
    final upcoming = events.where((e) => !e.isPast).toList();
    final past = events.where((e) => e.isPast).toList().reversed.toList();
    return switch (_period) {
      'upcoming' => upcoming,
      'past' => past,
      _ => [...upcoming, ...past],
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scopedEventsProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const FeedSkeleton(cards: 4, maxWidth: double.infinity),
      error: (e, _) => Center(
        child: Text('Erreur : $e', style: const TextStyle(color: kTextMuted)),
      ),
      data: (events) => _buildBody(context, events),
    );
  }

  Widget _buildBody(BuildContext context, List<EventModel> events) {
    final searched = _searchAndLocation(events);
    final filtered = _applyPeriod(searched);
    final width    = MediaQuery.sizeOf(context).width;
    final showRail = feedShowRail(width);
    // Centré (≤660) sur grand écran → 1 colonne, sinon 2 colonnes.
    final columns = showRail ? 1 : (width >= 980 ? 2 : 1);

    // Gestion : admin (super_admin/admin_groupe online, RLS = leur périmètre)
    // OU direction d'école (offline, uniquement SA propre école).
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final ctx = ref.watch(communicationContextProvider);
    final isAdmin = ctx.isPlatform || ctx.isGroup;
    final isDirection =
        !isAdmin && AppConstants.directionRoles.contains(profile?.role);
    final canManage = isAdmin || isDirection;
    final mySchoolId = profile?.schoolId;
    bool manageable(EventModel e) => isAdmin
        ? true
        : (isDirection && e.schoolId != null && e.schoolId == mySchoolId);

    final locations = {
      'tous': 'Tous les lieux',
      for (final e in events)
        if ((e.location ?? '').isNotEmpty) e.location!: e.location!,
    };

    final center = ListView(
      padding: EdgeInsets.symmetric(
          vertical: 22, horizontal: showRail ? 4 : 16),
      children: [
        if (canManage) ...[
          FeedComposer(
            hint: ctx.isSchool
                ? 'Planifiez un événement pour votre établissement…'
                : 'Planifiez un événement…',
            avatarColor: kGreen,
            avatarIcon: Icons.event_rounded,
            onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const StaffEventFormDialog()),
          ),
          const SizedBox(height: 14),
        ],
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 56),
            child: AdminEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Aucun événement',
              message: 'Le calendrier de votre communauté apparaîtra ici.',
            ),
          )
        else ...[
          _filterBar(locations),
          const SizedBox(height: 14),
          if (_calendarView)
            StaffEventCalendar(
              events: searched,
              onTapEvent: (e) => _openDetail(context, e),
            )
          else if (filtered.isEmpty)
            StaffNoResults(onReset: _reset)
          else
            StaffColumnGrid(
              columns: columns,
              children: [
                for (final e in filtered)
                  StaffEventCard(
                    event: e,
                    onTap: () => _openDetail(context, e),
                    manageable: manageable(e),
                    onEdit: () => showDialog<void>(
                        context: context,
                        builder: (_) => StaffEventFormDialog(existing: e)),
                    onDelete: () => confirmDeleteEvent(ref, context, e),
                  ),
              ],
            ),
        ],
      ],
    );

    // ── Coquille 3 colonnes (même structure que le fil d'actualité) ──────────
    final anns      = ref.watch(scopedAnnouncementsProvider).valueOrNull
        ?? const [];
    final savedIds  = ref.watch(savedAnnouncementIdsProvider).valueOrNull
        ?? const <String>{};
    final upcoming  = events.where((e) => !e.isPast).length;
    final pinned    = anns.where((a) => a.isPinned).length;

    return FeedScaffold(
      center: center,
      leftRail: FeedLeftRail(
        active: FeedShortcut.agenda,
        totalCount: anns.length,
        pinnedCount: pinned,
        savedCount: savedIds.length,
        upcomingCount: upcoming,
        onShortcut: (s) {
          if (s != FeedShortcut.agenda) widget.onBackToFeed?.call();
        },
      ),
      rightRail: FeedRightRail(
        announcements: anns,
      ),
    );
  }

  Widget _filterBar(Map<String, String> locations) => StaffFilterCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: StaffSearchField(
                controller: _searchCtrl,
                hint: 'Rechercher un événement (titre, description, lieu)…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 12),
            _ViewSegment(
              calendar: _calendarView,
              onChanged: (v) => setState(() => _calendarView = v),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!_calendarView)
                StaffFilterDropdown(
                  icon: Icons.calendar_month_rounded,
                  items: const {
                    'upcoming': 'À venir',
                    'past': 'Passés',
                    'all': 'Tous',
                  },
                  value: _period,
                  active: _period != 'upcoming',
                  onChanged: (v) => setState(() => _period = v),
                ),
              if (locations.length > 1)
                StaffFilterDropdown(
                  icon: Icons.place_rounded,
                  items: locations,
                  value: _location,
                  active: _location != 'tous',
                  onChanged: (v) => setState(() => _location = v),
                ),
              if (_hasFilters) StaffResetChip(onTap: _reset),
            ],
          ),
        ]),
      );

  void _openDetail(BuildContext context, EventModel event) {
    showDialog<void>(
      context: context,
      builder: (_) => StaffEventDetailDialog(event: event),
    );
  }
}

// ─── Segmented Liste | Calendrier ─────────────────────────────────────────────
class _ViewSegment extends StatelessWidget {
  const _ViewSegment({required this.calendar, required this.onChanged});
  final bool calendar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool isCalendar) {
      final active = calendar == isCalendar;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(isCalendar),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? kNavy : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: active ? Colors.white : kTextMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : kTextPrimary,
                  )),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Liste', Icons.view_agenda_rounded, false),
        seg('Calendrier', Icons.calendar_month_rounded, true),
      ]),
    );
  }
}
