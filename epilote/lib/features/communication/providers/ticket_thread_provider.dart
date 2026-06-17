import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';
import 'messages_provider.dart' show MessageAttachment, parseAttachments;

// ════════════════════════════════════════════════════════════════════════════
//  FIL DE CONVERSATION PAR TICKET SUPPORT — scope-aware, temps réel.
//  • super_admin / admin_groupe → Supabase `.stream()` (realtime).
//  • personnel école → PowerSync `db.watch()` (réactif, hors-ligne).
//  Le fil est toujours un dialogue demandeur ↔ support : pas besoin de
//  résoudre les noms (le super_admin n'est pas dans l'annuaire local).
// ════════════════════════════════════════════════════════════════════════════

class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.body,
    required this.isFromSupport,
    required this.createdAt,
    this.attachments = const [],
  });

  factory TicketMessage.fromMap(Map<String, dynamic> m) => TicketMessage(
        id:            m['id'] as String,
        ticketId:      m['ticket_id'] as String? ?? '',
        authorId:      m['author_id'] as String? ?? '',
        body:          m['body'] as String? ?? '',
        isFromSupport: m['is_from_support'] == true || m['is_from_support'] == 1,
        createdAt:     DateTime.tryParse(m['created_at'] as String? ?? '')
                          ?.toLocal() ?? DateTime.now(),
        attachments:   parseAttachments(m['attachments']),
      );

  final String   id;
  final String   ticketId;
  final String   authorId;
  final String   body;
  final bool     isFromSupport;
  final DateTime createdAt;
  final List<MessageAttachment> attachments;
}

/// Identité d'un participant au ticket (nom + photo + rôle).
class TicketParticipant {
  const TicketParticipant({this.name, this.role, this.avatarUrl});
  final String? name, role, avatarUrl;
}

/// Résout le profil du DEMANDEUR (propriétaire du ticket) — scope-aware.
/// Un ticket est un dialogue demandeur ↔ support : la photo du demandeur suffit
/// (pas de jointure par message). Le support a un avatar générique.
final ticketRequesterProvider = FutureProvider.autoDispose
    .family<TicketParticipant, String>((ref, ownerId) async {
  if (ownerId.isEmpty) return const TicketParticipant();
  final ctx = ref.watch(communicationContextProvider);
  Map<String, dynamic>? p;
  if (ctx.isSchool) {
    p = await db.getOptional(
      'SELECT first_name, last_name, role, avatar_url FROM profiles WHERE id = ?',
      [ownerId],
    );
  } else {
    p = await ref
        .watch(supabaseClientProvider)
        .from('profiles')
        .select('first_name, last_name, role, avatar_url')
        .eq('id', ownerId)
        .maybeSingle();
  }
  if (p == null) return const TicketParticipant();
  final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
  return TicketParticipant(
    name: name.isEmpty ? null : name,
    role: p['role'] as String?,
    avatarUrl: p['avatar_url'] as String?,
  );
});

/// Messages d'un ticket, du plus ancien au plus récent — temps réel.
final ticketThreadProvider = StreamProvider.autoDispose
    .family<List<TicketMessage>, String>((ref, ticketId) async* {
  final ctx = ref.watch(communicationContextProvider);

  if (ctx.isSchool) {
    yield* db
        .watch(
          'SELECT * FROM support_ticket_messages WHERE ticket_id = ? '
          'ORDER BY created_at ASC',
          parameters: [ticketId],
        )
        .map((rows) => rows.map(TicketMessage.fromMap).toList());
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* client
        .from('support_ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(TicketMessage.fromMap).toList());
  }
});

/// Envoie un message dans le fil — scope-aware.
/// École → écriture locale (remonte à la synchro) ; admin/super → online.
Future<void> sendTicketMessageScoped(
  WidgetRef ref, {
  required String ticketId,
  required String ticketOwnerId,
  required String? groupId,
  required String body,
  bool isFromSupport = false,
  List<MessageAttachment> attachments = const [],
}) async {
  final text = body.trim();
  // On autorise l'envoi d'une pièce jointe seule (texte vide).
  if (text.isEmpty && attachments.isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;
  final attachJson = attachments.map((a) => a.toJson()).toList();

  if (ctx.isSchool) {
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT INTO support_ticket_messages
         (id, ticket_id, group_id, ticket_owner_id, author_id, body,
          is_from_support, attachments, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)''',
      [const Uuid().v4(), ticketId, groupId, ticketOwnerId, me.id, text,
       jsonEncode(attachJson), now, now],
    );
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('support_ticket_messages').insert({
      'ticket_id':       ticketId,
      'group_id':        groupId,
      'ticket_owner_id': ticketOwnerId,
      'author_id':       me.id,
      'body':            text,
      'is_from_support': isFromSupport,
      'attachments':     attachJson,
    });
  }
}

/// Réponse du SUPPORT (super_admin) : message dans le fil + mise à jour du
/// ticket (statut + `response` legacy pour les clients hors-ligne tant que
/// les sync-rules ne descendent pas la table de messages).
Future<void> sendSupportReply(
  WidgetRef ref, {
  required String ticketId,
  required String ticketOwnerId,
  required String? groupId,
  required String body,
  required String status,
  List<MessageAttachment> attachments = const [],
}) async {
  final client = ref.read(supabaseClientProvider);
  final me     = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;
  final now = DateTime.now().toIso8601String();

  if (body.trim().isNotEmpty || attachments.isNotEmpty) {
    await client.from('support_ticket_messages').insert({
      'ticket_id':       ticketId,
      'group_id':        groupId,
      'ticket_owner_id': ticketOwnerId,
      'author_id':       me.id,
      'body':            body.trim(),
      'is_from_support': true,
      'attachments':     attachments.map((a) => a.toJson()).toList(),
    });
  }

  final update = <String, dynamic>{
    'status':      status,
    'assigned_to': me.id,
    'updated_at':  now,
  };
  if (body.trim().isNotEmpty) update['response'] = body.trim();
  if (status == 'resolved' || status == 'closed') update['resolved_at'] = now;
  await client.from('support_tickets').update(update).eq('id', ticketId);
}

/// Relance d'un ticket par son demandeur (admin_groupe online) : message +
/// réouverture si le ticket était résolu/fermé.
Future<void> sendRequesterFollowUp(
  WidgetRef ref, {
  required String ticketId,
  required String ticketOwnerId,
  required String? groupId,
  required String body,
  required String currentStatus,
  List<MessageAttachment> attachments = const [],
}) async {
  await sendTicketMessageScoped(
    ref,
    ticketId: ticketId,
    ticketOwnerId: ticketOwnerId,
    groupId: groupId,
    body: body,
    attachments: attachments,
  );
  final ctx = ref.read(communicationContextProvider);
  if (!ctx.isSchool &&
      (currentStatus == 'resolved' || currentStatus == 'closed')) {
    await ref.read(supabaseClientProvider).from('support_tickets').update({
      'status':      'open',
      'resolved_at': null,
      'updated_at':  DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }
}
