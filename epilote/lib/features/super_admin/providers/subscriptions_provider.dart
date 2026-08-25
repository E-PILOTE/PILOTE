import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../core/utils/billing_period.dart';
import '../../../core/utils/plan_referential_realtime.dart';
import '../../../core/utils/subscription_days.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'plans_provider.dart' show moneyXaf;

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
    this.billingPeriod = kDefaultBillingPeriod,
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
      billingPeriod:
          planMap['billing_period'] as String? ?? kDefaultBillingPeriod,
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
  final String  billingPeriod;
  final DateTime  createdAt, updatedAt;
  final DateTime? start, end;

  /// Tarif avec sa période — « 120 000 FCFA / an ». Un montant nu laissait
  /// chaque écran inventer son suffixe : l'espace admin_groupe affichait
  /// « / an » et l'espace plateforme « / mois », sur le MÊME abonnement.
  String get priceLabel => priceXaf == 0
      ? 'Gratuit'
      : '${moneyXaf(priceXaf)} FCFA / ${billingPeriodSuffix(billingPeriod)}';

  /// Contribution mensuelle de cet abonnement au revenu récurrent.
  int get monthlyPrice => monthlyEquivalent(priceXaf, billingPeriod);

  /// Suffixe de période — « an », « mois ».
  String get periodSuffix => billingPeriodSuffix(billingPeriod);

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
  ///
  /// Passe par `daysUntilDate` : `subscription_end` est un DATE (minuit) et
  /// `DateTime.now()` porte l'heure, si bien que la soustraction brute
  /// TRONQUAIT un jour dès que la journée avançait. Cet écran affichait donc
  /// « 21 j » là où le bandeau du groupe annonçait « 22 jours », le même jour.
  int? get daysRemaining => daysUntilDate(end);

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
    this.billingPeriod = kDefaultBillingPeriod,
  });
  final String id, name;
  final int    priceXaf;
  final String billingPeriod;

  String get priceLabel => priceXaf == 0
      ? 'Gratuit'
      : '${moneyXaf(priceXaf)} FCFA / ${billingPeriodSuffix(billingPeriod)}';
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
        // Un changement de tarif ne touche pas `school_groups` : sans ça, la
        // colonne « Montant » garde l'ancien prix toute la session.
        .watchPlanReferential(scheduleInvalidate)
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
            'plan:subscription_plans(name, slug, price_xaf, billing_period)')
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
        .select('id, name, price_xaf, billing_period')
        .eq('is_active', true)
        .order('price_xaf', ascending: true) as List;
    plans = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return PlanOption(
        id:       m['id']   as String,
        name:     m['name'] as String? ?? '',
        priceXaf: (m['price_xaf'] as num?)?.toInt() ?? 0,
        billingPeriod:
            m['billing_period'] as String? ?? kDefaultBillingPeriod,
      );
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int actifs = 0, trials = 0, inactifs = 0, expiringSoon = 0, mrr = 0;
  for (final s in subs) {
    if (s.isActive) {
      actifs++;
      // Ramené au mois : le MRR mélangeait des tarifs annuels et mensuels.
      mrr += s.monthlyPrice;
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
