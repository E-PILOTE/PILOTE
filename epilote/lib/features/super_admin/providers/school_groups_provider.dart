import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../core/constants/caractere_groupe.dart';
import '../../../core/constants/tutelle.dart';
import '../../../core/utils/billing_period.dart';
import '../../../core/utils/booleen_en_ligne.dart';
import '../../../core/utils/plan_referential_realtime.dart';
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
    this.billingPeriod = kDefaultBillingPeriod,
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
    this.tutelle,
    this.caractere,
    this.administreReferentielNational = false,
    this.agrementNumero,
    this.agrementType,
    this.agrementDate,
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
      billingPeriod:
          plan?['billing_period'] as String? ?? kDefaultBillingPeriod,
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
      isActive:    actifEnLigne(m['is_active']),
      notes:       m['notes']        as String?,
      foundedYear: m['founded_year'] as int?,
      tutelle:     m['tutelle']      as String?,
      caractere:   m['caractere']    as String?,
      administreReferentielNational:
          m['administre_referentiel_national'] as bool? ?? false,
      agrementNumero: m['agrement_numero'] as String?,
      agrementType:   m['agrement_type']   as String?,
      agrementDate: m['agrement_date'] == null
          ? null
          : DateTime.tryParse(m['agrement_date'] as String),
      schoolCount: schoolCount,
      createdAt:   DateTime.parse(m['created_at'] as String),
      updatedAt:   DateTime.parse(m['updated_at'] as String),
    );
  }

  final String  id, name, groupType, subscriptionStatus, adminEmail;
  final String  planId, planName;
  final String? slug, department, phone, address, logoUrl, notes;
  final int     priceXaf, maxSchools, maxStudents, schoolCount;
  final String  billingPeriod;

  /// Suffixe de période à accoler au tarif — « an », « mois ».
  String get periodSuffix => billingPeriodSuffix(billingPeriod);
  final int?    foundedYear;

  /// Ministère de tutelle du GROUPE — `mepsa` (enseignement général) ou `metp`
  /// (technique et professionnel). Les écoles en héritent par déclencheur et ne
  /// peuvent pas le contredire : un groupe n'est jamais mixte (migration 0153).
  ///
  /// `null` = groupe créé avant la colonne, ou dont les écoles portaient des
  /// tutelles divergentes au rétro-remplissage. À renseigner, pas à deviner :
  /// un groupe sans ministère ne remonte dans aucun état ministériel.
  final String? tutelle;

  /// Libellé court affichable — délégué au référentiel unique. `null` reste
  /// `null` : ne jamais inventer « MEPSA » par défaut, ce serait ranger
  /// d'office un lycée technique sous le mauvais ministère.
  String? get tutelleLabel => sigleTutelle(tutelle);

  /// Caractère du groupe — `laic`, `catholique`, `protestant`, `islamique`,
  /// `autre` (migration 0180). `null` = NON RENSEIGNÉ, jamais « laïc ».
  ///
  /// ⚠️ À ne pas confondre avec [groupType], qui porte le SECTEUR. Une école
  /// catholique est une école PRIVÉE : les deux informations sont vraies en
  /// même temps et vivent dans deux colonnes.
  final String? caractere;

  /// Libellé du caractère, ou `null` s'il n'est pas renseigné.
  String? get caractereLabel => libelleCaractere(caractere);

  /// VRAI si ce groupe EST le ministère de tutelle de son enseignement.
  ///
  /// ⚠️ Ce booléen (`administre_referentiel_national`, migration 0155) ouvre à
  /// lui seul l'écriture du référentiel national des examens, la lecture de
  /// TOUT le réseau du ministère — écoles qu'il ne possède pas comprises —,
  /// l'émission de circulaires et la vente d'une licence de tutelle. Un seul
  /// groupe peut le porter par ministère : l'index unique partiel
  /// `school_groups_un_seul_par_tutelle` (migration 0178) le garantit.
  final bool administreReferentielNational;

  /// Agrément délivré par la commission du ministère de tutelle.
  ///
  /// ⚠️ ENREGISTRÉ, jamais instruit : la plateforme ne délivre, ne valide ni
  /// n'expire aucun agrément. Ces trois champs sont une mention administrative
  /// — comme un numéro sur un en-tête —, et les écoles du groupe en héritent
  /// par déclencheur (migration 0158).
  final String? agrementNumero, agrementType;
  final DateTime? agrementDate;

  /// ⚠️ « rien de saisi » n'est PAS « pas agréé ». Un groupe parfaitement en
  /// règle peut n'avoir simplement rien renseigné.
  bool get aDeclareUnAgrement => (agrementNumero ?? '').trim().isNotEmpty;

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

  String get groupTypeLabel => libelleSecteur(groupType);

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
    bool? isActive, String? subscriptionStatus, String? tutelle,
  }) => GroupDetail(
    id: id, slug: slug, createdAt: createdAt, updatedAt: DateTime.now(),
    logoUrl: logoUrl, schoolCount: schoolCount,
    subscriptionStart: subscriptionStart, subscriptionEnd: subscriptionEnd,
    foundedYear: foundedYear,
    tutelle:            tutelle            ?? this.tutelle,
    agrementNumero: agrementNumero, agrementType: agrementType,
    agrementDate: agrementDate,
    name:               name               ?? this.name,
    groupType:          groupType          ?? this.groupType,
    department:         department         ?? this.department,
    adminEmail:         adminEmail         ?? this.adminEmail,
    phone:              phone              ?? this.phone,
    address:            address            ?? this.address,
    planId:             planId             ?? this.planId,
    planName:           planName           ?? this.planName,
    priceXaf:           priceXaf           ?? this.priceXaf,
    billingPeriod:      billingPeriod,
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
    this.billingPeriod = kDefaultBillingPeriod,
    required this.maxSchools,
    required this.maxStudents,
  });
  final String id, name;
  final int priceXaf, maxSchools, maxStudents;
  final String billingPeriod;

  String get periodSuffix => billingPeriodSuffix(billingPeriod);
}

// ─── Modèle données globales ──────────────────────────────────────────────────

/// Nom du groupe qui détient déjà le rôle de tutelle pour [tutelle], ou `null`
/// si le rôle est libre. [saufId] exclut le groupe qu'on est en train de
/// modifier — sinon un ministère se verrait reprocher de l'être déjà.
///
/// ⚠️ Sert à DIRE, pas à garantir. La garantie est l'index unique partiel
/// `school_groups_un_seul_par_tutelle` (migration 0178) : deux super_admins qui
/// valident à la même seconde ne peuvent pas passer tous les deux, ce qu'un
/// contrôle côté écran ne saura jamais empêcher. Ici on évite seulement à
/// l'agent de découvrir le conflit en cliquant « Enregistrer ».
String? detenteurDuRoleDeTutelle(
  List<GroupDetail> groupes,
  String? tutelle, {
  String? saufId,
}) {
  if (tutelle == null || tutelle.isEmpty) return null;
  for (final g in groupes) {
    if (g.administreReferentielNational &&
        g.tutelle == tutelle &&
        g.id != saufId) {
      return g.name;
    }
  }
  return null;
}

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
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('school_groups_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'school_groups',
          callback: (_) => scheduleInvalidate(),
        )
        // Chaque carte de groupe affiche le tarif et les quotas de son plan.
        .watchPlanReferential(scheduleInvalidate)
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
        .select('id, name, price_xaf, billing_period, max_schools, max_students')
        .eq('is_active', true)
        .order('price_xaf', ascending: true) as List;
    plans = rows.map((r) => PlanInfo(
      id:          r['id']           as String,
      name:        r['name']         as String,
      priceXaf:    (r['price_xaf']   as int?) ?? 0,
      billingPeriod:
          r['billing_period'] as String? ?? kDefaultBillingPeriod,
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
      'logo_url, is_active, notes, founded_year, tutelle, '
      'administre_referentiel_national, caractere, '
      'agrement_numero, agrement_type, agrement_date, created_at, updated_at, '
      'subscription_plans!plan_id(name, price_xaf, billing_period, max_schools, max_students)',
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
    // Ramené au mois : additionner des tarifs annuels et mensuels bruts ne
    // produit aucune grandeur interprétable (cf. `billing_period.dart`).
    if (g.isActif) {
      actifs++;
      revenus += monthlyEquivalent(g.priceXaf, g.billingPeriod);
    }
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
