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
    this.photoUrl,
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
  final String? photoUrl;

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
    this.department,
    this.schoolId,
    this.filiere,
    this.gender,
    this.activeOnly = true,
  });

  final String search;

  /// Département administratif. Le ministère raisonne d'abord par territoire,
  /// l'établissement ne vient qu'ensuite — d'où l'ordre des filtres à l'écran.
  final String? department;
  final String? schoolId;

  /// Filière technique. C'est la lentille propre au METP : « combien
  /// d'électrotechniciens, et où ? » est sa question de tous les jours.
  final String? filiere;
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
      department != null ||
      schoolId != null ||
      filiere != null ||
      gender != null ||
      safeSearch.length >= 2;

  /// Filtres actifs, libellés pour l'écran ET pour l'export : un tableau
  /// imprimé sans son périmètre est ininterprétable une semaine plus tard.
  List<(String, String)> get activeFilters => [
        if (safeSearch.isNotEmpty) ('Recherche', safeSearch),
        if (department != null) ('Département', department!),
        if (filiere != null) ('Filière', filiere!),
        if (gender != null) ('Sexe', gender == 'F' ? 'Filles' : 'Garçons'),
        if (!activeOnly) ('Statut', 'Actifs et inactifs'),
      ];

  StudentQuery copyWith({
    String? search,
    Object? department = _keep,
    Object? schoolId = _keep,
    Object? filiere = _keep,
    Object? gender = _keep,
    bool? activeOnly,
  }) =>
      StudentQuery(
        search: search ?? this.search,
        department:
            identical(department, _keep) ? this.department : department as String?,
        schoolId: identical(schoolId, _keep) ? this.schoolId : schoolId as String?,
        filiere: identical(filiere, _keep) ? this.filiere : filiere as String?,
        gender: identical(gender, _keep) ? this.gender : gender as String?,
        activeOnly: activeOnly ?? this.activeOnly,
      );

  static const Object _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is StudentQuery &&
      other.search == search &&
      other.department == department &&
      other.schoolId == schoolId &&
      other.filiere == filiere &&
      other.gender == gender &&
      other.activeOnly == activeOnly;

  @override
  int get hashCode =>
      Object.hash(search, department, schoolId, filiere, gender, activeOnly);
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

/// Filières ouvertes dans le réseau, telles qu'elles sont réellement portées
/// par des classes. On ne propose jamais une nomenclature théorique : une
/// filière qui n'existe nulle part ne ferait qu'offrir un filtre toujours vide.
final groupFilieresProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];
  final rows = await client
      .from('classes')
      .select('filiere_label')
      .eq('group_id', groupId)
      .not('filiere_label', 'is', null);
  final set = <String>{
    for (final r in rows as List)
      if ((r['filiere_label'] as String?)?.trim().isNotEmpty ?? false)
        (r['filiere_label'] as String).trim(),
  };
  return set.toList()..sort();
});

// ─── Tri ────────────────────────────────────────────────────────────────────
//  Le serveur renvoie les 200 premiers par nom ; le tri se fait donc sur cet
//  échantillon, jamais sur le réseau entier. C'est loyal parce que l'écran
//  annonce la troncature — sans ce message, trier par âge laisserait croire
//  qu'on tient le plus jeune du réseau.
enum StudentSort { name, school, filiere, className, age }

class StudentSortState {
  const StudentSortState({this.key = StudentSort.name, this.ascending = true});
  final StudentSort key;
  final bool ascending;

  /// Recliquer la même colonne inverse le sens ; en changer repart en croissant.
  StudentSortState toggled(StudentSort k) => k == key
      ? StudentSortState(key: k, ascending: !ascending)
      : StudentSortState(key: k);
}

final studentSortProvider =
    StateProvider.autoDispose<StudentSortState>((ref) => const StudentSortState());

/// Valeur triable d'une colonne — `null` quand la donnée manque.
Object? _sortKey(StudentSort k, GroupStudent s) {
  final v = switch (k) {
    StudentSort.name => s.fullName,
    StudentSort.school => s.schoolName,
    StudentSort.filiere => s.filiere,
    StudentSort.className => s.className,
    StudentSort.age => s.age,
  };
  if (v is String) return v.trim().isEmpty ? null : v.toLowerCase();
  return v;
}

List<GroupStudent> sortStudents(List<GroupStudent> rows, StudentSortState s) {
  final out = [...rows];
  out.sort((a, b) {
    final ka = _sortKey(s.key, a);
    final kb = _sortKey(s.key, b);
    final byName = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());

    // Une valeur absente coule TOUJOURS en fin de liste, y compris en tri
    // décroissant : elle est traitée AVANT l'inversion de sens, sinon les
    // « — » remonteraient en tête et se liraient comme un résultat.
    if (ka == null || kb == null) {
      if (ka == null && kb == null) return byName;
      return ka == null ? 1 : -1;
    }

    final c = ka is int ? ka.compareTo(kb as int) : (ka as String).compareTo(kb as String);
    // Départage stable par nom : deux élèves d'une même école ne doivent pas
    // changer d'ordre d'un rafraîchissement à l'autre.
    return c != 0 ? (s.ascending ? c : -c) : byName;
  });
  return out;
}

final studentSearchProvider =
    FutureProvider.autoDispose<StudentSearchResult>((ref) async {
  final query = ref.watch(studentQueryProvider);
  if (!query.isRunnable) return StudentSearchResult.empty;

  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return StudentSearchResult.empty;

  final currentYears = await ref.watch(currentYearIdsProvider.future);

  // Filtrer sur une filière oblige à INNER-joindre l'inscription et la classe :
  // sinon PostgREST rapporte l'élève avec une liste d'inscriptions vidée par le
  // filtre, ce qui ferait passer un élève d'une autre filière pour un « sans
  // classe ». Hors filtre filière on garde le LEFT JOIN, faute de quoi les
  // élèves non affectés — précisément ceux qu'un ministère cherche —
  // disparaîtraient de la liste.
  final byFiliere = query.filiere != null;
  final join = byFiliere ? '!inner' : '';

  // `dynamic` : chaque filtre PostgREST renvoie un builder d'un type différent ;
  // le chaînage conditionnel ne se type pas autrement (même motif que l'audit).
  dynamic q = client
      .from('students')
      .select('id, matricule, first_name, last_name, gender, date_of_birth, '
          'is_active, has_scholarship, photo_url, '
          'schools!inner(name, department), '
          // `!class_enrollments_class_id_fkey` est OBLIGATOIRE : la table porte
          // DEUX clés vers `classes` (`class_id` et `previous_class_id`). Sans
          // ce désambiguïsateur, PostgREST refuse l'imbrication (« more than
          // one relationship was found ») et l'écran entier tombe en erreur.
          'class_enrollments$join(status, academic_year_id, '
          'classes!class_enrollments_class_id_fkey$join('
          'name, cycle_code, level_code, filiere_label))')
      .eq('group_id', groupId);

  if (query.department != null) {
    q = q.eq('schools.department', query.department!);
  }
  if (query.schoolId != null) q = q.eq('school_id', query.schoolId!);
  if (query.gender != null) q = q.eq('gender', query.gender!);
  if (query.activeOnly) q = q.eq('is_active', true);

  if (byFiliere) {
    q = q.eq('class_enrollments.classes.filiere_label', query.filiere!);
    // Cadrage sur l'année en cours : sans lui, un élève ayant quitté la filière
    // l'an dernier ressortirait comme s'il y était encore.
    if (currentYears.isNotEmpty) {
      q = q.inFilter(
          'class_enrollments.academic_year_id', currentYears.toList());
    }
  }

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
    photoUrl: r['photo_url'] as String?,
  );
}
