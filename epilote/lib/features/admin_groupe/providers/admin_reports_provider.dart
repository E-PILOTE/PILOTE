import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/utils/mesures_manquantes.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RAPPORTS · agrégation filtrée (période + école) — scope group_id, Supabase
//  direct (admin_groupe est EN LIGNE). On charge une seule fois les lignes
//  brutes du groupe (élèves, personnel, écoles, paiements) puis on agrège côté
//  client selon la période/établissement sélectionnés : zéro requête réseau au
//  changement de filtre, drill-down instantané.
// ════════════════════════════════════════════════════════════════════════════

// ─── Granularité de période ──────────────────────────────────────────────────
enum ReportPeriodKind { year, trimester1, trimester2, trimester3, custom }

// ─── Sélection de période (immutable → clé de cache stable) ──────────────────
@immutable
class ReportPeriod {
  const ReportPeriod({
    required this.kind,
    this.customStart,
    this.customEnd,
  });

  const ReportPeriod.year() : this(kind: ReportPeriodKind.year);

  final ReportPeriodKind kind;
  final DateTime? customStart;
  final DateTime? customEnd;

  String get label => switch (kind) {
        ReportPeriodKind.year => 'Année scolaire',
        ReportPeriodKind.trimester1 => '1er trimestre',
        ReportPeriodKind.trimester2 => '2e trimestre',
        ReportPeriodKind.trimester3 => '3e trimestre',
        ReportPeriodKind.custom => 'Période personnalisée',
      };

  String get shortLabel => switch (kind) {
        ReportPeriodKind.year => 'Année',
        ReportPeriodKind.trimester1 => 'T1',
        ReportPeriodKind.trimester2 => 'T2',
        ReportPeriodKind.trimester3 => 'T3',
        ReportPeriodKind.custom => 'Perso.',
      };

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(kind, customStart, customEnd);
}

// ─── Filtre complet (période + école) ────────────────────────────────────────
@immutable
class ReportFilter {
  const ReportFilter({
    this.period = const ReportPeriod.year(),
    this.schoolId, // null = toutes les écoles
  });

  final ReportPeriod period;
  final String? schoolId;

  ReportFilter copyWith({ReportPeriod? period, Object? schoolId = _noChange}) =>
      ReportFilter(
        period: period ?? this.period,
        schoolId: identical(schoolId, _noChange)
            ? this.schoolId
            : schoolId as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.period == period &&
      other.schoolId == schoolId;

  @override
  int get hashCode => Object.hash(period, schoolId);
}

const Object _noChange = Object();

// ─── State du filtre sélectionné (piloté par l'UI) ───────────────────────────
final reportFilterProvider =
    StateProvider.autoDispose<ReportFilter>((ref) => const ReportFilter());

// ════════════════════════════════════════════════════════════════════════════
//  MODÈLES
// ════════════════════════════════════════════════════════════════════════════

// Point d'une série temporelle mensuelle (graphes lignes/aires/barres).
class ReportTrendPoint {
  const ReportTrendPoint(this.label, this.value, {this.amount = 0});
  final String label;
  final int value;
  final double amount;
}

// Catégorie nommée + valeur (camemberts, barres horizontales).
class ReportCategory {
  const ReportCategory(this.label, this.value, {this.amount = 0});
  final String label;
  final int value;
  final double amount;
}

// Ligne détaillée par établissement (tableau + drill-down).
class ReportSchoolRow {
  const ReportSchoolRow({
    required this.id,
    required this.name,
    required this.type,
    required this.department,
    required this.isActive,
    required this.students,
    required this.studentsM,
    required this.studentsF,
    required this.staff,
    required this.fonctionnaires,
    required this.classes,
    required this.revenue,
    required this.payments,
    this.city,
  });

  final String id;
  final String name;
  final String type; // public / prive
  final String department;
  final bool isActive;
  final int students, studentsM, studentsF;
  final int staff, fonctionnaires, classes;
  final double revenue;
  final int payments;
  final String? city;

  int get nonFonctionnaires =>
      (staff - fonctionnaires) < 0 ? 0 : staff - fonctionnaires;
}

// ─── Agrégat complet d'un rapport (déjà filtré) ──────────────────────────────
/// Les mesures d'un rapport, nommées — cf. `MesuresManquantes`.
///
/// ⚠️ SEPT LECTURES ÉTAIENT MUETTES. Un rapport de groupe part au ministère :
/// une requête qui échoue laissait « 0 école », « 0 élève », « 0 FCFA
/// encaissé », et rien ne disait que le chiffre venait d'un échec plutôt que
/// de la réalité. Un zéro rond est d'autant plus crédible.
class MesuresRapport {
  const MesuresRapport._();

  static const groupe = 'groupe';
  static const anneeScolaire = 'annee_scolaire';
  static const ecoles = 'ecoles';
  static const eleves = 'eleves';
  static const personnel = 'personnel';
  static const classes = 'classes';
  static const paiements = 'paiements';

  static String libelle(String cle) => switch (cle) {
        groupe => 'identité du groupe',
        anneeScolaire => 'année scolaire',
        ecoles => 'établissements',
        eleves => 'effectifs élèves',
        personnel => 'personnel',
        classes => 'classes',
        paiements => 'paiements',
        _ => cle,
      };
}

class ReportData {
  const ReportData({
    required this.groupName,
    required this.planName,
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
    required this.scopeLabel,
    required this.schoolsTotal,
    required this.schoolsActives,
    required this.publicCount,
    required this.priveCount,
    required this.elevesTotal,
    required this.elevesNouveaux,
    required this.studentsM,
    required this.studentsF,
    required this.personnelTotal,
    required this.personnelNouveau,
    required this.fonctionnaires,
    required this.nonFonctionnaires,
    required this.classesTotal,
    required this.revenusTotal,
    required this.paiementsCount,
    required this.elevesAJour,
    required this.staffByContract,
    required this.schoolsByDept,
    required this.studentsByDept,
    required this.enrollmentTrend,
    required this.hireTrend,
    required this.revenueTrend,
    required this.schoolRows,
    required this.allSchools,
    this.mesuresManquantes = const {},
  });

  /// Les mesures que la lecture n'a PAS pu obtenir — cf. [MesuresRapport].
  ///
  /// Vide dans le cas normal. Non vide, elle veut dire « ces chiffres ne sont
  /// pas à zéro : ils sont inconnus ». Un rapport de groupe part au ministère.
  final Set<String> mesuresManquantes;

  bool manque(String cle) => mesuresManquantes.contains(cle);

  final String groupName, planName, periodLabel, scopeLabel;
  final DateTime periodStart, periodEnd;

  // Établissements
  final int schoolsTotal, schoolsActives;
  final int publicCount, priveCount;

  // Effectifs (période)
  final int elevesTotal; // effectif total scopé (école)
  final int elevesNouveaux; // inscrits dans la période (created_at)
  final int studentsM, studentsF;

  // RH (période)
  final int personnelTotal;
  final int personnelNouveau; // embauchés dans la période (hire_date)
  final int fonctionnaires, nonFonctionnaires;

  final int classesTotal;

  // Finance (période)
  final double revenusTotal;
  final int paiementsCount;
  final int elevesAJour;

  // Distributions
  final Map<String, int> staffByContract;
  final Map<String, int> schoolsByDept;
  final Map<String, int> studentsByDept;

  // Séries temporelles (alignées sur la période)
  final List<ReportTrendPoint> enrollmentTrend;
  final List<ReportTrendPoint> hireTrend;
  final List<ReportTrendPoint> revenueTrend;

  // Détail établissements (respecte le filtre école si défini)
  final List<ReportSchoolRow> schoolRows;

  // Toutes les écoles du groupe (pour le sélecteur, non filtré)
  final List<ReportSchoolRow> allSchools;

  bool get isEmpty => elevesTotal == 0 && personnelTotal == 0 && schoolsTotal == 0;

  int get coveredDepts => schoolsByDept.length;

  int get elevesImpayes =>
      (elevesTotal - elevesAJour) < 0 ? 0 : elevesTotal - elevesAJour;

  double get tauxPaiement =>
      elevesTotal == 0 ? 0 : (elevesAJour / elevesTotal) * 100;

  double get tauxFonctionnaires =>
      personnelTotal == 0 ? 0 : (fonctionnaires / personnelTotal) * 100;

  double get pctFilles => elevesTotal == 0 ? 0 : studentsF / elevesTotal * 100;
  double get pctGarcons => elevesTotal == 0 ? 0 : studentsM / elevesTotal * 100;

  /// Ratio élèves / personnel (encadrement).
  double get ratioEncadrement =>
      personnelTotal == 0 ? 0 : elevesTotal / personnelTotal;

  double get revenuMoyenParEleve =>
      elevesTotal == 0 ? 0 : revenusTotal / elevesTotal;

  static final empty = ReportData(
    groupName: '—',
    planName: '—',
    periodLabel: 'Année scolaire',
    periodStart: DateTime(2025, 9, 1),
    periodEnd: DateTime(2026, 7, 31),
    scopeLabel: 'Toutes les écoles',
    schoolsTotal: 0,
    schoolsActives: 0,
    publicCount: 0,
    priveCount: 0,
    elevesTotal: 0,
    elevesNouveaux: 0,
    studentsM: 0,
    studentsF: 0,
    personnelTotal: 0,
    personnelNouveau: 0,
    fonctionnaires: 0,
    nonFonctionnaires: 0,
    classesTotal: 0,
    revenusTotal: 0,
    paiementsCount: 0,
    elevesAJour: 0,
    staffByContract: {},
    schoolsByDept: {},
    studentsByDept: {},
    enrollmentTrend: [],
    hireTrend: [],
    revenueTrend: [],
    schoolRows: [],
    allSchools: [],
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SNAPSHOT BRUT (chargé une fois, mis en cache, ré-agrégé localement)
// ════════════════════════════════════════════════════════════════════════════
class SchoolRaw {
  SchoolRaw({
    required this.id,
    required this.name,
    required this.type,
    required this.department,
    required this.isActive,
    this.city,
  });
  final String id, name, type, department;
  final bool isActive;
  final String? city;
}

class StudentRaw {
  StudentRaw({required this.schoolId, required this.gender, this.createdAt});
  final String schoolId;
  final String gender; // 'M' / 'F' / ''
  final DateTime? createdAt;
}

class StaffRaw {
  StaffRaw({required this.schoolId, required this.contract, this.hireDate});
  final String schoolId;
  final String contract; // permanent / contractuel / vacataire / stagiaire
  final DateTime? hireDate;
}

class PaymentRaw {
  PaymentRaw({
    required this.schoolId,
    required this.studentId,
    required this.amount,
    this.date,
  });
  final String schoolId;
  final String? studentId;
  final double amount;
  final DateTime? date;
}

class ReportsSnapshot {
  ReportsSnapshot({
    required this.groupName,
    required this.planName,
    required this.academicStart,
    required this.academicEnd,
    required this.schools,
    required this.students,
    required this.staff,
    required this.classesBySchool,
    required this.payments,
      this.mesuresManquantes = const {},
  });

  final String groupName, planName;
  final DateTime academicStart, academicEnd;
  final List<SchoolRaw> schools;
  final List<StudentRaw> students;
  final List<StaffRaw> staff;
  final Map<String, int> classesBySchool;
  final List<PaymentRaw> payments;

  /// Les mesures que cette lecture n'a PAS pu obtenir. Vide dans le cas normal.
  final Set<String> mesuresManquantes;
}

// ─── Provider snapshot (1 chargement réseau, realtime, keepAlive) ────────────
final reportsSnapshotProvider =
    FutureProvider.autoDispose<ReportsSnapshot>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) {
    final now = DateTime.now();
    return ReportsSnapshot(
      groupName: '—',
      planName: '—',
      academicStart: DateTime(now.year, 9, 1),
      academicEnd: DateTime(now.year + 1, 7, 31),
      schools: const [],
      students: const [],
      staff: const [],
      classesBySchool: const {},
      payments: const [],
    );
  }

  // Ce que la lecture n'aura pas pu obtenir. Rempli par les `catch` ci-dessous
  // et rendu avec les données : un rapport qui affiche des zéros sans dire
  // qu'il n'a rien lu est un rapport faux.
  final manquantes = MesuresManquantes();

  // Le pré-chargement réseau est lourd ; on n'invalide pas en boucle.
  // (Le bouton Actualiser + le pull-to-refresh suffisent ; pas de realtime ici
  //  pour éviter de recharger toutes les lignes du groupe à chaque écriture.)

  // ── Groupe + plan + année scolaire courante ──────────────────────────────
  String groupName = '—', planName = '—';
  final now = DateTime.now();
  DateTime academicStart = DateTime(now.year, 9, 1);
  DateTime academicEnd = DateTime(now.year + 1, 7, 31);
  try {
    final g = await client
        .from('school_groups')
        .select('name, subscription_plans!plan_id(name)')
        .eq('id', groupId)
        .maybeSingle();
    if (g != null) {
      groupName = g['name'] as String? ?? '—';
      final plan = g['subscription_plans'] as Map<String, dynamic>?;
      planName = plan?['name'] as String? ?? '—';
    }
  } catch (e) {
    manquantes.note(MesuresRapport.groupe, e, ecran: 'Rapports');
  }
  try {
    final ay = await client
        .from('academic_years')
        .select('start_date, end_date, is_current')
        .eq('group_id', groupId)
        .eq('is_current', true)
        .order('start_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (ay != null) {
      final sd = DateTime.tryParse(ay['start_date'] as String? ?? '');
      final ed = DateTime.tryParse(ay['end_date'] as String? ?? '');
      if (sd != null) academicStart = sd;
      if (ed != null) academicEnd = ed;
    }
  } catch (e) {
    manquantes.note(MesuresRapport.anneeScolaire, e, ecran: 'Rapports');
  }

  // ── Écoles ────────────────────────────────────────────────────────────────
  final List<SchoolRaw> schools = [];
  try {
    final rows = await client
        .from('schools')
        .select('id, name, school_type, city, department, is_active')
        .eq('group_id', groupId)
        .order('name', ascending: true) as List;
    for (final s in rows) {
      final dept = (s['department'] as String?)?.trim();
      schools.add(SchoolRaw(
        id: s['id'] as String,
        name: s['name'] as String? ?? '—',
        type: s['school_type'] as String? ?? 'prive',
        department: (dept == null || dept.isEmpty) ? 'Non précisé' : dept,
        isActive: s['is_active'] as bool? ?? true,
        city: s['city'] as String?,
      ));
    }
  } catch (e) {
    manquantes.note(MesuresRapport.ecoles, e, ecran: 'Rapports');
  }

  // ── Élèves ──────────────────────────────────────────────────────────────────
  final List<StudentRaw> students = [];
  try {
    final rows = await client
        .from('students')
        .select('school_id, gender, created_at')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    for (final r in rows) {
      students.add(StudentRaw(
        schoolId: r['school_id'] as String? ?? '',
        gender: (r['gender'] as String?) ?? '',
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      ));
    }
  } catch (e) {
    manquantes.note(MesuresRapport.eleves, e, ecran: 'Rapports');
  }

  // ── Personnel ───────────────────────────────────────────────────────────────
  final List<StaffRaw> staff = [];
  try {
    final rows = await client
        .from('staff_members')
        .select('school_id, contract_type, hire_date')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    for (final r in rows) {
      staff.add(StaffRaw(
        schoolId: r['school_id'] as String? ?? '',
        contract: (r['contract_type'] as String?) ?? 'permanent',
        hireDate: DateTime.tryParse(r['hire_date'] as String? ?? ''),
      ));
    }
  } catch (e) {
    manquantes.note(MesuresRapport.personnel, e, ecran: 'Rapports');
  }

  // ── Classes (compte par école) ──────────────────────────────────────────────
  final Map<String, int> classesBySchool = {};
  try {
    final rows = await client
        .from('classes')
        .select('school_id')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    for (final r in rows) {
      final sid = r['school_id'] as String? ?? '';
      classesBySchool[sid] = (classesBySchool[sid] ?? 0) + 1;
    }
  } catch (e) {
    manquantes.note(MesuresRapport.classes, e, ecran: 'Rapports');
  }

  // ── Paiements confirmés (toute l'année scolaire pour permettre le filtre) ───
  final List<PaymentRaw> payments = [];
  try {
    final rows = await client
        .from('student_payments')
        .select('school_id, student_id, amount_xaf, payment_date, status')
        .eq('group_id', groupId)
        .eq('status', 'confirmed') as List;
    for (final r in rows) {
      payments.add(PaymentRaw(
        schoolId: r['school_id'] as String? ?? '',
        studentId: r['student_id'] as String?,
        amount: (r['amount_xaf'] as num? ?? 0).toDouble(),
        date: DateTime.tryParse(r['payment_date'] as String? ?? ''),
      ));
    }
  } catch (e) {
    manquantes.note(MesuresRapport.paiements, e, ecran: 'Rapports');
  }

  return ReportsSnapshot(
    groupName: groupName,
    planName: planName,
    academicStart: academicStart,
    academicEnd: academicEnd,
    schools: schools,
    students: students,
    staff: staff,
    classesBySchool: classesBySchool,
    payments: payments,
    mesuresManquantes: manquantes.cles,
  );
});

// ════════════════════════════════════════════════════════════════════════════
//  PROVIDER AGRÉGÉ (param = filtre) — réagit instantanément aux changements
// ════════════════════════════════════════════════════════════════════════════
final reportDataProvider =
    Provider.autoDispose.family<AsyncValue<ReportData>, ReportFilter>((ref, filter) {
  final snap = ref.watch(reportsSnapshotProvider);
  return snap.whenData((s) => _aggregate(s, filter));
});

// ─── Bornes de date pour une période donnée ──────────────────────────────────
(DateTime, DateTime) periodBounds(ReportPeriod p, DateTime ayStart, DateTime ayEnd) {
  switch (p.kind) {
    case ReportPeriodKind.year:
      return (ayStart, ayEnd);
    case ReportPeriodKind.custom:
      final start = p.customStart ?? ayStart;
      final end = p.customEnd ?? ayEnd;
      // garantit start <= end
      return start.isAfter(end) ? (end, start) : (start, end);
    case ReportPeriodKind.trimester1:
    case ReportPeriodKind.trimester2:
    case ReportPeriodKind.trimester3:
      // Découpe l'année scolaire en trois fenêtres égales (la table
      // `trimesters` est vide en base → on dérive depuis l'année courante).
      final totalDays = ayEnd.difference(ayStart).inDays;
      final third = (totalDays / 3).floor();
      final idx = switch (p.kind) {
        ReportPeriodKind.trimester1 => 0,
        ReportPeriodKind.trimester2 => 1,
        _ => 2,
      };
      final start = ayStart.add(Duration(days: third * idx));
      final end = idx == 2 ? ayEnd : ayStart.add(Duration(days: third * (idx + 1)));
      return (start, end);
  }
}

bool _inRange(DateTime? d, DateTime start, DateTime end) {
  if (d == null) return false;
  final day = DateTime(d.year, d.month, d.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !day.isBefore(s) && !day.isAfter(e);
}

// ─── Cœur de l'agrégation (pur, testable, sans réseau) ───────────────────────
ReportData _aggregate(ReportsSnapshot s, ReportFilter f) {
  final (start, end) = periodBounds(f.period, s.academicStart, s.academicEnd);
  final schoolId = f.schoolId;

  bool keepSchool(String id) => schoolId == null || id == schoolId;

  // ── Référentiel écoles (toutes, pour le sélecteur) ──────────────────────────
  final Map<String, SchoolRaw> byId = {for (final sc in s.schools) sc.id: sc};

  // ── Agrégats par école (toujours calculés sur toutes les écoles) ────────────
  final Map<String, int> stuBySchool = {};
  final Map<String, int> stuMBySchool = {};
  final Map<String, int> stuFBySchool = {};
  final Map<String, int> staffBySchool = {};
  final Map<String, int> foncBySchool = {};
  final Map<String, double> revBySchool = {};
  final Map<String, int> payCountBySchool = {};

  // ── Distributions (scope école appliqué) ────────────────────────────────────
  int elevesTotal = 0, studentsM = 0, studentsF = 0, elevesNouveaux = 0;
  final Map<String, int> studentsByDept = {};
  final List<DateTime> enrollDates = [];

  for (final st in s.students) {
    final sc = byId[st.schoolId];
    final dept = sc?.department ?? 'Non précisé';
    // effectif total par école (non borné par période → photo actuelle)
    stuBySchool[st.schoolId] = (stuBySchool[st.schoolId] ?? 0) + 1;
    if (st.gender == 'M') {
      stuMBySchool[st.schoolId] = (stuMBySchool[st.schoolId] ?? 0) + 1;
    } else if (st.gender == 'F') {
      stuFBySchool[st.schoolId] = (stuFBySchool[st.schoolId] ?? 0) + 1;
    }
    if (!keepSchool(st.schoolId)) continue;
    elevesTotal++;
    if (st.gender == 'M') {
      studentsM++;
    } else if (st.gender == 'F') {
      studentsF++;
    }
    studentsByDept[dept] = (studentsByDept[dept] ?? 0) + 1;
    if (_inRange(st.createdAt, start, end)) {
      elevesNouveaux++;
      enrollDates.add(st.createdAt!);
    }
  }

  // ── Personnel ───────────────────────────────────────────────────────────────
  int personnelTotal = 0, fonctionnaires = 0, nonFonctionnaires = 0;
  int personnelNouveau = 0;
  final Map<String, int> staffByContract = {};
  final List<DateTime> hireDates = [];

  for (final m in s.staff) {
    final fonc = m.contract == 'permanent';
    staffBySchool[m.schoolId] = (staffBySchool[m.schoolId] ?? 0) + 1;
    if (fonc) foncBySchool[m.schoolId] = (foncBySchool[m.schoolId] ?? 0) + 1;
    if (!keepSchool(m.schoolId)) continue;
    personnelTotal++;
    if (fonc) {
      fonctionnaires++;
    } else {
      nonFonctionnaires++;
    }
    staffByContract[m.contract] = (staffByContract[m.contract] ?? 0) + 1;
    if (_inRange(m.hireDate, start, end)) {
      personnelNouveau++;
      hireDates.add(m.hireDate!);
    }
  }

  // ── Finance (paiements bornés par période) ──────────────────────────────────
  double revenusTotal = 0;
  int paiementsCount = 0;
  final Set<String> studentsPaid = {};
  final List<PaymentRaw> periodPayments = [];

  for (final p in s.payments) {
    revBySchool[p.schoolId] = (revBySchool[p.schoolId] ?? 0) + p.amount;
    payCountBySchool[p.schoolId] = (payCountBySchool[p.schoolId] ?? 0) + 1;
    if (!keepSchool(p.schoolId)) continue;
    if (!_inRange(p.date, start, end)) continue;
    revenusTotal += p.amount;
    paiementsCount++;
    if (p.studentId != null) studentsPaid.add(p.studentId!);
    periodPayments.add(p);
  }

  // ── Classes ───────────────────────────────────────────────────────────────────
  int classesTotal = 0;
  for (final e in s.classesBySchool.entries) {
    if (keepSchool(e.key)) classesTotal += e.value;
  }

  // ── Écoles (scope appliqué pour les compteurs d'établissements) ─────────────
  int schoolsTotal = 0, schoolsActives = 0, publicCount = 0, priveCount = 0;
  final Map<String, int> schoolsByDept = {};
  for (final sc in s.schools) {
    if (!keepSchool(sc.id)) continue;
    schoolsTotal++;
    if (sc.isActive) schoolsActives++;
    switch (sc.type) {
      case 'public':
        publicCount++;
        break;
      case 'prive':
        priveCount++;
        break;
    }
    schoolsByDept[sc.department] = (schoolsByDept[sc.department] ?? 0) + 1;
  }

  // ── Lignes par établissement ────────────────────────────────────────────────
  List<ReportSchoolRow> buildRows(bool scoped) {
    final out = <ReportSchoolRow>[];
    for (final sc in s.schools) {
      if (scoped && !keepSchool(sc.id)) continue;
      out.add(ReportSchoolRow(
        id: sc.id,
        name: sc.name,
        type: sc.type,
        department: sc.department,
        isActive: sc.isActive,
        city: sc.city,
        students: stuBySchool[sc.id] ?? 0,
        studentsM: stuMBySchool[sc.id] ?? 0,
        studentsF: stuFBySchool[sc.id] ?? 0,
        staff: staffBySchool[sc.id] ?? 0,
        fonctionnaires: foncBySchool[sc.id] ?? 0,
        classes: s.classesBySchool[sc.id] ?? 0,
        revenue: revBySchool[sc.id] ?? 0,
        payments: payCountBySchool[sc.id] ?? 0,
      ));
    }
    out.sort((a, b) => b.students.compareTo(a.students));
    return out;
  }

  final scopeLabel = schoolId == null
      ? 'Toutes les écoles'
      : (byId[schoolId]?.name ?? 'École');

  return ReportData(
    mesuresManquantes: s.mesuresManquantes,
    groupName: s.groupName,
    planName: s.planName,
    periodLabel: f.period.label,
    periodStart: start,
    periodEnd: end,
    scopeLabel: scopeLabel,
    schoolsTotal: schoolsTotal,
    schoolsActives: schoolsActives,
    publicCount: publicCount,
    priveCount: priveCount,
    elevesTotal: elevesTotal,
    elevesNouveaux: elevesNouveaux,
    studentsM: studentsM,
    studentsF: studentsF,
    personnelTotal: personnelTotal,
    personnelNouveau: personnelNouveau,
    fonctionnaires: fonctionnaires,
    nonFonctionnaires: nonFonctionnaires,
    classesTotal: classesTotal,
    revenusTotal: revenusTotal,
    paiementsCount: paiementsCount,
    elevesAJour: studentsPaid.length,
    staffByContract: staffByContract,
    schoolsByDept: schoolsByDept,
    studentsByDept: studentsByDept,
    enrollmentTrend: _monthlyCount(enrollDates, start, end),
    hireTrend: _monthlyCount(hireDates, start, end),
    revenueTrend: _monthlyMoney(periodPayments, start, end),
    schoolRows: buildRows(true),
    allSchools: buildRows(false),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS DE SÉRIE TEMPORELLE — bornés exactement par la période choisie
// ════════════════════════════════════════════════════════════════════════════
const List<String> _kMonthLabels = [
  'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
  'jui', 'aoû', 'sep', 'oct', 'nov', 'déc',
];

// Construit la liste ordonnée des mois (clé YYYY-MM + label) entre start et end.
List<(String, String)> _monthKeys(DateTime start, DateTime end) {
  final out = <(String, String)>[];
  var cur = DateTime(start.year, start.month, 1);
  final last = DateTime(end.year, end.month, 1);
  // borne de sécurité (max 36 mois) pour éviter toute boucle dégénérée.
  var guard = 0;
  while (!cur.isAfter(last) && guard < 36) {
    final key = '${cur.year}-${cur.month.toString().padLeft(2, '0')}';
    var label = _kMonthLabels[cur.month - 1];
    // si la période chevauche deux années, on suffixe l'année courte.
    if (start.year != end.year) {
      label = '$label ${cur.year.toString().substring(2)}';
    }
    out.add((key, label));
    cur = DateTime(cur.year, cur.month + 1, 1);
    guard++;
  }
  if (out.isEmpty) {
    final key = '${start.year}-${start.month.toString().padLeft(2, '0')}';
    out.add((key, _kMonthLabels[start.month - 1]));
  }
  return out;
}

List<ReportTrendPoint> _monthlyCount(
    List<DateTime> dates, DateTime start, DateTime end) {
  final months = _monthKeys(start, end);
  final counts = {for (final m in months) m.$1: 0};
  for (final d in dates) {
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
  }
  return [for (final m in months) ReportTrendPoint(m.$2, counts[m.$1] ?? 0)];
}

List<ReportTrendPoint> _monthlyMoney(
    List<PaymentRaw> payments, DateTime start, DateTime end) {
  final months = _monthKeys(start, end);
  final amount = {for (final m in months) m.$1: 0.0};
  final count = {for (final m in months) m.$1: 0};
  for (final p in payments) {
    final d = p.date;
    if (d == null) continue;
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    if (amount.containsKey(key)) {
      amount[key] = amount[key]! + p.amount;
      count[key] = count[key]! + 1;
    }
  }
  return [
    for (final m in months)
      ReportTrendPoint(m.$2, count[m.$1] ?? 0, amount: amount[m.$1] ?? 0)
  ];
}
