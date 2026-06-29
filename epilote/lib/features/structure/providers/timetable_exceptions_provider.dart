import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  EXCEPTIONS À LA TRAME (table `timetable_exceptions`) — écarts PONCTUELS à une
//  date précise : séance annulée / déplacée / exceptionnelle. Appliquées par
//  la projection calendaire pour rendre exactes les vues mois/trimestre/année.
//  100% offline (db.watch / db.execute).
// ════════════════════════════════════════════════════════════════════════════

const kExceptionKinds = <(String, String)>[
  ('cancelled', 'Séance annulée'),
  ('moved', 'Séance déplacée'),
  ('extra', 'Séance exceptionnelle'),
];

String exceptionKindLabel(String? k) => kExceptionKinds
    .firstWhere((e) => e.$1 == k, orElse: () => ('cancelled', 'Annulée'))
    .$2;

class TimetableException {
  const TimetableException({
    required this.id,
    required this.slotId,
    required this.date,
    required this.kind,
    required this.newStartTime,
    required this.newEndTime,
    required this.newRoomId,
    required this.newStaffId,
    required this.newSubjectId,
    required this.newClassId,
    required this.reason,
    required this.subjectName,
    required this.className,
    required this.staffName,
    required this.roomName,
  });

  final String id;
  final String? slotId;
  final DateTime date;
  final String kind;
  final String? newStartTime, newEndTime, newRoomId, newStaffId, newSubjectId,
      newClassId, reason;
  // Libellés résolus (pour l'affichage, surtout 'extra').
  final String? subjectName, className, staffName, roomName;

  bool get isCancelled => kind == 'cancelled';
  bool get isMoved => kind == 'moved';
  bool get isExtra => kind == 'extra';

  String _hhmm(String? t) =>
      (t != null && t.length >= 5) ? t.substring(0, 5) : (t ?? '');
  String get newTimeLabel => (newStartTime != null && newEndTime != null)
      ? '${_hhmm(newStartTime)}–${_hhmm(newEndTime)}'
      : '';
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Exceptions de l'école (année active), libellés joints.
final timetableExceptionsProvider =
    StreamProvider.autoDispose<List<TimetableException>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT e.id, e.slot_id, e.exception_date, e.kind,
               e.new_start_time, e.new_end_time, e.new_room_id, e.new_staff_id,
               e.new_subject_id, e.new_class_id, e.reason,
               COALESCE(es.name, ss.name)  AS subject_name,
               COALESCE(ec.name, sc.name)  AS class_name,
               (ep.first_name || ' ' || ep.last_name) AS staff_name,
               er.name AS room_name
        FROM   timetable_exceptions e
        LEFT JOIN timetable_slots s ON s.id = e.slot_id
        LEFT JOIN subjects ss ON ss.id = s.subject_id
        LEFT JOIN classes  sc ON sc.id = s.class_id
        LEFT JOIN subjects es ON es.id = e.new_subject_id
        LEFT JOIN classes  ec ON ec.id = e.new_class_id
        LEFT JOIN profiles ep ON ep.id = e.new_staff_id
        LEFT JOIN rooms    er ON er.id = e.new_room_id
        WHERE  e.school_id = ? AND e.academic_year_id = ?
        ORDER  BY e.exception_date
        ''',
        parameters: [schoolId, yearId ?? ''],
      )
      .map((rows) => [
            for (final r in rows)
              if (_d(r['exception_date']) != null)
                TimetableException(
                  id: r['id'] as String,
                  slotId: r['slot_id'] as String?,
                  date: _d(r['exception_date'])!,
                  kind: (r['kind'] as String?) ?? 'cancelled',
                  newStartTime: r['new_start_time'] as String?,
                  newEndTime: r['new_end_time'] as String?,
                  newRoomId: r['new_room_id'] as String?,
                  newStaffId: r['new_staff_id'] as String?,
                  newSubjectId: r['new_subject_id'] as String?,
                  newClassId: r['new_class_id'] as String?,
                  reason: r['reason'] as String?,
                  subjectName: r['subject_name'] as String?,
                  className: r['class_name'] as String?,
                  staffName: (r['staff_name'] as String?)?.trim(),
                  roomName: r['room_name'] as String?,
                ),
          ]);
});

/// Clé date 'yyyy-MM-dd' → exceptions de ce jour (pour la projection).
Map<String, List<TimetableException>> exceptionsByDate(
    List<TimetableException> all) {
  final m = <String, List<TimetableException>>{};
  for (final e in all) {
    (m[_ymd(e.date)] ??= []).add(e);
  }
  return m;
}

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createException({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  String? slotId,
  required DateTime date,
  required String kind,
  String? newStartTime,
  String? newEndTime,
  String? newRoomId,
  String? newStaffId,
  String? newSubjectId,
  String? newClassId,
  String? reason,
  String? createdBy,
}) async {
  final now = DateTime.now().toIso8601String();
  String? t(String? hhmm) => hhmm == null ? null : '$hhmm:00';
  await db.execute(
    '''
    INSERT INTO timetable_exceptions (
      id, group_id, school_id, academic_year_id, slot_id, exception_date, kind,
      new_start_time, new_end_time, new_room_id, new_staff_id, new_subject_id,
      new_class_id, reason, created_by, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [_uuid.v4(), groupId, schoolId, academicYearId, slotId, _ymd(date), kind,
     t(newStartTime), t(newEndTime), newRoomId, newStaffId, newSubjectId,
     newClassId, reason?.trim(), createdBy, now, now],
  );
}

Future<void> deleteException(String id) async {
  await db.execute('DELETE FROM timetable_exceptions WHERE id = ?', [id]);
}
