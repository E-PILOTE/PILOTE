import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_context.dart';

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
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }

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
    -- La classe DU JOUR DES FAITS : l'inscription de l'annee du passage,
    -- `active` d'abord, close acceptee ensuite -- sinon le passage d'un eleve
    -- parti depuis perdrait sa classe, donc sortirait du filtre. Le
    -- sous-select rend UNE ligne : une jointure sans annee en rendait deux
    -- apres une reconduction, et le meme passage se comptait deux fois.
    LEFT JOIN classes c ON c.id = (
      SELECT ce.class_id FROM class_enrollments ce
       WHERE ce.student_id = v.student_id
         AND ce.academic_year_id = v.academic_year_id
       ORDER BY CASE WHEN ce.status = 'active' THEN 0 ELSE 1 END,
                ce.created_at DESC
       LIMIT 1)
    WHERE v.school_id = ? AND v.academic_year_id = ?
    ${scope?.clause ?? ''}
    ORDER BY v.visit_date DESC, v.visit_time DESC, v.created_at DESC
    ''',
    parameters: [schoolId, yearId, ...?scope?.params],
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
  required String academicYearId,
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
        academic_year_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, studentId, date, time, symptoms, diagnosis,
       treatment, medication, restHours, parentNotified ? 1 : 0,
       parentNotified ? now : null,
       followUpRequired ? 1 : 0, followUpNotes, staffId, academicYearId,
       now, now],
    );
  }
}

Future<void> deleteVisit(String id) async {
  await db.execute('DELETE FROM infirmary_visits WHERE id = ?', [id]);
}

// ═══ L'ALERTE MEDICALE ══════════════════════════════════════════
//
// ATTENTION -- CECI EST LE POINT LE PLUS SERIEUX DU MODULE. Le formulaire de
// passage offre un champ « Medication » en texte libre : c'est la que
// l'infirmier note ce qu'il a administre. `students.allergies` et
// `students.blood_group` existent, se saisissent a l'inscription, et
// DESCENDENT DEJA sur le poste (ils sont declares dans le schema PowerSync
// local). L'ecran ne les montrait nulle part.
//
// Autrement dit : l'application connaissait l'allergie de l'enfant, l'avait
// sous la main, hors ligne, et se taisait au moment exact ou quelqu'un allait
// lui donner un medicament. Une infirmerie scolaire au Congo n'a pas de second
// systeme pour verifier.
//
// Provider a part, et non deux champs de plus sur `VsStudent` : ce modele est
// partage avec Discipline et Bibliotheque, qui n'ont aucune raison de porter
// du medical dans leur memoire.
typedef AlerteMedicale = ({String? allergies, String? groupeSanguin});

final alerteMedicaleProvider =
    StreamProvider.autoDispose.family<AlerteMedicale, String>((ref, studentId) {
  if (studentId.isEmpty) {
    return Stream.value((allergies: null, groupeSanguin: null));
  }
  return db.watch(
    'SELECT allergies, blood_group FROM students WHERE id = ? LIMIT 1',
    parameters: [studentId],
  ).map((rows) {
    if (rows.isEmpty) return (allergies: null, groupeSanguin: null);
    String? net(Object? v) {
      final t = (v as String?)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return (
      allergies: net(rows.first['allergies']),
      groupeSanguin: net(rows.first['blood_group']),
    );
  });
});

/// Clot un suivi : la case « Suivi requis » retombe, et ce qui a ete fait
/// s'ajoute aux notes.
///
/// ATTENTION -- « Suivi requis » etait un compteur QUI NE REDESCENDAIT JAMAIS.
/// L'infirmier cochait la case pour se souvenir de revoir l'enfant, et rien,
/// nulle part, ne permettait de dire que c'etait fait : le KPI montait
/// indefiniment jusqu'a ne plus rien vouloir dire, et un suivi reellement en
/// attente se noyait dans les suivis deja traites. Un rappel qu'on ne peut pas
/// eteindre cesse d'etre lu.
Future<void> cloreSuivi(String id, {String? note}) async {
  final now = DateTime.now().toIso8601String();
  final ligne = note == null || note.trim().isEmpty
      ? 'Suivi effectue le ${now.substring(0, 10)}'
      : 'Suivi effectue le ${now.substring(0, 10)} : ${note.trim()}';
  await db.execute(
    '''
    UPDATE infirmary_visits
       SET follow_up_required = 0,
           follow_up_notes = CASE
             WHEN follow_up_notes IS NULL OR TRIM(follow_up_notes) = '' THEN ?
             ELSE follow_up_notes || char(10) || ?
           END,
           updated_at = ?
     WHERE id = ?
    ''',
    [ligne, ligne, now, id],
  );
}
