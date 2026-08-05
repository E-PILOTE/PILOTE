---
name: vie-scolaire-categorie
description: "Catégorie VIE SCOLAIRE complète (6 modules offline) — Présences, Cantine, Discipline, Orientation, Infirmerie, Bibliothèque ; kit partagé + passage à l'échelle 200 élèves"
metadata: 
  node_type: memory
  type: project
  originSessionId: d4b7d011-2f3d-4ee1-8013-06ea3ffadd28
---

✅ **2026-06-29 — Catégorie VIE SCOLAIRE COMPLÈTE (6 modules), commits `7290e8b` (base) + `dd3333e` (scalabilité).** Espace école, offline-first, design standard plateforme. analyze 0 / build linux ✓. **AUCUNE migration ni déploiement** : les 8 tables (`attendance_records`/`attendance_entries`, `canteen_records`, `discipline_incidents`, `student_orientations`, `infirmary_visits`, `library_items`/`library_loans`) sont déjà dans le schéma PowerSync local ET les sync-rules déployées ; **discipline + infirmerie en buckets SENSIBLES** (`sync_discipline` / `sync_medical`, cf [[profil-source-de-verite-droits]]). Catalogue live : catégorie « VIE SCOLAIRE » = 6 slugs (`presences-eleves`, `cantine`, `discipline`, `orientation`, `infirmerie`, `bibliotheque`). Routes câblées (constantes + `module_routes` + `app_router`, remplacent les placeholders).

**Dossier** `lib/features/vie_scolaire/` (24 fichiers, tous ≤500). **Kit partagé** `widgets/` : `vs_kit.dart` (VsHeader, VsHeroKpis, VsCoverageRow+VsCoverageList, vsScopeUnits/vsClassUnits/vsFilterScope, VsScopeChip, VsSectionLabel, `vsCrumb` fil Cycle▸Niveau) ; `vs_student_field.dart` (sélecteur d'élève AVEC RECHERCHE, groupé par classe — passe à l'échelle) ; `vs_form_chrome.dart` (vsFormHeader/vsFormActions) ; `providers/vs_students_provider.dart` (élèves actifs + classe via inscription).

**Modules** (chacun : en-tête+sélecteurs → KPI hero → `ScopeDrilldownPanel` Cycle▸Niveau▸Classe → couverture/liste → atelier/formulaire) :
- **Présences** `/user/presences` : appel par classe×date×période (AM/PM) ; feuille d'appel P/A/R + heure + justification + « Tout présent » + Finaliser ; `attendance_records`(1/classe×date×période) + `attendance_entries`(1/élève). VÉRIFIÉ GUI (appel + écriture offline réactive).
- **Cantine** `/user/cantine` : pointage repas par date×type (petit-déj/déj/goûter), servi/absent + « Tout servir » ; `canteen_records`.
- **Discipline** `/user/discipline` (sensible) : registre d'incidents (8 types, 8 sanctions, parents notifiés, suivi) ; panneau = FILTRE cycle/niveau/classe (`metricLabel:''` → pas de barre, juste compteurs) ; liste + formulaire ; `discipline_incidents` (pas de class_id → join inscription active).
- **Orientation** `/user/orientation` : recommandations par élève×trimestre (niveau/filière cible texte libre, parents consultés) ; atelier par classe (recherche) ; `student_orientations`.
- **Infirmerie** `/user/infirmerie` (sensible) : journal des passages (symptômes/diagnostic/traitement/médication/repos/suivi) ; liste + formulaire ; `infirmary_visits` (PAS d'academic_year_id → non year-scopé).
- **Bibliothèque** `/user/bibliotheque` : segments Catalogue (`library_items`, CRUD, dispo) + Emprunts (`library_loans`, prêt/retour, retards) ; emprunteur = élève via VsStudentField ; dispo gérée à l'emprunt/retour.

**Passage à l'échelle 200 élèves/classe** (commit dd3333e) : recherche dans feuille d'appel/pointage/atelier orientation (>8 élèves) ; listes lazy ; fil Cycle▸Niveau dans les en-têtes de tiroirs ; anti-redondance KPI Cantine.

Enums live : `attendance_records.period`=AM/PM ; `attendance_entries.status`=present/absent/late ; discipline type/sanction=varchar libre (presets UI). Reste catégorie suivante : Finance (frais/paiements/dépenses/budget), RH (paie/présences perso/congés). Voir [[evaluation-notes-bulletins]] (même standard) et [[form-class-context-pattern]].
