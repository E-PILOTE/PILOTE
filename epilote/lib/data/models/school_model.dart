import '../../core/utils/booleen_offline.dart';


/// Table `schools`
class SchoolModel {
  const SchoolModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.schoolCode,
    this.address,
    this.city,
    this.department,
    this.province,
    this.arrondissement,
    this.phone,
    this.email,
    this.website,
    this.foundedYear,
    this.motto,
    this.directorId,
    this.logoUrl,
    required this.schoolType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    return SchoolModel(
      id:             map['id']           as String,
      groupId:        map['group_id']     as String,
      name:           map['name']         as String,
      schoolCode:     map['school_code']  as String?,
      address:        map['address']      as String?,
      city:           map['city']         as String?,
      department:     map['department']   as String?,
      province:       map['province']     as String?,
      arrondissement: map['arrondissement'] as String?,
      phone:          map['phone']        as String?,
      email:          map['email']        as String?,
      website:        map['website']      as String?,
      foundedYear:    map['founded_year'] as int?,
      motto:          map['motto']        as String?,
      directorId:     map['director_id']  as String?,
      logoUrl:        map['logo_url']     as String?,
      schoolType:     map['school_type']  as String? ?? 'secondaire',
      isActive:       actifOffline(map['is_active']), // défaut VRAI
      createdAt:      DateTime.parse(map['created_at'] as String),
      updatedAt:      DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  groupId;
  final String  name;
  final String? schoolCode;
  final String? address;
  final String? city;
  final String? department;
  final String? province;
  final String? arrondissement;
  final String? phone;
  final String? email;
  final String? website;
  final int?    foundedYear;
  final String? motto;
  final String? directorId;
  final String? logoUrl;
  final String  schoolType;
  final bool    isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toInsertMap() => {
    'group_id':    groupId,
    'name':        name,
    'school_code': schoolCode,
    'address':     address,
    'city':        city,
    'department':  department,
    'province':    province,
    'phone':       phone,
    'email':       email,
    'school_type': schoolType,
    'is_active':   isActive,
  };

  String get displayType {
    switch (schoolType) {
      case 'primaire':    return 'École Primaire';
      case 'secondaire':  return 'Collège / Lycée';
      case 'technique':   return 'Enseignement Technique';
      case 'superieur':   return 'Enseignement Supérieur';
      default:            return schoolType;
    }
  }

  String get locationLabel {
    final parts = [city, department, province]
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? '—' : parts.first;
  }

  @override
  String toString() => 'SchoolModel($id, $name)';
}
