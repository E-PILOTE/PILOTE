---
name: staff-personnel-annuaire
description: Module Personnel (annuaire) livré sur profiles ; état RÉEL espace école (Classes/Matières/Calendrier/Élèves déjà faits) ; nœud staff_members différé Paie
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

✅ 2026-06-21 — Module **Personnel** (`/user/personnel`) livré : 1er maillon manquant de Phase 2 Acteurs. Fichiers : `features/staff/screens/personnel_screen.dart` + `features/staff/providers/staff_directory_provider.dart` ; route câblée dans `app_router.dart` (remplace `_comingSoon`). Commit `59a94db`.

**Conception (vérifiée base LIVE — règle « base live avant tout ») :** l'identité du personnel = la table **`profiles`** (nom, rôle, contact, matricule, statut, avatar), PAS `staff_members`. Preuve décisive : `teacher_subjects.staff_id` est une FK vers **`profiles`** (pas staff_members). Annuaire = `db.watch` sur `profiles WHERE school_id=? AND role NOT IN ('eleve','parent')`, 100 % offline, **lecture seule** (les comptes sont provisionnés en ligne par l'admin groupe). Regroupé par catégorie métier (`staffCategory()` : Direction/Administration/Enseignants/Vie scolaire/Autres) + compteurs + puces filtre + recherche locale + fiche détail (bottom sheet). Réutilise `staffRoleLabel`/`staffFmtDateTime` (staff_account_widgets) + `UserAvatarCircle`. Vérifié LIVE (Collège Public de Kinkala, directrice Aline) : 19 agents, groupes 2/5/9/3, fiche détail OK.

**⚠️ NŒUD `staff_members` DIFFÉRÉ (Phase 5 Paie) — confirme [[profil-source-de-verite-droits]] :** `staff_members` (84 lignes seedées) est un overlay RH/FINANCE **anonyme** : colonnes job_title, hire_date, contract_type (enum: permanent/contractuel/vacataire/stagiaire), base_salary_xaf, **iban**, speciality — **PAS de nom, PAS de profile_id en base live**. Donc non reliable à une personne aujourd'hui. **Bug latent dormant** : le schéma PowerSync local (`powersync_schema.dart`) DÉCLARE `staff_members.profile_id` (absent en prod) et OMET `iban` → tout insert offline avec profile_id échouerait à l'upload (perte silencieuse, cf [[inscription-module-logique]]). Laissé dormant (personne n'écrit cette table). **À régler en Phase 5** : migration `ALTER TABLE staff_members ADD profile_id uuid REFERENCES profiles(id)` (nullable, unique) + aligner schéma local (ajouter iban) + sync-rules ; la couche salaire/contrat devient alors une donnée **sensible gatée par capacité** (pas le rôle).

**📌 ÉTAT RÉEL espace école au 2026-06-21 (la note CLAUDE.md « seul /user/inscriptions implémenté » du 06-04 est PÉRIMÉE) :** déjà réels & câblés = Dashboard · **Élèves** (`features/students`) · **Tuteurs** · **Inscriptions** · **Classes** (`features/classes`, 573 l > 500 = dette) · **Calendrier/Années** (`features/structure/school_calendar`) · **Matières** (subjects) · **Personnel** (nouveau) · Profil/Paramètres. Encore `_comingSoon` = `notes`, `bulletins`, `presences-eleves`, `emploi-du-temps`, `discipline`, `paiements-eleves` + modules sans route dédiée (niveaux, cantine, biblio, infirmerie, transferts, documents, budget, conges, paie, presences-personnel, programmes, cahier-textes, orientation, conseils, annuaire, frais-scolarite, depenses). Sidebar = scrollable, footer SYSTÈME épinglé (RH/Finance peuvent être sous le pli — pas un bug).

**Prochain maillon logique :** Phase 2 finir avec `teacher_subjects` (affectation prof↔matière↔classe, sur profiles) OU Phase 3 Quotidien (`presences-eleves` = forte valeur quotidienne, socle classes+enrollments déjà là, sans migration).
