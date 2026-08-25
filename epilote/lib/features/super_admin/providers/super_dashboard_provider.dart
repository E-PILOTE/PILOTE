import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/billing_period.dart';
import '../../../core/utils/booleen_en_ligne.dart';
import '../../../core/utils/plan_referential_realtime.dart';

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
    // ── Couverture territoriale ────────────────────────────────────────────
    this.ecolesGeolocalisees = 0,
    this.departementsCouverts = 0,
    this.departementsTotal = 0,
  });

  final int    groupesActifs;
  final int    groupesTotal;
  final int    elevesTotal;
  final int    personnelTotal;
  final double revenusXafMois;

  // ── Couverture territoriale ───────────────────────────────────────────────
  //
  // ⚠️ Ces deux mesures REMPLACENT « Sync réussie 99,7 % » et « Disponibilité
  // SLA 99,5 % », qui étaient des CONSTANTES écrites en dur dans ce fichier.
  // La plateforme n'instrumente ni l'une ni l'autre : aucune table ne mesure le
  // taux de synchronisation ni la disponibilité du service. Le tableau de bord
  // annonçait donc un engagement de service à un ministère sur la foi de deux
  // nombres inventés — y compris application hors ligne et base vide.
  //
  // Ce qui les remplace se compte vraiment, et répond à la question qu'un
  // superviseur national se pose : jusqu'où le déploiement est-il allé ?
  final int ecolesGeolocalisees;
  final int departementsCouverts;

  /// Nombre de départements du pays, lu en base (`departments`) — jamais
  /// codé en dur : l'écran national affichait « /12 » à un endroit et « /15 »
  /// à un autre, sur la même page.
  final int departementsTotal;

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

  // ── Abonnement Supabase Realtime ──────────────────────────────────────────
  // Invalide le provider dès qu'une ligne change (INSERT / UPDATE / DELETE).
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () {
      ref.invalidateSelf();
    });
  }

  final channel = client.channel('super_dashboard_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'school_groups',
        callback: (_) => scheduleInvalidate(),
      )
      // Le revenu récurrent est le PRIX du plan × groupes actifs : il change
      // sans qu'aucun groupe ne bouge.
      .watchPlanReferential(scheduleInvalidate)
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
  //
  // ⚠️ COMPTER, PAS RAMENER. `select('id')` puis `.length` compte les lignes
  // REÇUES — or PostgREST en renvoie 1 000 au maximum. Avec 9 104 élèves semés,
  // le tableau de bord affichait « 1.0 K » : un plafond technique présenté au
  // ministère comme un effectif national. À l'échelle visée (1 000+ écoles), la
  // mesure aurait été fausse d'un ordre de grandeur, et d'autant plus crédible
  // qu'elle est ronde.
  try {
    elevesTotal = await client.from('students').count(CountOption.exact);
  } catch (_) {}

  // ── Personnel (hors super_admin / admin_groupe) ───────────────────────────
  try {
    // `count()` s'applique au constructeur de requête : le filtre passe donc
    // par `select()` avant d'être compté.
    personnelTotal = (await client
            .from('profiles')
            .select()
            .not('role', 'in', '(super_admin,admin_groupe)')
            .count(CountOption.exact))
        .count;
  } catch (_) {}

  // ── Historique revenus 12 mois ────────────────────────────────────────────
  List<MonthlyRevenue> revenueMonthly = const [];

  // ── Couverture territoriale ───────────────────────────────────────────────
  // Deux mesures qui se comptent : combien d'écoles ont des coordonnées (donc
  // apparaissent sur la carte nationale), et combien de départements du pays
  // sont atteints. Le total des départements se LIT en base : il ne se devine
  // pas, et surtout il ne s'écrit pas en dur deux fois avec deux valeurs
  // différentes.
  var ecolesGeolocalisees = 0, departementsCouverts = 0, departementsTotal = 0;
  try {
    departementsTotal =
        await client.from('departments').count(CountOption.exact);
  } catch (_) {}

  // ── Écoles + Groupes ───────────────────────────────────────────────────────
  try {
    final schools = await client
        .from('schools')
        .select('id, group_id, latitude, longitude, department') as List;
    ecolesTotal = schools.length;

    final coveredDepts = <String>{};
    for (final s in schools) {
      if (s['latitude'] != null && s['longitude'] != null) {
        ecolesGeolocalisees++;
      }
      final d = (s['department'] as String?)?.trim();
      if (d != null && d.isNotEmpty) coveredDepts.add(d.toLowerCase());
    }
    departementsCouverts = coveredDepts.length;

    final Map<String, int> schoolsByGroup = {};
    for (final s in schools) {
      final gid = s['group_id'] as String? ?? '';
      schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
    }

    final groups = await client.from('school_groups').select(
      'id, name, department, is_active, subscription_status, '
      'subscription_end, created_at, '
      'subscription_plans!plan_id(name, price_xaf, billing_period)',
    ) as List;

    groupesTotal  = groups.length;
    groupesActifs = groups.where((g) => actifEnLigne(g['is_active'])).length;

    final now  = DateTime.now();
    final in30 = now.add(const Duration(days: 30));

    for (final grp in groups) {
      final plan     = grp['subscription_plans'] as Map<String, dynamic>?;
      final status   = grp['subscription_status'] as String? ?? '';
      final dept     = (grp['department'] as String?)?.trim().isNotEmpty == true
          ? grp['department'] as String
          : 'Autres';
      final planName = plan?['name'] as String? ?? 'Inconnu';
      // Revenu MENSUEL : un plan annuel à 2 500 000 FCFA pèse 208 333 par
      // mois. Sommer les tarifs bruts multipliait le revenu par douze.
      final price    = monthlyPriceOfPlanRow(plan);

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
        isActive:        actifEnLigne(grp['is_active']),
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
        final price2 = monthlyPriceOfPlanRow(plan2);
        if (price2 > 0) { mrr += price2; subs++; }
      }
      mrList.add(MonthlyRevenue(
        month: mDate.month, year: mDate.year,
        label: _kMonthLabels[mDate.month - 1],
        amount: mrr, subscriptions: subs,
      ));
    }
    // Pas de repli inventé : le calcul ci-dessus reconstitue le revenu
    // récurrent à partir des groupes et des plans RÉELS. Quand il ne donne
    // rien, c'est qu'il n'y a rien — et c'est ce qu'il faut montrer.
    revenueMonthly = mrList;
  } catch (_) {}

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
  // ⚠️ Les revenus se lisent sur les FACTURES ENCAISSÉES, pas sur une courbe
  // fabriquée. La version précédente prenait le revenu du mois courant et le
  // multipliait par [0.62, 0.70, 0.79, 0.87, 0.93, 1.0] : le graphique
  // « Revenus mensuels · Tendance » montrait donc une croissance régulière
  // inventée, identique quelle que soit la réalité de la plateforme — et une
  // courbe montante même un mois où rien n'a été encaissé.
  // La courbe de la carte « Revenus » est la QUEUE de l'historique 12 mois
  // calculé plus haut : une seule mesure, lue deux fois. Deux calculs
  // distincts sous deux libellés voisins finiraient par diverger, et personne
  // ne saurait lequel dit vrai.
  if (revenueMonthly.length >= 6) {
    trendRevenus = [
      for (final m in revenueMonthly.sublist(revenueMonthly.length - 6))
        MonthlyPoint(m.label, m.amount),
    ];
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
    ecolesGeolocalisees:  ecolesGeolocalisees,
    departementsCouverts: departementsCouverts,
    departementsTotal:    departementsTotal,
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

// ⚠️ Deux fabriques de courbes ont été supprimées ici : `_revenueTrend6m` et
// `_revenueEstimate12m`. Elles prenaient le revenu du mois courant et le
// multipliaient par une suite de facteurs croissants ([0.62, 0.70, 0.79, 0.87,
// 0.93, 1.0] pour l'une, douze valeurs de 0.35 à 1.0 pour l'autre). Le
// graphique « Revenus mensuels · Tendance » montrait donc TOUJOURS une belle
// progression, identique quelle que soit la réalité de la plateforme, y
// compris un mois sans le moindre encaissement. Le revenu se reconstitue
// désormais à partir des groupes, de leurs plans et de leurs dates
// d'abonnement — c'est-à-dire de faits.

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
