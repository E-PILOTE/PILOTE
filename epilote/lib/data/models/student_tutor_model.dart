bool _bTutor(dynamic v) => v == true || v == 1;

/// Table `student_tutors` — tuteurs légaux et contacts d'un élève.
/// Un élève a généralement 1 tuteur principal + 1 secondaire + 1 contact urgence.
class StudentTutorModel {
  const StudentTutorModel({
    required this.id,
    required this.studentId,
    required this.groupId,
    required this.firstName,
    required this.lastName,
    required this.relationship,
    required this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.profession,
    this.address,
    required this.isPrimaryContact,
    required this.hasAppAccess,
    this.userId,
    required this.isEmergencyContact,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentTutorModel.fromMap(Map<String, dynamic> map) {
    return StudentTutorModel(
      id:                 map['id']                   as String,
      studentId:          map['student_id']           as String,
      groupId:            map['group_id']             as String,
      firstName:          map['first_name']           as String,
      lastName:           map['last_name']            as String,
      relationship:       map['relationship']         as String,
      phonePrimary:       map['phone_primary']        as String,
      phoneSecondary:     map['phone_secondary']      as String?,
      email:              map['email']                as String?,
      profession:         map['profession']           as String?,
      address:            map['address']              as String?,
      isPrimaryContact:   _bTutor(map['is_primary_contact']),
      hasAppAccess:       _bTutor(map['has_app_access']),
      userId:             map['user_id']              as String?,
      isEmergencyContact: _bTutor(map['is_emergency_contact']),
      createdAt:          DateTime.parse(map['created_at'] as String),
      updatedAt:          DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  studentId;
  final String  groupId;
  final String  firstName;
  final String  lastName;
  final String  relationship;        // 'pere' | 'mere' | 'tuteur' | 'autre'
  final String  phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? profession;
  final String? address;
  final bool    isPrimaryContact;
  final bool    hasAppAccess;
  final String? userId;              // compte parent si activé
  final bool    isEmergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$firstName $lastName';

  String get relationshipLabel => switch (relationship) {
    'pere'   => 'Père',
    'mere'   => 'Mère',
    'tuteur' => 'Tuteur légal',
    'autre'  => 'Autre',
    _        => relationship,
  };

  @override
  String toString() => 'StudentTutorModel($id, $fullName, $relationshipLabel)';
}
