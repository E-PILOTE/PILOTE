import '../../core/constants/app_constants.dart';

/// Modèle correspondant à la table `profiles` (Supabase)
class ProfileModel {

  const ProfileModel({
    required this.id,
    this.groupId,
    this.schoolId,
    required this.role,
    this.accessProfileId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatarUrl,
    this.employeeNumber,
    required this.isActive,
    this.lastLogin,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id:              map['id']               as String,
      groupId:         map['group_id']         as String?,
      schoolId:        map['school_id']        as String?,
      role:            map['role']             as String? ?? AppConstants.roleSuperAdmin,
      accessProfileId: map['access_profile_id'] as String?,
      firstName:       map['first_name']       as String? ?? '',
      lastName:        map['last_name']        as String? ?? '',
      phone:           map['phone']            as String?,
      avatarUrl:       map['avatar_url']       as String?,
      employeeNumber:  map['employee_number']  as String?,
      isActive:        map['is_active']        as bool? ?? true,
      lastLogin:       map['last_login'] != null
          ? DateTime.parse(map['last_login'] as String)
          : null,
      fcmToken:        map['fcm_token']        as String?,
      createdAt:       DateTime.parse(map['created_at'] as String),
      updatedAt:       DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String? groupId;
  final String? schoolId;
  final String role;
  final String? accessProfileId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarUrl;
  final String? employeeNumber;
  final bool isActive;
  final DateTime? lastLogin;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() => {
    'id':                id,
    'group_id':          groupId,
    'school_id':         schoolId,
    'role':              role,
    'access_profile_id': accessProfileId,
    'first_name':        firstName,
    'last_name':         lastName,
    'phone':             phone,
    'avatar_url':        avatarUrl,
    'employee_number':   employeeNumber,
    'is_active':         isActive,
  };

  bool get isSuperAdmin  => role == AppConstants.roleSuperAdmin;
  bool get isAdminGroupe => role == AppConstants.roleAdminGroupe;
  bool get isSchoolStaff => !isSuperAdmin && !isAdminGroupe;
  bool get hasSchool     => schoolId != null;
  bool get hasGroup      => groupId != null;
  bool get hasPendingProfile => isSchoolStaff && accessProfileId == null;

  ProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phone,
    bool? isActive,
    String? accessProfileId,
    String? fcmToken,
  }) {
    return ProfileModel(
      id:              id,
      groupId:         groupId,
      schoolId:        schoolId,
      role:            role,
      accessProfileId: accessProfileId ?? this.accessProfileId,
      firstName:       firstName        ?? this.firstName,
      lastName:        lastName         ?? this.lastName,
      phone:           phone            ?? this.phone,
      avatarUrl:       avatarUrl        ?? this.avatarUrl,
      employeeNumber:  employeeNumber,
      isActive:        isActive         ?? this.isActive,
      lastLogin:       lastLogin,
      fcmToken:        fcmToken         ?? this.fcmToken,
      createdAt:       createdAt,
      updatedAt:       DateTime.now(),
    );
  }

  @override
  String toString() => 'ProfileModel($id, $role, $fullName)';
}
