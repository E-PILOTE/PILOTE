import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/student_tutor_model.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Providers lecture ────────────────────────────────────────────────────────

/// Tuteurs d'un élève — offline-first, réactif.
final studentTutorsProvider = StreamProvider.autoDispose
    .family<List<StudentTutorModel>, String>((ref, studentId) {
  return db
      .watch(
        '''
        SELECT * FROM student_tutors
        WHERE  student_id = ?
        ORDER  BY is_primary_contact DESC, created_at ASC
        ''',
        parameters: [studentId],
      )
      .map((rows) => rows.map(StudentTutorModel.fromMap).toList());
});

/// Contact principal d'un élève (is_primary_contact = 1).
final primaryTutorProvider = StreamProvider.autoDispose
    .family<StudentTutorModel?, String>((ref, studentId) {
  return db
      .watch(
        '''
        SELECT * FROM student_tutors
        WHERE  student_id        = ?
        AND    is_primary_contact = 1
        LIMIT  1
        ''',
        parameters: [studentId],
      )
      .map((rows) => rows.isEmpty ? null : StudentTutorModel.fromMap(rows.first));
});

// ─── Mutations (offline-first) ────────────────────────────────────────────────

/// Ajoute un tuteur/contact pour un élève.
Future<String> addTutor({
  required String studentId,
  required String groupId,
  required String firstName,
  required String lastName,
  required String relationship,    // pere | mere | tuteur | autre
  required String phonePrimary,
  String? phoneSecondary,
  String? email,
  String? profession,
  bool isPrimaryContact = false,
  bool hasAppAccess = false,
  bool isEmergencyContact = false,
  String? userId,
}) async {
  final id  = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO student_tutors (
      id, student_id, group_id,
      first_name, last_name, relationship,
      phone_primary, phone_secondary, email, profession,
      is_primary_contact, has_app_access, user_id,
      is_emergency_contact,
      created_at, updated_at
    ) VALUES (
      ?, ?, ?,
      ?, ?, ?,
      ?, ?, ?, ?,
      ?, ?, ?,
      ?,
      ?, ?
    )
    ''',
    [
      id, studentId, groupId,
      firstName, lastName, relationship,
      phonePrimary, phoneSecondary, email, profession,
      isPrimaryContact ? 1 : 0, hasAppAccess ? 1 : 0, userId,
      isEmergencyContact ? 1 : 0,
      now, now,
    ],
  );
  return id;
}

/// Met à jour les informations d'un tuteur.
Future<void> updateTutor({
  required String tutorId,
  String? firstName,
  String? lastName,
  String? relationship,
  String? phonePrimary,
  String? phoneSecondary,
  String? email,
  String? profession,
  bool? isPrimaryContact,
  bool? hasAppAccess,
  bool? isEmergencyContact,
}) async {
  final now = DateTime.now().toIso8601String();

  final fields = <String, dynamic>{
    if (firstName          != null) 'first_name':          firstName,
    if (lastName           != null) 'last_name':           lastName,
    if (relationship       != null) 'relationship':        relationship,
    if (phonePrimary       != null) 'phone_primary':       phonePrimary,
    if (phoneSecondary     != null) 'phone_secondary':     phoneSecondary,
    if (email              != null) 'email':               email,
    if (profession         != null) 'profession':          profession,
    if (isPrimaryContact   != null) 'is_primary_contact':  isPrimaryContact ? 1 : 0,
    if (hasAppAccess       != null) 'has_app_access':      hasAppAccess ? 1 : 0,
    if (isEmergencyContact != null) 'is_emergency_contact': isEmergencyContact ? 1 : 0,
  };

  if (fields.isEmpty) return;

  final setClauses = fields.keys.map((k) => '$k = ?').join(', ');
  final values     = [...fields.values, now, tutorId];

  await db.execute(
    'UPDATE student_tutors SET $setClauses, updated_at = ? WHERE id = ?',
    values,
  );
}

/// Supprime un tuteur (hard delete — pas de données critiques liées).
Future<void> deleteTutor(String tutorId) async {
  await db.execute('DELETE FROM student_tutors WHERE id = ?', [tutorId]);
}
