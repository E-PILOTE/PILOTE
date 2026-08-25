import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/active_agent_provider.dart';
import '../../../licensing/presentation/license_providers.dart';
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
  // Permissions de l'AGENT ACTIF (poste partagé) — son access_profile_id local.
  final apId = ref.watch(activeAgentAccessProfileIdProvider).valueOrNull;
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

/// `can(slug, action)` — verrou 3 (profil) pour gating des boutons. Faux si non
/// chargé. Ajout du **verrou LICENCE** : en lecture seule (licence expirée
/// au-delà de la grâce, ou fenêtre de confiance dépassée), on coupe les actions
/// d'ÉCRITURE — jamais la lecture. Fail-soft : sans licence (dormant) ou au
/// doute, aucun changement de comportement. Ne gate JAMAIS la synchro (C4).
final canProvider =
    Provider.autoDispose.family<bool, ({String slug, String action})>((ref, key) {
  final perm = ref.watch(modulePermissionProvider(key.slug));
  if (!(perm?.can(key.action) ?? false)) return false;

  // Actions MUTANTES coupées en lecture seule. `read` et `export` restent
  // toujours permis (N12 : export des dossiers élèves autorisé même restreint).
  const mutating = {
    'create', 'update', 'delete', 'import', 'validate', 'approve', 'manage', 'write',
  };
  if (mutating.contains(key.action)) {
    final ent = ref.watch(entitlementProvider).valueOrNull;
    if (ent != null && ent.isEnforced && !ent.canWriteAt(DateTime.now().toUtc())) {
      return false; // lecture seule → écriture coupée
    }
  }
  return true;
});

// ─── Périmètre (verrou 4) ──────────────────────────────────────────────────

/// IDs de classes autorisées pour un module, selon `data_scope` :
/// - `own_school`  → `null` (= aucune restriction : toute l'école, géré par RLS/appelant)
/// - `own_classes` → liste des `class_id` enseignés par le membre (peut être vide)
///
/// ── ⚠️ `teacher_subjects.staff_id` EST UN `profiles.id` ─────────────────────
/// La contrainte en base le dit : `teacher_subjects_staff_id_fkey FOREIGN KEY
/// (staff_id) REFERENCES profiles(id)`. Il n'y a pas d'identifiant « staff »
/// distinct à résoudre — `staff_members` est une table d'EXTENSION dont la clé
/// primaire est déjà l'id du profil (`staff_members_id_fkey → profiles(id)`).
///
/// On passait par un `myStaffIdProvider` qui cherchait `staff_members.profile_id` :
/// cette colonne n'existe pas côté serveur (elle n'est déclarée que dans le
/// schéma local, où elle reste vide). La recherche ne renvoyait donc JAMAIS
/// rien, et tout membre en `own_classes` héritait d'une liste de classes vide —
/// c'est-à-dire d'une application entièrement vide : aucun élève, aucune note,
/// aucun bulletin, et pas un message pour l'expliquer. Le verrou de périmètre
/// ne restreignait pas, il effaçait.
final scopedClassIdsProvider =
    StreamProvider.autoDispose.family<List<String>?, String>((ref, slug) {
  final perm = ref.watch(modulePermissionProvider(slug));
  if (perm == null || !perm.isOwnClasses) {
    return Stream.value(null); // null = toute l'école
  }
  final profileId = ref.watch(activeAgentIdProvider);
  if (profileId == null || profileId.isEmpty) {
    return Stream.value(const <String>[]);
  }
  return db
      .watch(
        'SELECT DISTINCT class_id FROM teacher_subjects WHERE staff_id = ?',
        parameters: [profileId],
      )
      .map((rows) =>
          rows.map((r) => r['class_id'] as String?).whereType<String>().toList());
});

/// Fragment SQL restreignant une requête aux classes du membre, à coller dans
/// un `WHERE` déjà ouvert. `null` = aucune restriction (`own_school`).
///
/// [column] est la colonne de classe DE LA REQUÊTE APPELANTE (`ce.class_id`,
/// `c.id`, …) : chaque module la nomme à sa façon, seule la liste d'IDs est
/// commune.
///
/// ⚠️ FERMÉ PAR DÉFAUT. Tant que la liste des classes n'est pas chargée, on
/// renvoie `AND 0 = 1` plutôt que « pas de restriction » : afficher toute
/// l'école pendant une demi-seconde à un enseignant restreint, c'est l'avoir
/// affichée. Chaque module doit passer par ici — un provider qui oublie le
/// périmètre ouvre l'école entière sans que rien ne le signale (c'était le cas
/// du registre des élèves, donc aussi de l'annuaire des familles).
({String clause, List<String> params})? classScopeClause(
  Ref ref,
  String slug, {
  required String column,
}) {
  // Profil d'accès pas encore lu : on ne sait pas si ce membre est restreint.
  // « Je ne sais pas » se traite comme « restreint », jamais comme « ouvert » —
  // sinon la fenêtre de chargement sert l'école entière. Les pages qui doivent
  // afficher un squelette plutôt qu'un effectif vide interrogent d'abord
  // [permissionsLoaded].
  if (!permissionsLoaded(ref)) {
    return (clause: 'AND 0 = 1', params: const <String>[]);
  }
  final perm = ref.watch(modulePermissionProvider(slug));
  if (perm == null || !perm.isOwnClasses) return null; // own_school → tout
  final ids =
      ref.watch(scopedClassIdsProvider(slug)).valueOrNull ?? const <String>[];
  if (ids.isEmpty) return (clause: 'AND 0 = 1', params: const <String>[]);
  final ph = List.filled(ids.length, '?').join(',');
  return (clause: 'AND $column IN ($ph)', params: ids);
}

/// `true` dès que le profil d'accès du membre est connu — même s'il est vide
/// (aucun module accordé). Sert à distinguer « pas encore chargé » de
/// « chargé et sans droit », que `modulePermissionProvider` confond en `null`.
bool permissionsLoaded(Ref ref) => ref.watch(myPermissionsProvider).hasValue;
