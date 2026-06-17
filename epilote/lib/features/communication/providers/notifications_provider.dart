import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'communication_scope.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.groupId,
    this.groupName,
    this.recipientId,
    this.sentAt,
    this.data,
  });

  final String  id;
  final String  type;
  final String  title;
  final String  body;
  final bool    isRead;
  final String  createdAt;
  final String? groupId;
  final String? groupName;
  final String? recipientId;
  final String? sentAt;
  final Map<String, dynamic>? data;

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id:          id,
    type:        type,
    title:       title,
    body:        body,
    isRead:      isRead ?? this.isRead,
    createdAt:   createdAt,
    groupId:     groupId,
    groupName:   groupName,
    recipientId: recipientId,
    sentAt:      sentAt,
    data:        data,
  );
}

class NotificationsData {
  const NotificationsData({
    required this.notifications,
    required this.total,
    required this.unread,
    required this.byType,
    required this.todayCount,
    required this.weekCount,
  });

  final List<NotificationModel> notifications;
  final int                     total;
  final int                     unread;
  final Map<String, int>        byType;
  final int                     todayCount;
  final int                     weekCount;
}

// ─── Filtres UI ────────────────────────────────────────────────────────────────

final notifTypeFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final notifReadFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final notifSearchProvider     = StateProvider.autoDispose<String>((ref) => '');

// ─── Provider principal (scope-aware) ───────────────────────────────────────────
// super_admin → plateforme entière (RLS) · admin_groupe → son groupe (online).
// personnel école → SON périmètre via PowerSync (offline-first, recipient_id).

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsData>((ref) async {
  ref.keepAlive();
  final ctx = ref.watch(communicationContextProvider);

  // Personnel scolaire : lecture 100 % locale (SQLite), réactive et hors-ligne.
  if (ctx.isSchool) return _notificationsOffline(ref);

  final client = ref.watch(supabaseClientProvider);

  // ── Realtime : rafraîchit la liste dès qu'une notif est émise/lue ───────────
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('comm_notifications_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // La cloche est PERSONNELLE : on ne montre que MES notifications (1 ligne par
  // destinataire générée par le trigger `trg_notify_on_message`). Sans ce filtre,
  // le super_admin verrait toutes les notifications de la plateforme (RLS large).
  final myUid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  var query = client
      .from('notifications')
      .select(
        'id, type, title, body, is_read, read_at, sent_at, created_at, '
        'group_id, recipient_id, data',
      )
      .eq('recipient_id', myUid);
  final rows = await query.order('created_at', ascending: false).limit(500);

  // Noms des groupes (pour l'affichage plateforme)
  final groupIds = (rows as List)
      .map((r) => (r as Map)['group_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();

  final Map<String, String> groupNames = {};
  if (groupIds.isNotEmpty) {
    final groups = await client
        .from('school_groups')
        .select('id, name')
        .inFilter('id', groupIds);
    for (final g in groups as List) {
      groupNames[(g as Map)['id'] as String] = g['name'] as String;
    }
  }

  final notifications = rows.map((r) {
    final m = r as Map;
    final gid = m['group_id'] as String?;
    return NotificationModel(
      id:          m['id'] as String,
      type:        m['type'] as String? ?? 'system',
      title:       m['title'] as String? ?? '(Sans titre)',
      body:        m['body'] as String? ?? '',
      isRead:      m['is_read'] as bool? ?? false,
      createdAt:   m['created_at'] as String? ?? '',
      groupId:     gid,
      groupName:   gid != null ? groupNames[gid] : null,
      recipientId: m['recipient_id'] as String?,
      sentAt:      m['sent_at'] as String?,
      data:        m['data'] as Map<String, dynamic>?,
    );
  }).toList();

  return _aggregate(notifications);
});

// ─── Périmètre école — lecture offline-first (PowerSync) ────────────────────────
// Notifications du membre (recipient_id = son profil), lues depuis SQLite local.
// Réactif : ré-évalue à chaque changement local, fonctionne hors-ligne.
Future<NotificationsData> _notificationsOffline(Ref ref) async {
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
  if (uid == null || uid.isEmpty) {
    return const NotificationsData(
      notifications: [], total: 0, unread: 0,
      byType: {}, todayCount: 0, weekCount: 0,
    );
  }

  // Réactivité locale (on ignore l'émission initiale pour éviter une boucle).
  final sub = db
      .watch('SELECT id FROM notifications WHERE recipient_id = ?',
          parameters: [uid])
      .skip(1)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final rows = await db.getAll(
    '''SELECT * FROM notifications WHERE recipient_id = ?
       ORDER BY created_at DESC LIMIT 500''',
    [uid],
  );

  final notifications = rows.map((m) => NotificationModel(
        id:          m['id'] as String,
        type:        m['type'] as String? ?? 'system',
        title:       m['title'] as String? ?? '(Sans titre)',
        body:        m['body'] as String? ?? '',
        isRead:      m['is_read'] == 1 || m['is_read'] == true,
        createdAt:   m['created_at'] as String? ?? '',
        groupId:     m['group_id'] as String?,
        recipientId: m['recipient_id'] as String?,
        sentAt:      m['sent_at'] as String?,
        data:        _decodeData(m['data']),
      )).toList();

  return _aggregate(notifications);
}

Map<String, dynamic>? _decodeData(Object? v) {
  if (v == null) return null;
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.isNotEmpty) {
    try {
      final d = jsonDecode(v);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Agrégation commune (online + offline) : totaux, non-lues, par type, période.
NotificationsData _aggregate(List<NotificationModel> notifications) {
  final now  = DateTime.now();
  final week = now.subtract(const Duration(days: 7));

  final Map<String, int> byType = {};
  for (final n in notifications) {
    byType[n.type] = (byType[n.type] ?? 0) + 1;
  }

  return NotificationsData(
    notifications: notifications,
    total:         notifications.length,
    unread:        notifications.where((n) => !n.isRead).length,
    byType:        byType,
    todayCount:    notifications.where((n) {
      final d = DateTime.tryParse(n.createdAt);
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }).length,
    weekCount: notifications.where((n) {
      final d = DateTime.tryParse(n.createdAt);
      return d != null && d.isAfter(week);
    }).length,
  );
}

// ─── Badge (léger, depuis le cache) ──────────────────────────────────────────
final notifBadgeProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.valueOrNull?.unread ?? 0;
});

// ─── Actions (scope-aware) ──────────────────────────────────────────────────────
// Personnel école → écriture locale PowerSync (offline-first, remontée à la sync).
// super_admin / admin_groupe → Supabase direct (online) + invalidation immédiate.

Future<void> markNotifRead(WidgetRef ref, String id) async {
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
      'UPDATE notifications SET is_read = 1, read_at = ?, updated_at = ? WHERE id = ?',
      [now, now, id],
    );
    // La liste se rafraîchit via la souscription db.watch — pas d'invalidate.
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('notifications')
        .update({'is_read': true, 'read_at': now}).eq('id', id);
    ref.invalidate(notificationsProvider);
  }
}

Future<void> markAllNotifRead(WidgetRef ref) async {
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    final uid = ref.read(authNotifierProvider).valueOrNull?.id;
    if (uid == null || uid.isEmpty) return;
    await db.execute(
      'UPDATE notifications SET is_read = 1, read_at = ?, updated_at = ? '
      'WHERE recipient_id = ? AND is_read = 0',
      [now, now, uid],
    );
  } else {
    final uid = ref.read(authNotifierProvider).valueOrNull?.id;
    if (uid == null || uid.isEmpty) return;
    final client = ref.read(supabaseClientProvider);
    // Ne marquer lues que MES notifications (le super_admin verrait sinon
    // toutes celles de la plateforme via RLS).
    await client.from('notifications')
        .update({'is_read': true, 'read_at': now})
        .eq('recipient_id', uid)
        .eq('is_read', false);
    ref.invalidate(notificationsProvider);
  }
}
