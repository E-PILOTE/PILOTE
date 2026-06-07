import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.isPublished,
    required this.groupId,
    required this.groupName,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.targetAudience = 'all',
    this.schoolId,
  });

  final String  id;
  final String  title;
  final String  description;
  final String  eventDate;   // ISO date (yyyy-MM-dd)
  final bool    isPublished;
  final String  groupId;
  final String  groupName;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String  targetAudience;
  final String? schoolId;

  DateTime? get date => DateTime.tryParse(eventDate);
  bool get isPast {
    final d = date;
    if (d == null) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class EventGroupOption {
  const EventGroupOption({required this.id, required this.name});
  final String id;
  final String name;
}

class EventsData {
  const EventsData({
    required this.events,
    required this.groups,
    required this.total,
    required this.published,
    required this.upcoming,
  });

  final List<EventModel>       events;
  final List<EventGroupOption> groups;
  final int total;
  final int published;
  final int upcoming;

  static const empty =
      EventsData(events: [], groups: [], total: 0, published: 0, upcoming: 0);
}

// ─── Filtres UI ────────────────────────────────────────────────────────────────
final eventFilterProvider = StateProvider.autoDispose<String>((ref) => 'upcoming');
/// Mode d'affichage : 'list' ou 'calendar'.
final eventViewProvider = StateProvider.autoDispose<String>((ref) => 'list');

// ─── Provider principal (scope-aware) ───────────────────────────────────────────
final eventsProvider = FutureProvider.autoDispose<EventsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  // ── Realtime : créations / publications / suppressions en direct ────────────
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('comm_events_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  var query = client.from('events').select(
    'id, title, description, event_date, end_date, start_time, end_time, '
    'location, target_audience, is_published, group_id, school_id, '
    'school_groups!group_id(name)',
  );
  if (ctx.isGroup && ctx.groupId != null) {
    query = query.eq('group_id', ctx.groupId!);
  }
  final rows = await query.order('event_date', ascending: false).limit(300);

  final events = (rows as List).map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? const {};
    return EventModel(
      id:             m['id'] as String,
      title:          m['title'] as String? ?? '(Sans titre)',
      description:    m['description'] as String? ?? '',
      eventDate:      m['event_date'] as String? ?? '',
      endDate:        m['end_date'] as String?,
      startTime:      m['start_time'] as String?,
      endTime:        m['end_time'] as String?,
      location:       m['location'] as String?,
      targetAudience: m['target_audience'] as String? ?? 'all',
      isPublished:    m['is_published'] as bool? ?? false,
      groupId:        m['group_id'] as String? ?? '',
      groupName:      sg['name'] as String? ?? '—',
      schoolId:       m['school_id'] as String?,
    );
  }).toList();

  // Groupes disponibles pour le sélecteur du formulaire
  List<EventGroupOption> groups;
  if (ctx.isGroup && ctx.groupId != null) {
    groups = events.isNotEmpty
        ? [EventGroupOption(id: ctx.groupId!, name: events.first.groupName)]
        : [EventGroupOption(id: ctx.groupId!, name: 'Mon groupe')];
  } else {
    final grows = await client.from('school_groups').select('id, name').order('name');
    groups = (grows as List)
        .map((r) => r as Map)
        .map((m) => EventGroupOption(id: m['id'] as String, name: m['name'] as String? ?? '—'))
        .toList();
  }

  return EventsData(
    events:    events,
    groups:    groups,
    total:     events.length,
    published: events.where((e) => e.isPublished).length,
    upcoming:  events.where((e) => !e.isPast).length,
  );
});

// ─── Actions ──────────────────────────────────────────────────────────────────

Future<void> saveEvent({
  required dynamic client,
  required String createdBy,
  String? id,
  required String groupId,
  String? schoolId,
  required String title,
  required String description,
  required String eventDate,
  String? endDate,
  String? startTime,
  String? endTime,
  String? location,
  required String targetAudience,
  required bool isPublished,
}) async {
  final now = DateTime.now().toIso8601String();
  final payload = {
    'group_id':        groupId,
    'school_id':      ?schoolId,
    'title':           title.trim(),
    'description':     description.trim(),
    'event_date':      eventDate,
    'end_date':       ?endDate,
    'start_time':     ?startTime,
    'end_time':       ?endTime,
    'location':       ?location,
    'target_audience': targetAudience,
    'is_published':    isPublished,
    'updated_at':      now,
  };
  if (id == null) {
    await client.from('events').insert({
      ...payload,
      'created_by': createdBy,
      'created_at': now,
    });
  } else {
    await client.from('events').update(payload).eq('id', id);
  }
}

Future<void> toggleEventPublish(dynamic client, String id, bool publish) async {
  await client.from('events').update({
    'is_published': publish,
    'updated_at':   DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> deleteEvent(dynamic client, String id) async {
  await client.from('events').delete().eq('id', id);
}
