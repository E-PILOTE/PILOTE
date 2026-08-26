import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../widgets/vs_kit.dart';

/// Le slug de CE module, déclaré à côté des requêtes qu'il borne — le
/// littéral recopié dans deux fichiers est ce qui laisse un périmètre dériver.
const kSlugOrientation = 'orientation';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  ORIENTATION (table `student_orientations`) — recommandation d'orientation par
//  élève × trimestre : niveau/filière cible, recommandation, consultation des
//  parents. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

typedef OrientationArgs = ({String classId, String? trimesterId});

class OrientationOverview {
  const OrientationOverview({
    required this.rows,
    required this.oriented,
    required this.consulted,
    required this.students,
  });
  final List<VsCoverageRow> rows;
  final int oriented, consulted, students;
  int get classesTotal => rows.length;
}

final orientationOverviewProvider = FutureProvider.autoDispose
    .family<OrientationOverview, String?>((ref, trimesterId) async {
  ref.keepAlive();
  // Périmètre de CE module, jamais celui de `classes` : le `data_scope`
  // posé sur ce module doit produire un effet.
  final classes = ref.watch(classesForModuleProvider(kSlugOrientation)).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const OrientationOverview(
        rows: [], oriented: 0, consulted: 0, students: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');
  final trimClause = trimesterId != null ? 'AND o.trimester_id = ?' : '';
  final params = <Object?>[...ids];
  if (trimesterId != null) params.add(trimesterId);

  final rows = await db.getAll(
    'SELECT ce.class_id AS cid, o.parent_consulted AS pc '
    'FROM student_orientations o '
    'JOIN class_enrollments ce ON ce.student_id = o.student_id '
    "AND ce.status = 'active' "
    'WHERE ce.class_id IN ($ph) $trimClause',
    params,
  );
  final oriented = <String, int>{};
  var totalOriented = 0, consulted = 0;
  for (final r in rows) {
    final cid = r['cid'] as String;
    oriented[cid] = (oriented[cid] ?? 0) + 1;
    totalOriented++;
    if (((r['pc'] as int?) ?? 0) == 1) consulted++;
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
        ok: oriented[c.id] ?? 0,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  return OrientationOverview(
    rows: cov,
    oriented: totalOriented,
    consulted: consulted,
    students: cov.fold(0, (a, c) => a + c.total),
  );
});

class OrientationRow {
  const OrientationRow({
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.recordId,
    required this.recommendation,
    required this.targetLevel,
    required this.targetFiliere,
    required this.parentConsulted,
  });
  final String studentId, studentName;
  final String? matricule, recordId, recommendation, targetLevel, targetFiliere;
  final bool parentConsulted;

  bool get oriented => recordId != null;
}

final classOrientationProvider = StreamProvider.autoDispose
    .family<List<OrientationRow>, OrientationArgs>((ref, args) {
  final trimClause = args.trimesterId != null ? 'AND o.trimester_id = ?' : '';
  final params = <Object?>[];
  if (args.trimesterId != null) params.add(args.trimesterId);
  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           o.id AS oid, o.recommendation AS reco, o.target_level AS tl,
           o.target_filiere AS tf, o.parent_consulted AS pc
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    LEFT JOIN student_orientations o
      ON o.student_id = s.id $trimClause
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [...params, args.classId],
  ).map((rows) => [
        for (final r in rows)
          OrientationRow(
            studentId: r['sid'] as String,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            recordId: r['oid'] as String?,
            recommendation: r['reco'] as String?,
            targetLevel: r['tl'] as String?,
            targetFiliere: r['tf'] as String?,
            parentConsulted: ((r['pc'] as int?) ?? 0) == 1,
          ),
      ]);
});

// ─── Mutation ────────────────────────────────────────────────────────────────
Future<void> saveOrientation({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String studentId,
  String? trimesterId,
  String? recommendation,
  String? targetLevel,
  String? targetFiliere,
  required bool parentConsulted,
  required String counselorId,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      '''
      UPDATE student_orientations SET recommendation = ?, target_level = ?,
        target_filiere = ?, parent_consulted = ?, trimester_id = ?, updated_at = ?
      WHERE id = ?
      ''',
      [recommendation, targetLevel, targetFiliere, parentConsulted ? 1 : 0,
       trimesterId, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO student_orientations (
        id, group_id, school_id, student_id, academic_year_id, trimester_id,
        recommendation, target_level, target_filiere, counselor_id,
        parent_consulted, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, studentId, academicYearId, trimesterId,
       recommendation, targetLevel, targetFiliere, counselorId,
       parentConsulted ? 1 : 0, now, now],
    );
  }
}

Future<void> deleteOrientation(String id) async {
  await db.execute('DELETE FROM student_orientations WHERE id = ?', [id]);
}
