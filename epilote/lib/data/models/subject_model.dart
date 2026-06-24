/// Matière scolaire (table `subjects`, offline-first). Une matière est portée
/// par un NIVEAU (`level_id` → school_levels) avec son propre coefficient ;
/// `level_id` NULL = tronc commun (toutes les classes). Le coefficient varie
/// donc d'un niveau à l'autre (Congo). Les champs `level*`/`cycleCode` sont
/// dérivés d'un JOIN (transitoires, non persistés).
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
    this.levelCode,
    this.levelName,
    this.levelOrder = 999,
    this.cycleCode,
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
        levelCode:    (m['level_code'] as String?)?.trim().isEmpty ?? true
            ? null
            : (m['level_code'] as String).trim(),
        levelName:    m['level_name'] as String?,
        levelOrder:   (m['level_order'] as num?)?.toInt() ?? 999,
        cycleCode:    m['cycle_code'] as String?,
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

  // ── Dérivés du JOIN school_levels (× education_cycles) ──────────────────────
  final String? levelCode;   // ex. « 6e », « Tle » ; NULL = tronc commun
  final String? levelName;
  final int     levelOrder;
  final String? cycleCode;

  bool get isTronc => levelId == null || (levelCode ?? '').isEmpty;
  String get levelLabel => isTronc ? 'Tronc commun' : levelCode!;

  static bool _b(Object? v) => v == 1 || v == true;
}
