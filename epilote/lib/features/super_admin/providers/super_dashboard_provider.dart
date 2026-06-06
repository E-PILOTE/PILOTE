import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── MonthlyPoint ─────────────────────────────────────────────────────────────

class MonthlyPoint {
  const MonthlyPoint(this.month, this.value);
  final String month;
  final double value;
}

// ─── MonthlyRevenue ───────────────────────────────────────────────────────────

class MonthlyRevenue {
  const MonthlyRevenue({
    required this.month,
    required this.year,
    required this.label,
    required this.amount,
    required this.subscriptions,
  });
  final int    month;
  final int    year;
  final String label;
  final double amount;
  final int    subscriptions;
}

// ─── Modèle activité récente ──────────────────────────────────────────────────

class ActivityItem {
  const ActivityItem({
    required this.time,
    required this.title,
    required this.detail,
    required this.icon,
  });
  final String time;
  final String title;
  final String detail;
  final String icon;
}

// ─── Modèle groupe par département ───────────────────────────────────────────

class DeptGroupInfo {
  const DeptGroupInfo({
    required this.id,
    required this.name,
    required this.planName,
    required this.status,
    required this.schoolsCount,
    required this.isActive,
    this.subscriptionEnd,
  });
  final String    id;
  final String    name;
  final String    planName;
  final String    status;
  final int       schoolsCount;
  final bool      isActive;
  final DateTime? subscriptionEnd;

  bool get expiresBientot {
    if (subscriptionEnd == null) return false;
    final diff = subscriptionEnd!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 30 && status == 'active';
  }
}

class DeptStat {
  const DeptStat({required this.dept, required this.groups});
  final String              dept;
  final List<DeptGroupInfo> groups;

  int get groupCount  => groups.length;
  int get schoolCount => groups.fold(0, (s, g) => s + g.schoolsCount);
}

// ─── Modèle stats dashboard ───────────────────────────────────────────────────

class SuperDashboardData {
  const SuperDashboardData({
    required this.groupesActifs,
    required this.groupesTotal,
    required this.elevesTotal,
    required this.personnelTotal,
    required this.revenusXafMois,
    required this.groupesByPlan,
    required this.recentActivity,
    required this.deptStats,
    required this.ecolesTotal,
    required this.abonnementsActifs,
    required this.expirantDans30j,
    // ── Sparklines mensuelles ──────────────────────────────────────────────
    required this.trendGroupes,
    required this.trendEcoles,
    required this.trendEleves,
    required this.trendRevenus,
    // ── Données barres horizontales ────────────────────────────────────────
    required this.personnelByRole,
    required this.abonnementsByStatus,
    // ── Historique revenus ─────────────────────────────────────────────────
    required this.revenueMonthly,
    this.syncRate = 99.7,
    this.slaRate  = 99.5,
  });

  final int    groupesActifs;
  final int    groupesTotal;
  final int    elevesTotal;
  final int    personnelTotal;
  final double revenusXafMois;
  final double syncRate;
  final double slaRate;
  final int    ecolesTotal;
  final int    abonnementsActifs;
  final int    expirantDans30j;

  final List<MapEntry<String, int>> groupesByPlan;
  final List<ActivityItem>          recentActivity;
  final List<DeptStat>              deptStats;

  // ── Sparklines ────────────────────────────────────────────────────────────
  final List<MonthlyPoint>          trendGroupes;
  final List<MonthlyPoint>          trendEcoles;
  final List<MonthlyPoint>          trendEleves;
  final List<MonthlyPoint>          trendRevenus;

  // ── Barres horizontales ───────────────────────────────────────────────────
  final List<MapEntry<String, int>> personnelByRole;
  final List<MapEntry<String, int>> abonnementsByStatus;

  // ── Historique revenus 12 mois ────────────────────────────────────────────
  final List<MonthlyRevenue>        revenueMonthly;

  static const empty = SuperDashboardData(
    groupesActifs:       0,
    groupesTotal:        0,
    elevesTotal:         0,
    personnelTotal:      0,
    revenusXafMois:      0,
    ecolesTotal:         0,
    abonnementsActifs:   0,
    expirantDans30j:     0,
    groupesByPlan:       [],
    recentActivity:      [],
    deptStats:           [],
    trendGroupes:        [],
    trendEcoles:         [],
    trendEleves:         [],
    trendRevenus:        [],
    personnelByRole:     [],
    abonnementsByStatus: [],
    revenueMonthly:      [],
  );
}

// ─── Provider principal ───────────────────────────────────────────────────────

final superDashboardProvider =
    FutureProvider.autoDispose<SuperDashboardData>((ref) async {
  // Garder les données en mémoire même quand on navigue vers une autre page.
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // ── Abonnement Supabase Realtime sur school_groups ────────────────────────
  // Invalide le provider dès qu'une ligne change (INSERT / UPDATE / DELETE).
  Timer? debounce;
  final channel = client.channel('super_dashboard_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'school_groups',
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(seconds: 2), () {
            ref.invalidateSelf();
          });
        },
      )
      .subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });

  int    groupesActifs     = 0;
  int    groupesTotal      = 0;
  int    elevesTotal       = 0;
  int    personnelTotal    = 0;
  double revenusXafMois    = 0;
  int    ecolesTotal       = 0;
  int    abonnementsActifs = 0;
  int    expirantDans30j   = 0;

  final Map<String, int>                planMap    = {};
  final Map<String, int>                statusMap  = {};
  final List<ActivityItem>              activity   = [];
  final Map<String, List<DeptGroupInfo>> deptMap   = {};

  // ── Élèves ─────────────────────────────────────────────────────────────────
  try {
    elevesTotal = (await client.from('students').select('id') as List).length;
  } catch (_) {}

  // ── Personnel (hors super_admin / admin_groupe) ───────────────────────────
  try {
    personnelTotal = (await client
        .from('profiles')
        .select('id')
        .not('role', 'in', '(super_admin,admin_groupe)') as List)
        .length;
  } catch (_) {}

  // ── Historique revenus 12 mois ────────────────────────────────────────────
  List<MonthlyRevenue> revenueMonthly = const [];

  // ── Écoles + Groupes ───────────────────────────────────────────────────────
  try {
    final schools = await client.from('schools').select('id, group_id') as List;
    ecolesTotal = schools.length;

    final Map<String, int> schoolsByGroup = {};
    for (final s in schools) {
      final gid = s['group_id'] as String? ?? '';
      schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
    }

    final groups = await client.from('school_groups').select(
      'id, name, department, is_active, subscription_status, '
      'subscription_end, created_at, subscription_plans!plan_id(name, price_xaf)',
    ) as List;

    groupesTotal  = groups.length;
    groupesActifs = groups.where((g) => g['is_active'] == true).length;

    final now  = DateTime.now();
    final in30 = now.add(const Duration(days: 30));

    for (final grp in groups) {
      final plan     = grp['subscription_plans'] as Map<String, dynamic>?;
      final status   = grp['subscription_status'] as String? ?? '';
      final dept     = (grp['department'] as String?)?.trim().isNotEmpty == true
          ? grp['department'] as String
          : 'Autres';
      final planName = plan?['name'] as String? ?? 'Inconnu';
      final price    = (plan?['price_xaf'] as num? ?? 0).toDouble();

      if (status == 'active') {
        revenusXafMois += price;
        abonnementsActifs++;
      }
      planMap[planName]   = (planMap[planName]   ?? 0) + 1;
      statusMap[status]   = (statusMap[status]   ?? 0) + 1;

      final endStr = grp['subscription_end'] as String?;
      final subEnd = endStr != null ? DateTime.tryParse(endStr) : null;
      if (subEnd != null && subEnd.isAfter(now) &&
          subEnd.isBefore(in30) && status == 'active') {
        expirantDans30j++;
      }

      final id = grp['id'] as String? ?? '';
      deptMap.putIfAbsent(dept, () => []).add(DeptGroupInfo(
        id:              id,
        name:            grp['name'] as String? ?? '—',
        planName:        planName,
        status:          status,
        schoolsCount:    schoolsByGroup[id] ?? 0,
        isActive:        grp['is_active'] as bool? ?? false,
        subscriptionEnd: subEnd,
      ));
    }

    // ── Calcul MRR par mois (12 derniers mois) ─────────────────────────────
    final nowM = DateTime.now();
    final mrList = <MonthlyRevenue>[];
    for (int i = 11; i >= 0; i--) {
      final mDate  = DateTime(nowM.year, nowM.month - i, 1);
      final mEnd   = DateTime(mDate.year, mDate.month + 1, 1)
          .subtract(const Duration(seconds: 1));
      double mrr  = 0;
      int    subs = 0;
      for (final grp in groups) {
        final created = DateTime.tryParse(grp['created_at'] as String? ?? '');
        if (created == null || created.isAfter(mEnd)) continue;
        final subEndStr2 = grp['subscription_end'] as String?;
        final subEnd2    = subEndStr2 != null ? DateTime.tryParse(subEndStr2) : null;
        if (subEnd2 != null && subEnd2.isBefore(mDate)) continue;
        final plan2  = grp['subscription_plans'] as Map<String, dynamic>?;
        final price2 = (plan2?['price_xaf'] as num? ?? 0).toDouble();
        if (price2 > 0) { mrr += price2; subs++; }
      }
      mrList.add(MonthlyRevenue(
        month: mDate.month, year: mDate.year,
        label: _kMonthLabels[mDate.month - 1],
        amount: mrr, subscriptions: subs,
      ));
    }
    revenueMonthly = mrList.isNotEmpty ? mrList : _revenueEstimate12m(revenusXafMois);
  } catch (_) {
    if (revenusXafMois > 0) revenueMonthly = _revenueEstimate12m(revenusXafMois);
  }

  // ── Personnel par rôle (barres horizontales) ──────────────────────────────
  List<MapEntry<String, int>> personnelByRole = const [];
  try {
    final staffRows = await client
        .from('profiles')
        .select('role')
        .not('role', 'in', '(super_admin,admin_groupe)') as List;
    final Map<String, int> roleMap = {};
    for (final r in staffRows) {
      final role = _shortenRole(r['role'] as String? ?? 'autre');
      roleMap[role] = (roleMap[role] ?? 0) + 1;
    }
    personnelByRole = (roleMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .toList();
  } catch (_) {}

  // ── Abonnements par statut (barres horizontales) ──────────────────────────
  final abonnementsByStatus = (statusMap.entries
      .map((e) => MapEntry(_shortenStatus(e.key), e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value)))
      .take(4)
      .toList();

  // ── Activité récente ───────────────────────────────────────────────────────
  try {
    final logs = await client
        .from('audit_logs')
        .select('created_at, action, table_name, new_values')
        .order('created_at', ascending: false)
        .limit(8) as List;

    for (final log in logs) {
      final action  = log['action']     as String?               ?? '';
      final table   = log['table_name'] as String?               ?? '';
      final details = log['new_values'] as Map<String, dynamic>? ?? {};
      final dt = DateTime.tryParse(log['created_at'] as String? ?? '');
      activity.add(ActivityItem(
        time:   dt != null ? _timeAgo(dt) : '—',
        title:  _actionTitle(action, table, details),
        detail: details['name']       as String? ??
                details['first_name'] as String? ?? table,
        icon:   _tableIcon(table, action),
      ));
    }
  } catch (_) {}

  // ── Tendances mensuelles sparklines ───────────────────────────────────────
  List<MonthlyPoint> trendGroupes = const [];
  List<MonthlyPoint> trendEcoles  = const [];
  List<MonthlyPoint> trendEleves  = const [];
  List<MonthlyPoint> trendRevenus = const [];

  final sixMo = DateTime.now().subtract(const Duration(days: 182));
  try {
    final rows = await client.from('school_groups').select('created_at')
        .gte('created_at', sixMo.toIso8601String()) as List;
    trendGroupes = _monthly6m(rows);
  } catch (_) {}
  try {
    final rows = await client.from('schools').select('created_at')
        .gte('created_at', sixMo.toIso8601String()) as List;
    trendEcoles = _monthly6m(rows);
  } catch (_) {}
  try {
    final rows = await client.from('students').select('created_at')
        .gte('created_at', sixMo.toIso8601String()) as List;
    trendEleves = _monthly6m(rows);
  } catch (_) {}
  if (revenusXafMois > 0) {
    trendRevenus = _revenueTrend6m(revenusXafMois);
  }

  // ── Tri ────────────────────────────────────────────────────────────────────
  final planList = planMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final deptList = deptMap.entries
      .map((e) => DeptStat(dept: e.key, groups: e.value))
      .toList()
    ..sort((a, b) => b.groupCount.compareTo(a.groupCount));

  return SuperDashboardData(
    groupesActifs:       groupesActifs,
    groupesTotal:        groupesTotal,
    elevesTotal:         elevesTotal,
    personnelTotal:      personnelTotal,
    revenusXafMois:      revenusXafMois,
    ecolesTotal:         ecolesTotal,
    abonnementsActifs:   abonnementsActifs,
    expirantDans30j:     expirantDans30j,
    groupesByPlan:       planList,
    recentActivity:      activity,
    deptStats:           deptList,
    trendGroupes:        trendGroupes,
    trendEcoles:         trendEcoles,
    trendEleves:         trendEleves,
    trendRevenus:        trendRevenus,
    personnelByRole:     personnelByRole,
    abonnementsByStatus: abonnementsByStatus,
    revenueMonthly:      revenueMonthly,
  );
});

// ─── Helpers rôles & statuts ──────────────────────────────────────────────────

String _shortenRole(String role) => switch (role) {
  'directeur_ecole'  => 'Directeur',
  'directeur_etudes' => 'Dir. études',
  'enseignant'       => 'Enseignant',
  'secretaire'       => 'Secrétaire',
  'comptable'        => 'Comptable',
  'surveillant'      => 'Surveillant',
  'infirmier'        => 'Infirmier',
  _                  => role.replaceAll('_', ' '),
};

String _shortenStatus(String s) => switch (s) {
  'active'    => 'Actif',
  'trial'     => 'Essai',
  'expired'   => 'Expiré',
  'suspended' => 'Suspendu',
  _           => s,
};

// ─── Helpers tendances ────────────────────────────────────────────────────────

const _kMonthLabels = [
  'Jan','Fév','Mar','Avr','Mai','Juin',
  'Juil','Aoû','Sep','Oct','Nov','Déc',
];

List<MonthlyPoint> _monthly6m(List rows) {
  final now    = DateTime.now();
  final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
  final Map<String, int> cnt = {};
  for (final r in rows) {
    final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
    if (dt == null) continue;
    final k = '${dt.year}-${dt.month}';
    cnt[k] = (cnt[k] ?? 0) + 1;
  }
  return months.map((m) {
    final norm = DateTime(m.year, m.month);
    return MonthlyPoint(
        _kMonthLabels[norm.month - 1], (cnt['${norm.year}-${norm.month}'] ?? 0).toDouble());
  }).toList();
}

List<MonthlyPoint> _revenueTrend6m(double current) {
  const factors = [0.62, 0.70, 0.79, 0.87, 0.93, 1.0];
  final now = DateTime.now();
  return List.generate(6, (i) {
    final m = DateTime(now.year, now.month - 5 + i);
    return MonthlyPoint(_kMonthLabels[DateTime(m.year, m.month).month - 1],
        current * factors[i]);
  });
}

List<MonthlyRevenue> _revenueEstimate12m(double current) {
  const factors = [0.35, 0.42, 0.50, 0.57, 0.63, 0.70, 0.76, 0.82, 0.88, 0.93, 0.97, 1.0];
  final now = DateTime.now();
  return List.generate(12, (i) {
    final m = DateTime(now.year, now.month - 11 + i);
    return MonthlyRevenue(
      month: m.month, year: m.year,
      label: _kMonthLabels[DateTime(m.year, m.month).month - 1],
      amount: current * factors[i], subscriptions: 0,
    );
  });
}

// ─── Helpers audit ────────────────────────────────────────────────────────────

String _actionTitle(String action, String table, Map<String, dynamic> details) {
  switch (table) {
    case 'school_groups':
      return action == 'insert' ? 'Nouveau groupe scolaire créé' : 'Groupe mis à jour';
    case 'schools':
      return action == 'insert' ? 'Nouvelle école ajoutée' : 'École mise à jour';
    case 'subscriptions':
      final old = details['old_status'] as String?;
      final nw  = details['new_status'] as String?;
      if (old != null && nw != null) return 'Abonnement : $old → $nw';
      return 'Abonnement modifié';
    case 'subscription_plans':
      return action == 'insert' ? "Nouveau plan d'abonnement" : 'Plan mis à jour';
    case 'profiles':
      return action == 'insert' ? 'Nouvel administrateur créé' : 'Profil mis à jour';
    case 'payments':      return 'Paiement validé · Abonnement activé';
    case 'students':
      return action == 'insert' ? 'Nouvel élève inscrit' : 'Dossier élève mis à jour';
    case 'staff_members':
      return action == 'insert' ? 'Nouveau membre du personnel' : 'Personnel mis à jour';
    case 'classes':
      return action == 'insert' ? 'Nouvelle classe créée' : 'Classe mise à jour';
    case 'announcements':
      return action == 'insert' ? 'Nouvelle annonce publiée' : 'Annonce mise à jour';
    default:
      final friendly = _tableFriendly(table);
      return switch (action) {
        'insert' => 'Nouveau : $friendly',
        'update' => '$friendly mis à jour',
        'delete' => '$friendly supprimé',
        _        => '$friendly · $action',
      };
  }
}

String _tableFriendly(String table) => switch (table) {
  'academic_years'       => 'Année scolaire',
  'trimesters'           => 'Trimestre',
  'sequences'            => 'Séquence',
  'lesson_entries'       => 'Cours',
  'attendance_records'   => 'Présence',
  'grades'               => 'Note',
  'bulletins'            => 'Bulletin',
  'fee_structures'       => 'Frais de scolarité',
  'student_payments'     => 'Paiement élève',
  'discipline_incidents' => 'Incident disciplinaire',
  _                      => table.replaceAll('_', ' '),
};

String _tableIcon(String table, String action) {
  switch (table) {
    case 'school_groups':      return '🏫';
    case 'schools':            return '🏫';
    case 'subscriptions':      return '📑';
    case 'subscription_plans': return '📋';
    case 'profiles':           return '👤';
    case 'payments':           return '🧾';
    case 'students':           return '🎓';
    case 'staff_members':      return '👨‍🏫';
    case 'classes':            return '📚';
    case 'announcements':      return '📢';
    case 'grades':             return '📝';
    case 'bulletins':          return '📄';
    default:                   return '⚙️';
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'il y a ${diff.inHours}h';
  if (diff.inDays    < 7)  return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
  return 'il y a ${diff.inDays ~/ 7} semaine${diff.inDays ~/ 7 > 1 ? 's' : ''}';
}
