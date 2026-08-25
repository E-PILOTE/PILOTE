import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

/// Périmètre d'un journal d'audit. Un même module, deux portées :
///  • **groupe** (admin_groupe) — toutes les écoles du groupe, dimension
///    « École » visible (filtre, classement, colonne).
///  • **école** (direction) — une seule école, dimension « École » masquée
///    (redondante). Le filtre RLS bascule de `group_id` à `school_id`.
///
/// C'est le SEUL point de divergence entre les deux espaces : tout le reste du
/// module (écran, providers, widgets) est partagé — cf. la règle CLAUDE.md
/// « pas de duplication par espace ».
enum AuditScopeKind { group, school }

class AuditScope {
  const AuditScope._(this.kind, this.column, this.id, this.hiddenActorRoles);

  /// Périmètre groupe (admin_groupe) : filtre `group_id`, écoles visibles.
  const AuditScope.group(String groupId,
      {Set<String> hiddenActorRoles = const <String>{}})
      : this._(AuditScopeKind.group, 'group_id', groupId, hiddenActorRoles);

  /// Périmètre école (direction) : filtre `school_id`, dimension école masquée.
  const AuditScope.school(String schoolId,
      {Set<String> hiddenActorRoles = const <String>{}})
      : this._(AuditScopeKind.school, 'school_id', schoolId, hiddenActorRoles);

  final AuditScopeKind kind;

  /// Colonne de filtrage RLS/requête (`group_id` ou `school_id`).
  final String column;

  /// Identifiant du groupe ou de l'école.
  final String id;

  /// Plancher de visibilité : rôles-acteurs dont les actions sont **masquées**
  /// pour ce spectateur (on ne voit jamais un niveau au-dessus du sien). Le
  /// trigger d'audit estampille `school_id`/`group_id` depuis la LIGNE modifiée,
  /// donc une action super_admin sur une ligne d'école porte le `school_id` de
  /// cette école → sans ce plancher elle remonterait dans l'audit école. Appliqué
  /// en dur dans chaque requête, jamais décochable (frontière de sécurité).
  final Set<String> hiddenActorRoles;

  bool get isGroup => kind == AuditScopeKind.group;

  /// Affiche la dimension « École » (filtre déroulant, top-écoles, colonne).
  /// Faux en périmètre école : une seule école → dimension redondante.
  bool get showSchoolDimension => isGroup;

  /// Suffixe stable pour nommer le canal Realtime.
  String get channelKey => '${column}_$id';

  @override
  bool operator ==(Object other) =>
      other is AuditScope && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Rôles-acteurs **masqués** selon le rôle du SPECTATEUR — « chacun voit son
/// niveau et en dessous, jamais au-dessus » :
///  • `super_admin` (plateforme) → ne masque rien, voit tout ;
///  • `admin_groupe` (groupe) → masque les actions `super_admin` ; voit en
///    revanche tout le personnel de ses écoles ;
///  • personnel école (TOUS les rôles école, sans sous-hiérarchie) → masque
///    `super_admin` et `admin_groupe` ; tout le staff voit toutes les actions de
///    son école.
///
/// Fonction pure (testable sans auth) — source unique du plancher de visibilité.
Set<String> hiddenActorRolesForViewer(String viewerRole) {
  if (viewerRole == AppConstants.roleSuperAdmin) return const <String>{};
  if (viewerRole == AppConstants.roleAdminGroupe) {
    return const {AppConstants.roleSuperAdmin};
  }
  return const {AppConstants.roleSuperAdmin, AppConstants.roleAdminGroupe};
}

/// Portée du journal d'audit déduite du compte connecté :
///  • admin_groupe / super_admin → périmètre **groupe** ;
///  • tout autre rôle (direction) → périmètre **école**.
///
/// Un utilisateur donné est soit l'un soit l'autre → portée non ambiguë, sans
/// override. Renvoie `null` si le tenant attendu n'est pas encore résolu
/// (l'écran affiche alors l'état « connexion requise »). La portée embarque
/// aussi le plancher de rôles-acteurs masqués ([hiddenActorRolesForViewer]).
final auditScopeProvider = Provider<AuditScope?>((ref) {
  final p = ref.watch(authNotifierProvider).valueOrNull;
  if (p == null) return null;
  final role = p.role;
  final hidden = hiddenActorRolesForViewer(role);
  if (role == AppConstants.roleSuperAdmin ||
      role == AppConstants.roleAdminGroupe) {
    final gid = p.groupId;
    return gid == null ? null : AuditScope.group(gid, hiddenActorRoles: hidden);
  }
  final sid = p.schoolId;
  return sid == null
      ? null
      : AuditScope.school(sid, hiddenActorRoles: hidden);
});
