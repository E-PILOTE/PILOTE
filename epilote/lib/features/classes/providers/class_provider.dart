import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/class_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Verrou 4 : périmètre de données (own_school vs own_classes) ──────────────

/// Restriction de périmètre pour le module [slug].
/// • `null`  → aucune restriction (`own_school`) : toute l'école.
/// • liste   → uniquement ces `class_id` (peut être vide = aucune classe).
///
/// Pendant le chargement des ids d'un périmètre `own_classes`, retourne une
/// liste vide plutôt que `null` : on ne laisse JAMAIS fuiter toute l'école à un
/// enseignant le temps que ses classes se résolvent.
List<String>? _scopeRestriction(Ref ref, String slug) {
  final perm = ref.watch(modulePermissionProvider(slug));
  if (perm == null || !perm.isOwnClasses) return null; // own_school → tout
  return ref.watch(scopedClassIdsProvider(slug)).valueOrNull ?? const <String>[];
}

/// `?,?,?` pour un `IN (...)` paramétré.
String _placeholders(int n) => List.filled(n, '?').join(',');

// ─── Liste des classes ────────────────────────────────────────────────────────

/// Classes actives de l'école, avec le nombre d'élèves inscrits (actifs).
/// Utilise un JOIN SQLite local — fonctionne 100% hors-ligne.
final classesProvider =
    StreamProvider.autoDispose<List<ClassModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value([]);
  }

  final scopeIds = _scopeRestriction(ref, 'classes');
  if (scopeIds != null && scopeIds.isEmpty) return Stream.value([]);
  final scopeClause =
      scopeIds == null ? '' : 'AND c.id IN (${_placeholders(scopeIds.length)})';

  return db
      .watch(
        '''
        SELECT c.*,
               COALESCE(ec.cnt, 0) AS student_count
        FROM   classes c
        LEFT JOIN (
          SELECT class_id, COUNT(*) AS cnt
          FROM   class_enrollments
          WHERE  status = 'active'
          GROUP  BY class_id
        ) ec ON ec.class_id = c.id
        WHERE  c.school_id = ?
        AND    c.academic_year_id = ?
        AND    c.is_active  = 1
        $scopeClause
        ORDER  BY c.name
        ''',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.map(ClassModel.fromMap).toList());
});

// ─── Classe par ID ────────────────────────────────────────────────────────────

final classByIdProvider =
    StreamProvider.autoDispose.family<ClassModel?, String>((ref, classId) {
  return db
      .watch(
        '''
        SELECT c.*,
               COALESCE(ec.cnt, 0) AS student_count
        FROM   classes c
        LEFT JOIN (
          SELECT class_id, COUNT(*) AS cnt
          FROM   class_enrollments
          WHERE  status = 'active'
          GROUP  BY class_id
        ) ec ON ec.class_id = c.id
        WHERE  c.id = ?
        LIMIT  1
        ''',
        parameters: [classId],
      )
      .map((rows) => rows.isEmpty ? null : ClassModel.fromMap(rows.first));
});

// ─── Élèves inscrits dans une classe ─────────────────────────────────────────

/// Inscriptions actives d'une classe, avec les infos élèves (JOIN local).
final classEnrollmentsProvider = StreamProvider.autoDispose
    .family<List<ClassEnrollmentModel>, String>((ref, classId) {
  return db
      .watch(
        '''
        SELECT ce.*,
               s.first_name,
               s.last_name,
               s.matricule,
               s.photo_url,
               s.gender
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.class_id = ?
        AND    ce.status   = 'active'
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [classId],
      )
      .map((rows) => rows.map(ClassEnrollmentModel.fromMap).toList());
});

// ─── Stats globales ───────────────────────────────────────────────────────────

/// Nombre total de classes actives pour l'école courante.
final classCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(0);
  }
  final scopeIds = _scopeRestriction(ref, 'classes');
  if (scopeIds != null && scopeIds.isEmpty) return Stream.value(0);
  final scopeClause =
      scopeIds == null ? '' : 'AND id IN (${_placeholders(scopeIds.length)})';
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM classes '
        'WHERE school_id = ? AND academic_year_id = ? AND is_active = 1 $scopeClause',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});

/// Nombre total d'élèves inscrits (actifs) pour l'école et l'année actives.
final enrolledStudentCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(0);
  }
  final scopeIds = _scopeRestriction(ref, 'eleves');
  if (scopeIds != null && scopeIds.isEmpty) return Stream.value(0);
  final scopeClause =
      scopeIds == null ? '' : 'AND class_id IN (${_placeholders(scopeIds.length)})';
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM class_enrollments '
        'WHERE school_id = ? AND academic_year_id = ? AND status = \'active\' $scopeClause',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});

// ─── Mutations (offline-first) ────────────────────────────────────────────────

/// Crée une classe dans SQLite local — PowerSync la synchronise vers Supabase
/// dès que la connexion est disponible.
Future<String> createClass({
  required String schoolId,
  required String groupId,
  required String academicYearId,
  required String name,
  int? capacity,
  String? mainTeacherId,
  String? room,
  String? levelId,
}) async {
  // Pré-validation anti-perte silencieuse : contrainte UNIQUE
  // (school_id, academic_year_id, name). Sans ce contrôle, un doublon part en
  // local « avec succès » puis est rejeté en silence (23505) à la synchro.
  final dup = await db.getAll(
    'SELECT 1 FROM classes '
    'WHERE school_id = ? AND academic_year_id = ? AND name = ? LIMIT 1',
    [schoolId, academicYearId, name],
  );
  if (dup.isNotEmpty) {
    throw Exception('Une classe « $name » existe déjà pour cette année scolaire.');
  }

  final id  = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO classes
      (id, school_id, group_id, academic_year_id, name, capacity,
       main_teacher_id, room, level_id, is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, schoolId, groupId, academicYearId, name,
     capacity, mainTeacherId, room, levelId, now, now],
  );
  return id;
}

/// Archive une classe (soft delete — is_active = 0).
Future<void> archiveClass(String classId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE classes SET is_active = 0, updated_at = ? WHERE id = ?',
    [now, classId],
  );
}

// ─── Inscriptions en attente de validation ────────────────────────────────────

/// Inscriptions `pending_validation` de l'école courante (tableau du directeur).
final pendingEnrollmentsProvider =
    StreamProvider.autoDispose<List<ClassEnrollmentModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId  = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value([]);
  }
  final scopeIds = _scopeRestriction(ref, 'inscriptions');
  if (scopeIds != null && scopeIds.isEmpty) return Stream.value([]);
  final scopeClause =
      scopeIds == null ? '' : 'AND ce.class_id IN (${_placeholders(scopeIds.length)})';
  return db
      .watch(
        '''
        SELECT ce.*,
               s.first_name,
               s.last_name,
               s.matricule,
               s.photo_url,
               s.gender
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.school_id = ?
        AND    ce.academic_year_id = ?
        AND    ce.status    = 'pending_validation'
        $scopeClause
        ORDER  BY ce.created_at DESC
        ''',
        parameters: [profile.schoolId, yearId, ...?scopeIds],
      )
      .map((rows) => rows.map(ClassEnrollmentModel.fromMap).toList());
});

/// Inscrit un élève dans une classe avec statut `pending_validation`.
/// Le directeur devra valider ou rejeter via [validateEnrollment]/[rejectEnrollment].
Future<String> enrollStudent({
  required String schoolId,
  required String groupId,
  required String studentId,
  required String classId,
  required String academicYearId,
  bool isRepeating = false,
  String? previousClassId,
  String inscriptionType = 'new',        // new | reinscription | transfer
  String? previousSchoolName,
  String? previousClassName,
  String? transferReason,                // motif si type=transfer (0007)
  String? filiereId,                     // filière FP → education_programs (0007)
  String? notes,                         // notes internes (0007)
  String? createdBy,                     // agent ayant saisi l'inscription (0007)
}) async {
  // Pré-validation anti-perte silencieuse : contrainte UNIQUE
  // (student_id, academic_year_id) — un élève = une seule inscription par année
  // (tout statut confondu). Sans ce contrôle, le doublon serait rejeté en
  // silence (23505) à la synchro et l'inscription « disparaîtrait ».
  final dup = await db.getAll(
    'SELECT 1 FROM class_enrollments '
    'WHERE student_id = ? AND academic_year_id = ? LIMIT 1',
    [studentId, academicYearId],
  );
  if (dup.isNotEmpty) {
    throw Exception('Cet élève est déjà inscrit pour cette année scolaire.');
  }

  final id    = _uuid.v4();
  final now   = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  await db.execute(
    '''
    INSERT INTO class_enrollments
      (id, group_id, school_id, student_id, class_id, academic_year_id,
       enrollment_date, status, is_repeating, previous_class_id,
       inscription_type, previous_school_name, previous_class_name,
       transfer_reason, filiere_id, notes, created_by,
       created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending_validation', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      id, groupId, schoolId, studentId, classId, academicYearId,
      today, isRepeating ? 1 : 0, previousClassId,
      inscriptionType, previousSchoolName, previousClassName,
      transferReason, filiereId, notes, createdBy,
      now, now,
    ],
  );
  return id;
}

/// Valide une inscription (pending_validation → active).
Future<void> validateEnrollment({
  required String enrollmentId,
  required String validatedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status       = 'active',
           validated_at = ?,
           validated_by = ?,
           updated_at   = ?
    WHERE  id = ?
    ''',
    [now, validatedBy, now, enrollmentId],
  );
}

/// Rejette une inscription (pending_validation → rejected).
Future<void> rejectEnrollment({
  required String enrollmentId,
  required String rejectionReason,
  required String validatedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status           = 'rejected',
           rejection_reason = ?,
           validated_at     = ?,
           validated_by     = ?,
           updated_at       = ?
    WHERE  id = ?
    ''',
    [rejectionReason, now, validatedBy, now, enrollmentId],
  );
}

/// Retire un élève d'une classe (status → withdrawn).
Future<void> withdrawStudent({
  required String enrollmentId,
  required String reason,
}) async {
  final now   = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  await db.execute(
    '''
    UPDATE class_enrollments
    SET    status = 'withdrawn',
           withdrawal_date   = ?,
           withdrawal_reason = ?,
           updated_at        = ?
    WHERE  id = ?
    ''',
    [today, reason, now, enrollmentId],
  );
}
