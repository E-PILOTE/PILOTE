/// Matière scolaire (table `subjects`, offline-first).
class SubjectModel {
  const SubjectModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.slug,
    required this.coefficient,
    required this.isActive,
    this.schoolId,
    this.levelId,
    this.displayOrder = 0,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> m) => SubjectModel(
        id:           m['id'] as String,
        groupId:      m['group_id'] as String? ?? '',
        name:         m['name'] as String? ?? '',
        slug:         m['slug'] as String? ?? '',
        coefficient:  (m['coefficient'] as num?)?.toInt() ?? 1,
        isActive:     _b(m['is_active']),
        schoolId:     m['school_id'] as String?,
        levelId:      m['level_id'] as String?,
        displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
      );

  final String  id;
  final String  groupId;
  final String  name;
  final String  slug;
  final int     coefficient;
  final bool    isActive;
  final String? schoolId;
  final String? levelId;
  final int     displayOrder;

  static bool _b(Object? v) => v == 1 || v == true;
}
