import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Permissions du membre courant — verrous 3 (profil) & 4 (périmètre), offline.
//  Source : profile_permissions (synchronisé pour le seul profil du membre).
// ════════════════════════════════════════════════════════════════════════════

/// Permission d'un module : 10 actions + périmètre de données.
class ModulePermission {
  const ModulePermission({
    required this.moduleSlug,
    required this.canRead,
    required this.canCreate,
    required this.canUpdate,
    required this.canDelete,
    required this.canExport,
    required this.canImport,
    required this.canValidate,
    required this.canApprove,
    required this.canManage,
    required this.canWrite,
    required this.dataScope,
  });

  factory ModulePermission.fromRow(Map<String, dynamic> r) => ModulePermission(
        moduleSlug: r['slug'] as String? ?? '',
        canRead:     _b(r['can_read']),
        canCreate:   _b(r['can_create']),
        canUpdate:   _b(r['can_update']),
        canDelete:   _b(r['can_delete']),
        canExport:   _b(r['can_export']),
        canImport:   _b(r['can_import']),
        canValidate: _b(r['can_validate']),
        canApprove:  _b(r['can_approve']),
        canManage:   _b(r['can_manage']),
        canWrite:    _b(r['can_write']),
        dataScope:   r['data_scope'] as String? ?? 'own_school',
      );

  final String moduleSlug;
  final bool canRead, canCreate, canUpdate, canDelete, canExport;
  final bool canImport, canValidate, canApprove, canManage, canWrite;
  final String dataScope; // own_classes | own_school

  bool get isOwnClasses => dataScope == 'own_classes';

  /// Évalue une action par son nom (clé utilisée par [PermissionGate]).
  bool can(String action) => switch (action) {
        'read'     => canRead,
        'create'   => canCreate,
        'update'   => canUpdate,
        'delete'   => canDelete,
        'export'   => canExport,
        'import'   => canImport,
        'validate' => canValidate,
        'approve'  => canApprove,
        'manage'   => canManage,
        'write'    => canWrite,
        _          => false,
      };

  // PowerSync stocke les booléens en INTEGER (0/1).
  static bool _b(Object? v) => v == 1 || v == true;
}

/// Permissions du membre, indexées par slug de module. Réactif, 100% local.
/// Map vide si aucun profil d'accès n'est assigné (`access_profile_id` null).
final myPermissionsProvider =
    StreamProvider.autoDispose<Map<String, ModulePermission>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final apId = profile?.accessProfileId;
  if (apId == null || apId.isEmpty) {
    return Stream.value(const {});
  }
  return db
      .watch(
        '''
        SELECT  m.slug AS slug, pp.*
        FROM    profile_permissions pp
        JOIN    modules m ON m.id = pp.module_id
        WHERE   pp.profile_id = ?
        ''',
        parameters: [apId],
      )
      .map((rows) {
        final map = <String, ModulePermission>{};
        for (final r in rows) {
          final p = ModulePermission.fromRow(r);
          if (p.moduleSlug.isNotEmpty) map[p.moduleSlug] = p;
        }
        return map;
      });
});

/// La permission d'un module précis (ou null si non accordé / non chargé).
final modulePermissionProvider =
    Provider.autoDispose.family<ModulePermission?, String>((ref, slug) {
  final perms = ref.watch(myPermissionsProvider).valueOrNull ?? const {};
  return perms[slug];
});

/// `can(slug, action)` — verrou 3 pour gating des boutons. Faux si non chargé.
final canProvider =
    Provider.autoDispose.family<bool, ({String slug, String action})>((ref, key) {
  final perm = ref.watch(modulePermissionProvider(key.slug));
  return perm?.can(key.action) ?? false;
});

// ─── Périmètre (verrou 4) ──────────────────────────────────────────────────

/// `staff_id` du membre connecté (via staff_members.profile_id), ou null.
/// Null tant que le lien n'est pas peuplé → own_classes = aucune classe (sûr).
final myStaffIdProvider = StreamProvider.autoDispose<String?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final pid = profile?.id;
  if (pid == null || pid.isEmpty) return Stream.value(null);
  return db
      .watch(
        'SELECT id FROM staff_members WHERE profile_id = ? AND is_active = 1 LIMIT 1',
        parameters: [pid],
      )
      .map((rows) => rows.isEmpty ? null : rows.first['id'] as String?);
});

/// IDs de classes autorisées pour un module, selon `data_scope` :
/// - `own_school`  → `null` (= aucune restriction : toute l'école, géré par RLS/appelant)
/// - `own_classes` → liste des `class_id` enseignés par le membre (peut être vide)
final scopedClassIdsProvider =
    StreamProvider.autoDispose.family<List<String>?, String>((ref, slug) {
  final perm = ref.watch(modulePermissionProvider(slug));
  if (perm == null || !perm.isOwnClasses) {
    return Stream.value(null); // null = toute l'école
  }
  final staffId = ref.watch(myStaffIdProvider).valueOrNull;
  if (staffId == null) return Stream.value(const <String>[]);
  return db
      .watch(
        'SELECT DISTINCT class_id FROM teacher_subjects WHERE staff_id = ?',
        parameters: [staffId],
      )
      .map((rows) =>
          rows.map((r) => r['class_id'] as String?).whereType<String>().toList());
});
