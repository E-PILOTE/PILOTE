import '../../core/utils/booleen_offline.dart';

/// Matière scolaire CANONIQUE (table `subjects`, offline-first). Une matière est
/// une IDENTITÉ unique (ex. « Mathématiques »), réutilisée dans tout
/// l'établissement. Son niveau, son cycle et son coefficient EFFECTIF ne lui
/// appartiennent pas : ils sont portés par l'AFFECTATION à chaque classe
/// (`class_subjects`). `coefficient` n'est qu'un coefficient PAR DÉFAUT, proposé
/// au moment de l'affectation. `classCount` / `niveaux` sont dérivés des
/// affectations (transitoires, via sous-requêtes — non persistés).
class SubjectModel {
  const SubjectModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.slug,
    required this.coefficient,
    required this.isActive,
    this.schoolId,
    this.displayOrder = 0,
    this.classCount = 0,
    this.niveaux = const [],
  });

  factory SubjectModel.fromMap(Map<String, dynamic> m) => SubjectModel(
        id:           m['id'] as String,
        groupId:      m['group_id'] as String? ?? '',
        name:         m['name'] as String? ?? '',
        slug:         m['slug'] as String? ?? '',
        coefficient:  (m['coefficient'] as num?)?.toInt() ?? 1,
        isActive:     actifOffline(m['is_active']), // défaut VRAI
        schoolId:     m['school_id'] as String?,
        displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
        classCount:   (m['class_count'] as num?)?.toInt() ?? 0,
        niveaux:      _split(m['niveaux']),
      );

  final String  id;
  final String  groupId;
  final String  name;
  final String  slug;
  final int     coefficient; // coef PAR DÉFAUT (proposé à l'affectation)
  final bool    isActive;
  final String? schoolId;
  final int     displayOrder;

  // ── Dérivés des affectations (class_subjects) ───────────────────────────────
  final int          classCount; // nb de classes où la matière est dispensée
  final List<String> niveaux;    // codes des niveaux où elle est dispensée

  bool get isAssigned => classCount > 0;
  String get coefLabel => 'Coef. $coefficient';

  static List<String> _split(Object? v) {
    if (v is! String || v.trim().isEmpty) return const [];
    return v
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

}
