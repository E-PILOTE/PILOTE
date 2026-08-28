import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../widgets/vs_kit.dart';

/// Le slug de CE module, déclaré à côté des requêtes qu'il borne — le
/// littéral recopié dans deux fichiers est ce qui laisse un périmètre dériver.
const kSlugCantine = 'cantine';

// ════════════════════════════════════════════════════════════════════════════
//  CANTINE (table `canteen_records`) — pointage des repas par élève × date ×
//  type de repas (présent/absent + note). Une ligne par (élève, date, repas).
//  100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kMealTypes = <(String, String)>[
  ('petit_dejeuner', 'Petit-déjeuner'),
  ('dejeuner', 'Déjeuner'),
  ('gouter', 'Goûter'),
];

String mealLabel(String code) =>
    kMealTypes.firstWhere((m) => m.$1 == code, orElse: () => ('dejeuner', 'Déjeuner')).$2;

typedef MealDay = ({String date, String meal});
typedef MealArgs = ({String classId, String date, String meal});

class CanteenOverview {
  const CanteenOverview({
    required this.rows,
    required this.served,
    required this.absent,
    required this.students,
  });
  final List<VsCoverageRow> rows;
  final int served, absent, students;
  int get classesTotal => rows.length;
}

final canteenOverviewProvider = FutureProvider.autoDispose
    .family<CanteenOverview, MealDay>((ref, day) async {
  ref.keepAlive();
  // Périmètre de CE module, jamais celui de `classes` : le `data_scope`
  // posé sur ce module doit produire un effet.
  final classes = ref.watch(classesForModuleProvider(kSlugCantine)).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const CanteenOverview(rows: [], served: 0, absent: 0, students: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');

  final rows = await db.getAll(
    'SELECT ce.class_id AS cid, cr.is_present AS pres '
    'FROM canteen_records cr '
    'JOIN class_enrollments ce ON ce.student_id = cr.student_id '
    "AND ce.status = 'active' "
    'WHERE cr.record_date = ? AND cr.meal_type = ? AND ce.class_id IN ($ph)',
    [day.date, day.meal, ...ids],
  );
  final served = <String, int>{};
  var totalServed = 0, totalAbsent = 0;
  for (final r in rows) {
    final cid = r['cid'] as String;
    if (((r['pres'] as int?) ?? 0) == 1) {
      served[cid] = (served[cid] ?? 0) + 1;
      totalServed++;
    } else {
      totalAbsent++;
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
        ok: served[c.id] ?? 0,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  return CanteenOverview(
    rows: cov,
    served: totalServed,
    absent: totalAbsent,
    students: cov.fold(0, (a, c) => a + c.total),
  );
});

class MealRow {
  const MealRow({
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.present,
    required this.recordId,
    required this.notes,
  });
  final String studentId, studentName;
  final String? matricule, recordId, notes;
  final bool? present; // null = non pointé
}

final classMealProvider =
    StreamProvider.autoDispose.family<List<MealRow>, MealArgs>((ref, args) {
  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           cr.id AS rid, cr.is_present AS pres, cr.notes AS notes
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    LEFT JOIN canteen_records cr
      ON cr.student_id = s.id AND cr.record_date = ? AND cr.meal_type = ?
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [args.date, args.meal, args.classId],
  ).map((rows) => [
        for (final r in rows)
          MealRow(
            studentId: r['sid'] as String,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            recordId: r['rid'] as String?,
            present: r['rid'] == null ? null : ((r['pres'] as int?) ?? 0) == 1,
            notes: r['notes'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
// ── ⚠️ UNE CLÉ MÉTIER UNIQUE, DONC UN IDENTIFIANT DÉDUIT ────────────────────
// La base tient `UNIQUE (student_id, record_date, meal_type)`. Deux INSERT pour le même
// fait — deux appuis rapides avant que le flux n'ait rafraîchi, ou deux
// appareils hors ligne — se font refuser en 23505. C'est un code FATAL pour le
// connecteur PowerSync : il jette le LOT ENTIER en attente, pas seulement la
// ligne fautive. La saisie de l'heure, les paiements, les notes : tout part.
//
// Deux gardes, comme pour l'appel (voir `core/utils/identite_offline.dart`) :
// la ligne se relit dans la base LOCALE sur sa clé métier — toutes les
// écritures y sont sérialisées, il n'y a pas de course — et l'identifiant d'une
// ligne neuve se DÉDUIT de cette clé, pour que deux appareils écrivent la même
// ligne au lieu d'en créer deux.
//
// ⚠️ [existingId] N'EST QU'UNE INDICATION, jamais la décision : il vient d'un
// instantané du flux. « Servi » puis « Absent » sur la même ligne — le geste
// ordinaire d'un pointage — arrivaient tous deux avec `existingId` nul et
// INSÉRAIENT deux fois. Rien dans l'écran ne l'empêchait : seul « Tout servi »
// était protégé d'un double appui.
Future<void> setMeal({
  required String groupId,
  required String schoolId,
  required String studentId,
  required String date,
  required String meal,
  required bool present,
  String? notes,
  String? existingId,
}) async {
  final now = DateTime.now().toIso8601String();
  final vue = await db.getAll(
    'SELECT id FROM canteen_records '
    'WHERE student_id = ? AND record_date = ? AND meal_type = ? LIMIT 1',
    [studentId, date, meal],
  );
  final cible = vue.isNotEmpty ? vue.first['id'] as String : existingId;
  if (cible != null) {
    await db.execute(
      'UPDATE canteen_records SET is_present = ?, notes = ?, updated_at = ? '
      'WHERE id = ?',
      [present ? 1 : 0, notes, now, cible],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO canteen_records (
        id, group_id, school_id, student_id, record_date, meal_type,
        is_present, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [idDeterministe('canteen_record', [studentId, date, meal]),
       groupId, schoolId, studentId, date, meal, present ? 1 : 0,
       notes, now, now],
    );
  }
}

/// Marque tous les élèves non pointés comme servis.
Future<int> markAllServed({
  required String groupId,
  required String schoolId,
  required String date,
  required String meal,
  required List<MealRow> rows,
}) async {
  // « Non encore pointé » se lit dans la BASE, pas dans [rows] : cette liste est
  // un instantané du flux, et après un premier « Tout servi » elle dit encore
  // que personne n'est pointé.
  final deja = {
    for (final e in await db.getAll(
      'SELECT student_id FROM canteen_records '
      'WHERE record_date = ? AND meal_type = ?',
      [date, meal],
    ))
      e['student_id'] as String
  };
  var n = 0;
  for (final r in rows) {
    if (r.present != null || deja.contains(r.studentId)) continue;
    await setMeal(
      groupId: groupId,
      schoolId: schoolId,
      studentId: r.studentId,
      date: date,
      meal: meal,
      present: true,
    );
    n++;
  }
  return n;
}
