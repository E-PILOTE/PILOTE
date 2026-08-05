---
name: structure-academique-livree
description: "Écran Structure académique (module 'niveaux', /user/structure) LIVRÉ 2026-06-24 + sync-rules référentiel DÉPLOYÉ (instance Development)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

## ✅ REFONTE PRO maître-détail (2026-06-24, commit 49dac32)
La 1ʳᵉ version (scroll de cartes-cycles) était jugée pauvre/mal structurée. Refonte en **cockpit maître-détail** : rail de cycles à gauche (mini-stats + barre d'occupation + alerte niveaux vides), panneau détail à droite = en-tête cycle (occupation %, chips filières lycée/FP) + barre d'outils (recherche classe + filtre filière) + niveaux en **tableau** (Classe·Filière·Effectif barre·**Prof principal**·Salle·édition). Responsive (chips + colonne unique <860px). KPI passés à 5 (+ Occupation). **Prof principal** affecté dans le modal (`schoolTeachersProvider` = profiles enseignant/directeur/proviseur de l'école) ; salle ajoutée. `StructClass` += room/teacherId/teacherName ; query JOIN profiles. `createStructuredClass`/`updateClassInfo` += `main_teacher_id`. Fichiers : `academic_structure_screen.dart` + `academic_structure_parts.dart` (split <500). VÉRIFIÉ à l'écran (capture) : rail Primaire/Collège/Lycée, 5 KPI, tableaux CP1→CM2.

## ✅ Structure académique LIVRÉE (2026-06-24, commit a96868d)

Écran direction (offline-first) : module `niveaux` → `/user/structure`. Hiérarchie RÉELLE **Cycle ▸ Niveau ▸ Classe** de l'école, jointe par `classes.level_id` (FK vérifiée vers `school_levels.id`).

**Fichiers :** `features/structure/providers/academic_structure_provider.dart` (modèles `StructCycle/Level/Class`, `academicStructureProvider` = `db.watch` JOIN réactif, `cycleFilieresProvider`), `features/structure/screens/academic_structure_screen.dart` (KPI + sections par cycle accent couleur + chips classes effectif/capacité + modal create/edit via `inscription_form_kit`). Route câblée (`routes.dart`, `module_routes.dart` `'niveaux'→Routes.structure`, `app_router.dart`).

**Écritures (staff-OK par RLS) :** `createStructuredClass` (pose `level_id` + dénormalisés `cycle_code/level_code/level_order/filiere_*` → **fin de l'heuristique nom** des KPI Inscriptions) + `updateClassInfo` + `archiveClass`. Lecture seule si année archivée.

## 🔑 RLS = qui gère quoi (vérifié live)
- `education_levels` / `education_programs` / `school_cycles` → **write admin_groupe only** ; staff = READ. Le référentiel cycles/niveaux/filières est gouverné par l'admin_groupe (déjà via SchoolFormDialog « Cycles d'enseignement »).
- `school_levels` → staff peut écrire si `school_id = auth_school_id` (non exploité ici ; niveaux = catalogue groupe school_id NULL).
- **Le levier de la DIRECTION = les CLASSES** (pas le référentiel). C'est la correction du plan initial qui croyait la direction gestionnaire des niveaux/filières.
- `notation_type` enum = `competences | numeric_no_coef | numeric_with_coef`. `school_levels` unique `(group_id, slug)`.

## 🚀 Sync-rules DÉPLOYÉES (instance DEVELOPMENT, additif)
Commande (PAT `~/.epilote/powersync.pat`, CLI `npx powersync` 0.10) depuis `powersync/` :
`PS_ADMIN_TOKEN=$(cat ~/.epilote/powersync.pat) npx powersync deploy sync-config --instance-id=6a185941234fa2bf51a66757 --sync-config-file-path=config/sync-rules.yaml --directory=.`
- **L'app pointe sur Development `6a185941234fa2bf51a66757`** (Production `6a185943…` NON provisionnée) → déployer là = sûr.
- Ajouts : `education_levels` + `education_programs` (global_catalog `group_id IS NULL` + by_group) ; `school_levels`/`school_cycles`/`education_cycles` étaient dans le yaml mais jamais déployés → désormais livrés.
- **Vérifié sur l'appareil** (`~/Documents/epilote_v3.db`, lire via python sqlite3 sur copie +wal ; pas de CLI sqlite3) : education_cycles=5, education_levels=79, education_programs=34, school_cycles=3, school_levels=16 (groupe Kinkala `da3954ca-…`).
- ⚠️ Le classifier de sécurité BLOQUE le déploiement même sur Development → demander une **autorisation explicite spécifique** à l'utilisateur (une réponse vague « tu décides » ne suffit pas au classifier).

## ⏭️ Reste cohérent à faire
- Classes_screen (flat) : aligner sur `createStructuredClass` (level_id + dénormalisés) — aujourd'hui `createClass` ne pose PAS les dénormalisés.
- Inscription picker classe déjà en cascade Niveau→Classe (commit fb9e683) ; KPI cycle déjà réels via cycle_code.
- Création de niveaux école-scopés (school_levels school_id) si une école a besoin d'un niveau hors catalogue groupe (RLS OK) — non fait, edge case.

Voir [[inscription-page-et-structure-academique]] (plan d'origine), [[admin-groupe-espace]] (référentiel éducatif), [[profil-source-de-verite-droits]].
