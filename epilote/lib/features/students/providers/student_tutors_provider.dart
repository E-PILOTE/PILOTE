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
///
/// ── POURQUOI [schoolId] EST OBLIGATOIRE ────────────────────────────────────
/// Depuis la migration 0110, `student_tutors.school_id` est NOT NULL et c'est
/// par lui que les sync-rules descendent les coordonnées des familles — par
/// école, et non plus par groupe.
///
/// Le serveur le recalcule de toute façon (trigger `trg_student_tutor_derive
/// _school`) : ce paramètre n'est pas là pour LUI. Il est là pour la base
/// LOCALE, où aucun trigger ne tourne. Une fiche saisie hors ligne avec un
/// `school_id` vide n'existerait pour aucune requête filtrant sur l'école
/// jusqu'au retour du réseau — c'est le piège `is_active` déjà rencontré, et
/// cette fois il ferait disparaître le seul numéro joignable d'une famille.
///
/// ⚠️ Ne JAMAIS passer `?? ''` ici, ni pour [groupId] : la colonne est un
/// `uuid` NOT NULL côté serveur, la chaîne vide y lève `22P02`, et un code
/// fatal fait abandonner à PowerSync le LOT ENTIER — l'élève et son
/// inscription compris. Passer par `isUsableId` / `missingWriteIds`.
Future<String> addTutor({
  required String studentId,
  required String groupId,
  required String schoolId,
  required String firstName,
  required String lastName,
  required String relationship,    // pere | mere | tuteur | autre
  required String phonePrimary,
  String? phoneSecondary,
  String? email,
  String? profession,
  String? address,
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
      id, student_id, group_id, school_id,
      first_name, last_name, relationship,
      phone_primary, phone_secondary, email, profession, address,
      is_primary_contact, has_app_access, user_id,
      is_emergency_contact,
      created_at, updated_at
    ) VALUES (
      ?, ?, ?, ?,
      ?, ?, ?,
      ?, ?, ?, ?, ?,
      ?, ?, ?,
      ?,
      ?, ?
    )
    ''',
    [
      id, studentId, groupId, schoolId,
      firstName, lastName, relationship,
      phonePrimary, phoneSecondary, email, profession, address,
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
  String? address,
  bool? isPrimaryContact,
  bool? hasAppAccess,
  bool? isEmergencyContact,
}) async {
  final now = DateTime.now().toIso8601String();

  final fields = <String, dynamic>{
    'first_name':          ?firstName,
    'last_name':           ?lastName,
    'relationship':        ?relationship,
    'phone_primary':       ?phonePrimary,
    'phone_secondary':     ?phoneSecondary,
    'email':               ?email,
    'profession':          ?profession,
    'address':             ?address,
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
