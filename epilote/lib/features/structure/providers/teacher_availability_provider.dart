import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';
import 'timetable_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  DISPONIBILITÉS ENSEIGNANT (table `teacher_availability`) — déclare les plages
//  où un prof N'EST PAS disponible (DUR) ou à éviter / privilégier (SOUPLE).
//  Convention : ABSENCE de ligne = disponible. start/end NULL = journée entière.
//  La construction de l'emploi du temps en tient compte (blocage / avertissement).
//  100% offline (db.watch / db.execute).
// ════════════════════════════════════════════════════════════════════════════

const kAvailStatuses = <(String, String)>[
  ('unavailable', 'Indisponible'),
  ('preference_against', 'À éviter'),
  ('preference_for', 'Privilégié'),
];

String availStatusLabel(String? s) => kAvailStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('unavailable', 'Indisponible'))
    .$2;

class TeacherAvailability {
  const TeacherAvailability({
    required this.id,
    required this.staffId,
    required this.dayOfWeek,
    required this.status,
    this.startTime,
    this.endTime,
    this.note,
    this.staffName,
  });

  final String id, staffId, status;
  final int dayOfWeek; // 1=lun … 7=dim
  final String? startTime, endTime, note, staffName;

  bool get isHard => status == 'unavailable';
  bool get wholeDay => (startTime ?? '').isEmpty || (endTime ?? '').isEmpty;

  String get hhmmStart =>
      (startTime != null && startTime!.length >= 5) ? startTime!.substring(0, 5) : '';
  String get hhmmEnd =>
      (endTime != null && endTime!.length >= 5) ? endTime!.substring(0, 5) : '';
  String get rangeLabel => wholeDay ? 'Toute la journée' : '$hhmmStart–$hhmmEnd';
}

/// Toutes les disponibilités déclarées de l'école (toute année + année active).
final teacherAvailabilityProvider =
    StreamProvider.autoDispose<List<TeacherAvailability>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT a.id, a.staff_id, a.day_of_week, a.start_time, a.end_time,
           a.status, a.note,
           (p.first_name || ' ' || p.last_name) AS staff_name
    FROM   teacher_availability a
    LEFT JOIN profiles p ON p.id = a.staff_id
    WHERE  a.school_id = ?
      AND  (a.academic_year_id IS NULL OR a.academic_year_id = ?)
    ORDER  BY a.day_of_week, a.start_time
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          TeacherAvailability(
            id: r['id'] as String,
            staffId: (r['staff_id'] as String?) ?? '',
            dayOfWeek: (r['day_of_week'] as int?) ?? 1,
            startTime: r['start_time'] as String?,
            endTime: r['end_time'] as String?,
            status: (r['status'] as String?) ?? 'unavailable',
            note: r['note'] as String?,
            staffName: (r['staff_name'] as String?)?.trim(),
          ),
      ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createTeacherAvailability({
  required String groupId,
  required String schoolId,
  required String staffId,
  String? academicYearId,
  required int dayOfWeek,
  String? startTime, // 'HH:MM' ou null = journée entière
  String? endTime,
  required String status,
  String? note,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO teacher_availability (
      id, group_id, school_id, staff_id, academic_year_id, day_of_week,
      start_time, end_time, status, note, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [id, groupId, schoolId, staffId, academicYearId, dayOfWeek,
     startTime != null ? '$startTime:00' : null,
     endTime != null ? '$endTime:00' : null, status, note?.trim(), now, now],
  );
}

Future<void> deleteTeacherAvailability(String id) async {
  await db.execute('DELETE FROM teacher_availability WHERE id = ?', [id]);
}

// ─── Vérification : un prof placé sur (jour, plage) viole-t-il une dispo ? ─────
/// Renvoie la plus forte violation : 'unavailable' (DUR) > 'preference_against'
/// (SOUPLE) > null (aucune). Une dispo « journée entière » couvre toute la plage.
String? availabilityViolation({
  required List<TeacherAvailability> avail,
  required String staffId,
  required int day,
  required String start,
  required String end,
}) {
  if (staffId.isEmpty) return null;
  String? worst;
  for (final a in avail) {
    if (a.staffId != staffId || a.dayOfWeek != day) continue;
    final hits = a.wholeDay ||
        rangesOverlap(start, end, a.hhmmStart, a.hhmmEnd);
    if (!hits) continue;
    if (a.status == 'unavailable') return 'unavailable';
    if (a.status == 'preference_against') worst = 'preference_against';
  }
  return worst;
}
