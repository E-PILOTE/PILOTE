import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../communication/providers/messages_provider.dart'
    show MessageAttachment, parseAttachments;

// ─── Modèles ──────────────────────────────────────────────────────────────────

class TicketModel {
  const TicketModel({
    required this.id,
    required this.subject,
    required this.body,
    required this.groupName,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.groupId,
    this.submittedBy,
    this.response,
    this.resolvedAt,
    this.attachments = const [],
  });

  final String  id;
  final String  subject;
  final String  body;
  final String  groupName;
  final String  category;
  final String  status;
  final String  priority;
  final String  createdAt;
  final String? groupId;
  final String? submittedBy;
  final String? response;
  final String? resolvedAt;
  final List<MessageAttachment> attachments;

  bool get isClosed => status == 'resolved' || status == 'closed';
}

class TicketsData {
  const TicketsData({
    required this.tickets,
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.urgent,
  });

  final List<TicketModel> tickets;
  final int               total;
  final int               open;
  final int               inProgress;
  final int               resolved;
  final int               urgent;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final ticketsStatusFilter   = StateProvider.autoDispose<String>((ref) => 'all');
final ticketsPriorityFilter = StateProvider.autoDispose<String>((ref) => 'all');

final ticketsProvider = FutureProvider.autoDispose<TicketsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime : nouveaux tickets / relances / changements de statut en direct.
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('super_support_tickets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
          callback: (_) => scheduleInvalidate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_ticket_messages',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  final rows = await client
      .from('support_tickets')
      .select(
        'id, group_id, submitted_by, subject, body, category, status, '
        'priority, created_at, response, resolved_at, attachments, '
        'school_groups!group_id(name)',
      )
      .order('created_at', ascending: false);

  final tickets = (rows as List).map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    return TicketModel(
      id:          m['id'] as String,
      subject:     m['subject'] as String? ?? '(Sans objet)',
      body:        m['body'] as String? ?? '',
      groupName:   sg['name'] as String? ?? '—',
      category:    m['category'] as String? ?? 'Général',
      status:      m['status'] as String? ?? 'open',
      priority:    m['priority'] as String? ?? 'medium',
      createdAt:   m['created_at'] as String? ?? '',
      groupId:     m['group_id'] as String?,
      submittedBy: m['submitted_by'] as String?,
      response:    m['response'] as String?,
      resolvedAt:  m['resolved_at'] as String?,
      attachments: parseAttachments(m['attachments']),
    );
  }).toList();

  return TicketsData(
    tickets:    tickets,
    total:      tickets.length,
    open:       tickets.where((t) => t.status == 'open').length,
    inProgress: tickets.where((t) => t.status == 'in_progress').length,
    resolved:   tickets.where((t) => t.isClosed).length,
    urgent:     tickets.where((t) => t.priority == 'urgent').length,
  );
});

/// Changement de statut seul (sans message) — depuis les chips du détail.
Future<void> updateTicketStatus(dynamic client, String id, String status,
    {String? response}) async {
  final update = <String, dynamic>{
    'status':     status,
    'updated_at': DateTime.now().toIso8601String(),
  };
  if (response != null) update['response'] = response;
  if (status == 'resolved' || status == 'closed') {
    update['resolved_at'] = DateTime.now().toIso8601String();
  } else {
    update['resolved_at'] = null;
  }
  await client.from('support_tickets').update(update).eq('id', id);
}
