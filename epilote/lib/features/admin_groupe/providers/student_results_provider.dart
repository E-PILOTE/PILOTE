import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉSULTATS PAR MATIÈRE — le profil scolaire de l'élève, dans son dossier.
//
//  ── POURQUOI LES NOTES, ET PAS SEULEMENT L'ÉQUIPE ENSEIGNANTE ───────────────
//  Savoir QUI enseigne une classe relève de l'organisation ; savoir CE QUE
//  l'élève obtient, matière par matière, est ce qui permet d'instruire un cas —
//  une bourse, une réorientation, un signalement. L'enseignement technique
//  compte de nombreuses matières, générales et professionnelles : c'est
//  justement la répartition entre les deux qui révèle un profil.
//
//  ── CE QUE CES MOYENNES SONT, ET NE SONT PAS ────────────────────────────────
//  Ce sont des notes de CONTRÔLE CONTINU, propres à l'établissement. Elles
//  décrivent un élève dans sa classe ; elles ne classent PAS des élèves entre
//  établissements — professeurs, sujets et exigences y diffèrent. C'est la même
//  règle que pour le palmarès, qui ne retient que l'examen d'État. La moyenne
//  de la classe est affichée à côté de celle de l'élève pour cette raison
//  précise : 12/20 dans une classe à 9 de moyenne ne se lit pas comme 12/20
//  dans une classe à 15.
//
//  ── DEUX PIÈGES DE CALCUL, TENUS ICI ────────────────────────────────────────
//  • Une ABSENCE n'est pas un zéro. Une note absente est exclue de la moyenne,
//    jamais comptée 0 — l'inverse fabriquerait un élève en échec.
//  • Un barème n'est pas toujours sur 20. Chaque note est ramenée sur 20 via le
//    `max_score` de son évaluation avant toute moyenne.
// ════════════════════════════════════════════════════════════════════════════

/// Résultat d'une matière pour un élève.
class SubjectResult {
  const SubjectResult({
    required this.subject,
    required this.coefficient,
    required this.gradeCount,
    this.average,
    this.classAverage,
    this.teacher,
  });

  final String subject;
  final int coefficient;

  /// Nombre de notes retenues (les absences n'en font pas partie).
  final int gradeCount;

  /// Moyenne de l'élève, sur 20. `null` si aucune note : la matière est alors
  /// affichée « non évaluée », jamais à 0.
  final double? average;

  /// Moyenne de la classe dans la matière — l'étalon qui rend la note lisible.
  final double? classAverage;

  final String? teacher;

  /// Écart à la classe : positif = au-dessus. `null` si l'un des deux manque.
  double? get delta =>
      (average == null || classAverage == null) ? null : average! - classAverage!;
}

class StudentResults {
  const StudentResults({
    required this.subjects,
    this.overall,
    this.classOverall,
  });

  final List<SubjectResult> subjects;

  /// Moyenne générale, pondérée par les coefficients de matière.
  final double? overall;
  final double? classOverall;

  bool get isEmpty => subjects.isEmpty;

  /// Matières réellement notées — celles qui portent l'information.
  int get evaluatedCount => subjects.where((s) => s.average != null).length;

  static const empty = StudentResults(subjects: []);
}

/// Clé de la requête : les résultats n'existent que pour un élève DANS une
/// classe SUR une année. Les trois sont nécessaires, aucun n'est déductible.
class ResultsKey {
  const ResultsKey({
    required this.studentId,
    required this.classId,
    required this.academicYearId,
  });

  final String studentId;
  final String classId;
  final String academicYearId;

  @override
  bool operator ==(Object other) =>
      other is ResultsKey &&
      other.studentId == studentId &&
      other.classId == classId &&
      other.academicYearId == academicYearId;

  @override
  int get hashCode => Object.hash(studentId, classId, academicYearId);
}

final studentResultsProvider =
    FutureProvider.autoDispose.family<StudentResults, ResultsKey>((ref, k) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return StudentResults.empty;

  // On charge les évaluations PUBLIÉES de la classe avec les notes de TOUS ses
  // élèves : c'est ce qui permet de calculer, d'une seule requête, la moyenne
  // de l'élève et celle de la classe. Une évaluation non publiée n'est pas un
  // résultat — un brouillon de l'enseignant n'a rien à faire dans un dossier
  // consulté par le ministère.
  final rows = await client
      .from('evaluations')
      .select('subject_id, coefficient, max_score, '
          'subjects!inner(name, coefficient), '
          'grades(student_id, score, is_absent)')
      .eq('group_id', groupId)
      .eq('class_id', k.classId)
      .eq('academic_year_id', k.academicYearId)
      .eq('status', 'published');

  return computeResults(rows as List, k.studentId);
});

/// Calcul des moyennes à partir des évaluations publiées d'une classe.
///
/// Fonction PURE, séparée de la requête pour être testable : ce sont ces règles
/// — et non le réseau — qui décident si un élève paraît en échec.
StudentResults computeResults(List rows, String studentId) {
  // Accumulateurs par matière : somme pondérée et somme des coefficients, pour
  // l'élève d'un côté, pour la classe de l'autre.
  final acc = <String, _Acc>{};

  for (final r in rows) {
    final m = r as Map<String, dynamic>;
    final subject = m['subjects'] as Map<String, dynamic>?;
    final name = (subject?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    final evalCoef = (m['coefficient'] as num?)?.toDouble() ?? 1;
    final maxScore = (m['max_score'] as num?)?.toDouble() ?? 20;
    if (maxScore <= 0) continue;

    final a = acc.putIfAbsent(
      name,
      () => _Acc(
        subjectCoef: (subject?['coefficient'] as num?)?.toInt() ?? 1,
      ),
    );

    for (final g in (m['grades'] as List?) ?? const []) {
      final gm = g as Map<String, dynamic>;
      // Absence : la note n'existe pas. La compter 0 inventerait un échec.
      if (gm['is_absent'] == true) continue;
      final score = (gm['score'] as num?)?.toDouble();
      if (score == null) continue;

      final on20 = score / maxScore * 20;
      a.classSum += on20 * evalCoef;
      a.classWeight += evalCoef;

      if (gm['student_id'] == studentId) {
        a.sum += on20 * evalCoef;
        a.weight += evalCoef;
        a.count++;
      }
    }
  }

  final subjects = [
    for (final e in acc.entries)
      SubjectResult(
        subject: e.key,
        coefficient: e.value.subjectCoef,
        gradeCount: e.value.count,
        average: e.value.weight == 0 ? null : e.value.sum / e.value.weight,
        classAverage: e.value.classWeight == 0
            ? null
            : e.value.classSum / e.value.classWeight,
      ),
  ]..sort((a, b) => a.subject.toLowerCase().compareTo(b.subject.toLowerCase()));

  return StudentResults(
    subjects: subjects,
    overall: _weighted(subjects, (s) => s.average),
    classOverall: _weighted(subjects, (s) => s.classAverage),
  );
}

/// Moyenne générale : chaque matière pèse son coefficient. Une matière non
/// évaluée est ignorée — elle ne doit ni tirer la moyenne vers le bas, ni
/// disparaître silencieusement du tableau (elle y reste, marquée non évaluée).
double? _weighted(List<SubjectResult> subjects, double? Function(SubjectResult) pick) {
  var sum = 0.0;
  var weight = 0.0;
  for (final s in subjects) {
    final v = pick(s);
    if (v == null) continue;
    final c = s.coefficient <= 0 ? 1 : s.coefficient;
    sum += v * c;
    weight += c;
  }
  return weight == 0 ? null : sum / weight;
}

class _Acc {
  _Acc({required this.subjectCoef});
  final int subjectCoef;
  double sum = 0;
  double weight = 0;
  double classSum = 0;
  double classWeight = 0;
  int count = 0;
}
