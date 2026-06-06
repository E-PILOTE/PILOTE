import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles catalogue modules (espace admin_groupe) ─────────────────────────
class AdminCatalogModule {
  const AdminCatalogModule({
    required this.slug,
    required this.name,
    required this.authorizedProfiles,
    this.id,
    this.icon,
    this.description,
  });
  final String? id;   // UUID DB — clé de liaison avec les données d'adoption
  final String slug;
  final String name;
  final int authorizedProfiles;
  final String? icon;
  final String? description;
}

class AdminCatalogCategory {
  const AdminCatalogCategory({
    required this.name,
    required this.slug,
    required this.modules,
  });
  final String name;
  final String slug;
  final List<AdminCatalogModule> modules;
}

class AdminModulesCatalog {
  const AdminModulesCatalog({
    required this.categories,
    required this.totalProfiles,
  });
  final List<AdminCatalogCategory> categories;
  final int totalProfiles; // nb de profils d'accès du groupe (dénominateur)

  bool get isEmpty => categories.isEmpty;
  int get moduleCount =>
      categories.fold(0, (sum, c) => sum + c.modules.length);
}

// ─── Adoption des modules par école ──────────────────────────────────────────

class ModuleAdoptionEntry {
  const ModuleAdoptionEntry({
    required this.moduleId,
    required this.moduleName,
    required this.schoolCount,
    this.icon,
    this.schoolIds = const {},
  });
  final String      moduleId;
  final String      moduleName;
  final String?     icon;
  final int         schoolCount;
  /// IDs des écoles qui utilisent ce module (au moins 1 utilisateur autorisé).
  final Set<String> schoolIds;
}

class ModuleAdoptionData {
  const ModuleAdoptionData({
    required this.totalSchools,
    required this.ranking,
    this.schoolNames = const {},
  });
  final int totalSchools;
  /// Modules triés par nombre décroissant d'écoles ayant ≥1 utilisateur autorisé.
  final List<ModuleAdoptionEntry> ranking;
  /// schoolId → nom de l'école (pour le drill-down par module).
  final Map<String, String> schoolNames;
  bool get isEmpty => ranking.isEmpty || totalSchools == 0;
}

/// Croise profiles.access_profile_id × profile_permissions × schools pour
/// savoir quelles écoles ont chaque module configuré.
final adminModuleAdoptionProvider =
    FutureProvider.autoDispose<ModuleAdoptionData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  const empty   = ModuleAdoptionData(totalSchools: 0, ranking: []);
  if (groupId == null) return empty;

  try {
    // Fetch en parallèle : écoles actives (id+name) + liens profil-école + permissions
    final results = await Future.wait([
      client.from('schools')
          .select('id, name')
          .eq('group_id', groupId)
          .eq('is_active', true),
      client.from('profiles')
          .select('school_id, access_profile_id')
          .eq('group_id', groupId)
          .eq('is_active', true)
          .not('school_id', 'is', null)
          .not('access_profile_id', 'is', null),
      client.from('profile_permissions')
          .select('profile_id, module_id, can_read, can_create, can_update, '
              'can_delete, can_export, can_import, can_validate, can_approve, can_manage')
          .eq('group_id', groupId),
    ]);

    final schoolRows  = results[0] as List;
    final profileRows = results[1] as List;
    final permRows    = results[2] as List;

    final totalSchools = schoolRows.length;
    if (totalSchools == 0) return empty;

    // schoolId → nom
    final schoolNameMap = <String, String>{};
    for (final s in schoolRows) {
      final sid = s['id'] as String?;
      if (sid != null) schoolNameMap[sid] = s['name'] as String? ?? '?';
    }

    // profileId → Set<moduleId> ayant au moins un droit actif
    final profileMods = <String, Set<String>>{};
    for (final p in permRows) {
      final pid = p['profile_id'] as String?;
      final mid = p['module_id']  as String?;
      if (pid == null || mid == null) continue;
      final any = (p['can_read']     as bool? ?? false) ||
                  (p['can_create']   as bool? ?? false) ||
                  (p['can_update']   as bool? ?? false) ||
                  (p['can_delete']   as bool? ?? false) ||
                  (p['can_export']   as bool? ?? false) ||
                  (p['can_import']   as bool? ?? false) ||
                  (p['can_validate'] as bool? ?? false) ||
                  (p['can_approve']  as bool? ?? false) ||
                  (p['can_manage']   as bool? ?? false);
      if (any) (profileMods[pid] ??= {}).add(mid);
    }

    // moduleId → Set<schoolId>
    final modSchools = <String, Set<String>>{};
    for (final link in profileRows) {
      final sid = link['school_id']        as String?;
      final pid = link['access_profile_id'] as String?;
      if (sid == null || pid == null) continue;
      for (final mid in profileMods[pid] ?? <String>{}) {
        (modSchools[mid] ??= {}).add(sid);
      }
    }
    if (modSchools.isEmpty) return empty;

    // Récupérer les noms + icônes des modules concernés
    final modIds  = modSchools.keys.toList();
    final modRows = await client.from('modules')
        .select('id, name, icon')
        .eq('is_active', true)
        .inFilter('id', modIds) as List;

    final ranking = modRows.map((m) {
      final mid = m['id'] as String;
      return ModuleAdoptionEntry(
        moduleId:    mid,
        moduleName:  m['name'] as String? ?? '—',
        icon:        m['icon'] as String?,
        schoolCount: modSchools[mid]?.length ?? 0,
        schoolIds:   Set<String>.unmodifiable(modSchools[mid] ?? {}),
      );
    }).toList()
      ..sort((a, b) => b.schoolCount.compareTo(a.schoolCount));

    return ModuleAdoptionData(
      totalSchools: totalSchools,
      ranking:      ranking,
      schoolNames:  Map<String, String>.unmodifiable(schoolNameMap),
    );
  } catch (_) {
    return empty;
  }
});

// ─────────────────────────────────────────────────────────────────────────────

/// Catalogue des modules **accessibles** selon le plan du groupe, enrichi de la
/// posture de gouvernance (nb de profils autorisés par module). Alimente à la
/// fois l'entrée « Modules du groupe » de la sidebar et l'écran catalogue.
final adminModulesCatalogProvider =
    FutureProvider.autoDispose<AdminModulesCatalog>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  const empty = AdminModulesCatalog(categories: [], totalProfiles: 0);
  if (groupId == null) return empty;

  // 1. Plan du groupe → ids des modules accessibles
  Set<String> accessibleIds = {};
  try {
    final g = await client.from('school_groups')
        .select('plan_id').eq('id', groupId).maybeSingle();
    final planId = g?['plan_id'] as String?;
    if (planId != null) {
      final rows = await client.from('plan_modules')
          .select('module_id').eq('plan_id', planId) as List;
      accessibleIds = {for (final r in rows) r['module_id'] as String};
    }
  } catch (_) {}
  if (accessibleIds.isEmpty) return empty;

  // 2. Profils d'accès du groupe (dénominateur)
  int totalProfiles = 0;
  try {
    final r = await client.from('access_profiles')
        .select('id').eq('group_id', groupId) as List;
    totalProfiles = r.length;
  } catch (_) {}

  // 3. Profils autorisés par module (au moins un droit can_* actif)
  final Map<String, Set<String>> authByModule = {};
  try {
    final r = await client.from('profile_permissions')
        .select('module_id, profile_id, can_read, can_create, can_update, '
            'can_delete, can_export, can_import, can_validate, can_approve, can_manage')
        .eq('group_id', groupId) as List;
    for (final p in r) {
      final mid = p['module_id'] as String?;
      final pid = p['profile_id'] as String?;
      if (mid == null || pid == null) continue;
      final any = (p['can_read']     as bool? ?? false) ||
                  (p['can_create']   as bool? ?? false) ||
                  (p['can_update']   as bool? ?? false) ||
                  (p['can_delete']   as bool? ?? false) ||
                  (p['can_export']   as bool? ?? false) ||
                  (p['can_import']   as bool? ?? false) ||
                  (p['can_validate'] as bool? ?? false) ||
                  (p['can_approve']  as bool? ?? false) ||
                  (p['can_manage']   as bool? ?? false);
      if (any) (authByModule[mid] ??= {}).add(pid);
    }
  } catch (_) {}

  // 4. Catalogue catégories + modules actifs accessibles
  final List<AdminCatalogCategory> cats = [];
  try {
    final catRows = await client.from('module_categories')
        .select('id, name, slug, display_order')
        .order('display_order') as List;
    final modRows = await client.from('modules')
        .select('id, name, slug, icon, description, category_id, display_order')
        .eq('is_active', true)
        .order('display_order') as List;
    for (final c in catRows) {
      final cid = c['id'] as String;
      final mods = modRows
          .where((m) => m['category_id'] == cid &&
              accessibleIds.contains(m['id'] as String))
          .map((m) => AdminCatalogModule(
                id:   m['id'] as String?,
                slug: m['slug'] as String? ?? '',
                name: m['name'] as String? ?? '—',
                icon: m['icon'] as String?,
                description: m['description'] as String?,
                authorizedProfiles: authByModule[m['id'] as String]?.length ?? 0,
              ))
          .toList();
      if (mods.isNotEmpty) {
        cats.add(AdminCatalogCategory(
          name: c['name'] as String? ?? '—',
          slug: c['slug'] as String? ?? '',
          modules: mods,
        ));
      }
    }
  } catch (_) {}

  return AdminModulesCatalog(categories: cats, totalProfiles: totalProfiles);
});
