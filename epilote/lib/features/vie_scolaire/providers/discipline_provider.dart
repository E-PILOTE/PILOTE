import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

export '../../../core/utils/discipline_vocab.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  DISCIPLINE (table `discipline_incidents`, SENSIBLE — gatée par la capacité
//  `sync_discipline` du profil d'accès). Incidents par élève : type, sanction,
//  notification parents, suivi. Couverture/filtrage par cycle/niveau/classe via
//  l'inscription active de l'élève. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

// Types d'incidents et sanctions : déplacés dans `core/utils/discipline_vocab`
// pour que le ministère (online) puisse relire les mêmes libellés sans importer
// PowerSync. Ré-exportés ici — les écrans Vie scolaire les voient inchangés.

class DisciplineIncident {
  const DisciplineIncident({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.date,
    required this.type,
    required this.description,
    required this.sanction,
    required this.sanctionDate,
    required this.parentNotified,
    required this.followUp,
  });
  final String id, studentId, studentName;
  final String? classId, className, cycleCode, levelCode;
  final int levelOrder;
  final String date;
  final String type;
  final String? description, sanction, sanctionDate, followUp;
  final bool parentNotified;

  bool get hasSanction => (sanction ?? '').isNotEmpty && sanction != 'aucune';
}

/// Tous les incidents de l'année active, enrichis (élève + classe via
/// l'inscription active). Réactif.
final incidentsProvider =
    StreamProvider.autoDispose<List<DisciplineIncident>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT di.*, s.first_name, s.last_name,
           c.id AS cid, c.name AS class_name, c.cycle_code AS cycle_code,
           c.level_code AS level_code, c.level_order AS level_order
    FROM discipline_incidents di
    JOIN students s ON s.id = di.student_id
    LEFT JOIN class_enrollments ce
      ON ce.student_id = di.student_id AND ce.status = 'active'
    LEFT JOIN classes c ON c.id = ce.class_id
    WHERE di.school_id = ? AND di.academic_year_id = ?
    ORDER BY di.incident_date DESC, di.created_at DESC
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          DisciplineIncident(
            id: r['id'] as String,
            studentId: r['student_id'] as String,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            classId: r['cid'] as String?,
            className: r['class_name'] as String?,
            cycleCode: r['cycle_code'] as String?,
            levelCode: r['level_code'] as String?,
            levelOrder: (r['level_order'] as int?) ?? 999,
            date: (r['incident_date'] as String?) ?? '',
            type: (r['incident_type'] as String?) ?? 'autre',
            description: r['description'] as String?,
            sanction: r['sanction'] as String?,
            sanctionDate: r['sanction_date'] as String?,
            parentNotified: ((r['parent_notified'] as int?) ?? 0) == 1,
            followUp: r['follow_up_notes'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> saveIncident({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String studentId,
  required String date,
  required String type,
  String? description,
  String? sanction,
  String? sanctionDate,
  required bool parentNotified,
  String? followUp,
  required String reportedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      '''
      UPDATE discipline_incidents SET incident_date = ?, incident_type = ?,
        description = ?, sanction = ?, sanction_date = ?, parent_notified = ?,
        follow_up_notes = ?, updated_at = ?
      WHERE id = ?
      ''',
      [date, type, description, sanction, sanctionDate, parentNotified ? 1 : 0,
       followUp, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO discipline_incidents (
        id, group_id, school_id, student_id, academic_year_id, incident_date,
        incident_type, description, sanction, sanction_date, reported_by,
        parent_notified, follow_up_notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, studentId, academicYearId, date, type,
       description, sanction, sanctionDate, reportedBy, parentNotified ? 1 : 0,
       followUp, now, now],
    );
  }
}

Future<void> deleteIncident(String id) async {
  await db.execute('DELETE FROM discipline_incidents WHERE id = ?', [id]);
}
