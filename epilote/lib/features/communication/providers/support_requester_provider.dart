import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../admin_groupe/providers/admin_support_provider.dart'
    show adminTicketsProvider, createSupportTicket, adminTicketCategories;
import '../../user/providers/staff_support_provider.dart'
    show staffTicketsProvider, createStaffTicketLocal, staffTicketCategories;
import 'communication_scope.dart';
import 'messages_provider.dart' show MessageAttachment;

// ═════════════════════════════════════════════════════════════════════════════
// Support — côté DEMANDEUR, partagé admin_groupe + personnel école.
// Un seul écran/modèle scope-aware : admin_groupe émet en ligne (Supabase),
// le personnel scolaire émet hors-ligne (PowerSync). Le super_admin garde son
// bureau de triage dédié (tickets_screen.dart). Voir communicationContext.
// ═════════════════════════════════════════════════════════════════════════════

/// Vue unifiée d'une demande au support, indépendante de la source (online/offline).
class RequesterTicket {
  const RequesterTicket({
    required this.id,
    required this.subject,
    required this.body,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.submittedBy,
    this.response,
    this.attachments = const [],
  });

  final String id, subject, body, category, status, priority, createdAt;
  final String? submittedBy, response;
  final List<MessageAttachment> attachments;

  bool get hasResponse => response != null && response!.trim().isNotEmpty;
  bool get isClosed => status == 'resolved' || status == 'closed';
}

class RequesterTicketsData {
  const RequesterTicketsData({
    required this.tickets,
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final List<RequesterTicket> tickets;
  final int total, open, inProgress, resolved;

  static const empty = RequesterTicketsData(
      tickets: [], total: 0, open: 0, inProgress: 0, resolved: 0);
}

// ─── Catégories / priorités (catégories selon le périmètre) ──────────────────
Map<String, String> requesterCategories(CommScope scope) =>
    scope == CommScope.group ? adminTicketCategories : staffTicketCategories;

const requesterPriorities = {
  'low':    'Basse',
  'medium': 'Normale',
  'high':   'Haute',
  'urgent': 'Urgente',
};

// ─── Filtre + tri + recherche (état UI unifié) ───────────────────────────────
final requesterStatusFilter = StateProvider.autoDispose<String>((ref) => 'all');
final requesterSortProvider  = StateProvider.autoDispose<String>((ref) => 'recent');
final requesterSearchProvider = StateProvider.autoDispose<String>((ref) => '');

const requesterSortLabels = {
  'recent':   'Plus récents',
  'old':      'Plus anciens',
  'priority': 'Priorité',
  'status':   'Statut',
};

const _priorityRank = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
const _statusRank   = {'open': 0, 'in_progress': 1, 'resolved': 2, 'closed': 3};

List<RequesterTicket> sortRequesterTickets(List<RequesterTicket> list, String sort) {
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

// ─── Provider scope-aware (délègue à la source online ou offline) ────────────
final supportRequesterProvider =
    Provider.autoDispose<AsyncValue<RequesterTicketsData>>((ref) {
  final ctx = ref.watch(communicationContextProvider);

  if (ctx.isGroup) {
    return ref.watch(adminTicketsProvider).whenData(
          (d) => RequesterTicketsData(
            tickets: [
              for (final t in d.tickets)
                RequesterTicket(
                  id: t.id,
                  subject: t.subject,
                  body: t.body,
                  category: t.category,
                  status: t.status,
                  priority: t.priority,
                  createdAt: t.createdAt,
                  submittedBy: t.submittedBy,
                  response: t.response,
                  attachments: t.attachments,
                ),
            ],
            total: d.total,
            open: d.open,
            inProgress: d.inProgress,
            resolved: d.resolved,
          ),
        );
  }

  // Périmètre école → source offline (PowerSync), filtrée sur l'utilisateur.
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const AsyncValue.loading();
  return ref.watch(staffTicketsProvider(uid)).whenData(
        (d) => RequesterTicketsData(
          tickets: [
            for (final t in d.tickets)
              RequesterTicket(
                id: t.id,
                subject: t.subject,
                body: t.body,
                category: t.category,
                status: t.status,
                priority: t.priority,
                createdAt: t.createdAt,
                submittedBy: uid,
                response: t.response,
                attachments: t.attachments,
              ),
          ],
          total: d.total,
          open: d.open,
          inProgress: d.inProgress,
          resolved: d.resolved,
        ),
      );
});

// ─── Création scope-aware (online direct vs local offline-first) ─────────────
Future<void> createRequesterTicket(
  WidgetRef ref, {
  required String subject,
  required String category,
  required String priority,
  required String body,
  List<MessageAttachment> attachments = const [],
}) async {
  final ctx     = ref.read(communicationContextProvider);
  final profile = ref.read(authNotifierProvider).valueOrNull;
  final uid     = ref.read(currentUserProvider)?.id;
  final groupId = profile?.groupId;
  if (uid == null || groupId == null) {
    throw StateError('Session invalide');
  }

  if (ctx.isGroup) {
    await createSupportTicket(
      client: ref.read(supabaseClientProvider),
      groupId: groupId,
      submittedBy: uid,
      subject: subject,
      category: category,
      priority: priority,
      body: body,
      attachments: attachments,
    );
    ref.invalidate(adminTicketsProvider);
  } else {
    await createStaffTicketLocal(
      groupId: groupId,
      submittedBy: uid,
      subject: subject,
      category: category,
      priority: priority,
      body: body,
      attachments: attachments,
    );
    // Le StreamProvider PowerSync se rafraîchit tout seul.
  }
}
