import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../super_admin/providers/invoices_provider.dart' show InvoiceDetail;

// ─── Modèles ────────────────────────────────────────────────────────────────
class GroupSubscription {
  const GroupSubscription({
    required this.groupName,
    required this.planId,
    required this.planName,
    required this.planSlug,
    required this.priceXaf,
    required this.status,
    required this.start,
    required this.end,
    required this.maxSchools,
    required this.maxStudents,
    required this.maxStaff,
    required this.moduleCount,
    required this.schoolsUsed,
    required this.studentsUsed,
    required this.staffUsed,
    this.description,
  });
  final String groupName;
  final String? planId;
  final String planName;
  final String planSlug;
  final int priceXaf;
  final String status;
  final DateTime? start;
  final DateTime? end;
  final int maxSchools, maxStudents, maxStaff, moduleCount;
  final int schoolsUsed, studentsUsed, staffUsed;
  final String? description;

  int? get daysLeft => end?.difference(DateTime.now()).inDays;
  bool get expireSoon {
    final d = daysLeft;
    return d != null && d >= 0 && d <= 30;
  }
  bool get expired {
    final d = daysLeft;
    return d != null && d < 0;
  }
}

/// Une famille de modules débloquée par un plan (ex: "FINANCE — 7 modules").
class PlanCategory {
  const PlanCategory({
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.moduleCount,
  });
  final String categoryId;
  final String name;
  final String slug;
  final int displayOrder;
  final int moduleCount;
}

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceXaf,
    required this.maxSchools,
    required this.maxStudents,
    required this.maxStaff,
    required this.moduleCount,
    this.description,
    this.categories = const [],
  });
  final String id;
  final String name;
  final String slug;
  final int priceXaf;
  final int maxSchools, maxStudents, maxStaff, moduleCount;
  final String? description;

  /// Familles de modules débloquées (triées par display_order).
  final List<PlanCategory> categories;

  bool get unlimitedSchools  => maxSchools  <= 0;
  bool get unlimitedStudents => maxStudents <= 0;
  bool get unlimitedStaff    => maxStaff    <= 0;

  /// Nombre de modules débloqués pour une famille donnée (0 si absente).
  int modulesInCategory(String categorySlug) => categories
      .firstWhere(
        (c) => c.slug == categorySlug,
        orElse: () => const PlanCategory(
            categoryId: '', name: '', slug: '', displayOrder: 0, moduleCount: 0),
      )
      .moduleCount;

  /// Descriptif lisible — généré si la colonne `description` est nulle en base.
  String get effectiveDescription {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    final schools = unlimitedSchools ? 'écoles illimitées' : '$maxSchools école${maxSchools > 1 ? 's' : ''}';
    final students = unlimitedStudents ? 'élèves illimités' : '$maxStudents élèves';
    return priceXaf == 0
        ? 'Offre de découverte : $schools, $students et $moduleCount modules essentiels pour démarrer.'
        : 'Plan $name : $schools, $students et $moduleCount modules pour piloter votre établissement.';
  }
}

class SubscriptionTicket {
  const SubscriptionTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.body,
    this.response,
    this.resolvedAt,
  });
  final String id;
  final String subject;
  final String status;
  final String priority;
  final DateTime? createdAt;
  final String? body;
  final String? response;
  final DateTime? resolvedAt;
}

class AdminSubscriptionData {
  const AdminSubscriptionData({
    required this.subscription,
    required this.plans,
    required this.tickets,
    required this.invoices,
  });
  final GroupSubscription? subscription;
  final List<PlanOption> plans;
  final List<SubscriptionTicket> tickets;
  final List<InvoiceDetail> invoices;

  // ── Synthèse de facturation (lecture seule) ──
  int get billedTotal      => invoices.fold(0, (s, i) => s + i.amountXaf);
  int get paidTotal        =>
      invoices.where((i) => i.isPaid).fold(0, (s, i) => s + i.amountXaf);
  int get outstandingTotal => invoices
      .where((i) => i.isPending || i.isOverdue)
      .fold(0, (s, i) => s + i.amountXaf);
  int get overdueCount     => invoices.where((i) => i.isOverdue).length;

  // ── Demandes de changement de plan ──
  /// Vrai si une demande est encore en cours (open / in_progress) — utilisé
  /// pour bloquer une seconde demande et informer l'utilisateur.
  bool get hasPendingRequest =>
      tickets.any((t) => t.status == 'open' || t.status == 'in_progress');

  /// La plus récente demande encore active (sinon null).
  SubscriptionTicket? get pendingRequest {
    for (final t in tickets) {
      if (t.status == 'open' || t.status == 'in_progress') return t;
    }
    return null;
  }

  /// Toutes les familles de modules connues (union de tous les plans),
  /// triées par display_order — sert d'axe à la matrice comparative.
  List<PlanCategory> get allCategories {
    final byId = <String, PlanCategory>{};
    for (final p in plans) {
      for (final c in p.categories) {
        final existing = byId[c.categoryId];
        if (existing == null || c.moduleCount > existing.moduleCount) {
          byId[c.categoryId] = c;
        }
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  static const empty = AdminSubscriptionData(
      subscription: null, plans: [], tickets: [], invoices: []);
}

// ─── Provider ────────────────────────────────────────────────────────────────
final adminSubscriptionProvider =
    FutureProvider.autoDispose<AdminSubscriptionData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminSubscriptionData.empty;

  // Realtime : groupe + tickets
  Timer? debounce;
  void onChange(_) {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('admin_subscription_$groupId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'school_groups',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'id', value: groupId),
      callback: onChange,
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_tickets',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      callback: onChange,
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'group_invoices',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      callback: onChange,
    );
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Groupe + plan courant
  GroupSubscription? sub;
  try {
    final g = await client
        .from('school_groups')
        .select('name, plan_id, subscription_status, subscription_start, subscription_end, '
            'subscription_plans!plan_id(id, name, slug, price_xaf, max_schools, max_students, max_staff, module_count, description)')
        .eq('id', groupId)
        .maybeSingle();

    // Compteurs d'usage
    int schoolsUsed = 0, studentsUsed = 0, staffUsed = 0;
    try {
      final s = await client.from('schools').select('id')
          .eq('group_id', groupId).eq('is_active', true) as List;
      schoolsUsed = s.length;
    } catch (_) {}
    try {
      final s = await client.from('students').select('id')
          .eq('group_id', groupId).eq('is_active', true) as List;
      studentsUsed = s.length;
    } catch (_) {}
    try {
      final s = await client.from('staff_members').select('id')
          .eq('group_id', groupId).eq('is_active', true) as List;
      staffUsed = s.length;
    } catch (_) {}

    if (g != null) {
      final plan = g['subscription_plans'] as Map<String, dynamic>?;
      sub = GroupSubscription(
        groupName:    g['name'] as String? ?? '—',
        planId:       g['plan_id'] as String?,
        planName:     plan?['name'] as String? ?? '—',
        planSlug:     plan?['slug'] as String? ?? '',
        priceXaf:     (plan?['price_xaf'] as int?) ?? 0,
        status:       g['subscription_status'] as String? ?? 'trial',
        start:        DateTime.tryParse(g['subscription_start'] as String? ?? ''),
        end:          DateTime.tryParse(g['subscription_end'] as String? ?? ''),
        maxSchools:   (plan?['max_schools'] as int?) ?? 0,
        maxStudents:  (plan?['max_students'] as int?) ?? 0,
        maxStaff:     (plan?['max_staff'] as int?) ?? 0,
        moduleCount:  (plan?['module_count'] as int?) ?? 0,
        description:  plan?['description'] as String?,
        schoolsUsed:  schoolsUsed,
        studentsUsed: studentsUsed,
        staffUsed:    staffUsed,
      );
    }
  } catch (_) {}

  // Familles de modules débloquées par plan : plan_modules ⋈ modules ⋈ module_categories.
  // Lecture seule (RLS subscription_plans_read = true ; modules/catégories publics).
  // Map<planId, Map<categoryId, PlanCategory>>
  final Map<String, Map<String, PlanCategory>> catsByPlan = {};
  try {
    final rows = await client.from('plan_modules')
        .select('plan_id, modules!inner(id, is_active, module_categories!inner(id, name, slug, display_order))')
        as List;
    for (final r in rows) {
      final planId = r['plan_id'] as String?;
      final mod = r['modules'] as Map<String, dynamic>?;
      if (planId == null || mod == null) continue;
      if (mod['is_active'] == false) continue;
      final cat = mod['module_categories'] as Map<String, dynamic>?;
      if (cat == null) continue;
      final catId = cat['id'] as String?;
      if (catId == null) continue;
      final bucket = catsByPlan.putIfAbsent(planId, () => {});
      final prev = bucket[catId];
      bucket[catId] = PlanCategory(
        categoryId:   catId,
        name:         cat['name'] as String? ?? '—',
        slug:         cat['slug'] as String? ?? '',
        displayOrder: (cat['display_order'] as int?) ?? 0,
        moduleCount:  (prev?.moduleCount ?? 0) + 1,
      );
    }
  } catch (_) {}

  // TOUS les plans actifs (un groupe peut demander à monter OU descendre de plan),
  // triés par prix croissant pour une comparaison lisible.
  final List<PlanOption> plans = [];
  try {
    final rows = await client.from('subscription_plans')
        .select('id, name, slug, price_xaf, max_schools, max_students, max_staff, module_count, description, is_active')
        .eq('is_active', true)
        .order('price_xaf') as List;
    for (final r in rows) {
      final id = r['id'] as String;
      final cats = (catsByPlan[id]?.values.toList() ?? <PlanCategory>[])
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      plans.add(PlanOption(
        id:          id,
        name:        r['name'] as String? ?? '—',
        slug:        r['slug'] as String? ?? '',
        priceXaf:    (r['price_xaf'] as int?) ?? 0,
        maxSchools:  (r['max_schools'] as int?) ?? 0,
        maxStudents: (r['max_students'] as int?) ?? 0,
        maxStaff:    (r['max_staff'] as int?) ?? 0,
        moduleCount: (r['module_count'] as int?) ?? 0,
        description: r['description'] as String?,
        categories:  cats,
      ));
    }
  } catch (_) {}

  // Historique des demandes (tickets de changement de plan)
  final List<SubscriptionTicket> tickets = [];
  try {
    final rows = await client.from('support_tickets')
        .select('id, subject, body, status, priority, response, created_at, resolved_at')
        .eq('group_id', groupId)
        .eq('category', 'changement_plan')
        .order('created_at', ascending: false)
        .limit(10) as List;
    for (final r in rows) {
      tickets.add(SubscriptionTicket(
        id:         r['id'] as String,
        subject:    r['subject'] as String? ?? '—',
        body:       r['body'] as String?,
        status:     r['status'] as String? ?? 'open',
        priority:   r['priority'] as String? ?? 'medium',
        response:   r['response'] as String?,
        createdAt:  DateTime.tryParse(r['created_at'] as String? ?? ''),
        resolvedAt: DateTime.tryParse(r['resolved_at'] as String? ?? ''),
      ));
    }
  } catch (_) {}

  // Historique de facturation du groupe (RLS invoices_select → lecture seule)
  final List<InvoiceDetail> invoices = [];
  try {
    final rows = await client.from('group_invoices')
        .select('*, school_groups(name), subscription_plans(name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false) as List;
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      m['group_name'] = (r['school_groups'] as Map?)?['name'];
      m['plan_name']  = (r['subscription_plans'] as Map?)?['name'];
      invoices.add(InvoiceDetail.fromMap(m));
    }
  } catch (_) {}

  return AdminSubscriptionData(
      subscription: sub, plans: plans, tickets: tickets, invoices: invoices);
});

// ─── Service ────────────────────────────────────────────────────────────────
class AdminSubscriptionService {
  AdminSubscriptionService(this._ref);
  final Ref _ref;

  /// Crée un ticket de support `category='changement_plan'` pour demander un
  /// nouveau plan. L'admin de groupe ne modifie PAS `school_groups.plan_id`
  /// lui-même (réservé au super_admin) : il dépose une demande.
  Future<void> requestPlanChange({
    required String targetPlanName,
    required String message,
  }) async {
    final client  = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    final uid     = client.auth.currentUser?.id;
    if (groupId == null || uid == null) throw Exception('Session invalide');

    // Garde-fou : empêche une seconde demande tant qu'une est en cours.
    final pending = _ref.read(adminSubscriptionProvider).valueOrNull;
    if (pending != null && pending.hasPendingRequest) {
      throw Exception('Une demande est déjà en cours de traitement.');
    }

    final body = message.trim().isEmpty
        ? 'Demande de passage au plan $targetPlanName.'
        : '$message\n\n— Plan visé : $targetPlanName';

    await client.from('support_tickets').insert({
      'group_id': groupId,
      'submitted_by': uid,
      'subject': 'Demande de changement de plan vers $targetPlanName',
      'body': body,
      'category': 'changement_plan',
      'priority': 'medium',
      'status': 'open',
    });
    _ref.invalidate(adminSubscriptionProvider);
  }

  /// Réabonnement au MÊME plan : génère (ou récupère) une facture de
  /// renouvellement via `create_renewal_invoice` (SECURITY DEFINER, gère
  /// l'autorisation et l'idempotence côté base). Renvoie le résultat brut :
  ///   { created:true, invoice_number, amount_xaf, period_start, period_end }
  ///   { already_pending:true, ... }  — une facture impayée existait déjà
  ///   { free:true, period_end }      — plan gratuit, prolongé directement
  /// Le paiement lui-même reste confirmé par la plateforme (mark_invoice_paid).
  Future<Map<String, dynamic>> requestRenewal() async {
    final client  = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) throw Exception('Session invalide');

    final res = await client.rpc('create_renewal_invoice',
        params: {'p_group_id': groupId});
    _ref.invalidate(adminSubscriptionProvider);
    return (res is Map)
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{'success': true};
  }
}

final adminSubscriptionServiceProvider =
    Provider<AdminSubscriptionService>((ref) => AdminSubscriptionService(ref));
