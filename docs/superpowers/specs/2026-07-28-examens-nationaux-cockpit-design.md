# Examens nationaux & Résultats/archives — design

**Date** 2026-07-28 · **Branche** `feat/examens-nationaux` · **Espace** `admin_groupe` (ministère, online)

## Contexte

Deux pages du cockpit ministériel sont concernées :

- **« Examens nationaux »** (`admin_exams_screen.dart`) — suit la session en cours : qui a
  inscrit, déposé, transmis. Chiffres issus de NOS écoles.
- **« Résultats & archives »** (`admin_exam_results_screen.dart`) — ce que la DEC a proclamé,
  et l'archive des pièces. Chiffres issus de la DEC.

La séparation est délibérée et reste acquise : deux « réussites par département » aux valeurs
différentes ne doivent jamais se toucher.

### Le processus réel (source : fonctionnaire DSIC/METP)

La DEC/DSIC produit les listes, le ministère décide de publier, les écoles se déplacent à la
DEC/DSIC pour récupérer les listes. **Il y a donc toujours une pièce.** Recoupé côté public : le
site du METP héberge lui-même le PDF de la Direction des examens et concours techniques et
professionnels, et les listes publiées portent le détail candidat (matricule, nom, sexe, date et
lieu de naissance, série, établissement, département).

Corollaire décisif : les taux sont proclamés **par examen** — BET 77,59 % et BEP 74,29 % (2025),
BTF 100 %, BAC T/P 51,61 % (2026). Le ministère ne publie jamais un chiffre « tous examens
confondus ». Or c'est exactement ce que fait le cockpit aujourd'hui.

## Problèmes constatés

| # | Problème | Cause dans le code |
|---|---|---|
| P1 | « Résultats & archives » met du temps à s'afficher | `officialFiguresProvider` / `examPublicationsProvider` sont `autoDispose` **sans** `keepAlive` (`exam_archives_provider.dart:258,307`) → détruits et refetchés à chaque aller-retour |
| P2 | La page montre une *fausse* réponse avant les données | `.valueOrNull ?? const []` (`admin_exam_results_screen.dart:35-36`, `exam_history_section.dart:34`) → KPI à 0, « aucun chiffre officiel enregistré », puis bascule |
| P3 | Sourcer un chiffre est un cul-de-sac | `_SourcePicker` (`exam_figure_panel.dart:362`) ne propose que les pièces de la même session, et le panneau n'offre aucun moyen d'en déposer une |
| P4 | Une publication porte des dizaines de chiffres | Un aller-retour complet dans le panneau par chiffre relevé |
| P5 | Le cockpit mélange tous les examens | `adminExamsProvider` agrège BET + BEP + BAC T + BAC P + concours dans un KPI et un taux uniques |
| P6 | Le graphe ne raconte rien | Série plate « candidats par examen » |
| P7 | Les ventilations filière/département sont des culs-de-sac | `ExamRateBreakdown` : « Mécanique 42 % » sans moyen de savoir quelles écoles |
| P8 | La modal école ne dit pas QUI bloque | `MinistrySchoolExam` ne porte aucun candidat |

## Décisions

### Chantier A — « Résultats & archives »

#### A1 · Chargement

- `ref.keepAlive()` sur `officialFiguresProvider` et `examPublicationsProvider`.
- L'écran résout les deux `AsyncValue` **une seule fois** et passe `List<OfficialFigure>` +
  `List<ExamPublication>` en paramètres aux trois sections (`ExamHistorySection`,
  `ExamArchivesSection`, `ExamFiguresSection`), qui cessent de re-`watch` (4 abonnements pour
  2 requêtes aujourd'hui).
- Un seul `when` : `ListShimmer` au premier chargement, `ExamsErrorView` en erreur,
  `skipLoadingOnReload: true` pour qu'un rafraîchissement ne vide plus la page.
- Bénéfice secondaire : les trois sections deviennent des widgets purs, testables sans Supabase.

#### A2 · Déposer la pièce depuis le panneau de relevé

- `showExamPublicationDialog` passe de `Future<void>` à **`Future<String?>`** — le `pubId` existe
  déjà (`exam_publication_dialog.dart:143`) et n'est aujourd'hui pas remonté au `pop()`.
- `_SourcePicker` gagne une action **« Déposer la pièce… »** qui ouvre le panneau de dépôt
  préchargé (session, périmètre, département/école du chiffre en cours). Au retour, la publication
  est sélectionnée automatiquement.
- Un chiffre déjà enregistré sans source se répare par le même chemin. `ExamFiguresSection` ajoute
  un raccourci **« Sourcer »** sur les lignes non sourcées : le KPI « Chiffres sans source » cesse
  d'être un constat sans issue.

#### A3 · Saisie groupée depuis la pièce

Nouveau panneau **« Relever les chiffres de cette pièce »** :

- la pièce, la session et la date de publication restent **épinglées** en tête et ne se vident
  jamais ;
- on saisit périmètre (national / département / établissement) + inscrits/présents/admis, puis
  **« Enregistrer et suivant »** — seuls le périmètre et les nombres se réinitialisent ;
- la liste des relevés déjà enregistrés pour cette pièce s'accumule sous le formulaire
  (« 3 relevés : National · Pool · Bouenza »), avec retrait possible ;
- deux entrées : à la fin d'un dépôt réussi, et depuis le menu d'une pièce archivée.

Les champs communs sont extraits de `exam_figure_panel.dart` vers `exam_figure_fields.dart`
partagé — sans quoi les deux panneaux dépassent 500 lignes.

### Chantier B — « Examens nationaux »

#### B0 · Décomposition par examen

`adminExamsProvider` **garde sa requête unique** (un seul aller-retour serveur). Ce qui change :

- les lignes accumulées portent désormais `examCode`, `examShortName`, `schoolId`, `schoolName` ;
- l'agrégation devient une fonction **pure** `MinistryExamsData.forExam(String? code)` — recalcul
  en mémoire, aucune requête supplémentaire, testable sans base ;
- `examFilterProvider = StateProvider<String?>` (`null` = tous les examens).

Correction de justesse : les KPI **« Stages du réseau »** et **« Bacs bloqués »** ne concernent que
`BAC_T` / `BAC_P`. Sur un examen non-bac ils **disparaissent** au lieu d'afficher un chiffre hors
sujet.

#### B1 · Sélecteur d'examen

Barre de puces sous le titre : `[Tous] (BET · 842) (BEP · 311) (BAC T · 204) (BTF · 28)`, triée par
effectif décroissant. Elle recadre toute la page : KPI, graphe, réussite par filière, réussite par
département, tableau des écoles.

#### B2 · Graphe

Entonnoir **Déclarés → Déposés → Admis** :

- sur **« Tous »** : trois séries groupées, un groupe par examen — on voit où la campagne fuit ;
- sur **un examen** : le même entonnoir **par département** (une barre unique n'a pas de sens).

Traitement visuel : colonnes arrondies, légende, tooltip portant l'assiette
(`47 admis / 112 connus`), étiquettes sur la seule série du haut, animation d'entrée.
`CategoryAxis` en X (String), `NumericAxis` en Y (double) — jamais l'inverse.

La palette et la grammaire du graphe suivent la skill `dataviz`, chargée avant d'écrire le code du
graphique.

#### B3 · Ventilations cliquables

Chaque ligne de `ExamRateBreakdown` devient cliquable → modal **« écoles de l'axe »** :

```
┌─ Mécanique générale · 42 % · BET ────────┐
│ 118 candidats · 47 admis / 112 connus    │
│ ÉCOLE            CAND. ADMIS  TAUX       │
│ LT Poaty          34    24    70,6 % ████│
│ CET Kinkala       28    12    42,9 % ██  │
│ CET Owando        25     2     8,0 % ▏ ⚠ │
│           [Exporter]      [Fermer]       │
└──────────────────────────────────────────┘
```

Classement par taux décroissant, mini-barre, ⚠ sur les écoles en bas de tableau, relance directe
depuis la ligne pour celles qui n'ont rien transmis. **Aucune requête nouvelle** : mêmes lignes en
mémoire, d'où l'ajout de `schoolId`/`schoolName` en B0.

Un taux inconnu s'affiche « en attente », jamais 0 % (règle réseau, `exam_stats.dart`).

#### B4 · Export

**Un seul bouton « Exporter »** → aperçu PDF à en-tête ministériel (`OfficialPdfKit` +
`showPdfPreviewDialog`), qui contient déjà imprimer et enregistrer. Trois boutons deviennent un.

Deux emplacements : dans la modal de drill-down (l'axe), et au niveau page (périmètre examen
courant : KPI + ventilations + tableau écoles).

⚠ La liste d'écoles est construite en **lignes**, jamais en `frame()` — un `frame()` ne se scinde
pas entre pages et lève `TooManyPages`.

#### B5 · Candidats dans la modal école

Nouveau provider **`schoolExamCandidatesProvider(schoolId)`** (family), chargé **paresseusement**
— uniquement à l'ouverture de la section — pour que la modal s'ouvre instantanément.

Lecture : `exam_candidates` joint à `students`, `classes` (`cycle_code`, `level_code`,
**`filiere_label`** — jamais `filiere_id`) et `exam_sessions → national_exams`.

- groupement **cycle → examen → filière**, avec effectif par groupe ;
- filtres **cycle**, **filière**, et **« dossiers incomplets seulement »** ;
- ligne : nom, classe, n° candidat, badge d'état ; pour un dossier incomplet, **les pièces
  manquantes nommément** (`missing_documents`).

Conséquence : le message de relance porte le détail réel — « 6 candidats de F5 sans acte de
naissance » se traite, « vos dossiers sont incomplets » se classe.

`admin_exam_school_modal.dart` est à 465 lignes : la section part dans
`school_candidates_section.dart`.

## Hors périmètre

- **Aucune migration** : toutes les colonnes existent (`candidate_number`, `missing_documents`,
  `filiere_label`, `cycle_code`). Chantier 100 % client.
- **Pas de « partager »** : aucun canal sortant réel dans l'app ; la relance par notification
  existe déjà et reste le seul geste sortant.
- **Pas d'évolution pluriannuelle** dans le drill-down : elle vit sur « Résultats & archives ».
  La dupliquer recréerait deux vérités.
- `admin_groupe` reste online/`supabase.from()`, jamais PowerSync. Aucun gate licence.

## Fichiers

| Fichier | Nature |
|---|---|
| `providers/exam_archives_provider.dart` | modif — `keepAlive` ×2 |
| `screens/admin_exam_results_screen.dart` | modif — un seul `when`, passage des données aux sections |
| `widgets/exam_history_section.dart` · `exam_archives_section.dart` · `exam_figures_section.dart` | modif — données en paramètres ; raccourci « Sourcer » |
| `widgets/exam_publication_dialog.dart` | modif — retourne le `pubId`, accepte un préremplissage |
| `widgets/exam_figure_fields.dart` | **neuf** — champs partagés |
| `widgets/exam_figure_panel.dart` | modif — « Déposer la pièce… », usage des champs partagés |
| `widgets/exam_figure_batch_panel.dart` | **neuf** — saisie groupée |
| `providers/admin_exams_provider.dart` | modif — `examCode`/`schoolId` dans les lignes, `forExam()`, `examFilterProvider` |
| `screens/admin_exams_screen.dart` | modif — sélecteur, périmètre, export page |
| `widgets/exam_scope_chips.dart` | **neuf** — barre de puces |
| `widgets/admin_exams_views.dart` | modif — graphe entonnoir |
| `widgets/admin_exams_breakdown.dart` | modif — lignes cliquables |
| `widgets/exam_axis_drilldown_modal.dart` | **neuf** — écoles de l'axe |
| `services/exam_axis_pdf_service.dart` | **neuf** — export PDF de l'axe et du périmètre |
| `providers/school_exam_candidates_provider.dart` | **neuf** |
| `widgets/school_candidates_section.dart` | **neuf** |
| `widgets/admin_exam_school_modal.dart` | modif — accueille la section, relance détaillée |

Tous les fichiers restent ≤ 500 lignes.

## Tests

- `admin_exams_scope_test` — `forExam()` recalcule KPI/filière/département ; les KPI stages et
  bacs bloqués disparaissent hors `BAC_T`/`BAC_P`.
- `exam_axis_drilldown_test` — classement des écoles, « en attente » jamais rendu en 0 %.
- `exam_figure_batch_test` — la pièce et la session restent épinglées, le périmètre et les nombres
  se vident, la liste des relevés s'accumule.
- `exam_results_loading_test` — la page rend un squelette et non une fausse page vide.
- `school_exam_candidates_test` — groupement cycle→examen→filière, filtres, pièces manquantes.

## Ordre d'exécution

A1 (lenteur) → A2 · A3 (sourcing) → B0 · B1 (filtre) → B2 (graphe) → B3 · B4 (drill-down +
export) → B5 (candidats).
