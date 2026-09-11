# ÉVALUATION — analyse

**Slug catégorie** : `evaluation` · **Modules** : 4
**Code concerné** : `features/evaluation/` (28 fichiers, 11 031 lignes) ·
`core/utils/mention.dart` · `core/utils/passage_bareme.dart` ·
`core/utils/rang.dart` · consommateurs hors catégorie :
`features/admin_groupe/providers/student_results_provider.dart`,
`features/vie_scolaire/providers/orientation_provider.dart`
**Date** : 2026-09-08

> **Couverture déclarée.** Les 4 écrans d'entrée, les 7 providers et les
> 3 services PDF ont été lus intégralement. Lus partiellement (parcourus par
> requête ciblée : périmètre, tables, sorties document, états vides,
> `catch`) : `cloture_examen_section.dart` (894), `passage_parts.dart` (843),
> `cloture_examen_provider.dart` (719), `non_revenus_section.dart` (388),
> `conseils_parts.dart` (316), `evaluation_overview_widgets.dart` (486).
> Zone non couverte en détail : la mise en page fine des onglets « Classes
> d'examen » et « Non revenus » de l'écran Passage.
>
> Faits vérifiés en base LIVE (`wqpdamlnrwgozfvzjjpo`, 2026-09-08) et cités
> comme tels ; le reste est prouvé `fichier:ligne`.

---

## A. Vue d'ensemble de la catégorie (10 lignes max)

Les quatre modules forment une **chaîne temporelle complète** et cohérente :
saisir (`notes`) → calculer et remettre (`bulletins`) → délibérer le trimestre
(`conseils`) → délibérer l'année (`passage`). Chaque étage consomme
littéralement le calcul de l'étage précédent — `passage` appelle
`bulletinComputationProvider` trois fois plutôt que de refaire une moyenne
(`passage_provider.dart:466-471`), ce qui est la bonne décision et la raison
pour laquelle cette catégorie ne souffre d'aucune divergence *interne*.

Il n'y a ni intrus ni manque au catalogue. **Mais `passage` est un module dont
personne n'a fini l'installation** : la migration 0147 lui a donné une ligne,
des plans et des droits, la route est gardée sous son slug — et l'écran, lui,
demande toujours ses permissions au nom de `conseils`
(`passage_screen.dart:25`). Et surtout, la chaîne fuit **vers l'extérieur** :
la moyenne imprimée sur le bulletin n'est pas calculée avec les mêmes règles
que celle du dossier lu par le réseau et le ministère.

---

## B. Fiche par module

### Évaluations & Notes — `notes`

| | |
|---|---|
| Route | `/user/notes` (gardée : `module_routes.dart:26`) |
| Écran | `NotesScreen` — `features/evaluation/screens/notes_screen.dart` (313 l.) + parts `notes_parts.dart` (348), `notes_list.dart` (266), `notes_form.dart` (337), `notes_grades.dart` (329) |
| Tables lues | `evaluations`, `grades`, `class_enrollments`, `students`, `classes`, `subjects`, `class_subjects` (programme de la classe), `trimesters` |
| Tables écrites | `evaluations` (create/update/delete/statut), `grades` (upsert/delete) |
| Profondeur UI | **L2** (8/10) — manquants : n° 2 (aucun tri utilisateur), n° 9 (aucune sortie document) |
| Sortie document | **aucune** (détail en D.4) |

**Ce que le module fait** — Une évaluation = classe × matière × trimestre, avec
barème `max_score`, coefficient, type et cycle de vie
brouillon→soumise→validée→publiée. La feuille de saisie (tiroir bas) note élève
par élève sur le barème, ou marque l'absence, et normalise sur 20 à l'écran.
Écriture idempotente : `upsertGrade` relit la base sur la clé métier et déduit
l'identifiant (`eval_grades_provider.dart:88-95, 118`) — le double appui
n'envoie plus un 23505 fatal.

**Ce qui manque**

- **Le KPI hero compte TOUTE l'école, hors périmètre.**
  `evaluationsProvider` interroge `WHERE e.school_id = ? AND e.academic_year_id = ?`
  sans le moindre filtre de périmètre (`evaluations_provider.dart:123`), et
  `notes_screen.dart:164` le sert directement à `_NotesKpis`. Un enseignant en
  `data_scope = own_classes` — 7 lignes de `profile_permissions` en base — voit
  donc « Évaluations : 264 · Moyenne générale : 12,40/20 » pour
  l'établissement entier. La *liste* est bien bornée (elle passe par
  `evaluationOverviewProvider` → `classesForModuleProvider('notes')`), les
  *chiffres* ne le sont pas. Le test gardien `perimetre_par_module_test.dart:107`
  ne cherche que les usages de `classesProvider` : il est aveugle à une requête
  SQL écrite en direct.
- **Aucune sortie document.** `grep -rn "PdfPreview\|showPdfPreviewDialog" lib/features/evaluation/screens/notes*` → 0. Il n'existe ni feuille de
  notes imprimable, ni procès-verbal de composition, ni relevé de classe par
  matière — trois pièces qu'une école congolaise produit à chaque séquence.
- **Pas de recherche dans la feuille de saisie.** `notes_grades.dart` ne
  contient qu'un `TextField` (ligne 274) : le champ de note. Sur une classe de
  60, saisir la note de l'élève N°47 se fait au défilement.
- **`evaluations.sequence_id` n'est jamais écrit** (`grep -rn "sequence_id" lib/features/evaluation/` → 0). Le mode séquentiel réglé par
  l'admin groupe reste inerte — déjà nommé dans `evaluation-notes-bulletins.md`.
- **« Publiées — visibles élèves/parents » est faux** (`notes_parts.dart:23`) :
  `/user/espace-parent` est le seul placeholder du routeur
  (`00-INVENTAIRE.md:84`). Publier une évaluation la rend visible au **réseau et
  à la tutelle** (`student_results_provider.dart:142`), pas aux familles.

**Ce qui est en double** — Néant à l'intérieur du module. Le barème des
mentions n'apparaît nulle part ici (vérifié : `mentionFor` n'a que 6 appelants
dans tout `lib/`, tous légitimes).

**Ce que ce module partage** — **Produit** `evaluations` + `grades`, consommés
par `bulletins`, `conseils`, `passage`, et **hors catégorie** par le dossier
élève du Réseau (`student_results_provider.dart`) et par le palmarès
`admin_groupe` (`get_passage_merit`, migration 0061). **Consomme** `classes`
(`classes`), `class_subjects`/`subjects` (`matieres`, `programmes`),
`class_enrollments` (`inscriptions`), `trimesters` (calendrier admin_groupe —
qui n'est pas un module du catalogue).

---

### Bulletins — `bulletins`

| | |
|---|---|
| Route | `/user/bulletins` (gardée : `module_routes.dart:27`) |
| Écran | `BulletinsScreen` — `features/evaluation/screens/bulletins_screen.dart` (314 l.) + `bulletins_parts.dart` (330), `bulletins_detail.dart` (285) |
| Tables lues | `evaluations`, `grades`, `class_subjects`, `subjects`, `class_enrollments`, `students`, `bulletins`, `bulletin_subject_lines`, `trimesters`, `attendance_entries` + `attendance_records` |
| Tables écrites | `bulletins` (insert/update/statut), `bulletin_subject_lines` (delete+insert) |
| Profondeur UI | **L2** (8/10) — manquants : n° 1 (aucune recherche sur une liste d'élèves de 40-80 lignes), n° 2 (tri figé sur le rang) |
| Sortie document | **conforme** — `BulletinPdfService` + `OfficialPdfKit` + `showPdfPreviewDialog` (D.4) |

**Ce que le module fait** — Calcule offline, depuis les notes : moyenne par
matière (notes /20 pondérées par le coefficient de l'évaluation, absences
exclues), moyenne générale (pondérée par le coefficient de matière), rang de
compétition, mention, et l'assiduité du trimestre. « Générer » persiste ;
« Publier » fige et remet aux familles. Un bulletin publié n'est **jamais**
recalculé et se relit depuis `bulletin_subject_lines`
(`bulletins_provider.dart:236-279, 414-434`) — la protection est réelle et bien
faite.

**Ce qui manque**

- 🩸 **La moyenne du bulletin ne filtre PAS le statut des évaluations.**
  `bulletins_provider.dart:120-124` :
  `SELECT id, subject_id, coefficient, max_score FROM evaluations e WHERE e.class_id = ? AND e.trimester_id = ?` — aucun `AND e.status = ...`.
  Un brouillon avec trois notes tapées entre dans la moyenne du trimestre, dans
  la moyenne de classe, dans le rang, et sur le bulletin imprimé. Corollaire :
  **toute la chaîne brouillon→soumise→validée→publiée, durcie en base par la
  migration 0121 et gardée à l'écran (`notes_list.dart:209-214`), n'a aucune
  conséquence sur le document qu'elle est censée protéger.** « Valider » ne
  change rien à ce que le bulletin affiche. Invisible aujourd'hui : les
  **15 672 évaluations en base sont TOUTES `published`** (relevé live).
- 🩸 **Trois moteurs de moyenne pour le même élève** — détail complet en D.2 :
  ce module en est le premier exemplaire, et le seul des trois à ignorer le
  statut et à préférer `class_subjects.coefficient`.
- **Aucune impression en lot.** `grep -rni "imprimer tout\|tous les bulletins" lib/features/evaluation/` → 0. Le PDF s'ouvre depuis le tiroir d'un élève
  (`bulletins_detail.dart:56`). Remettre 60 bulletins = 60 ouvertures de tiroir,
  60 aperçus, 60 impressions. C'est le geste le plus répété de la fin de
  trimestre, et il n'est pas outillé.
- **Aucun relevé de classe imprimable** (le tableau rang / élève / moyenne /
  mention affiché à l'écran n'a pas de sortie) — alors que `conseils` et
  `passage` en ont un.
- **Le seuil de réussite est recopié.** `bulletins_parts.dart:63` :
  `comp.students.where((s) => (s.overallAverage ?? 0) >= 10)` — un exemplaire de
  plus de `kPassingMark`, alors que `isPassing()` existe dans
  `core/utils/mention.dart:50` et que le fichier importe déjà ce module par
  ré-export (`bulletins_provider.dart:14`). Le KPI s'intitule « Taux de
  réussite · ≥ 10/20 » (`bulletins_parts.dart:126-129`).
- **`setBulletinsStatus` publie plus que ce qui est à l'écran.**
  `bulletins_provider.dart:615-616` filtre
  `enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)` —
  **sans** `AND status = 'active'`, alors que le roster affiché n'a que les
  actifs (`:163`). Un élève sorti en cours de trimestre voit son bulletin publié
  sans jamais avoir figuré dans la liste. Contraire à la règle §4.3 « on
  imprime ce qui est à l'écran ».

**Ce qui est en double**

| Ce qui est dupliqué | A | B | Foyer |
|---|---|---|---|
| Seuil de réussite 10/20 | `bulletins_parts.dart:63` | `core/utils/mention.dart:47` (`kPassingMark`) | `isPassing()` |
| Colonne `bulletins.mention` écrite (`bulletins_provider.dart:528, 540, 560`) vs recalculée à chaque lecture (`:79 String get mention => mentionFor(...)`) | base | Dart | La colonne n'est **jamais relue** par l'app — soit on l'assume comme archive du document figé, soit on la retire |

**Ce que ce module partage** — **Produit** `bulletins` (+ `decision`,
`teacher_comment`, `director_comment`, `total_absences`) : consommé
**uniquement** dans la catégorie (`grep -rn "FROM bulletins" lib/ | grep -v features/evaluation` → 0). **Consomme** `notes` (le calcul),
`presences-eleves` (`attendance_entries` pour l'assiduité,
`bulletins_provider.dart:377-389` — migration 0122 appliquée, colonnes
NULLABLES et « Non renseignée — aucun appel enregistré » à `:88`), et
`classes`/`matieres` pour les coefficients.

---

### Conseils de Classe — `conseils`

| | |
|---|---|
| Route | `/user/conseils` (gardée : `module_routes.dart:28`) |
| Écran | `ConseilsScreen` — `features/evaluation/screens/conseils_screen.dart` (386 l.) + `conseils_parts.dart` (316), `conseils_roster.dart` (306), `conseils_deliberation.dart` (333) |
| Tables lues | tout ce que lit `bulletins` (réutilise `bulletinComputationProvider`) |
| Tables écrites | `bulletins.decision`, `bulletins.teacher_comment`, `bulletins.director_comment`, `bulletins.status` |
| Profondeur UI | **L2** (8/10) — manquants : n° 1 (aucune recherche), n° 2 (aucun tri) |
| Sortie document | **conforme** — `ConseilPdfService` (PV) |

**Ce que le module fait** — Délibération de trimestre : six distinctions
(`conseils_provider.dart:34-41`) inscrites dans `bulletins.decision`,
appréciation par élève, synthèse de classe partagée, validation du lot, et
procès-verbal PDF. `autofillAwards` propose sans jamais écraser
(`conseils_provider.dart:203-205`).

**Vérification du piège de vocabulaire annoncé — résultat : RIEN À SIGNALER.**
`bulletins.decision` n'est écrit que par `saveCouncilDecision`
(`conseils_provider.dart:174-176`) et `autofillAwards` (`:207-211`), toujours
avec un code de `councilAwards`. Le verdict annuel vit bien ailleurs
(`class_enrollments.promotion_decision`, `passage_provider.dart:658`), et
`passage_provider.dart:29-33` documente explicitement la distinction. **Confirmé
en base live** : `select distinct decision from bulletins` →
`avertissement_travail | encouragements | felicitations | tableau_honneur` ;
`select distinct promotion_decision from class_enrollments` →
`passe | redouble`. Aucune contamination, ni en code, ni en données.

**Ce qui manque**

- 🩸 **« Valider la délibération » est gardé par `update`, pas par `validate`.**
  `conseils_roster.dart:108` (`onStatus('validated')`) est sous
  `if (canEdit)` (`:80`), et `canEdit = canUpdate && !readOnly`
  (`conseils_screen.dart:241-243`). C'est **exactement** le défaut que la
  migration 0118 a corrigé pour « Publier » sur la page Bulletins — laissé
  debout un cran plus bas. Partout ailleurs le module applique la bonne règle :
  Notes exige `validate` pour `validated`/`published` (`notes_list.dart:212-213`),
  Bulletins pour publier (`bulletins_screen.dart:178`), Passage pour reconduire
  l'année (`passage_screen.dart:299`). Conseils est la seule action d'avancement
  de statut restée sur `update`. **La base ne rattrape pas** : le `WITH CHECK`
  de `bulletins_update` (relevé live) n'exige `bulletins.validate` que pour
  `status = 'published'` — `validated` passe avec `update`. Aucun garde-fou nulle
  part.
- ⚠️ **« Générer les bulletins » est gardé par `update`, alors que la base exige
  `create`.** `conseils_roster.dart:84` sous `if (canEdit)` — tandis que
  `bulletins_screen.dart:269` utilise `canCreate` pour le même geste. La policy
  `bulletins_insert` (live) exige
  `auth_module_permet(ARRAY['bulletins','conseils'], 'create')`. Un profil
  `conseils.update = true / can_create = false` verrait le bouton, insérerait en
  local, et prendrait un **42501 fatal à la remontée → lot entier jeté**.
  Latent aujourd'hui : `select … where can_update and not can_create` sur
  `conseils` → **0 ligne**. Mais rien n'empêche l'admin groupe de créer un tel
  profil demain, et le coût est la perte silencieuse de toutes les saisies hors
  ligne du poste.
- **Le barème des distinctions est en dur et non réglable.**
  `suggestedAward` (`conseils_provider.dart:52-59`) : 16 / 14 / 12 / < 8. Quatre
  seuils qui décident d'un « Blâme » ou d'un « Tableau d'honneur », sans réglage
  d'établissement — alors que la barre de passage, de conséquence comparable, a
  été rendue réglable (migration 0107). Ce n'est pas une copie du barème des
  mentions (les valeurs diffèrent volontairement) : c'est un **cinquième barème
  sans foyer déclaré**.
- **`suggestedAward` n'a aucun test** (`grep -rn "suggestedAward" test/` → 0).
- **Le bouton « Ouvrir la délibération » ne vérifie rien.**
  `conseils_parts.dart:308` : `context.go(Routes.passage)`, sans
  `PermissionGate` ni test de `passage.can_read`. Un membre sans le module
  `passage` clique et se fait renvoyer au tableau de bord par le garde
  (`app_router.dart:319-321`), sans un mot.
- **Aucune recherche/tri** sur une liste qui est un roster de classe complet.

**Ce qui est en double**

- Le seuil de couleur `>= 14 / >= 10` recopié trois fois pour le même usage
  décoratif : `conseils_roster.dart:190-192`, `conseils_deliberation.dart:62-64`,
  `bulletins_parts.dart:260-262` (+ `notes_grades.dart:324-326`). Quatre
  exemplaires du couple (barre de réussite, seuil « Bien »). Foyer : un helper
  `couleurMoyenne(double?)` à côté de `mentionFor`.
- « Générer les bulletins » implémenté deux fois — `conseils_screen._generate`
  (`:83-135`) et `bulletins_screen._generate` (`:68-121`) : même appel, mêmes
  contrôles d'identité, mêmes messages, **et deux gardes de droit différents**
  (cf. ci-dessus). Foyer : une fonction partagée dans `bulletins_provider`.

**Ce que ce module partage** — **Produit** la délibération portée par
`bulletins` : relue par le détail du bulletin
(`bulletins_detail.dart:86, 159`), par le PDF officiel
(`bulletin_pdf_service.dart:159, 178-180`) et par le compteur « délibérés » de
l'aperçu (`evaluation_overview_provider.dart:134-137`). **Consomme**
intégralement le calcul de `bulletins`.

---

### Passage en classe supérieure — `passage`

| | |
|---|---|
| Route | `/user/passage` — gardée sous le slug **`passage`** (`module_routes.dart:35` + `app_router.dart:298-321`) |
| Écran | `PassageScreen` — `features/evaluation/screens/passage_screen.dart` (626 l.) + `passage_parts.dart` (843), `cloture_examen_section.dart` (894), `non_revenus_section.dart` (388) |
| Providers | `passage_provider.dart` (914), `cloture_examen_provider.dart` (719), `non_revenus_provider.dart` (238) |
| Tables lues | `classes`, `class_enrollments`, `students`, `trimesters`, `academic_years`, `education_cycles`, `school_groups` + `school_levels` (barème), `exam_candidates`, `exam_sessions`, `national_exams`, `student_tutors` |
| Tables écrites | `class_enrollments` (`promotion_decision`, `promotion_average`, `promotion_target_class_id`, `promotion_decided_at/by`, `status`, réinscriptions), `classes` (reconduction de structure) |
| Profondeur UI | **L2** (7/10) — manquants : n° 1 (aucune recherche, 3 onglets et des dizaines de classes), n° 2 (aucun tri), n° 10 (4 fichiers > 500 l.) ; n° 9 partiel (PV pour le passage, **rien** pour les deux autres onglets) |
| Sortie document | **conforme là où elle existe** — `PassagePdfService` (PV) ; **absente** pour « Classes d'examen » et « Non revenus » |

**Ce que le module fait** — Trois régimes de fin d'année sous un seul écran :
(1) **Passage** — moyenne annuelle = moyenne des trois moyennes trimestrielles
à poids égal (`passage_provider.dart:142-147`, calculée par le moteur des
bulletins), verdict proposé par le barème réglable, campagne à l'échelle de
l'école avec compte rendu nominatif, PV, réinscription en masse ;
(2) **Clôture des classes d'examen** — report de la proclamation DEC, retour des
ajournés, sortie `graduated` des diplômés ; (3) **Non revenus** — détection des
élèves attendus et absents, avec garde-fou de seuil de saisie
(`non_revenus_provider.dart:16-21`).

**Vérification du barème de passage — résultat : la source unique tient, sauf
deux survivances.** `core/utils/passage_bareme.dart` est bien le seul foyer,
`suggestedVerdict` y délègue (`passage_provider.dart:93`), et le barème est lu
groupe puis dérogé niveau (`_baremeFor`, `:104-135`). Les deux copies :

- 🩸 **Le procès-verbal imprime « Barre de passage : 10/20 » EN DUR.**
  `passage_pdf_service.dart:145-147` — chaîne littérale, alors que
  `session.bareme` est disponible dans la même fonction et que
  `BaremePassage.libelle` existe précisément pour ça
  (`passage_bareme.dart:76-81`), et est déjà utilisé à l'écran
  (`passage_screen.dart:160`). Un groupe qui règle sa barre à 12 délibère à 12
  et **signe un PV qui affirme 10**. Le PV est la pièce qui fait foi.
  Invisible aujourd'hui : les **10 groupes sont à 10,00 sans zone de
  délibération** (relevé live) — le défaut est masqué par la donnée, exactement
  comme le barème des mentions l'a été.
- ⚠️ `passage_parts.dart:785` : `color: a == null ? kTextMuted : (a >= 10 ? kGreen : kRed)`
  dans `_TrimesterChip` — dans **le fichier même** dont le commentaire de la
  ligne 366 déclare que le `>= 10` écrit en dur a été retiré. Il en reste un.

**Ce qui manque**

- 🩸 **Le module demande ses permissions sous le mauvais nom.**
  `passage_screen.dart:25` : `const _kSlug = 'conseils';`. Conséquence, en
  trois temps :
  1. le **routeur** ouvre `/user/passage` sur `passage.can_read` + le plan
     `passage` + le hard-lock (`app_router.dart:298-321`, via
     `module_routes.dart:35`) ;
  2. le **`ModuleScaffold`** de la page re-teste `conseils.can_read`
     (`passage_screen.dart:52`) ;
  3. **tous les boutons** lisent `conseils` (`:291`, `:299`).

  Retirer `passage.can_update` dans la console d'administration **ne désactive
  aucun bouton** ; retirer `conseils.can_read` en gardant `passage.can_read`
  ouvre la route puis affiche « accès refusé ». La migration 0147 a créé le
  module en supposant que l'écran l'utiliserait ; l'en-tête de l'écran affirme
  au contraire « C'est la même instance, d'où le même module (`conseils`) »
  (`passage_screen.dart:30-32`). Les deux textes se contredisent, et c'est la
  console d'administration qui ment. **Relevé live** : les 21 lignes de
  `profile_permissions` sur `passage` sont aujourd'hui rigoureusement identiques
  à celles de `conseils` (0147 les a recopiées) — donc **aucun effet
  aujourd'hui, et un cadenas sur rien dès la première modification.**
  Corollaire : le littéral `'conseils'` est déclaré **deux fois** dans
  `features/evaluation/` (`conseils_screen.dart:28` et `passage_screen.dart:25`),
  ce que le test gardien de Finance interdit explicitement pour son propre slug
  (`perimetre_par_module_test.dart:143-152`).
- 🩸 **Aucun périmètre de données n'est appliqué sur toute la page.**
  `passageClassesProvider` (`passage_provider.dart:334-352`),
  `passageSessionProvider` (`:429`), `examClosureClassesProvider`
  (`cloture_examen_provider.dart:266`) et `non_revenus_provider.dart:83` lisent
  `classes` / `class_enrollments` en SQL direct — aucun appel à
  `classesForModuleProvider` ni à `classScopeClause`
  (`grep -rn "classesForModuleProvider\|classScopeClause" lib/features/evaluation/`
  → 2 occurrences seulement : `evaluation_overview_provider.dart:82` et
  `notes_form.dart:144`). **7 lignes de `profile_permissions` portent
  `data_scope = 'own_classes'` sur `passage`** (relevé live) : elles sont sans
  effet. Un enseignant restreint à ses classes voit et délibère **toutes** les
  classes de l'école. C'est le défaut F1 de
  `perimetre_par_module_test.dart:26-36`, resté sur le seul écran qui décide du
  redoublement — et le test ne le voit pas, parce qu'il ne cherche que les
  usages de `classesProvider`.
  `passageClassesProvider` ne filtre même pas `school_id`
  (`passage_provider.dart:344-348`, seulement `academic_year_id`), là où
  `classesForModuleProvider` le fait.
- **« Non revenus » et « Classes d'examen » n'ont aucune sortie.**
  `grep -n "showPdfPreviewDialog\|export" cloture_examen_section.dart non_revenus_section.dart`
  → 0. La liste des non-revenus porte le **téléphone du tuteur**
  (`non_revenus_provider.dart:172-174`) : c'est une liste d'appels, et elle ne
  peut ni s'imprimer ni s'exporter. La déperdition scolaire est un chiffre que
  le ministère publie ; ici il ne sort pas de l'écran.
- **Aucune recherche sur les trois onglets.** Aucun `TextField` dans
  `passage_screen.dart`, `passage_parts.dart`, `cloture_examen_section.dart`,
  `non_revenus_section.dart`.
- **Le compte rendu de campagne n'est pas conservé.** `BilanPropositions.resume`
  part dans un `SnackBar` de 7 secondes (`passage_screen.dart:189-193`). Sur une
  école de 460 élèves, « 48 restants » disparaît avec le message et n'est
  retrouvable nulle part.

**Ce qui est en double**

- `reenrollDecided` (`passage_provider.dart:849-905`) et la réinscription des
  ajournés de `cloture_examen_provider.dart:640-705` : deux implémentations du
  même geste (relecture anti-23505, `idDeterministe('class_enrollment', …)`,
  `previous_class_id`, `is_repeating`). Les deux sont correctes aujourd'hui ;
  elles devront le rester ensemble. Foyer : une fonction unique dans
  `passage_provider`.
- `_nextYear` : `passage_provider.dart:869` et `cloture_examen_provider.dart:469`
  — même requête, deux exemplaires.
- Le couple de seuils de couleur (cf. `conseils`), quatrième exemplaire à
  `passage_parts.dart:785`.

**Ce que ce module partage** — **Produit** `class_enrollments.promotion_decision`
(+ `promotion_average`, `promotion_target_class_id`) : lu **hors catégorie** par
`orientation` (`vie_scolaire/providers/orientation_provider.dart:128, 185`), et
par ses propres onglets. Produit aussi les **inscriptions de l'année suivante**
(consommées par `inscriptions`, `eleves`, `classes`) et la **reconduction de
structure** (`classes`, via `structure/providers/class_rollover.dart`).
**Consomme** `bulletins`/`notes` (les trois moyennes trimestrielles),
`examens` (`exam_candidates`, `exam_sessions` pour l'onglet de clôture),
`inscriptions` (`student_tutors` pour les non-revenus), et le **réglage
admin_groupe** `school_groups.promotion_pass_mark` / `school_levels.pass_mark`.

---

## C. Relations entre les modules DE cette catégorie

```
   [matieres] [classes] [inscriptions]        [presences-eleves]
        │         │           │                       │
        ▼         ▼           ▼                       │
  ┌───────────────────────────────────┐               │
  │  notes  ── evaluations + grades   │               │
  └───────────────┬───────────────────┘               │
                  │  bulletinComputationProvider      │
                  │  ⚠ ne filtre PAS evaluations.status
                  ▼                                   ▼
  ┌───────────────────────────────────────────────────────────┐
  │  bulletins  ── moyenne/matière · moyenne générale · rang   │
  │               mention · assiduité · GEL à la publication   │
  └───────┬─────────────────────────────────┬─────────────────┘
          │ (le MÊME calcul, réutilisé)     │ decision/appréciations
          ▼                                 ▼
  ┌────────────────────┐          ┌───────────────────────────┐
  │ passage (×3 trim.) │          │ conseils (par trimestre)  │
  │  moyenne annuelle  │          │  distinctions + PV        │
  │  verdict + PV      │          │  statut → validated       │
  └────────┬───────────┘          └────────────┬──────────────┘
           │                                   │
           │ promotion_decision                └─► retour sur le bulletin
           ▼                                       (écran + PDF officiel)
   [orientation]  [inscriptions N+1]  [classes N+1]
```

**Ce qui tient.** L'enchaînement est réel, pas déclaratif : `passage` **appelle**
`bulletinComputationProvider` (`passage_provider.dart:466-471`) au lieu de
recalculer, et `conseils` fait de même (`conseils_provider.dart:110-111`). Un
seul moteur de moyenne pour les trois écrans, donc aucune divergence interne.
`evaluationOverviewProvider` est bien clé par slug appelant
(`evaluation_overview_provider.dart:82` + les trois appels
`notes_screen.dart:165`, `bulletins_screen.dart:171`, `conseils_screen.dart:240`)
— **le point de vigilance annoncé est traité**.

**Où la chaîne casse.**

1. **En amont** : le statut d'une évaluation ne conditionne pas son entrée dans
   la moyenne. La barrière de validation est posée sur la porte, pas sur le
   couloir.
2. **Entre `conseils` et `passage`** : `passage` réutilise le module `conseils`
   pour ses droits mais est gardé comme `passage` par le routeur — deux serrures
   sur la même porte, avec deux clés différentes.
3. **En sortie de `passage`** : le verdict est écrit, le PV est imprimé, mais
   la *règle* qui a produit ce verdict n'est pas imprimée fidèlement (10/20 en
   dur).
4. **Vers l'extérieur** : les moyennes du bulletin et celles du dossier
   réseau/ministère ne sortent pas du même calcul (D.2, ligne 1).

---

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `bulletins` | Le calcul ignore `evaluations.status` : un brouillon compte dans la moyenne, et « Valider » ne change rien au bulletin | `bulletins_provider.dart:120-124` (pas de `AND e.status`) vs `student_results_provider.dart:142` et `0061…sql:81` qui filtrent `published` | Le bulletin remis à la famille et le dossier lu par le ministère donnent deux moyennes. Toute la cérémonie de validation (0121) est sans effet en aval | S |
| 2 | `passage` | Aucun `data_scope` appliqué : 4 providers lisent l'école entière | `passage_provider.dart:334-352, 429` · `cloture_examen_provider.dart:266` · `non_revenus_provider.dart:83` ; `grep -rn "classScopeClause\|classesForModuleProvider" lib/features/evaluation/` → 2 hits seulement | 7 profils en `own_classes` sur `passage` (live) délibèrent sur toute l'école. Cadenas fermé sur rien, sur l'écran qui décide du redoublement | M |
| 3 | `passage` | L'écran déclare `_kSlug = 'conseils'` alors que la route est gardée sous `passage` | `passage_screen.dart:25, 52, 291, 299` vs `module_routes.dart:35` + `app_router.dart:298-321` + migration 0147 | Les 10 booléens et le `data_scope` de `passage` dans la console d'administration ne pilotent que l'ouverture de la route. Divergence dès la première modification | S |
| 4 | `passage` | Le PV imprime « Barre de passage : 10/20 » en dur | `passage_pdf_service.dart:145-147` ; `BaremePassage.libelle` existe (`passage_bareme.dart:76-81`) et est utilisé à l'écran (`passage_screen.dart:160`) | Un groupe à 12/20 signe un PV qui affirme 10. Pièce qui fait foi | XS |
| 5 | `conseils` | « Valider la délibération » gardé par `update`, pas `validate` | `conseils_roster.dart:80, 108` + `conseils_screen.dart:241` ; la base ne rattrape pas (`bulletins_update` WITH CHECK n'exige `validate` que pour `published`, relevé live) | Un enseignant valide sa propre délibération. §8.3 « le directeur valide avant publication » | XS |
| 6 | `conseils` | « Générer les bulletins » gardé par `update` alors que la base exige `create` | `conseils_roster.dart:84` vs `bulletins_screen.dart:269` (`canCreate`) ; policy `bulletins_insert` (live) | 42501 fatal → **lot PowerSync entier jeté**. Latent : 0 profil concerné à ce jour | XS |
| 7 | `notes` | Les KPI hero comptent toute l'école, hors périmètre | `evaluations_provider.dart:123` (aucun filtre) servi tel quel à `notes_screen.dart:164` | Fuite de volumétrie et de moyenne d'école à un enseignant restreint | S |
| 8 | `bulletins` | Aucune impression en lot des bulletins d'une classe | `grep -rni "imprimer tout\|tous les bulletins" lib/features/evaluation/` → 0 ; seul point d'impression : `bulletins_detail.dart:56` | 60 tiroirs à ouvrir par classe, trois fois par an. Le geste le plus répété de la fin de trimestre | M |
| 9 | `notes` | Aucune sortie document du module | `grep -n showPdfPreviewDialog lib/features/evaluation/screens/notes*` → 0 | Ni feuille de notes, ni PV de composition, ni relevé par matière | M |
| 10 | `passage` | Onglets « Classes d'examen » et « Non revenus » sans aucune sortie | `grep -n "showPdfPreviewDialog\|export" cloture_examen_section.dart non_revenus_section.dart` → 0 | La liste d'appel des non-revenus (avec téléphone tuteur, `non_revenus_provider.dart:172`) ne sort pas de l'écran | S |
| 11 | `bulletins`, `conseils`, `passage` | Aucune recherche ni tri sur des rosters de 40-80 élèves | 0 `TextField` de recherche dans `bulletins_*`, `conseils_parts/roster`, `passage_*` | Critères §8 n°1 et n°2 sur trois modules | S |
| 12 | `bulletins` | Publication plus large que l'affichage | `bulletins_provider.dart:615-616` (pas de `AND status='active'`) vs roster `:163` | Bulletins publiés pour des élèves jamais affichés. §4.3 | XS |
| 13 | `conseils` | Barème des distinctions (16/14/12/8) en dur, non réglable, non testé | `conseils_provider.dart:52-59` ; `grep -rn suggestedAward test/` → 0 | Cinquième barème sans foyer déclaré, dans un dépôt qui a déjà payé cette facture deux fois | S |
| 14 | `notes` | `evaluations.sequence_id` jamais écrit | `grep -rn "sequence_id" lib/features/evaluation/` → 0 | §8.6 mode séquentiel configurable mais inerte (déjà nommé en mémoire) | M |
| 15 | tous | Aucune notification aux familles (§8.3 FCM) ; `/user/espace-parent` est un placeholder | `00-INVENTAIRE.md:84` ; `firebase_messaging` commenté dans `pubspec.yaml` | « Publier » ne prévient personne — cf. D.5 n°3 et 4 | L |

### D.2 Doublons et redondances — vue consolidée

| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|
| 1 | `notes`+`bulletins` ↔ **admin_groupe** ↔ **SQL** | 🩸 **Le calcul de la moyenne d'un élève, en trois exemplaires divergents** | `bulletins_provider.dart:120-124, 136-147, 281-331` (aucun filtre de statut · `COALESCE(cs.coefficient, subj.coefficient)`) | `student_results_provider.dart:139-142, 151-215` (`status='published'` · `subjects.coefficient`) **et** `0061_palmares_classes_de_passage.sql:71, 81, 95-107` (`status='published'` · `sub.coefficient`) | **Divergence de règle**, pas de code | Le Dart offline fait autorité (comme `mention.dart`). Aligner : filtrer `status='published'` côté bulletin, et faire remonter `class_subjects.coefficient` dans les deux autres. Test miroir obligatoire, faute de quoi les trois redériveront |
| 2 | `bulletins`, `conseils`, `notes`, `passage` | Le seuil de réussite 10/20 et le seuil « Bien » 14/20 | `bulletins_parts.dart:63` (**compté**, pas décoratif) + `:260-262` | `conseils_roster.dart:190-192`, `conseils_deliberation.dart:62-64`, `notes_grades.dart:324-326`, `passage_parts.dart:785` | Recopie de constante | `isPassing()` pour le compte ; un `couleurMoyenne(double?)` à côté de `mentionFor` pour les 4 copies décoratives |
| 3 | `passage` | La barre de passage, imprimée en dur sur le PV | `passage_pdf_service.dart:145-147` (`'Barre de passage : 10/20.'`) | `core/utils/passage_bareme.dart:76-81` (`BaremePassage.libelle`), déjà appelé à `passage_screen.dart:160` | Recopie de barème sur un document officiel | `session.bareme.libelle` |
| 4 | `conseils` ↔ `bulletins` | « Générer les bulletins » : même geste, deux implémentations, **deux gardes de droit différents** | `conseils_screen.dart:83-135` + `conseils_roster.dart:84` (`canEdit`) | `bulletins_screen.dart:68-121` + `:269` (`canCreate`) | Duplication de code **et** divergence de règle | Une fonction partagée exposée par `bulletins_provider`, gardée par `create` |
| 5 | `passage` (interne) | La réinscription dans l'année suivante | `passage_provider.dart:849-905` | `cloture_examen_provider.dart:640-705` | Duplication de code | `reenrollDecided` unique, paramétrée par la source du verdict |
| 6 | `passage` (interne) | `_nextYear()` | `passage_provider.dart:869-881` | `cloture_examen_provider.dart:469-478` | Duplication de code | `passage_provider` |
| 7 | `bulletins` | La mention : colonne `bulletins.mention` écrite mais jamais relue | `bulletins_provider.dart:528, 540, 560` (écriture) | `bulletins_provider.dart:79` (`mentionFor` recalculé à chaque lecture) | Donnée écrite sans lecteur | Trancher : archive du document figé (et la relire pour les publiés, comme les lignes-matières) ou colonne à retirer |

**Faux positifs écartés (vérifiés).** Le barème des mentions n'a **qu'un**
exemplaire : `mentionFor` est appelé 6 fois dans `lib/`, tous légitimes, la
recherche du motif `>=18…>=16…>=14…>=12` hors de `mention.dart` ne rend rien, et
`get_mention()` **n'existe plus en base** (`select count(*) from pg_proc where proname='get_mention'` → **0**, relevé live). Le test
`mention_source_unique_test.dart` garde cet état. `bulletins.decision` n'est
jamais confondu avec `promotion_decision` (données live à l'appui, cf. fiche
`conseils`). `evaluationOverviewProvider` porte bien le slug de l'appelant.

### D.3 Données partagées HORS catégorie

| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|
| `evaluations` + `grades` (statut `published`) | `notes` | **hors cat.** : dossier élève Réseau (`student_results_provider.dart:139`), palmarès `get_passage_merit` (`/admin/palmares`) | « publiée » = résultat officiel, opposable au ministère | Déjà rompu **en amont** : le bulletin ignore ce statut (D.1 n°1). Publier n'a pas le même sens des deux côtés |
| `attendance_entries` / `attendance_records` | `presences-eleves` | `bulletins` (`bulletins_provider.dart:377-389`) | Un appel enregistré sur la fenêtre du trimestre ; **absence de ligne ⇒ « — », jamais 0** (0122) | Contrat respecté. Mais l'appel est **par demi-journée** : au collège, une heure séchée n'apparaît sur aucun bulletin (`attendance_records.subject_id` toujours NULL — cf. `presences-appel-identite-deduite.md`) |
| `class_enrollments.promotion_decision` | `passage` | `orientation` (`vie_scolaire/providers/orientation_provider.dart:128, 185`), `inscriptions`, `eleves` | 3 codes : `passe` / `redouble` / `reoriente` | `reoriente` n'est jamais proposé automatiquement (`passage_bareme.dart:150`) : il est **saisi à la main** puis **exclu de la réinscription** (`passage_provider.dart:855`). Le relais vers `orientation` est donc entièrement manuel — vérifié `passe | redouble` seulement en base live |
| `class_subjects.coefficient` | `programmes` / `classes` | `bulletins` (`:139`) ; **ignoré** par le Réseau et par `get_passage_merit` | Le coefficient de la classe prime sur celui du référentiel | Latent : **0 divergence sur 4 564 lignes** en base live. Le jour où une école dérogeoie un coefficient, bulletin et palmarès s'écartent |
| `school_groups.promotion_pass_mark` / `school_levels.pass_mark` | réglage **admin_groupe** (`bareme_passage_card.dart`) | `passage` (`passage_provider.dart:104-135`) | Miroir Dart/SQL tenu identique (`verdict_passage()`, 0107) | Respecté à l'écran, **rompu sur le PV** (D.1 n°4). Les 10 groupes sont à 10,00 : le défaut est invisible aujourd'hui |
| `exam_candidates` / `exam_sessions` | `examens` | onglet « Classes d'examen » de `passage` (`cloture_examen_provider.dart:288, 481`) | La DEC proclame `admis`/`ajourne`/`absent`/`fraude` ; **jamais de moyenne** (cf. `metp-partage-dec-classes-passage.md`) | Respecté : `verdictFromExamResult` (`:64-69`) ne lit que l'admission, et la moyenne figée reste vide si la DEC ne la donne pas |
| `bulletins` + `bulletin_subject_lines` | `bulletins` | **personne hors catégorie** (`grep -rn "FROM bulletins" lib/ \| grep -v features/evaluation` → 0) | — | Le Réseau ne lit **pas** les bulletins : il recalcule. C'est la cause racine de D.2 n°1 |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|
| `notes` | **aucune** | — | — | non | **Manque**, pas non-conformité. Une feuille de notes est une pièce d'école |
| `bulletins` | `bulletin_pdf_service.dart` (233 l.) | oui (`:28-29, 70, 72`) | oui (`bulletins_detail.dart:56`) | non | **Conforme.** Réserves : impression **unitaire seulement** (D.1 n°8) ; pas de relevé de classe |
| `conseils` | `conseil_pdf_service.dart` (210 l.) | oui (`:25-26, 86, 89`) | oui (`conseils_parts.dart:82`) | non | **Conforme** |
| `passage` | `passage_pdf_service.dart` (226 l.) | oui (`:31-32, 97, 100, 107`) | oui (`passage_screen.dart:263`) | non | **Conforme sur la forme, fautif sur le fond** : « Barre de passage : 10/20 » en dur (`:145-147`). Onglets Clôture et Non revenus : aucune sortie |

**Compléments au balayage global (`22-transversal-documents.md`).**

- Les 3 services de la catégorie sont bien dans les 41 producteurs conformes :
  **0 `Printing.layoutPdf(`, 0 `PdfGoogleFonts`** dans `features/evaluation/`.
- ⚠️ **Aucun des trois n'utilise `OfficialPdfKit.tableSection`**
  (`grep -n tableSection lib/features/evaluation/services/*.dart` → 0). Ce
  n'est pas propre à la catégorie : **8 fichiers sur 41 producteurs** l'emploient
  dans tout le dépôt. **Vérifié empiriquement, sans défaut** : le PV de passage a
  été exécuté sur 60 élèves — `flutter test test/passage_pv_pdf_test.dart` →
  **4/4 verts**, le document sort et grossit avec l'effectif. La construction
  `MultiPage > Padding > Column` pagine correctement. **La règle §4.2 mérite
  donc d'être requalifiée à la fusion** : ce n'est pas l'absence de
  `tableSection` qui casse, c'est un widget non fractionnable trop haut.
- ⚠️ **`ConseilPdfService` et `BulletinPdfService` n'ont pas l'équivalent de
  `passage_pv_pdf_test.dart`** (`grep -rn "ConseilPdfService\|BulletinPdfService" test/` → 0). Le PV du conseil est bâti exactement comme celui du passage —
  donc probablement sain — mais rien ne le garde. Un test de 30 lignes par
  service, à 60 élèves et 18 matières, ferme le sujet.
- `ConseilPdfService` ne pose **aucun en-tête de continuation** :
  `header: (ctx) => ctx.pageNumber == 1 ? … : pw.SizedBox()`
  (`conseil_pdf_service.dart:85-88`), là où `PassagePdfService` réaffiche titre
  **et** en-tête de tableau (`passage_pdf_service.dart:99-105`). Les pages 2+ du
  PV de conseil arrivent sans colonnes.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|
| 1 | `passage` | **Case morte** | `passage_screen.dart:25` vs `module_routes.dart:35` | La console d'administration montre le module « Passage en classe supérieure » avec ses 10 verbes et son `data_scope` | Seul `can_read` agit (par le routeur). Les 9 autres verbes et le périmètre ne sont lus par aucune ligne de code — l'écran interroge `conseils` |
| 2 | `passage` | **Case morte** | `passage_provider.dart:334-352` et 3 autres providers | `data_scope = own_classes` sur `passage` : **7 lignes en base live** | Aucun filtre. L'agent voit et délibère toutes les classes de l'école |
| 3 | `notes` | **Promesse fausse** | `notes_parts.dart:23` | « Publiées · visibles élèves/parents » | `/user/espace-parent` est un placeholder (`00-INVENTAIRE.md:84`). Publier rend visible au **Réseau et à la tutelle**, pas aux familles |
| 4 | `bulletins`, `conseils` | **Promesse fausse** | `bulletins_parts.dart:206` (« visibles familles ») · `conseils_roster.dart:38` (« Bulletins publiés aux familles ») · `bulletins_screen.dart:290` (« Publiez aux familles ») | Le bulletin atteint la famille | Aucun canal : pas d'espace parent, pas de FCM (`firebase_messaging` commenté), `profiles.fcm_token` jamais écrit. Le bulletin n'atteint la famille que sur papier, imprimé un par un |
| 5 | `bulletins` | **Case morte** | `bulletins_provider.dart:120-124` | Le cycle brouillon → soumise → **validée** → publiée d'une évaluation, gardé à l'écran (`notes_list.dart:209-214`) et en base (0121) | Le bulletin prend toutes les évaluations quel que soit leur statut. « Valider » ne modifie aucun chiffre en aval |
| 6 | `bulletins` | **Case morte** | `bulletins_provider.dart:528, 540, 560` (écriture) vs `:79` (recalcul) | La colonne `bulletins.mention` est renseignée | Jamais relue par l'application. Même famille que `GradeModel` supprimé en 2026-08-27 |
| 7 | `passage` | **Affirmation fausse sur un document** | `passage_pdf_service.dart:145-147` | Le PV signé annonce la règle appliquée | Il annonce 10/20 quelle que soit la barre du groupe |

**Ce qui n'est PAS un zéro menteur, et mérite d'être dit** :
`features/evaluation/` ne contient **aucun `catch (_) {}`**
(`grep -rn "catch" lib/features/evaluation/` → une seule occurrence,
`non_revenus_section.dart:92`, qui affiche `messageErreur(e)` à l'utilisateur).
Les quatre écrans traitent `loading` et `error` séparément. Les tiret-plutôt-que-zéro
sont systématiques et commentés : mention sans note (`mention.dart:35`),
assiduité sans appel (`bulletins_provider.dart:86-94`), rang d'un élève sans
note (`:352-360`), trimestre sans note sur le PV (`passage_pdf_service.dart:199-206`),
absence de proposition en zone de délibération (`passage_bareme.dart:130-136`).
C'est la catégorie la plus propre du dépôt sur cet axe.

### D.6 Dette de structure

**6 fichiers sur 28 dépassent 500 lignes (21 %), tous concentrés sur `passage`.**

| Fichier | Lignes | Couture de découpe proposée |
|---|---|---|
| `providers/passage_provider.dart` | **914** | Trois responsabilités nettes : (a) le barème et les verdicts (`_baremeFor`, `suggestedVerdict`, `annualAverageOf`, l.61-147) → `passage_bareme_provider.dart` ; (b) la session de classe (`passageSessionProvider`, `_nextYear`, `_classAt`, l.424-905… lecture) → `passage_session_provider.dart` ; (c) les écritures et la campagne (`savePassageDecision`, `BilanPropositions`, `autofillVerdicts`, `autofillEcole`, `reenrollDecided`, l.630-905) → `passage_ecriture.dart` |
| `screens/cloture_examen_section.dart` | **894** | La section est autonome. Extraire l'en-tête de campagne, la grille de classes, la feuille de report DEC et la sortie `graduated` en 4 widgets — la couture existe déjà visuellement |
| `screens/passage_parts.dart` | **843** | Deux blocs sans lien : `_ClassCard`/`_CampaignHeader`/`_CampagneEcoleBar`/`_StudentRow` (l.1-560) et la feuille de verdict `_VerdictSheet`/`_TrimesterChip`/`_VerdictTile` (l.560-843) → `passage_verdict_sheet.dart` |
| `providers/cloture_examen_provider.dart` | **719** | Séparer la lecture (classes d'examen, roster) de l'écriture (report, réinscription, `graduated`), comme ci-dessus. Y mutualiser `_nextYear` et la réinscription avec `passage_provider` (D.2 n°5-6) |
| `screens/passage_screen.dart` | **626** | Sortir `_ClassDeliberation` (l.482-626), qui est déjà un écran complet |
| `providers/bulletins_provider.dart` | **619** | Frontière franche à la ligne 471 : le moteur de calcul (l.1-469) et la persistance (l.471-619) → `bulletin_calcul.dart` / `bulletin_persistance.dart`. ⚠️ `export` du `mentionFor` à conserver (l.14), plusieurs écrans en dépendent |

⚠️ **Rappel §7 du socle** : les tests de source doivent suivre dans le même
commit. `perimetre_par_module_test.dart` et `bulletin_publie_test.dart` lisent
des chemins de fichiers en dur.

Le reste de la catégorie est sain : 22 fichiers ≤ 500 lignes, et les quatre
écrans d'entrée (313 / 314 / 386 / 626) sont des orchestrateurs découpés en
`part` cohésifs.

### D.7 Désalignements catalogue ↔ code

1. 🩸 **`passage` : slug de catalogue ≠ slug de code.** Le catalogue et le
   routeur disent `passage` (`00-CATALOGUE.md:46`, `module_routes.dart:35`,
   migration 0147, base live : module actif, `display_order = 4`) ; l'écran dit
   `conseils` (`passage_screen.dart:25`). Cf. D.1 n°3 — c'est le désalignement
   le plus coûteux du périmètre.
2. **Une route, trois catégories.** `/user/passage` héberge trois gestes sous le
   verrou d'un seul module : le passage (**ÉVALUATION**), la clôture des classes
   d'examen — qui lit `exam_candidates`/`exam_sessions`, donc **EXAMENS &
   CERTIFICATION** (`cloture_examen_provider.dart:288, 481`) — et les non-revenus,
   qui écrivent le motif de sortie d'une inscription, donc **SCOLARITÉ**
   (`non_revenus_provider.dart:228`). Un profil ayant `examens` mais pas
   `conseils` ne peut pas reporter la proclamation de la DEC ; un profil ayant
   `inscriptions` mais pas `conseils` ne peut pas enregistrer un non-retour.
   À trancher : trois onglets sous un module assumé, ou un découpage par
   catégorie.
3. **La barre de passage se règle hors catalogue.** Le réglage vit dans les
   Paramètres de l'espace Réseau (`admin_groupe/widgets/bareme_passage_card.dart`)
   et pilote un écran de la catégorie ÉVALUATION. Aucun module ne le porte —
   même absence que pour le calendrier scolaire (années/trimestres/séquences),
   déjà notée dans `modules-acces-hierarchie.md`.
4. **Le test gardien de périmètre est aveugle à cette catégorie.**
   `perimetre_par_module_test.dart:107-118` ne cherche que
   `watch(classesProvider)`. Les quatre providers fautifs de `passage` et
   `evaluationsProvider` écrivent leur SQL en direct : ils passent au travers.
   La sonde est verte et aveugle — le motif exact averti au §7 du socle.
5. **Absent du catalogue, présent dans le code** : rien. Les 4 slugs
   `notes` / `bulletins` / `conseils` / `passage` sont actifs en base
   (relevé live) et ont chacun une route dédiée — aucun ne tombe sur
   `/user/m/:slug`.

---

## E. Les cinq choses à faire en premier

1. **Filtrer le statut des évaluations dans le calcul du bulletin — et le tester
   contre les deux autres moteurs.**
   *Module* : `bulletins` (et `notes`, `passage`, qui en héritent).
   *Fichier d'entrée* : `bulletins_provider.dart:120-124` — ajouter
   `AND e.status = 'published'`, puis un test miroir qui compare
   `bulletinComputationProvider`, `computeResults`
   (`student_results_provider.dart:151`) et `get_passage_merit` sur le même jeu.
   *Gain* : le bulletin de la famille, le dossier du ministère et le palmarès
   national cessent de donner trois nombres. La chaîne de validation redevient
   conséquente. *Effort* : **S** — la ligne est triviale, le test miroir est le
   vrai travail, et c'est lui qui empêche la troisième dérive.
   ⚠️ **Décider aussi du coefficient** : `class_subjects.coefficient` (bulletin)
   ou `subjects.coefficient` (les deux autres). 0 divergence en base
   aujourd'hui : la fenêtre pour trancher sans reprise de données est ouverte.

2. **Faire porter à `passage` son propre slug, et appliquer son périmètre.**
   *Module* : `passage`. *Fichier d'entrée* : `passage_screen.dart:25`
   (`_kSlug = 'passage'`), puis brancher `classesForModuleProvider('passage')`
   dans `passage_provider.dart:334`, `:429`, `cloture_examen_provider.dart:266`
   et `non_revenus_provider.dart:83`.
   *Gain* : la console d'administration cesse de montrer un cadenas sans
   serrure sur l'écran qui décide du redoublement ; les 7 profils en
   `own_classes` sont enfin bornés. *Effort* : **M**.
   ⚠️ **Ordre obligatoire** : la migration 0147 est déjà appliquée (module et
   droits en base, identiques à `conseils`) — le changement de slug peut donc
   partir avec le prochain build sans fermer la porte à personne. Étendre
   `perimetre_par_module_test.dart` pour qu'il cherche aussi `FROM classes` sans
   `classScopeClause`, sinon la correction se défera en silence.

3. **Rendre au procès-verbal la règle qu'il applique, et à « Valider » son
   droit.** *Modules* : `passage`, `conseils`.
   *Fichiers d'entrée* : `passage_pdf_service.dart:145-147` →
   `session.bareme.libelle` ; `conseils_roster.dart:80/108` → gard "Valider" par
   `canProvider((slug:'conseils', action:'validate'))` et « Générer » par
   `create` ; `bulletins_parts.dart:63` → `isPassing()`.
   *Gain* : trois défauts que les données de démonstration masquent
   aujourd'hui (10 groupes à 10,00 ; 0 profil `update`-sans-`create`) et qui
   apparaîtront tous les trois à la première école qui règle son barème ou son
   profil. *Effort* : **XS** — une demi-journée pour les trois.

4. **Imprimer les bulletins d'une classe en un geste.**
   *Module* : `bulletins`. *Fichier d'entrée* : `bulletins_parts.dart:_ActionBar`
   + `bulletin_pdf_service.dart` — un `buildPdf` qui prend `List<StudentBulletin>`
   et ajoute une `MultiPage` par élève, servi par `showPdfPreviewDialog`.
   *Gain* : le geste le plus répété de la fin de trimestre, trois fois par an,
   par classe. Aujourd'hui : 60 tiroirs, 60 aperçus.
   *Effort* : **M**. Poser au passage le test d'effectif manquant sur
   `BulletinPdfService` et `ConseilPdfService` (D.4), et l'en-tête de
   continuation absent du PV de conseil (`conseil_pdf_service.dart:85-88`).

5. **Donner une sortie aux non-revenus, et une recherche aux rosters.**
   *Modules* : `passage`, `bulletins`, `conseils`.
   *Fichiers d'entrée* : `non_revenus_section.dart` (liste + téléphone tuteur →
   PDF via `OfficialPdfKit`) ; puis un champ de recherche dans
   `bulletins_parts._StudentRow`, `conseils_roster`, `notes_grades._GradeSheet`.
   *Gain* : la déperdition scolaire devient un document remontable au
   ministère ; saisir la note de l'élève n°47 d'une classe de 60 cesse d'être
   un exercice de défilement. *Effort* : **S**.

---

**Deux points à remonter au socle, en contradiction assumée (règle §11.3).**

- **§4.2 « `tableSection`, jamais une table à la main » est trop large.**
  Mesuré : 8 fichiers sur 41 producteurs l'utilisent, et le PV de passage —
  qui ne l'utilise pas — sort correctement à 60 élèves
  (`flutter test test/passage_pv_pdf_test.dart` → 4/4 verts, exécuté le
  2026-09-08). Le critère utile n'est pas l'appel à `tableSection` mais
  l'existence d'un **test d'effectif réel** sur chaque producteur de liste.
- **Le chantier `chantier-bareme-classe-solde-eleve.md` n'a pas bougé et ne
  touche pas cette catégorie.** Il porte sur Finance (dû par classe vs
  candidature par élève, `obligation_provider.dart` / `paiements_provider.dart`
  / `exam_fees_provider.dart`). Aucun de ces fichiers n'est référencé depuis
  `features/evaluation/`, et rien dans la catégorie ÉVALUATION n'en dépend :
  **il reste ouvert, au même point qu'au 13/08/2026**, et il n'est pas un
  prérequis des cinq actions ci-dessus.
