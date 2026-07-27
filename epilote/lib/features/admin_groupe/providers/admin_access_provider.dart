import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ────────────────────────────────────────────────────────────────
class AccessProfile {
  const AccessProfile({
    required this.id,
    required this.name,
    required this.isActive,
    required this.memberCount,
    required this.moduleCount,
    this.description,
    this.roleType,
  });
  final String id;
  final String name;
  final String? description;
  final String? roleType; // type ERP standard (proviseur, comptable…)
  final bool isActive;
  final int memberCount;
  final int moduleCount;
}

class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.accessible,
    this.icon,
  });
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final bool accessible; // inclus dans le plan du groupe
}

class ModuleCategory {
  const ModuleCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.modules,
  });
  final String id;
  final String name;
  final String slug;
  final List<ModuleInfo> modules;
}

class AdminAccessData {
  const AdminAccessData({
    required this.profiles,
    required this.categories,
    this.withoutProfile    = 0,
    this.totalGroupMembers = 0,
  });
  final List<AccessProfile> profiles;
  final List<ModuleCategory> categories;
  final int withoutProfile;
  final int totalGroupMembers;

  int get accessibleModules  =>
      categories.fold(0, (s, c) => s + c.modules.where((m) => m.accessible).length);
  int get totalModules       => categories.fold(0, (s, c) => s + c.modules.length);
  int get activeProfiles     => profiles.where((p) => p.isActive).length;
  int get inactiveProfiles   => profiles.length - activeProfiles;
  int get totalCoveredMembers =>
      profiles.fold<int>(0, (s, p) => s + p.memberCount);

  static const empty = AdminAccessData(profiles: [], categories: []);
}

class PermRow {
  const PermRow({
    this.canRead = false,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
    this.canExport = false,
    this.canImport = false,
    this.canValidate = false,
    this.canApprove = false,
    this.canManage = false,
    this.dataScope = 'own_school',
  });
  final bool canRead, canCreate, canUpdate, canDelete,
      canExport, canImport, canValidate, canApprove, canManage;
  final String dataScope;

  bool get isEmpty =>
      !canRead && !canCreate && !canUpdate && !canDelete &&
      !canExport && !canImport && !canValidate && !canApprove && !canManage;

  // Lecture de compatibilité : un profil « écrit » s'il crée ou modifie.
  bool get canWrite => canCreate || canUpdate;

  // Nombre d'actions sensibles activées (suppression, export, import,
  // validation, approbation, gestion des paramètres).
  int get sensitiveCount =>
      (canDelete ? 1 : 0) + (canExport ? 1 : 0) + (canImport ? 1 : 0) +
      (canValidate ? 1 : 0) + (canApprove ? 1 : 0) + (canManage ? 1 : 0);

  PermRow copyWith({
    bool? canRead, bool? canCreate, bool? canUpdate, bool? canDelete,
    bool? canExport, bool? canImport, bool? canValidate, bool? canApprove,
    bool? canManage, String? dataScope,
  }) =>
      PermRow(
        canRead:     canRead     ?? this.canRead,
        canCreate:   canCreate   ?? this.canCreate,
        canUpdate:   canUpdate   ?? this.canUpdate,
        canDelete:   canDelete   ?? this.canDelete,
        canExport:   canExport   ?? this.canExport,
        canImport:   canImport   ?? this.canImport,
        canValidate: canValidate ?? this.canValidate,
        canApprove:  canApprove  ?? this.canApprove,
        canManage:   canManage   ?? this.canManage,
        dataScope:   dataScope   ?? this.dataScope,
      );

  Map<String, dynamic> toJson(String moduleId) => {
        'module_id': moduleId,
        'can_read': canRead,
        'can_create': canCreate,
        'can_update': canUpdate,
        'can_delete': canDelete,
        'can_export': canExport,
        'can_import': canImport,
        'can_validate': canValidate,
        'can_approve': canApprove,
        'can_manage': canManage,
        'data_scope': dataScope,
      };
}

// ─── Provider liste profils + catalogue modules ─────────────────────────────
final adminAccessProvider =
    FutureProvider.autoDispose<AdminAccessData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminAccessData.empty;

  Timer? debounce;
  try {
    final channel = client.channel('admin_access_$groupId');
    for (final t in ['access_profiles', 'profile_permissions', 'profiles']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
        },
      );
    }
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Plan du groupe → modules accessibles
  Set<String> accessibleModuleIds = {};
  try {
    final g = await client.from('school_groups')
        .select('plan_id').eq('id', groupId).maybeSingle();
    final planId = g?['plan_id'] as String?;
    if (planId != null) {
      final rows = await client.from('plan_modules')
          .select('module_id').eq('plan_id', planId) as List;
      accessibleModuleIds = {for (final r in rows) r['module_id'] as String};
    }
  } catch (_) {}

  // Catalogue : catégories + modules
  final List<ModuleCategory> categories = [];
  try {
    final cats = await client.from('module_categories')
        .select('id, name, slug, display_order')
        .order('display_order', ascending: true) as List;
    final mods = await client.from('modules')
        .select('id, name, slug, icon, category_id, display_order')
        .eq('is_active', true)
        .order('display_order', ascending: true) as List;
    for (final c in cats) {
      final cid = c['id'] as String;
      final catMods = mods.where((m) => m['category_id'] == cid).map((m) {
        final mid = m['id'] as String;
        return ModuleInfo(
          id: mid,
          name: m['name'] as String? ?? '—',
          slug: m['slug'] as String? ?? '',
          icon: m['icon'] as String?,
          accessible: accessibleModuleIds.contains(mid),
        );
      }).toList();
      if (catMods.isNotEmpty) {
        categories.add(ModuleCategory(
          id: cid,
          name: c['name'] as String? ?? '—',
          slug: c['slug'] as String? ?? '',
          modules: catMods,
        ));
      }
    }
  } catch (_) {}

  // Profils d'accès
  final List<Map<String, dynamic>> apRows = [];
  try {
    final rows = await client.from('access_profiles')
        .select('id, name, description, is_active, role_type')
        .eq('group_id', groupId)
        .order('name', ascending: true) as List;
    apRows.addAll(rows.cast<Map<String, dynamic>>());
  } catch (_) {}

  // Comptage membres par profil + membres sans profil
  final Map<String, int> members = {};
  int withoutProfileCount = 0;
  int totalGrpMembers     = 0;
  try {
    final rows = await client.from('profiles')
        .select('access_profile_id')
        .eq('group_id', groupId)
        .eq('is_active', true) as List;
    for (final r in rows) {
      totalGrpMembers++;
      final pid = r['access_profile_id'] as String?;
      if (pid != null) { members[pid] = (members[pid] ?? 0) + 1; }
      else             { withoutProfileCount++; }
    }
  } catch (_) {}

  // Comptage modules autorisés par profil
  final Map<String, int> modCounts = {};
  try {
    final rows = await client.from('profile_permissions')
        .select('profile_id')
        .eq('group_id', groupId) as List;
    for (final r in rows) {
      final pid = r['profile_id'] as String?;
      if (pid != null) modCounts[pid] = (modCounts[pid] ?? 0) + 1;
    }
  } catch (_) {}

  final profiles = apRows.map((a) {
    final id = a['id'] as String;
    return AccessProfile(
      id: id,
      name: a['name'] as String? ?? '—',
      description: a['description'] as String?,
      roleType: a['role_type'] as String?,
      isActive: a['is_active'] as bool? ?? true,
      memberCount: members[id] ?? 0,
      moduleCount: modCounts[id] ?? 0,
    );
  }).toList();

  return AdminAccessData(
    profiles:          profiles,
    categories:        categories,
    withoutProfile:    withoutProfileCount,
    totalGroupMembers: totalGrpMembers,
  );
});

// ─── Permissions existantes d'un profil ─────────────────────────────────────
final accessProfilePermsProvider = FutureProvider.autoDispose
    .family<Map<String, PermRow>, String>((ref, profileId) async {
  final client = ref.watch(supabaseClientProvider);
  final Map<String, PermRow> map = {};
  try {
    final rows = await client.from('profile_permissions')
        .select('module_id, can_read, can_create, can_update, can_delete, '
            'can_export, can_import, can_validate, can_approve, can_manage, data_scope')
        .eq('profile_id', profileId) as List;
    for (final r in rows) {
      map[r['module_id'] as String] = PermRow(
        canRead:     r['can_read']     as bool? ?? false,
        canCreate:   r['can_create']   as bool? ?? false,
        canUpdate:   r['can_update']   as bool? ?? false,
        canDelete:   r['can_delete']   as bool? ?? false,
        canExport:   r['can_export']   as bool? ?? false,
        canImport:   r['can_import']   as bool? ?? false,
        canValidate: r['can_validate'] as bool? ?? false,
        canApprove:  r['can_approve']  as bool? ?? false,
        canManage:   r['can_manage']   as bool? ?? false,
        dataScope:   r['data_scope']   as String? ?? 'own_school',
      );
    }
  } catch (_) {}
  return map;
});

// ─── Service ────────────────────────────────────────────────────────────────
class AdminAccessService {
  AdminAccessService(this._ref);
  final Ref _ref;

  Future<String> createProfile({
    required String name,
    String? description,
    String? roleType,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    final uid = client.auth.currentUser?.id;
    if (groupId == null) throw Exception('Groupe introuvable');
    final row = await client.from('access_profiles').insert({
      'group_id':   groupId,
      'name':       name,
      'description': (description != null && description.isNotEmpty) ? description : null,
      'role_type':  roleType,
      'is_active':  true,
      'created_by': uid,
    }).select('id').single();
    _ref.invalidate(adminAccessProvider);
    return row['id'] as String;
  }

  Future<void> updateProfile({
    required String id,
    required String name,
    String? description,
    String? roleType,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('access_profiles').update({
      'name': name,
      'description': (description != null && description.isNotEmpty) ? description : null,
      'role_type': roleType,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(adminAccessProvider);
  }

  Future<void> setActive(String id, bool active) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('access_profiles').update({
      'is_active': active,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(adminAccessProvider);
  }

  /// Nombre de membres (actifs ou non) rattachés à ce profil.
  /// Sert de garde avant suppression : la FK profiles.access_profile_id
  /// est en NO ACTION → supprimer un profil encore attribué échoue côté DB.
  Future<int> countMembers(String profileId) async {
    final client = _ref.read(supabaseClientProvider);
    final rows = await client
        .from('profiles')
        .select('id')
        .eq('access_profile_id', profileId) as List;
    return rows.length;
  }

  /// Supprime définitivement un profil d'accès.
  /// Les permissions associées partent en cascade (FK ON DELETE CASCADE).
  /// Refuse la suppression si des membres y sont encore rattachés.
  Future<void> deleteProfile(String id) async {
    final client = _ref.read(supabaseClientProvider);
    final attached = await countMembers(id);
    if (attached > 0) {
      throw Exception(
          '$attached membre${attached > 1 ? 's' : ''} encore rattaché'
          '${attached > 1 ? 's' : ''} à ce profil. Réattribuez-les avant suppression.');
    }
    await client.from('access_profiles').delete().eq('id', id);
    _ref.invalidate(adminAccessProvider);
    _ref.invalidate(accessProfilePermsProvider(id));
  }

  Future<void> savePermissions(String profileId, List<Map<String, dynamic>> perms) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_profile_permissions', params: {
      'p_profile_id': profileId,
      'p_perms': perms,
    });
    _ref.invalidate(adminAccessProvider);
    _ref.invalidate(accessProfilePermsProvider(profileId));
  }
}

final adminAccessServiceProvider =
    Provider<AdminAccessService>((ref) => AdminAccessService(ref));
