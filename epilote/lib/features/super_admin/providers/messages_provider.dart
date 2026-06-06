import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class MessageModel {
  const MessageModel({
    required this.id,
    required this.subject,
    required this.body,
    required this.senderName,
    required this.senderId,
    required this.groupName,
    required this.groupId,
    required this.topic,
    required this.isRead,
    required this.isArchived,
    required this.insertedAt,
    this.parentId,
  });

  final String  id;
  final String  subject;
  final String  body;
  final String  senderName;
  final String  senderId;
  final String  groupName;
  final String  groupId;
  final String  topic;
  final bool    isRead;
  final bool    isArchived;
  final String  insertedAt;
  final String? parentId;
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

// ─── Providers ────────────────────────────────────────────────────────────────

final messagesFilterProvider = StateProvider.autoDispose<String>((ref) => 'inbox');

final messagesProvider = FutureProvider.autoDispose<MessagesData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('messages')
      .select(
        'id, subject, body, sender_id, group_id, is_read, is_archived, created_at, parent_message_id, '
        'school_groups!group_id(name)',
      )
      .order('created_at', ascending: false)
      .limit(300);

  final messages = (rows as List).map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    return MessageModel(
      id:         m['id'] as String,
      subject:    m['subject'] as String? ?? '(Sans objet)',
      body:       m['body'] as String? ?? '',
      senderName: 'Admin Groupe',
      senderId:   m['sender_id'] as String? ?? '',
      groupName:  sg['name'] as String? ?? '—',
      groupId:    m['group_id'] as String? ?? '',
      topic:      '',
      isRead:     m['is_read'] as bool? ?? false,
      isArchived: m['is_archived'] as bool? ?? false,
      insertedAt: m['created_at'] as String? ?? '',
      parentId:   m['parent_message_id'] as String?,
    );
  }).toList();

  return MessagesData(
    messages:      messages,
    totalCount:    messages.length,
    unreadCount:   messages.where((m) => !m.isRead && !m.isArchived).length,
    archivedCount: messages.where((m) => m.isArchived).length,
  );
});

// Mark as read
Future<void> markMessageRead(dynamic client, String id) async {
  await client.from('messages').update({
    'is_read': true,
    'read_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

// Archive
Future<void> archiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': true,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

// Unarchive
Future<void> unarchiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': false,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

// Résout l'administrateur de groupe (destinataire) pour un groupe donné.
// Retourne null si aucun admin actif n'existe.
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

// Send / compose — recipient_id est NOT NULL en base
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
    if (parentId != null) 'parent_message_id': parentId,
    'created_at':         now,
    'updated_at':         now,
  });
}
