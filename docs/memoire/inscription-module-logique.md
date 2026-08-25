---
name: inscription-module-logique
description: Module Inscription (1ère fonctionnalité) — logique métier offline-first + pièges de perte silencieuse à la sync
metadata: 
  node_type: memory
  type: project
  originSessionId: aacc8667-eedb-4396-9d75-f8ea5eb7d79c
---

Première fonctionnalité développée = **module Inscription** (espace personnel `utilisateur`, offline-first PowerSync). Route `/user/inscriptions` (+ `/user/eleves`, `/user/classes`).

**Why:** décision utilisateur (2026-05-31), c'est le premier module métier après la console super_admin.

**Inscription = 3 écritures** (pas une table) : `students` (dossier, matricule unique groupe) + `student_tutors` (parents) + `class_enrollments` (élève↔classe↔année, `UNIQUE(student_id, academic_year_id)`). Prérequis : `schools`, `academic_years` (is_current), `classes`. Code offline déjà amorcé : `class_provider.dart` (`enrollStudent`/`withdrawStudent` via `db.execute`).

**How to apply — pièges vérifiés (perte SILENCIEUSE de données à la sync) :**
- Le connecteur `powersync_connector.dart:7,79` traite `^22...$`, `^23...$`, `42501` comme **fatals** → `transaction.complete()` = écriture **jetée sans message**.
- Trigger live `trg_enforce_student_quota` (BEFORE INSERT students) lève `ERRCODE='check_violation'` = **23514** → quota plein hors-ligne = élève **perdu** à la sync. Idem `trg_enforce_staff_quota`.
- `UNIQUE(group_id, matricule)` + `UNIQUE(student_id, academic_year_id)` → collision offline = **23505** = drop silencieux. Le matricule est généré CLIENT (aucun trigger serveur) → prévoir schéma anti-collision.
- `RLS WITH CHECK` actif → toujours estampiller `group_id`+`school_id` depuis le profil sur chaque insert, sinon **42501** = drop.
- Écritures offline limitées aux colonnes de `powersync_schema.dart` (la table locale `students` n'a PAS `blood_group`/`allergies`/`user_id`).
- `student_model.dart` mappe des colonnes FANTÔMES `place_of_birth`/`father_name`/`mother_name` (inexistantes en DB) → à retirer ; parents = `student_tutors`.

Voir [[role-admin-groupe]], [[verifier-base-live-vs-schema]].
