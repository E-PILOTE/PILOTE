bool _b(dynamic v) => v == true || v == 1;

/// Table `classes`
class ClassModel {
  const ClassModel({
    required this.id,
    required this.schoolId,
    required this.groupId,
    required this.academicYearId,
    this.levelId,
    required this.name,
    this.capacity,
    this.mainTeacherId,
    this.room,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.studentCount,
    this.teacherName,
    this.levelName,
    this.cycleCode,
    this.levelCode,
    this.levelOrder,
    this.filiereCode,
    this.filiereLabel,
  });

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id:             map['id']               as String,
      schoolId:       map['school_id']        as String,
      groupId:        map['group_id']         as String,
      academicYearId: map['academic_year_id'] as String,
      levelId:        map['level_id']         as String?,
      name:           map['name']             as String,
      capacity:       map['capacity']         as int?,
      mainTeacherId:  map['main_teacher_id']  as String?,
      room:           map['room']             as String?,
      isActive:       _b(map['is_active']),
      createdAt:      DateTime.parse(map['created_at'] as String),
      updatedAt:      DateTime.parse(map['updated_at'] as String),
      studentCount:   map['student_count']    as int?,
      teacherName:    map['teacher_name']     as String?,
      levelName:      map['level_name']       as String?,
      cycleCode:      map['cycle_code']       as String?,
      levelCode:      map['level_code']       as String?,
      levelOrder:     (map['level_order'] as num?)?.toInt(),
      filiereCode:    map['filiere_code']     as String?,
      filiereLabel:   map['filiere_label']    as String?,
    );
  }

  final String  id;
  final String  schoolId;
  final String  groupId;
  final String  academicYearId;
  final String? levelId;
  final String  name;
  final int?    capacity;
  final String? mainTeacherId;
  final String? room;
  final bool    isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int?    studentCount;
  final String? teacherName;
  final String? levelName;
  final String? cycleCode;
  final String? levelCode;
  final int?    levelOrder;
  final String? filiereCode;
  final String? filiereLabel;

  double? get fillRate {
    if (capacity == null || capacity == 0 || studentCount == null) return null;
    return studentCount! / capacity!;
  }

  String get fillRateLabel {
    final rate = fillRate;
    if (rate == null) return '${studentCount ?? 0} élève(s)';
    return '${studentCount ?? 0}/$capacity (${(rate * 100).round()}%)';
  }

  @override
  String toString() => 'ClassModel($id, $name)';
}

/// Table `class_enrollments` — inscription d'un élève dans une classe.
/// Workflow : pending_validation → active | rejected
class ClassEnrollmentModel {
  const ClassEnrollmentModel({
    required this.id,
    required this.groupId,
    required this.schoolId,
    required this.studentId,
    required this.classId,
    required this.academicYearId,
    required this.enrollmentDate,
    required this.status,
    required this.isRepeating,
    this.previousClassId,
    this.withdrawalDate,
    this.withdrawalReason,
    // Workflow validation
    this.inscriptionType = 'new',
    this.validatedAt,
    this.validatedBy,
    this.rejectionReason,
    // École/classe précédente (réinscription ou transfert)
    this.previousSchoolName,
    this.previousClassName,
    required this.createdAt,
    required this.updatedAt,
    // Champs JOIN students
    this.studentFirstName,
    this.studentLastName,
    this.studentMatricule,
    this.studentPhotoUrl,
    this.studentGender,
  });

  factory ClassEnrollmentModel.fromMap(Map<String, dynamic> map) {
    return ClassEnrollmentModel(
      id:                 map['id']                  as String,
      groupId:            map['group_id']            as String,
      schoolId:           map['school_id']           as String,
      studentId:          map['student_id']          as String,
      classId:            map['class_id']            as String,
      academicYearId:     map['academic_year_id']    as String,
      enrollmentDate:     DateTime.parse(map['enrollment_date'] as String),
      status:             map['status']              as String? ?? 'pending_validation',
      isRepeating:        _b(map['is_repeating']),
      previousClassId:    map['previous_class_id']   as String?,
      withdrawalDate:     map['withdrawal_date'] != null
          ? DateTime.tryParse(map['withdrawal_date'] as String)
          : null,
      withdrawalReason:   map['withdrawal_reason']   as String?,
      inscriptionType:    map['inscription_type']    as String? ?? 'new',
      validatedAt:        map['validated_at'] != null
          ? DateTime.tryParse(map['validated_at'] as String)
          : null,
      validatedBy:        map['validated_by']        as String?,
      rejectionReason:    map['rejection_reason']    as String?,
      previousSchoolName: map['previous_school_name'] as String?,
      previousClassName:  map['previous_class_name']  as String?,
      createdAt:          DateTime.parse(map['created_at'] as String),
      updatedAt:          DateTime.parse(map['updated_at'] as String),
      studentFirstName:   map['first_name']          as String?,
      studentLastName:    map['last_name']            as String?,
      studentMatricule:   map['matricule']            as String?,
      studentPhotoUrl:    map['photo_url']            as String?,
      studentGender:      map['gender']               as String?,
    );
  }

  final String   id;
  final String   groupId;
  final String   schoolId;
  final String   studentId;
  final String   classId;
  final String   academicYearId;
  final DateTime enrollmentDate;
  final String   status; // pending_validation | active | rejected | withdrawn | transferred | graduated
  final bool     isRepeating;
  final String?  previousClassId;
  final DateTime? withdrawalDate;
  final String?  withdrawalReason;

  // ── Workflow inscription ──────────────────────────────────────────────────
  final String   inscriptionType;    // new | reinscription | transfer
  final DateTime? validatedAt;
  final String?  validatedBy;
  final String?  rejectionReason;
  final String?  previousSchoolName;
  final String?  previousClassName;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Champs JOIN students ──────────────────────────────────────────────────
  final String? studentFirstName;
  final String? studentLastName;
  final String? studentMatricule;
  final String? studentPhotoUrl;
  final String? studentGender;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get studentFullName =>
      '${studentFirstName ?? ''} ${studentLastName ?? ''}'.trim();

  bool get isPendingValidation => status == 'pending_validation';
  bool get isActive            => status == 'active';
  bool get isRejected          => status == 'rejected';
  bool get isWithdrawn         => status == 'withdrawn';

  String get statusLabel => switch (status) {
    'pending_validation' => 'En attente',
    'active'             => 'Validée',
    'rejected'           => 'Refusée',
    'withdrawn'          => 'Retirée',
    'transferred'        => 'Transférée',
    'graduated'          => 'Diplômée',
    _                    => status,
  };

  String get inscriptionTypeLabel => switch (inscriptionType) {
    'new'           => 'Nouvelle inscription',
    'reinscription' => 'Réinscription',
    'transfer'      => 'Transfert',
    _               => inscriptionType,
  };

  @override
  String toString() => 'ClassEnrollmentModel($studentId → $classId, $status)';
}
