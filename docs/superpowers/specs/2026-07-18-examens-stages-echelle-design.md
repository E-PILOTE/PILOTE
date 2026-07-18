# Examens & Stages à l'échelle — regroupement classe/filière + virtualisation

**Date** : 2026-07-18
**Modules** : `features/examens`, `features/stages`
**Statut** : design validé

## Problème

Les listes de candidats aux examens et de stages sont rendues **à plat et sans
virtualisation** : `for (…) _TableRow` dans un `Column`, cartes en `GridView`
`shrinkWrap`. Au-delà d'une classe (école de 500+ candidats, gros lycée), tout
est construit d'un coup → jank. Trois manques de conception :

1. **Pas de regroupement** : un mur de lignes, sans structure classe/filière.
2. **Filière absente** comme dimension (elle dérive pourtant l'examen).
3. **Pas de virtualisation** : coût mémoire/CPU proportionnel à l'effectif total.

Le « lot » (tranches de ~50) est **purement organisationnel** (confirmé METP) :
il n'est PAS une contrainte DEC et **ne s'affiche pas à l'écran** — il reste
cantonné à la transmission/PDF, inchangé.

## Objectif

Rendre les deux écrans lisibles et fluides à toute échelle, en organisant les
candidats/stages **par classe** (avec la **filière** visible), sans toucher aux
KPI, actions groupées, dialogues (dossier/résultat/transmission), ni à
l'architecture offline-first.

## Décisions validées

- **Regroupement par classe, en-têtes pliables** (pas onglets, pas liste plate).
- **Lot : jamais à l'écran** (transmission/PDF uniquement, code inchangé).
- Le `ScopeDrilldownPanel` (cycle→niveau→classe) **reste** le sélecteur de haut
  niveau ; le regroupement par classe agit *sous* le scope courant.

## Conception

### 1. Modèle de données (offline, inchangé côté écritures)

- `ExamCandidateRow` gagne `filiereLabel` (`String?`) — source `classes.filiere_label`,
  la requête joint déjà `classes`. Ajouter la colonne au `SELECT` et au mapping.
- `InternshipRow` (stages) gagne `filiereLabel` de la même façon
  (`classes.filiere_label` via le join existant).
- Aucune migration : `filiere_label` existe déjà en base.

### 2. Regroupement + rendu virtualisé

Modèle d'**aplatissement** pour une seule liste virtualisée :

```
List<GroupedEntry> where GroupedEntry = GroupHeader | ItemRow
```

- On regroupe les lignes filtrées par `classId` (ordre : `levelOrder`, `className`).
- Pour chaque groupe : un `GroupHeader` (toujours présent) + les `ItemRow` du
  groupe **seulement si le groupe est déplié**.
- Un `SliverList.builder` parcourt cette liste aplatie → seules les entrées
  visibles sont construites (vraie virtualisation).

**En-tête de groupe (pliable)** :
- Examens : `Classe · [badge filière] · N candidats · C complets · D déposés`.
- Stages : `Classe · [badge filière] · N stages · A attestations · B bloqués`.
- Chevron plié/déplié ; clic = bascule. État plié conservé dans le State du panneau.
- **Défaut** : déplié si (scope = une classe) OU (≤ 2 groupes) ; sinon replié.
  « Tout déplier / Tout replier » dans la barre.

**Case « tout sélectionner »** (examens) : au niveau d'un groupe, coche/décoche
tous les candidats **visibles de ce groupe** (cohérent avec la sélection actuelle
qui ne retient que les ids visibles).

### 3. Restructuration en slivers (fin du `ListView` externe)

`exam_session_screen` et `stages_screen` passent d'un `ListView(children:[…])` à
un `CustomScrollView(slivers:[…])` :

- `SliverToBoxAdapter` : en-tête, KPI, `ScopeDrilldownPanel`, barre de filtres,
  barre d'actions groupées, en-tête de résultats.
- `SliverList.builder` : la liste aplatie groupée (le cœur virtualisé).
- `SliverToBoxAdapter` : `TransmissionsPanel` (examens) / bas de page.

**Propriété du défilement** — décision explicite : l'état d'UI candidats (texte de
recherche, filtres dossier/résultat/filière, bascule tableau/cartes, sélection,
groupes pliés) **remonte dans le `State` de l'écran** (`ExamSessionScreen` est déjà
`ConsumerStatefulWidget`). L'écran construit **un seul** `CustomScrollView` dont les
sections (barre de filtres, barre d'actions groupées, en-tête de résultats, liste
groupée) sont des slivers produits par des méthodes/ widgets dédiés.
`ExamCandidatePanel` est **dissous** en ces sections (un `Column` unique ne peut pas
virtualiser un enfant `SliverList`). La logique métier (filtrage, `_bulkDeposit`,
`_bulkRemove`) est déplacée telle quelle, sans changement de comportement.

### 4. Filière comme dimension

- **Badge** filière sur chaque en-tête de groupe (couleur neutre par tutelle).
- **Colonne** « Filière » dans le tableau examens (masquée si aucune filière dans
  le jeu courant, ex. collège général).
- **Filtre** filière dans la barre (déroulant alimenté par les filières présentes).

### 5. Ce qui NE change pas

KPI (`ExamKpiRow`, KpiGrid), actions de ligne (`ExamCandidateActions`), actions
groupées (`_bulkDeposit`/`_bulkRemove`), dialogues dossier/résultat, transmissions,
`assignLotNumbers`, sync-rules, schéma serveur, RLS.

## Découpage fichiers (règle ≤500 lignes)

- `exam_candidate_views.dart` : extraire le rendu groupé dans un nouveau
  `exam_candidate_grouped.dart` (modèle aplati + `SliverList` + en-tête de groupe).
  Le tableau/carte de ligne existants deviennent le contenu d'un groupe.
- Idem stages : `stages_grouped.dart` pour la version groupée/virtualisée.
- Providers : ajout d'un champ, pas de nouveau fichier.

## Tests

- **Unitaire (logique d'aplatissement)** : `groupByClass(rows, expanded)` produit
  la bonne séquence d'entrées (headers + rows selon plié/déplié ; ordre
  levelOrder/className ; compteurs par groupe corrects). Cas : 0 ligne, 1 classe,
  N classes, groupe replié = header seul.
- **Filière** : un jeu mêlant BAC_T/BAC_P regroupe et badge correctement ; un jeu
  sans filière n'affiche pas la colonne.
- Les tests existants (registration, dossier, résultats, lots, stages) restent
  verts (aucun changement de logique métier).

## Vérification

`flutter analyze` = 0 · `flutter test` vert · build release OK · vérif GUI dès que
le poste graphique est stable (grand scope = défilement fluide, en-têtes pliables,
badges filière).

## Hors périmètre (YAGNI)

- Pas d'affichage de lot à l'écran, pas de colonne/filtre lot.
- Pas d'onglets par filière.
- Pas de pagination « page 1/2 » : la virtualisation suffit.
- Pas de sticky-header (évite une dépendance ; à reconsidérer si besoin réel).
