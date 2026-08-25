import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../core/utils/plan_referential_realtime.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle ModuleCategory ────────────────────────────────────────────────────

class ModuleCategory {
  const ModuleCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.moduleCount,
    required this.activeModuleCount,
    this.icon,
  });

  factory ModuleCategory.fromMap(
    Map<String, dynamic> m, {
    int moduleCount = 0,
    int activeModuleCount = 0,
  }) =>
      ModuleCategory(
        id:           m['id']            as String,
        name:         m['name']          as String? ?? '',
        slug:         m['slug']          as String? ?? '',
        icon:         m['icon']          as String?,
        displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
        createdAt:    DateTime.parse(m['created_at'] as String),
        updatedAt:    DateTime.parse(m['updated_at'] as String),
        moduleCount:       moduleCount,
        activeModuleCount: activeModuleCount,
      );

  final String  id, name, slug;
  final String? icon;
  final int     displayOrder, moduleCount, activeModuleCount;
  final DateTime createdAt, updatedAt;

  String get emoji => (icon ?? '').trim().isNotEmpty ? icon!.trim() : '📦';

  ModuleCategory copyWith({int? moduleCount, int? activeModuleCount}) =>
      ModuleCategory(
        id: id, name: name, slug: slug, icon: icon,
        displayOrder: displayOrder, createdAt: createdAt, updatedAt: updatedAt,
        moduleCount:       moduleCount ?? this.moduleCount,
        activeModuleCount: activeModuleCount ?? this.activeModuleCount,
      );
}

// ─── Modèle ModuleItem ────────────────────────────────────────────────────────

class ModuleItem {
  const ModuleItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.slug,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.planCount,
    this.description,
    this.icon,
    this.categoryIcon,
  });

  factory ModuleItem.fromMap(
    Map<String, dynamic> m, {
    int planCount = 0,
  }) {
    final cat = m['category'];
    final catMap = cat is Map ? Map<String, dynamic>.from(cat) : const {};
    return ModuleItem(
      id:           m['id']            as String,
      categoryId:   m['category_id']   as String,
      categoryName: (catMap['name']    as String?) ?? '',
      categoryIcon: catMap['icon']     as String?,
      name:         m['name']          as String? ?? '',
      slug:         m['slug']          as String? ?? '',
      description:  m['description']   as String?,
      icon:         m['icon']          as String?,
      displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
      isActive:     m['is_active']     as bool? ?? true,
      createdAt:    DateTime.parse(m['created_at'] as String),
      updatedAt:    DateTime.parse(m['updated_at'] as String),
      planCount:    planCount,
    );
  }

  final String  id, categoryId, categoryName, name, slug;
  final String? description, icon, categoryIcon;
  final int     displayOrder, planCount;
  final bool    isActive;
  final DateTime createdAt, updatedAt;

  String get emoji => (icon ?? '').trim().isNotEmpty ? icon!.trim() : '🧩';
}

// ─── Modèle PlanInfo (couverture par plan) ────────────────────────────────────

class PlanInfo {
  const PlanInfo({
    required this.id,
    required this.name,
    required this.moduleCount,
    this.priceXaf,
  });
  final String id, name;
  final int    moduleCount;
  final int?   priceXaf;
}

// ─── Modèle données globales ──────────────────────────────────────────────────

class ModulesData {
  const ModulesData({
    required this.categories,
    required this.modules,
    required this.plans,
    required this.totalCategories,
    required this.totalModules,
    required this.activeModules,
    required this.inactiveModules,
    required this.totalPlanLinks,
  });

  final List<ModuleCategory> categories;
  final List<ModuleItem>     modules;
  final List<PlanInfo>       plans;
  final int totalCategories, totalModules, activeModules,
            inactiveModules, totalPlanLinks;

  static const empty = ModulesData(
    categories: [], modules: [], plans: [],
    totalCategories: 0, totalModules: 0, activeModules: 0,
    inactiveModules: 0, totalPlanLinks: 0,
  );
}

// ─── Provider principal ───────────────────────────────────────────────────────

final modulesProvider = FutureProvider.autoDispose<ModulesData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime : invalidation silencieuse sur changements catégories / modules / liens plan
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('platform_modules_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'modules',
          callback: (_) => scheduleInvalidate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'module_categories',
          callback: (_) => scheduleInvalidate(),
        )
        // `plan_modules` + `subscription_plans` : cet écran liste aussi les
        // plans auxquels chaque module est rattaché, avec leur tarif.
        .watchPlanReferential(scheduleInvalidate)
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // ── Modules (avec leur catégorie) ─────────────────────────────────────────
  List<Map<String, dynamic>> moduleRows = [];
  try {
    final rows = await client
        .from('modules')
        .select('id, category_id, name, slug, description, icon, '
            'display_order, is_active, created_at, updated_at, '
            'category:module_categories(name, icon)')
        .order('display_order', ascending: true) as List;
    moduleRows = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  } catch (_) {}

  // ── Liens plan_modules (comptage par module) ──────────────────────────────
  final Map<String, int> planCountByModule = {};
  try {
    final rows = await client.from('plan_modules').select('module_id') as List;
    for (final r in rows) {
      final mid = (r as Map)['module_id'] as String?;
      if (mid != null) planCountByModule[mid] = (planCountByModule[mid] ?? 0) + 1;
    }
  } catch (_) {}

  final modules = moduleRows
      .map((m) => ModuleItem.fromMap(m, planCount: planCountByModule[m['id']] ?? 0))
      .toList();

  // ── Comptages par catégorie ───────────────────────────────────────────────
  final Map<String, int> modCountByCat = {};
  final Map<String, int> activeCountByCat = {};
  for (final m in modules) {
    modCountByCat[m.categoryId] = (modCountByCat[m.categoryId] ?? 0) + 1;
    if (m.isActive) {
      activeCountByCat[m.categoryId] = (activeCountByCat[m.categoryId] ?? 0) + 1;
    }
  }

  // ── Catégories ─────────────────────────────────────────────────────────────
  List<ModuleCategory> categories = [];
  try {
    final rows = await client
        .from('module_categories')
        .select('id, name, slug, icon, display_order, created_at, updated_at')
        .order('display_order', ascending: true) as List;
    categories = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      return ModuleCategory.fromMap(
        m,
        moduleCount:       modCountByCat[id] ?? 0,
        activeModuleCount: activeCountByCat[id] ?? 0,
      );
    }).toList();
  } catch (_) {}

  // ── Plans d'abonnement (couverture) ────────────────────────────────────────
  List<PlanInfo> plans = [];
  try {
    final rows = await client
        .from('subscription_plans')
        .select('id, name, price_xaf, is_active')
        .eq('is_active', true)
        .order('price_xaf', ascending: true) as List;
    // comptage des modules par plan
    final Map<String, int> modCountByPlan = {};
    try {
      final links = await client.from('plan_modules').select('plan_id') as List;
      for (final l in links) {
        final pid = (l as Map)['plan_id'] as String?;
        if (pid != null) modCountByPlan[pid] = (modCountByPlan[pid] ?? 0) + 1;
      }
    } catch (_) {}
    plans = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      return PlanInfo(
        id:          id,
        name:        m['name'] as String? ?? '',
        priceXaf:    (m['price_xaf'] as num?)?.toInt(),
        moduleCount: modCountByPlan[id] ?? 0,
      );
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  final activeModules   = modules.where((m) => m.isActive).length;
  final totalPlanLinks  = planCountByModule.values.fold<int>(0, (a, b) => a + b);

  return ModulesData(
    categories:      categories,
    modules:         modules,
    plans:           plans,
    totalCategories: categories.length,
    totalModules:    modules.length,
    activeModules:   activeModules,
    inactiveModules: modules.length - activeModules,
    totalPlanLinks:  totalPlanLinks,
  );
});
