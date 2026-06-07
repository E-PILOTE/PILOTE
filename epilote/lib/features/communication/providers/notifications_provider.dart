import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
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
// super_admin → plateforme entière (RLS) · admin_groupe → son groupe.
// (Le périmètre école/offline sera branché sur PowerSync lors du lot école.)

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

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

  var query = client
      .from('notifications')
      .select(
        'id, type, title, body, is_read, read_at, sent_at, created_at, '
        'group_id, recipient_id, data',
      );
  // Restriction par périmètre groupe (admin_groupe)
  if (ctx.isGroup && ctx.groupId != null) {
    query = query.eq('group_id', ctx.groupId!);
  }
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
});

// ─── Badge (léger, depuis le cache) ──────────────────────────────────────────
final notifBadgeProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.valueOrNull?.unread ?? 0;
});

// ─── Actions ──────────────────────────────────────────────────────────────────

Future<void> markNotificationRead(dynamic client, String id) async {
  await client.from('notifications').update({
    'is_read': true,
    'read_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> markAllNotificationsRead(dynamic client) async {
  await client.from('notifications').update({
    'is_read': true,
    'read_at': DateTime.now().toIso8601String(),
  }).eq('is_read', false);
}
