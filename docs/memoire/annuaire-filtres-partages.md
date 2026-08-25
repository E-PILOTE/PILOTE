---
name: annuaire-filtres-partages
description: "Kit d'annuaire partagé core/widgets/annuaire_filter_bar.dart — la barre d'outils se tient JUSTE AU-DESSUS de la liste, jamais dans l'en-tête de page"
metadata: 
  node_type: memory
  type: reference
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T06:26:50.483Z
---

# Un seul jeu de widgets pour tous les annuaires (2026-08-04)

`core/widgets/annuaire_filter_bar.dart` — extrait des widgets **privés** de
`admin_users_screen.dart` (10 Ko supprimés là-bas), consommé par :
- admin groupe → **Utilisateurs** ;
- école → **Personnel**.

`AnnuaireFilterBar` · `AnnuaireDropdown<T>` · `AnnuaireStatusSegment` ·
`AnnuaireViewToggle` · `AnnuaireIconAction` · `AnnuairePrimaryAction` ·
`AnnuaireResetChip` · `AnnuaireResultHeader`.

## ⚠️ LA RÈGLE DE COMPOSITION

**Tout ce qui agit sur la liste se tient juste au-dessus d'elle**, dans la carte
de filtres : recherche, filtres, bascule cartes/tableau, export, action
principale. **Rien ne remonte dans l'en-tête de page** — un bouton posé loin de
ce qu'il modifie oblige l'œil à faire l'aller-retour.

Deux rangées : (1) chercher → voir → agir ; (2) restreindre → tout relâcher.

## Décisions

- **Un seul jeu de filtres.** La barre de segments (`StaffSegmentBar`) POSE le
  filtre de son axe au lieu d'en tenir un second en parallèle. Deux filtres
  pour une même dimension donnent des listes qu'on ne sait plus expliquer.
- Les déroulants ne proposent que les valeurs **réellement présentes**.
- `AnnuaireResultHeader` dit toujours « N sur M » quand c'est filtré : un
  filtre trop serré ne doit pas se confondre avec un annuaire vide.
- Une action indisponible est **grisée, jamais retirée** (`onTap: null`).

## ⚠️ KPI par cycle : nommer ce qui manque

`teachingCycle` est **DÉDUIT** des classes enseignées → il est nul tant que
l'emploi du temps n'est pas fait. La carte « **Sans classe affectée** » est donc
obligatoire : sans elle, un lycée de 30 enseignants lit « Collège 4 · Lycée 15 »
et doute du comptage. **La somme doit se recomposer à l'œil.**
Testé : `test/personnel_cycle_kpis_test.dart`.

Liens : [[ecole-constate-une-arrivee]] · [[regle-taille-fichier-500]] ·
[[design-gouvernance-anti-redondance]]
