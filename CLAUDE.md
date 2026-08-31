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

**Build Linux** : `flutter_secure_storage` (coffre licence) exige `libsecret-1-dev`
(`sudo apt-get install -y libsecret-1-dev`) — sinon `flutter build linux` échoue à la
génération CMake. À prévoir en CI.

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
- `licensing/` — **module transverse** (îlot hexagonal : `domain/`/`application/`/`infrastructure/`/`presentation/`) du système de licence offline-first. Enforcement **dormant** tant que `licensePinnedKeysProvider` est vide. Décisions gelées : `docs/adr/ADR-licence.md` ; org. code : `docs/ABONNEMENT_ARCHITECTURE_LOGICIELLE.md`. Ne JAMAIS gater la synchro PowerSync sur la licence (C4).

Navigation : ajouter un écran = créer screen + provider, déclarer la route dans `core/router/app_router.dart` et la constante dans `core/constants/routes.dart`.

## Conventions de code (RÈGLE GLOBALE)

- **Taille de fichier : cible ≤ 500 lignes par fichier Dart** (alerte à 400). Au-delà, **découper par responsabilité** :
  - widgets → `widgets/` (un gros widget = un fichier), sections d'écran → sous-widgets,
  - logique d'état → `providers/`, modèles → `data/models/` ou `models/`.
  - Ne jamais découper arbitrairement au milieu d'un widget : couper le long des coutures de cohésion.
- Appliquer **systématiquement au code neuf** ; refondre les fichiers existants > 500 lignes **quand on les touche** (ex. factorisation). Plusieurs écrans hérités dépassent (super_admin : annonces ~1900, messagerie ~1150, etc.) → dette à résorber au fil des modifications.
- Fonctionnalités transverses (communication : annonces/messagerie/notifications/événements) = **module partagé `features/communication/` scope-aware** (périmètre déduit du rôle), réutilisé par super_admin / admin_groupe / école ; **pas de duplication par espace**.

## Pièges spécifiques au projet

- **Vérifier la base LIVE avant tout** : `schema.sql` et `docs/CONTEXTE.md` sont périmés. Interroger Supabase via le **MCP Supabase** (`list_tables`, `execute_sql`) ou `information_schema.columns`. État réel ≈ 66 tables / 49 migrations.
- **L'enum `user_role` n'a PAS de valeur `'utilisateur'`.** Le rôle EST le métier (`enseignant`, `secretaire`, `cpe`, `comptable`, `surveillant`, `directeur`, `proviseur`, `parent`, `eleve`, `infirmier`, `responsable_cantine`, + `super_admin`, `admin_groupe`). ⚠️ La constante `AppConstants.roleUtilisateur = 'utilisateur'` existe encore dans `app_constants.dart` : c'est un **piège dormant** — ne jamais l'utiliser pour un test de rôle (utiliser `_isStaffRole`). Un bug historique (`role == 'utilisateur'`) avait tué la synchro du personnel — résolu le 2026-06-06.
- `inFilter()` (pas `in_()`) — postgrest 2.7.0. `.count(CountOption.exact)`. `CardThemeData` (pas `CardTheme`). `.withValues(alpha:)` (pas `withOpacity`).
- `student_tutors` (pas `guardians`) ; `announcements.is_published` (pas `status`).
- `profiles` n'a PAS de colonne `email` (l'email vit dans `auth.users` → passer par les RPC SECURITY DEFINER `get_group_users` / `get_platform_admins`). Résoudre un acteur d'audit via `profiles(id, first_name, last_name)`.
- **Syncfusion `BarSeries`** : `primaryXAxis: CategoryAxis` ← `xValueMapper` (String) ; `primaryYAxis: NumericAxis` ← `yValueMapper` (double). Ne jamais inverser (crash `String is not a subtype of num`).
- **`school_type_enum` ≠ `group_type`** : deux énumérations distinctes aux MÊMES libellés (`public` | `prive`) — l'une sur `school_groups.group_type`, l'autre sur `schools.school_type`. Les confondre ne lève `42883` qu'à l'exécution de la comparaison.
- **Le prix d'un groupe suit son NOMBRE D'ÉCOLES** (mig 0159) : `plan_price_xaf(plan, n)` en base, miroir `lib/core/utils/tarif_ecoles.dart`. Ne JAMAIS afficher `price_xaf` seul — c'est la base d'UNE école. Ne jamais calculer un MRR par `tarif × abonnés`.
- **`REVOKE EXECUTE ... FROM anon, authenticated` ne fait rien** si `PUBLIC` détient encore le droit (grant par défaut de PostgreSQL). Retirer `FROM PUBLIC`, puis re-`GRANT` aux rôles qui en ont besoin (une fonction appelée dans une politique RLS doit rester exécutable par `authenticated`).
- `service_role` JAMAIS dans Flutter (Edge Functions uniquement). Clé anon dans `lib/core/constants/supabase_constants.dart`.

## Supabase

- Project ID `wqpdamlnrwgozfvzjjpo`, region `eu-central-2`, PG 17.
- Helpers RLS en base : `is_super_admin()`, `auth_group_id()`, `auth_school_id()`, `check_quota()`, `is_admin_groupe()`.
- **Mentions — source unique : `lib/core/utils/mention.dart`** (`mentionFor`), tenue identique à `get_mention()` en base (migration 0059). Excellent ≥18, Très Bien ≥16, Bien ≥14, Assez Bien ≥12, Passable ≥10, Insuffisant <10 ; barre de réussite 10/20. ⚠️ Ce barème avait dérivé de 2 points côté bulletins (8/20 ressortait « Passable ») — ne jamais en recopier une variante locale : toute modification touche le Dart **et** le SQL. Devise XAF (FCFA).

## État d'avancement

> ⚠️ Cette section a menti pendant des mois : elle annonçait l'espace personnel
> « à construire » alors qu'il était livré. Vérifié dans le code le 2026-08-17.
> **Ne jamais conclure sur l'avancement sans ouvrir `app_router.dart`** —
> compter les `_PlaceholderScreen` / `StaffComingSoonScreen` prend dix secondes.

- **super_admin** : 19 pages ✅ complètes (routes câblées).
- **admin_groupe** : 12 écrans ✅ (les 10 + Palmarès et Élèves du réseau).
- **Personnel scolaire** : ✅ **espace livré**. Les ~48 routes `/user/*` pointent
  sur de vrais écrans — Scolarité, Structure, EDT, Évaluation, Passage, Examens,
  Vie scolaire, Finance, RH, Communication, Cahier de textes. Il ne reste que
  **un seul inachevé** dans tout l'espace :
  | Route | État |
  |---|---|
  | `/user/espace-parent` | `StaffComingSoonScreen` — le rôle `parent` n'a pas son espace |
  | ~~`/user/rapports`~~ | ✅ livré le 2026-08-17 — états des effectifs, du recouvrement et du personnel, PDF signables |
  | ~~`/user/eleves/:id`~~ | ✅ route morte neutralisée en redirection vers `/user/eleves` |

  ⚠️ **`/user/rapports` est une page de DIRECTION** : elle lit l'école entière,
  hors du périmètre de classes de l'agent. Deux verrous, tous deux nécessaires —
  la sidebar (`_staffSections`) et le `redirect` du routeur, comme le Calendrier
  scolaire.

  La sidebar personnel n'est PAS en dur : `_staffSections` (`core/widgets/app_shell/nav_config.dart`)
  la construit depuis `modulesGroupedByCategoryProvider` × `myPermissionsProvider`,
  et distingue « en cours de synchro » de « aucun module accordé ».

## Mémoire projet

Contexte détaillé et décisions dans `/home/melack/.claude/projects/-home-melack-E-PILOTE/memory/` (index : `MEMORY.md`). Lire en priorité avant une nouvelle session.
