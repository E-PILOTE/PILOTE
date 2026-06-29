import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCES DU PERSONNEL (table `staff_attendance`, staff_id -> profiles.id,
//  sensible sync_finance). Pointage quotidien des agents : present / late /
//  absent (enum attendance_status). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kStaffAttStatuses = <(String, String)>[
  ('present', 'Présent'),
  ('late', 'Retard'),
  ('absent', 'Absent'),
];

String staffAttStatusLabel(String? s) => kStaffAttStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('', '—'))
    .$2;

String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

/// Pointage d'un agent à une date : statut + horaires.
class AttendanceMark {
  const AttendanceMark({
    required this.id,
    required this.status,
    this.arrival,
    this.departure,
    this.notes,
  });
  final String id, status;
  final String? arrival, departure, notes;
}

/// Map staffId → pointage, pour une date donnée (école courante).
final staffAttendanceForDateProvider = StreamProvider.autoDispose
    .family<Map<String, AttendanceMark>, String>((ref, dateKey) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) {
    return Stream.value(const {});
  }
  return db.watch(
    'SELECT * FROM staff_attendance WHERE school_id = ? AND record_date = ?',
    parameters: [schoolId, dateKey],
  ).map((rows) => {
        for (final r in rows)
          (r['staff_id'] as String): AttendanceMark(
            id: r['id'] as String,
            status: (r['status'] as String?) ?? 'present',
            arrival: r['arrival_time'] as String?,
            departure: r['departure_time'] as String?,
            notes: r['notes'] as String?,
          ),
      });
});

// ─── Mutation : pointer un agent (upsert par staff_id + date) ─────────────────
Future<void> setStaffAttendance({
  required String groupId,
  required String schoolId,
  required String staffId,
  required String dateKey,
  required String status,
  required String recordedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  final existing = await db.getAll(
    'SELECT id FROM staff_attendance WHERE school_id = ? AND staff_id = ? '
    'AND record_date = ? LIMIT 1',
    [schoolId, staffId, dateKey],
  );
  if (existing.isNotEmpty) {
    await db.execute(
      'UPDATE staff_attendance SET status = ?, recorded_by = ?, updated_at = ? '
      'WHERE id = ?',
      [status, recordedBy, now, existing.first['id']],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO staff_attendance (
        id, group_id, school_id, staff_id, record_date, status,
        recorded_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, staffId, dateKey, status, recordedBy,
       now, now],
    );
  }
}

Future<void> clearStaffAttendance(String id) async {
  await db.execute('DELETE FROM staff_attendance WHERE id = ?', [id]);
}
