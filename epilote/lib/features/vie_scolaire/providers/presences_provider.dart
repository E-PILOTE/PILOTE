import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../widgets/vs_kit.dart';

/// Le slug de CE module, déclaré à côté des requêtes qu'il borne — le
/// littéral recopié dans deux fichiers est ce qui laisse un périmètre dériver.
const kSlugPresences = 'presences-eleves';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCES ÉLÈVES (tables `attendance_records` + `attendance_entries`) — appel
//  quotidien par classe × date × période (AM/PM). Un `attendance_record` par
//  (classe, date, période) ; une `attendance_entry` par élève (present/absent/
//  late + heure d'arrivée + justification). 100% offline (db.watch/execute).
// ════════════════════════════════════════════════════════════════════════════

const kAttendanceStatuses = <(String, String)>[
  ('present', 'Présent'),
  ('absent', 'Absent'),
  ('late', 'En retard'),
];

typedef AttendanceDay = ({String date, String period});
typedef AttendanceArgs = ({String classId, String date, String period});

/// Vue d'ensemble école pour une date × période : couverture par classe
/// (élèves pointés / effectif) + compteurs présents/absents/retards.
class AttendanceOverview {
  const AttendanceOverview({
    required this.rows,
    required this.present,
    required this.absent,
    required this.late,
    required this.students,
    required this.recorded,
    required this.classesDone,
  });
  final List<VsCoverageRow> rows;
  final int present, absent, late, students, recorded, classesDone;
  int get classesTotal => rows.length;
}

final attendanceOverviewProvider = FutureProvider.autoDispose
    .family<AttendanceOverview, AttendanceDay>((ref, day) async {
  ref.keepAlive();
  // Périmètre de CE module, jamais celui de `classes` : le `data_scope`
  // posé sur ce module doit produire un effet.
  final classes = ref.watch(classesForModuleProvider(kSlugPresences)).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const AttendanceOverview(
        rows: [], present: 0, absent: 0, late: 0, students: 0, recorded: 0,
        classesDone: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');

  // Entrées du jour+période, par classe (via le record).
  final rows = await db.getAll(
    'SELECT r.class_id AS cid, e.status AS status, r.is_finalized AS fin '
    'FROM attendance_entries e '
    'JOIN attendance_records r ON r.id = e.attendance_record_id '
    'WHERE r.record_date = ? AND r.period = ? AND r.class_id IN ($ph)',
    [day.date, day.period, ...ids],
  );
  final rec = <String, int>{};
  final fin = <String, bool>{};
  var present = 0, absent = 0, late = 0;
  for (final r in rows) {
    final cid = r['cid'] as String;
    rec[cid] = (rec[cid] ?? 0) + 1;
    if (((r['fin'] as int?) ?? 0) == 1) fin[cid] = true;
    switch (r['status'] as String?) {
      case 'present':
        present++;
      case 'absent':
        absent++;
      case 'late':
        late++;
    }
  }

  final cov = [
    for (final c in classes)
      VsCoverageRow(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        total: c.studentCount ?? 0,
        ok: rec[c.id] ?? 0,
        note: (fin[c.id] ?? false) ? '✓' : null,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  return AttendanceOverview(
    rows: cov,
    present: present,
    absent: absent,
    late: late,
    students: cov.fold(0, (a, c) => a + c.total),
    recorded: rec.values.fold(0, (a, b) => a + b),
    classesDone: fin.length,
  );
});

/// Une ligne d'appel pour un élève.
class RollRow {
  const RollRow({
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.status,
    required this.arrivalTime,
    required this.justification,
    required this.entryId,
  });
  final String studentId, studentName;
  final String? matricule, status, arrivalTime, justification, entryId;
  bool get recorded => status != null;
}

class ClassRoll {
  const ClassRoll({required this.rows, required this.recordId, required this.finalized});
  final List<RollRow> rows;
  final String? recordId; // null = aucun appel encore créé
  final bool finalized;
}

/// Feuille d'appel d'une classe pour une date × période (réactif).
final classRollProvider =
    StreamProvider.autoDispose.family<ClassRoll, AttendanceArgs>((ref, args) {
  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           e.id AS eid, e.status AS status, e.arrival_time AS arr,
           e.justification AS just,
           r.id AS rid, r.is_finalized AS fin
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    LEFT JOIN attendance_records r
      ON r.class_id = ce.class_id AND r.record_date = ? AND r.period = ?
    LEFT JOIN attendance_entries e
      ON e.attendance_record_id = r.id AND e.student_id = s.id
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [args.date, args.period, args.classId],
  ).map((rows) {
    String? recordId;
    var finalized = false;
    final list = <RollRow>[];
    for (final r in rows) {
      recordId ??= r['rid'] as String?;
      if (((r['fin'] as int?) ?? 0) == 1) finalized = true;
      list.add(RollRow(
        studentId: r['sid'] as String,
        studentName: '${(r['last_name'] as String?) ?? ''} '
                '${(r['first_name'] as String?) ?? ''}'
            .trim(),
        matricule: r['matricule'] as String?,
        status: r['status'] as String?,
        arrivalTime: r['arr'] as String?,
        justification: r['just'] as String?,
        entryId: r['eid'] as String?,
      ));
    }
    return ClassRoll(rows: list, recordId: recordId, finalized: finalized);
  });
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────

/// Garantit l'existence du `attendance_record` (classe, date, période) et
/// renvoie son id. Crée s'il manque.
Future<String> ensureAttendanceRecord({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String classId,
  required String date,
  required String period,
  required String recordedBy,
}) async {
  final ex = await db.getAll(
    'SELECT id FROM attendance_records WHERE class_id = ? AND record_date = ? '
    'AND period = ? LIMIT 1',
    [classId, date, period],
  );
  if (ex.isNotEmpty) return ex.first['id'] as String;
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO attendance_records (
      id, group_id, school_id, class_id, academic_year_id, record_date,
      period, recorded_by, is_finalized, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    ''',
    [id, groupId, schoolId, classId, academicYearId, date, period, recordedBy,
     now, now],
  );
  return id;
}

/// Pose / met à jour le statut d'un élève dans l'appel.
Future<void> setAttendance({
  required String recordId,
  required String groupId,
  required String schoolId,
  required String studentId,
  required String status,
  String? arrivalTime,
  String? justification,
  String? existingEntryId,
}) async {
  final now = DateTime.now().toIso8601String();
  if (existingEntryId != null) {
    await db.execute(
      'UPDATE attendance_entries SET status = ?, arrival_time = ?, '
      'justification = ?, updated_at = ? WHERE id = ?',
      [status, arrivalTime, justification, now, existingEntryId],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO attendance_entries (
        id, attendance_record_id, student_id, group_id, school_id, status,
        arrival_time, justification, parent_notified, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
      ''',
      [_uuid.v4(), recordId, studentId, groupId, schoolId, status, arrivalTime,
       justification, now, now],
    );
  }
}

/// Marque l'appel comme finalisé (ou rouvert).
Future<void> finalizeAttendance(String recordId, bool finalized) async {
  await db.execute(
    'UPDATE attendance_records SET is_finalized = ?, updated_at = ? WHERE id = ?',
    [finalized ? 1 : 0, DateTime.now().toIso8601String(), recordId],
  );
}

/// Pointe d'un coup tous les élèves non encore pointés comme « présents ».
Future<void> markAllPresent({
  required String recordId,
  required String groupId,
  required String schoolId,
  required List<RollRow> rows,
}) async {
  for (final r in rows) {
    if (r.recorded) continue;
    await setAttendance(
      recordId: recordId,
      groupId: groupId,
      schoolId: schoolId,
      studentId: r.studentId,
      status: 'present',
    );
  }
}
