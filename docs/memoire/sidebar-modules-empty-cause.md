---
name: sidebar-modules-empty-cause
description: "Pourquoi les modules n'apparaissent pas dans la sidebar du personnel — backend SAIN, cause = comptes sans profil d'accès"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1e049c31-2175-4605-89ef-5c434794a1b6
---

Symptôme (2026-06-08) : « les modules n'apparaissent pas dans la sidebar » de l'espace personnel école, espace « très basique ».

## ⚠️ CORRECTION : ma 1ʳᵉ hypothèse (sync-rules non déployées) était FAUSSE
Vérifié via le **CLI PowerSync** (`npx powersync`, token PAT fourni par l'utilisateur, instance **Development** `6a185941234fa2bf51a66757`, project `6a18593de63d960007e81e7b`, org `6a1858e9ec3f4400078f635f`) :
- `pull instance` → le config **déployé** contient DÉJÀ `profile_permissions` + `access_profiles` ; **diff déployé↔local = vide** (identiques). Le `git diff HEAD` montrait +28 lignes seulement parce que le fichier local diverge du dernier *commit git*, PAS du Cloud.
- `fetch status` → Supabase **connected**, *initial replication done: true*, lag ~56 bytes ; `profile_permissions`/`access_profiles`/`plan_modules`/`modules`/`module_categories` **tous répliqués** (`used_for_replication: yes`).
- App Flutter pointe bien vers Development (`powersync_connector.dart:13`). SDK `powersync 1.18.0` compatible edition 3 / `auto_subscribe`.

**→ Backend 100 % sain, rien à déployer.** (Instances : Development provisionnée ✓ ; Production `6a185943…` NON provisionnée.)

## VRAIE cause de la sidebar vide
1. ~~**~95 % des comptes staff n'ont PAS d'`access_profile_id`**~~ → **RÉSOLU 2026-06-08** : tous les 88 comptes staff du groupe Kinkala ont reçu le profil correspondant à leur rôle (UPDATE SQL `access_profile_id` par `role_type`, `cpe`→profil Surveillant faute de profil cpe dédié). Vérif : 0 `sans_profil`. Désormais **n'importe quel compte voit ses modules**. (En prod réelle, c'est l'admin_groupe qui attribue les profils via **Profils d'accès**/**Utilisateurs**.)
2. **Fenêtre de 1ʳᵉ synchro** : avant, la sidebar collapsait « en chargement » et « vide » → paraissait cassée.

## Accès déploiement PowerSync (pour plus tard)
Le CLI peut déployer : `PS_ADMIN_TOKEN=<pat> npx powersync deploy sync-config --instance-id 6a185941234fa2bf51a66757 --project-id 6a18593de63d960007e81e7b --sync-config-file-path config/sync-rules.yaml` (depuis `powersync/`). Le PAT est fourni à la demande par l'utilisateur (login interactif `npx powersync login` OU env `PS_ADMIN_TOKEN`). ⚠️ `pull instance` écrit `service.yaml` qui contient le **mot de passe Postgres** → supprimer après usage (ne pas committer). Voir [[powersync-status]].

## Corrections code livrées (2026-06-08, 0 lint, build ✓) — toujours valables
- `app_shell.dart` : sidebar distingue « Synchronisation… » (spinner) de « Aucun module attribué » (plus de zone vide muette) via `_NavItem.info(loading:)`.
- `user_dashboard_screen.dart` : « Accès rapide » → `_SyncingModulesCard` pendant la synchro, `_NoModulesCard` si réellement vide.
- `features/navigation/widgets/module_coming_soon.dart` (NEW) : `ModuleComingSoonScreen` remplace le `_PlaceholderScreen` brut. Reste DANS l'AppShell via `ModuleScaffold` (sidebar/en-tête/sélecteur d'année + garde verrou-3), kit `admin_ui`, icône+nom+badge « En préparation »+blurb+capacités du profil. Câblé `app_router.dart` via `_comingSoon()` + `/user/m/:slug`. N'a PAS touché la logique métier des modules.
