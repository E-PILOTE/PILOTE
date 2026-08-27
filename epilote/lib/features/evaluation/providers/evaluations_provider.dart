import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  ÉVALUATIONS (table `evaluations`) — une évaluation notée (composition, devoir
//  surveillé, séquence, examen, contrôle) pour une classe × matière, avec un
//  barème (max_score), un coefficient, une date et un trimestre. Les NOTES des
//  élèves vivent dans `grades` (1 ligne/élève). Cycle de vie : draft → submitted
//  → validated → published. 100% offline (db.watch / db.execute).
// ════════════════════════════════════════════════════════════════════════════

const kEvaluationTypes = <(String, String)>[
  ('composition', 'Composition'),
  ('devoir_surveille', 'Devoir surveillé'),
  ('sequence', 'Séquence'),
  ('examen', 'Examen'),
  ('controle', 'Contrôle'),
];

String evaluationTypeLabel(String? t) => kEvaluationTypes
    .firstWhere((e) => e.$1 == t, orElse: () => ('controle', 'Contrôle'))
    .$2;

const kEvalStatuses = <(String, String)>[
  ('draft', 'Brouillon'),
  ('submitted', 'Soumise'),
  ('validated', 'Validée'),
  ('published', 'Publiée'),
];

String evalStatusLabel(String? s) => kEvalStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('draft', 'Brouillon'))
    .$2;

class Evaluation {
  const Evaluation({
    required this.id,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.subjectId,
    required this.subjectName,
    required this.trimesterId,
    required this.title,
    required this.type,
    required this.date,
    required this.maxScore,
    required this.coefficient,
    required this.status,
    required this.gradedCount,
    required this.studentCount,
    required this.average,
  });

  final String id, classId, subjectId, title, type, status;
  final String? className, cycleCode, levelCode, subjectName, trimesterId;
  final int levelOrder, coefficient, gradedCount, studentCount;
  final double maxScore;
  final double? average; // moyenne /20 des notes saisies (hors absents)

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';

  /// Validée ou publiée : le chef d'établissement l'a ARRÊTÉE.
  ///
  /// Le cahier des charges (§8.3) réserve la validation à la direction. Tant
  /// que ce mot n'a pas de conséquence, il ne veut rien dire : une évaluation
  /// figée ne se modifie plus, ne se renote plus et ne se supprime plus — sauf
  /// par qui détient précisément le droit `validate` sur `notes`.
  bool get estFigee => status == 'validated' || status == 'published';
  bool get isComplete => studentCount > 0 && gradedCount >= studentCount;

  String get dateLabel {
    final d = date;
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  final DateTime? date;
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Toutes les évaluations de l'école (année active), enrichies des libellés,
/// du nombre de notes saisies et de la moyenne /20.
final evaluationsProvider =
    StreamProvider.autoDispose<List<Evaluation>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT e.id, e.class_id, e.subject_id, e.trimester_id, e.title,
               e.evaluation_type, e.evaluation_date, e.max_score, e.coefficient,
               e.status,
               c.name AS class_name, c.cycle_code AS cycle_code,
               c.level_code AS level_code, c.level_order AS level_order,
               sub.name AS subject_name,
               (SELECT COUNT(*) FROM class_enrollments ce
                  WHERE ce.class_id = e.class_id AND ce.status = 'active')
                 AS student_count,
               (SELECT COUNT(*) FROM grades g WHERE g.evaluation_id = e.id)
                 AS graded_count,
               (SELECT AVG(g.score) FROM grades g
                  WHERE g.evaluation_id = e.id AND g.is_absent = 0
                    AND g.score IS NOT NULL) AS avg_raw
        FROM   evaluations e
        LEFT JOIN classes c    ON c.id = e.class_id
        LEFT JOIN subjects sub ON sub.id = e.subject_id
        WHERE  e.school_id = ? AND e.academic_year_id = ?
        ORDER  BY e.evaluation_date DESC, e.created_at DESC
        ''',
        parameters: [schoolId, yearId ?? ''],
      )
      .map((rows) => [
            for (final r in rows)
              () {
                final max = (r['max_score'] as num?)?.toDouble() ?? 20;
                final avgRaw = (r['avg_raw'] as num?)?.toDouble();
                return Evaluation(
                  id: r['id'] as String,
                  classId: (r['class_id'] as String?) ?? '',
                  className: r['class_name'] as String?,
                  cycleCode: r['cycle_code'] as String?,
                  levelCode: r['level_code'] as String?,
                  levelOrder: (r['level_order'] as int?) ?? 999,
                  subjectId: (r['subject_id'] as String?) ?? '',
                  subjectName: r['subject_name'] as String?,
                  trimesterId: r['trimester_id'] as String?,
                  title: (r['title'] as String?) ?? '',
                  type: (r['evaluation_type'] as String?) ?? 'controle',
                  date: _d(r['evaluation_date']),
                  maxScore: max,
                  coefficient: (r['coefficient'] as int?) ?? 1,
                  status: (r['status'] as String?) ?? 'draft',
                  gradedCount: (r['graded_count'] as int?) ?? 0,
                  studentCount: (r['student_count'] as int?) ?? 0,
                  average:
                      (avgRaw != null && max > 0) ? avgRaw / max * 20 : null,
                );
              }(),
          ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<String> createEvaluation({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String classId,
  required String subjectId,
  String? trimesterId,
  required String title,
  required String type,
  required DateTime date,
  required double maxScore,
  required int coefficient,
  required String createdBy,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO evaluations (
      id, group_id, school_id, class_id, subject_id, academic_year_id,
      trimester_id, title, evaluation_type, evaluation_date, max_score,
      coefficient, created_by, status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?)
    ''',
    [id, groupId, schoolId, classId, subjectId, academicYearId, trimesterId,
     title.trim(), type, date.toIso8601String().substring(0, 10), maxScore,
     coefficient, createdBy, now, now],
  );
  return id;
}

Future<void> updateEvaluation({
  required String id,
  required String title,
  required String type,
  String? trimesterId,
  required DateTime date,
  required double maxScore,
  required int coefficient,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE evaluations
    SET title = ?, evaluation_type = ?, trimester_id = ?, evaluation_date = ?,
        max_score = ?, coefficient = ?, updated_at = ?
    WHERE id = ?
    ''',
    [title.trim(), type, trimesterId, date.toIso8601String().substring(0, 10),
     maxScore, coefficient, now, id],
  );
}

/// Change le statut (cycle de vie). Renseigne les dates/acteurs idoines.
Future<void> setEvaluationStatus({
  required String id,
  required String status,
  String? actorId,
}) async {
  final now = DateTime.now().toIso8601String();
  if (status == 'published') {
    await db.execute(
      'UPDATE evaluations SET status = ?, published_at = ?, updated_at = ? WHERE id = ?',
      [status, now, now, id],
    );
  } else if (status == 'validated') {
    await db.execute(
      'UPDATE evaluations SET status = ?, validated_by = ?, validated_at = ?, updated_at = ? WHERE id = ?',
      [status, actorId, now, now, id],
    );
  } else {
    await db.execute(
      'UPDATE evaluations SET status = ?, updated_at = ? WHERE id = ?',
      [status, now, id],
    );
  }
}

Future<void> deleteEvaluation(String id) async {
  await db.execute('DELETE FROM grades WHERE evaluation_id = ?', [id]);
  await db.execute('DELETE FROM evaluations WHERE id = ?', [id]);
}
