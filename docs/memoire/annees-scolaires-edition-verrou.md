---
name: annees-scolaires-edition-verrou
description: "Année scolaire — édition (admin) + piège \"année verrouillée\" côté staff si is_current=false"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a40fc29-8762-4c8e-bbec-655c8bf3d09a
---

**Piège central** : côté personnel (staff, offline), `yearReadOnlyProvider` = `y == null ? true : (y.isLocked || !y.isCurrent)`. Donc si le groupe n'a **aucune année marquée `is_current=true`**, TOUT l'espace école est en lecture seule → Inscription affiche « Année verrouillée » sur le bouton Nouvelle inscription (`inscriptions_screen.dart` `_AddButton(readOnly)`). Créer une année ne suffit PAS : `createYear` la pose `is_current=false` ; il faut l'action explicite **« Définir courante »** (`setCurrentYear`, gouvernance admin_groupe). L'année active = sélection header sinon `currentAcademicYearProvider`.

**Édition livrée** (commit 09a4c35, `feat/poste-vitrine-securite`) : avant, `AdminCalendarService` n'avait pas de méthode d'édition → une année créée avec faute (« 20.26-2027 », dates de quelques jours) était incorrigeable. Ajouté : `updateYear(id,label,start,end)` (scopé groupe) ; bouton « Modifier » sur chaque carte (hors archivée) ; `_YearDialog` sert création+édition (param `existing`). Création désormais **pré-remplie** via `school_year_defaults.dart` (helpers purs calendrier Congo : 1er lundi d'octobre → 2ᵉ vendredi de juillet, libellé `AAAA-AAAA`) — éditables. Stratégie retenue = dynamique+éditable (pas de pré-génération en masse). Tables : `academic_years` (group_id, school_id NULL=group-level, label, start_date, end_date, is_current, is_locked) → `trimesters` → `sequences`. Voir [[structure-academique-livree]].
