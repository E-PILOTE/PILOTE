import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle GroupDetail ───────────────────────────────────────────────────────

class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    required this.groupType,
    required this.subscriptionStatus,
    required this.adminEmail,
    required this.planId,
    required this.planName,
    required this.priceXaf,
    required this.maxSchools,
    required this.maxStudents,
    required this.isActive,
    required this.schoolCount,
    required this.createdAt,
    required this.updatedAt,
    this.slug,
    this.department,
    this.phone,
    this.address,
    this.logoUrl,
    this.notes,
    this.subscriptionStart,
    this.subscriptionEnd,
    this.foundedYear,
  });

  factory GroupDetail.fromMap(Map<String, dynamic> m, int schoolCount) {
    final plan = m['subscription_plans'] as Map<String, dynamic>?;
    return GroupDetail(
      id:                 m['id']                  as String,
      name:               m['name']                as String,
      slug:               m['slug']                as String?,
      groupType:          m['group_type']           as String? ?? 'prive',
      department:         m['department']           as String?,
      planId:             m['plan_id']              as String,
      planName:           plan?['name']             as String? ?? '—',
      priceXaf:           (plan?['price_xaf']       as int?)   ?? 0,
      maxSchools:         (plan?['max_schools']     as int?)   ?? 1,
      maxStudents:        (plan?['max_students']    as int?)   ?? 100,
      subscriptionStatus: m['subscription_status']  as String? ?? 'trial',
      subscriptionStart: m['subscription_start'] != null
          ? DateTime.tryParse(m['subscription_start'] as String)
          : null,
      subscriptionEnd: m['subscription_end'] != null
          ? DateTime.tryParse(m['subscription_end'] as String)
          : null,
      adminEmail: m['admin_email'] as String,
      phone:      m['phone']       as String?,
      address:    m['address']     as String?,
      logoUrl:    m['logo_url']    as String?,
      isActive:    m['is_active']    as bool? ?? true,
      notes:       m['notes']        as String?,
      foundedYear: m['founded_year'] as int?,
      schoolCount: schoolCount,
      createdAt:   DateTime.parse(m['created_at'] as String),
      updatedAt:   DateTime.parse(m['updated_at'] as String),
    );
  }

  final String  id, name, groupType, subscriptionStatus, adminEmail;
  final String  planId, planName;
  final String? slug, department, phone, address, logoUrl, notes;
  final int     priceXaf, maxSchools, maxStudents, schoolCount;
  final int?    foundedYear;
  final bool    isActive;
  final DateTime  createdAt, updatedAt;
  final DateTime? subscriptionStart, subscriptionEnd;

  bool get isActif     => subscriptionStatus == 'active';
  bool get isEssai     => subscriptionStatus == 'trial';
  bool get isSuspendu  => subscriptionStatus == 'suspended';
  bool get isCancelled => subscriptionStatus == 'cancelled';

  bool get expiresBientot {
    if (subscriptionEnd == null || !isActif) return false;
    return subscriptionEnd!.difference(DateTime.now()).inDays <= 30 &&
        subscriptionEnd!.isAfter(DateTime.now());
  }

  String get groupTypeLabel => switch (groupType) {
    'public'      => 'Public',
    'prive'       => 'Privé',
    'catholique'  => 'Catholique',
    'islamique'   => 'Islamique',
    'protestant'  => 'Protestant',
    _             => groupType,
  };

  String get statusLabel => switch (subscriptionStatus) {
    'active'    => 'Actif',
    'trial'     => 'Essai',
    'suspended' => 'Suspendu',
    'cancelled' => 'Résilié',
    _           => subscriptionStatus,
  };

  GroupDetail copyWith({
    String? name, String? groupType, String? department, String? adminEmail,
    String? phone, String? address, String? planId, String? planName,
    int? priceXaf, int? maxSchools, int? maxStudents, String? notes,
    bool? isActive, String? subscriptionStatus,
  }) => GroupDetail(
    id: id, slug: slug, createdAt: createdAt, updatedAt: DateTime.now(),
    logoUrl: logoUrl, schoolCount: schoolCount,
    subscriptionStart: subscriptionStart, subscriptionEnd: subscriptionEnd,
    name:               name               ?? this.name,
    groupType:          groupType          ?? this.groupType,
    department:         department         ?? this.department,
    adminEmail:         adminEmail         ?? this.adminEmail,
    phone:              phone              ?? this.phone,
    address:            address            ?? this.address,
    planId:             planId             ?? this.planId,
    planName:           planName           ?? this.planName,
    priceXaf:           priceXaf           ?? this.priceXaf,
    maxSchools:         maxSchools         ?? this.maxSchools,
    maxStudents:        maxStudents        ?? this.maxStudents,
    notes:              notes              ?? this.notes,
    isActive:           isActive           ?? this.isActive,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
  );
}

// ─── Modèle PlanInfo ──────────────────────────────────────────────────────────

class PlanInfo {
  const PlanInfo({
    required this.id,
    required this.name,
    required this.priceXaf,
    required this.maxSchools,
    required this.maxStudents,
  });
  final String id, name;
  final int priceXaf, maxSchools, maxStudents;
}

// ─── Modèle données globales ──────────────────────────────────────────────────

class SchoolGroupsData {
  const SchoolGroupsData({
    required this.groups,
    required this.plans,
    required this.total,
    required this.actifs,
    required this.enEssai,
    required this.suspendus,
    required this.revenusTotal,
    required this.expirantBientot,
    required this.departments,
  });

  final List<GroupDetail> groups;
  final List<PlanInfo>    plans;
  final int    total, actifs, enEssai, suspendus, expirantBientot;
  final double revenusTotal;
  final List<String> departments;

  static const empty = SchoolGroupsData(
    groups: [], plans: [], total: 0, actifs: 0, enEssai: 0,
    suspendus: 0, revenusTotal: 0, expirantBientot: 0, departments: [],
  );
}

// ─── Provider principal ───────────────────────────────────────────────────────

final schoolGroupsProvider =
    FutureProvider.autoDispose<SchoolGroupsData>((ref) async {
  // Garder les données en mémoire entre navigations.
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime : invalidation silencieuse sur changement (hors try/catch)
  Timer? debounce;
  try {
    final channel = client.channel('school_groups_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'school_groups',
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
          },
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {
    // Realtime non disponible (token expiré ou hors ligne) → on continue quand même
  }

  // ── Plans d'abonnement ────────────────────────────────────────────────────
  List<PlanInfo> plans = [];
  try {
    final rows = await client
        .from('subscription_plans')
        .select('id, name, price_xaf, max_schools, max_students')
        .eq('is_active', true)
        .order('price_xaf') as List;
    plans = rows.map((r) => PlanInfo(
      id:          r['id']           as String,
      name:        r['name']         as String,
      priceXaf:    (r['price_xaf']   as int?) ?? 0,
      maxSchools:  (r['max_schools'] as int?) ?? 1,
      maxStudents: (r['max_students'] as int?) ?? 100,
    )).toList();
  } catch (_) {}

  // ── Nombre d'écoles par groupe ────────────────────────────────────────────
  final Map<String, int> schoolsByGroup = {};
  try {
    final schools = await client.from('schools').select('id, group_id') as List;
    for (final s in schools) {
      final gid = s['group_id'] as String? ?? '';
      schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
    }
  } catch (_) {}

  // ── Groupes scolaires ─────────────────────────────────────────────────────
  List<GroupDetail> groups = [];
  try {
    final rows = await client.from('school_groups').select(
      'id, name, slug, group_type, department, plan_id, subscription_status, '
      'subscription_start, subscription_end, admin_email, phone, address, '
      'logo_url, is_active, notes, founded_year, created_at, updated_at, '
      'subscription_plans!plan_id(name, price_xaf, max_schools, max_students)',
    ).order('created_at', ascending: false) as List;

    groups = rows.map((r) =>
        GroupDetail.fromMap(r, schoolsByGroup[r['id'] as String? ?? ''] ?? 0)
    ).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int    actifs    = 0;
  int    enEssai   = 0;
  int    suspendus = 0;
  int    expirant  = 0;
  double revenus   = 0;

  for (final g in groups) {
    if (g.isActif)     { actifs++;    revenus += g.priceXaf; }
    if (g.isEssai)       enEssai++;
    if (g.isSuspendu)    suspendus++;
    if (g.expiresBientot) expirant++;
  }

  // Départements uniques triés
  final depts = groups
      .map((g) => g.department ?? '')
      .where((d) => d.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  return SchoolGroupsData(
    groups:          groups,
    plans:           plans,
    total:           groups.length,
    actifs:          actifs,
    enEssai:         enEssai,
    suspendus:       suspendus,
    revenusTotal:    revenus,
    expirantBientot: expirant,
    departments:     depts,
  );
});

// ─── Module Access per group ───────────────────────────────────────────────────

class GroupModuleAccess {
  const GroupModuleAccess({
    required this.moduleId,
    required this.moduleName,
    required this.categoryName,
    required this.isAccessible,
    this.icon,
    this.accessReason,
  });
  final String  moduleId;
  final String  moduleName;
  final String  categoryName;
  final bool    isAccessible;
  final String? icon;
  final String? accessReason;
}

final groupModuleAccessProvider = FutureProvider.autoDispose
    .family<List<GroupModuleAccess>, String>((ref, groupId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.rpc('get_group_module_access',
      params: {'p_group_id': groupId});
  return (rows as List).map((r) {
    final m = r as Map;
    return GroupModuleAccess(
      moduleId:     m['module_id']     as String,
      moduleName:   m['module_name']   as String? ?? '?',
      categoryName: m['category_name'] as String? ?? '?',
      isAccessible: m['is_accessible'] as bool? ?? false,
      icon:         m['module_icon']   as String?,
      accessReason: m['access_reason'] as String?,
    );
  }).toList();
});
