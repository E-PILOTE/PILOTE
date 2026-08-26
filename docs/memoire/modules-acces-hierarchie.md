---
name: modules-acces-hierarchie
description: Hiérarchie des modules et qui accède aux pages — cascade à 4 verrous + gotcha providers dynamiques non câblés côté personnel
metadata: 
  node_type: memory
  type: project
  originSessionId: b797fb41-8337-48f0-932b-03b0f50da9f1
---

**Qui accède aux PAGES des modules : le personnel scolaire UNIQUEMENT** (11 rôles ≠ super_admin/admin_groupe), espace `/user/*`, offline-first PowerSync. super_admin **définit** le catalogue ; admin_groupe **attribue/pilote** ; ni l'un ni l'autre n'ouvre une page fonctionnelle.

**Why:** logique métier plateforme — modules = catalogue plateforme consommé sur le terrain, parfois sans internet.

**How to apply — la cascade d'accès à 4 verrous (toute nouvelle page module doit la respecter) :**
1. **Rôle** (routeur `app_router.dart:160-175`) → répartit dans `/user/*` ; super_admin/admin_groupe y sont bloqués (PowerSync non connecté pour eux).
2. **Plan** (`school_groups.plan_id → plan_modules`) → quels modules existent pour le groupe. Gratuit 9 · Premium 25 · Pro 37 · Institutionnel 41. Calcul 100% SQLite offline.
3. **Profil d'accès** (`profiles.access_profile_id → profile_permissions`) → quels modules CE membre voit, avec **10 booléens** `can_read/create/update/delete/export/import/validate/approve/manage/write`.
4. **Périmètre** (`profile_permissions.data_scope` enum = `own_classes` | `own_school`) + RLS serveur `auth_school_id()`.

**Catalogue (base live, super_admin)** : 8 catégories / 41 modules (40 actifs) — `module_categories` → `modules` → `plan_modules` (offre↔module) → `profile_permissions` (profil↔module, niveau groupe). Catégories : SCOLARISATION(8, dont `inscriptions`), PÉDAGOGIE(10), VIE SCOLAIRE(4), FINANCE(7), RH(4), COMMUNICATION(5), RESSOURCES(1), IA(2).

**⚠️ GOTCHA — la consommation côté personnel n'est PAS câblée (état 2026-06-04) :**
- Sidebar du personnel = **encore en dur** (`app_shell.dart:108-120`, branche `default:`), ne consomme PAS `modulesGroupedByCategoryProvider`.
- `activeModulesProvider` / `modulesGroupedByCategoryProvider` / `hasModuleAccessProvider` (dans `module_navigation_provider.dart`) sont **écrits mais appelés nulle part** = code mort prêt à brancher (vérifié par grep).
- Guard routeur ne contrôle que l'**espace**, pas l'accès module-par-module (verrous 3-4 pas appliqués au routage `/user/*`).
- **Une seule page `/user/*` réelle** : `/user/inscriptions` (module Inscription développé). Le reste = `_placeholder`.
- Côté admin_groupe en revanche, la sidebar « Modules du groupe » EST dynamique (`adminNavModulesProvider`).
- Les 3 tables catalogue SONT dans `powersync_schema.dart:11,20,33` (donc synchro offline OK — l'ancienne note « sync-rules à compléter » est périmée).

→ Chantier « Phase 1 offline-first » = brancher sidebar dynamique depuis le plan + filtrage `profile_permissions` + garde `hasModuleAccessProvider` sur `/user/*`.

**✅ SOCLE CONTRÔLE D'ACCÈS CÂBLÉ (2026-06-07)** — la cascade 4 verrous est désormais appliquée offline (le GOTCHA ci-dessus est résolu). 0 lint, build linux ✓.
- **Verrous 3-4 maintenant synchronisables** : `access_profiles` + `profile_permissions` ajoutés à `powersync_schema.dart` + 2 streams dans `sync-rules.yaml` (scopés au seul profil du membre via `profiles.access_profile_id`). ⚠️ **Le profil ne descend QUE si on REDÉPLOIE les sync-rules dans le dashboard PowerSync Cloud** — tant que non fait, la sidebar staff n'affiche que Dashboard + COMMUNICATION + Paramètres (dégradation gracieuse, pas de crash).
- **Providers** : `features/navigation/providers/permissions_provider.dart` = `ModulePermission` (10 booléens + data_scope) · `myPermissionsProvider` (StreamProvider Map<slug,perm>, vide si `access_profile_id` null) · `canProvider((slug,action))` · `myStaffIdProvider` · `scopedClassIdsProvider` (own_classes→teacher_subjects, own_school→null=toute l'école).
- **`module_routes.dart`** = source unique slug↔route↔icône (Material) pour les 28 modules ; `moduleRoute(slug)` (route dédiée sinon `/user/m/:slug` placeholder) + `moduleSlugForLocation(loc)` (pour le garde).
- **Sidebar dynamique** (`app_shell.dart`) : branche `default:` codée en dur REMPLACÉE par `_staffNavItems(ref,profile)` = `modulesGroupedByCategoryProvider` (verrou 2) ∩ `myPermissions.can_read` (verrou 3), groupé par catégorie ; COMMUNICATION reste native (garde-fous élève/parent conservés).
- **Garde de routes** (`app_router.dart` redirect) : route `/user/*` → `moduleSlugForLocation` → si `!canRead` → redirige `userDashboard` (laisse passer pendant le chargement). Routes natives/dashboard/paramètres non gardées.
- **Kit réutilisable** (`features/navigation/widgets/module_scaffold.dart`) : `ModuleScaffold(slug,title,child)` (gate can_read + états « accès refusé »/« aucun profil assigné ») · `PermissionGate(slug,action,child)` (masque boutons) · `runModuleWrite()` (remonte erreurs ; rappel : drops sync 23514/23505/42501 = pré-valider AVANT écriture).
- **3 modules rebranchés** : Élèves/Classes/Inscriptions via `ModuleScaffold` + boutons gatés `PermissionGate`.
- **1ʳᵉ tranche métier = Matières** (`features/structure/{providers/subjects_provider,screens/subjects_screen}` + `data/models/subject_model.dart`) : CRUD offline gaté, coefficient, slug anti-collision pré-validé. ⚠️ **Drift corrigé** : `powersync_schema` `subjects` avait un `code` fantôme + manquait `slug`(NOT NULL live)/`level_id`/`display_order`/timestamps → réécrit. ⚠️ **Le catalogue n'a PAS de module pour années/trimestres/séquences** (calendrier scolaire) → tranche calendrier = chantier suivant (nécessite soit un nouveau module catalogue super_admin, soit une zone direction fixe).
- **Migration `0003_staff_profile_link.sql`** (staff_members.profile_id, pour own_classes) écrite mais **PAS appliquée** (DDL bloqué par le classifier auto-mode malgré l'allowedPrompt) → à appliquer par l'utilisateur (pooler ou SQL Editor) + ajouter au schema (déjà fait) ; sans elle own_classes = 0 classe (sûr).

## 🩸 Verrou 4 — CHAQUE écran applique le périmètre de SON module (2026-08-25/27)

**Seize écrans lisaient `classesProvider`** — donc le `data_scope` du module
`classes`, pas le leur. Un commentaire l'affirmait même noir sur blanc :
« `classesProvider` applique déjà le périmètre ». Il l'applique. Ce n'est pas
le bon.

Conséquence : le `data_scope` posé sur **Paiements, Notes, Bulletins, Conseils,
Présences, Cantine, Orientation, Emploi du temps, Cahier de textes, Élèves,
Inscriptions** n'avait **AUCUN effet**. L'administration affichait un cadenas
fermé sur rien — le pire des défauts, celui qui rend compte d'un succès.

⚠️ Aucune fuite mesurée en production : toutes les divergences tombent sur
`own_school`, où le repli ouvre de toute façon. Mais **Vie scolaire n'a même
pas le module `classes`** : son périmètre venait d'un module que ce profil ne
détient pas.

### La forme juste

`classesForModuleProvider(slug)` (`classes/providers/class_provider.dart`).
`classesProvider` n'en est plus qu'un relais pour le module `classes`.

⚠️ `evaluationOverviewProvider` est partagé par TROIS écrans de slugs
différents (notes, bulletins, conseils) : sa clé porte le slug de l'appelant.
Un aperçu partagé ne peut pas avoir un périmètre unique.

**Trois usages de `classesProvider` subsistent, commentés sur place** : l'écran
du module `classes`, et les deux blocs du tableau de bord d'accueil — qui n'est
pas un module et n'a donc pas de `data_scope` propre.

### ⚠️ Le piège du passage à une FAMILLE

Deux sites devenaient `ref.read(famille(...)).valueOrNull` — qui rend `null`
quand rien n'écoute (le défaut B du même jour). Un garde existant a mordu sur
ma propre correction. Forme obligatoire : `await ref.read(p.future)`.

Garde : `test/perimetre_par_module_test.dart` (ex-`perimetre_finance_test`).

Voir [[role-admin-groupe]], [[inscription-module-logique]], [[powersync-status]], [[catalogue-modules-v2]].
