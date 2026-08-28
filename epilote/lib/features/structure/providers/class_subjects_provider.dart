import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';

/// Une affectation « matière dispensée dans une classe » (table `class_subjects`),
/// enrichie du coefficient effectif, du professeur (via teacher_subjects) et de
/// l'effectif réel (élèves actifs de la classe).
class SubjectAssignment {
  const SubjectAssignment({
    required this.id,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.filiereLabel,
    required this.coefOverride,
    required this.niveauCoef,
    required this.weeklyHours,
    required this.teacherId,
    required this.teacherName,
    required this.studentCount,
  });

  final String id;
  final String classId;
  final String className;
  final String? cycleCode;
  final String? levelCode;
  final int levelOrder;
  final String? filiereLabel;
  final int? coefOverride; // NULL = hérite du niveau
  final int niveauCoef; // coef par défaut du niveau (subjects.coefficient)
  final int? weeklyHours;
  final String? teacherId;
  final String? teacherName;
  final int studentCount;

  /// Coefficient réellement appliqué dans cette classe.
  int get effectiveCoef => coefOverride ?? niveauCoef;

  /// L'enseignant diffère-t-il du coef de référence du niveau ?
  bool get hasOverride => coefOverride != null && coefOverride != niveauCoef;

  bool get hasTeacher => (teacherName ?? '').trim().isNotEmpty;
  String get teacherLabel => hasTeacher ? teacherName!.trim() : 'Non affecté';
}

/// Affectations d'une matière (toutes les classes où elle est dispensée).
final subjectAssignmentsProvider = StreamProvider.autoDispose
    .family<List<SubjectAssignment>, String>((ref, subjectId) {
  return db.watch(
    '''
    SELECT cs.id            AS id,
           cs.class_id      AS class_id,
           cs.coefficient   AS coef_override,
           cs.weekly_hours  AS weekly_hours,
           c.name           AS class_name,
           c.cycle_code     AS cycle_code,
           c.level_code     AS level_code,
           c.level_order    AS level_order,
           c.filiere_label  AS filiere_label,
           subj.coefficient AS niveau_coef,
           ts.staff_id      AS teacher_id,
           TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,'')) AS teacher_name,
           (SELECT COUNT(*) FROM class_enrollments ce
              WHERE ce.class_id = c.id AND ce.status = 'active') AS student_count
    FROM   class_subjects cs
    JOIN   classes  c    ON c.id  = cs.class_id
    JOIN   subjects subj ON subj.id = cs.subject_id
    LEFT JOIN teacher_subjects ts
           ON ts.subject_id = cs.subject_id AND ts.class_id = cs.class_id
    LEFT JOIN profiles p ON p.id = ts.staff_id
    WHERE  cs.subject_id = ?
    ORDER  BY c.level_order, c.name
    ''',
    parameters: [subjectId],
  ).map((rows) => [
        for (final r in rows)
          SubjectAssignment(
            id: r['id'] as String,
            classId: r['class_id'] as String,
            className: (r['class_name'] as String?) ?? '—',
            cycleCode: r['cycle_code'] as String?,
            levelCode: r['level_code'] as String?,
            levelOrder: (r['level_order'] as num?)?.toInt() ?? 999,
            filiereLabel: (r['filiere_label'] as String?)?.trim().isEmpty ?? true
                ? null
                : (r['filiere_label'] as String).trim(),
            coefOverride: (r['coef_override'] as num?)?.toInt(),
            niveauCoef: (r['niveau_coef'] as num?)?.toInt() ?? 1,
            weeklyHours: (r['weekly_hours'] as num?)?.toInt(),
            teacherId: r['teacher_id'] as String?,
            teacherName: r['teacher_name'] as String?,
            studentCount: (r['student_count'] as num?)?.toInt() ?? 0,
          ),
      ]);
});

/// Classe candidate à l'affectation d'une matière (pas encore liée).
class CandidateClass {
  const CandidateClass(this.id, this.label, this.levelOrder);
  final String id;
  final String label;
  final int levelOrder;
}

/// Classes affectables pour une matière canonique : TOUTES les classes actives
/// de l'école (tout cycle / tout niveau), pas encore présentes dans
/// `class_subjects`. La matière n'est plus liée à un niveau.
final assignableClassesProvider = StreamProvider.autoDispose
    .family<List<CandidateClass>, String>((ref, subjectId) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);

  return db.watch(
    '''
    SELECT c.id, c.name, c.level_code, c.level_order, c.filiere_label
    FROM   classes c
    WHERE  c.school_id = ? AND COALESCE(c.is_active, 1) <> 0
      AND  c.id NOT IN (SELECT class_id FROM class_subjects WHERE subject_id = ?)
    ORDER  BY c.level_order, c.name
    ''',
    parameters: [schoolId, subjectId],
  ).map((rows) => [
        for (final r in rows)
          CandidateClass(
            r['id'] as String,
            [
              (r['name'] as String?) ?? '—',
              if (((r['filiere_label'] as String?) ?? '').trim().isNotEmpty)
                '· ${(r['filiere_label'] as String).trim()}',
            ].join(' '),
            (r['level_order'] as num?)?.toInt() ?? 999,
          ),
      ]);
});

// ─── Mutations (offline-first) ──────────────────────────────────────────────

/// Affecte une matière à une classe (programme). [coefficient] NULL = hérite du niveau.
Future<void> assignSubjectToClass({
  required String groupId,
  required String schoolId,
  required String subjectId,
  required String classId,
  int? coefficient,
  int? weeklyHours,
}) async {
  // Garde-fou anti-doublon (UNIQUE class_id+subject_id côté serveur).
  final existing = await db.getAll(
    'SELECT id FROM class_subjects WHERE class_id = ? AND subject_id = ?',
    [classId, subjectId],
  );
  if (existing.isNotEmpty) return;

  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO class_subjects (
      id, group_id, school_id, class_id, subject_id,
      coefficient, weekly_hours, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    // Deduit de `UNIQUE (class_id, subject_id)` : depuis que les classes
    // portent un identifiant deduit, deux postes hors ligne produisent LA
    // MEME classe -- donc la meme cle ici. Sans identifiant deduit, la
    // collision se serait simplement deplacee d'une table a l'autre.
    [idDeterministe('class_subject', [classId, subjectId]),
     groupId, schoolId, classId, subjectId,
     coefficient, weeklyHours, now, now],
  );
}

/// Met à jour le coefficient effectif / volume horaire d'une affectation.
/// [clearCoefficient] = true → revenir au coef du niveau (override NULL).
Future<void> updateAssignment({
  required String id,
  int? coefficient,
  int? weeklyHours,
  bool clearCoefficient = false,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE class_subjects SET coefficient = ?, weekly_hours = ?, updated_at = ? WHERE id = ?',
    [clearCoefficient ? null : coefficient, weeklyHours, now, id],
  );
}

/// Retire une matière d'une classe.
Future<void> removeAssignment(String id) async {
  await db.execute('DELETE FROM class_subjects WHERE id = ?', [id]);
}

/// Affecte (ou retire si [teacherId] NULL) le professeur d'une matière dans une
/// classe via `teacher_subjects`. L'année est déduite de la classe.
Future<void> setAssignmentTeacher({
  required String groupId,
  required String schoolId,
  required String subjectId,
  required String classId,
  String? teacherId,
}) async {
  final rows = await db.getAll(
    'SELECT id, academic_year_id FROM classes WHERE id = ?',
    [classId],
  );
  if (rows.isEmpty) return;
  final yearId = rows.first['academic_year_id'] as String?;

  final existing = await db.getAll(
    'SELECT id FROM teacher_subjects WHERE subject_id = ? AND class_id = ?',
    [subjectId, classId],
  );
  final now = DateTime.now().toIso8601String();

  if (teacherId == null) {
    for (final r in existing) {
      await db.execute('DELETE FROM teacher_subjects WHERE id = ?', [r['id']]);
    }
    return;
  }

  if (existing.isNotEmpty) {
    await db.execute(
      'UPDATE teacher_subjects SET staff_id = ?, updated_at = ? WHERE id = ?',
      [teacherId, now, existing.first['id']],
    );
  } else {
    if (yearId == null) return; // année obligatoire (NOT NULL)
    await db.execute(
      '''
      INSERT INTO teacher_subjects (
        id, group_id, school_id, staff_id, subject_id, class_id,
        academic_year_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      // `UNIQUE (staff_id, subject_id, class_id, academic_year_id)`.
      [idDeterministe('teacher_subject',
          [teacherId, subjectId, classId, yearId]),
       groupId, schoolId, teacherId, subjectId, classId,
       yearId, now, now],
    );
  }
}
