import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Point mensuel (sparklines / courbes) ───────────────────────────────────
class MonthlyPoint {
  const MonthlyPoint(this.month, this.value);
  final String month;
  final int value;
}

// ─── Résumé par école ───────────────────────────────────────────────────────
class SchoolSummary {
  const SchoolSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    required this.students,
    required this.staff,
    required this.classes,
    this.city,
    this.department,
  });
  final String id;
  final String name;
  final String type;
  final bool isActive;
  final int students;
  final int staff;
  final int classes;
  final String? city;
  final String? department;
}

// ─── Activité récente ───────────────────────────────────────────────────────
class AdminActivity {
  const AdminActivity({required this.time, required this.title, required this.icon});
  final String time;
  final String title;
  final String icon;
}

// ─── Données dashboard admin groupe ─────────────────────────────────────────
class AdminDashboardData {
  const AdminDashboardData({
    required this.groupName,
    required this.planName,
    required this.planSlug,
    required this.subscriptionStatus,
    required this.subscriptionEnd,
    required this.maxSchools,
    required this.maxStudents,
    required this.maxStaff,
    required this.moduleCount,
    required this.ecolesTotal,
    required this.ecolesActives,
    required this.elevesTotal,
    required this.personnelTotal,
    required this.classesTotal,
    required this.revenusMois,
    required this.paiementsMoisCount,
    this.revenusMoisLabel,
    required this.elevesAJour,
    required this.schools,
    required this.recentActivity,
    required this.publicCount,
    required this.priveCount,
    required this.studentsM,
    required this.studentsF,
    required this.enseignantsTotal,
    required this.adminsTotal,
    required this.schoolsByDept,
    required this.studentsByDept,
    required this.enrollmentTrend,
    required this.revenueTrend,
    required this.fonctionnaires,
    required this.nonFonctionnaires,
    required this.staffByContract,
    required this.staffByDept,
    required this.hireTrend,
  });

  final String  groupName;
  final String  planName;
  final String  planSlug;
  final String  subscriptionStatus;
  final DateTime? subscriptionEnd;
  final int     maxSchools, maxStudents, maxStaff, moduleCount;
  final int     ecolesTotal, ecolesActives, elevesTotal, personnelTotal, classesTotal;
  final double  revenusMois;
  final int     paiementsMoisCount;

  /// Nommé SEULEMENT si les revenus affichés ne sont pas ceux du mois en
  /// cours — un chiffre d'une autre période ne se montre jamais sans sa date.
  final String? revenusMoisLabel;
  final int     elevesAJour;
  final List<SchoolSummary> schools;
  final List<AdminActivity> recentActivity;

  // ── Indicateurs stratégiques ──
  final int publicCount, priveCount;
  final int studentsM, studentsF;
  final int enseignantsTotal, adminsTotal;
  final Map<String, int> schoolsByDept;
  final Map<String, int> studentsByDept;
  final List<MonthlyPoint> enrollmentTrend;
  final List<MonthlyPoint> revenueTrend;

  // ── Ressources humaines · statut d'emploi ──
  // Fonctionnaires de l'État = agents titulaires (contrat « permanent »).
  // Personnel non fonctionnaire = contractuels, vacataires, stagiaires.
  final int fonctionnaires, nonFonctionnaires;
  final Map<String, int> staffByContract; // permanent / contractuel / vacataire / stagiaire
  final Map<String, int> staffByDept;
  final List<MonthlyPoint> hireTrend;

  /// Part des fonctionnaires de l'État dans le personnel total (%).
  double get tauxFonctionnaires =>
      personnelTotal == 0 ? 0 : (fonctionnaires / personnelTotal) * 100;

  /// Personnel administratif (non enseignant) estimé.
  int get personnelAdministratif {
    final v = personnelTotal - enseignantsTotal;
    return v < 0 ? 0 : v;
  }

  int get elevesImpayes =>
      (elevesTotal - elevesAJour) < 0 ? 0 : elevesTotal - elevesAJour;

  double get tauxPaiement =>
      elevesTotal == 0 ? 0 : (elevesAJour / elevesTotal) * 100;

  int get coveredDepts => schoolsByDept.length;

  int get newThisMonth =>
      enrollmentTrend.isEmpty ? 0 : enrollmentTrend.last.value;
  int get newLastMonth => enrollmentTrend.length < 2
      ? 0
      : enrollmentTrend[enrollmentTrend.length - 2].value;
  double get enrollmentGrowth {
    final prev = newLastMonth;
    if (prev == 0) return newThisMonth > 0 ? 100 : 0;
    return (newThisMonth - prev) / prev * 100;
  }

  double get tauxOccupationEleves =>
      maxStudents <= 0 ? 0 : (elevesTotal / maxStudents * 100).clamp(0, 999);

  bool get expireBientot {
    if (subscriptionEnd == null) return false;
    final d = subscriptionEnd!.difference(DateTime.now()).inDays;
    return d >= 0 && d <= 30;
  }

  static const empty = AdminDashboardData(
    groupName: '—',
    planName: '—',
    planSlug: '',
    subscriptionStatus: 'trial',
    subscriptionEnd: null,
    maxSchools: 0, maxStudents: 0, maxStaff: 0, moduleCount: 0,
    ecolesTotal: 0, ecolesActives: 0, elevesTotal: 0,
    personnelTotal: 0, classesTotal: 0,
    revenusMois: 0, paiementsMoisCount: 0, elevesAJour: 0,
    schools: [], recentActivity: [],
    publicCount: 0, priveCount: 0,
    studentsM: 0, studentsF: 0,
    enseignantsTotal: 0, adminsTotal: 0,
    schoolsByDept: {}, studentsByDept: {},
    enrollmentTrend: [], revenueTrend: [],
    fonctionnaires: 0, nonFonctionnaires: 0,
    staffByContract: {}, staffByDept: {}, hireTrend: [],
  );
}

/// « 2026-06 » → « juin 2026 ». Un chiffre venu d'un autre mois que le mois
/// courant doit porter son mois, sinon il se lit comme celui d'aujourd'hui.
String _monthLabel(String key) {
  const noms = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return key;
  return '${noms[m - 1]} ${parts[0]}';
}

// ─── Provider principal ─────────────────────────────────────────────────────
final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboardData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  if (groupId == null) return AdminDashboardData.empty;

  // ── Realtime : invalidation silencieuse sur changements du groupe ─────────
  Timer? debounce;
  void onChange(_) {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('admin_dashboard_$groupId');
    for (final table in ['schools', 'students', 'staff_members', 'student_payments']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: onChange,
      );
    }
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {/* hors-ligne / token expiré → on continue */}

  // ── Groupe + plan ──────────────────────────────────────────────────────────
  String  groupName = '—';
  String  planName = '—', planSlug = '';
  String  subStatus = 'trial';
  DateTime? subEnd;
  int maxSchools = 0, maxStudents = 0, maxStaff = 0, moduleCount = 0;
  try {
    final g = await client
        .from('school_groups')
        .select('name, subscription_status, subscription_end, '
            'subscription_plans!plan_id(name, slug, max_schools, max_students, max_staff, module_count)')
        .eq('id', groupId)
        .maybeSingle();
    if (g != null) {
      groupName = g['name'] as String? ?? '—';
      subStatus = g['subscription_status'] as String? ?? 'trial';
      final endStr = g['subscription_end'] as String?;
      subEnd = endStr != null ? DateTime.tryParse(endStr) : null;
      final plan = g['subscription_plans'] as Map<String, dynamic>?;
      planName    = plan?['name'] as String? ?? '—';
      planSlug    = plan?['slug'] as String? ?? '';
      maxSchools  = (plan?['max_schools']  as int?) ?? 0;
      maxStudents = (plan?['max_students'] as int?) ?? 0;
      maxStaff    = (plan?['max_staff']    as int?) ?? 0;
      moduleCount = (plan?['module_count'] as int?) ?? 0;
    }
  } catch (_) {}

  // ── Écoles (avec département) ─────────────────────────────────────────────
  final List<Map<String, dynamic>> schoolRows = [];
  final Map<String, String> schoolDept = {};
  final Map<String, int> schoolsByDept = {};
  int publicCount = 0, priveCount = 0;
  try {
    final rows = await client
        .from('schools')
        .select('id, name, school_type, city, department, is_active')
        .eq('group_id', groupId)
        .order('name', ascending: true) as List;
    schoolRows.addAll(rows.cast<Map<String, dynamic>>());
    for (final s in schoolRows) {
      final id   = s['id'] as String;
      final dept = (s['department'] as String?)?.trim();
      final deptKey = (dept == null || dept.isEmpty) ? 'Non précisé' : dept;
      schoolDept[id] = deptKey;
      schoolsByDept[deptKey] = (schoolsByDept[deptKey] ?? 0) + 1;
      switch (s['school_type'] as String?) {
        case 'public': publicCount++; break;
        case 'prive':  priveCount++;  break;
      }
    }
  } catch (_) {}

  // ── Élèves : comptage, genre, département, tendance d'inscription ─────────
  final Map<String, int> studentsBySchool = {};
  final Map<String, int> studentsByDept   = {};
  final List<DateTime> enrollDates = [];
  int elevesTotal = 0, studentsM = 0, studentsF = 0;
  try {
    final rows = await client
        .from('students')
        .select('school_id, gender, created_at')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    elevesTotal = rows.length;
    for (final r in rows) {
      final sid = r['school_id'] as String? ?? '';
      studentsBySchool[sid] = (studentsBySchool[sid] ?? 0) + 1;
      final dept = schoolDept[sid] ?? 'Non précisé';
      studentsByDept[dept] = (studentsByDept[dept] ?? 0) + 1;
      switch (r['gender'] as String?) {
        case 'M': studentsM++; break;
        case 'F': studentsF++; break;
      }
      final created = DateTime.tryParse(r['created_at'] as String? ?? '');
      if (created != null) enrollDates.add(created);
    }
  } catch (_) {}

  // ── Personnel + statut d'emploi (fonctionnaires vs non-fonctionnaires) ────
  final Map<String, int> staffBySchool   = {};
  final Map<String, int> staffByContract = {};
  final Map<String, int> staffByDept     = {};
  final List<DateTime>   hireDates        = [];
  int personnelTotal = 0, fonctionnaires = 0, nonFonctionnaires = 0;
  try {
    final rows = await client
        .from('staff_members')
        .select('school_id, contract_type, hire_date')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    personnelTotal = rows.length;
    for (final r in rows) {
      final sid = r['school_id'] as String? ?? '';
      staffBySchool[sid] = (staffBySchool[sid] ?? 0) + 1;
      final dept = schoolDept[sid] ?? 'Non précisé';
      staffByDept[dept] = (staffByDept[dept] ?? 0) + 1;
      final ct = (r['contract_type'] as String?) ?? 'permanent';
      staffByContract[ct] = (staffByContract[ct] ?? 0) + 1;
      // Fonctionnaire de l'État = contrat permanent (titulaire) ; sinon non-fonctionnaire.
      if (ct == 'permanent') {
        fonctionnaires++;
      } else {
        nonFonctionnaires++;
      }
      final hired = DateTime.tryParse(r['hire_date'] as String? ?? '');
      if (hired != null) hireDates.add(hired);
    }
  } catch (_) {}

  // ── Classes ──────────────────────────────────────────────────────────────
  final Map<String, int> classesBySchool = {};
  int classesTotal = 0;
  try {
    final rows = await client
        .from('classes')
        .select('school_id')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    classesTotal = rows.length;
    for (final r in rows) {
      final sid = r['school_id'] as String? ?? '';
      classesBySchool[sid] = (classesBySchool[sid] ?? 0) + 1;
    }
  } catch (_) {}

  // ── Corps enseignant / administrateurs (profiles, scope groupe) ──────────
  int enseignantsTotal = 0, adminsTotal = 0;
  try {
    final rows = await client
        .from('profiles')
        .select('role')
        .eq('group_id', groupId) as List;
    for (final r in rows) {
      switch (r['role'] as String?) {
        case 'enseignant':   enseignantsTotal++; break;
        case 'admin_groupe': adminsTotal++;      break;
      }
    }
  } catch (_) {}

  final schools = schoolRows.map((s) {
    final id = s['id'] as String;
    return SchoolSummary(
      id:         id,
      name:       s['name'] as String? ?? '—',
      type:       s['school_type'] as String? ?? 'prive',
      city:       s['city'] as String?,
      department: s['department'] as String?,
      isActive:   s['is_active'] as bool? ?? true,
      students:   studentsBySchool[id] ?? 0,
      staff:      staffBySchool[id] ?? 0,
      classes:    classesBySchool[id] ?? 0,
    );
  }).toList();

  // ── Finance : élèves à jour sur l'ANNÉE, revenus du dernier mois encaissé ──
  //
  // ⚠️ Deux erreurs de fenêtre corrigées ici, toutes deux visibles sur l'écran
  // d'accueil du ministère :
  //
  //  1. « Élèves à jour » se comptait sur le MOIS CIVIL en cours. Or la
  //     scolarité se règle par tranches sur l'année (sept→juin) : le 1er de
  //     chaque mois, et pendant toutes les vacances de juillet-août, le taux
  //     retombait mécaniquement à 0 % — un rouge franc sur la page d'accueil,
  //     alors que la page Rapports, elle, comptait sur l'année et affichait
  //     69 %. Deux chiffres contradictoires pour la même question.
  //  2. « Revenus du mois » restait à zéro dès qu'aucun encaissement n'avait
  //     encore eu lieu dans le mois courant. On montre désormais le DERNIER
  //     mois encaissé, en le nommant — un chiffre daté vaut mieux qu'un zéro
  //     muet.
  double revenusMois = 0;
  int    paiementsCount = 0;
  String? revenusMoisLabel;
  final  Set<String> studentsPaid = {};
  final  List<DateTime> payDates = [];
  final  Map<String, double> revByMonth = {};
  final  Map<String, int> countByMonth = {};
  try {
    final now = DateTime.now();
    // L'année scolaire congolaise court de septembre à juin.
    final yearStart = DateTime(now.month >= 9 ? now.year : now.year - 1, 9, 1);
    final from6 = DateTime(now.year, now.month - 5, 1);
    final from = yearStart.isBefore(from6) ? yearStart : from6;
    final rows = await client
        .from('student_payments')
        .select('amount_xaf, student_id, status, payment_date')
        .eq('group_id', groupId)
        .eq('status', 'confirmed')
        .gte('payment_date', from.toIso8601String().substring(0, 10)) as List;
    for (final r in rows) {
      final amount = (r['amount_xaf'] as num? ?? 0).toDouble();
      final dt = DateTime.tryParse(r['payment_date'] as String? ?? '');
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      revByMonth[key] = (revByMonth[key] ?? 0) + amount;
      countByMonth[key] = (countByMonth[key] ?? 0) + 1;
      payDates.add(dt);
      // À jour = a réglé au moins une tranche depuis la rentrée.
      if (!dt.isBefore(yearStart)) {
        final sid = r['student_id'] as String?;
        if (sid != null) studentsPaid.add(sid);
      }
    }
    // Le mois courant s'il a encaissé, sinon le dernier qui l'a fait.
    final currentKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final key = revByMonth.containsKey(currentKey)
        ? currentKey
        : (revByMonth.keys.toList()..sort()).lastOrNull;
    if (key != null) {
      revenusMois = revByMonth[key] ?? 0;
      paiementsCount = countByMonth[key] ?? 0;
      if (key != currentKey) revenusMoisLabel = _monthLabel(key);
    }
  } catch (_) {}

  // ── Activité récente (audit, RLS scope groupe) ───────────────────────────
  final List<AdminActivity> activity = [];
  try {
    final logs = await client
        .from('audit_logs')
        .select('created_at, action, table_name')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(8) as List;
    for (final l in logs) {
      final action = l['action'] as String? ?? '';
      final table  = l['table_name'] as String? ?? '';
      final dt = DateTime.tryParse(l['created_at'] as String? ?? '');
      activity.add(AdminActivity(
        time:  dt != null ? _timeAgo(dt) : '—',
        title: _activityTitle(action, table),
        icon:  _tableIcon(table),
      ));
    }
  } catch (_) {}

  return AdminDashboardData(
    groupName:          groupName,
    planName:           planName,
    planSlug:           planSlug,
    subscriptionStatus: subStatus,
    subscriptionEnd:    subEnd,
    maxSchools:         maxSchools,
    maxStudents:        maxStudents,
    maxStaff:           maxStaff,
    moduleCount:        moduleCount,
    ecolesTotal:        schools.length,
    ecolesActives:      schools.where((s) => s.isActive).length,
    elevesTotal:        elevesTotal,
    personnelTotal:     personnelTotal,
    classesTotal:       classesTotal,
    revenusMois:        revenusMois,
    paiementsMoisCount: paiementsCount,
    revenusMoisLabel:   revenusMoisLabel,
    elevesAJour:        studentsPaid.length,
    schools:            schools,
    recentActivity:     activity,
    publicCount:        publicCount,
    priveCount:         priveCount,
    studentsM:          studentsM,
    studentsF:          studentsF,
    enseignantsTotal:   enseignantsTotal,
    adminsTotal:        adminsTotal,
    schoolsByDept:      schoolsByDept,
    studentsByDept:     studentsByDept,
    enrollmentTrend:    _monthlyTrend(enrollDates),
    revenueTrend:       _monthlyMoneyTrend(revByMonth),
    fonctionnaires:     fonctionnaires,
    nonFonctionnaires:  nonFonctionnaires,
    staffByContract:    staffByContract,
    staffByDept:        staffByDept,
    hireTrend:          _monthlyTrend(hireDates),
  );
});

// ─── Helpers ────────────────────────────────────────────────────────────────
const List<String> _kMonthLabels = [
  'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
  'jui', 'aoû', 'sep', 'oct', 'nov', 'déc',
];

/// Répartit une liste de dates sur les 6 derniers mois (compte par mois).
List<MonthlyPoint> _monthlyTrend(List<DateTime> dates) {
  final now = DateTime.now();
  final keys = <String>[];
  final labels = <String>[];
  final counts = <String, int>{};
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    keys.add(key);
    labels.add(_kMonthLabels[d.month - 1]);
    counts[key] = 0;
  }
  for (final dt in dates) {
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
  }
  return [for (int i = 0; i < keys.length; i++) MonthlyPoint(labels[i], counts[keys[i]] ?? 0)];
}

/// Somme financière par mois sur les 6 derniers mois (en milliers XAF pour l'échelle).
List<MonthlyPoint> _monthlyMoneyTrend(Map<String, double> byMonth) {
  final now = DateTime.now();
  final out = <MonthlyPoint>[];
  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    out.add(MonthlyPoint(_kMonthLabels[d.month - 1], (byMonth[key] ?? 0).round()));
  }
  return out;
}

String _activityTitle(String action, String table) {
  final verb = switch (action) {
    'insert' => 'Création',
    'update' => 'Modification',
    'delete' => 'Suppression',
    _        => action,
  };
  final friendly = switch (table) {
    'schools'           => 'école',
    'students'          => 'élève',
    'staff_members'     => 'personnel',
    'classes'           => 'classe',
    'student_payments'  => 'paiement',
    'access_profiles'   => "profil d'accès",
    'profiles'          => 'utilisateur',
    'grades'            => 'note',
    'bulletins'         => 'bulletin',
    'fee_structures'    => 'frais de scolarité',
    _                   => table.replaceAll('_', ' '),
  };
  return '$verb · $friendly';
}

String _tableIcon(String table) => switch (table) {
  'schools'          => '🏫',
  'students'         => '🎓',
  'staff_members'    => '👨‍🏫',
  'classes'          => '📚',
  'student_payments' => '🧾',
  'access_profiles'  => '🔐',
  'profiles'         => '👤',
  'grades'           => '📝',
  'bulletins'        => '📄',
  _                  => '⚙️',
};

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1)  return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'il y a ${diff.inHours}h';
  if (diff.inDays    < 7)  return 'il y a ${diff.inDays}j';
  return 'il y a ${diff.inDays ~/ 7} sem';
}
