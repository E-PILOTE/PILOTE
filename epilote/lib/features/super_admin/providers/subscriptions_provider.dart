import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle SubscriptionDetail (un groupe scolaire = un abonnement) ───────────

class SubscriptionDetail {
  const SubscriptionDetail({
    required this.id,
    required this.groupName,
    required this.adminEmail,
    required this.groupType,
    required this.status,
    required this.priceXaf,
    required this.schoolsCount,
    required this.createdAt,
    required this.updatedAt,
    this.groupLogo,
    this.phone,
    this.department,
    this.planId,
    this.planName,
    this.planSlug,
    this.start,
    this.end,
  });

  factory SubscriptionDetail.fromMap(
    Map<String, dynamic> m, {
    int schoolsCount = 0,
  }) {
    final plan = m['plan'];
    final planMap = plan is Map ? Map<String, dynamic>.from(plan) : const {};
    return SubscriptionDetail(
      id:          m['id']            as String,
      groupName:   m['name']          as String? ?? '',
      groupLogo:   m['logo_url']      as String?,
      adminEmail:  m['admin_email']   as String? ?? '',
      phone:       m['phone']         as String?,
      groupType:   m['group_type']    as String? ?? 'prive',
      department:  m['department']    as String?,
      planId:      m['plan_id']       as String?,
      planName:    planMap['name']    as String?,
      planSlug:    planMap['slug']    as String?,
      priceXaf:    (planMap['price_xaf'] as num?)?.toInt() ?? 0,
      status:      m['subscription_status'] as String? ?? 'trial',
      start:       _date(m['subscription_start']),
      end:         _date(m['subscription_end']),
      schoolsCount: schoolsCount,
      createdAt:   DateTime.parse(m['created_at'] as String),
      updatedAt:   DateTime.parse(m['updated_at'] as String),
    );
  }

  final String  id, groupName, adminEmail, groupType, status;
  final String? groupLogo, phone, department, planId, planName, planSlug;
  final int     priceXaf, schoolsCount;
  final DateTime  createdAt, updatedAt;
  final DateTime? start, end;

  bool get isActive => status == 'active';
  bool get isTrial  => status == 'trial';

  String get statusLabel => switch (status) {
    'trial'     => 'Essai',
    'active'    => 'Actif',
    'suspended' => 'Suspendu',
    'expired'   => 'Expiré',
    'cancelled' => 'Annulé',
    _           => status,
  };

  String get groupTypeLabel => groupType == 'public' ? 'Public' : 'Privé';

  /// Jours restants avant la fin de l'abonnement (null si pas de date de fin).
  int? get daysRemaining {
    if (end == null) return null;
    return end!.difference(DateTime.now()).inDays;
  }

  /// Abonnement payant qui expire dans 30 jours ou moins (et pas déjà expiré).
  bool get isExpiringSoon {
    final d = daysRemaining;
    return d != null && d >= 0 && d <= 30 && isActive;
  }

  bool get isOverdue {
    final d = daysRemaining;
    return d != null && d < 0 && status != 'cancelled';
  }

  String get remainingLabel {
    final d = daysRemaining;
    if (d == null) return '—';
    if (d < 0) return 'Expiré depuis ${-d} j';
    if (d == 0) return "Expire aujourd'hui";
    if (d < 30) return '$d jours restants';
    if (d < 365) return '${(d / 30).round()} mois restants';
    return '${(d / 365).round()} an(s) restant(s)';
  }

  String get initials {
    final n = groupName.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v as String);
}

// ─── Modèle PlanOption (sélecteur de plan dans le formulaire) ─────────────────

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.priceXaf,
  });
  final String id, name;
  final int    priceXaf;
}

// ─── Modèle données globales ───────────────────────────────────────────────────

class SubscriptionsData {
  const SubscriptionsData({
    required this.subscriptions,
    required this.plans,
    required this.total,
    required this.actifs,
    required this.trials,
    required this.inactifs,
    required this.expiringSoon,
    required this.mrr,
  });

  final List<SubscriptionDetail> subscriptions;
  final List<PlanOption>         plans;
  final int total, actifs, trials, inactifs, expiringSoon, mrr;

  static const empty = SubscriptionsData(
    subscriptions: [], plans: [], total: 0, actifs: 0,
    trials: 0, inactifs: 0, expiringSoon: 0, mrr: 0,
  );
}

// ─── Provider principal ─────────────────────────────────────────────────────────

final subscriptionsProvider =
    FutureProvider.autoDispose<SubscriptionsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('platform_subscriptions_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'school_groups',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // ── Nombre d'écoles par groupe ──────────────────────────────────────────────
  final Map<String, int> schoolsByGroup = {};
  try {
    final rows = await client.from('schools').select('group_id') as List;
    for (final r in rows) {
      final gid = (r as Map)['group_id'] as String?;
      if (gid != null) schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
    }
  } catch (_) {}

  // ── Abonnements (groupes + plan joint) ──────────────────────────────────────
  List<SubscriptionDetail> subs = [];
  try {
    final rows = await client
        .from('school_groups')
        .select('id, name, logo_url, admin_email, phone, group_type, '
            'department, plan_id, subscription_status, subscription_start, '
            'subscription_end, created_at, updated_at, '
            'plan:subscription_plans(name, slug, price_xaf)')
        .order('created_at', ascending: false) as List;
    subs = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return SubscriptionDetail.fromMap(
        m,
        schoolsCount: schoolsByGroup[m['id']] ?? 0,
      );
    }).toList();
  } catch (_) {}

  // ── Plans disponibles (pour changer de plan) ────────────────────────────────
  List<PlanOption> plans = [];
  try {
    final rows = await client
        .from('subscription_plans')
        .select('id, name, price_xaf')
        .eq('is_active', true)
        .order('price_xaf') as List;
    plans = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return PlanOption(
        id:       m['id']   as String,
        name:     m['name'] as String? ?? '',
        priceXaf: (m['price_xaf'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int actifs = 0, trials = 0, inactifs = 0, expiringSoon = 0, mrr = 0;
  for (final s in subs) {
    if (s.isActive) {
      actifs++;
      mrr += s.priceXaf;
    } else if (s.isTrial) {
      trials++;
    } else {
      inactifs++;
    }
    if (s.isExpiringSoon) expiringSoon++;
  }

  return SubscriptionsData(
    subscriptions: subs,
    plans:         plans,
    total:         subs.length,
    actifs:        actifs,
    trials:        trials,
    inactifs:      inactifs,
    expiringSoon:  expiringSoon,
    mrr:           mrr,
  );
});
