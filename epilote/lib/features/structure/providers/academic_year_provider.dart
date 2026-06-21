import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/academic_year_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();
String get _now => DateTime.now().toIso8601String();

// ─── Année académique courante ────────────────────────────────────────────────

/// Année académique active pour l'école / le groupe de l'utilisateur.
/// Lit depuis SQLite PowerSync (offline-first).
///
/// Préfère l'année propre à l'école ; à défaut, l'année définie au niveau du
/// groupe (`school_id` NULL = calendrier partagé par tout le groupe). Sans ce
/// repli, un membre rattaché à une école ne verrait jamais une année courante
/// définie globalement.
final currentAcademicYearProvider =
    StreamProvider.autoDispose<AcademicYearModel?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile == null) return Stream.value(null);

  final schoolId = profile.schoolId ?? '';
  final groupId  = profile.groupId ?? '';
  if (schoolId.isEmpty && groupId.isEmpty) return Stream.value(null);

  return db
      .watch(
        '''
        SELECT * FROM academic_years
        WHERE is_current = 1
          AND (school_id = ? OR (school_id IS NULL AND group_id = ?))
        ORDER BY school_id DESC   -- l'année propre à l'école (non NULL) prime
        LIMIT 1
        ''',
        parameters: [schoolId, groupId],
      )
      .map((rows) =>
          rows.isEmpty ? null : AcademicYearModel.fromMap(rows.first));
});

/// Toutes les années académiques visibles : celles propres à l'école + celles
/// définies au niveau du groupe (`school_id` NULL = calendrier partagé).
final academicYearsProvider =
    StreamProvider.autoDispose<List<AcademicYearModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile == null) return Stream.value([]);

  final schoolId = profile.schoolId ?? '';
  final groupId  = profile.groupId ?? '';
  if (schoolId.isEmpty && groupId.isEmpty) return Stream.value([]);

  return db
      .watch(
        '''
        SELECT * FROM academic_years
        WHERE school_id = ? OR (school_id IS NULL AND group_id = ?)
        ORDER BY start_date DESC
        ''',
        parameters: [schoolId, groupId],
      )
      .map((rows) => rows.map(AcademicYearModel.fromMap).toList());
});

// ─── Trimestres ───────────────────────────────────────────────────────────────

/// Trimestres d'une année académique donnée.
final trimestersProvider = StreamProvider.autoDispose
    .family<List<TrimesterModel>, String>((ref, academicYearId) {
  return db
      .watch(
        'SELECT * FROM trimesters WHERE academic_year_id = ? ORDER BY trimester_number',
        parameters: [academicYearId],
      )
      .map((rows) => rows.map(TrimesterModel.fromMap).toList());
});

/// Trimestre courant pour une année académique donnée.
final currentTrimesterProvider = StreamProvider.autoDispose
    .family<TrimesterModel?, String>((ref, academicYearId) {
  return db
      .watch(
        'SELECT * FROM trimesters WHERE academic_year_id = ? AND is_current = 1 LIMIT 1',
        parameters: [academicYearId],
      )
      .map((rows) =>
          rows.isEmpty ? null : TrimesterModel.fromMap(rows.first));
});

// ─── Séquences ────────────────────────────────────────────────────────────────

/// Séquences d'un trimestre donné.
final sequencesProvider = StreamProvider.autoDispose
    .family<List<SequenceModel>, String>((ref, trimesterId) {
  return db
      .watch(
        'SELECT * FROM sequences WHERE trimester_id = ? ORDER BY sequence_number',
        parameters: [trimesterId],
      )
      .map((rows) => rows.map(SequenceModel.fromMap).toList());
});

/// Séquence courante pour un trimestre donné.
final currentSequenceProvider = StreamProvider.autoDispose
    .family<SequenceModel?, String>((ref, trimesterId) {
  return db
      .watch(
        'SELECT * FROM sequences WHERE trimester_id = ? AND is_current = 1 LIMIT 1',
        parameters: [trimesterId],
      )
      .map((rows) =>
          rows.isEmpty ? null : SequenceModel.fromMap(rows.first));
});

// ─── École courante ──────────────────────────────────────────────────────────

/// École de l'utilisateur connecté (depuis SQLite PowerSync).
final currentSchoolProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value(null);
  }
  return db
      .watch(
        'SELECT * FROM schools WHERE id = ? LIMIT 1',
        parameters: [profile.schoolId],
      )
      .map((rows) => rows.isEmpty ? null : rows.first);
});

/// Logo du groupe scolaire de l'école courante — héritage de marque.
/// Sert de repli quand l'école n'a pas son propre `logo_url` : l'école étant une
/// émanation du groupe, elle hérite de son identité visuelle. 100% offline : la
/// ligne `school_groups` du périmètre est synchronisée par PowerSync.
final currentGroupLogoProvider = StreamProvider.autoDispose<String?>((ref) {
  final school = ref.watch(currentSchoolProvider).valueOrNull;
  final gid = school?['group_id'] as String?;
  if (gid == null || gid.isEmpty) return Stream.value(null);
  return db
      .watch(
        'SELECT logo_url FROM school_groups WHERE id = ? LIMIT 1',
        parameters: [gid],
      )
      .map((rows) =>
          rows.isEmpty ? null : rows.first['logo_url'] as String?);
});

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER = LECTURE SEULE côté école.
//  L'année / les trimestres / les séquences sont définis EXCLUSIVEMENT par
//  admin_groupe (le ministère, online) puis hérités par toutes les écoles via
//  PowerSync. Le personnel école les CONSULTE (providers ci-dessus) — il ne les
//  écrit JAMAIS (garanti aussi par la RLS : write réservé à
//  is_admin_groupe()/super_admin). Ceci supprime tout risque d'écriture
//  concurrente hors-ligne sur `is_current` (collision `uq_ay_current_group`).
//  Seule écriture côté école pour « adopter » une année = créer ses CLASSES.
// ════════════════════════════════════════════════════════════════════════════

// ─── Contenu d'une année (compteurs) ──────────────────────────────────────────

/// Nombre de classes actives + d'élèves inscrits (actifs) pour une année donnée.
/// Sert à montrer « le contenu » de chaque année dans l'historique.
typedef YearContentCount = ({int classes, int eleves});

final yearContentCountProvider = StreamProvider.autoDispose
    .family<YearContentCount, String>((ref, yearId) {
  return db
      .watch(
        '''
        SELECT
          (SELECT COUNT(*) FROM classes
             WHERE academic_year_id = ?1 AND is_active = 1)               AS classes,
          (SELECT COUNT(*) FROM class_enrollments
             WHERE academic_year_id = ?1 AND status = 'active')           AS eleves
        ''',
        parameters: [yearId],
      )
      .map((rows) => rows.isEmpty
          ? (classes: 0, eleves: 0)
          : (
              classes: (rows.first['classes'] as int?) ?? 0,
              eleves: (rows.first['eleves'] as int?) ?? 0,
            ));
});

/// PRÉPARER LA RENTRÉE (côté école) — recopie les classes actives d'une année
/// source vers une année cible, pour CETTE école, sans les inscriptions. Saute
/// les classes déjà présentes (même nom, insensible à la casse). Renvoie le
/// nombre de classes créées. L'année elle-même est définie par le groupe
/// (lecture seule côté école) ; ici on ne crée QUE des classes (données
/// opérationnelles propres à l'établissement).
Future<int> copySchoolClassesToYear({
  required String sourceYearId,
  required String targetYearId,
  required String schoolId,
  required String groupId,
}) async {
  final existing = await db.getAll(
    'SELECT name FROM classes WHERE academic_year_id = ? AND school_id = ?',
    [targetYearId, schoolId],
  );
  final taken =
      existing.map((r) => (r['name'] as String).toLowerCase().trim()).toSet();
  final src = await db.getAll(
    'SELECT name, capacity, room, level_id, main_teacher_id FROM classes '
    'WHERE academic_year_id = ? AND school_id = ? AND is_active = 1',
    [sourceYearId, schoolId],
  );
  var created = 0;
  for (final c in src) {
    if (taken.contains((c['name'] as String).toLowerCase().trim())) continue;
    await db.execute(
      '''INSERT INTO classes
         (id, school_id, group_id, academic_year_id, name, capacity,
          main_teacher_id, room, level_id, is_active, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)''',
      [
        _uuid.v4(), schoolId, groupId, targetYearId, c['name'], c['capacity'],
        c['main_teacher_id'], c['room'], c['level_id'], _now, _now,
      ],
    );
    created++;
  }
  return created;
}
