import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

part 'timetable_conflicts.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  EMPLOI DU TEMPS (table `timetable_slots`) — créneaux hebdomadaires d'une
//  classe : jour × horaire → matière + enseignant + salle. 100% offline
//  (db.watch / db.execute). Jointures matière / prof / classe pour l'affichage.
// ════════════════════════════════════════════════════════════════════════════

const frDays = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi',
    'Dimanche'];
const frDaysShort = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Trame d'horaires standard (collège/lycée Congo, séances de 55 min, récré et
/// pause déjeuner exclues). Sert de saisie rapide dans le formulaire — la
/// direction reste libre de saisir une heure personnalisée.
const kStdPeriods = <(String, String)>[
  ('07:00', '07:55'),
  ('07:55', '08:50'),
  ('08:50', '09:45'),
  ('10:00', '10:55'),
  ('10:55', '11:50'),
  ('11:50', '12:45'),
  ('14:00', '14:55'),
  ('14:55', '15:50'),
  ('15:50', '16:45'),
];

/// Minutes depuis minuit pour un horaire 'HH:MM'.
int hhmmToMin(String hhmm) {
  final p = hhmm.split(':');
  if (p.isEmpty) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 +
      (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

/// Deux plages [a) et [b) se chevauchent-elles (même journée supposée) ?
bool rangesOverlap(String aStart, String aEnd, String bStart, String bEnd) {
  final a1 = hhmmToMin(aStart), a2 = hhmmToMin(aEnd);
  final b1 = hhmmToMin(bStart), b2 = hhmmToMin(bEnd);
  return a1 < b2 && b1 < a2;
}

class TimetableSlot {
  const TimetableSlot({
    required this.id,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.subjectId,
    required this.subjectName,
    required this.staffId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    this.roomId,
    this.versionId,
  });

  final String id, classId, subjectId, staffId;
  final String? className, cycleCode, subjectName, teacherName, room;
  final String? roomId, versionId;
  final int dayOfWeek; // 1=lun … 7=dim
  final String startTime, endTime; // 'HH:MM' (tronqué)

  String get hhmmStart => startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get hhmmEnd => endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
  String get timeLabel => '$hhmmStart–$hhmmEnd';

  // Durée en minutes (pour le total horaire).
  int get durationMinutes {
    int mins(String t) {
      final p = t.split(':');
      if (p.length < 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    final d = mins(endTime) - mins(startTime);
    return d > 0 ? d : 0;
  }
}

/// Tous les créneaux ACTIFS de l'école (année active), joints aux libellés.
final timetableSlotsProvider =
    StreamProvider.autoDispose<List<TimetableSlot>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT t.id, t.class_id, t.subject_id, t.staff_id, t.version_id,
               t.day_of_week, t.start_time, t.end_time, t.room, t.room_id,
               c.name AS class_name, c.cycle_code AS cycle_code,
               sub.name AS subject_name,
               rm.name AS room_name,
               (p.first_name || ' ' || p.last_name) AS teacher_name
        FROM   timetable_slots t
        LEFT JOIN classes c  ON c.id = t.class_id
        LEFT JOIN subjects sub ON sub.id = t.subject_id
        LEFT JOIN profiles p ON p.id = t.staff_id
        LEFT JOIN rooms rm ON rm.id = t.room_id
        WHERE  t.school_id = ?
          AND  t.academic_year_id = ?
          AND  COALESCE(t.is_active, 1) <> 0
        ORDER  BY t.day_of_week, t.start_time
        ''',
        parameters: [schoolId, yearId ?? ''],
      )
      .map((rows) => [
            for (final r in rows)
              TimetableSlot(
                id: r['id'] as String,
                classId: (r['class_id'] as String?) ?? '',
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                subjectId: (r['subject_id'] as String?) ?? '',
                subjectName: r['subject_name'] as String?,
                staffId: (r['staff_id'] as String?) ?? '',
                teacherName: (r['teacher_name'] as String?)?.trim(),
                dayOfWeek: (r['day_of_week'] as int?) ?? 1,
                startTime: (r['start_time'] as String?) ?? '00:00',
                endTime: (r['end_time'] as String?) ?? '00:00',
                // Salle = nom du registre (room_id) si présent, sinon legacy texte.
                room: ((r['room_name'] as String?)?.trim().isNotEmpty ?? false)
                    ? (r['room_name'] as String?)
                    : r['room'] as String?,
                roomId: r['room_id'] as String?,
                versionId: r['version_id'] as String?,
              ),
          ]);
});

// ─── Version d'emploi du temps (cycle de vie + publication) ──────────────────
class TimetableVersion {
  const TimetableVersion(
      {required this.id, required this.status, required this.label});
  final String id, status, label;

  String get statusLabel => switch (status) {
        'brouillon' => 'Brouillon',
        'en_cours' => 'En cours',
        'en_validation' => 'En validation',
        'valide' => 'Validé',
        'publie' => 'Publié',
        'suspendu' => 'Suspendu',
        'archive' => 'Archivé',
        _ => status,
      };
  bool get isPublished => status == 'publie';
}

/// Version ACTIVE de l'école pour l'année courante (porte le statut publié/brouillon).
final activeTimetableVersionProvider =
    StreamProvider.autoDispose<TimetableVersion?>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(null);
  return db.watch(
    '''
    SELECT id, status, label FROM timetable_versions
    WHERE school_id = ? AND academic_year_id = ? AND COALESCE(is_active, 1) <> 0
    LIMIT 1
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => rows.isEmpty
      ? null
      : TimetableVersion(
          id: rows.first['id'] as String,
          status: (rows.first['status'] as String?) ?? 'brouillon',
          label: (rows.first['label'] as String?) ?? 'Emploi du temps',
        ));
});

/// Charge hebdomadaire maximale conseillée d'un enseignant (heures de cours).
/// Seuil souple d'alerte — au-delà, on signale une surcharge.
const kTeacherMaxWeeklyHours = 27;

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createTimetableSlot({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String classId,
  required String subjectId,
  required String staffId,
  required int dayOfWeek,
  required String startTime, // 'HH:MM'
  required String endTime,
  String? room, // nom (legacy/affichage)
  String? roomId, // → rooms (référencé, fiabilise les conflits)
  String? versionId, // → timetable_versions
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO timetable_slots (
      id, group_id, school_id, version_id, class_id, subject_id, staff_id,
      academic_year_id, day_of_week, start_time, end_time, room, room_id,
      is_active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, groupId, schoolId, versionId, classId, subjectId, staffId,
     academicYearId, dayOfWeek, '$startTime:00', '$endTime:00',
     room?.trim(), roomId, now, now],
  );
}

Future<void> updateTimetableSlot({
  required String id,
  required String subjectId,
  required String staffId,
  required int dayOfWeek,
  required String startTime,
  required String endTime,
  String? room,
  String? roomId,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE timetable_slots
    SET subject_id = ?, staff_id = ?, day_of_week = ?, start_time = ?,
        end_time = ?, room = ?, room_id = ?, updated_at = ?
    WHERE id = ?
    ''',
    [subjectId, staffId, dayOfWeek, '$startTime:00', '$endTime:00',
     room?.trim(), roomId, now, id],
  );
}

Future<void> deleteTimetableSlot(String id) async {
  await db.execute('DELETE FROM timetable_slots WHERE id = ?', [id]);
}

/// Supprime TOUS les créneaux d'une classe (année active). Renvoie le nombre.
Future<int> clearClassTimetable({
  required String schoolId,
  required String academicYearId,
  required String classId,
}) async {
  final rows = await db.getAll(
    'SELECT id FROM timetable_slots WHERE school_id = ? AND academic_year_id = ? '
    'AND class_id = ? AND COALESCE(is_active, 1) <> 0',
    [schoolId, academicYearId, classId],
  );
  for (final r in rows) {
    await db.execute(
        'DELETE FROM timetable_slots WHERE id = ?', [r['id'] as String]);
  }
  return rows.length;
}

/// Duplique tous les créneaux de [fromClassId] vers [toClassId] (même école/
/// année). Les matières hors programme de la classe cible sont conservées telles
/// quelles (la direction ajuste ensuite). Renvoie le nombre de créneaux copiés.
Future<int> duplicateClassTimetable({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String fromClassId,
  required String toClassId,
  String? versionId,
}) async {
  final rows = await db.getAll(
    '''
    SELECT subject_id, staff_id, day_of_week, start_time, end_time, room, room_id
    FROM   timetable_slots
    WHERE  school_id = ? AND academic_year_id = ? AND class_id = ?
      AND  COALESCE(is_active, 1) <> 0
    ''',
    [schoolId, academicYearId, fromClassId],
  );
  final now = DateTime.now().toIso8601String();
  for (final r in rows) {
    await db.execute(
      '''
      INSERT INTO timetable_slots (
        id, group_id, school_id, version_id, class_id, subject_id, staff_id,
        academic_year_id, day_of_week, start_time, end_time, room, room_id,
        is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, versionId, toClassId,
       r['subject_id'], r['staff_id'], academicYearId, r['day_of_week'],
       r['start_time'], r['end_time'], r['room'], r['room_id'], now, now],
    );
  }
  return rows.length;
}

// ─── Cycle de vie de la VERSION (brouillon → publié) ─────────────────────────
/// Renvoie l'id de la version ACTIVE de l'école/année, en la CRÉANT (brouillon)
/// si aucune n'existe. À appeler avant la 1re écriture de créneau.
Future<String> ensureActiveVersionId({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  String? createdBy,
}) async {
  final existing = await db.getAll(
    'SELECT id FROM timetable_versions WHERE school_id = ? AND academic_year_id = ? '
    'AND COALESCE(is_active, 1) <> 0 LIMIT 1',
    [schoolId, academicYearId],
  );
  if (existing.isNotEmpty) return existing.first['id'] as String;
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO timetable_versions (
      id, group_id, school_id, academic_year_id, label, status, is_active,
      created_by, created_at, updated_at
    ) VALUES (?, ?, ?, ?, 'Emploi du temps', 'brouillon', 1, ?, ?, ?)
    ''',
    [id, groupId, schoolId, academicYearId, createdBy, now, now],
  );
  return id;
}

/// Publie la version : visible des enseignants/élèves/parents.
Future<void> publishTimetableVersion(String id, {String? validatedBy}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE timetable_versions SET status = ?, published_at = ?, validated_by = ?, '
    'updated_at = ? WHERE id = ?',
    ['publie', now, validatedBy, now, id],
  );
}

/// Repasse la version en brouillon (retire la publication).
Future<void> unpublishTimetableVersion(String id) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE timetable_versions SET status = ?, published_at = NULL, updated_at = ? '
    'WHERE id = ?',
    ['brouillon', now, id],
  );
}

// ─── Conformité au programme (volume horaire requis vs placé) ────────────────
/// Heures hebdomadaires REQUISES par classe (somme des `class_subjects.weekly_hours`).
/// Sert à mesurer la conformité de l'emploi du temps au programme.
final classRequiredHoursProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const {});
  return db.watch(
    '''
    SELECT cs.class_id AS class_id,
           SUM(COALESCE(cs.weekly_hours, 0)) AS req
    FROM   class_subjects cs
    JOIN   classes c ON c.id = cs.class_id
    WHERE  c.school_id = ?
    GROUP  BY cs.class_id
    ''',
    parameters: [schoolId],
  ).map((rows) => {
        for (final r in rows)
          (r['class_id'] as String): ((r['req'] as num?)?.toInt() ?? 0),
      });
});

// ─── Programme d'une classe (matières affectées) ─────────────────────────────
//  Le formulaire ne propose QUE les matières au programme de la classe
//  (`class_subjects`), pré-remplit l'enseignant (via `teacher_subjects`) et le
//  volume horaire — cohérence avec le modèle canonique matière↔affectation.
class ClassSubjectOption {
  const ClassSubjectOption({
    required this.subjectId,
    required this.subjectName,
    this.teacherId,
    this.weeklyHours,
  });
  final String subjectId, subjectName;
  final String? teacherId;
  final int? weeklyHours;
}

final classProgramProvider = StreamProvider.autoDispose
    .family<List<ClassSubjectOption>, String>((ref, classId) {
  if (classId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT cs.subject_id   AS subject_id,
           subj.name       AS subject_name,
           cs.weekly_hours AS weekly_hours,
           ts.staff_id     AS teacher_id
    FROM   class_subjects cs
    JOIN   subjects subj ON subj.id = cs.subject_id
    LEFT JOIN teacher_subjects ts
           ON ts.subject_id = cs.subject_id AND ts.class_id = cs.class_id
    WHERE  cs.class_id = ?
    ORDER  BY subj.display_order, subj.name
    ''',
    parameters: [classId],
  ).map((rows) => [
        for (final r in rows)
          ClassSubjectOption(
            subjectId: r['subject_id'] as String,
            subjectName: (r['subject_name'] as String?) ?? 'Matière',
            teacherId: r['teacher_id'] as String?,
            weeklyHours: (r['weekly_hours'] as num?)?.toInt(),
          ),
      ]);
});
