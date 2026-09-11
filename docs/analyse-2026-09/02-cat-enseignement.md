# ENSEIGNEMENT — analyse

**Slug catégorie** : `enseignement` · **Modules** : 6
**Code concerné** : `features/structure/` (76 fichiers, 19 147 lignes) · `features/classes/` (4 fichiers, 2 778 lignes)
**Date** : 2026-09-08

> **Couverture** : les 6 écrans d'entrée, leurs 80 fichiers, les 21 providers et
> les 3 services PDF ont été lus. Les faits de production sont vérifiés en base
> LIVE (`wqpdamlnrwgozfvzjjpo`, MCP Supabase) et les sync-rules dans
> `powersync/config/sync-rules.yaml`. **Zone non couverte** : le rendu à l'écran
> (aucun test GUI ; les fiches mémoire signalent que les vues calendaires, les
> exceptions et l'historique de l'EDT n'ont jamais été vérifiés visuellement).

---

## A. Vue d'ensemble de la catégorie

La catégorie tient toute la **chaîne pédagogique** :
`Cycle ▸ Niveau ▸ Classe` (structure) → `Matières` (catalogue canonique) →
`class_subjects` (matière × classe : coefficient + volume horaire) →
`Emploi du temps` → `Cahier de textes`. Les six modules forment un vrai tout et
s'enchaînent réellement dans le code (le formulaire du cahier de textes lit les
créneaux de l'EDT ; l'EDT mesure sa conformité sur `class_subjects`).

Deux anomalies de composition :

- **`programmes` est un intrus fonctionnel.** Sa table `school_programs` compte
  **1 ligne pour 44 écoles** et **aucun module ne la lit** hors de son propre
  écran. Le mot « programme » désigne par ailleurs autre chose dans l'EDT
  (`classProgramProvider` = `class_subjects`). Deux notions, un mot.
- **Le calendrier scolaire (années/trimestres/séquences) n'est pas un module** —
  c'est assumé et correctement câblé (entrée native, gardée par le rôle). Mais
  la **saisie** des jours non ouvrés vit dans le tiroir de réglages de
  `emploi-du-temps`, un module vendable. Voir D.7.

Le module `niveaux` couvre à lui seul Cycle ▸ Niveau ▸ Classe et **recoupe
`classes`** : deux écrans, deux formulaires de classe, deux comptes d'effectif.

---

## B. Fiche par module

### Classes — `classes`

| | |
|---|---|
| Route | `/user/classes` (+ `/user/classes/:id`) |
| Écran | `ClassesScreen` — `features/classes/screens/classes_screen.dart` (392 l) + `classes_parts.dart` (**1 278 l**) + `classe_detail_screen.dart` (386 l) |
| Tables lues | `classes`, `class_enrollments`, `students`, `profiles`, `school_cycles`/`education_cycles`/`school_levels` (via `academicStructureProvider`), `education_programs` |
| Tables écrites | `classes` (INSERT `createStructuredClass`, UPDATE `updateClassInfo`, soft-delete `archiveClass`) |
| Profondeur UI | **L2** (8/10) — manquants : n° 9 (pas de PDF ; CSV seulement) et n° 10 (`classes_parts.dart` = 1 278 l) |
| Sortie document | CSV uniquement (`class_provider.dart:342`) — aucun PDF (détail en D.4) |

**Ce que le module fait** — Liste et gouverne les classes de l'année active :
KPI, graphes cycle/occupation, filtres cycle/niveau/filière + recherche, table
ou cartes, sélection multiple (archiver / exporter), création en cascade
Cycle ▸ Niveau, fiche de détail avec la liste des inscrits.

**Ce qui manque**

- **Impossible de corriger le niveau d'une classe.** `updateClassInfo`
  (`class_provider.dart:305-330`) ne touche ni `level_id` ni les dénormalisés
  `cycle_code`/`level_code`/`level_order`. Le formulaire d'édition n'affiche
  d'ailleurs les menus Cycle/Niveau que `if (!_isEdit)`
  (`classes_parts.dart:812`). Une « 6e A » créée par erreur sous *Primaire*
  reste sous Primaire pour toujours — et tous les KPI de la plateforme
  (Inscriptions, Structure, EDT, Bulletins) lisent ces dénormalisés. Le seul
  recours est d'archiver et de recréer, ce qui casse les inscriptions.
- **Aucune sortie PDF.** La liste des classes avec effectifs est une pièce que
  l'inspection réclame ; seul un CSV est produit. `grep -n "showPdfPreviewDialog"
  lib/features/classes/` → aucun résultat.
- **`createClass` est du code mort** (`class_provider.dart:217-256`) :
  `grep -rn "createClass(" lib/ test/` ne retourne que sa déclaration. C'est la
  version « plate » qui ne posait pas les dénormalisés — précisément le bug
  qu'on a corrigé. La laisser, c'est laisser un piège armé.
- **Aucun lien depuis la fiche de classe** vers son emploi du temps, son
  programme, son cahier de textes ou ses notes :
  `grep -n "context.push\|Routes\." lib/features/classes/screens/classe_detail_screen.dart`
  → 0 résultat. La fiche est un cul-de-sac.
- Les échecs d'archivage en lot sont avalés : `catch (_) {}`
  (`classes_screen.dart:143`). Le compteur « n classe(s) archivée(s) » est
  honnête, mais les échecs disparaissent sans un mot.

**Ce qui est en double**

- **Deux formulaires de création/édition de classe** :
  `classes_parts.dart:640` (`_ClassFormSheet`, via `AdminFormDialog` +
  `runModuleWrite`) et `academic_structure_class_form.dart:7`
  (`_ClassFormModal`, via `InscriptionModalFrame` + `try/catch` nu). Même
  écriture, deux chromes, deux politiques d'erreur, **deux politiques de
  permission** (cf. fiche `niveaux`). **Foyer proposé** : un seul
  `ClassFormDialog` partagé, appelé avec un `levelId` optionnel (verrouillé
  quand on vient de la structure — c'est exactement le patron
  `ClassContextBanner` déjà retenu, fiche `form-class-context-pattern`).
- **Le compte d'élèves d'une classe est calculé à deux endroits, différemment** —
  voir D.2 #1.
- **`class_provider.dart` (722 l) n'est le provider du module `classes` qu'à un
  tiers** : il porte 13 fonctions de cycle de vie d'`class_enrollments`
  (`enrollStudent`, `validateEnrollment`, `setEnrollmentExemption`,
  `withdrawStudent`, …, `class_provider.dart:396-722`) qui appartiennent à
  `inscriptions` / `eleves`. **Foyer proposé** :
  `features/students/providers/enrollments_provider.dart`.

**Ce que ce module partage** — Il **produit** la table `classes` et ses champs
dénormalisés, consommés par `eleves`, `inscriptions`, `transferts`, `documents`,
`notes`, `bulletins`, `conseils`, `passage`, `presences-eleves`, `discipline`,
`cantine`, `orientation`, `infirmerie`, `bibliotheque`, `stages`,
`paiements-eleves`. Il **produit** `classesForModuleProvider(slug)`, l'API de
périmètre de 12 modules. Il **consomme** `niveaux` (`academicStructureProvider`
pour la cascade du formulaire).

✅ **Aucune régression du défaut `classesProvider`** :
`grep -rn "classesProvider" lib/ | grep -v classesForModuleProvider` ne rend que
les **trois** usages légitimes documentés (`classes_screen.dart:204`,
`dashboard_chart_parts.dart:14`, `dashboard_kpi_parts.dart:19`), chacun commenté
sur place. 17 appelants passent bien par `classesForModuleProvider(<son slug>)`.

---

### Niveaux — `niveaux`

| | |
|---|---|
| Route | `/user/structure` |
| Écran | `AcademicStructureScreen` — `features/structure/screens/academic_structure_screen.dart` (233 l) + 5 parts (`_cycles` 181, `_detail` 237, `_niveaux` 121, `_classes` 260, `_class_form` 265) |
| Tables lues | `school_cycles`, `education_cycles`, `school_levels`, `classes`, `class_enrollments`, `profiles`, `education_programs` |
| Tables écrites | **`classes`** (INSERT/UPDATE/archive — le module n'écrit PAS de niveau) |
| Profondeur UI | **L2** (8/10) — manquants : n° 9 (aucun export) et n° 2 (pas de tri, tolérable : c'est une hiérarchie) |
| Sortie document | **aucune** (détail en D.4) |

**Ce que le module fait** — Cockpit maître-détail de la structure de l'école :
rail des cycles à gauche, panneau détail à droite (occupation, filtre filière,
recherche de classe, niveaux en tableau avec professeur principal et salle).
Le référentiel (cycles/niveaux/filières) est **gouverné par l'admin groupe** ;
le seul levier de la direction ici, ce sont les **classes**.

**Ce qui manque**

- ⛔ **AUCUN verbe de permission sur tout l'écran.**
  `grep -n "canProvider\|PermissionGate\|runModuleWrite" lib/features/structure/screens/academic_structure_*.dart`
  → **0 résultat sur les 6 fichiers**. Le seul garde est
  `yearReadOnlyProvider` (`academic_structure_screen.dart:81`), c'est-à-dire
  l'année verrouillée. Le bouton « + » ne dépend que de lui
  (`academic_structure_niveaux.dart:59-60`), comme l'édition
  (`:70`, `:75`) et l'archivage (`academic_structure_class_form.dart:118`).
  **Or la RLS exige le verbe** : `classes_insert` (vérifié en base) requiert
  `auth_module_permet(ARRAY['classes'],'create')` OR `conseils.validate` OR
  `auth_est_chef_etablissement()`. **En production, 7 profils « Secrétariat »
  (38 membres, rôles `secretaire`+`enseignant`) lisent `niveaux` sans détenir
  `classes.create`** — ils voient donc un « + » qui produit un **42501, code
  FATAL pour le connecteur PowerSync : le lot d'écritures entier du poste est
  jeté** (appel du matin, paiements du guichet, notes de la journée).
  C'est exactement la famille de défauts que `test/porte_de_creation_test.dart`
  garde — mais ce fichier n'est pas dans sa liste `_kPortes`
  (`porte_de_creation_test.dart:44-51`), parce que la porte n'est pas un
  `AdminEmptyState` mais un « + » de ligne.
- ⛔ **Le formulaire n'utilise pas `runModuleWrite`.**
  `academic_structure_class_form.dart:77-116` appelle `createStructuredClass`
  dans un `try/catch` nu. L'écriture locale réussit toujours ; le refus arrive
  plus tard, à la remontée, hors de tout `catch`. L'écran annonce
  « Classe créée. » (`:108`) pour une classe qui n'existera jamais côté serveur.
- ⛔ **Aucun périmètre `data_scope`.** `academicStructureProvider`
  (`academic_structure_provider.dart:89-144`) n'appelle pas `classScopeClause`.
  **En production, le profil « Enseignant » (201 membres) est en `own_classes`
  sur `niveaux`** : chacun voit ici la totalité des classes, des effectifs et
  des professeurs principaux de l'établissement. La fiche mémoire
  `modules-acces-hierarchie` (§ Verrou 4) affirmait « aucune fuite mesurée en
  production : toutes les divergences tombent sur `own_school` » — **ce n'est
  plus vrai**, `niveaux` et `emploi-du-temps` sont en `own_classes` pour 201
  membres.
- **Aucun export.** C'est l'écran qu'un établissement ouvre le premier matin et
  celui qu'une présentation ministérielle ouvre en premier ; « structure et
  effectifs par niveau » est un état officiel. Rien ne sort.
- **Impossible de créer un niveau école-scopé** (`school_levels.school_id`), que
  la RLS autorise pourtant au staff (fiche `structure-academique-livree`). Cas
  limite assumé — mentionné pour mémoire, pas à faire.

**Ce qui est en double**

- **Le second formulaire de classe** — voir la fiche `classes` ci-dessus,
  `academic_structure_class_form.dart:7` vs `classes_parts.dart:640`.
- **Le compte d'élèves** — D.2 #1.
- **Les palettes et libellés de cycle sont recopiés 3 fois** :
  `academic_structure_screen.dart:21-40`, `classes_screen.dart:23-49`,
  `programmes_screen.dart:27-58` (`_cycleColors` / `_cycleNames` /
  `_cycleOrder`). `scope_drilldown_panel.dart` porte déjà `scopeCycleColor` /
  `scopeCycleName` / `scopeCycleOrder`. **Foyer proposé** : ce dernier.

**Ce que ce module partage** — Il **produit** `academicStructureProvider`,
consommé hors de lui par `classes` (`classes_parts.dart:799`), `programmes`
(`programmes_cycle_view.dart:33`, `programmes_form.dart:91`) et
`emploi-du-temps` (`edt_periods_tab.dart:89`, sélecteur de cycle de la trame).
Il **consomme** le référentiel écrit par l'espace Réseau (`school_levels`,
`school_cycles`, `education_*`).

---

### Matières — `matieres`

| | |
|---|---|
| Route | `/user/matieres` |
| Écran | `SubjectsScreen` — `features/structure/screens/subjects_screen.dart` (381 l) + 5 parts + `subject_detail_dialog.dart` (265) / `_actions` (315) / `_assignment` (142) |
| Tables lues | `subjects`, `class_subjects`, `classes`, `teacher_subjects`, `profiles`, `class_enrollments` |
| Tables écrites | `subjects`, `class_subjects`, **`teacher_subjects`** |
| Profondeur UI | **L3** (10/10) |
| Sortie document | PDF conforme (kit + aperçu) — **mais** `OfficialPdfKit.table` au lieu de `tableSection`, et pas de mention « vue filtrée » (D.4) |

**Ce que le module fait** — Catalogue canonique des matières (une matière = une
identité), avec son coefficient par défaut. Le détail d'une matière ouvre ses
**affectations** : classes où elle est dispensée, coefficient effectif par
classe, volume horaire hebdomadaire, professeur affecté.

**Ce qui manque**

- ⛔ **L'écran ne peut afficher aucune des 94 matières de la plateforme.**
  `subjectsProvider` filtre `WHERE s.school_id = ?`
  (`subjects_provider.dart:46`). En base LIVE :
  `select count(*) filter (where school_id is null) … from subjects` →
  **94 sur 95 ont `school_id NULL`** (catalogue de groupe). Le correctif du
  2026-09-07 (`33ecf02`, « Les matières ne descendaient sur aucun poste ») a
  ajouté la projection `by_group` aux sync-rules
  (`sync-rules.yaml:203-204`) **mais n'a pas touché une ligne de Dart**
  (`git show 33ecf02 --stat` : 1 fichier, `sync-rules.yaml`). Les matières
  descendent maintenant sur le poste — et la page qui sert à les gérer
  continue de n'en voir aucune. Conséquences en cascade :
  le **filtre Matière du cahier de textes** est vide
  (`cahier_textes_screen.dart:151`) ; l'affectation d'un professeur à une
  matière devient impossible ; or **`teacher_subjects` est la source unique du
  périmètre `own_classes` de TOUTE la plateforme**
  (`permissions_provider.dart:161`) — un enseignant qu'on ne peut plus
  rattacher à ses matières se retrouve avec zéro classe, donc une application
  entièrement vide.
- **`createSubject` écrit `school_id = schoolId`**
  (`subjects_provider.dart:104-108`) : toute matière créée depuis l'app entre
  dans un régime différent des 94 autres (visible d'une seule école, projetée
  par `by_school` `sync-rules.yaml:280`). Deux régimes coexistent sans que rien
  ne le dise. **À trancher explicitement** : le catalogue est-il de groupe ou
  d'école ? La RLS (`0142`) autorise les deux.
- **Les affectations ignorent l'année scolaire.**
  `subjectAssignmentsProvider` (`class_subjects_provider.dart:54-79`) et
  `assignableClassesProvider` (`:119-127`) n'ont **aucun filtre
  `academic_year_id`**, alors que le KPI en a un (`subjects_provider.dart:35-44`,
  avec le commentaire qui explique pourquoi). Au premier renouvellement
  d'année, le détail d'une matière listera les classes de l'an dernier et le
  sélecteur d'affectation les proposera — pendant que le KPI de la même page
  affichera le bon compte. Deux chiffres, une donnée.
- Pas de garde sur `weekly_hours` : rien n'empêche de saisir 40 h hebdomadaires
  sur une matière (`class_subjects_provider.dart:180-191`), et c'est ce total
  qui pilote la « Conformité » de l'EDT.

**Ce qui est en double** — Néant de structurel. (Le coefficient a bien un seul
foyer : `subjects.coefficient` = défaut, `class_subjects.coefficient` =
surcharge, `effectiveCoef` `class_subjects_provider.dart:42`.)

**Ce que ce module partage** — Il **produit** `subjects` (lu par `notes`,
`bulletins`, `examens`, `emploi-du-temps`, `cahier-textes`, `programmes`),
`class_subjects` (lu par `bulletins_provider.dart:142` — un `JOIN`, donc un
bulletin sans ses lignes si la matière manque — et par
`classRequiredHoursProvider` pour la conformité EDT) et **`teacher_subjects`**,
qui gouverne `scopedClassIdsProvider` pour les 32 modules. C'est, de loin, le
module le plus structurant de la catégorie.

---

### Programmes — `programmes`

| | |
|---|---|
| Route | `/user/programmes` |
| Écran | `ProgrammesScreen` — `features/structure/screens/programmes_screen.dart` (453 l) + 7 parts |
| Tables lues | `school_programs`, `subjects`, `school_levels`, `education_cycles`, `trimesters` |
| Tables écrites | `school_programs` |
| Profondeur UI | **L3** (9/10) — manquant : n° 2 (aucun tri : l'état de l'écran ne porte pas de `_sort`, `programmes_screen.dart:85-91`) |
| Sortie document | PDF conforme à l'écran, **mais** `Printing.layoutPdf(` en source et un `pw.Column` non fractionnable (D.4) |

**Ce que le module fait** — Syllabus d'une matière à un niveau, éventuellement
par trimestre : titre + contenu, « officiel » (partagé par le groupe,
`school_id NULL`) ou « personnalisé ». Trois vues (table / cartes / par cycle),
filtres matière / niveau / trimestre / type, actions groupées, PDF.

**Ce qui manque**

- ⛔ **Le module ne sert à rien aujourd'hui, et à personne demain.**
  En base LIVE : `select count(*) from school_programs` → **1 ligne**, pour
  44 écoles et 4 564 affectations `class_subjects`. Et
  `grep -rn "school_programs\|programmesProvider" lib/ | grep -v structure/`
  → **aucun consommateur hors du module**. Le cahier de textes ne s'y adosse
  pas, la conformité de l'EDT lit `class_subjects.weekly_hours` et non le
  syllabus, les bulletins l'ignorent. Un module qu'on remplit et que rien ne
  relit : ce n'est pas encore une table morte, c'est un **cul-de-sac**.
  → Décision à prendre : brancher (le cahier de textes devrait pointer la
  séance sur l'item de programme couvert, l'inspection le demande) ou retirer
  du catalogue.
- **Collision de vocabulaire.** « Programme » = `school_programs` ici, et
  = `class_subjects` dans l'EDT (`classProgramProvider`,
  `timetable_provider.dart:410` ; panneau « Conformité au **programme** »,
  `emploi_du_temps_body.dart:28`). Deux objets, un mot, dans la même catégorie.
- Pas de tri (critère 2) alors que la vue table peut dépasser 20 lignes.

**Ce qui est en double** — Palette/libellés de cycle recopiés
(`programmes_screen.dart:27-58`) — voir fiche `niveaux`.

**Ce que ce module partage** — Il **consomme** `matieres` (`subjects`) et
`niveaux` (`school_levels`, `education_cycles`) et le calendrier (`trimesters`).
Il **ne produit rien pour personne**.

---

### Emploi du Temps — `emploi-du-temps`

| | |
|---|---|
| Route | `/user/emploi-du-temps` |
| Écran | `EmploiDuTempsScreen` — `features/structure/screens/emploi_du_temps_screen.dart` (377 l) + **15 parts** + tiroir de réglages `edt_settings_screen.dart` (219 l) + 6 parts + `emploi_du_temps_history.dart` (165 l) |
| Tables lues | `timetable_slots`, `timetable_versions`, `timetable_exceptions`, `rooms`, `school_periods`, `teacher_availability`, `school_holidays`, `class_subjects`, `subjects`, `classes`, `profiles`, `academic_years`, `trimesters`, `audit_logs` |
| Tables écrites | `timetable_slots`, `timetable_versions`, `timetable_exceptions`, `rooms`, `school_periods`, `teacher_availability`, `school_holidays` |
| Profondeur UI | **L3** (10/10) |
| Sortie document | conforme (kit + `showPdfPreviewDialog`), **mais** le livret exporte hors filtre (D.4) |

**Ce que le module fait** — C'est le module le plus abouti de la plateforme :
4 vues (Établissement / Classe / Enseignant / Salle), 6 empans (jour → annuel,
avec projection sur le calendrier réel hors jours non ouvrés), détection de
conflits prof/salle/classe bloquante à la saisie, registre de salles avec
contrôle de capacité, trame horaire par cycle, disponibilités enseignant,
exceptions datées (annulé/déplacé/en plus), versionnement + publication,
duplication et vidage d'une classe, historique d'audit, glisser-déposer,
livret PDF paysage.

**⚠️ Correction au brief de mission — la Vague 0 EST déployée.** Vérifié en base
LIVE : `timetable_slots` porte bien `version_id` et `room_id` (migration 0018),
**1 905 / 1 905 créneaux sont versionnés et rattachés à une salle référencée**,
`timetable_slots` et `lesson_entries` portent 4 politiques RLS chacune
(migration 0019), `rooms` = 212 lignes, `school_periods` = 42,
`teacher_availability` = 140, `timetable_versions` = 19,
`timetable_exceptions` = 56, et 2 triggers d'audit sont posés sur
`timetable_slots` (migration 0022). Le corps de la fiche mémoire
`edt-refonte-v2` le dit d'ailleurs (« APPLIQUÉES + VÉRIFIÉES en prod le
2026-06-28 ») ; seule sa ligne `description:` est restée périmée.
**Aucun gate de déploiement ne pèse sur ce module.**

**Ce qui manque**

- ⛔ **« Brouillon — non publié · En construction — invisible des
  enseignants/élèves »** (`emploi_du_temps_overview.dart:143-147`). C'est faux
  dans les deux sens. `timetableSlotsProvider`
  (`timetable_provider.dart:102-121`) ne filtre **pas** sur `version_id` ni sur
  le statut : un brouillon est visible de tout membre qui lit le module.
  Et `activeTimetableVersionProvider` n'a que **deux lecteurs, tous deux dans
  cette page** (`emploi_du_temps_screen.dart:173`,
  `emploi_du_temps_overview.dart:28` et `:118`) — publier ne change qu'un badge.
  Quant à « visible des élèves et parents », le rôle `parent` n'a pas d'espace
  (`/user/espace-parent` est le seul placeholder de la plateforme). Une
  protection annoncée mais absente est pire que son absence.
- ⛔ **Aucun périmètre `data_scope` sur les créneaux.**
  `timetableSlotsProvider` (`timetable_provider.dart:95-121`) ne passe pas par
  `classScopeClause`, alors que la liste de classes de la page, elle, le fait
  (`emploi_du_temps_screen.dart:169`,
  `classesForModuleProvider('emploi-du-temps')`). Le profil « Enseignant »
  (201 membres) est en `own_classes` sur ce module : en vue « Établissement »
  il obtient l'emploi du temps complet de l'école, et le sélecteur
  « Enseignant » énumère tous ses collègues
  (`emploi_du_temps_body.dart:46-53`).
- ⛔ **KPI « Classes couvertes X / Y » mélange deux périmètres** :
  `covered: coveredIds.length` vient de `all` (non borné,
  `emploi_du_temps_screen.dart:208`), `totalClasses: sorted.length` vient des
  classes bornées (`:287`). Pour un enseignant restreint, X peut dépasser Y.
- **Le livret PDF ignore le filtre de l'écran** :
  `_exportBooklet(sorted, all)` (`emploi_du_temps_screen.dart:329`) reçoit
  `all` et non `shown`. Un directeur qui filtre « Collège » puis imprime obtient
  toute l'école, sans mention « vue filtrée ». Violation de la règle §4-3.
- **Le tiroir de réglages n'est pas gardé.** `EdtSettingsView`
  (`edt_settings_screen.dart:65`) n'est pas enveloppé dans un `ModuleScaffold` ;
  il est ouvert depuis l'écran natif Calendrier
  (`calendar_holidays.dart:52-54`, `openEdtSettingsDrawer(…, kEdtSegCalendar)`),
  route qui n'est pas un module (`module_routes.dart:13-52`) et n'est gardée que
  par le rôle (`app_router.dart:287-291`). Un chef d'établissement d'une école
  au plan **Découverte** — qui ne comprend pas `emploi-du-temps` (vérifié en
  base : `plan_modules` → Découverte = `classes, matieres, niveaux`) — atteint
  ainsi les salles, la trame et les disponibilités. Verrou 2 contourné.
- **La trame n'existe presque nulle part** : 7 écoles sur 44 ont des
  `school_periods`, et **les 7 sont des écoles de formation professionnelle**
  (`cycle_code = 'formation_pro'`, 42 lignes). Les 12 écoles qui ont déjà un EDT
  sans trame affichent une grille sans ossature ni bandes de pause.
- L'historique d'audit est **vide en production** :
  `select count(*) from audit_logs where table_name in ('timetable_slots',…)` →
  **0**. Attendu (le trigger `log_edt_audit()` s'abstient quand `auth.uid()` est
  NULL, donc sur les seeds), mais aucun établissement n'a encore vu autre chose
  que « Aucune modification » (`emploi_du_temps_history.dart:99`).

**Ce qui est en double**

- **La salle est décrite deux fois.** Registre `rooms`
  (`rooms_provider.dart`, utilisé par l'EDT) **et** champ texte libre
  `classes.room`, saisi dans les deux formulaires de classe
  (`classes_parts.dart:888` et `academic_structure_class_form.dart:214-218`) et
  affiché dans la structure (`academic_structure_classes.dart:109`, `:213`).
  Rien ne les rapproche. **Foyer proposé** : `rooms` ; `classes.room` devient un
  `room_id` (la colonne existe déjà sur `timetable_slots`).
- **`kStdPeriods` (`timetable_provider.dart:26-36`) survit à `school_periods`** :
  trame 55 min codée en dur, alors que la table configurable la remplace depuis
  la migration 0016. Deux trames possibles pour la même école.
  **Foyer proposé** : `schoolPeriodsProvider`, et `kStdPeriods` réduit à un
  gabarit de `seedStandardPeriods`.

**Ce que ce module partage** — Il **consomme** `classes`, `class_subjects`
(conformité), `subjects`, `teacher_subjects` (pré-remplissage du prof),
`profiles`, et le calendrier natif (`academic_years`, `trimesters`,
`school_holidays`). Il **produit** `timetable_slots`, lu par
**un seul écran hors de lui** : le `_SeancePicker` du cahier de textes
(`cahier_textes_form.dart:167`). `grep -rln "timetable_slots" lib/ | grep -v structure` → rien.
**Les présences ne s'appuient pas sur l'emploi du temps** : il n'y a pas d'appel
« au cours de 8 h ».

---

### Cahier de Textes — `cahier-textes`

| | |
|---|---|
| Route | `/user/cahier-textes` |
| Écran | `CahierTextesScreen` — `features/structure/screens/cahier_textes_screen.dart` (279 l) + `_parts` (412) + `_form` (352) + `_form_fields` (168) |
| Tables lues | `lesson_entries`, `classes`, `subjects`, `profiles`, `class_subjects` (programme), `timetable_slots` (séances du jour) |
| Tables écrites | `lesson_entries` |
| Profondeur UI | **L2** (8/10) — manquants : n° 2 (aucun tri : ordre figé `entry_date DESC`, `lesson_log_provider.dart:90`) et n° 9 (aucun PDF) |
| Sortie document | **aucune** (D.4) |

**Ce que le module fait** — Journal des séances : date, classe, matière,
enseignant, titre, contenu, objectifs, devoirs, ressources. KPI, panneau de
répartition par cycle, filtres classe/matière/recherche, liste chronologique,
détail en 4 sections, CRUD gardé. Le formulaire limite la matière au programme
de la classe, pré-remplit l'enseignant depuis `teacher_subjects` et propose les
**séances de l'emploi du temps du jour** en un clic
(`cahier_textes_form.dart:254`, `_SeancePicker`).

**État réel : le module est LIVRÉ et utilisé** — 1 905 entrées en production,
sur 19 écoles. Ce n'est plus un chantier.

**Ce qui manque**

- **Aucune sortie PDF.** Le cahier de textes est LA pièce que l'inspection
  pédagogique demande (« cahier de textes de la 6e A, 2e trimestre »).
  `grep -n "showPdfPreviewDialog\|PdfService" lib/features/structure/screens/cahier_textes_*.dart`
  → 0. C'est le manque le plus net de la catégorie sur l'axe documents.
- **`lesson_entries.trimester_id` est une colonne dormante** : déclarée au
  schéma PowerSync (`powersync_schema.dart:713`) et présente en base, elle n'est
  **ni écrite ni lue** (`createLessonEntry`
  `lesson_log_provider.dart:134-147` ne la cite pas ;
  `grep -n "trimester" lib/features/structure/providers/lesson_log_provider.dart`
  → 0). Sans elle, pas de vue « cahier du trimestre », pas de filtre trimestre,
  et le PDF ci-dessus ne saurait pas se borner.
- **Le filtre Matière est vide** : il est alimenté par `subjectsProvider`
  (`cahier_textes_screen.dart:151`), cassé par le défaut `school_id` décrit
  plus haut. Le module hérite du défaut de `matieres`.
- Le lien avec l'EDT est **cosmétique** : `_pickedSlotId` ne part pas en base
  (`lesson_entries` n'a pas de `slot_id`, vérifié). On ne peut donc pas
  répondre à « quelles séances prévues n'ont pas été consignées ? », qui est la
  question de contrôle.
- Aucun tri (critère 2).

**Ce qui est en double** — Néant.

**Ce que ce module partage** — Il **consomme** `classes`, `matieres`
(`class_subjects` + `subjects`), `emploi-du-temps` (`timetable_slots`) et
`personnel` (`staffDirectoryProvider`). Il **ne produit rien** pour un autre
module : `grep -rln "lesson_entries" lib/ | grep -v structure` → rien.

✅ **Seul module de la catégorie à appliquer son propre périmètre** :
`classScopeClause(ref, kSlugCahierTextes, …)` (`lesson_log_provider.dart:73`),
avec le commentaire qui explique la correction (`:58-65`).

---

## C. Relations entre les modules DE cette catégorie

```
   [Réseau / admin_groupe]                         [natif, hors catalogue]
  education_cycles ─ school_levels                 academic_years ─ trimesters ─ sequences
        │                                                    │   (/user/calendrier, rôle)
        ▼                                                    │
  ① niveaux  /user/structure ───(school_cycles ⋈ school_levels ⋈ classes)
        │  écrit ▼                                           │
  ② classes  /user/classes ── classes (+ cycle_code/level_code/level_order/filiere_*)
        │                         │                          │
        │                         ├──────────► 16 modules hors catégorie
        │                         │
  ③ matieres /user/matieres ── subjects ─┬─ class_subjects (coef + weekly_hours)
        │                                └─ teacher_subjects ──► scopedClassIdsProvider
        │                                                        (verrou 4 de TOUTE la plateforme)
        ▼                                    ▼
  ⑤ emploi-du-temps ── timetable_slots ── conformité = Σ weekly_hours
        │  (+ rooms, school_periods, teacher_availability,
        │     school_holidays, timetable_versions, timetable_exceptions)
        ▼
  ⑥ cahier-textes ── lesson_entries  (_SeancePicker lit les créneaux du jour)

  ④ programmes ── school_programs ────────►  ✗  (1 ligne en prod, aucun lecteur)
```

**Où la chaîne casse — quatre ruptures :**

1. **À la source, sur `matieres`.** `subjectsProvider` ne voit pas 94 des
   95 matières. Tout l'aval (filtre du cahier de textes, affectation des
   professeurs, donc `teacher_subjects`, donc le périmètre `own_classes` de la
   plateforme entière) part d'un catalogue que son propre écran affiche vide.
2. **`programmes` n'est branché sur rien** — ni en amont utile, ni en aval.
3. **`niveaux` et `classes` se chevauchent** : deux écrans qui créent la même
   ligne, avec deux formulaires, deux politiques d'erreur et deux politiques de
   permission (l'un gardé, l'autre pas).
4. **`emploi-du-temps` ne sort pas de lui-même** : ses créneaux ne sont lus que
   par le cahier de textes ; la publication n'informe personne ; les présences
   ne s'y adossent pas.

---

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `matieres` | L'écran filtre `s.school_id = ?` alors que 94/95 matières ont `school_id NULL` | `subjects_provider.dart:46` ; base LIVE `count filter (school_id is null)` = 94/95 ; `git show 33ecf02 --stat` = sync-rules seules | Catalogue vide → plus d'affectation prof → `teacher_subjects` gelé → périmètre `own_classes` vide pour 201 enseignants | **S** |
| 2 | `niveaux` | Aucun verbe de permission sur les 6 fichiers de l'écran | `grep -n "canProvider\|PermissionGate\|runModuleWrite" academic_structure_*.dart` = 0 ; bouton `academic_structure_niveaux.dart:59` ; RLS `classes_insert` exige `classes.create` | 38 membres « Secrétariat » face à un « + » qui déclenche un 42501 → **lot PowerSync entier jeté** | **S** |
| 3 | `niveaux` + `emploi-du-temps` | Aucun `classScopeClause` sur les données | `academic_structure_provider.dart:89-144` ; `timetable_provider.dart:95-121` | 201 enseignants en `own_classes` voient toute l'école (effectifs, EDT, collègues) | **M** |
| 4 | `cahier-textes` | Aucun PDF | `grep "showPdfPreviewDialog" cahier_textes_*.dart` = 0 | La pièce que l'inspection réclame ne s'imprime pas | **M** |
| 5 | `cahier-textes` | `trimester_id` jamais écrit ni lu | `powersync_schema.dart:713` ; absent de `createLessonEntry` (`lesson_log_provider.dart:134-147`) | Pas de cahier par trimestre — donc pas de PDF bornable | **S** |
| 6 | `classes` | Le niveau d'une classe n'est plus modifiable | `updateClassInfo` `class_provider.dart:305-330` ; menus `if (!_isEdit)` `classes_parts.dart:812` | Une classe mal rangée fausse les KPI de 16 modules, sans recours | **S** |
| 7 | `classes` + `niveaux` | Aucun export (liste des classes en PDF, structure & effectifs par niveau) | `grep "showPdfPreviewDialog" features/classes/` = 0 ; idem `academic_structure_*` | Deux états officiels de rentrée absents | **M** |
| 8 | `programmes` | Aucun consommateur : `school_programs` = 1 ligne / 44 écoles, lu nulle part ailleurs | base LIVE ; `grep -rn "school_programs" lib/ \| grep -v structure/` = 0 | Un module vendu (plans Pro/Institutionnel) qui n'alimente rien | **M** (brancher) ou **S** (retirer) |
| 9 | `emploi-du-temps` | Le statut de publication ne gouverne rien | 2 lecteurs, tous deux dans la page (`emploi_du_temps_screen.dart:173`, `_overview.dart:28`, `:118`) ; `timetableSlotsProvider` ne filtre pas le statut | Un brouillon est lu comme un EDT officiel | **M** |
| 10 | `emploi-du-temps` | Trame absente de 37 écoles sur 44 ; les 7 pourvues sont toutes `formation_pro` | base LIVE `school_periods` : 42 lignes, 7 écoles, `cycle_code = formation_pro` uniquement | Grilles sans ossature ni pause au 1er octobre | **M** (amorçage) |
| 11 | `matieres` | Affectations et classes affectables non bornées à l'année | `class_subjects_provider.dart:54-79` et `:119-127` (aucun `academic_year_id`), vs KPI borné `subjects_provider.dart:35-44` | Au renouvellement d'année : classes de l'an dernier proposées, deux chiffres sur la même page | **S** |
| 12 | `programmes` | Aucun tri sur une liste qui dépasse 20 lignes | état de l'écran sans `_sort` (`programmes_screen.dart:85-91`) | Confort | **S** |

### D.2 Doublons et redondances — vue consolidée

| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|
| 1 | `classes` ↔ `niveaux` | **Le compte d'élèves d'une classe** — B omet le filtre `students.is_active`, que A documente longuement | `class_provider.dart:86-90` (`ce.status='active' AND COALESCE(s.is_active,1) <> 0`) | `academic_structure_provider.dart:118-119` (`ce.status='active'` seul) | **Chiffre divergent** : un élève désactivé occupe encore une place sur `/user/structure` mais pas sur `/user/classes` | Un `classEnrollmentCountSql` partagé ; A fait foi |
| 2 | `classes` ↔ `niveaux` | **Le formulaire de création/édition d'une classe** | `classes_parts.dart:640-941` (`AdminFormDialog` + `runModuleWrite` + `canProvider`) | `academic_structure_class_form.dart:7-265` (`InscriptionModalFrame` + `try/catch` nu, **sans permission**) | Duplication fonctionnelle **avec divergence de sécurité** | Un `ClassFormDialog` unique, `levelId` verrouillé par contexte (`ClassContextBanner`) |
| 3 | `emploi-du-temps` ↔ `classes`/`niveaux` | **La salle** : registre typé vs texte libre | `rooms_provider.dart` / `timetable_slots.room_id` | `classes.room`, saisi `classes_parts.dart:888` et `academic_structure_class_form.dart:214-218` | Deux foyers pour un même objet | `rooms` ; `classes.room` → `room_id` |
| 4 | `emploi-du-temps` (interne) | **La trame horaire** : codée en dur vs configurable | `timetable_provider.dart:26-36` (`kStdPeriods`, 9 séances 55 min) | `school_periods` (`school_periods_provider.dart:60-70`) | Reliquat pré-migration 0016 | `schoolPeriodsProvider` ; `kStdPeriods` → gabarit de seed |
| 5 | `niveaux`, `classes`, `programmes` | **Palette / libellés / ordre des cycles**, recopiés 3 fois | `academic_structure_screen.dart:21-40` et `classes_screen.dart:23-49` | `programmes_screen.dart:27-58` | Copie littérale (déjà divergente : `'fp'` présent dans 2 des 3) | `scope_drilldown_panel.dart` (`scopeCycleColor/Name/Order`) |
| 6 | `classes` (dossier) | **Le cycle de vie des inscriptions vit dans le provider des classes** | `class_provider.dart:396-722` (13 fonctions `class_enrollments`) | consommé par `features/students/` | Mauvais foyer, pas une copie | `features/students/providers/enrollments_provider.dart` |

*(Faux positif écarté : `calendar_holidays.dart` et `edt_calendar_tab.dart`
traitent la même table `school_holidays`, mais l'un est explicitement en lecture
seule et renvoie vers l'autre pour écrire — `calendar_holidays.dart:16-17`.
Ce n'est pas un doublon, c'est la doctrine « un seul endroit pour écrire ».)*

### D.3 Données partagées HORS catégorie

| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|
| `classes` + dénormalisés `cycle_code`/`level_code`/`level_order`/`filiere_*` | `classes`, `niveaux` | `eleves`, `inscriptions`, `transferts`, `documents`, `annuaire`, `notes`, `bulletins`, `conseils`, `passage`, `examens`, `stages`, `presences-eleves`, `discipline`, `orientation`, `cantine`, `infirmerie`, `bibliotheque`, `paiements-eleves` | Les dénormalisés sont posés à la création et **jamais recalculés** | Une classe créée hors `createStructuredClass` fausse tous les KPI par cycle/niveau de la plateforme, en silence |
| `classesForModuleProvider(slug)` | `classes` | 12 modules (`grep -rn "classesForModuleProvider("`) | Chaque appelant passe **son** slug | Passer le mauvais slug applique le périmètre d'un autre module (défaut historique corrigé, non revenu) |
| **`teacher_subjects`** | `matieres` (`setAssignmentTeacher`, `class_subjects_provider.dart:200-248`) | **tous** — `scopedClassIdsProvider` (`permissions_provider.dart:161`), `staff_directory_provider`, `staff_dossier_provider`, `admin_groupe/student_dossier_provider` | `staff_id` est un `profiles.id` ; une ligne = « ce prof enseigne cette matière dans cette classe » | **Le verrou 4 de toute la plateforme dépend d'un écran de la catégorie.** Catalogue vide → plus d'affectation → `own_classes` = 0 classe = application vide |
| `class_subjects.coefficient` | `matieres` | `bulletins` (`bulletins_provider.dart:142`, un **`JOIN`**), `notes`, `conseils`, `passage` | Le coef effectif est `coefficient ?? subjects.coefficient` | Un coef changé change moyennes, rangs et mentions de toute l'école, sans trace visible |
| `class_subjects.weekly_hours` | `matieres` | `emploi-du-temps` (`classRequiredHoursProvider`, `timetable_provider.dart:370-392`) | Somme par classe = volume hebdomadaire requis | Non saisi → « Conformité 0 % » affiché comme un fait (4 564/4 564 renseignés en prod : OK aujourd'hui) |
| `subjects` | `matieres` | `notes`, `bulletins`, `examens`, `emploi-du-temps`, `cahier-textes`, `programmes` | Une matière = une identité, jointe par id | Non synchronisée → colonnes matière blanches (LEFT JOIN) et **bulletins sans lignes** (JOIN) |
| `academic_years` / `trimesters` / `sequences` / `school_holidays` | **hors catégorie** (Réseau + écran natif Calendrier) | toute la catégorie | `yearReadOnlyProvider` = `y.isLocked \|\| !y.isCurrent` | Aucune année `is_current` → **toute la catégorie passe en lecture seule** (fiche `annees-scolaires-edition-verrou`) |
| `timetable_slots` | `emploi-du-temps` | `cahier-textes` **uniquement** | Le créneau pré-remplit une séance | Rupture invisible : personne d'autre ne s'en sert |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|
| `classes` | CSV seul (`class_provider.dart:342`) | — | — | non | **Manque** — la liste des classes est un état officiel |
| `niveaux` | **aucune** | — | — | non | **Manque** — structure & effectifs par niveau |
| `matieres` | PDF (`subjects_pdf_service.dart`) | oui (`:22-74`) | oui (`subjects_screen.dart:147`) | non | **Conforme avec réserve** : `OfficialPdfKit.table` (`:74`) et non `tableSection` ; pas de mention « vue filtrée » alors que les lignes exportées sont `filtered` (`subjects_screen.dart:246`) |
| `programmes` | PDF (`programmes_pdf_service.dart`) | oui | oui (`programmes_screen.dart:236`) | **oui, `:214`** | **Non conforme** — voir ci-dessous |
| `emploi-du-temps` | PDF fiche + livret | oui (`emploi_du_temps_pdf_service.dart:39,83,167`) | oui (`emploi_du_temps_bulk_actions.dart:262,297`) | non | **Conforme avec réserve** : le livret exporte `all` et non `shown` (`emploi_du_temps_screen.dart:329`) — filtre à l'écran, document complet, sans mention |
| `cahier-textes` | **aucune** | — | — | non | **Manque le plus net de la catégorie** (pièce d'inspection) |

Trois précisions sur `programmes` :

1. **`Printing.layoutPdf(` `programmes_pdf_service.dart:214`** est bien actif en
   source, mais dans `printDoc()`, **que personne n'appelle** :
   `grep -rn "ProgrammesPdfService\." lib/` → seulement `buildPdf` et
   `downloadDoc` (`programmes_screen.dart:239,241`). L'écran passe bien par
   l'aperçu. La correction reste due (§4-1), elle est sans risque.
2. **Risque `TooManyPagesException`** : `_cycleSection`
   (`programmes_pdf_service.dart:133-176`) construit **un `pw.Padding > pw.Column`
   par cycle**, contenant tous ses niveaux et leurs tableaux. Un `pw.Column`
   n'est pas fractionnable par `MultiPage` : un cycle plus haut qu'une page ne
   produit **aucun document**, pas un document tronqué. C'est le motif exact que
   `tableSection` existe pour éviter (`official_pdf_kit.dart:509-517`).
   Le balayage transversal ne l'avait pas vu : il cherchait les tables
   construites à la main, pas les tables du kit enfermées dans un conteneur
   non fractionnable.
3. **Aucun PDF de la catégorie n'écrit « vue filtrée »**, alors que la
   convention existe (`core/services/fiche_detail_pdf.dart:204`,
   `features/tutelle/services/tutelle_pdf_service.dart:83`).

**⚠️ Correction au balayage transversal `22-transversal-documents.md`.** Son
tableau « Écrans de liste sans aucune sortie » annonce **Recherche : non** pour
`classes_screen.dart`, `academic_structure_screen.dart` et
`cahier_textes_screen.dart`. Les trois **ont** une recherche : elle vit dans un
fichier `part`, que le balayage n'a pas lu —
`classes_parts.dart:53-59` (`TextField` « Rechercher (nom, salle, prof.) »),
`academic_structure_detail.dart:209-214` (« Rechercher une classe… »),
`cahier_textes_parts.dart:42-46` (« Rechercher (titre, contenu…) »).
La mesure de profondeur est à refaire par **bibliothèque** (fichier + ses
`part`), pas par fichier. Idem pour `classes_screen.dart`, rangé « sans aucune
sortie » alors qu'il exporte un CSV.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|
| 1 | `emploi-du-temps` | **Étiquette mensongère** | `emploi_du_temps_overview.dart:143-147` | « Brouillon — non publié · **En construction — invisible des enseignants/élèves** » / « Publié · Visible des enseignants, élèves et parents » | `timetableSlotsProvider` ne filtre ni `version_id` ni le statut : le brouillon est visible de tous les lecteurs du module. Et aucun espace élève/parent n'existe (`/user/espace-parent` = placeholder) |
| 2 | `emploi-du-temps` | **Case qui ne fait rien** | `timetable_provider.dart:348-365` (`publishTimetableVersion`) | Publier / dépublier un emploi du temps | Change un `status` que **2 lecteurs** consultent, tous deux dans la même page (`emploi_du_temps_screen.dart:173`, `_overview.dart:28`, `:118`). Aucun autre module, aucun autre rôle |
| 3 | `matieres` | **Écran vide sans message** | `subjects_provider.dart:46` | « Aucune matière — Créez les matières enseignées » (`subjects_screen.dart:254`) | 94 matières sont bien présentes sur le poste ; la requête les écarte. L'état vide invite à créer un doublon d'un catalogue existant |
| 4 | `niveaux` | **Porte de création ouverte** | `academic_structure_niveaux.dart:59-60` | Un « + » disponible dès qu'on sait lire | La RLS exige `classes.create` : 38 membres « Secrétariat » obtiendront un 42501, code fatal — le lot PowerSync entier du poste est jeté, sans message |
| 5 | `niveaux` | **Succès annoncé à tort** | `academic_structure_class_form.dart:106-109` | « Classe créée. » | L'écriture est locale ; le refus serveur arrive plus tard, hors du `try/catch`. Pas de `runModuleWrite`, donc pas de remontée |
| 6 | `niveaux` vs `classes` | **Deux effectifs pour la même classe** | `academic_structure_provider.dart:118-119` vs `class_provider.dart:86-90` | Le même nombre d'élèves sur deux écrans | Un élève désactivé compte encore sur `/user/structure` |
| 7 | `emploi-du-temps` | **Ratio incohérent** | `emploi_du_temps_screen.dart:208` + `:286-287` | « Classes couvertes X / Y » | X est calculé sur des créneaux non bornés, Y sur des classes bornées : X peut dépasser Y pour un enseignant restreint |
| 8 | `emploi-du-temps` | **Libellé faux sur une donnée réelle** | `school_periods_provider.dart:16-24` (`kPeriodKinds`, `orElse: ('cours', 'Séance de cours')`) | Le type de chaque bande de la trame | En base : 14 lignes portent `kind = 'pause'`, valeur absente du catalogue Dart (`cours\|recreation\|pause_meridienne`, migration `0016:16`, **sans CHECK**). L'onglet Trame les affiche « **Séance de cours** », couleur et icône de cours, pendant que la grille les traite en pause (`!isCourse`) |
| 9 | `classes`, `matieres`, `programmes` | `catch (_) {}` en action groupée | `classes_screen.dart:143`, `subjects_screen.dart:126`, et l'équivalent de `programmes_bulk` | « n classe(s) archivée(s) » | Le compteur est honnête, mais les échecs individuels disparaissent sans aucun message |

### D.6 Dette de structure

**Deux fichiers seulement dépassent 500 lignes dans toute la catégorie** — les
76 fichiers de `features/structure/` sont tous conformes, ce qui est
remarquable et mérite d'être dit en une ligne.

| Fichier | Lignes | Couture de découpe proposée |
|---|---|---|
| `features/classes/screens/classes_parts.dart` | **1 278** | Trois coutures nettes déjà visibles dans le fichier : `classes_filters.dart` (`_ClassFilterBar`, `_FilterDropdown`, `_ViewToggle`, `_ResultHeader`, `_ClassBulkBar`, `_BulkBtn` — l. 9-205 et 1033-1102), `classes_table.dart` (`_ClassTable`…`_ClassGridCard`, l. 206-634), `classes_form.dart` (`_ClassFormSheet` + champs locaux, l. 640-1032), `classes_charts.dart` (l. 1103-1278). Aucune des quatre n'a de dépendance croisée autre que les helpers `_cyc*` du fichier principal. |
| `features/classes/providers/class_provider.dart` | **722** | La couture est métier, pas cosmétique : **les 13 fonctions `class_enrollments` (l. 361-722) ne sont pas des classes**. Les sortir vers `features/students/providers/enrollments_provider.dart` ramène le fichier à ~360 lignes et remet chaque écriture dans le module qui la gouverne (cf. D.2 #6). |

⚠️ `test/dette_des_fichiers_de_500_lignes_test.dart` est un **cliquet** :
`_plafond = 82` et le second test exige que l'écart au réel reste ≤ 10. Ces deux
découpages font descendre le compte — il faudra abaisser `_plafond` dans le même
commit.

À ajouter au même passage : `test/porte_de_creation_test.dart` doit couvrir
`academic_structure_niveaux.dart` (porte « + » de ligne, pas seulement les
`AdminEmptyState`), et `test/perimetre_par_module_test.dart` doit exiger
`classScopeClause` dans `academic_structure_provider.dart` et
`timetable_provider.dart`.

### D.7 Désalignements catalogue ↔ code

1. **Le module `niveaux` ne gère pas les niveaux.** Son écran
   (`AcademicStructureScreen`) affiche Cycle ▸ Niveau ▸ Classe mais **n'écrit
   que des classes** : le référentiel `school_levels`/`education_levels` est
   gouverné par l'admin groupe (RLS vérifiée, fiche
   `structure-academique-livree`). Le découpage du catalogue est donc **inexact
   sur deux points** :
   - le nom « Niveaux » promet un pouvoir que l'écran n'a pas ; il faudrait le
     lire « Structure académique » (c'est d'ailleurs son titre à l'écran,
     `academic_structure_screen.dart:47`) ;
   - `niveaux` et `classes` **écrivent la même table**, avec deux formulaires.
     **Verdict : le découpage n'est pas juste.** Deux formes défendables — soit
     `classes` absorbe `niveaux` (un module « Structure & classes », avec une
     vue liste et une vue arbre), soit `niveaux` devient strictement une
     **consultation** du référentiel reçu du réseau et rend la création de
     classe à `classes`. La seconde est la plus fidèle à la RLS : l'école
     *reçoit* sa structure et *pose* ses classes. Dans les deux cas, un seul
     formulaire.

2. **Le calendrier scolaire n'a pas de module — et c'est correct.**
   `/user/calendrier` (`SchoolCalendarScreen`, 385 l + 3 parts) gère
   années → trimestres → séquences → jours non ouvrés → reconduction des
   classes. Il est **hors catalogue et assumé comme tel**, avec les trois
   verrous cohérents : entrée native déclarée (`socle_natif.dart:139-147`),
   garde de rôle au routeur (`app_router.dart:287-291`), garde de rôle à
   l'écran (`school_calendar_screen.dart:33-35`), et **le garde reproduit en
   base** (`auth_est_chef_etablissement()`, migration 0128). La note de la fiche
   `modules-acces-hierarchie` (« le catalogue n'a PAS de module pour
   années/trimestres/séquences ») est donc **résolue, pas ouverte**.
   **Mais une conséquence n'est pas résolue** : la *saisie* des jours non ouvrés
   vit dans le tiroir de `emploi-du-temps` (`edt_calendar_tab.dart`), tandis que
   `/user/calendrier` ne fait que les lire (`calendar_holidays.dart:16-17`).
   Comme `EdtSettingsView` n'a pas de `ModuleScaffold`
   (`edt_settings_screen.dart:65`), le tiroir s'ouvre depuis un écran natif
   **sans verrou de plan** : une école au plan **Découverte**
   (`classes, matieres, niveaux` seulement, vérifié en base) atteint ainsi
   salles, trame et disponibilités. Le verrou 2 est contourné dans un sens, et
   dans l'autre l'école ne pourrait pas saisir ses vacances sans passer par un
   module qu'elle n'a pas achetée. **Un écran natif ne doit pas avoir son
   chemin d'écriture à l'intérieur d'un module vendable.**

3. **Plan `Standard` sans `programmes`** (vérifié en base) : la sidebar masque
   l'entrée et le routeur bloque la route — comportement correct, mais l'écart
   avec `Pro` porte sur un module dont la table compte 1 ligne au total.
   Argument de vente creux.

4. **`features/structure/providers/class_rollover.dart`** (149 l) est consommé
   par `features/evaluation/screens/passage_screen.dart:12` (module `passage`)
   et par l'écran natif Calendrier (`calendar_rollover.dart:58`). Provider
   partagé rangé dans la catégorie Enseignement : à signaler, pas à déplacer —
   la reconduction *crée des classes*, sa place ici se défend.

5. **Table morte : plus aucune trace.** `school_education_levels` /
   `school_education_programs` ne sont plus référencées nulle part dans
   `epilote/lib` ni dans les sync-rules — seule subsiste la ligne de
   commentaire qui raconte la panne
   (`admin_groupe/providers/education_provider.dart:240`). ✅ Le défaut fondateur
   de cette catégorie est purgé.
   **La chasse a néanmoins produit deux trouvailles de la même famille** :
   `school_programs` (écrit, lu par son seul écran, 1 ligne en production) et
   `lesson_entries.trimester_id` (colonne synchronisée, jamais écrite ni lue).

---

## E. Les cinq choses à faire en premier

1. **Rendre les matières visibles.** Retirer `AND s.school_id = ?` de
   `subjects_provider.dart:46` au profit de
   `AND (s.school_id = ? OR (s.school_id IS NULL AND s.group_id = ?))` — la
   forme exacte qu'emploie déjà `programmesProvider`
   (`programmes_provider.dart:102`) — et trancher ce que `createSubject` écrit
   (`:104-108`). Sans cela, le catalogue est vide, l'affectation des professeurs
   est impossible, et le verrou 4 de toute la plateforme se vide avec lui.
   *Gain : maximal · Effort : S · Entrée :
   `features/structure/providers/subjects_provider.dart`.*
   ⚠️ Vérifier au passage que la sync-rule `by_group` de `33ecf02` est bien
   **déployée** au dashboard PowerSync Cloud — le commit prévient qu'elle ne
   prend effet qu'après.

2. **Fermer la porte de création de `/user/structure`.** Poser
   `PermissionGate(slug:'classes', action:'create')` sur le « + »
   (`academic_structure_niveaux.dart:59`), gater édition et archivage sur
   `update`/`delete`, et faire passer les trois écritures par `runModuleWrite`
   (`academic_structure_class_form.dart:77-116`). 38 membres « Secrétariat » y
   perdent aujourd'hui, à chaque clic, tout le lot d'écritures en attente de
   leur poste. Ajouter le fichier à `_kPortes` dans
   `test/porte_de_creation_test.dart`.
   *Gain : évite une perte de données à la rentrée · Effort : S · Entrée :
   `features/structure/screens/academic_structure_niveaux.dart`.*

3. **Appliquer le périmètre sur `niveaux` et `emploi-du-temps`.** Ajouter
   `classScopeClause(ref, 'niveaux', column: 'c.id')` à
   `academic_structure_provider.dart:134-138` et
   `classScopeClause(ref, 'emploi-du-temps', column: 't.class_id')` à
   `timetable_provider.dart:116-118`, puis corriger le KPI
   « Classes couvertes » (`emploi_du_temps_screen.dart:208`) pour qu'il compte
   sur le même ensemble que son dénominateur. 201 enseignants sont en
   `own_classes` sur ces deux modules ; la fiche mémoire qui affirmait
   « aucune fuite mesurée » doit être corrigée.
   *Gain : referme le seul verrou 4 encore ouvert · Effort : M · Entrée :
   `features/structure/providers/timetable_provider.dart`.*

4. **Dire la vérité sur la publication de l'emploi du temps** — ou la rendre
   vraie. Aujourd'hui la barre affirme « invisible des enseignants/élèves »
   (`emploi_du_temps_overview.dart:146`) alors que rien ne filtre le brouillon.
   Le choix minimal et honnête : borner `timetableSlotsProvider` au
   `version_id` publié pour qui n'a pas `emploi-du-temps.update`, et retirer
   « élèves et parents » du libellé tant que ces espaces n'existent pas.
   *Gain : supprime la protection annoncée mais absente · Effort : M · Entrée :
   `features/structure/screens/emploi_du_temps_overview.dart`.*

5. **Donner un PDF au cahier de textes, et un au couple structure/classes.**
   Le cahier de textes est la pièce que l'inspection réclame et il n'a aucune
   sortie ; commencer par écrire `trimester_id` dans `createLessonEntry`
   (`lesson_log_provider.dart:134-147`) pour que le document puisse se borner à
   un trimestre. Dans le même lot : la liste des classes (PDF, pas seulement
   CSV) et l'état « structure & effectifs par niveau ». Utiliser
   `OfficialPdfKit.tableSection` — et en profiter pour reprendre
   `programmes_pdf_service.dart:133-176`, dont le `pw.Column` par cycle peut ne
   produire **aucun** document, et supprimer le `Printing.layoutPdf(` de sa
   ligne 214.
   *Gain : trois états officiels manquants + un document qui peut ne pas sortir ·
   Effort : M · Entrée :
   `features/structure/screens/cahier_textes_screen.dart`.*
