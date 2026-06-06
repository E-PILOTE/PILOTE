// Helper : accepte bool (Supabase) et int 0/1 (SQLite PowerSync)
bool _b(dynamic v) => v == true || v == 1;

/// Table `module_categories` — données globales plateforme
class ModuleCategoryModel {
  const ModuleCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModuleCategoryModel.fromMap(Map<String, dynamic> map) {
    return ModuleCategoryModel(
      id:           map['id']            as String,
      name:         map['name']          as String,
      slug:         map['slug']          as String,
      icon:         map['icon']          as String?,
      displayOrder: map['display_order'] as int? ?? 0,
      createdAt:    DateTime.parse(map['created_at'] as String),
      updatedAt:    DateTime.parse(map['updated_at'] as String),
    );
  }

  final String  id;
  final String  name;
  final String  slug;
  final String? icon;
  final int     displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() => 'ModuleCategoryModel($slug)';
}

/// Table `modules` — données globales plateforme
class ModuleModel {
  const ModuleModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
  });

  factory ModuleModel.fromMap(Map<String, dynamic> map) {
    return ModuleModel(
      id:           map['id']            as String,
      categoryId:   map['category_id']   as String,
      name:         map['name']          as String,
      slug:         map['slug']          as String,
      description:  map['description']   as String?,
      icon:         map['icon']          as String?,
      displayOrder: map['display_order'] as int? ?? 0,
      isActive:     _b(map['is_active']),
      createdAt:    DateTime.parse(map['created_at'] as String),
      updatedAt:    DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
    );
  }

  final String  id;
  final String  categoryId;
  final String  name;
  final String  slug;
  final String? description;
  final String? icon;
  final int     displayOrder;
  final bool    isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Champs de jointure optionnels (requête JOIN module_categories)
  final String? categoryName;
  final String? categoryIcon;

  @override
  String toString() => 'ModuleModel($slug)';
}

/// Table `plan_modules` — relation plan ↔ modules
class PlanModuleModel {
  const PlanModuleModel({
    required this.id,
    required this.planId,
    required this.moduleId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanModuleModel.fromMap(Map<String, dynamic> map) {
    return PlanModuleModel(
      id:        map['id']         as String,
      planId:    map['plan_id']    as String,
      moduleId:  map['module_id']  as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final String   id;
  final String   planId;
  final String   moduleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String toString() => 'PlanModuleModel($planId → $moduleId)';
}
