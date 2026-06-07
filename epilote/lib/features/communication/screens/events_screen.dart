import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/communication_scope.dart';
import '../providers/events_provider.dart';

part 'event_form.dart';
part 'event_calendar.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kAmber  = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBg     = Color(0xFFF0F4F8);
const _kBorder = Color(0xFFE2E8F0);

final _fmtDay   = DateFormat('d', 'fr_FR');
final _fmtMonth = DateFormat('MMM', 'fr_FR');
final _fmtFull  = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

const _audienceLabels = {
  'all':        'Tous',
  'parents':    'Parents',
  'enseignants':'Enseignants',
  'eleves':     'Élèves',
  'personnel':  'Personnel',
};

/// Événements scope-aware (super_admin = plateforme · admin_groupe = son groupe).
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventsProvider);

    return AppShell(
      title: 'Événements',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(error: e.toString(), onRetry: () => ref.invalidate(eventsProvider)),
        data: (data) => _Body(data: data),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final EventsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFilterProvider);
    final view   = ref.watch(eventViewProvider);
    final isPlatform = ref.watch(communicationContextProvider).isPlatform;

    var events = data.events;
    switch (filter) {
      case 'upcoming':
        events = events.where((e) => !e.isPast).toList()
          ..sort((a, b) => (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)));
      case 'past':
        events = events.where((e) => e.isPast).toList();
      case 'published':
        events = events.where((e) => e.isPublished).toList();
      case 'draft':
        events = events.where((e) => !e.isPublished).toList();
      default:
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(children: [
            _Kpi(label: 'Total', value: '${data.total}', color: _kNavy, icon: Icons.event_rounded),
            const SizedBox(width: 12),
            _Kpi(label: 'À venir', value: '${data.upcoming}', color: _kGreen, icon: Icons.upcoming_rounded),
            const SizedBox(width: 12),
            _Kpi(label: 'Publiés', value: '${data.published}', color: _kAmber, icon: Icons.public_rounded),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _showForm(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouvel événement'),
              style: FilledButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(children: [
            if (view == 'list')
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  _FilterChip(label: 'À venir', value: 'upcoming', current: filter),
                  _FilterChip(label: 'Tous', value: 'all', current: filter),
                  _FilterChip(label: 'Publiés', value: 'published', current: filter),
                  _FilterChip(label: 'Brouillons', value: 'draft', current: filter),
                  _FilterChip(label: 'Passés', value: 'past', current: filter),
                ]),
              )
            else
              const Spacer(),
            _ViewToggle(view: view),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: view == 'calendar'
              ? _EventCalendar(
                  events: data.events,
                  showGroup: isPlatform,
                  onEdit: (e) => _showForm(context, ref, e),
                )
              : events.isEmpty
                  ? const _Empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      itemCount: events.length,
                      itemBuilder: (_, i) => _EventCard(
                        event: events[i],
                        showGroup: isPlatform,
                        onEdit: () => _showForm(context, ref, events[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, EventModel? event) {
    showDialog<void>(
      context: context,
      builder: (_) => _EventFormDialog(
        groups: data.groups,
        event: event,
        onSaved: () => ref.invalidate(eventsProvider),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _kSub)),
          ]),
        ]),
      );
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({required this.label, required this.value, required this.current});
  final String label;
  final String value;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => ref.read(eventFilterProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kNavy : _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _kNavy : _kBorder),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _kSub,
            )),
      ),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.view});
  final String view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget seg(String value, IconData icon, String label) {
      final sel = view == value;
      return GestureDetector(
        onTap: () => ref.read(eventViewProvider.notifier).state = value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : _kSub),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _kSub)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('list', Icons.view_list_rounded, 'Liste'),
        seg('calendar', Icons.calendar_month_rounded, 'Calendrier'),
      ]),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.showGroup, required this.onEdit});
  final EventModel event;
  final bool showGroup;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = event.date;
    final time = [event.startTime, event.endTime].whereType<String>().map((t) {
      final parts = t.split(':');
      return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
    }).join(' – ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Bloc date
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: (event.isPast ? _kSub : _kNavy).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(d != null ? _fmtDay.format(d) : '–',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: event.isPast ? _kSub : _kNavy)),
              Text(d != null ? _fmtMonth.format(d).toUpperCase() : '',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kSub)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(event.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                _StatusPill(published: event.isPublished),
              ]),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(event.description,
                    style: const TextStyle(fontSize: 12, color: _kSub, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 4, children: [
                if (d != null) _Meta(icon: Icons.calendar_today_rounded, label: _fmtFull.format(d)),
                if (time.isNotEmpty) _Meta(icon: Icons.schedule_rounded, label: time),
                if (event.location != null && event.location!.isNotEmpty)
                  _Meta(icon: Icons.place_rounded, label: event.location!),
                _Meta(icon: Icons.groups_rounded, label: _audienceLabels[event.targetAudience] ?? event.targetAudience),
                if (showGroup) _Meta(icon: Icons.corporate_fare_rounded, label: event.groupName),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: _kSub),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) async {
              final client = ref.read(supabaseClientProvider);
              if (v == 'edit') {
                onEdit();
              } else if (v == 'publish') {
                await toggleEventPublish(client, event.id, !event.isPublished);
                ref.invalidate(eventsProvider);
              } else if (v == 'delete') {
                final ok = await _confirmDelete(context);
                if (ok) {
                  await deleteEvent(client, event.id);
                  ref.invalidate(eventsProvider);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit_outlined, size: 16, color: _kNavy), SizedBox(width: 8), Text('Modifier'),
              ])),
              PopupMenuItem(value: 'publish', child: Row(children: [
                Icon(event.isPublished ? Icons.visibility_off_outlined : Icons.public_rounded,
                    size: 16, color: _kAmber),
                const SizedBox(width: 8),
                Text(event.isPublished ? 'Dépublier' : 'Publier'),
              ])),
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: _kRed),
                SizedBox(width: 8),
                Text('Supprimer', style: TextStyle(color: _kRed)),
              ])),
            ],
          ),
        ]),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cet événement ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.published});
  final bool published;
  @override
  Widget build(BuildContext context) {
    final c = published ? _kGreen : _kSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(published ? 'Publié' : 'Brouillon',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kSub),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
      ]);
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Aucun événement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kSub)),
          const SizedBox(height: 4),
          const Text('Créez un événement pour le calendrier scolaire',
              style: TextStyle(fontSize: 12, color: _kSub)),
        ]),
      );
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
        const SizedBox(height: 12),
        Text(error, style: const TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white)),
      ]));
}
