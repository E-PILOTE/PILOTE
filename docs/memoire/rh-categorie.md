---
name: rh-categorie
description: Catégorie RH livrée (Dossier agent riche + Présences + Congés + Paie) ; GATE = migration 0023 + déploiement sync-rules
metadata: 
  node_type: memory
  type: project
  originSessionId: d4b7d011-2f3d-4ee1-8013-06ea3ffadd28
---

✅ 2026-06-29 — catégorie **RH** complète, offline-first. analyze 0 / build ✓ / fichiers ≤500. Commits `a8a8c9a` (fondation + Dossiers) + `41a1464` (Présences/Congés/Paie). Code dans `epilote/lib/features/staff/`.

**Décision d'architecture (verrouillée) : l'AGENT = la ligne `profiles`.** Vérifié live : `payroll.staff_id`, `leave_requests.staff_id`, `staff_attendance.staff_id` pointent TOUS vers `profiles.id` (pas `staff_members`). `staff_members` (84 lignes anonymes, sans `profile_id` en base) reste un overlay legacy NON utilisé comme identité. `profiles` porte déjà matricule (`employee_number`), photo (`avatar_url`), genre, naissance.

**4 modules** :
- **Dossiers du personnel** (`/user/personnel` enrichi) — `showStaffDossier` : identité étendue en LECTURE (provisionnée online par admin_groupe : statut, grade·échelon·catégorie, spécialité, prise de service, matricule, naissance, contact) + **Parcours professionnel** (`staff_career`) & **Diplômes** (`staff_diplomas`) en **CRUD offline** (école). Frontière propre : RLS `profiles` n'autorise QUE admin_groupe/soi en UPDATE → on n'édite jamais profiles offline, seulement les 2 tables enfants school-gated.
- **Présences personnel** (`/user/presences-personnel`, `staff_attendance`) : pointage quotidien Présent/Retard/Absent (enum `attendance_status`), upsert par staff+date, KPI, recherche scalable.
- **Congés** (`/user/conges`, `leave_requests`) : demandes (type varchar libre + `kLeaveTypes`, jours auto), workflow pending→approved/rejected (enum `leave_status`), motif de refus.
- **Paie** (`/user/paie`, `payroll`, SENSIBLE) : bulletins mois/année, base+primes−retenues=net en direct, masse salariale, marquer payé, méthode (enum `payment_method`) / statut (enum `payment_status`).

**Vague 0 données — migration `0023_rh_dossier.sql`** : enum `employment_status` (fonctionnaire/contractuel/volontaire/prestataire/stagiaire/benevole) ; ALTER profiles (+employment_status/grade/echelon/category/hire_date/speciality) ; tables `staff_career`+`staff_diplomas` (FK profile_id, RLS `auth_sync_finance()` comme staff_members, index). Schéma PowerSync local + sync-rules MAJ (staff_attendance/staff_career/staff_diplomas ajoutées au bucket `sensitive_finance`).

**Élévation 2026-06-29 (commit `22ac4fc`)** — distinction = **axe Catégorie métier / Statut d'emploi** (PAS cycle/niveau/classe, qui sont des axes ÉLÈVE ; un agent n'y est pas inscrit). Kit partagé `widgets/staff_kit.dart` : `StaffAxis`, `staffSegments()`, `StaffAxisToggle`, `StaffSegmentBar` (carte/segment cliquable = filtre + métrique), `StaffBulkButton`. **Actions groupées** ajoutées : Présences = « Tous présents »/« Réinitialiser » (`setStaffAttendanceBulk`, writeTransaction) ; Congés = « Approuver les N en attente » (`approveLeaveBulk`) + double filtre statut×segment ; Paie = « Reporter le mois précédent » (`carryOverPayroll`, anti-doublon) + « Marquer tous payés » (`confirmPayrollBulk`).

**3e axe « Cycle » (commit `8e009a4`)** — un enseignant appartient à un cycle (primaire/collège/lycée). `StaffAxis.cycle` déduit le cycle de l'agent des classes qu'il enseigne (`classes.main_teacher_id` + `teacher_subjects.class_id` → `cycle_code`, sous-requête live dans staffDirectoryProvider ET staffDossierProvider) ; `StaffMember.teachingCycle`/`StaffDossier.teachingCycle`. Toggle d'axe à **3 positions** (Catégorie/Statut/Cycle) ; non-enseignants regroupés « Hors enseignement ». Réutilise `scopeCycleName`/`scopeCycleOrder` (cohérent avec l'axe élève). Ligne « Cycle enseigné » dans la carte d'identité. ⚠️ `teacher_subjects` quasi vide (3) + 2 classes avec main_teacher → l'axe est correct mais surtout « Hors enseignement » tant que les affectations profs ne sont pas saisies.

**Paie PDF + Personnel riche + form admin RH (commits `b65e030`+`7b8900c`) :**
- **Bulletins de paie PDF** (`services/payroll_pdf_service.dart`, OfficialPdfKit) : bulletin individuel par agent (base/primes/retenues/net, signatures) + état de paie période (tableau paysage, masse salariale). Boutons : icône PDF par carte + « État de paie (PDF) ».
- **Page Personnel refondue RICHE et scope-aware** (`personnel_screen.dart` + `personnel_views.dart` part) : KPI hero, distinction 3 axes + graphe répartition proportionnel (`_DistributionBar`), recherche + filtre statut, **bascule vue Cartes/Tableau**, **export PDF + CSV** (`services/personnel_export_service.dart`), ouverture dossier. **Verrou `staffCanManageProvider`** (admin_groupe/super_admin) = clé scope-aware : même page, gestion online du profil réservée à admin_groupe (le profil est lié `auth.users`, **création/identité = admin_groupe online uniquement**, infaisable offline). La direction école = lecture + dossier offline.
- **Form utilisateur admin_groupe enrichi** (source des champs RH) : migration **0024 APPLIQUÉE** (get_group_users renvoie statut/grade/échelon/catégorie/spécialité/hire_date) ; section « Carrière » en ÉDITION (création via RPC figée → enrichir à l'édition). `updateUser` persiste via `profiles.update`. **C'est ici qu'on renseigne statut/grade** pour que le dossier école les affiche.

**GATE — ✅ TOUT FAIT au 2026-06-29 :**
1. ✅ **Migration 0023 APPLIQUÉE en prod** (vérifié live : 6 colonnes profiles, tables staff_career/staff_diplomas + RLS, enum employment_status).
2. ✅ **Sync-rules DÉPLOYÉES au Cloud** (CLI 0.10, pré-vérif diff = +3 tables/0 retrait ; `fetch config` confirme staff_attendance/staff_career/staff_diplomas dans `sensitive_finance` live). Catégorie RH 100% opérationnelle et synchro.

Lié : [[staff-personnel-annuaire]] (annuaire profils préexistant), [[finance-categorie]] (même bucket sensitive_finance), [[profil-source-de-verite-droits]] (capacité sync_finance).
