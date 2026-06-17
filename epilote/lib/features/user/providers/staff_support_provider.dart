import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../communication/providers/messages_provider.dart'
    show MessageAttachment, parseAttachments;

// ═════════════════════════════════════════════════════════════════════════════
// Support du personnel scolaire — 100 % OFFLINE-FIRST (PowerSync).
// La demande est écrite en SQLite local puis remonte vers Supabase à la
// reconnexion (connector upload). La réponse du support redescend par la
// sync-rule `by_user` (submitted_by = soi). Symétrique de l'espace Support
// admin_groupe (admin_support_provider, online direct).
// ═════════════════════════════════════════════════════════════════════════════

class StaffTicket {
  const StaffTicket({
    required this.id,
    required this.subject,
    required this.body,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.response,
    this.resolvedAt,
    this.attachments = const [],
  });

  factory StaffTicket.fromRow(Map<String, dynamic> r) => StaffTicket(
        id:         r['id'] as String,
        subject:    r['subject'] as String? ?? '',
        body:       r['body'] as String? ?? '',
        category:   r['category'] as String? ?? 'autre',
        status:     r['status'] as String? ?? 'open',
        priority:   r['priority'] as String? ?? 'medium',
        createdAt:  r['created_at'] as String? ?? '',
        response:   r['response'] as String?,
        resolvedAt: r['resolved_at'] as String?,
        attachments: parseAttachments(r['attachments']),
      );

  final String id, subject, body, category, status, priority, createdAt;
  final String? response, resolvedAt;
  final List<MessageAttachment> attachments;

  bool get isClosed => status == 'resolved' || status == 'closed';
  bool get hasResponse => response != null && response!.trim().isNotEmpty;
}

class StaffTicketsData {
  const StaffTicketsData({
    required this.tickets,
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final List<StaffTicket> tickets;
  final int total, open, inProgress, resolved;

  static const empty = StaffTicketsData(
      tickets: [], total: 0, open: 0, inProgress: 0, resolved: 0);
}

// Catégories proposées au personnel (clé technique → libellé)
const staffTicketCategories = {
  'technique':      'Problème technique',
  'synchronisation':'Synchronisation des données',
  'compte':         'Compte & accès',
  'fonctionnalite': 'Demande de fonctionnalité',
  'autre':          'Autre',
};

const staffTicketPriorities = {
  'low':    'Basse',
  'medium': 'Normale',
  'high':   'Haute',
  'urgent': 'Urgente',
};

// ─── Filtre + tri UI ─────────────────────────────────────────────────────────
final staffTicketStatusFilter = StateProvider.autoDispose<String>((ref) => 'all');
/// Tri : 'recent' | 'old' | 'priority' | 'status'.
final staffTicketSortProvider = StateProvider.autoDispose<String>((ref) => 'recent');
/// Recherche plein-texte (objet + description).
final staffTicketSearchProvider = StateProvider.autoDispose<String>((ref) => '');

const staffTicketSortLabels = {
  'recent':   'Plus récents',
  'old':      'Plus anciens',
  'priority': 'Priorité',
  'status':   'Statut',
};

const _priorityRank = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
const _statusRank   = {'open': 0, 'in_progress': 1, 'resolved': 2, 'closed': 3};

/// Trie une liste de tickets selon le mode choisi.
List<StaffTicket> sortStaffTickets(List<StaffTicket> list, String sort) {
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

// ─── Provider principal — db.watch (réactif, hors ligne par nature) ──────────
final staffTicketsProvider =
    StreamProvider.autoDispose.family<StaffTicketsData, String>((ref, uid) {
  ref.keepAlive();
  return db
      .watch(
        'SELECT * FROM support_tickets WHERE submitted_by = ? '
        'ORDER BY created_at DESC',
        parameters: [uid],
      )
      .map((rows) {
    final tickets = rows
        .map((r) => StaffTicket.fromRow(Map<String, dynamic>.from(r)))
        .toList();
    return StaffTicketsData(
      tickets:    tickets,
      total:      tickets.length,
      open:       tickets.where((t) => t.status == 'open').length,
      inProgress: tickets.where((t) => t.status == 'in_progress').length,
      resolved:   tickets.where((t) => t.isClosed).length,
    );
  });
});

/// Crée la demande en LOCAL (SQLite) — l'upload vers Supabase se fait
/// automatiquement à la prochaine connexion (RLS : `group_insert_tickets`
/// autorise tout membre du groupe avec submitted_by = auth.uid()).
Future<void> createStaffTicketLocal({
  required String groupId,
  required String submittedBy,
  required String subject,
  required String category,
  required String priority,
  required String body,
  List<MessageAttachment> attachments = const [],
}) async {
  final id  = const Uuid().v4();
  final now = DateTime.now().toIso8601String();
  final attachJson = jsonEncode(attachments.map((a) => a.toJson()).toList());
  await db.execute(
    '''INSERT INTO support_tickets
       (id, group_id, submitted_by, subject, body, category,
        status, priority, attachments, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'open', ?, ?, ?, ?)''',
    [id, groupId, submittedBy, subject.trim(), body.trim(), category,
     priority, attachJson, now, now],
  );
}
