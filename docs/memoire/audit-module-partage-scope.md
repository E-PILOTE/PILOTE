---
name: audit-module-partage-scope
description: "Journal d'audit unifié en module partagé scope-aware (admin_groupe + école) — parité complète, dimension école auto-masquée en périmètre école"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-25T09:25:40.562Z
---

**2026-07-24 — Journal d'audit = module partagé `features/audit/` scope-aware** (non commité à l'écriture ; analyze 0, 381 tests). Remplace les DEUX anciens écrans : `admin_groupe/screens/admin_audit_screen.dart` (3257 l.) + `admin_audit_provider.dart` (944 l.) ET `user/screens/staff_audit_screen.dart` (329 l., version « lite ») + `staff_audit_provider.dart` — **les 4 supprimés**. Applique la règle CLAUDE.md « pas de duplication par espace » (précédent = Communication).

**Le SEUL point de divergence = `AuditScope`** (`providers/audit_scope.dart`) :
- `AuditScope.group(groupId)` → filtre `group_id`, `showSchoolDimension=true` ;
- `AuditScope.school(schoolId)` → filtre `school_id`, `showSchoolDimension=false`.
- `auditScopeProvider` (plain Provider) **dérive la portée de l'auth** : role super_admin/admin_groupe → groupe ; tout autre (direction) → école. Pas d'override, portée non ambiguë (un compte = un rôle). Renvoie `null` si tenant non résolu → écran « consultation indisponible ».

`showSchoolDimension` pilote tout le reste : filtre déroulant « École » (auto-masqué car `facets.schools` vide en école), classement « Top écoles » (charts), colonne École (non hydratée → chip absente), bouton « Filtrer cette école » (modal détail), colonne École de l'export CSV.

**Audit = exception ONLINE assumée** pour le staff aussi (donnée de gouvernance, RLS `school_id = auth_school_id()`) → réutiliser l'écran admin ne viole PAS la règle PowerSync. `audit_logs` porte `group_id` ET `school_id`.

**Découpage ≤500 l.** : providers = `audit_scope.dart` / `audit_models.dart` (modèles+alertes) / `audit_data.dart` (facets/timeline/page/export/realtime, `.eq(scope.column, scope.id)`). Écran = `audit_screen.dart` (KPIs + 3 onglets) + `widgets/` : audit_kpi, audit_filter_bar, audit_activity_tab, audit_row, audit_charts_tab, audit_alerts_tab, audit_detail_dialog, audit_export_dialog (+ audit_export_parts), audit_date_range_dialog.

**Routes** (`app_router.dart`) : `/admin/audit` ET `/user/journal-audit` → même `AuditScreen`, importé `as shared_audit` (collision de nom avec `super_admin/screens/audit_screen.dart` qui est un `AuditScreen` **distinct**, plateforme-wide, NON touché). Gating direction inchangé (sidebar + RLS).

**2026-07-25 — Plancher de visibilité par niveau** (« on voit son niveau et en dessous, jamais au-dessus ») ajouté à `AuditScope`. **Cause racine** : le trigger `log_edt_audit` (mig 0022) estampille `school_id`/`group_id` depuis la LIGNE modifiée (`NEW.school_id`), pas depuis l'acteur → une action super_admin/admin_groupe sur une ligne d'école porte le `school_id` de l'école et **remontait dans l'audit école**. Fix = `AuditScope.hiddenActorRoles` (fonction pure `hiddenActorRolesForViewer(role)`) : super_admin ne masque rien ; admin_groupe masque `super_admin` ; **tout** rôle école masque `super_admin`+`admin_groupe` (⚠️ PAS de sous-hiérarchie intra-école — décision user : tout le staff voit toutes les actions de son école). Appliqué EN DUR (non décochable) via `_applyScopeFloor()` aux 6 sites de lecture de `audit_data.dart` : `.or('user_role.is.null,user_role.not.in.(…)')` (NULL role reste visible — jamais masquer du travail légitime). Realtime inchangé (refetch ré-applique le plancher). `test/audit_scope_test.dart` = 12 tests. analyze 0, 386 tests. ⚠️ non commité, non rebuild/réinstallé.

Test garde-fou : `test/audit_scope_test.dart` (12) sur le contrat de divergence + plancher. ⚠️ **Pas encore GUI-vérifié dans l'app réelle** (deux logins requis : admin_groupe + direction). Voir [[staff-personnel-annuaire]], [[communication-unification-plan]].
