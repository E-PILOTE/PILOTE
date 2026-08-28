import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';

const _uuid = Uuid();

/// Le slug de CE module, declare a cote des requetes qu'il borne.
const kSlugInfirmerie = 'infirmerie';

// ════════════════════════════════════════════════════════════════════════════
//  INFIRMERIE (table `infirmary_visits`, SENSIBLE — gatée par `sync_medical`).
//  Journal des passages à l'infirmerie : symptômes, diagnostic, traitement,
//  médication, repos, notification parents, suivi. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class InfirmaryVisit {
  const InfirmaryVisit({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.date,
    required this.time,
    required this.symptoms,
    required this.diagnosis,
    required this.treatment,
    required this.medication,
    required this.restHours,
    required this.parentNotified,
    required this.followUpRequired,
    required this.followUpNotes,
  });
  final String id, studentId, studentName;
  final String? classId, className, cycleCode, levelCode;
  final int levelOrder;
  final String date;
  final String? time, symptoms, diagnosis, treatment, medication, followUpNotes;
  final int? restHours;
  final bool parentNotified, followUpRequired;
}

final visitsProvider = StreamProvider.autoDispose<List<InfirmaryVisit>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);

  // Perimetre de CE module (verrou 4), ferme par defaut. Ce journal porte du
  // medical sur des mineurs : il servait l'ecole entiere a qui ouvrait l'ecran.
  final scope = classScopeClause(ref, kSlugInfirmerie, column: 'c.id');

  return db.watch(
    '''
    SELECT v.*, s.first_name, s.last_name,
           c.id AS cid, c.name AS class_name, c.cycle_code AS cycle_code,
           c.level_code AS level_code, c.level_order AS level_order
    FROM infirmary_visits v
    JOIN students s ON s.id = v.student_id
    -- Une seule ligne par passage, et la classe survit a la fermeture de
    -- l'inscription : sur `status = 'active'` seul, le passage d'un eleve sorti
    -- depuis perdait sa classe, donc sortait du filtre par classe.
    -- ATTENTION : `infirmary_visits` n'a PAS d'`academic_year_id`. On ne peut
    -- donc pas viser l'inscription de l'annee DU passage, comme le fait la
    -- discipline. On prend la plus recente, active d'abord : un passage de 6e
    -- relu en 3e affichera la classe d'aujourd'hui. Limite assumee, faute de
    -- colonne -- pas un oubli.
    LEFT JOIN classes c ON c.id = (
      SELECT ce.class_id FROM class_enrollments ce
       WHERE ce.student_id = v.student_id
       ORDER BY CASE WHEN ce.status = 'active' THEN 0 ELSE 1 END,
                ce.created_at DESC
       LIMIT 1)
    WHERE v.school_id = ?
    ${scope?.clause ?? ''}
    ORDER BY v.visit_date DESC, v.visit_time DESC, v.created_at DESC
    ''',
    parameters: [schoolId, ...?scope?.params],
  ).map((rows) => [
        for (final r in rows)
          InfirmaryVisit(
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
            date: (r['visit_date'] as String?) ?? '',
            time: r['visit_time'] as String?,
            symptoms: r['symptoms'] as String?,
            diagnosis: r['diagnosis'] as String?,
            treatment: r['treatment'] as String?,
            medication: r['medication'] as String?,
            restHours: r['rest_period_hours'] as int?,
            parentNotified: ((r['parent_notified'] as int?) ?? 0) == 1,
            followUpRequired: ((r['follow_up_required'] as int?) ?? 0) == 1,
            followUpNotes: r['follow_up_notes'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
// ATTENTION : `parent_notified` SANS `notified_at` NE DIT RIEN D'UTILE -- la
// colonne existait et restait vide. Un enfant reparti chez lui apres un
// malaise : on savait QUE les parents avaient ete prevenus, jamais QUAND. La
// date se pose quand la case passe a vrai et ne bouge plus ; la decocher
// l'efface. Meme defaut, meme correctif que `discipline_provider`.
Future<void> saveVisit({
  String? id,
  required String groupId,
  required String schoolId,
  required String studentId,
  required String date,
  String? time,
  String? symptoms,
  String? diagnosis,
  String? treatment,
  String? medication,
  int? restHours,
  required bool parentNotified,
  required bool followUpRequired,
  String? followUpNotes,
  required String staffId,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      '''
      UPDATE infirmary_visits SET visit_date = ?, visit_time = ?, symptoms = ?,
        diagnosis = ?, treatment = ?, medication = ?, rest_period_hours = ?,
        parent_notified = ?,
        notified_at = CASE WHEN ? = 1 THEN COALESCE(notified_at, ?) ELSE NULL END,
        follow_up_required = ?, follow_up_notes = ?,
        updated_at = ?
      WHERE id = ?
      ''',
      [date, time, symptoms, diagnosis, treatment, medication, restHours,
       parentNotified ? 1 : 0, parentNotified ? 1 : 0, now,
       followUpRequired ? 1 : 0, followUpNotes, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO infirmary_visits (
        id, group_id, school_id, student_id, visit_date, visit_time, symptoms,
        diagnosis, treatment, medication, rest_period_hours, parent_notified,
        notified_at, follow_up_required, follow_up_notes, staff_id,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, studentId, date, time, symptoms, diagnosis,
       treatment, medication, restHours, parentNotified ? 1 : 0,
       parentNotified ? now : null,
       followUpRequired ? 1 : 0, followUpNotes, staffId, now, now],
    );
  }
}

Future<void> deleteVisit(String id) async {
  await db.execute('DELETE FROM infirmary_visits WHERE id = ?', [id]);
}
