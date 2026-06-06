# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

**E-PILOTE CONGO v3.0** — SaaS national de gestion scolaire offline-first pour la République du Congo (commande MEPSA + METP). Multi-tenant, plus de 1000 écoles publiques et privées visées.

## Layout du dépôt (monorepo)

| Dossier | Rôle |
|---|---|
| `epilote/` | **L'application Flutter** (tout le code Dart). C'est ici que se passe 99 % du dev. |
| `powersync/` | Config PowerSync auto-hébergé : `docker-compose.yml`, `config/sync-rules.yaml` (règles de synchro), `config/powersync.yaml`, `supabase-setup.sql`. |
| `database/` | `schema.sql` — ⚠️ **PÉRIMÉ**, ne pas s'y fier. |
| `docs/` | `CONTEXTE.md` / `ANALYSE.md` — `CONTEXTE.md` est **PÉRIMÉ** (parle de 55 tables, rôle `utilisateur`). `ANALYSE.md` (cahier des charges) reste globalement fiable. |
| `mockups/` | Maquettes. |

Le dépôt git racine est `/home/melack/E-PILOTE` → remote GitHub privé `E-PILOTE/PILOTE`. `.env` (powersync) et `.claude/` sont gitignorés.

## Commandes (toutes depuis `epilote/`)

```bash
cd epilote
flutter pub get
flutter analyze                         # doit rester à 0 issue
dart fix --apply                        # corrige automatiquement les lints
flutter run -d linux                    # lancer en dev (desktop Linux)
flutter build linux --debug             # vérifier la compilation avant de lancer
flutter test                            # tous les tests
flutter test test/admin_geo_test.dart   # un seul fichier de test
flutter test --name "nom du test"       # un seul test par nom
dart run build_runner build --delete-conflicting-outputs   # codegen Riverpod
```

Le binaire `dart`/`flutter` est dans `/home/melack/flutter/bin/`.

## Architecture — LA règle centrale (non négociable)

L'app a **deux chemins de données distincts selon le rôle**. C'est le concept structurant ; il traverse `powersync_service.dart`, `sync-rules.yaml` et chaque provider :

| Rôle | Mode | API à utiliser |
|---|---|---|
| `super_admin` | online, Supabase direct | `supabase.from(...)` |
| `admin_groupe` | online, Supabase direct (KPIs temps réel) | `supabase.from(...)` |
| **Personnel scolaire** (tous les autres rôles) | **offline-first PowerSync** | `db.watch()` / `db.execute()` **UNIQUEMENT** — jamais `supabase.from()` |

« Personnel scolaire » = tout rôle SAUF `super_admin` et `admin_groupe`. La fonction de référence est `_isStaffRole(role)` dans `lib/services/powersync/powersync_service.dart` :
```dart
bool _isStaffRole(String? role) =>
    role != null && role != 'super_admin' && role != 'admin_groupe';
```
C'est `_isStaffRole` qui décide d'appeler `db.connect()` (= activer la synchro offline). Les écritures locales remontent vers Supabase via `SupabasePowerSyncConnector.uploadData` (upsert/patch/delete).

### Couche PowerSync (offline)
- Schéma SQLite local : `lib/services/powersync/powersync_schema.dart` (déclare les tables synchronisables).
- Connecteur JWT + upload : `lib/services/powersync/powersync_connector.dart`.
- Les **sync-rules** (`powersync/config/sync-rules.yaml`) décident *quelles lignes* arrivent sur chaque appareil. Elles se déploient via le **dashboard PowerSync Cloud** après modif — un changement ici peut casser la synchro en prod, ne jamais l'éditer à l'aveugle.

## Structure du code Flutter (`epilote/lib/`)

- `main.dart` — init Supabase → `initPowerSync()` → `ProviderScope`.
- `core/` — `router/app_router.dart` (GoRouter avec `redirect` gardé par rôle ; `_dashboardForRole`), `constants/` (routes, app_constants), `theme/`, `widgets/` (dont `app_shell.dart` = sidebar), `extensions/`, `utils/`.
- `data/models/` — modèles immuables (ex. `ProfileModel`).
- `features/<domaine>/` — organisation **feature-first** : sous-dossiers `screens/`, `providers/` (Riverpod), `services/`, `widgets/`. Domaines : `auth`, `super_admin`, `admin_groupe`, `students`, `classes`, `structure`, `navigation`, `user`.
- `services/` — `supabase_service.dart` + `powersync/`.

Navigation : ajouter un écran = créer screen + provider, déclarer la route dans `core/router/app_router.dart` et la constante dans `core/constants/routes.dart`.

## Pièges spécifiques au projet

- **Vérifier la base LIVE avant tout** : `schema.sql` et `docs/CONTEXTE.md` sont périmés. Interroger Supabase via le **MCP Supabase** (`list_tables`, `execute_sql`) ou `information_schema.columns`. État réel ≈ 66 tables / 49 migrations.
- **L'enum `user_role` n'a PAS de valeur `'utilisateur'`.** Le rôle EST le métier (`enseignant`, `secretaire`, `cpe`, `comptable`, `surveillant`, `directeur`, `proviseur`, `parent`, `eleve`, `infirmier`, `responsable_cantine`, + `super_admin`, `admin_groupe`). ⚠️ La constante `AppConstants.roleUtilisateur = 'utilisateur'` existe encore dans `app_constants.dart` : c'est un **piège dormant** — ne jamais l'utiliser pour un test de rôle (utiliser `_isStaffRole`). Un bug historique (`role == 'utilisateur'`) avait tué la synchro du personnel — résolu le 2026-06-06.
- `inFilter()` (pas `in_()`) — postgrest 2.7.0. `.count(CountOption.exact)`. `CardThemeData` (pas `CardTheme`). `.withValues(alpha:)` (pas `withOpacity`).
- `student_tutors` (pas `guardians`) ; `announcements.is_published` (pas `status`).
- `profiles` n'a PAS de colonne `email` (l'email vit dans `auth.users` → passer par les RPC SECURITY DEFINER `get_group_users` / `get_platform_admins`). Résoudre un acteur d'audit via `profiles(id, first_name, last_name)`.
- **Syncfusion `BarSeries`** : `primaryXAxis: CategoryAxis` ← `xValueMapper` (String) ; `primaryYAxis: NumericAxis` ← `yValueMapper` (double). Ne jamais inverser (crash `String is not a subtype of num`).
- `service_role` JAMAIS dans Flutter (Edge Functions uniquement). Clé anon dans `lib/core/constants/supabase_constants.dart`.

## Supabase

- Project ID `wqpdamlnrwgozfvzjjpo`, region `eu-central-2`, PG 17.
- Helpers RLS en base : `is_super_admin()`, `auth_group_id()`, `auth_school_id()`, `check_quota()`, `is_admin_groupe()`.
- Mentions (alignées sur `get_mention()` en base) : Excellent ≥18, Très bien ≥16, Bien ≥14, Assez bien ≥12, Passable ≥10. Devise XAF (FCFA).

## État d'avancement

- **super_admin** : 19 pages ✅ complètes (routes câblées).
- **admin_groupe** : 10 écrans ✅ complets (dashboard KPI+carte, écoles, utilisateurs, profils d'accès, rapports PDF, abonnement, audit, paramètres, modules).
- **Personnel scolaire** : ⚠️ **espace à construire** — routes `/user/*` sont des placeholders dans `app_router.dart`, SAUF `/user/inscriptions` (réellement implémenté). C'est le gros du roadmap restant (Phases 1-8 : structure → acteurs → quotidien → évaluation → finance → vie scolaire → communication → documents). La sidebar personnel (`app_shell.dart`) est encore en dur et n'utilise pas encore la nav dynamique (`activeModulesProvider`).

## Mémoire projet

Contexte détaillé et décisions dans `/home/melack/.claude/projects/-home-melack-E-PILOTE/memory/` (index : `MEMORY.md`). Lire en priorité avant une nouvelle session.
