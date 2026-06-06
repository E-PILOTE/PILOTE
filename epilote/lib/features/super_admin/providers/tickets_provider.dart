import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

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
    this.response,
    this.resolvedAt,
  });

  final String  id;
  final String  subject;
  final String  body;
  final String  groupName;
  final String  category;
  final String  status;
  final String  priority;
  final String  createdAt;
  final String? response;
  final String? resolvedAt;
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

  final rows = await client
      .from('support_tickets')
      .select(
        'id, subject, body, category, status, priority, created_at, '
        'response, resolved_at, '
        'school_groups!group_id(name)',
      )
      .order('created_at', ascending: false);

  final tickets = (rows as List).map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    return TicketModel(
      id:         m['id'] as String,
      subject:    m['subject'] as String? ?? '(Sans objet)',
      body:       m['body'] as String? ?? '',
      groupName:  sg['name'] as String? ?? '—',
      category:   m['category'] as String? ?? 'Général',
      status:     m['status'] as String? ?? 'open',
      priority:   m['priority'] as String? ?? 'medium',
      createdAt:  m['created_at'] as String? ?? '',
      response:   m['response'] as String?,
      resolvedAt: m['resolved_at'] as String?,
    );
  }).toList();

  return TicketsData(
    tickets:    tickets,
    total:      tickets.length,
    open:       tickets.where((t) => t.status == 'open').length,
    inProgress: tickets.where((t) => t.status == 'in_progress').length,
    resolved:   tickets.where((t) => ['resolved','closed'].contains(t.status)).length,
    urgent:     tickets.where((t) => t.priority == 'urgent').length,
  );
});

// Update ticket status
Future<void> updateTicketStatus(dynamic client, String id, String status, {String? response}) async {
  final update = <String, dynamic>{
    'status':     status,
    'updated_at': DateTime.now().toIso8601String(),
  };
  if (response != null) update['response'] = response;
  if (status == 'resolved' || status == 'closed') {
    update['resolved_at'] = DateTime.now().toIso8601String();
  }
  await client.from('support_tickets').update(update).eq('id', id);
}
