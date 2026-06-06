// Helper : accepte bool (Supabase) et int 0/1 (SQLite PowerSync)
bool _b(dynamic v) => v == true || v == 1;

/// Table `academic_years`
class AcademicYearModel {
  const AcademicYearModel({
    required this.id,
    required this.groupId,
    this.schoolId,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcademicYearModel.fromMap(Map<String, dynamic> map) {
    return AcademicYearModel(
      id:        map['id']         as String,
      groupId:   map['group_id']   as String,
      schoolId:  map['school_id']  as String?,
      label:     map['label']      as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate:   DateTime.parse(map['end_date']   as String),
      isCurrent: _b(map['is_current']),
      isLocked:  _b(map['is_locked']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  groupId;
  final String? schoolId;
  final String  label;      // Ex: "2025-2026"
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() => 'AcademicYearModel($label${isCurrent ? " *" : ""})';
}

/// Table `trimesters`
class TrimesterModel {
  const TrimesterModel({
    required this.id,
    required this.academicYearId,
    required this.groupId,
    this.schoolId,
    required this.label,
    required this.trimesterNumber,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrimesterModel.fromMap(Map<String, dynamic> map) {
    return TrimesterModel(
      id:              map['id']               as String,
      academicYearId:  map['academic_year_id'] as String,
      groupId:         map['group_id']         as String,
      schoolId:        map['school_id']        as String?,
      label:           map['label']            as String,
      trimesterNumber: map['trimester_number'] as int,
      startDate:       DateTime.parse(map['start_date'] as String),
      endDate:         DateTime.parse(map['end_date']   as String),
      isCurrent:       _b(map['is_current']),
      isLocked:        _b(map['is_locked']),
      createdAt:       DateTime.parse(map['created_at'] as String),
      updatedAt:       DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  academicYearId;
  final String  groupId;
  final String? schoolId;
  final String  label;           // "1er Trimestre"
  final int     trimesterNumber; // 1, 2 ou 3
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() => 'TrimesterModel($label)';
}

/// Table `sequences`
class SequenceModel {
  const SequenceModel({
    required this.id,
    required this.trimesterId,
    required this.groupId,
    this.schoolId,
    required this.label,
    required this.sequenceNumber,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SequenceModel.fromMap(Map<String, dynamic> map) {
    return SequenceModel(
      id:             map['id']              as String,
      trimesterId:    map['trimester_id']    as String,
      groupId:        map['group_id']        as String,
      schoolId:       map['school_id']       as String?,
      label:          map['label']           as String,
      sequenceNumber: map['sequence_number'] as int,
      startDate:      DateTime.parse(map['start_date'] as String),
      endDate:        DateTime.parse(map['end_date']   as String),
      isCurrent:      _b(map['is_current']),
      createdAt:      DateTime.parse(map['created_at'] as String),
      updatedAt:      DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  trimesterId;
  final String  groupId;
  final String? schoolId;
  final String  label;          // "Séquence 1"
  final int     sequenceNumber; // 1, 2
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() => 'SequenceModel($label)';
}

/// Modèle léger pour les niveaux scolaires (`school_levels`)
class SchoolLevelModel {
  const SchoolLevelModel({
    required this.id,
    required this.schoolId,
    required this.groupId,
    required this.name,
    this.category,
    this.orderIndex,
  });

  factory SchoolLevelModel.fromMap(Map<String, dynamic> map) {
    return SchoolLevelModel(
      id:         map['id']          as String,
      schoolId:   map['school_id']   as String,
      groupId:    map['group_id']    as String,
      name:       map['name']        as String,
      category:   map['category']    as String?,
      orderIndex: map['order_index'] as int?,
    );
  }

  final String  id;
  final String  schoolId;
  final String  groupId;
  final String  name;        // "6ème", "Terminale D"
  final String? category;
  final int?    orderIndex;

  String get categoryLabel {
    switch (category) {
      case 'general':       return 'Enseignement Général';
      case 'technique':     return 'Enseignement Technique';
      case 'professionnel': return 'Enseignement Professionnel';
      default:              return category ?? '—';
    }
  }
}
