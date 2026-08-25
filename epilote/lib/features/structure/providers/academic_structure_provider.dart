import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STRUCTURE ACADÉMIQUE (direction, offline-first).
//  Hiérarchie RÉELLE Cycle → Niveau → Classe, dérivée 100% des tables
//  synchronisées : school_cycles (cycles offerts) × education_cycles (libellés)
//  × school_levels (catalogue niveaux du groupe) × classes (année active).
//  Le référentiel (cycles/niveaux/filières) est gouverné par l'admin_groupe
//  (RLS) → lecture ici ; le levier de la direction = créer/éditer les CLASSES.
// ════════════════════════════════════════════════════════════════════════════

class StructClass {
  const StructClass({
    required this.id,
    required this.name,
    required this.capacity,
    required this.enrolled,
    required this.filiereLabel,
    this.room,
    this.teacherId,
    this.teacherName,
  });
  final String id, name;
  final int? capacity;
  final int enrolled;
  final String? filiereLabel;
  final String? room, teacherId, teacherName;

  double? get fillRatio =>
      (capacity == null || capacity == 0) ? null : enrolled / capacity!;
  bool get isOver => capacity != null && enrolled > capacity!;
  bool get isNearFull {
    final r = fillRatio;
    return r != null && r >= 0.9 && !isOver;
  }
}

class StructLevel {
  const StructLevel({
    required this.id,
    required this.name,
    required this.code,
    required this.order,
    required this.classes,
  });
  final String id, name, code;
  final int order;
  final List<StructClass> classes;

  int get enrolled => classes.fold(0, (s, c) => s + c.enrolled);
  int get capacity => classes.fold(0, (s, c) => s + (c.capacity ?? 0));
}

class StructCycle {
  const StructCycle({
    required this.code,
    required this.name,
    required this.order,
    required this.hasPrograms,
    required this.levels,
  });
  final String code, name;
  final int order;
  final bool hasPrograms;
  final List<StructLevel> levels;

  int get classCount => levels.fold(0, (s, l) => s + l.classes.length);
  int get enrolled => levels.fold(0, (s, l) => s + l.enrolled);
  int get capacity => levels.fold(0, (s, l) => s + l.capacity);
  int get emptyLevels => levels.where((l) => l.classes.isEmpty).length;
  double? get fillRatio => capacity == 0 ? null : enrolled / capacity;
}

class AcademicStructure {
  const AcademicStructure(this.cycles);
  final List<StructCycle> cycles;
  static const empty = AcademicStructure([]);

  int get levelCount => cycles.fold(0, (s, c) => s + c.levels.length);
  int get classCount => cycles.fold(0, (s, c) => s + c.classCount);
  int get enrolled => cycles.fold(0, (s, c) => s + c.enrolled);
}

/// Hiérarchie complète Cycle → Niveau → Classe (réactive, offline).
final academicStructureProvider =
    StreamProvider.autoDispose<AcademicStructure>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId = ref.watch(activeYearIdProvider);
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(AcademicStructure.empty);
  }

  return db.watch(
    '''
    SELECT
      ec.code         AS cycle_code,
      ec.name         AS cycle_name,
      ec.order_index  AS cycle_order,
      ec.has_programs AS has_programs,
      sl.id           AS level_id,
      sl.name         AS level_name,
      sl.code         AS level_code,
      sl.order_index  AS level_order,
      c.id            AS class_id,
      c.name          AS class_name,
      c.capacity      AS capacity,
      c.room          AS room,
      c.filiere_label AS filiere_label,
      c.main_teacher_id AS teacher_id,
      (SELECT TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,''))
         FROM profiles p WHERE p.id = c.main_teacher_id) AS teacher_name,
      (SELECT COUNT(*) FROM class_enrollments ce
         WHERE ce.class_id = c.id AND ce.status = 'active') AS enrolled
    FROM school_cycles sc
    JOIN education_cycles ec ON ec.id = sc.cycle_id
    LEFT JOIN school_levels sl
           ON sl.cycle_id = sc.cycle_id
          -- ⚠️ SANS CETTE LIGNE, l'écran affichait les niveaux de TOUTES les
          -- écoles du réseau : 42 au lieu de 6, sept copies de CP1, CE1, CM2.
          -- `school_levels` porte bien un `school_id` — le filtre sur le seul
          -- `group_id` laissait entrer les catalogues voisins.
          AND sl.school_id = sc.school_id
          AND sl.group_id  = sc.group_id
          -- `is_active = 1` rate les lignes écrites par l'application : la vue
          -- PowerSync n'y met pas toujours un entier. Un niveau créé le matin
          -- disparaissait de l'écran l'après-midi.
          AND COALESCE(sl.is_active, 1) <> 0
    LEFT JOIN classes c
           ON c.level_id = sl.id
          AND c.school_id = ?
          AND c.academic_year_id = ?
          AND COALESCE(c.is_active, 1) <> 0
    WHERE sc.school_id = ?
    ORDER BY ec.order_index, sl.order_index, c.name
    ''',
    parameters: [schoolId, yearId, schoolId],
  ).map(_foldStructure);
});

AcademicStructure _foldStructure(List<Map<String, dynamic>> rows) {
  // Regroupe les lignes plates en Cycle → Niveau → Classe.
  final cycles = <String, _CycleAcc>{};
  for (final r in rows) {
    final cCode = r['cycle_code'] as String?;
    if (cCode == null) continue;
    final cyc = cycles.putIfAbsent(
      cCode,
      () => _CycleAcc(
        code: cCode,
        name: (r['cycle_name'] as String?) ?? cCode,
        order: (r['cycle_order'] as num?)?.toInt() ?? 0,
        hasPrograms: r['has_programs'] == 1 || r['has_programs'] == true,
      ),
    );
    final levelId = r['level_id'] as String?;
    if (levelId == null) continue; // cycle sans niveau (rare)
    final lvl = cyc.levels.putIfAbsent(
      levelId,
      () => _LevelAcc(
        id: levelId,
        name: (r['level_name'] as String?) ?? '',
        code: (r['level_code'] as String?) ?? '',
        order: (r['level_order'] as num?)?.toInt() ?? 0,
      ),
    );
    final classId = r['class_id'] as String?;
    if (classId == null) continue; // niveau sans classe
    final tName = (r['teacher_name'] as String?)?.trim();
    lvl.classes.add(StructClass(
      id: classId,
      name: (r['class_name'] as String?) ?? '',
      capacity: (r['capacity'] as num?)?.toInt(),
      enrolled: (r['enrolled'] as num?)?.toInt() ?? 0,
      filiereLabel: r['filiere_label'] as String?,
      room: r['room'] as String?,
      teacherId: r['teacher_id'] as String?,
      teacherName: (tName == null || tName.isEmpty) ? null : tName,
    ));
  }

  final out = cycles.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return AcademicStructure([
    for (final c in out)
      StructCycle(
        code: c.code,
        name: c.name,
        order: c.order,
        hasPrograms: c.hasPrograms,
        levels: (c.levels.values.toList()
              ..sort((a, b) => a.order.compareTo(b.order)))
            .map((l) => StructLevel(
                  id: l.id,
                  name: l.name,
                  code: l.code,
                  order: l.order,
                  classes: l.classes,
                ))
            .toList(),
      ),
  ]);
}

class _CycleAcc {
  _CycleAcc({
    required this.code,
    required this.name,
    required this.order,
    required this.hasPrograms,
  });
  final String code, name;
  final int order;
  final bool hasPrograms;
  final Map<String, _LevelAcc> levels = {};
}

class _LevelAcc {
  _LevelAcc({
    required this.id,
    required this.name,
    required this.code,
    required this.order,
  });
  final String id, name, code;
  final int order;
  final List<StructClass> classes = [];
}

// ─── Filières (séries lycée / métiers FP) par cycle — référentiel offline ────
class StructFiliere {
  const StructFiliere(this.code, this.name);
  final String code, name;
}

/// Filières disponibles pour un cycle (vide si le cycle n'a pas de filières).
final cycleFilieresProvider = FutureProvider.autoDispose
    .family<List<StructFiliere>, String>((ref, cycleCode) async {
  final rows = await db.getAll(
    '''
    SELECT ep.code, ep.name
    FROM education_programs ep
    JOIN education_cycles ec ON ec.id = ep.cycle_id
    WHERE ec.code = ? AND COALESCE(ep.is_active, 1) <> 0
    ORDER BY ep.order_index, ep.name
    ''',
    [cycleCode],
  );
  return [
    for (final r in rows)
      StructFiliere((r['code'] as String?) ?? '', (r['name'] as String?) ?? ''),
  ];
});

// ─── Enseignants de l'école (pour l'affectation du professeur principal) ─────
class SchoolTeacher {
  const SchoolTeacher(this.id, this.fullName);
  final String id, fullName;
}

final schoolTeachersProvider =
    StreamProvider.autoDispose<List<SchoolTeacher>>((ref) {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT id, TRIM(COALESCE(first_name,'') || ' ' || COALESCE(last_name,'')) AS full_name
    FROM profiles
    WHERE school_id = ? AND COALESCE(is_active, 1) <> 0
      AND role IN ('enseignant', 'directeur', 'proviseur')
    ORDER BY last_name, first_name
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          SchoolTeacher(
            r['id'] as String,
            ((r['full_name'] as String?)?.trim().isNotEmpty ?? false)
                ? (r['full_name'] as String).trim()
                : 'Sans nom',
          ),
      ]);
});
