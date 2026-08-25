---
name: sync-failure-journal
description: "Journal local durable des échecs de synchro PowerSync — table local-only sync_failures + bannière shell staff acquittable ; rend la perte silencieuse VISIBLE (défense en profondeur)"
metadata:
  node_type: memory
  type: project
  originSessionId: 012e8fef-2c27-4d9d-a848-ba9c0832077f
---

✅ **2026-07-04 (branche `refonte/sidebar-shell`, non commité, analyze 0 + `flutter build linux --debug` OK)** — Construit la **défense en profondeur** contre la perte silencieuse à la synchro (cf [[inscription-validation-effectif-a-verifier]]). Avant : une transaction rejetée définitivement (codes 22xxx/23xxx/42501) était abandonnée et seulement loggée + un `ValueNotifier lastFatalUploadError` que personne ne consommait.

**4 pièces livrées :**
1. **Table local-only `sync_failures`** dans `powersync_schema.dart` (`Table.localOnly(...)` : `at`, `code`, `message`, `ops` JSON, `summary`, `acknowledged`). **Ne remonte JAMAIS au serveur** → aucun impact sync-rules/prod, zéro migration/déploiement.
2. **Connecteur** (`powersync_connector.dart`) : dans la branche fatale de `uploadData`, en plus du log/notifier, `database.execute(INSERT INTO sync_failures ...)` avec `const Uuid().v4()` (convention Dart-side, PAS le `uuid()` SQL). `summary` humain via map `_tableHumanLabel` (students/class_enrollments/student_tutors → « Inscription d'élève », etc., dédupliqué). Insert protégé par try/catch (ne casse jamais l'upload).
3. **Provider** `sync_failures_provider.dart` : `syncFailuresProvider` = `db.watch(... WHERE acknowledged = 0 ORDER BY at DESC)` ; helpers `acknowledgeSyncFailure(id)` / `acknowledgeAllSyncFailures()`.
4. **Bannière shell** `sync_failure_banner.dart` (`SyncFailureBanner`) : bandeau rouge sous `ReadOnlyYearBanner`, **gaté `isStaff`** dans `app_shell.dart` (super_admin/admin_groupe online-direct = jamais concernés). « N données n'ont pas pu être synchronisées » + [Voir] → dialogue listant chaque échec (libellé + date `le JJ/MM à HH:MM`) + [J'ai compris] (acquitte tout) / ✓ par ligne.

**Choix clé (durable vs éphémère)** : table local-only choisie car la synchro se fait en arrière-plan (parfois hors de l'écran concerné, ou au lancement suivant) — un `ValueNotifier` ne garde que le dernier échec et meurt au redémarrage. Un échec doit survivre jusqu'à ce qu'un humain l'ait **vu et acquitté**. **Pas de rejeu** (une violation de contrainte ne se rejoue pas → message actionnable « veuillez ressaisir »).

✅ **2026-07-04 — COMMITÉ + POUSSÉ** (`535c397` sur `refonte/sidebar-shell`, `flutter analyze` 0 issue). Correction au passage : les clés de `_tableHumanLabel` étaient fausses (`school_expenses`/`staff_leaves`/`attendance`) → réalignées sur les vrais noms de tables locales (`expenses`, `leave_requests`, `attendance_records`+`attendance_entries`) ; sinon le résumé retombait sur le nom technique brut. `uuid ^4.5.1` confirmé dans pubspec.

⚠️ **Toujours pas vérifié GUI le chemin de rejet réel** — le forcer = session staff (PIN agent) + écriture violant une contrainte, impraticable via l'UI polie (le garde-fou DOB bloque le cas simple), et un INSERT externe dans le sqlite ne déclenche pas le `db.watch` in-process. Câblage relu OK (bannière gatée `isStaff` sous `ReadOnlyYearBanner`, insert dans la branche fatale de `uploadData`). ⚠️ Le `refonte/sidebar-shell` a déjà été mergé dans `main` via PR #1 — ce commit est AU-DESSUS, il faudra une nouvelle PR pour l'amener sur `main`. À capturer GUI en même temps que card glass + garde DOB au prochain passage sur un compte école.
