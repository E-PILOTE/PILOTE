# Emploi du temps — Conception technique (bridge fonctionnel → technique)

> Référence : dossier d'analyse fonctionnelle Parties I & II. Ce document traduit
> l'architecture métier en architecture technique E-PILOTE (Flutter + Riverpod +
> PowerSync offline-first + Supabase, multi-tenant groupe→école).
> **Statut : en construction par vagues. Vague 0 (fondation données) = en cours.**

## Principes directeurs (non négociables)

1. **Offline-first** : le personnel scolaire lit/écrit via `db.watch()` / `db.execute()`
   (PowerSync SQLite local). Jamais `supabase.from()` côté personnel.
2. **Pas de duplication** : classes, matières/programmes (`class_subjects`),
   enseignants (`profiles`), calendrier (`events`, `trimesters`), audit (`audit_logs`),
   notifications (`notifications`) restent possédés par leurs modules. L'EDT les CONSOMME.
3. **Modèle besoin → trame → occurrence** : posé dès la fondation pour éviter toute
   refonte. MVP exploite surtout la **trame** (séance récurrente) ; les **occurrences
   datées** (exécution, exceptions) arrivent en V1 sur la même fondation.
4. **Cycle de vie porté par une `timetable_versions`** (brouillon→…→publié→archivé),
   pas par le créneau. Introduit dès le MVP pour ne jamais migrer plus tard.

## Modèle de données (cible)

| Table | Rôle | Vague |
|---|---|---|
| `rooms` | Registre des salles typées (remplace `room` texte libre) | MVP |
| `school_periods` | Trame horaire configurable par école/cycle (remplace `kStdPeriods` codé en dur) | MVP |
| `teacher_availability` | Disponibilités / indispos / préférences enseignant | MVP |
| `timetable_versions` | Version d'EDT = cycle de vie + publication | MVP |
| `timetable_slots` (+ `version_id`, `room_id`) | Séance planifiée (trame) | MVP (refonte) |
| `timetable_occurrences` | Occurrence datée (exécution : assurée/déplacée/annulée) | V1 |
| `teacher_absences` + `substitutions` | Absences & remplacements | V1 |
| `course_requirements` (besoin de cours) | Exigence dérivée de `class_subjects` × volume | V1 |

### Conventions
- IDs UUID texte. Booléens = `integer` 0/1 côté PowerSync, `boolean` côté Postgres.
- Tout porte `group_id` + `school_id` (dénormalisés) pour le routage sync sans JOIN.
- `created_at` / `updated_at` ISO partout (versionnage sync).
- RLS : policy tenant identique à `class_subjects` (super_admin OR (group =
  auth_group_id() AND (is_admin_groupe() OR school = auth_school_id()))). FK indexées.
- Sync-rules : bucket `by_school` (`SELECT * FROM <t> WHERE school_id = bucket.sid`).

## Plan d'implémentation par vagues

- **Vague 0 — Fondation données** *(en cours)* : migrations 0015–0019, `powersync_schema.dart`,
  `sync-rules.yaml`. Tables rooms / school_periods / teacher_availability /
  timetable_versions + `version_id`/`room_id` sur slots + RLS hardening slots/lessons.
- **Vague 1 — Salles & trame** : providers + écrans de gestion des salles et de la trame
  horaire (paramétrage école). Réutilise `admin_ui`, `ModuleScaffold`, `runModuleWrite`.
- **Vague 2 — Construction EDT refondue** : provider versionné, formulaire créneau
  (matière au programme, prof habilité, salle référencée, dispo prof), détection des
  conflits durs (prof/classe/salle/ressource), vues classe/prof/salle, mur d'ensemble.
- **Vague 3 — Disponibilités & publication** : écran dispos enseignant ; workflow
  brouillon→validation→publication (transitions gardées par rôle) ; export PDF.
- **Vague 4 — Branchements** : calendrier (fériés/vacances neutralisés), contrôle
  volume horaire vs `class_subjects`, lien cahier de textes, notifications de changement.

> V1+ (occurrences datées, absences/remplacements, examens, groupes, semaines A/B,
> indicateurs complets, génération assistée) s'ajoutent sur cette même fondation.

## Checklist de déploiement (à exécuter par l'humain / sur approbation)

1. Appliquer migrations `0015`→`0019` sur Supabase (ordre strict).
2. Déployer `sync-rules.yaml` via le dashboard PowerSync Cloud (sinon les nouvelles
   tables n'arrivent jamais sur les appareils → perte silencieuse).
3. `flutter pub get` puis vérifier `flutter analyze` (0 issue) et build Linux.
4. Vérifier la réplication des nouvelles tables sur un appareil de test.
