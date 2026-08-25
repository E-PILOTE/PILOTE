import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Élèves actifs AVEC leur classe (via l'inscription active) — pour les pickers
//  et les couvertures des modules vie scolaire (discipline, infirmerie,
//  orientation). 100% offline, réactif.
// ════════════════════════════════════════════════════════════════════════════
class VsStudent {
  const VsStudent({
    required this.id,
    required this.name,
    required this.matricule,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
  });
  final String id, name;
  final String? matricule, classId, className, cycleCode, levelCode;
  final int levelOrder;

  String get classLabel => className ?? 'Sans classe';
}

final vsStudentsProvider = StreamProvider.autoDispose<List<VsStudent>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           c.id AS cid, c.name AS class_name, c.cycle_code AS cycle_code,
           c.level_code AS level_code, c.level_order AS level_order
    FROM students s
    LEFT JOIN class_enrollments ce
      ON ce.student_id = s.id AND ce.status = 'active'
    LEFT JOIN classes c ON c.id = ce.class_id
    WHERE s.school_id = ? AND COALESCE(s.is_active, 1) <> 0
    ORDER BY c.level_order, c.name, s.last_name, s.first_name
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          VsStudent(
            id: r['sid'] as String,
            name: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            classId: r['cid'] as String?,
            className: r['class_name'] as String?,
            cycleCode: r['cycle_code'] as String?,
            levelCode: r['level_code'] as String?,
            levelOrder: (r['level_order'] as int?) ?? 999,
          ),
      ]);
});
