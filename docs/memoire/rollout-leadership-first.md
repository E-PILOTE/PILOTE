---
name: rollout-leadership-first
description: "Vision rollout espace école — direction/administration d'ABORD, enseignants en DERNIER (scope le plus étroit, dépend de tout le reste)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fbfd7c02-473f-415b-b6e1-a21454a8de92
---

**CORRECTION DE PRIORITÉ (2026-06-07, explicite utilisateur).** Les profils d'accès / l'espace école se construisent et s'activent **d'abord pour la DIRECTION & l'ADMINISTRATION** (Proviseur [lycée], Directeur [collège/EP], Directeur des Études, Chef des Travaux, Secrétaire, Comptable, Surveillant) — **l'enseignant est parmi les DERNIERS à gérer**.

**Why (logique métier, confirmée par les données live + les 10 presets `admin_access_screen._kPresets` + ANALYSE.md §2) :**
- La direction **OPÈRE** le système : ce sont eux qui paramètrent et font tourner l'école. Permissions larges + périmètre **`own_school`** (toute l'école). Volume de droits seedés : Proviseur 161, Directeur 161, Consultant 156, Secrétaire 100, D.E 99, Chef Travaux 92, Surveillant 57, Comptable 43.
- L'**enseignant CONSOMME** : périmètre **`own_classes`** (uniquement SES classes via `teacher_subjects`), peu de modules (notes/évaluations/cahier de textes + lecture scolarité/vie scolaire). Droits seedés : 42 `own_classes` + 26 lecture. C'est le scope le plus ÉTROIT.
- L'enseignant **dépend de tout le reste** : pour saisir des notes il faut d'abord années/trimestres/séquences (calendrier), classes, matières, élèves inscrits, ET les **affectations enseignant↔matière↔classe** (`teacher_subjects`) + le lien `staff_members.profile_id`. Donc il vient logiquement EN DERNIER.

**Hiérarchie d'autorité (presets, du + large au + étroit) :** Proviseur ≈ Directeur (full sur les 6 catégories) > Directeur des Études (pédagogie) > Secrétaire / Chef des Travaux / Comptable / Surveillant (spécialisés) > Enseignant (own_classes) > Consultant (lecture+export) > Autre (vierge).

**Le socle (livré 2026-06-07) sert DÉJÀ correctement cette vision** : `scopedClassIdsProvider` → `own_school` = aucune restriction (la direction voit tout) ; `own_classes` = restreint aux classes de l'enseignant. État « aucun profil assigné » géré. ⚠️ Mon framing « tester avec un enseignant » était À L'ENVERS — la 1ʳᵉ persona = **Proviseur/Directeur/Secrétaire**.

**Séquence de déploiement décidée (leadership-first), à dérouler dans cet ordre :**
1. **Direction/Config** (Proviseur/Directeur/D.E/C.T) : **Calendrier scolaire ✅ LIVRÉ 2026-06-07** (années/trimestres/séquences) + référentiel Enseignement (Matières ✅, Niveaux, Programmes, EDT ; Classes ✅).
   - Calendrier = `features/structure/{providers/academic_year_provider (mutations create/setCurrent/lock pour années+trimestres+séquences, 1 seule courante par niveau), screens/school_calendar_screen + part calendar_detail}`. **Config NATIVE gating par RÔLE** (pas ModuleScaffold) : voir = {proviseur,directeur,directeur_etudes,secretaire} ; éditer = {proviseur,directeur}. Route `Routes.calendrier` `/user/calendrier` (non gardée par module). Entrée sidebar « Calendrier scolaire » section ÉTABLISSEMENT (visible direction). Master-détail années→trimestres→séquences, dialogs date-pickers, année verrouillée bloque l'édition. 0 lint, build ✓.
2. **Secrétariat/Scolarité** (Secrétaire) : Élèves ✅, Inscriptions ✅, Documents, Transferts, Annuaire.
3. **RH/Personnel — KEYSTONE** (Directeur/Proviseur) : Personnel (`staff_members` + lien `profile_id`), Affectations (`teacher_subjects`), Congés. ← c'est CE module qui rend « l'enseignant en dernier » réellement possible (sans affectation, own_classes = 0 classe).
4. **Finance** (Comptable) : Frais, Paiements, Dépenses, Budget.
5. **Vie scolaire** (Surveillant/CPE) : Présences, Discipline, Infirmerie, Cantine, Bibliothèque, Orientation.
6. **Enseignement opéré par les profs — EN DERNIER** (Enseignant) : Notes, Évaluations, Bulletins, Cahier de textes, Conseils de classe.

**Décision calendrier scolaire** : années/trimestres/séquences n'ont **pas de module catalogue** (ce ne sont pas des fonctionnalités vendables, c'est de la config socle). → les traiter en **tissu natif de configuration réservé à la DIRECTION** (gating par rôle proviseur/directeur, comme la COMMUNICATION est native), pas un module du catalogue. Lecture possible aux rôles qui en ont besoin (secrétaire/D.E).

**Prérequis gouvernance (hors code, à faire par l'admin_groupe)** : presque aucun utilisateur n'a de profil assigné (66 enseignants, 9 cpe, 8 comptable, 10 secrétaire, 9 surveillant = `access_profile_id` NULL ; seuls 2 liés). L'écran `admin_users_screen` permet déjà d'assigner un profil (`accessProfileId`). → **Assigner les profils LEADERSHIP d'abord** (Proviseur/Directeur/Secrétaire/Comptable), enseignants ensuite.

Lié : [[modules-acces-hierarchie]], [[role-admin-groupe]], [[design-gouvernance-anti-redondance]], [[catalogue-modules-v2]], [[inscription-module-logique]].
