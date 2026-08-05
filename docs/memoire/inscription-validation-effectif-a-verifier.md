---
name: inscription-validation-effectif-a-verifier
description: "✅ RÉSOLU 2026-07-04 : inscription 'perdue' à la sync = date de naissance NULL vs colonne students NOT NULL (perte silencieuse) ; date rendue obligatoire dans l'assistant"
metadata: 
  node_type: memory
  type: project
  originSessionId: 012e8fef-2c27-4d9d-a848-ba9c0832077f
---

✅ **2026-07-04 — CAUSE RACINE TROUVÉE + CORRIGÉE.** Symptôme observé en test GUI : une inscription créée puis « validée » (Proviseur, Collège Public de Kinkala) n'apparaissait pas dans l'effectif Élèves (61, pas 62) et disparaissait du pipeline. Ce n'était **pas** un bug de validation.

**Cause = perte silencieuse à la synchro** (cf [[inscription-module-logique]]). Preuve dans les logs PowerSync de l'app :
```
⚠️ PowerSync — transaction ABANDONNÉE (code 23502). Écritures locales perdues :
   put students#… null value in column "date_of_birth" violates not-null constraint
⚠️ … (23503) student_tutors … violates FK student_tutors_student_id_fkey
⚠️ … (23503) class_enrollments … violates FK class_enrollments_student_id_fkey
```
L'élève avait été créé **sans date de naissance**. Le SQLite local (PowerSync, permissif) accepte → UI « Inscription créée » ✓. À l'upload, le serveur rejette l'INSERT `students` (`date_of_birth` **NOT NULL**, 23502) → **transaction abandonnée, lignes locales supprimées** → tuteur + inscription tombent en cascade (FK vers un élève inexistant, 23503). D'où disparition totale, effectif inchangé, **aucun** message utilisateur.

**Correctif appliqué** (`add_inscription_screen.dart` + `add_inscription_steps_1_2.dart`) : `_validateStep()` rend **obligatoires** prénom + nom + **date de naissance** (étape Élève) et année + classe (étape Scolarité), bloqués dans `_next()` + rempart au `_submit()` ; astérisque sur « Date de naissance * ». Aligne le formulaire sur les contraintes NOT NULL serveur. analyze 0, hot-reload OK. ⚠️ pas encore re-vérifié GUI (user passé sur admin_groupe).

**Méthode réutilisable** : diagnostiquer les pertes silencieuses via les logs `flutter run` (`grep "ABANDONNÉE\|Écritures locales perdues\|23502\|23503"`). **✅ Défense en profondeur CONSTRUITE** (2026-07-04) — les échecs sont désormais journalisés durablement et surfacés à l'utilisateur : voir [[sync-failure-journal]] (table local-only `sync_failures` + bannière shell acquittable). **Reste** : auditer les autres colonnes NOT NULL de `students`/`class_enrollments` ; envisager `date_of_birth` nullable en base si l'école peut ignorer la date (décision migration séparée). Lecture SQLite locale externe NON fiable (VFS PowerSync — voir frames WAL absents).
