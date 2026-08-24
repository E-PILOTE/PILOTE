import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DOSSIER D'UN ÉLÈVE — identité, tuteurs, et la ligne de scolarité brute.
//
//  Extrait de `inscriptions_data_provider.dart`, qui dépassait largement les
//  500 lignes de la règle maison. La coupe suit une couture de cohésion : ce
//  fichier répond à « que sait-on de CET élève », l'autre à « où en est le
//  guichet ». Deux questions, deux lecteurs, deux fichiers.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

class StudentTutorInfo {
  const StudentTutorInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.phonePrimary,
    required this.phoneSecondary,
    required this.email,
    required this.profession,
    required this.address,
    required this.isPrimary,
    required this.isEmergency,
  });
  final String id, firstName, lastName, relationship;
  final String? phonePrimary, phoneSecondary, email, profession, address;
  final bool isPrimary, isEmergency;

  String get fullName => '$firstName $lastName'.trim();
}

class StudentDossier {
  const StudentDossier({required this.student, required this.tutors});
  final Map<String, dynamic> student; // ligne students brute
  final List<StudentTutorInfo> tutors;

  String s(String k) => (student[k] as String?)?.trim() ?? '';
  DateTime? get dob => _d(student['date_of_birth']);
}

/// Dossier élève (offline) : ligne students + tuteurs. Invalidé après édition.
final studentDossierProvider =
    FutureProvider.autoDispose.family<StudentDossier, String>((ref, id) async {
  final s = await db.getOptional('SELECT * FROM students WHERE id = ?', [id]);
  final tutors = await db.getAll(
    'SELECT * FROM student_tutors WHERE student_id = ? '
    'ORDER BY is_primary_contact DESC, last_name',
    [id],
  );
  return StudentDossier(
    student: s ?? const {},
    tutors: [
      for (final t in tutors)
        StudentTutorInfo(
          id: (t['id'] as String?) ?? '',
          firstName: (t['first_name'] as String?) ?? '',
          lastName: (t['last_name'] as String?) ?? '',
          relationship: (t['relationship'] as String?) ?? '',
          phonePrimary: t['phone_primary'] as String?,
          phoneSecondary: t['phone_secondary'] as String?,
          email: t['email'] as String?,
          profession: t['profession'] as String?,
          address: t['address'] as String?,
          isPrimary: t['is_primary_contact'] == 1 ||
              t['is_primary_contact'] == true,
          isEmergency: t['is_emergency_contact'] == 1 ||
              t['is_emergency_contact'] == true,
        ),
    ],
  );
});

/// Ligne brute `class_enrollments` (champs scolarité non portés par la vue
/// liste : école/classe d'origine, motif transfert, notes, rejet, retrait).
/// Utilisée par la fiche détail et l'assistant de modification.
final enrollmentDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, enrollmentId) async {
  final r = await db.getOptional(
      'SELECT * FROM class_enrollments WHERE id = ?', [enrollmentId]);
  return r ?? const <String, dynamic>{};
});
