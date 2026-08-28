import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import 'academic_year_context.dart';

const _uuid = Uuid();

/// Slug du module — le périmètre (`own_school` / `own_classes`) se lit sur CE
/// module, jamais sur un autre.
const kSlugCahierTextes = 'cahier-textes';

// ════════════════════════════════════════════════════════════════════════════
//  CAHIER DE TEXTES (table `lesson_entries`) — journal des séances : ce qui a
//  été fait en classe (titre, contenu, objectifs, devoirs, ressources) par
//  date / classe / matière / enseignant. 100% offline (db.watch / db.execute).
// ════════════════════════════════════════════════════════════════════════════
class LessonEntry {
  const LessonEntry({
    required this.id,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.subjectId,
    required this.subjectName,
    required this.staffId,
    required this.teacherName,
    required this.entryDate,
    required this.title,
    required this.content,
    required this.objectives,
    required this.homework,
    required this.resources,
  });

  final String id, classId, subjectId, staffId, title;
  final String? className, cycleCode, levelCode, subjectName, teacherName;
  final int levelOrder;
  final String? content, objectives, homework, resources;
  final DateTime? entryDate;

  bool get hasHomework => (homework ?? '').trim().isNotEmpty;
  String get dateLabel {
    final d = entryDate;
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Les séances de l'année active, DANS LE PÉRIMÈTRE du membre.
///
/// ⚠️ Ce flux servait « toutes les séances de l'école » : un enseignant en
/// `own_classes` — qui ne voit que ses classes partout ailleurs — recevait ici
/// le cahier de textes de l'établissement entier. Le formulaire, lui, était
/// déjà borné (`classesForModuleProvider`) : on pouvait donc lire ce qu'on ne
/// pouvait pas écrire. Le périmètre se pose des DEUX côtés, ou il ne sert à
/// rien.
final lessonEntriesProvider =
    StreamProvider.autoDispose<List<LessonEntry>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  final scope = classScopeClause(ref, kSlugCahierTextes, column: 'l.class_id');
  return db
      .watch(
        '''
        SELECT l.id, l.class_id, l.subject_id, l.staff_id, l.entry_date,
               l.lesson_title, l.content, l.objectives, l.homework, l.resources,
               c.name AS class_name, c.cycle_code AS cycle_code,
               c.level_code AS level_code, c.level_order AS level_order,
               sub.name AS subject_name,
               (p.first_name || ' ' || p.last_name) AS teacher_name
        FROM   lesson_entries l
        LEFT JOIN classes c   ON c.id = l.class_id
        LEFT JOIN subjects sub ON sub.id = l.subject_id
        LEFT JOIN profiles p  ON p.id = l.staff_id
        WHERE  l.school_id = ?
          AND  l.academic_year_id = ?
               ${scope?.clause ?? ''}
        ORDER  BY l.entry_date DESC, l.created_at DESC
        ''',
        parameters: [schoolId, yearId ?? '', ...?scope?.params],
      )
      .map((rows) => [
            for (final r in rows)
              LessonEntry(
                id: r['id'] as String,
                classId: (r['class_id'] as String?) ?? '',
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                subjectId: (r['subject_id'] as String?) ?? '',
                subjectName: r['subject_name'] as String?,
                staffId: (r['staff_id'] as String?) ?? '',
                teacherName: (r['teacher_name'] as String?)?.trim(),
                entryDate: _d(r['entry_date']),
                title: (r['lesson_title'] as String?) ?? '',
                content: r['content'] as String?,
                objectives: r['objectives'] as String?,
                homework: r['homework'] as String?,
                resources: r['resources'] as String?,
              ),
          ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createLessonEntry({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String classId,
  required String subjectId,
  required String staffId,
  required DateTime entryDate,
  required String title,
  String? content,
  String? objectives,
  String? homework,
  String? resources,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO lesson_entries (
      id, group_id, school_id, class_id, subject_id, staff_id,
      academic_year_id, entry_date, lesson_title, content, objectives,
      homework, resources, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [id, groupId, schoolId, classId, subjectId, staffId, academicYearId,
     entryDate.toIso8601String().substring(0, 10), title.trim(),
     content?.trim(), objectives?.trim(), homework?.trim(), resources?.trim(),
     now, now],
  );
}

Future<void> updateLessonEntry({
  required String id,
  required String classId,
  required String subjectId,
  required String staffId,
  required DateTime entryDate,
  required String title,
  String? content,
  String? objectives,
  String? homework,
  String? resources,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE lesson_entries
    SET class_id = ?, subject_id = ?, staff_id = ?, entry_date = ?,
        lesson_title = ?, content = ?, objectives = ?, homework = ?,
        resources = ?, updated_at = ?
    WHERE id = ?
    ''',
    [classId, subjectId, staffId,
     entryDate.toIso8601String().substring(0, 10), title.trim(),
     content?.trim(), objectives?.trim(), homework?.trim(), resources?.trim(),
     now, id],
  );
}

Future<void> deleteLessonEntry(String id) async {
  await db.execute('DELETE FROM lesson_entries WHERE id = ?', [id]);
}
