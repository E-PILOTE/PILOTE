import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import 'admin_access_provider.dart' show PermRow;

// ─── Accès d'un profil vis-à-vis d'un module ─────────────────────────────────
class ModuleProfileAccess {
  const ModuleProfileAccess({
    required this.id,
    required this.name,
    required this.memberCount,
    this.roleType,
    this.perm,
  });
  final String id;
  final String name;
  final int memberCount;
  final String? roleType;
  final PermRow? perm; // permissions actuelles pour CE module (null = aucun accès)

  bool get authorized => perm != null && !perm!.isEmpty;
}

// ─── Gouvernance d'un module (niveau groupe) ─────────────────────────────────
class ModuleOverview {
  const ModuleOverview({
    required this.id,
    required this.name,
    required this.slug,
    required this.accessible,
    required this.profiles,
    this.icon,
    this.description,
    this.categoryName,
  });
  final String id;
  final String name;
  final String slug;
  final bool accessible; // inclus dans le plan du groupe
  final List<ModuleProfileAccess> profiles;
  final String? icon;
  final String? description;
  final String? categoryName;

  int get authorizedProfiles => profiles.where((p) => p.authorized).length;
  int get totalProfiles => profiles.length;
}

final adminModuleProvider = FutureProvider.autoDispose
    .family<ModuleOverview?, String>((ref, slug) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return null;

  // 1. Module + catégorie
  Map<String, dynamic>? m;
  try {
    m = await client.from('modules')
        .select('id, name, slug, icon, description, '
            'module_categories!category_id(name)')
        .eq('slug', slug)
        .maybeSingle();
  } catch (_) {}
  if (m == null) return null;
  final moduleId = m['id'] as String;
  final cat = m['module_categories'] as Map<String, dynamic>?;

  // 2. Inclus dans le plan du groupe ?
  bool accessible = false;
  try {
    final g = await client.from('school_groups')
        .select('plan_id').eq('id', groupId).maybeSingle();
    final planId = g?['plan_id'] as String?;
    if (planId != null) {
      final r = await client.from('plan_modules')
          .select('module_id').eq('plan_id', planId)
          .eq('module_id', moduleId).maybeSingle();
      accessible = r != null;
    }
  } catch (_) {}

  // 3. Profils d'accès du groupe
  final List<Map<String, dynamic>> apRows = [];
  try {
    final r = await client.from('access_profiles')
        .select('id, name, role_type').eq('group_id', groupId)
        .order('name', ascending: true) as List;
    apRows.addAll(r.cast<Map<String, dynamic>>());
  } catch (_) {}

  // 4. Membres (personnel actif) rattachés à chaque profil
  final Map<String, int> membersByProfile = {};
  try {
    final r = await client.from('profiles')
        .select('access_profile_id')
        .eq('group_id', groupId).eq('is_active', true) as List;
    for (final p in r) {
      final pid = p['access_profile_id'] as String?;
      if (pid != null) membersByProfile[pid] = (membersByProfile[pid] ?? 0) + 1;
    }
  } catch (_) {}

  // 5. Permissions de CE module, par profil
  final Map<String, PermRow> permByProfile = {};
  try {
    final r = await client.from('profile_permissions')
        .select('profile_id, can_read, can_create, can_update, can_delete, '
            'can_export, can_import, can_validate, can_approve, can_manage, data_scope')
        .eq('group_id', groupId).eq('module_id', moduleId) as List;
    for (final p in r) {
      final pid = p['profile_id'] as String?;
      if (pid == null) continue;
      permByProfile[pid] = PermRow(
        canRead:     p['can_read']     as bool? ?? false,
        canCreate:   p['can_create']   as bool? ?? false,
        canUpdate:   p['can_update']   as bool? ?? false,
        canDelete:   p['can_delete']   as bool? ?? false,
        canExport:   p['can_export']   as bool? ?? false,
        canImport:   p['can_import']   as bool? ?? false,
        canValidate: p['can_validate'] as bool? ?? false,
        canApprove:  p['can_approve']  as bool? ?? false,
        canManage:   p['can_manage']   as bool? ?? false,
        dataScope:   p['data_scope']   as String? ?? 'own_school',
      );
    }
  } catch (_) {}

  final profiles = apRows.map((a) {
    final id = a['id'] as String;
    return ModuleProfileAccess(
      id: id,
      name: a['name'] as String? ?? '—',
      roleType: a['role_type'] as String?,
      memberCount: membersByProfile[id] ?? 0,
      perm: permByProfile[id],
    );
  }).toList();

  return ModuleOverview(
    id:           moduleId,
    name:         m['name'] as String? ?? '—',
    slug:         m['slug'] as String? ?? slug,
    icon:         m['icon'] as String?,
    description:  m['description'] as String?,
    categoryName: cat?['name'] as String?,
    accessible:   accessible,
    profiles:     profiles,
  );
});
