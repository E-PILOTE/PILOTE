import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../communication/providers/messages_provider.dart'
    show MessageAttachment, parseAttachments;

// ─── Modèle ───────────────────────────────────────────────────────────────────
class AdminTicket {
  const AdminTicket({
    required this.id,
    required this.subject,
    required this.body,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.submittedBy,
    this.response,
    this.resolvedAt,
    this.attachments = const [],
  });

  factory AdminTicket.fromRow(Map<String, dynamic> r) => AdminTicket(
        id:          r['id'] as String,
        subject:     r['subject'] as String? ?? '(Sans objet)',
        body:        r['body'] as String? ?? '',
        category:    r['category'] as String? ?? 'autre',
        status:      r['status'] as String? ?? 'open',
        priority:    r['priority'] as String? ?? 'medium',
        createdAt:   r['created_at'] as String? ?? '',
        submittedBy: r['submitted_by'] as String?,
        response:    r['response'] as String?,
        resolvedAt:  r['resolved_at'] as String?,
        attachments: parseAttachments(r['attachments']),
      );

  final String  id, subject, body, category, status, priority, createdAt;
  final String? submittedBy, response, resolvedAt;
  final List<MessageAttachment> attachments;

  bool get hasResponse => response != null && response!.trim().isNotEmpty;
  bool get isClosed    => status == 'resolved' || status == 'closed';
}

class AdminTicketsData {
  const AdminTicketsData({
    required this.tickets,
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final List<AdminTicket> tickets;
  final int total, open, inProgress, resolved;

  static const empty =
      AdminTicketsData(tickets: [], total: 0, open: 0, inProgress: 0, resolved: 0);
}

// Catégories proposées à la création (clé technique → libellé)
const adminTicketCategories = {
  'technique':          'Problème technique',
  'facturation':        'Facturation / abonnement',
  'compte':             'Compte & utilisateurs',
  'modification_groupe':'Modification du groupe',
  'fonctionnalite':     'Demande de fonctionnalité',
  'autre':              'Autre',
};

const adminTicketPriorities = {
  'low':    'Basse',
  'medium': 'Normale',
  'high':   'Haute',
  'urgent': 'Urgente',
};

// ─── Filtre + tri UI ─────────────────────────────────────────────────────────
final adminTicketStatusFilter = StateProvider.autoDispose<String>((ref) => 'all');
/// Tri : 'recent' | 'old' | 'priority' | 'status'.
final adminTicketSortProvider = StateProvider.autoDispose<String>((ref) => 'recent');
/// Recherche plein-texte (objet + description).
final adminTicketSearchProvider = StateProvider.autoDispose<String>((ref) => '');

const adminTicketSortLabels = {
  'recent':   'Plus récents',
  'old':      'Plus anciens',
  'priority': 'Priorité',
  'status':   'Statut',
};

const _priorityRank = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
const _statusRank   = {'open': 0, 'in_progress': 1, 'resolved': 2, 'closed': 3};

/// Trie une liste de tickets selon le mode choisi.
List<AdminTicket> sortTickets(List<AdminTicket> list, String sort) {
  final out = [...list];
  switch (sort) {
    case 'old':
      out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case 'priority':
      out.sort((a, b) =>
          (_priorityRank[a.priority] ?? 9).compareTo(_priorityRank[b.priority] ?? 9));
    case 'status':
      out.sort((a, b) =>
          (_statusRank[a.status] ?? 9).compareTo(_statusRank[b.status] ?? 9));
    default: // recent
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return out;
}

// ─── Provider principal (scope groupe + realtime) ───────────────────────────────
final adminTicketsProvider =
    FutureProvider.autoDispose<AdminTicketsData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminTicketsData.empty;

  // Realtime : réponses du support / changements de statut en direct
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('admin_support_tickets')
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
      .select('id, subject, body, category, status, priority, response, '
          'resolved_at, created_at, submitted_by, attachments')
      .eq('group_id', groupId)
      .order('created_at', ascending: false) as List;

  final tickets = [for (final r in rows) AdminTicket.fromRow(r as Map<String, dynamic>)];

  return AdminTicketsData(
    tickets:    tickets,
    total:      tickets.length,
    open:       tickets.where((t) => t.status == 'open').length,
    inProgress: tickets.where((t) => t.status == 'in_progress').length,
    resolved:   tickets.where((t) => t.isClosed).length,
  );
});

// ─── Actions ─────────────────────────────────────────────────────────────────
Future<void> createSupportTicket({
  required dynamic client,
  required String groupId,
  required String submittedBy,
  required String subject,
  required String category,
  required String priority,
  required String body,
  List<MessageAttachment> attachments = const [],
}) async {
  await client.from('support_tickets').insert({
    'group_id':     groupId,
    'submitted_by': submittedBy,
    'subject':      subject.trim(),
    'category':     category,
    'priority':     priority,
    'body':         body.trim(),
    'status':       'open',
    'attachments':  attachments.map((a) => a.toJson()).toList(),
  });
}
