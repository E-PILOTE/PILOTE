import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  NOTES D'UNE ÉVALUATION (table `grades`) — une ligne par élève inscrit dans la
//  classe de l'évaluation, jointe à sa note s'il y en a une. Saisie offline :
//  score (sur le barème max_score) ou absent, + appréciation facultative.
// ════════════════════════════════════════════════════════════════════════════

class GradeRow {
  const GradeRow({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.gradeId,
    required this.score,
    required this.isAbsent,
    required this.appreciation,
  });
  final String enrollmentId, studentId, studentName;
  final String? matricule, gradeId, appreciation;
  final double? score;
  final bool isAbsent;

  bool get hasGrade => gradeId != null;
}

/// Élèves actifs de la classe [classId] avec leur note pour l'évaluation [evalId].
typedef _Args = ({String classId, String evalId});

final evalGradesProvider =
    StreamProvider.autoDispose.family<List<GradeRow>, _Args>((ref, args) {
  ref.keepAlive();
  return db
      .watch(
        '''
        SELECT ce.id AS enrollment_id, s.id AS student_id,
               s.first_name, s.last_name, s.matricule,
               g.id AS grade_id, g.score, g.is_absent, g.appreciation
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        LEFT JOIN grades g
               ON g.enrollment_id = ce.id AND g.evaluation_id = ?
        WHERE  ce.class_id = ? AND ce.status = 'active'
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [args.evalId, args.classId],
      )
      .map((rows) => [
            for (final r in rows)
              GradeRow(
                enrollmentId: r['enrollment_id'] as String,
                studentId: r['student_id'] as String,
                studentName: '${(r['last_name'] as String?) ?? ''} '
                        '${(r['first_name'] as String?) ?? ''}'
                    .trim(),
                matricule: r['matricule'] as String?,
                gradeId: r['grade_id'] as String?,
                score: (r['score'] as num?)?.toDouble(),
                isAbsent: ((r['is_absent'] as int?) ?? 0) == 1,
                appreciation: r['appreciation'] as String?,
              ),
          ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
/// Enregistre (insert/update) la note d'un élève. [score] NULL + [isAbsent] →
/// absent ; [score] NULL sans absence → efface la note (si elle existait).
Future<void> upsertGrade({
  required String groupId,
  required String schoolId,
  required String evaluationId,
  required String studentId,
  required String enrollmentId,
  required String createdBy,
  double? score,
  bool isAbsent = false,
  String? appreciation,
  String? existingGradeId,
}) async {
  final now = DateTime.now().toIso8601String();

  // ⚠️ [existingGradeId] n'est qu'une INDICATION : il vient d'un instantané du
  // flux. Saisir 12, se reprendre et saisir 14 dans la seconde — le geste
  // ordinaire d'une grille de notes — arrivait deux fois avec `null`, et
  // INSÉRAIT deux lignes. La base tient `UNIQUE (evaluation_id, student_id)` :
  // 23505, code fatal, LOT ENTIER jeté. On relit donc la note dans la base
  // locale sur sa clé métier.
  final vue = await db.getAll(
    'SELECT id FROM grades WHERE evaluation_id = ? AND student_id = ? LIMIT 1',
    [evaluationId, studentId],
  );
  final gradeId = vue.isNotEmpty ? vue.first['id'] as String : existingGradeId;

  // Ni note ni absence → on retire la ligne existante (note effacée).
  if (score == null && !isAbsent) {
    if (gradeId != null) {
      await db.execute('DELETE FROM grades WHERE id = ?', [gradeId]);
    }
    return;
  }

  if (gradeId != null) {
    await db.execute(
      '''
      UPDATE grades SET score = ?, is_absent = ?, appreciation = ?, updated_at = ?
      WHERE id = ?
      ''',
      [score, isAbsent ? 1 : 0, appreciation?.trim(), now, gradeId],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO grades (
        id, group_id, school_id, evaluation_id, student_id, enrollment_id,
        score, is_absent, appreciation, created_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [idDeterministe('grade', [evaluationId, studentId]),
       groupId, schoolId, evaluationId, studentId, enrollmentId,
       score, isAbsent ? 1 : 0, appreciation?.trim(), createdBy, now, now],
    );
  }
}
