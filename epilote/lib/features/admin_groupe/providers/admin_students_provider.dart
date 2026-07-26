import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉLÈVES DU RÉSEAU — recherche transversale du ministère (admin_groupe).
//
//  ── POURQUOI UNE RECHERCHE, ET PAS UNE LISTE ────────────────────────────────
//  Un groupe national vise plus de 1 000 écoles, soit des centaines de milliers
//  d'élèves. Charger « la liste des élèves » côté client serait tenable
//  aujourd'hui (quelques centaines) et intenable demain. L'écran est donc bâti
//  d'emblée comme une RECHERCHE SERVEUR bornée : on part d'un critère (un nom,
//  un matricule, un établissement), le serveur filtre, et la réponse est
//  plafonnée. Rien à réécrire au passage à l'échelle.
//
//  ── PÉRIMÈTRE DE DONNÉES — volontairement restreint ─────────────────────────
//  Le ministère consulte l'IDENTITÉ et la SCOLARITÉ. Les champs sensibles —
//  médical (groupe sanguin, allergies) et discipline — ne sont pas demandés :
//  ils relèvent de l'établissement, et la plateforme les cloisonne déjà pour
//  le personnel (`sync_medical` / `sync_discipline`). Ne pas les requêter ici
//  est la même règle, appliquée un cran plus haut.
//
//  Lecture seule : le ministère pilote, il ne saisit pas à la place de l'école.
// ════════════════════════════════════════════════════════════════════════════

/// Plafond de résultats. Au-delà, on demande d'affiner plutôt que de tronquer
/// en silence : une liste coupée sans le dire ferait croire à un effectif faux.
const int kStudentSearchLimit = 200;

class GroupStudent {
  const GroupStudent({
    required this.id,
    required this.fullName,
    required this.schoolName,
    required this.isActive,
    this.matricule,
    this.gender,
    this.dateOfBirth,
    this.department,
    this.className,
    this.filiere,
    this.cycleCode,
    this.levelCode,
    this.enrollmentStatus,
    this.hasScholarship = false,
  });

  final String id;
  final String fullName;
  final String schoolName;
  final bool isActive;
  final String? matricule;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? department;
  final String? className;
  final String? filiere;
  final String? cycleCode;
  final String? levelCode;
  final String? enrollmentStatus;
  final bool hasScholarship;

  bool get isFemale => gender == 'F';

  /// Âge révolu au jour de consultation. `null` si la date manque — un âge
  /// inventé sur une date absente serait pire que pas d'âge du tout.
  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 120 ? null : a;
  }

  /// Non inscrit dans une classe pour l'année courante : le cas qui intéresse
  /// un ministère (un élève enregistré mais sans affectation).
  bool get isUnplaced => className == null;
}

/// Critères de recherche. Tous facultatifs, mais il en faut AU MOINS UN : une
/// recherche sans critère sur un réseau national n'a pas de sens.
class StudentQuery {
  const StudentQuery({
    this.search = '',
    this.schoolId,
    this.gender,
    this.activeOnly = true,
  });

  final String search;
  final String? schoolId;
  final String? gender;
  final bool activeOnly;

  /// Le terme saisi, débarrassé de ce qui casserait la syntaxe de filtre
  /// PostgREST (virgules, parenthèses, jokers). Sans ce nettoyage, une virgule
  /// tapée par mégarde transforme le filtre en une autre requête.
  String get safeSearch =>
      search.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  /// Une recherche par nom exige 2 caractères : en dessous, elle ramènerait
  /// une part énorme du réseau pour rien.
  bool get isRunnable =>
      schoolId != null || gender != null || safeSearch.length >= 2;

  StudentQuery copyWith({
    String? search,
    Object? schoolId = _keep,
    Object? gender = _keep,
    bool? activeOnly,
  }) =>
      StudentQuery(
        search: search ?? this.search,
        schoolId: identical(schoolId, _keep) ? this.schoolId : schoolId as String?,
        gender: identical(gender, _keep) ? this.gender : gender as String?,
        activeOnly: activeOnly ?? this.activeOnly,
      );

  static const Object _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is StudentQuery &&
      other.search == search &&
      other.schoolId == schoolId &&
      other.gender == gender &&
      other.activeOnly == activeOnly;

  @override
  int get hashCode => Object.hash(search, schoolId, gender, activeOnly);
}

final studentQueryProvider =
    StateProvider.autoDispose<StudentQuery>((ref) => const StudentQuery());

class StudentSearchResult {
  const StudentSearchResult({required this.students, required this.truncated});
  final List<GroupStudent> students;

  /// Vrai si le plafond a été atteint : l'écran doit le DIRE.
  final bool truncated;

  static const empty = StudentSearchResult(students: [], truncated: false);
}

/// Effectif total du réseau — un `count` serveur, jamais un `length` de liste.
final groupStudentCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return 0;
  return client
      .from('students')
      .count(CountOption.exact)
      .eq('group_id', groupId)
      .eq('is_active', true);
});

/// Identifiants des années scolaires COURANTES du groupe : sert à retenir la
/// bonne inscription quand un élève en compte plusieurs (années successives).
final currentYearIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const {};
  final rows = await client
      .from('academic_years')
      .select('id')
      .eq('group_id', groupId)
      .eq('is_current', true);
  return {for (final r in rows as List) r['id'] as String};
});

final studentSearchProvider =
    FutureProvider.autoDispose<StudentSearchResult>((ref) async {
  final query = ref.watch(studentQueryProvider);
  if (!query.isRunnable) return StudentSearchResult.empty;

  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return StudentSearchResult.empty;

  final currentYears = await ref.watch(currentYearIdsProvider.future);

  // `dynamic` : chaque filtre PostgREST renvoie un builder d'un type différent ;
  // le chaînage conditionnel ne se type pas autrement (même motif que l'audit).
  dynamic q = client
      .from('students')
      .select('id, matricule, first_name, last_name, gender, date_of_birth, '
          'is_active, has_scholarship, '
          'schools!inner(name, department), '
          // `!class_enrollments_class_id_fkey` est OBLIGATOIRE : la table porte
          // DEUX clés vers `classes` (`class_id` et `previous_class_id`). Sans
          // ce désambiguïsateur, PostgREST refuse l'imbrication (« more than
          // one relationship was found ») et l'écran entier tombe en erreur.
          'class_enrollments(status, academic_year_id, '
          'classes!class_enrollments_class_id_fkey('
          'name, cycle_code, level_code, filiere_label))')
      .eq('group_id', groupId);

  if (query.schoolId != null) q = q.eq('school_id', query.schoolId!);
  if (query.gender != null) q = q.eq('gender', query.gender!);
  if (query.activeOnly) q = q.eq('is_active', true);

  final term = query.safeSearch;
  if (term.length >= 2) {
    q = q.or('first_name.ilike.%$term%,last_name.ilike.%$term%,'
        'matricule.ilike.%$term%');
  }

  // limit+1 : une ligne de trop suffit à savoir qu'il y en avait davantage.
  final rows = await q
      .order('last_name', ascending: true)
      .limit(kStudentSearchLimit + 1) as List;

  final truncated = rows.length > kStudentSearchLimit;
  final kept = truncated ? rows.take(kStudentSearchLimit) : rows;

  return StudentSearchResult(
    students: [
      for (final r in kept) _toStudent(r as Map<String, dynamic>, currentYears),
    ],
    truncated: truncated,
  );
});

GroupStudent _toStudent(Map<String, dynamic> r, Set<String> currentYears) {
  final school = r['schools'] as Map<String, dynamic>?;
  final first = (r['first_name'] as String?)?.trim() ?? '';
  final last = (r['last_name'] as String?)?.trim() ?? '';

  // Inscription retenue : celle d'une année COURANTE. À défaut, la dernière
  // connue — mais on ne fait jamais passer une inscription d'une année révolue
  // pour la situation actuelle sans que l'écran puisse le distinguer.
  final enrollments = (r['class_enrollments'] as List?) ?? const [];
  Map<String, dynamic>? chosen;
  for (final e in enrollments) {
    final m = e as Map<String, dynamic>;
    if (currentYears.contains(m['academic_year_id'])) {
      chosen = m;
      break;
    }
  }
  final klass = chosen?['classes'] as Map<String, dynamic>?;

  return GroupStudent(
    id: r['id'] as String? ?? '',
    fullName: '$first $last'.trim().isEmpty ? 'Élève sans nom' : '$first $last'.trim(),
    schoolName: (school?['name'] as String?) ?? '—',
    department: school?['department'] as String?,
    isActive: r['is_active'] != false,
    matricule: r['matricule'] as String?,
    gender: r['gender'] as String?,
    dateOfBirth: DateTime.tryParse('${r['date_of_birth']}'),
    className: klass?['name'] as String?,
    filiere: klass?['filiere_label'] as String?,
    cycleCode: klass?['cycle_code'] as String?,
    levelCode: klass?['level_code'] as String?,
    enrollmentStatus: chosen?['status'] as String?,
    hasScholarship: r['has_scholarship'] == true,
  );
}
