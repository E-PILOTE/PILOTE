import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'communication_scope.dart';
import 'messages_provider.dart' show MessageAttachment, parseAttachments;
import '../../../core/utils/erreur_metier.dart';

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
    this.attachments = const [],
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
  final List<MessageAttachment> attachments;

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
    'location, target_audience, is_published, group_id, school_id, attachments, '
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
      attachments:    parseAttachments(m['attachments']),
    );
  }).toList();

  // Groupes disponibles pour le sélecteur du formulaire
  List<EventGroupOption> groups;
  if (ctx.isGroup && ctx.groupId != null) {
    groups = events.isNotEmpty
        ? [EventGroupOption(id: ctx.groupId!, name: events.first.groupName)]
        : [EventGroupOption(id: ctx.groupId!, name: 'Mon groupe')];
  } else {
    final grows = await client.from('school_groups').select('id, name').order('name', ascending: true);
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

// ─── Personnel école — événements offline-first (lecture seule) ─────────────────
// Événements PUBLIÉS. Les sync-rules descendent ceux du GROUPE entier (bucket
// by_group) : on re-filtre localement le ciblage — `school_id IS NULL` =
// événement réseau (toutes les écoles), sinon uniquement ceux adressés à MON
// école. 100 % local (SQLite), réactif, hors-ligne. Tri chronologique.
final schoolEventsProvider =
    StreamProvider.autoDispose<List<EventModel>>((ref) {
  final profile  = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId ?? '';
  final groupId  = profile?.groupId ?? '';
  if (schoolId.isEmpty && groupId.isEmpty) return Stream.value(const []);

  return db
      .watch(
        '''SELECT * FROM events
           WHERE is_published = 1
             AND (school_id IS NULL OR school_id = ?)
           ORDER BY event_date ASC''',
        parameters: [schoolId],
      )
      .map((rows) => rows.map(_eventFromLocalRow).toList());
});

EventModel _eventFromLocalRow(Map<String, dynamic> m) => EventModel(
      id:             m['id'] as String,
      title:          m['title'] as String? ?? '(Sans titre)',
      description:    m['description'] as String? ?? '',
      eventDate:      m['event_date'] as String? ?? '',
      endDate:        m['end_date'] as String?,
      startTime:      m['start_time'] as String?,
      endTime:        m['end_time'] as String?,
      location:       m['location'] as String?,
      targetAudience: m['target_audience'] as String? ?? 'all',
      isPublished:    m['is_published'] == 1 || m['is_published'] == true,
      groupId:        m['group_id'] as String? ?? '',
      groupName:      '',
      schoolId:       m['school_id'] as String?,
      attachments:    parseAttachments(m['attachments']),
    );

// ─── Actions locales DIRECTION (offline-first, scope = MON école) ──────────────
// RLS serveur : events_tenant autorise l'écriture si school_id = auth_school_id().

Future<String> createSchoolEventLocal({
  required String groupId,
  required String schoolId,
  required String createdBy,
  required String title,
  required String description,
  required String eventDate,
  String? endDate,
  String? startTime,
  String? endTime,
  String? location,
  String targetAudience = 'all',
  List<MessageAttachment> attachments = const [],
}) async {
  final id  = const Uuid().v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''INSERT INTO events
       (id, group_id, school_id, title, description, event_date, end_date,
        start_time, end_time, location, target_audience, is_published,
        attachments, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)''',
    [id, groupId, schoolId, title.trim(), description.trim(), eventDate,
     endDate, startTime, endTime, location, targetAudience,
     jsonEncode(attachments.map((a) => a.toJson()).toList()),
     createdBy, now, now],
  );
  return id;
}

Future<void> updateSchoolEventLocal({
  required String id,
  required String title,
  required String description,
  required String eventDate,
  String? endDate,
  String? startTime,
  String? endTime,
  String? location,
  required String targetAudience,
  List<MessageAttachment>? attachments,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''UPDATE events
       SET title = ?, description = ?, event_date = ?, end_date = ?,
           start_time = ?, end_time = ?, location = ?, target_audience = ?
           ${attachments != null ? ', attachments = ?' : ''}, updated_at = ?
       WHERE id = ?''',
    [title.trim(), description.trim(), eventDate, endDate, startTime, endTime,
     location, targetAudience,
     if (attachments != null)
       jsonEncode(attachments.map((a) => a.toJson()).toList()),
     now, id],
  );
}

Future<void> deleteSchoolEventLocal(String id) async {
  await db.execute('DELETE FROM events WHERE id = ?', [id]);
}

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
  List<MessageAttachment>? attachments,
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
    if (attachments != null)
      'attachments': attachments.map((a) => a.toJson()).toList(),
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

// ════════════════════════════════════════════════════════════════════════════
//  COUCHE UNIFIÉE SCOPE-AWARE — UN seul agenda partagé par super_admin /
//  admin_groupe (online Supabase) ET école (offline PowerSync). Réutilisé comme
//  onglet « Agenda » du module Annonces (pas de page Événements dupliquée).
// ════════════════════════════════════════════════════════════════════════════

/// Liste d'événements affichée par l'agenda, quel que soit l'espace.
final scopedEventsProvider =
    Provider.autoDispose<AsyncValue<List<EventModel>>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) return ref.watch(schoolEventsProvider);
  return ref.watch(eventsProvider).whenData((d) => d.events);
});

/// Groupes pour le sélecteur du formulaire (super_admin = tous ; sinon le sien).
final eventGroupsProvider = Provider.autoDispose<List<EventGroupOption>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) return const [];
  return ref.watch(eventsProvider).valueOrNull?.groups ?? const [];
});

/// Création/MAJ SCOPE-AWARE : école → local (offline) ; admin/super → online.
Future<void> saveEventScoped(
  WidgetRef ref, {
  String? id,
  required String title,
  required String description,
  required String eventDate,
  String? endDate,
  String? startTime,
  String? endTime,
  String? location,
  required String targetAudience,
  bool isPublished = true,
  List<MessageAttachment>? attachments,
  String? groupIdOverride,
}) async {
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) throw const ErreurMetier('Session invalide.');
  if (ctx.isSchool) {
    if (id == null) {
      await createSchoolEventLocal(
        groupId: me.groupId!,
        schoolId: me.schoolId!,
        createdBy: me.id,
        title: title,
        description: description,
        eventDate: eventDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        location: location,
        targetAudience: targetAudience,
        attachments: attachments ?? const [],
      );
    } else {
      await updateSchoolEventLocal(
        id: id,
        title: title,
        description: description,
        eventDate: eventDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        location: location,
        targetAudience: targetAudience,
        attachments: attachments,
      );
    }
  } else {
    final groupId = ctx.isGroup ? ctx.groupId : groupIdOverride;
    if (groupId == null || groupId.isEmpty) {
      throw const ErreurMetier('Choisissez un groupe destinataire.');
    }
    await saveEvent(
      client: ref.read(supabaseClientProvider),
      createdBy: me.id,
      id: id,
      groupId: groupId,
      title: title,
      description: description,
      eventDate: eventDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      location: location,
      targetAudience: targetAudience,
      isPublished: isPublished,
      attachments: attachments,
    );
    ref.invalidate(eventsProvider); // refresh immédiat (ne pas dépendre du realtime)
  }
}

/// Suppression SCOPE-AWARE : école → local ; admin/super → online.
Future<void> deleteEventScoped(WidgetRef ref, String id) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await deleteSchoolEventLocal(id);
  } else {
    await deleteEvent(ref.read(supabaseClientProvider), id);
    ref.invalidate(eventsProvider);
  }
}
