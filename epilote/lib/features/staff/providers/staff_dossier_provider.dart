import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER RH DE L'AGENT — l'agent EST la ligne `profiles`. Identité + volet
//  carrière (statut/grade/échelon/catégorie/prise de service) en LECTURE (saisis
//  online par l'admin groupe à la provision du compte) ; les journaux
//  `staff_career` + `staff_diplomas` sont en CRUD offline (gérés par l'école).
//  Tables sensibles (bucket sensitive_finance). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

/// Statut de l'agent (axe employeur/financement) — aligné enum `employment_status`.
const kEmploymentStatuses = <(String, String)>[
  ('fonctionnaire', 'Fonctionnaire'),
  ('contractuel', 'Contractuel'),
  ('volontaire', 'Volontaire'),
  ('prestataire', 'Prestataire'),
  ('stagiaire', 'Stagiaire'),
  ('benevole', 'Bénévole'),
];

String employmentStatusLabel(String? s) => kEmploymentStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('', '—'))
    .$2;

// ─── Identité étendue de l'agent (profiles) ──────────────────────────────────
class StaffDossier {
  const StaffDossier({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.employeeNumber,
    this.employmentStatus,
    this.grade,
    this.echelon,
    this.category,
    this.speciality,
    this.hireDate,
    this.dateOfBirth,
    this.birthPlace,
    this.address,
    this.gender,
    this.teachingCycle,
  });

  final String id, firstName, lastName, role;
  final String? avatarUrl, phone, employeeNumber, employmentStatus;
  final String? grade, echelon, category, speciality;
  final String? hireDate, dateOfBirth, birthPlace, address, gender;
  final String? teachingCycle;

  String get fullName {
    final n = '${firstName.trim()} ${lastName.trim()}'.trim();
    return n.isEmpty ? '—' : n;
  }
}

final staffDossierProvider =
    StreamProvider.autoDispose.family<StaffDossier?, String>((ref, profileId) {
  return db.watch(
      '''
      SELECT p.*, (
        SELECT c.cycle_code FROM classes c
        WHERE c.main_teacher_id = p.id AND c.cycle_code IS NOT NULL
        UNION
        SELECT c2.cycle_code FROM teacher_subjects ts
        JOIN classes c2 ON c2.id = ts.class_id
        WHERE ts.staff_id = p.id AND c2.cycle_code IS NOT NULL
        LIMIT 1
      ) AS teaching_cycle
      FROM profiles p WHERE p.id = ?
      ''',
      parameters: [profileId]).map((rows) {
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StaffDossier(
      id: r['id'] as String,
      firstName: (r['first_name'] as String?) ?? '',
      lastName: (r['last_name'] as String?) ?? '',
      role: (r['role'] as String?) ?? '',
      avatarUrl: r['avatar_url'] as String?,
      phone: r['phone'] as String?,
      employeeNumber: r['employee_number'] as String?,
      employmentStatus: r['employment_status'] as String?,
      grade: r['grade'] as String?,
      echelon: r['echelon'] as String?,
      category: r['category'] as String?,
      speciality: r['speciality'] as String?,
      hireDate: r['hire_date'] as String?,
      dateOfBirth: r['date_of_birth'] as String?,
      birthPlace: r['birth_place'] as String?,
      address: r['address'] as String?,
      gender: r['gender'] as String?,
      teachingCycle: r['teaching_cycle'] as String?,
    );
  });
});

// ─── Parcours professionnel (staff_career) ───────────────────────────────────
class CareerEntry {
  const CareerEntry({
    required this.id,
    required this.position,
    this.organization,
    this.startDate,
    this.endDate,
    required this.isCurrent,
    this.notes,
  });
  final String id, position;
  final String? organization, startDate, endDate, notes;
  final bool isCurrent;
}

final staffCareerProvider = StreamProvider.autoDispose
    .family<List<CareerEntry>, String>((ref, profileId) {
  return db.watch(
    'SELECT * FROM staff_career WHERE profile_id = ? '
    'ORDER BY is_current DESC, start_date DESC, created_at DESC',
    parameters: [profileId],
  ).map((rows) => [
        for (final r in rows)
          CareerEntry(
            id: r['id'] as String,
            position: (r['position'] as String?) ?? '—',
            organization: r['organization'] as String?,
            startDate: r['start_date'] as String?,
            endDate: r['end_date'] as String?,
            isCurrent: r['is_current'] == 1 || r['is_current'] == true,
            notes: r['notes'] as String?,
          ),
      ]);
});

Future<void> saveCareerEntry({
  String? id,
  required String groupId,
  required String schoolId,
  required String profileId,
  required String position,
  String? organization,
  String? startDate,
  String? endDate,
  required bool isCurrent,
  String? notes,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE staff_career SET position = ?, organization = ?, start_date = ?, '
      'end_date = ?, is_current = ?, notes = ?, updated_at = ? WHERE id = ?',
      [position, organization, startDate, endDate, isCurrent ? 1 : 0, notes,
       now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO staff_career (
        id, group_id, school_id, profile_id, position, organization,
        start_date, end_date, is_current, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, profileId, position, organization,
       startDate, endDate, isCurrent ? 1 : 0, notes, now, now],
    );
  }
}

Future<void> deleteCareerEntry(String id) async {
  await db.execute('DELETE FROM staff_career WHERE id = ?', [id]);
}

// ─── Diplômes & qualifications (staff_diplomas) ──────────────────────────────
class Diploma {
  const Diploma({
    required this.id,
    required this.title,
    this.level,
    this.field,
    this.institution,
    this.yearObtained,
  });
  final String id, title;
  final String? level, field, institution;
  final int? yearObtained;
}

final staffDiplomasProvider = StreamProvider.autoDispose
    .family<List<Diploma>, String>((ref, profileId) {
  return db.watch(
    'SELECT * FROM staff_diplomas WHERE profile_id = ? '
    'ORDER BY year_obtained DESC, created_at DESC',
    parameters: [profileId],
  ).map((rows) => [
        for (final r in rows)
          Diploma(
            id: r['id'] as String,
            title: (r['title'] as String?) ?? '—',
            level: r['level'] as String?,
            field: r['field'] as String?,
            institution: r['institution'] as String?,
            yearObtained: (r['year_obtained'] as num?)?.round(),
          ),
      ]);
});

Future<void> saveDiploma({
  String? id,
  required String groupId,
  required String schoolId,
  required String profileId,
  required String title,
  String? level,
  String? field,
  String? institution,
  int? yearObtained,
}) async {
  final now = DateTime.now().toIso8601String();
  if (id != null) {
    await db.execute(
      'UPDATE staff_diplomas SET title = ?, level = ?, field = ?, '
      'institution = ?, year_obtained = ?, updated_at = ? WHERE id = ?',
      [title, level, field, institution, yearObtained, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO staff_diplomas (
        id, group_id, school_id, profile_id, title, level, field,
        institution, year_obtained, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, profileId, title, level, field,
       institution, yearObtained, now, now],
    );
  }
}

Future<void> deleteDiploma(String id) async {
  await db.execute('DELETE FROM staff_diplomas WHERE id = ?', [id]);
}

/// Niveaux de diplôme courants (Congo) — proposés au formulaire.
const kDiplomaLevels = <String>[
  'CEPE', 'BEPC', 'BAC', 'BAC+2 / DEUG', 'Licence', 'Master / Maîtrise',
  'Doctorat', 'CAP', 'BEP', 'CAFOP', 'CAPES', 'CAPET', 'Certificat', 'Autre',
];
