import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/student_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Verrou 4 : périmètre de données du module `eleves` ──────────────────────

/// Sous-requête restreignant les élèves à ceux inscrits (actifs) dans les
/// classes du membre, quand son profil d'accès `eleves` est `own_classes`.
/// Retourne `null` (= aucune restriction, toute l'école) ou un fragment SQL
/// `AND id IN (SELECT …)` accompagné de ses paramètres.
({String clause, List<String> params})? _eleveScope(Ref ref) {
  final perm = ref.watch(modulePermissionProvider('eleves'));
  if (perm == null || !perm.isOwnClasses) return null; // own_school → tout
  final ids = ref.watch(scopedClassIdsProvider('eleves')).valueOrNull
      ?? const <String>[];
  final ph = List.filled(ids.length, '?').join(',');
  // ids vide → `IN ()` impossible : on force un ensemble vide via `IN (NULL)`.
  final clause = ids.isEmpty
      ? 'AND 0 = 1'
      : 'AND id IN (SELECT student_id FROM class_enrollments '
        "WHERE status = 'active' AND class_id IN ($ph))";
  return (clause: clause, params: ids);
}

// ─── Matricule ────────────────────────────────────────────────────────────────

/// Génère un matricule collision-safe pour création offline.
/// Format : {YEAR}-{8 premiers chars UUID} — ex. 2026-A3F7C2B1
/// Le serveur peut normaliser/remplacer à la sync si besoin.
String _generateMatricule() {
  final year   = DateTime.now().year;
  final suffix = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
  return '$year-$suffix';
}

// ─── Providers lecture ────────────────────────────────────────────────────────

/// Tous les élèves actifs de l'école — offline-first, réactif.
final studentsProvider = StreamProvider.autoDispose<List<StudentModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value([]);
  }
  final scope = _eleveScope(ref);
  return db
      .watch(
        '''
        SELECT * FROM students
        WHERE  school_id = ?
        AND    is_active  = 1
        ${scope?.clause ?? ''}
        ORDER  BY last_name, first_name
        ''',
        parameters: [profile.schoolId, ...?scope?.params],
      )
      .map((rows) => rows.map(StudentModel.fromMap).toList());
});

/// Élève par ID — offline-first.
final studentByIdProvider =
    StreamProvider.autoDispose.family<StudentModel?, String>((ref, studentId) {
  return db
      .watch(
        'SELECT * FROM students WHERE id = ? LIMIT 1',
        parameters: [studentId],
      )
      .map((rows) => rows.isEmpty ? null : StudentModel.fromMap(rows.first));
});

/// Recherche d'élèves par nom ou matricule (min 2 caractères).
final searchStudentsProvider =
    StreamProvider.autoDispose.family<List<StudentModel>, String>((ref, query) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || query.trim().length < 2) {
    return Stream.value([]);
  }
  final pattern = '%${query.trim()}%';
  final scope = _eleveScope(ref);
  return db
      .watch(
        '''
        SELECT * FROM students
        WHERE  school_id = ?
        AND    is_active  = 1
        AND    (first_name LIKE ? OR last_name LIKE ? OR matricule LIKE ?)
        ${scope?.clause ?? ''}
        ORDER  BY last_name, first_name
        LIMIT  50
        ''',
        parameters: [profile.schoolId, pattern, pattern, pattern, ...?scope?.params],
      )
      .map((rows) => rows.map(StudentModel.fromMap).toList());
});

/// Nombre d'élèves actifs pour l'école courante.
final studentCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value(0);
  }
  final scope = _eleveScope(ref);
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM students '
        'WHERE school_id = ? AND is_active = 1 ${scope?.clause ?? ''}',
        parameters: [profile.schoolId, ...?scope?.params],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});

// ─── Mutations (offline-first) ────────────────────────────────────────────────

/// Vérifie le quota d'élèves avant création offline.
/// Retourne null si OK, ou un message d'erreur si quota dépassé.
/// Actuellement aucun quota n'est enforced côté DB — toujours null.
/// À câbler si la table `schools` reçoit un champ `max_students` plus tard.
Future<String?> checkStudentQuota({
  required String schoolId,
  required String groupId,
}) async {
  return null;
}

/// Crée un élève dans SQLite local — PowerSync synchronise vers Supabase.
/// Retourne l'ID généré.
Future<String> createStudent({
  required String schoolId,
  required String groupId,
  required String firstName,
  required String lastName,
  String? id,
  DateTime? dateOfBirth,
  String? placeOfBirth,
  String? gender,
  String? nationality,
  String? address,
  String? city,
  String? region,
  String? photoUrl,
  String? bloodGroup,
  String? allergies,
  String? situationFamiliale,
  int nombreFreresSoeurs = 0,
  bool isBoarder = false,
  bool hasScholarship = false,
  String? scholarshipType,
  bool hasSocialAid = false,
  String? socialAidType,
  bool isAffecte = false,
}) async {
  final sid        = id ?? _uuid.v4();
  final matricule  = _generateMatricule();
  final now        = DateTime.now().toIso8601String();

  await db.execute(
    '''
    INSERT INTO students (
      id, school_id, group_id, matricule,
      first_name, last_name, date_of_birth, place_of_birth,
      gender, nationality, address, city, region, photo_url,
      blood_group, allergies,
      situation_familiale, nombre_freres_soeurs,
      is_boarder, has_scholarship, scholarship_type,
      has_social_aid, social_aid_type, is_affecte,
      is_active, created_at, updated_at
    ) VALUES (
      ?, ?, ?, ?,
      ?, ?, ?, ?,
      ?, ?, ?, ?, ?, ?,
      ?, ?,
      ?, ?,
      ?, ?, ?,
      ?, ?, ?,
      1, ?, ?
    )
    ''',
    [
      sid, schoolId, groupId, matricule,
      firstName, lastName,
      dateOfBirth?.toIso8601String().substring(0, 10),
      placeOfBirth,
      gender, nationality ?? 'Congolaise', address, city, region, photoUrl,
      bloodGroup, allergies,
      situationFamiliale, nombreFreresSoeurs,
      isBoarder ? 1 : 0, hasScholarship ? 1 : 0, scholarshipType,
      hasSocialAid ? 1 : 0, socialAidType, isAffecte ? 1 : 0,
      now, now,
    ],
  );
  return sid;
}

/// Met à jour les informations d'un élève.
Future<void> updateStudent({
  required String studentId,
  String? firstName,
  String? lastName,
  DateTime? dateOfBirth,
  String? placeOfBirth,
  String? gender,
  String? nationality,
  String? address,
  String? city,
  String? region,
  String? photoUrl,
  String? bloodGroup,
  String? allergies,
  String? situationFamiliale,
  int? nombreFreresSoeurs,
  bool? isBoarder,
  bool? hasScholarship,
  String? scholarshipType,
  bool? hasSocialAid,
  String? socialAidType,
  bool? isAffecte,
}) async {
  final now = DateTime.now().toIso8601String();

  final fields = <String, dynamic>{
    'first_name':           ?firstName,
    'last_name':            ?lastName,
    if (dateOfBirth       != null) 'date_of_birth':        dateOfBirth.toIso8601String().substring(0, 10),
    'place_of_birth':       ?placeOfBirth,
    'gender':               ?gender,
    'nationality':          ?nationality,
    'address':              ?address,
    'city':                 ?city,
    'region':               ?region,
    'photo_url':            ?photoUrl,
    'blood_group':          ?bloodGroup,
    'allergies':            ?allergies,
    'situation_familiale':  ?situationFamiliale,
    'nombre_freres_soeurs': ?nombreFreresSoeurs,
    if (isBoarder         != null) 'is_boarder':           isBoarder ? 1 : 0,
    if (hasScholarship    != null) 'has_scholarship':      hasScholarship ? 1 : 0,
    'scholarship_type':     ?scholarshipType,
    if (hasSocialAid      != null) 'has_social_aid':       hasSocialAid ? 1 : 0,
    'social_aid_type':      ?socialAidType,
    if (isAffecte         != null) 'is_affecte':           isAffecte ? 1 : 0,
  };

  if (fields.isEmpty) return;

  final setClauses = fields.keys.map((k) => '$k = ?').join(', ');
  final values     = [...fields.values, now, studentId];

  await db.execute(
    'UPDATE students SET $setClauses, updated_at = ? WHERE id = ?',
    values,
  );
}

/// Désactive un élève (soft delete — is_active = 0).
Future<void> deactivateStudent(String studentId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE students SET is_active = 0, updated_at = ? WHERE id = ?',
    [now, studentId],
  );
}
