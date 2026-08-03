import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER DE L'ÉLÈVE — vue ministère (admin_groupe, online, lecture seule).
//
//  Rassemble ce qu'un cabinet doit pouvoir consulter sur un enfant scolarisé
//  dans son réseau : identité, inscription, famille, équipe enseignante,
//  établissement de rattachement et conduite.
//
//  ── DEUX LIGNES DE PARTAGE, TENUES ─────────────────────────────────────────
//  • Le MÉDICAL (groupe sanguin, allergies) n'est jamais demandé : c'est la
//    donnée la plus sensible du dossier et elle n'a aucun usage de pilotage.
//  • La CONDUITE remonte avec son MOTIF — un ministère qui lit une sanction
//    sans savoir pourquoi ne peut ni arbitrer ni protéger l'élève — mais les
//    `follow_up_notes` (cahier de suivi du CPE) restent à l'établissement.
//    On transmet les faits, pas le carnet de travail de celui qui les suit.
// ════════════════════════════════════════════════════════════════════════════

/// Rang au classement des classes de passage, tel qu'on le présente en tête de
/// dossier quand on arrive depuis le classement.
///
/// ── DEUX MENTIONS OBLIGATOIRES, JAMAIS DÉCORATIVES ──────────────────────────
/// [scope] : un rang n'existe que dans un périmètre. « 1ᵉʳ » sur un trimestre
/// et un niveau n'est pas « 1ᵉʳ du pays », et un dossier qui l'afficherait sans
/// le dire ferait décider de travers.
///
/// [basis] : ce rang repose sur le CONTRÔLE CONTINU, calculé par
/// l'établissement — pas sur une épreuve nationale. La plateforme ne calcule
/// aucun résultat d'examen d'État : elle transmet la liste des candidats à la
/// DEC, qui proclame les admis. Sans cette ligne, une pièce qui circule se
/// lirait comme une distinction d'examen. [classAverage] est là pour la même
/// raison : 16/20 dans une classe à 15 n'est pas 16/20 dans une classe à 9.
class DossierDistinction {
  const DossierDistinction({
    required this.rank,
    required this.average,
    required this.mention,
    required this.scope,
    required this.basis,
    this.exAequo = false,
    this.classAverage,
  });

  final int rank;
  final double average;
  final String mention;
  final String scope;
  final String basis;
  final bool exAequo;
  final double? classAverage;

  /// Ligne de provenance : la base d'abord, la moyenne de classe ensuite.
  List<String> get details => [
        basis,
        if (classAverage != null)
          'moyenne de la classe : ${classAverage!.toStringAsFixed(2)}',
      ];
}

class DossierTutor {
  const DossierTutor({
    required this.fullName,
    this.relationship,
    this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.profession,
    this.address,
    this.isPrimary = false,
    this.isEmergency = false,
  });

  final String fullName;
  final String? relationship;
  final String? phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? profession;
  final String? address;
  final bool isPrimary;
  final bool isEmergency;

  String get relationshipLabel => switch (relationship) {
        'pere' => 'Père',
        'mere' => 'Mère',
        'tuteur' => 'Tuteur légal',
        'oncle' => 'Oncle',
        'tante' => 'Tante',
        'grand_parent' => 'Grand-parent',
        null || '' => 'Responsable',
        _ => relationship!,
      };
}

class DossierTeacher {
  const DossierTeacher({
    required this.fullName,
    required this.subject,
    this.weeklyHours,
    this.speciality,
  });
  final String fullName;
  final String subject;
  final int? weeklyHours;
  final String? speciality;
}

class DossierIncident {
  const DossierIncident({
    required this.date,
    required this.type,
    required this.description,
    required this.parentNotified,
    this.sanction,
    this.sanctionDate,
  });

  final DateTime? date;
  final String type;

  /// Le MOTIF. C'est lui qui rend la sanction lisible.
  final String description;
  final bool parentNotified;
  final String? sanction;
  final DateTime? sanctionDate;

  bool get hasSanction =>
      sanction != null && sanction!.isNotEmpty && sanction != 'aucune';
}

class DossierSchool {
  const DossierSchool({
    required this.name,
    this.address,
    this.city,
    this.department,
    this.phone,
    this.email,
    this.directorName,
    this.directorRole,
    this.directorPhone,
  });

  final String name;
  final String? address;
  final String? city;
  final String? department;
  final String? phone;
  final String? email;
  final String? directorName;
  final String? directorRole;
  final String? directorPhone;

  bool get hasDirector => directorName != null;
}

class DossierEnrollment {
  const DossierEnrollment({
    this.classId,
    this.academicYearId,
    this.className,
    this.filiere,
    this.cycleCode,
    this.levelCode,
    this.enrollmentDate,
    this.status,
    this.inscriptionType,
    this.isRepeating = false,
    this.previousSchool,
    this.previousClass,
    this.validatedAt,
  });

  /// Identifiants de l'inscription retenue — ils servent à aller chercher les
  /// résultats de l'élève dans SA classe et SUR l'année en cours.
  final String? classId;
  final String? academicYearId;
  final String? className;
  final String? filiere;
  final String? cycleCode;
  final String? levelCode;
  final DateTime? enrollmentDate;
  final String? status;
  final String? inscriptionType;
  final bool isRepeating;
  final String? previousSchool;
  final String? previousClass;
  final DateTime? validatedAt;

  bool get isEmpty => className == null && enrollmentDate == null;
}

class StudentDossier {
  const StudentDossier({
    required this.id,
    required this.fullName,
    required this.school,
    required this.enrollment,
    required this.tutors,
    required this.teachers,
    required this.incidents,
    this.matricule,
    this.ine,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    this.nationality,
    this.address,
    this.city,
    this.photoUrl,
    this.isActive = true,
    this.isBoarder = false,
    this.hasScholarship = false,
    this.scholarshipType,
    this.hasSocialAid = false,
    this.isAffecte = false,
    this.situationFamiliale,
    this.siblings,
  });

  final String id;
  final String fullName;
  final DossierSchool school;
  final DossierEnrollment enrollment;
  final List<DossierTutor> tutors;
  final List<DossierTeacher> teachers;
  final List<DossierIncident> incidents;

  final String? matricule;

  /// Identifiant national (migration 0080).
  final String? ine;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? placeOfBirth;
  final String? nationality;
  final String? address;
  final String? city;
  final String? photoUrl;
  final bool isActive;
  final bool isBoarder;
  final bool hasScholarship;
  final String? scholarshipType;
  final bool hasSocialAid;
  final bool isAffecte;
  final String? situationFamiliale;
  final int? siblings;

  bool get isFemale => gender == 'F';

  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 120 ? null : a;
  }

  DossierTutor? get primaryTutor => tutors.isEmpty
      ? null
      : tutors.firstWhere((t) => t.isPrimary, orElse: () => tutors.first);

  int get sanctionCount => incidents.where((i) => i.hasSanction).length;
}

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse('$v');

final studentDossierProvider =
    FutureProvider.autoDispose.family<StudentDossier, String>((ref, id) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) throw StateError('Groupe introuvable');

  final currentYears = await ref.watch(_dossierYearsProvider.future);

  // Identité + établissement. Ni `blood_group` ni `allergies` : voir l'en-tête.
  final row = await client
      .from('students')
      .select('id, matricule, ine, first_name, last_name, gender, date_of_birth, '
          'place_of_birth, nationality, address, city, photo_url, is_active, '
          'is_boarder, has_scholarship, scholarship_type, has_social_aid, '
          'is_affecte, situation_familiale, nombre_freres_soeurs, '
          'schools!inner(id, name, address, city, department, phone, email, '
          'director_id)')
      .eq('id', id)
      .eq('group_id', groupId)
      .single();

  final schoolRow = row['schools'] as Map<String, dynamic>;

  // Inscription de l'année courante (avec sa classe).
  final enrollRows = await client
      .from('class_enrollments')
      .select('academic_year_id, enrollment_date, status, inscription_type, '
          'is_repeating, previous_school_name, previous_class_name, '
          'validated_at, class_id, '
          'classes!class_enrollments_class_id_fkey('
          'name, cycle_code, level_code, filiere_label)')
      .eq('student_id', id)
      .order('enrollment_date', ascending: false);

  Map<String, dynamic>? enroll;
  for (final e in enrollRows as List) {
    final m = e as Map<String, dynamic>;
    if (currentYears.contains(m['academic_year_id'])) {
      enroll = m;
      break;
    }
  }
  final klass = enroll?['classes'] as Map<String, dynamic>?;

  // Famille, équipe enseignante, conduite et chef d'établissement : lancés
  // ensemble — quatre allers-retours en série feraient patienter pour rien.
  final classId = enroll?['class_id'] as String?;
  // `<dynamic>` explicite : les quatre requêtes ne renvoient pas le même type
  // (listes et objet unique), l'inférence échouerait sur `E`.
  final results = await Future.wait<dynamic>([
    client
        .from('student_tutors')
        .select('first_name, last_name, relationship, phone_primary, '
            'phone_secondary, email, profession, address, is_primary_contact, '
            'is_emergency_contact')
        .eq('student_id', id)
        .order('is_primary_contact', ascending: false),
    if (classId != null)
      client
          .from('teacher_subjects')
          .select('weekly_hours, subjects(name), '
              'profiles!teacher_subjects_staff_id_fkey('
              'first_name, last_name, speciality)')
          .eq('class_id', classId)
    else
      Future.value(const <dynamic>[]),
    // `follow_up_notes` volontairement absent : cahier de suivi de l'école.
    client
        .from('discipline_incidents')
        .select('incident_date, incident_type, description, sanction, '
            'sanction_date, parent_notified')
        .eq('student_id', id)
        .order('incident_date', ascending: false),
    if (schoolRow['director_id'] != null)
      client
          .from('profiles')
          .select('first_name, last_name, phone, role')
          .eq('id', schoolRow['director_id'] as String)
          .maybeSingle()
    else
      Future.value(null),
  ]);

  final tutorRows = results[0] as List;
  final teacherRows = results[1] as List;
  final incidentRows = results[2] as List;
  final director = results[3] as Map<String, dynamic>?;

  String name(Map<String, dynamic>? m) =>
      '${(m?['first_name'] as String?)?.trim() ?? ''} '
              '${(m?['last_name'] as String?)?.trim() ?? ''}'
          .trim();

  final studentName = name(row);

  return StudentDossier(
    id: id,
    fullName: studentName.isEmpty ? 'Élève sans nom' : studentName,
    matricule: row['matricule'] as String?,
    ine: row['ine'] as String?,
    gender: row['gender'] as String?,
    dateOfBirth: _d(row['date_of_birth']),
    placeOfBirth: row['place_of_birth'] as String?,
    nationality: row['nationality'] as String?,
    address: row['address'] as String?,
    city: row['city'] as String?,
    photoUrl: row['photo_url'] as String?,
    isActive: row['is_active'] != false,
    isBoarder: row['is_boarder'] == true,
    hasScholarship: row['has_scholarship'] == true,
    scholarshipType: row['scholarship_type'] as String?,
    hasSocialAid: row['has_social_aid'] == true,
    isAffecte: row['is_affecte'] == true,
    situationFamiliale: row['situation_familiale'] as String?,
    siblings: (row['nombre_freres_soeurs'] as num?)?.toInt(),
    school: DossierSchool(
      name: (schoolRow['name'] as String?) ?? '—',
      address: schoolRow['address'] as String?,
      city: schoolRow['city'] as String?,
      department: schoolRow['department'] as String?,
      phone: schoolRow['phone'] as String?,
      email: schoolRow['email'] as String?,
      directorName: director == null ? null : name(director),
      directorRole: director?['role'] as String?,
      directorPhone: director?['phone'] as String?,
    ),
    enrollment: DossierEnrollment(
      classId: enroll?['class_id'] as String?,
      academicYearId: enroll?['academic_year_id'] as String?,
      className: klass?['name'] as String?,
      filiere: klass?['filiere_label'] as String?,
      cycleCode: klass?['cycle_code'] as String?,
      levelCode: klass?['level_code'] as String?,
      enrollmentDate: _d(enroll?['enrollment_date']),
      status: enroll?['status'] as String?,
      inscriptionType: enroll?['inscription_type'] as String?,
      isRepeating: enroll?['is_repeating'] == true,
      previousSchool: enroll?['previous_school_name'] as String?,
      previousClass: enroll?['previous_class_name'] as String?,
      validatedAt: _d(enroll?['validated_at']),
    ),
    tutors: [
      for (final t in tutorRows)
        DossierTutor(
          fullName: name(t as Map<String, dynamic>),
          relationship: t['relationship'] as String?,
          phonePrimary: t['phone_primary'] as String?,
          phoneSecondary: t['phone_secondary'] as String?,
          email: t['email'] as String?,
          profession: t['profession'] as String?,
          address: t['address'] as String?,
          isPrimary: t['is_primary_contact'] == true,
          isEmergency: t['is_emergency_contact'] == true,
        ),
    ],
    teachers: [
      for (final t in teacherRows)
        DossierTeacher(
          fullName: name(t['profiles'] as Map<String, dynamic>?),
          subject: (t['subjects']?['name'] as String?) ?? 'Matière',
          weeklyHours: (t['weekly_hours'] as num?)?.toInt(),
          speciality: t['profiles']?['speciality'] as String?,
        ),
    ]..sort((a, b) => a.subject.compareTo(b.subject)),
    incidents: [
      for (final i in incidentRows)
        DossierIncident(
          date: _d(i['incident_date']),
          type: (i['incident_type'] as String?) ?? 'autre',
          description: (i['description'] as String?) ?? '',
          parentNotified: i['parent_notified'] == true,
          sanction: i['sanction'] as String?,
          sanctionDate: _d(i['sanction_date']),
        ),
    ],
  );
});

/// Années courantes du groupe — dupliquer la liste ailleurs ferait diverger le
/// dossier de la liste de recherche sur ce qui compte comme « cette année ».
final _dossierYearsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const {};
  final rows = await client
      .from('academic_years')
      .select('id')
      .eq('group_id', groupId)
      .eq('is_current', true);
  return {for (final r in rows as List) r['id'] as String};
});
