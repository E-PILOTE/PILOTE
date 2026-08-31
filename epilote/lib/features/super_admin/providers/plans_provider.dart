import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../core/utils/billing_period.dart';
import '../../../core/utils/plan_referential_realtime.dart';
import '../../../core/utils/tarif_ecoles.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle PlanDetail ─────────────────────────────────────────────────────────

class PlanDetail {
  const PlanDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceXaf,
    required this.maxSchools,
    required this.maxStudents,
    required this.maxStaff,
    required this.moduleCount,
    required this.isPublicPlan,
    required this.isActive,
    required this.linkedModules,
    required this.subscribersTotal,
    required this.subscribersActive,
    required this.createdAt,
    required this.updatedAt,
    this.billingPeriod = kDefaultBillingPeriod,
    this.description,
    this.extra2a5 = 0,
    this.extra6a10 = 0,
    this.extra11a20 = 0,
    this.extra21p = 0,
    this.activeMonthlyRevenue = 0,
  });

  factory PlanDetail.fromMap(
    Map<String, dynamic> m, {
    int linkedModules = 0,
    int subscribersTotal = 0,
    int subscribersActive = 0,
    int activeMonthlyRevenue = 0,
  }) =>
      PlanDetail(
        id:           m['id']             as String,
        name:         m['name']           as String? ?? '',
        slug:         m['slug']           as String? ?? '',
        priceXaf:     (m['price_xaf']     as num?)?.toInt() ?? 0,
        maxSchools:   (m['max_schools']   as num?)?.toInt() ?? 0,
        maxStudents:  (m['max_students']  as num?)?.toInt() ?? 0,
        maxStaff:     (m['max_staff']     as num?)?.toInt() ?? 0,
        moduleCount:  (m['module_count']  as num?)?.toInt() ?? 0,
        billingPeriod: m['billing_period'] as String? ?? kDefaultBillingPeriod,
        description:  m['description']    as String?,
        isPublicPlan: m['is_public_plan'] as bool? ?? false,
        isActive:     m['is_active']      as bool? ?? true,
        extra2a5:     (m['extra_school_2_5_xaf']   as num?)?.toInt() ?? 0,
        extra6a10:    (m['extra_school_6_10_xaf']  as num?)?.toInt() ?? 0,
        extra11a20:   (m['extra_school_11_20_xaf'] as num?)?.toInt() ?? 0,
        extra21p:     (m['extra_school_21p_xaf']   as num?)?.toInt() ?? 0,
        linkedModules:     linkedModules,
        subscribersTotal:  subscribersTotal,
        subscribersActive: subscribersActive,
        activeMonthlyRevenue: activeMonthlyRevenue,
        createdAt:    DateTime.parse(m['created_at'] as String),
        updatedAt:    DateTime.parse(m['updated_at'] as String),
      );

  final String  id, name, slug;
  final String? description;
  final int     priceXaf, maxSchools, maxStudents, maxStaff, moduleCount;
  final int     linkedModules, subscribersTotal, subscribersActive;

  /// Tranches dégressives — miroir des colonnes `extra_school_*_xaf` (0159).
  final int     extra2a5, extra6a10, extra11a20, extra21p;

  /// Somme des tarifs MENSUELS réellement dus par les groupes actifs de ce
  /// plan, chacun calculé sur SON nombre d'écoles (ou son tarif négocié).
  final int     activeMonthlyRevenue;
  final bool    isPublicPlan, isActive;
  final String  billingPeriod;
  final DateTime createdAt, updatedAt;

  bool get isFree    => priceXaf <= 0;
  bool get unlimited => maxSchools < 0;

  /// Nombre de mois couverts par `priceXaf`.
  int get billingMonths => billingPeriodMonths(billingPeriod);

  /// Libellé de la périodicité : « Annuel ».
  String get periodLabel => billingPeriodLabel(billingPeriod);

  /// Tarif ramené au mois — indispensable pour additionner des plans de
  /// périodicités différentes.
  int get monthlyPrice => monthlyEquivalent(priceXaf, billingPeriod);

  /// Revenu mensuel récurrent généré par les groupes actifs sur ce plan.
  ///
  /// ⚠️ C'est bien le tarif RAMENÉ AU MOIS qui compte : un plan à 2 500 000
  /// FCFA par AN pèse 208 333 FCFA de MRR, pas 2 500 000. L'ancien calcul
  /// multipliait le revenu de la plateforme par douze.
  ///
  /// ⚠️ Depuis 0159 il ne peut PLUS s'écrire `monthlyPrice × abonnés` : deux
  /// groupes du même plan ne paient plus le même montant. Un réseau de douze
  /// écoles pèse quatre fois un groupe mono-école — l'ancienne formule aurait
  /// sous-estimé le revenu de la plateforme sans qu'aucun écran ne s'en plaigne.
  int get monthlyRevenue => activeMonthlyRevenue;

  /// Le tarif de ce plan pour [ecoles] écoles. Miroir de `plan_price_xaf()`.
  int priceFor(int ecoles) => tarifPourEcoles(
        base: priceXaf,
        tranche2a5: extra2a5,
        tranche6a10: extra6a10,
        tranche11a20: extra11a20,
        tranche21p: extra21p,
        ecoles: ecoles,
      );

  /// Vrai si le plan facture les écoles supplémentaires.
  bool get parEcole => extra2a5 > 0 || extra6a10 > 0 || extra11a20 > 0 || extra21p > 0;

  /// Tarif AVEC sa période — « à partir de 30 000 FCFA / mois ». Le « à partir
  /// de » n'est pas de la prudence commerciale : sans lui, le montant affiché
  /// est faux pour tout groupe de plus d'une école.
  String get priceLabel => isFree
      ? 'Gratuit'
      : '${parEcole ? 'dès ' : ''}${_money(priceXaf)} FCFA / '
          '${billingPeriodSuffix(billingPeriod)}';

  /// Tarif SEUL — pour un tableau qui possède déjà une colonne « Périodicité ».
  /// Répéter le suffixe y tronquait le montant.
  String get priceAmountLabel =>
      isFree ? 'Gratuit' : '${parEcole ? 'dès ' : ''}${_money(priceXaf)} FCFA';

  /// « +10 000 / école » — la seule ligne qui rende la grille lisible.
  String get parEcoleLabel =>
      parEcole ? '+${_money(extra2a5)} FCFA / école' : '—';
  String get maxSchoolsLabel  => quotaLabel(maxSchools);
  String get maxStudentsLabel => quotaLabel(maxStudents);
  String get maxStaffLabel    => quotaLabel(maxStaff);

  String get initials {
    final n = name.trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }
}

// ─── Modèle ModulePick (pour la sélection des modules du plan) ────────────────

class ModulePick {
  const ModulePick({
    required this.id,
    required this.name,
    required this.categoryName,
    this.icon,
  });
  final String  id, name, categoryName;
  final String? icon;
}

// ─── Modèle données globales ───────────────────────────────────────────────────

class PlansData {
  const PlansData({
    required this.plans,
    required this.modules,
    required this.total,
    required this.actifs,
    required this.publics,
    required this.subscribers,
    required this.mrr,
    required this.avgPrice,
  });

  final List<PlanDetail> plans;
  final List<ModulePick> modules;
  final int total, actifs, publics, subscribers, mrr, avgPrice;

  static const empty = PlansData(
    plans: [], modules: [], total: 0, actifs: 0,
    publics: 0, subscribers: 0, mrr: 0, avgPrice: 0,
  );
}

// ─── Helper de formatage monétaire ─────────────────────────────────────────────

String _money(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

String moneyXaf(int v) => _money(v);

// ─── Quotas : la convention « -1 = illimité » ─────────────────────────────────
//
// `check_quota()` en base traite `-1` comme « pas de plafond », pour les trois
// quotas. Le formulaire ne l'annonçait que sur les écoles, et rien n'empêchait
// de saisir `-5` — qui aurait bloqué toute création dès la première ligne, sans
// message compréhensible. Ces deux fonctions tiennent la convention d'un seul
// endroit, côté affichage comme côté saisie.

/// Étiquette d'un quota : `-1` (ou tout négatif) → « Illimité ».
String quotaLabel(int v) => v < 0 ? 'Illimité' : _money(v);

/// Valide la saisie d'un quota. `null` = valeur acceptable.
String? validatePlanQuota(String? raw) {
  final n = int.tryParse((raw ?? '').trim().replaceAll(' ', ''));
  if (n == null) return 'Nombre requis';
  if (n < -1) return '-1 (illimité) ou ≥ 0';
  return null;
}

// ─── Provider principal ─────────────────────────────────────────────────────────

final plansProvider = FutureProvider.autoDispose<PlansData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime : invalidation silencieuse
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('platform_plans_list')
        .watchPlanReferential(scheduleInvalidate)
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

  // ── Liens plan_modules (comptage par plan) ──────────────────────────────────
  final Map<String, int> modulesByPlan = {};
  try {
    final rows = await client.from('plan_modules').select('plan_id') as List;
    for (final r in rows) {
      final pid = (r as Map)['plan_id'] as String?;
      if (pid != null) modulesByPlan[pid] = (modulesByPlan[pid] ?? 0) + 1;
    }
  } catch (_) {}

  // ── Groupes abonnés par plan (total + actifs) ───────────────────────────────
  final Map<String, int> subsByPlan = {};
  final Map<String, int> activeSubsByPlan = {};
  // Les groupes ACTIFS, retenus pour le calcul du revenu : depuis 0159 deux
  // groupes du même plan ne paient plus le même montant, il faut donc les
  // parcourir un par un au lieu de multiplier un tarif par un effectif.
  final Map<String, List<Map<String, dynamic>>> activeGroupsByPlan = {};
  try {
    final rows = await client
        .from('school_groups')
        .select('plan_id, subscription_status, price_override_xaf, billed_schools')
        as List;
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      final pid = m['plan_id'] as String?;
      if (pid == null) continue;
      subsByPlan[pid] = (subsByPlan[pid] ?? 0) + 1;
      if (m['subscription_status'] == 'active') {
        activeSubsByPlan[pid] = (activeSubsByPlan[pid] ?? 0) + 1;
        activeGroupsByPlan.putIfAbsent(pid, () => []).add(m);
      }
    }
  } catch (_) {}

  // ── Plans ───────────────────────────────────────────────────────────────────
  List<PlanDetail> plans = [];
  try {
    final rows = await client
        .from('subscription_plans')
        .select('id, name, slug, price_xaf, extra_school_2_5_xaf, '
            'extra_school_6_10_xaf, extra_school_11_20_xaf, extra_school_21p_xaf, '
            'max_schools, max_students, '
            'max_staff, module_count, description, is_public_plan, '
            'is_active, billing_period, created_at, updated_at')
        .order('price_xaf', ascending: true) as List;
    plans = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      final periode = m['billing_period'] as String?;
      var revenu = 0;
      for (final g in activeGroupsByPlan[id] ?? const <Map<String, dynamic>>[]) {
        // Un tarif négocié prime sur la grille — c'est sa raison d'être.
        final du = (g['price_override_xaf'] as num?)?.toInt() ??
            tarifPlanRow(m, (g['billed_schools'] as num?)?.toInt() ?? 1);
        revenu += monthlyEquivalent(du, periode);
      }
      return PlanDetail.fromMap(
        m,
        linkedModules:     modulesByPlan[id] ?? 0,
        subscribersTotal:  subsByPlan[id] ?? 0,
        subscribersActive: activeSubsByPlan[id] ?? 0,
        activeMonthlyRevenue: revenu,
      );
    }).toList();
  } catch (_) {}

  // ── Modules disponibles (pour le formulaire) ────────────────────────────────
  List<ModulePick> modules = [];
  try {
    final rows = await client
        .from('modules')
        .select('id, name, icon, category:module_categories(name)')
        .eq('is_active', true)
        .order('display_order', ascending: true) as List;
    modules = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final cat = m['category'];
      final catMap = cat is Map ? Map<String, dynamic>.from(cat) : const {};
      return ModulePick(
        id:           m['id']   as String,
        name:         m['name'] as String? ?? '',
        icon:         m['icon'] as String?,
        categoryName: catMap['name'] as String? ?? '',
      );
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  final actifs       = plans.where((p) => p.isActive).length;
  final publics      = plans.where((p) => p.isPublicPlan).length;
  final subscribers  = subsByPlan.values.fold<int>(0, (a, b) => a + b);
  final mrr          = plans.fold<int>(0, (a, p) => a + p.monthlyRevenue);
  final paidPlans    = plans.where((p) => !p.isFree).toList();
  // Prix moyen ramené au mois : additionner un tarif annuel et un tarif
  // mensuel tels quels ne produirait aucune grandeur interprétable.
  final avgPrice     = paidPlans.isEmpty
      ? 0
      : (paidPlans.fold<int>(0, (a, p) => a + p.monthlyPrice) / paidPlans.length)
          .round();

  return PlansData(
    plans:       plans,
    modules:     modules,
    total:       plans.length,
    actifs:      actifs,
    publics:     publics,
    subscribers: subscribers,
    mrr:         mrr,
    avgPrice:    avgPrice,
  );
});

/// Renvoie les IDs des modules liés à un plan (pour pré-remplir le formulaire).
Future<Set<String>> fetchPlanModuleIds(WidgetRef ref, String planId) async {
  try {
    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('plan_modules')
        .select('module_id')
        .eq('plan_id', planId) as List;
    return rows
        .map((r) => (r as Map)['module_id'] as String)
        .toSet();
  } catch (_) {
    return <String>{};
  }
}
