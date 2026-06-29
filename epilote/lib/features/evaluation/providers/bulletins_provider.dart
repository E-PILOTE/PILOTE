import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  BULLETINS (tables `bulletins` + `bulletin_subject_lines`) — relevés de notes
//  par élève × trimestre. Calculés à partir des `grades` : moyenne par matière
//  (notes /20 pondérées par le coefficient de l'évaluation), moyenne générale
//  (pondérée par le coefficient de la matière), rang, mention. Le calcul est
//  fait offline (db) ; la « génération » persiste le résultat (cycle de vie
//  draft → submitted → validated → published). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

/// Mention selon la moyenne /20 (aligné sur la fonction SQL `get_mention`).
String mentionFor(double? avg) {
  if (avg == null) return '—';
  if (avg >= 16) return 'Excellent';
  if (avg >= 14) return 'Très Bien';
  if (avg >= 12) return 'Bien';
  if (avg >= 10) return 'Assez Bien';
  if (avg >= 8) return 'Passable';
  return 'Insuffisant';
}

class SubjectLine {
  const SubjectLine({
    required this.subjectId,
    required this.subjectName,
    required this.coefficient,
    required this.average,
    required this.classAverage,
    required this.rank,
  });
  final String subjectId, subjectName;
  final int coefficient;
  final double? average; // /20, null si aucune note
  final double? classAverage;
  final int? rank;

  double? get weighted => average == null ? null : average! * coefficient;
}

class StudentBulletin {
  const StudentBulletin({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.overallAverage,
    required this.rank,
    required this.totalStudents,
    required this.lines,
    required this.persisted,
    required this.status,
    this.decision,
    this.councilAppreciation,
    this.directorComment,
  });
  final String enrollmentId, studentId, studentName;
  final String? matricule;
  final double? overallAverage; // /20
  final int rank, totalStudents;
  final List<SubjectLine> lines;
  final bool persisted; // un bulletin existe déjà en base
  final String status; // statut du bulletin persisté (ou 'draft')
  // Sortie du conseil de classe (délibération) — portée par le bulletin.
  final String? decision; // distinction attribuée (code, cf. conseils_provider)
  final String? councilAppreciation; // appréciation du conseil (teacher_comment)
  final String? directorComment; // synthèse / avis du chef d'établissement

  String get mention => mentionFor(overallAverage);
}

class BulletinComputation {
  const BulletinComputation({
    required this.students,
    required this.classAverage,
    required this.evaluationCount,
  });
  final List<StudentBulletin> students;
  final double? classAverage; // moyenne générale de la classe
  final int evaluationCount;
}

typedef BulletinArgs = ({String classId, String? trimesterId});

/// Calcul des bulletins d'une classe pour un trimestre, depuis les `grades`.
final bulletinComputationProvider = FutureProvider.autoDispose
    .family<BulletinComputation, BulletinArgs>((ref, args) async {
  ref.keepAlive();
  final trimClause =
      args.trimesterId != null ? 'AND e.trimester_id = ?' : '';
  final evalParams = <Object?>[args.classId];
  if (args.trimesterId != null) evalParams.add(args.trimesterId);

  // 1) Évaluations de la classe (et trimestre) avec barème + coefficient.
  final evals = await db.getAll(
    'SELECT id, subject_id, coefficient, max_score FROM evaluations e '
    'WHERE e.class_id = ? $trimClause',
    evalParams,
  );
  final evalCoef = <String, int>{};
  final evalMax = <String, double>{};
  final evalSubject = <String, String>{};
  for (final e in evals) {
    final id = e['id'] as String;
    evalCoef[id] = (e['coefficient'] as int?) ?? 1;
    evalMax[id] = (e['max_score'] as num?)?.toDouble() ?? 20;
    evalSubject[id] = (e['subject_id'] as String?) ?? '';
  }

  // 2) Coefficient + nom de chaque matière de la classe.
  final subjRows = await db.getAll(
    '''
    SELECT cs.subject_id AS sid,
           COALESCE(cs.coefficient, subj.coefficient) AS coef,
           subj.name AS name
    FROM class_subjects cs
    JOIN subjects subj ON subj.id = cs.subject_id
    WHERE cs.class_id = ?
    ORDER BY subj.name
    ''',
    [args.classId],
  );
  final subjCoef = <String, int>{};
  final subjName = <String, String>{};
  for (final s in subjRows) {
    final id = s['sid'] as String;
    subjCoef[id] = (s['coef'] as num?)?.toInt() ?? 1;
    subjName[id] = (s['name'] as String?) ?? '—';
  }

  // 3) Élèves actifs de la classe.
  final studentRows = await db.getAll(
    '''
    SELECT ce.id AS enrollment_id, s.id AS student_id,
           s.first_name, s.last_name, s.matricule
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    [args.classId],
  );

  // 4) Toutes les notes des évaluations concernées.
  final gradeRows = await db.getAll(
    '''
    SELECT g.enrollment_id, g.evaluation_id, g.score, g.is_absent
    FROM grades g
    JOIN evaluations e ON e.id = g.evaluation_id
    WHERE e.class_id = ? $trimClause
    ''',
    evalParams,
  );
  // enrollment → subject → list of (normalized score, evalCoef)
  final byStudentSubject = <String, Map<String, List<(double, int)>>>{};
  for (final g in gradeRows) {
    if (((g['is_absent'] as int?) ?? 0) == 1) continue;
    final score = (g['score'] as num?)?.toDouble();
    if (score == null) continue;
    final evalId = g['evaluation_id'] as String;
    final subj = evalSubject[evalId] ?? '';
    final max = evalMax[evalId] ?? 20;
    final coef = evalCoef[evalId] ?? 1;
    final norm = max > 0 ? score / max * 20 : 0.0;
    final enr = g['enrollment_id'] as String;
    ((byStudentSubject[enr] ??= {})[subj] ??= []).add((norm, coef));
  }

  // 5) Persistance existante (bulletins déjà générés) pour le statut.
  final existing = await db.getAll(
    'SELECT enrollment_id, status, decision, teacher_comment, director_comment '
    'FROM bulletins WHERE '
    '${args.trimesterId != null ? 'trimester_id = ?' : '1=1'} '
    'AND enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)',
    args.trimesterId != null
        ? [args.trimesterId, args.classId]
        : [args.classId],
  );
  final statusByEnr = {
    for (final r in existing)
      r['enrollment_id'] as String: (r['status'] as String?) ?? 'draft'
  };
  final councilByEnr = {
    for (final r in existing)
      r['enrollment_id'] as String: (
        decision: r['decision'] as String?,
        appreciation: r['teacher_comment'] as String?,
        director: r['director_comment'] as String?,
      )
  };

  // 6) Moyenne par matière par élève.
  final subjAvg = <String, Map<String, double>>{}; // enr → subj → avg/20
  for (final entry in byStudentSubject.entries) {
    for (final se in entry.value.entries) {
      var sw = 0.0;
      var wc = 0;
      for (final (n, c) in se.value) {
        sw += n * c;
        wc += c;
      }
      if (wc > 0) (subjAvg[entry.key] ??= {})[se.key] = sw / wc;
    }
  }

  // 7) Moyennes de classe par matière (pour rang matière + class_average).
  final subjClassValues = <String, List<double>>{};
  for (final m in subjAvg.values) {
    for (final e in m.entries) {
      (subjClassValues[e.key] ??= []).add(e.value);
    }
  }
  final subjClassAvg = <String, double>{
    for (final e in subjClassValues.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length
  };

  // 8) Construction des bulletins élève + moyenne générale.
  final tmp = <(String enr, double? overall, List<SubjectLine> lines)>[];
  for (final st in studentRows) {
    final enr = st['enrollment_id'] as String;
    final avgMap = subjAvg[enr] ?? const {};
    final lines = <SubjectLine>[];
    var weightedSum = 0.0;
    var coefSum = 0;
    for (final sid in subjCoef.keys) {
      final a = avgMap[sid];
      final coef = subjCoef[sid] ?? 1;
      lines.add(SubjectLine(
        subjectId: sid,
        subjectName: subjName[sid] ?? '—',
        coefficient: coef,
        average: a,
        classAverage: subjClassAvg[sid],
        rank: null, // calculé ci-dessous
      ));
      if (a != null) {
        weightedSum += a * coef;
        coefSum += coef;
      }
    }
    final overall = coefSum > 0 ? weightedSum / coefSum : null;
    tmp.add((enr, overall, lines));
  }

  // 9) Rang par matière.
  final subjRankMap = <String, Map<String, int>>{}; // subj → enr → rank
  for (final sid in subjCoef.keys) {
    final pairs = <(String, double)>[];
    for (final t in tmp) {
      final a = (subjAvg[t.$1] ?? const {})[sid];
      if (a != null) pairs.add((t.$1, a));
    }
    pairs.sort((x, y) => y.$2.compareTo(x.$2));
    for (var i = 0; i < pairs.length; i++) {
      (subjRankMap[sid] ??= {})[pairs[i].$1] = i + 1;
    }
  }

  // 10) Rang général.
  final ranked = [...tmp]..sort((a, b) {
      final av = a.$2, bv = b.$2;
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    });
  final overallRank = <String, int>{};
  for (var i = 0; i < ranked.length; i++) {
    if (ranked[i].$2 != null) overallRank[ranked[i].$1] = i + 1;
  }

  final total = studentRows.length;
  final students = <StudentBulletin>[];
  for (final st in studentRows) {
    final enr = st['enrollment_id'] as String;
    final t = tmp.firstWhere((e) => e.$1 == enr);
    final lines = [
      for (final l in t.$3)
        SubjectLine(
          subjectId: l.subjectId,
          subjectName: l.subjectName,
          coefficient: l.coefficient,
          average: l.average,
          classAverage: l.classAverage,
          rank: subjRankMap[l.subjectId]?[enr],
        ),
    ];
    students.add(StudentBulletin(
      enrollmentId: enr,
      studentId: st['student_id'] as String,
      studentName: '${(st['last_name'] as String?) ?? ''} '
              '${(st['first_name'] as String?) ?? ''}'
          .trim(),
      matricule: st['matricule'] as String?,
      overallAverage: t.$2,
      rank: overallRank[enr] ?? 0,
      totalStudents: total,
      lines: lines,
      persisted: statusByEnr.containsKey(enr),
      status: statusByEnr[enr] ?? 'draft',
      decision: councilByEnr[enr]?.decision,
      councilAppreciation: councilByEnr[enr]?.appreciation,
      directorComment: councilByEnr[enr]?.director,
    ));
  }
  students.sort((a, b) {
    if (a.rank == 0 && b.rank == 0) return 0;
    if (a.rank == 0) return 1;
    if (b.rank == 0) return -1;
    return a.rank.compareTo(b.rank);
  });

  final classVals = [
    for (final s in students)
      if (s.overallAverage != null) s.overallAverage!
  ];
  final classAvg = classVals.isEmpty
      ? null
      : classVals.reduce((a, b) => a + b) / classVals.length;

  return BulletinComputation(
    students: students,
    classAverage: classAvg,
    evaluationCount: evals.length,
  );
});

// ─── Génération / persistance (offline-first) ────────────────────────────────
/// Persiste (ou met à jour) les bulletins calculés d'une classe pour un
/// trimestre, avec leurs lignes-matières. Statut initial 'draft'.
Future<int> generateBulletins({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String trimesterId,
  required BulletinComputation comp,
}) async {
  final now = DateTime.now().toIso8601String();
  var count = 0;
  for (final s in comp.students) {
    // Bulletin existant ?
    final ex = await db.getAll(
      'SELECT id FROM bulletins WHERE enrollment_id = ? AND trimester_id = ?',
      [s.enrollmentId, trimesterId],
    );
    final mention = mentionFor(s.overallAverage);
    String bulletinId;
    if (ex.isNotEmpty) {
      bulletinId = ex.first['id'] as String;
      await db.execute(
        '''
        UPDATE bulletins SET overall_average = ?, class_average = ?, rank = ?,
          total_students = ?, mention = ?, updated_at = ?
        WHERE id = ?
        ''',
        [s.overallAverage, comp.classAverage, s.rank == 0 ? null : s.rank,
         s.totalStudents, mention, now, bulletinId],
      );
      await db.execute(
          'DELETE FROM bulletin_subject_lines WHERE bulletin_id = ?',
          [bulletinId]);
    } else {
      bulletinId = _uuid.v4();
      await db.execute(
        '''
        INSERT INTO bulletins (
          id, group_id, school_id, student_id, enrollment_id, academic_year_id,
          trimester_id, overall_average, class_average, rank, total_students,
          mention, total_absences, total_lates, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'draft', ?, ?)
        ''',
        [bulletinId, groupId, schoolId, s.studentId, s.enrollmentId,
         academicYearId, trimesterId, s.overallAverage, comp.classAverage,
         s.rank == 0 ? null : s.rank, s.totalStudents, mention, now, now],
      );
    }
    for (final l in s.lines) {
      await db.execute(
        '''
        INSERT INTO bulletin_subject_lines (
          id, bulletin_id, subject_id, group_id, average, class_average, rank,
          coefficient, weighted_average, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [_uuid.v4(), bulletinId, l.subjectId, groupId, l.average,
         l.classAverage, l.rank, l.coefficient, l.weighted, now, now],
      );
    }
    count++;
  }
  return count;
}

/// Change le statut de tous les bulletins d'une classe×trimestre.
Future<void> setBulletinsStatus({
  required String classId,
  required String trimesterId,
  required String status,
  String? actorId,
}) async {
  final now = DateTime.now().toIso8601String();
  final col = switch (status) {
    'published' => 'published_at',
    'validated' => 'validated_at',
    'submitted' => 'submitted_at',
    _ => null,
  };
  final actorCol = switch (status) {
    'published' => null,
    'validated' => 'validated_by',
    'submitted' => 'submitted_by',
    _ => null,
  };
  final sets = <String>['status = ?', 'updated_at = ?'];
  final params = <Object?>[status, now];
  if (col != null) {
    sets.add('$col = ?');
    params.add(now);
  }
  if (actorCol != null) {
    sets.add('$actorCol = ?');
    params.add(actorId);
  }
  params.addAll([trimesterId, classId]);
  await db.execute(
    'UPDATE bulletins SET ${sets.join(', ')} WHERE trimester_id = ? '
    'AND enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)',
    params,
  );
}
