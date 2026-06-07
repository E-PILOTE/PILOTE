import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class MessageModel {
  const MessageModel({
    required this.id,
    required this.subject,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.groupId,
    required this.groupName,
    required this.isRead,
    required this.isArchived,
    required this.insertedAt,
    this.parentId,
  });

  final String  id;
  final String  subject;
  final String  body;
  final String  senderId;
  final String  senderName;
  final String  recipientId;
  final String  recipientName;
  final String  groupId;
  final String  groupName;
  final bool    isRead;
  final bool    isArchived;
  final String  insertedAt;
  final String? parentId;

  /// Libellé de l'interlocuteur du point de vue de [myId].
  String counterpart(String myId) {
    if (senderId == myId) {
      return recipientName.isNotEmpty ? recipientName : groupName;
    }
    return senderName.isNotEmpty ? senderName : groupName;
  }
}

class MessagesData {
  const MessagesData({
    required this.messages,
    required this.totalCount,
    required this.unreadCount,
    required this.archivedCount,
  });

  final List<MessageModel> messages;
  final int                totalCount;
  final int                unreadCount;
  final int                archivedCount;
}

/// Destinataire possible pour la composition (scope-aware).
class RecipientOption {
  const RecipientOption({required this.value, required this.label, this.subtitle});
  final String  value;   // platform → groupId · group → userId
  final String  label;
  final String? subtitle;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final messagesFilterProvider = StateProvider.autoDispose<String>((ref) => 'inbox');

String _fullName(Map? p, String fallback) {
  if (p == null) return fallback;
  final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
  return n.isNotEmpty ? n : fallback;
}

final messagesProvider = FutureProvider.autoDispose<MessagesData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  // ── Realtime : nouveaux messages / lectures / archivages en direct ──────────
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('comm_messages_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  var query = client.from('messages').select(
    'id, subject, body, sender_id, recipient_id, group_id, is_read, is_archived, '
    'created_at, parent_message_id, '
    'school_groups!group_id(name), '
    'sender:profiles!sender_id(first_name,last_name), '
    'recipient:profiles!recipient_id(first_name,last_name)',
  );
  // Périmètre groupe (admin_groupe) — la plateforme voit tout via RLS.
  if (ctx.isGroup && ctx.groupId != null) {
    query = query.eq('group_id', ctx.groupId!);
  }

  final rows = await query.order('created_at', ascending: false).limit(300);

  final messages = (rows as List).map((r) {
    final m = r as Map;
    final sg = m['school_groups'] as Map? ?? const {};
    return MessageModel(
      id:            m['id'] as String,
      subject:       m['subject'] as String? ?? '(Sans objet)',
      body:          m['body'] as String? ?? '',
      senderId:      m['sender_id'] as String? ?? '',
      senderName:    _fullName(m['sender'] as Map?, 'Expéditeur'),
      recipientId:   m['recipient_id'] as String? ?? '',
      recipientName: _fullName(m['recipient'] as Map?, 'Destinataire'),
      groupId:       m['group_id'] as String? ?? '',
      groupName:     sg['name'] as String? ?? '—',
      isRead:        m['is_read'] as bool? ?? false,
      isArchived:    m['is_archived'] as bool? ?? false,
      insertedAt:    m['created_at'] as String? ?? '',
      parentId:      m['parent_message_id'] as String?,
    );
  }).toList();

  return MessagesData(
    messages:      messages,
    totalCount:    messages.length,
    unreadCount:   messages.where((m) => !m.isRead && !m.isArchived).length,
    archivedCount: messages.where((m) => m.isArchived).length,
  );
});

/// Destinataires possibles selon le périmètre :
/// - plateforme → groupes scolaires (recipient = admin du groupe, résolu à l'envoi)
/// - groupe     → utilisateurs actifs du groupe (recipient = l'utilisateur)
final messageRecipientsProvider =
    FutureProvider.autoDispose<List<RecipientOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  if (ctx.isGroup && ctx.groupId != null) {
    final myId = client.auth.currentUser?.id;
    final rows = await client
        .rpc('get_group_users', params: {'p_group_id': ctx.groupId}) as List;
    return rows
        .map((r) => r as Map)
        .where((m) => m['id'] != myId && (m['is_active'] as bool? ?? true))
        .map((m) => RecipientOption(
              value:    m['id'] as String,
              label:    _fullName(m, m['email'] as String? ?? '—'),
              subtitle: m['email'] as String?,
            ))
        .toList();
  }

  // Plateforme : liste des groupes
  final rows = await client
      .from('school_groups')
      .select('id, name')
      .order('name');
  return (rows as List)
      .map((r) => r as Map)
      .map((m) => RecipientOption(
            value: m['id'] as String,
            label: m['name'] as String? ?? '—',
          ))
      .toList();
});

/// Reconstruit le fil de conversation contenant [m] à partir de la liste
/// chargée : remonte la chaîne `parentId` jusqu'à la racine puis collecte
/// tous les messages du fil, triés par date croissante.
List<MessageModel> threadOf(List<MessageModel> all, MessageModel m) {
  final byId = {for (final x in all) x.id: x};

  String rootOf(MessageModel x) {
    var cur = x;
    final seen = <String>{};
    while (cur.parentId != null &&
        byId.containsKey(cur.parentId) &&
        seen.add(cur.id)) {
      cur = byId[cur.parentId]!;
    }
    return cur.id;
  }

  final root = rootOf(m);
  final thread = all.where((x) => rootOf(x) == root).toList()
    ..sort((a, b) => a.insertedAt.compareTo(b.insertedAt));
  return thread.isEmpty ? [m] : thread;
}

/// Sujet de base d'un fil (sans les préfixes « RE: » accumulés).
String baseSubject(String subject) {
  var s = subject.trim();
  final re = RegExp(r'^(re|rép|rep)\s*:\s*', caseSensitive: false);
  while (re.hasMatch(s)) {
    s = s.replaceFirst(re, '').trim();
  }
  return s.isEmpty ? subject : s;
}

// ─── Actions ──────────────────────────────────────────────────────────────────

Future<void> markMessageRead(dynamic client, String id) async {
  await client.from('messages').update({
    'is_read': true,
    'read_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> markMessageUnread(dynamic client, String id) async {
  await client.from('messages').update({
    'is_read': false,
    'read_at': null,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> deleteMessage(dynamic client, String id) async {
  await client.from('messages').delete().eq('id', id);
}

Future<void> archiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': true,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> unarchiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': false,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

/// Résout l'administrateur de groupe (destinataire) pour un groupe donné.
Future<String?> groupAdminRecipient(dynamic client, String groupId) async {
  final rows = await client
      .from('profiles')
      .select('id')
      .eq('group_id', groupId)
      .eq('role', 'admin_groupe')
      .eq('is_active', true)
      .limit(1);
  final list = rows as List;
  return list.isEmpty ? null : (list.first as Map)['id'] as String;
}

/// Envoie / compose — `recipient_id` et `group_id` sont NOT NULL en base.
Future<void> sendMessage({
  required dynamic client,
  required String senderId,
  required String recipientId,
  required String groupId,
  required String subject,
  required String body,
  String? parentId,
}) async {
  final now = DateTime.now().toIso8601String();
  await client.from('messages').insert({
    'sender_id':          senderId,
    'recipient_id':       recipientId,
    'group_id':           groupId,
    'subject':            subject.trim(),
    'body':               body.trim(),
    'is_read':            false,
    'is_archived':        false,
    'parent_message_id': ?parentId,
    'created_at':         now,
    'updated_at':         now,
  });
}
