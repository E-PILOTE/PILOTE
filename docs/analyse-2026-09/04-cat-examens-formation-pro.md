# EXAMENS & CERTIFICATION · FORMATION PROFESSIONNELLE — analyse

**Slugs catégories** : `examens` (1 module) · `formation-pro` (1 module)
**Code concerné** : `features/examens/` (33 fichiers, 9 453 l.) · `features/stages/` (13 fichiers, 3 916 l.)
**Date** : 2026-09-08 · **Périmètre lu intégralement** (46 fichiers, 13 369 lignes) — aucun échantillonnage.

> Base LIVE interrogée via MCP Supabase (`wqpdamlnrwgozfvzjjpo`) pour tous les
> chiffres de production cités. 10 fiches mémoire ouvertes (liste en fin de
> rapport). Deux blocs A→E, un par catégorie.

---
---

# BLOC 1 — EXAMENS & CERTIFICATION (`examens`)

## A. Vue d'ensemble de la catégorie

Une catégorie, **un seul module**, **9 453 lignes** : le module le plus lourd du
catalogue, 1,8× le poids moyen par module de `features/students/` (5 179 l./module)
et 3,4× celui d'ÉVALUATION (2 758 l./module). Il couvre toute la chaîne d'État —
dérivation des classes d'examen, inscription des candidats, dossier pièce par
pièce avec scans, caisse des frais d'examen, numéros DEC, convocations,
transmission opposable à la DEC, saisie des résultats reçus, statistiques, et
vérification des prérequis de parcours.

Ce n'est pas un module, c'est **un espace applicatif rangé sous un seul
interrupteur**. La question posée en tête de mission — faut-il le scinder au
catalogue ? — est tranchée en **C** : *non au découpage du catalogue, oui au
découpage des responsabilités*, et les preuves du pourquoi sont dans **D.1**.

La catégorie n'a pas d'intrus ; elle a un **manque** : le socle DEC
(`exam_publications`, `exam_official_results`) n'est **pas** dans les sync-rules
(`grep -n "exam_official_results" powersync/config/sync-rules.yaml` → aucun
résultat), donc l'école ne voit jamais le chiffre OFFICIEL de son propre
établissement. Elle ne dispose que de son propre décompte.

---

## B. Fiche par module

### Examens — `examens`

| | |
|---|---|
| Route | `/user/examens` (+ `/user/examens/session/:id`) |
| Écrans | `ExamensScreen` — `features/examens/screens/examens_screen.dart` (296 l.)<br>`ExamSessionScreen` — `features/examens/screens/exam_session_screen.dart` (598 l.) |
| Tables lues | `classes`, `national_exams`, `exam_sessions`, `exam_candidates`, `class_enrollments`, `students`, `student_documents`, `internships`, `internship_companies`, `fee_structures`, `academic_years`, `student_payments`, `transmissions`, `schools` |
| Tables écrites | `exam_candidates` (INSERT/UPDATE/DELETE), `student_documents` (INSERT via `attachStudentDocumentOffline`, DELETE, UPDATE `is_verified`), `transmissions` + `transmission_items` (INSERT/UPDATE), `student_payments` (INSERT via `savePayment`) |
| Profondeur UI — accueil | **L2** — satisfaits 3,4,5,6,7,8,10 · manquant **n°9** (aucune sortie document) · n°1 et 2 sans objet (≈5 classes d'examen par école : 116 classes / 24 écoles en prod) |
| Profondeur UI — session | **L2** — satisfaits 1,3,4,5,6,7,8 · **n°9 présent mais DÉFAILLANT** (cf. D.4) · **n°10 non** (598 l.) · n°2 sans objet (l'ordre alphabétique intra-classe est celui qu'exige la DEC) |
| Sortie document | **non conforme — le document principal ne se génère pas** (détail D.4) |

**Ce que le module fait.** Il lit les classes d'examen dérivées par le serveur
(`classes.exam_id` / `exam_status`, jamais rejouées en Dart —
`examens_provider.dart:14-16`), inscrit les élèves à la session de leur diplôme,
tient leur dossier de pièces (déclarées ou scannées), encaisse les frais, colle
les numéros de la DEC, imprime convocations et liste, fige le dépôt en
transmission opposable, puis enregistre les résultats reçus.

**Ce qui manque.**

- ⛔ **La liste des candidats — LE document déposé au centre d'examen — ne se
  génère jamais.** `exam_export_service.dart:95-121` : 9 en-têtes,
  `flex: const [2, 7, 4, 4, 2, 4, 4, 4]` = **8 valeurs** (ligne 121).
  `OfficialPdfKit.table` fait `List.generate(headers.length, (i) => cell(…, flex[i], …))`
  (`core/services/official_pdf_kit.dart:722-727`) → `flex[8]` lève
  `RangeError`. Vérifié sur **les 45 appels à `OfficialPdfKit.table*` de
  tout `lib/` : c'est le seul déséquilibre**. Aucun test ne construit ce PDF
  (`grep -rl "buildCandidateListPdf\|ExamExportService" test/` → vide).
  **Impact : le geste central du module est mort** ; une école découvre à
  l'usage que « Liste des candidats » plante.
- ⛔ **Ce même document ne se pagine pas.** `exam_export_service.dart:90-121` :
  `OfficialPdfKit.frame(child: OfficialPdfKit.table(rows: <tous les candidats>))`
  dans un `pw.MultiPage`. Le kit documente que `frame()` enveloppe dans un
  `Padding` incapable de se scinder et que passer une page fait boucler
  `MultiPage` jusqu'à `TooManyPagesException`
  (`official_pdf_kit.dart:684-690`) ; le point d'entrée prévu est
  `tableSection` (bloc de `kRowsPerBlock = 28` lignes, `official_pdf_kit.dart:506`).
  En prod, **90 candidats maximum par école+session, 53 en moyenne** (47 lots
  mesurés) — trois fois la taille d'un bloc. Le correctif du `flex` seul ne
  suffira donc pas.
- **Aucune saisie en masse des résultats.** `exam_result_dialog.dart` est
  strictement par candidat (`showExamResultDialog(context, row: …)`,
  `exam_candidate_views.dart:110`). La DEC publie une **liste d'admis** ; il
  faut donc ouvrir 90 modales pour reporter une proclamation, alors que le
  module possède déjà exactement le patron nécessaire — le collage positionnel
  de `assignCandidateNumbers` (`exam_registration_provider.dart:388-448`).
  `can_import` est accordé au profil Secrétariat en base, **et aucun chemin
  d'import n'existe** (`grep -rn "'import'" features/examens` → aucun résultat).
- **`data_scope` n'est pas appliqué.** `classScopeClause` est utilisé par 15
  fichiers de `lib/` — dont `features/stages/providers/stages_provider.dart:142` —
  et **par aucun fichier de `features/examens/`**
  (`grep -rn "classScopeClause" features/examens` → vide). Or la base porte
  **7 lignes `profile_permissions` « Enseignant » sur `examens` en
  `data_scope = 'own_classes'`**. La RLS serveur, elle, ne filtre que par
  école (`exam_candidates_select` : `school_id = auth_school_id()`, aucun
  `class_id`). **Un enseignant voit donc toute l'école** : noms, dates de
  naissance, matricules, INE, état des dossiers, résultats et état de paiement
  de tous les candidats. Verrou 4 déclaré, non tenu.
- **Le verrou d'année n'est pas posé.** `yearReadOnlyProvider` est consommé par
  **31 écrans** de l'espace école (`grep -rln "yearReadOnlyProvider" features/`)
  ; `features/examens/` n'en fait pas partie. `ModuleScaffold` ne l'applique
  pas non plus (`features/navigation/widgets/module_scaffold.dart:44-70`).
  Sur une année archivée on peut donc encore inscrire, déposer, transmettre à
  la DEC et **encaisser**.
- **Déposer un dossier est moins protégé que le rouvrir.** Rouvrir exige
  `validate` (`exam_dossier_dialog.dart:59-60, 98`) ; déposer passe par la
  barre groupée rendue sous `if (canEdit && …)` avec `canEdit = 'update'`
  (`exam_session_screen.dart:274, 411` → `_bulkDeposit` l.180-201). L'acte
  engageant est gardé plus bas que son annulation.
- **Aucun bouton « Déposer » dans le dossier lui-même.**
  `grep -n "submitDossier\|Déposer" features/examens/widgets/exam_dossier_dialog.dart`
  → vide. Le geste naturel (ouvrir un dossier, cocher les pièces, déposer)
  n'existe pas : il faut fermer, retrouver la ligne, cocher la case, utiliser
  la barre groupée.
- **Le prérequis de diplôme n'est jamais vérifié à l'inscription.**
  `kPrerequisites` (`student_history_dialog.dart:20-27`) n'est lu qu'à
  l'ouverture manuelle du « Parcours » d'UN candidat
  (`grep -rn "kPrerequisites" lib/` → 1 lecture, l. 131). Le formulaire
  d'inscription (`exam_register_dialog.dart`) ne le consulte pas. Sur 300
  candidats au bac, la vérification annoncée dans la fiche mémoire
  (« signaler d'elle-même celui qui n'y a pas droit ») demande 300 clics.
- **`kPrerequisites` est une règle nationale gelée en Dart** et couvre **4 des
  17 diplômes actifs** (BAC, BEP, CAP, BTF — plus BAC_T/BAC_P hérités). BT,
  BTS, CFEEN, DCAF, DECS, DEMA, CQP, BAC_G, BEPC, CEPE : aucune règle. Le
  référentiel appartient au ministère (`/admin/referentiel-examens`,
  cf. `referentiel-examens-au-ministere.md`) — les prérequis devraient l'y
  rejoindre, comme les règles d'éligibilité.
- **`written_to`, `practical_from/to`, `results_published_at` ne sont jamais
  lus par l'école.** `ConvocationService` accepte pourtant `writtenTo`
  (l. 51, 86, 216) et sait écrire « du X au Y » (l. 111-113) — **aucun
  appelant ne le passe** (`exam_session_screen.dart:_exportConvocations`
  l.152-176). En base : `written_to` renseigné sur **11 sessions sur 11** qui
  ont un `written_from`. Toutes les convocations du pays annoncent une date
  unique au lieu de la période réelle des épreuves.
- **La liste PDF omet la filière/série et le lieu de naissance.** Les listes
  publiées par la DEC portent « matricule, nom, sexe, date/lieu de naissance,
  série, mention » (fiche `archives-publications-dec.md`). `ExamCandidateRow`
  porte `filiereLabel`, `CandidateFile` porte `placeOfBirth` — ni l'un ni
  l'autre ne figure dans les colonnes de `buildCandidateListPdf`
  (l. 95-105). Pour un bac technique, la série **est** l'information de tri
  du jury.
- **La transmission n'a aucun document et aucun détail.** `transmission_items`
  est écrit (`transmission_provider.dart:224`) et **lu nulle part**
  (`grep -rn "transmission_items" lib/` → 2 occurrences : l'INSERT et le
  schéma). La tuile de transmission n'est pas cliquable
  (`transmissions_panel.dart:266-327`). Le `snapshot` figé — « feuille de
  frappe DEC et bordereau des dossiers papier » selon le dialogue lui-même
  (l. 129-131) — ne s'imprime pas. Une transmission est donc une preuve qu'on
  ne peut ni relire ni produire.
- **Le rectificatif est promis et injoignable.** Le dialogue de confirmation
  écrit « une correction se fait par rectificatif » (`transmissions_panel.dart:130`)
  ; `createTransmission` accepte `correctsId` et `kind`
  (`transmission_provider.dart:145-147`) ; **aucun appelant ne les passe**
  (`grep -rn "correctsId" features/examens` → uniquement le provider).
- **Rien n'empêche de figer une liste incomplète.** `_bulkDeposit` refuse les
  dossiers incomplets (`exam_session_screen.dart:181`), mais
  `TransmissionsPanel._submit` fige `scoped` tel quel
  (`exam_session_screen.dart:477-484`) sans compter ni signaler les dossiers
  incomplets ou les candidats sans numéro.
- **Le comptable ne peut pas encaisser les frais d'examen.** Le bouton de
  paiement est sous `canEdit = examens/update`
  (`exam_candidate_views.dart:99, 76-96`). En base, le profil « Comptabilité »
  a `examens` en **lecture seule** (`can_update = false`). La caisse d'examen
  est donc réservée au secrétariat et à la direction. La RLS, elle, l'aurait
  admis : `payments_insert` accepte `auth_module_permet(ARRAY['paiements-eleves','inscriptions','examens'],'create')`.
- **L'anomalie « classe à qualifier » n'a aucune action.**
  `ExamAnomalyCard` (`examens_widgets.dart:442-505`) liste les classes et
  s'arrête là. Les deux gestes correcteurs vivent ailleurs — saisir la filière
  (module `classes`, `classes_parts.dart:906-913`) ou ajouter une règle
  (espace ministère) — et l'écran ne les nomme pas. Par ailleurs
  `exam_override_id` / `exam_excluded`, annotés « saisissable » dans le schéma
  (`services/powersync/powersync_schema.dart:352-353`), sont **lus** par 4
  providers et **écrits par aucune UI** (`grep -rn "exam_override_id" lib/`).
- **Aucune saisie de `schools.dec_code`** — 0 école renseignée en prod, alors
  que c'est la seule clé de jointure fiable des publications DEC par
  établissement (`archives-publications-dec.md`). Déjà signalé dans la fiche,
  toujours ouvert.
- **Aucune sortie sur la page d'accueil** du module : ni PDF ni CSV
  (`grep -n "showPdfPreviewDialog" features/examens/screens/examens_screen.dart`
  → vide). L'état d'avancement des inscriptions par diplôme est pourtant ce
  qu'un chef d'établissement emporte en réunion.

**Ce qui est en double.**

- **`updateDossier` est du code mort et une seconde règle de complétude.**
  `exam_registration_provider.dart:290-303` recalcule `missing_documents` et
  `dossier_status` par sa propre logique, ignorant fichiers attachés,
  déclarations et attestation de stage. Le foyer réel est
  `recomputeDossier` (`exam_dossier_actions.dart:186-244`). Aucun appelant
  (`grep -rn "updateDossier" lib/` → seule la déclaration). **À supprimer**,
  avant qu'un écran ne s'en serve.
- **`kListOrangeLocal` recopie `kListOrange`.**
  `transmissions_panel.dart:342` (`const kListOrangeLocal = Color(0xFFFF6B35)`)
  vs `core/widgets/list_chrome.dart:29` (`const kListOrange = Color(0xFFFF6B35)`).
  Même valeur, deux définitions — et l'en-tête d'`examens_widgets.dart:11-12`
  interdit explicitement les couleurs en dur.
- **Trois copies du jeu « diplômes exigeant un stage », déjà divergentes.**
  `admin_groupe/providers/ministry_exam_rows.dart:45` =
  `{'BAC','BAC_T','BAC_P','BAC_TP'}` · `stages/providers/stages_provider.dart:25`
  = `{'BAC','BAC_T','BAC_P'}` · `super_admin/providers/super_exams_provider.dart:31`
  = `{'BAC','BAC_T','BAC_P'}`. **`BAC_TP` n'est que dans la première.** Sur une
  base portant encore ce code, le cockpit ministériel signalerait une école « à
  risque » que le module Stages de cette école déclare en règle. Foyer proposé :
  une constante unique dans `features/examens/models/` (déjà le foyer partagé
  de `exam_stats.dart`), importée par les trois espaces.
- **Deux définitions de « l'attestation de stage est délivrée ».** Côté examens :
  `attestation_issued_at IS NOT NULL`, sans condition de statut
  (`exam_dossier_provider.dart:162` et `exam_dossier_actions.dart:237`). Côté
  stages : la même chose **plus** `i.status IN ('termine','valide')`
  (`stages_provider.dart:180`). Foyer proposé : la règle côté stages (le module
  producteur), lue par le pont.

**Ce que ce module partage.**

- **Produit** : `exam_candidates.result` → consommé par `passage` (clôture des
  classes d'examen, `features/evaluation/providers/cloture_examen_provider.dart:284-288, 372-377`,
  seul écrivain de `graduated`) ; `exam_candidates.*` → cockpit ministériel
  `/admin/examens` et `/admin/resultats` (`admin_groupe/providers/admin_exams_provider.dart`,
  `ministry_exam_rows.dart`) et adoption `super_admin/providers/super_exams_provider.dart`.
- **Produit** : `features/examens/models/exam_stats.dart` est le **foyer unique
  de la règle « taux sur résultats connus »** pour toute la plateforme —
  importé par `admin_groupe/providers/admin_exams_provider.dart:4`,
  `ministry_exam_rows.dart:1`, `admin_regional_view.dart:24`,
  `admin_exams_breakdown.dart:4`. Sain, mais **mal rangé** (cf. D.7).
- **Produit** : `student_payments` (frais d'examen) → module `paiements-eleves`
  et revenu du groupe, sans chemin parallèle (`exam_payment_dialog.dart:249-262`
  appelle `savePayment` de Finance).
- **Consomme** : `classes.exam_id/exam_status` (dérivés serveur, module `classes`
  pour la filière) · `class_enrollments` (module `inscriptions`) · `students`
  (module `eleves`) · `fee_structures` (module `frais-scolarite`, portée groupe,
  posé par le ministère) · `internships.attestation_issued_at` (module `stages`)
  · `academic_years` (socle) · `student_documents` (module `documents`).
- **Consomme du ministère** : `national_exams`, `exam_sessions`,
  `exam_eligibility_rules` (référentiel, écrit dans `/admin/referentiel-examens`,
  RLS ouverte à tout `admin_groupe` — décision gelée, cf. fiche).

---

## C. La question de premier ordre — faut-il scinder `examens` ?

**Le module couvre neuf métiers.** Décomposition exhaustive (somme = 9 453) :

```
 1 163  A. Pilotage des classes d'examen (accueil)        3 fichiers
 3 417  B. Inscription / candidatures / écran Session    10 fichiers
 1 373  C. Dossier de candidature (pièces, scans)         6 fichiers
   724  D. Frais d'examen (caisse)                        4 fichiers
   264  E. Numéros de candidat (collage DEC)              1 fichier
   617  F. Transmission à la DEC (acte opposable)         2 fichiers
   743  G. Résultats & statistiques                       3 fichiers
   607  H. Documents (liste, convocations, CSV)           2 fichiers
   545  I. Parcours & prérequis de l'élève                2 fichiers
```

La description vendue au catalogue en cite **cinq** (« Classes d'examen,
candidatures…, dossiers, convocations et résultats ») et **omet les quatre
autres** — dont la caisse et la transmission, les deux qui engagent
respectivement l'argent et la responsabilité de l'établissement.

**Verdict : NE PAS scinder le catalogue. Scinder les responsabilités.**

*Pourquoi pas le catalogue* — trois raisons, dans l'ordre de force :

1. **Une seule table, une seule politique.** Dossier, frais, numéro et résultat
   sont des **colonnes de la même ligne** `exam_candidates`, protégée par une
   politique unique (`exam_candidates_update` → `auth_module_permet(ARRAY['examens'],'update')`).
   Retirer « Résultats » du plan d'une école ne l'empêcherait pas d'écrire
   `result` : le module restant garde le droit d'`UPDATE` sur la ligne
   entière. **Un découpage catalogue sans découpage de tables est une
   séparation de façade** — exactement le travers que le §6 du socle appelle
   « deux écrans, deux vérités ».
2. **La chaîne est indivisible métier.** Vendre « Candidatures » sans
   « Transmission », c'est vendre une chaîne qui s'arrête juste avant l'acte
   qui vaut dépôt. Une école qui inscrit sans transmettre n'a rien fait.
3. **Le précédent `stages` montre ce qu'est un vrai second module** : table
   propre (`internships`), verbes RLS propres (mig 0143), alerte propre. Rien
   de tel n'existe à l'intérieur d'`examens`.

*Ce qu'il faut scinder à la place* — et c'est là que le problème de vente est réel :

- **La grille de verbes est sous-employée.** `examens` ne consomme que 4 verbes
  sur 10 (`create`, `update`, `validate`, `export` —
  `grep -n "canProvider" features/examens/**` → 6 sites). `update` est le
  fourre-tout : il ouvre **cocher une pièce, encaisser 5 000 F, saisir un
  résultat DEC et retirer une candidature**, tous rendus par le même
  `canEdit` (`exam_candidate_views.dart:99-133`). Quatre responsabilités, un
  interrupteur. Le levier existe déjà : `approve` (saisir le résultat reçu),
  `manage` (frais), `delete` (retrait) sont **déclarés en base, accordés à la
  Direction, et lus par zéro ligne de code**.
- **Le retrait est déjà désaligné de la base.** `unregisterCandidate`
  (`exam_registration_provider.dart:284`) fait un `DELETE`, l'UI le garde sur
  `update` (`exam_candidate_views.dart:120`) et sur `canEdit`
  (`exam_session_screen.dart:411`) — alors que la politique serveur
  `exam_candidates_delete` exige `examens/delete`. Aujourd'hui latent (tous
  les profils qui ont `update` ont `delete`) ; **le jour où une école crée un
  profil « saisie sans suppression », le retrait disparaîtra côté serveur sans
  message et le candidat reviendra à la synchro suivante.** C'est le défaut
  exact que `test/stage_correction_test.dart` a été écrit pour interdire côté
  stages, et qui n'a pas de gardien côté examens.
- **La caisse d'examen est le seul candidat sérieux à l'extraction** : c'est
  le seul sous-domaine qui écrit dans une **autre** table (`student_payments`)
  et relève d'un **autre** métier. Sans aller jusqu'au module séparé, faire
  porter le bouton par `paiements-eleves/create` (que la RLS accepte déjà)
  rendrait la caisse au comptable et retirerait le droit d'encaisser au
  secrétariat qui ne l'a pas demandé.

*Le problème de plan, lui, est réel et mesuré* : `examens` n'existe que dans
**Pro (50 000 F), Institutionnel (40 000 F) et Licence de tutelle**. Le plan
**Standard (30 000 F, 17 modules) ne le porte pas**. Un collège qui veut
seulement produire sa liste BEPC doit passer de 30 000 à 50 000 F/mois, +67 %.
Le levier n'est pas de scinder le module en deux lignes de catalogue (voir
raison 1), c'est de **descendre `examens` dans Standard et de garder les
sous-domaines à valeur (transmission opposable, caisse, statistiques) derrière
des verbes** — ce qui se pilote profil par profil, sans toucher aux tables.

---

## D. Synthèse de la catégorie EXAMENS

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `examens` | La liste officielle des candidats **plante** (9 en-têtes / 8 `flex`) | `exam_export_service.dart:95-121` + `official_pdf_kit.dart:722-727` ; unique sur 45 tables de `lib/` | Le document déposé au centre d'examen ne sort pas. Casse une session. | XS |
| 2 | `examens` | Ce même PDF n'est pas paginé (`frame`+`table` dans `MultiPage`) | `exam_export_service.dart:90-121` vs `official_pdf_kit.dart:518, 684-690` ; 90 candidats max/école+session en prod | Après correction du `flex`, le document reste absent au-delà de 28 lignes | S |
| 3 | `examens` | `data_scope = own_classes` non appliqué | `grep -rn "classScopeClause" features/examens` → vide ; 7 profils Enseignant en `own_classes` en base ; RLS sans `class_id` | Un enseignant lit l'état civil, les dossiers, les résultats et les impayés de toute l'école | S |
| 4 | `examens` | Aucune saisie en masse des résultats DEC | `exam_result_dialog.dart` par candidat ; `can_import` accordé, aucun chemin d'import | 90 à 300 modales pour reporter une proclamation ; le patron existe (`assignCandidateNumbers`) | M |
| 5 | `examens` | Verrou d'année absent | 31 écrans utilisent `yearReadOnlyProvider`, `features/examens/` non | Inscription, dépôt DEC et encaissement possibles sur une année archivée | XS |
| 6 | `examens` | Retrait de candidature gardé sur `update`, refusé par la RLS sur `delete` | `exam_candidate_views.dart:120` / `exam_session_screen.dart:411` vs politique `exam_candidates_delete` | Suppression silencieusement annulée à la synchro (latent aujourd'hui) | XS |
| 7 | `examens` | Dépôt (`update`) moins gardé que réouverture (`validate`) | `exam_session_screen.dart:274, 411` vs `exam_dossier_dialog.dart:59-60` | L'acte engageant est ouvert plus largement que son annulation | XS |
| 8 | `examens` | Pas de bouton « Déposer » dans le dossier | `grep -n "submitDossier" widgets/exam_dossier_dialog.dart` → vide | Le geste naturel du secrétariat n'existe pas | XS |
| 9 | `examens` | Prérequis jamais vérifié à l'inscription ; couvre 4 diplômes sur 17 | `kPrerequisites` lu 1 fois (`student_history_dialog.dart:131`) ; 17 diplômes actifs en base | Un candidat inéligible est découvert au comptoir DEC | M |
| 10 | `examens` | `written_to` / `practical_*` jamais transmis aux convocations | `convocation_service.dart:51, 86, 216` sans appelant ; 11/11 sessions renseignées | Toutes les convocations annoncent une date au lieu d'une période | XS |
| 11 | `examens` | Transmission sans document ni détail ; `transmission_items` jamais lu | `grep -rn "transmission_items" lib/` → INSERT + schéma | La preuve opposable ne peut être ni relue ni imprimée | M |
| 12 | `examens` | Rectificatif promis, injoignable | `transmissions_panel.dart:130` vs `grep -rn "correctsId" features/examens` | Une liste erronée ne peut pas être corrigée dans l'app | S |
| 13 | `examens` | Rien n'empêche de figer une liste avec dossiers incomplets | `exam_session_screen.dart:477-484` (aucun garde, contrairement à `_bulkDeposit` l.181) | Une transmission opposable part avec des dossiers irrecevables | XS |
| 14 | `examens` | La liste PDF omet filière/série et lieu de naissance | `exam_export_service.dart:95-105` ; `place_of_birth` renseigné sur 3 034 élèves / 10 364 | La série est l'axe de tri du jury du bac technique | S |
| 15 | `examens` | Le comptable ne peut pas encaisser les frais d'examen | Bouton sous `examens/update` (`exam_candidate_views.dart:99`) ; profil Comptabilité en lecture seule sur `examens` | La caisse d'examen échappe au métier de la caisse | XS |
| 16 | `examens` | L'anomalie « à qualifier » n'a aucune action ; `exam_override_id`/`exam_excluded` jamais écrits | `examens_widgets.dart:442-505` ; `grep -rn "exam_override_id" lib/` (4 lectures, 0 écriture) | Une classe terminale non qualifiée reste sans issue côté école | S |
| 17 | `examens` | Aucune saisie de `schools.dec_code` | 0 école renseignée en base | Les publications DEC par établissement ne se rattachent à rien | S |
| 18 | `examens` | Aucune sortie sur la page d'accueil du module | `grep -n "showPdfPreviewDialog" screens/examens_screen.dart` → vide | L'état des inscriptions par diplôme ne s'emporte pas en réunion | S |

### D.2 Doublons et redondances — vue consolidée

| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|
| 1 | `examens` | Règle de complétude d'un dossier | `exam_registration_provider.dart:290-303` (`updateDossier`, **mort**) | `exam_dossier_actions.dart:186-244` (`recomputeDossier`) | Code mort + 2ᵉ vérité | `recomputeDossier` — supprimer `updateDossier` |
| 2 | `examens`, `stages`, espace Réseau, espace Fondateur | Jeu des diplômes exigeant un stage — **déjà divergent** (`BAC_TP` sur un seul) | `admin_groupe/providers/ministry_exam_rows.dart:45` | `stages/providers/stages_provider.dart:25` · `super_admin/providers/super_exams_provider.dart:31` | Constante nationale recopiée 3× | `features/examens/models/` (foyer déjà partagé via `exam_stats.dart`) |
| 3 | `examens`, `stages` | Définition de « attestation délivrée » | `exam_dossier_provider.dart:162` + `exam_dossier_actions.dart:237` (sans statut) | `stages/providers/stages_provider.dart:180` (`status IN ('termine','valide')`) | Deux prédicats sur la même donnée | Le module producteur : `stages` |
| 4 | `examens` | Couleur orange de liste | `transmissions_panel.dart:342` (`kListOrangeLocal`) | `core/widgets/list_chrome.dart:29` (`kListOrange`) | Constante recopiée | `core/widgets/list_chrome.dart` |
| 5 | `examens`, `stages` | Formules et charpente d'attestation | `stages/services/stage_export_service.dart:39-73, 139-167` (`_para`, `_signatureBlock`, « Je soussigné(e) », « en foi de quoi ») | `core/services/attestation_kit.dart:84-163` (`formuleSoussigne`, `formuleFinale`, `paragraphe`, `signature`) | Charpente réimplémentée | `AttestationKit` |

### D.3 Données partagées HORS catégorie

| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|
| `exam_candidates.result` | `examens` | `passage` (clôture), espaces Réseau + Fondateur | `admis ⇒ passe`, `ajourne`/`absent` ⇒ `redouble`, `fraude` ⇒ rien ; jamais de note | La clôture d'année d'une classe d'examen n'a plus d'entrée ; `graduated` n'est plus écrit |
| `exam_candidates.average` | `examens` | `passage`, cockpit Réseau | **Colonne facultative que la DEC n'alimente pas — 0 ligne renseignée sur 2 470 en prod** | Tout classement adossé à l'examen sort vide (déjà arbitré : palmarès = classes de passage) |
| `classes.exam_id` / `exam_status` | *serveur* (`resolve_class_exam`, trigger) | `examens`, `stages`, `passage` | Dérivé, jamais saisi ; le client LIT | Une règle changée sans `recompute_class_exams()` ne touche aucune classe |
| `internships.attestation_issued_at` | `stages` | `examens` (pièce `attestation_stage`) | Attestation émise ⇒ pièce satisfaite, sans re-cochage | Le dossier de bac redevient éternellement incomplet |
| `fee_structures` (`applies_to_exam_id`, portée groupe) | `frais-scolarite` (ministère) | `examens` | Barème publié par le ministère + **année scolaire PUBLIÉE** (`published_at`) sinon la jointure `academic_years.label` ne rend rien | Le tarif reste introuvable **sans erreur** ; 3 groupes sur 7 ont un `frais_examens` qui ne vise aucun examen → invisible du module |
| `student_payments` | `examens` (écrit) | `paiements-eleves`, `budget`, revenu du groupe | `enrollment_id` NOT NULL résolu avant écriture ; `frais_examens` exclu du recouvrement de scolarité | Rejet serveur ⇒ **lot PowerSync entier abandonné en silence** |
| `student_documents` (`exam_candidate_id`) | `documents` / `examens` | `examens`, `stages` | Chemin d'écriture unique `attachStudentDocumentOffline` | Une colonne NOT NULL oubliée fait tomber le lot entier |
| `exam_stats.dart` (règle « taux sur résultats connus ») | `examens` (code) | espaces Réseau et Fondateur | `isKnownExamResult` / `groupExamLines` importés, jamais recopiés | Deux taux de réussite différents entre l'école et le ministère |
| `exam_publications` / `exam_official_results` | espace Réseau (DEC) | **personne côté école** — absents des sync-rules | — | L'école ne connaît jamais le chiffre officiel de son établissement |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|
| `examens` — liste des candidats | oui (PDF) | oui (`exam_export_service.dart:41-64`) | oui (`exam_session_screen.dart:105`) | non | ⛔ **NON CONFORME — ne se génère jamais** : `flex` à 8 pour 9 colonnes (l. 121) ; et `frame`+`table` non paginés (l. 90) |
| `examens` — fiche d'inscription | oui (PDF) | oui (l. 140-227, 3 tables 2 colonnes) | oui (`candidate_file_dialog.dart:394`) | non | ✅ conforme (tables courtes, `frame` sans risque de débordement) |
| `examens` — convocations | oui (PDF, 1 page/candidat) | oui (`convocation_service.dart:53-90`) | oui (`exam_session_screen.dart:135`) | non | ✅ conforme sur la forme — ⚠️ `pw.Page` par candidat, bon choix ; mais période des épreuves jamais transmise (D.1 n°10) |
| `examens` — CSV | oui | s.o. | s.o. | non | ✅ conforme (BOM UTF-8 + `utf8.encode`, `exam_export_service.dart:340-346`) |
| `examens` — page d'accueil | **aucune** | — | — | — | ⚠️ critère n°9 manquant |
| `examens` — transmission (snapshot) | **aucune** | — | — | — | ⛔ la pièce opposable ne s'imprime pas |

*Complément au balayage global* : le rapport `22-transversal-documents.md`
comptait 3 tables à la main hors de ce périmètre ; **`exam_export_service.dart:90`
et `stage_export_service.dart:355` sont deux cas supplémentaires** de
`frame`+`table` non découpés, et le premier porte en plus l'unique déséquilibre
`headers`/`flex` de tout `lib/`.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|
| 1 | `examens` | Zéro menteur (par disparition) | `exam_fees_panel.dart:41` — `error: (e, _) => const SizedBox.shrink()` | — | Une lecture des frais qui échoue **fait disparaître tout le panneau** : ni montant, ni attendu, ni message. L'école conclut qu'il n'y a pas de frais. |
| 2 | `examens` + tableau de bord | Zéro menteur | `features/user/screens/dashboard_examens_parts.dart:23-26` (`valueOrNull`), l. 40-47, 87-104 | « 0 candidat », « 0 classe d'examen », **aucune alerte** | Si `examOverviewProvider` ou `stagesOverviewProvider` échoue, tout vaut `null`→`0`, les cartes d'alerte (« Dossiers bloqués », « Classes à qualifier ») sont conditionnées à `> 0` et **disparaissent**. Une panne se lit « tout va bien ». |
| 3 | `examens` | Message obsolète (case morte de texte) | `exam_payment_dialog.dart:210` | « définissez d'abord le montant dû par candidat » | L'école **ne peut plus** définir ce montant : `ensureExamFeeStructure`/`setExamFeeAmount` retirées le 5 août 2026 (`exam_fees_provider.dart:186-194`). Le message ordonne un geste qui n'existe plus. |
| 4 | `examens` | Case morte | `exam_registration_provider.dart:290-303` (`updateDossier`) | — | Fonction complète, aucun appelant. |
| 5 | `examens` | Case morte | `convocation_service.dart:51, 216` (`writtenTo`) | « du X au Y » | Paramètre jamais passé ; 11/11 sessions ont pourtant `written_to` en base. |
| 6 | `examens` | Case morte | `transmission_provider.dart:145-147` (`correctsId`, `kind`) | « une correction se fait par rectificatif » (`transmissions_panel.dart:130`) | Aucun appelant ne crée de rectificatif. |
| 7 | `examens` | Case morte | `transmission_provider.dart:224` (`transmission_items`) | « feuille de frappe et bordereau » | Table écrite, **jamais relue** dans tout `lib/`. |
| 8 | `examens` | Verbes accordés sans code | base : `can_approve`, `can_manage`, `can_import` = true pour Direction/Secrétariat sur `examens` | — | `grep -rn "'approve'\|'manage'\|'import'" features/examens` → aucun résultat. Trois droits vendus, zéro effet. |
| 9 | `examens` | Périmètre à deux vitesses sur une même page | `exam_session_screen.dart:341` (KPI = session entière) et `:344` (frais = session entière) vs `:475, :477` (stats et transmission = périmètre) | — | Après un filtre « Terminale A », les KPI du haut restent ceux des 90 candidats, la liste en montre 22, et rien ne le dit. |
| 10 | `examens` | Compteur potentiellement faux | `examens_provider.dart:213-215` — `(SELECT COUNT(*) FROM exam_candidates ec WHERE ec.class_id = c.id)` | « N inscrits / M élèves » | Compte **toutes sessions confondues** : une classe inscrite à une session normale **et** à un rattrapage affiche une couverture > 100 %. |

### D.6 Dette de structure

| Fichier | Lignes | Couture de découpe proposée |
|---|---|---|
| `features/examens/widgets/examens_widgets.dart` | **599** | 3 fichiers déjà nets : `exam_session_banners.dart` (`ExamSessionBanner`, `ExamNoOpenSession`, `ExamPastSessions`, l. 26-247) · `exam_group_card.dart` (`ExamGroupCard`, `_ClassRow`, `_CountPill`, l. 248-441) · `exam_states.dart` (`ExamAnomalyCard`, `ExamSectionLabel`, `ExamEmptyState`, `ExamErrorCard`, l. 442-599). ⚠️ `ExamErrorCard` est importé par `features/stages/screens/stages_screen.dart:9` — le promouvoir plutôt dans `core/widgets/`. |
| `features/examens/screens/exam_session_screen.dart` | **598** | Extraire l'état de filtrage/sélection (`_scope`, `_panelFilter`, `_selected`, `_syncCollapse`, l. 47-100 + 250-262) dans un `exam_session_controller.dart`, et les trois exports (l. 102-176) dans un `exam_session_exports.dart`. Le `build` retombe sous 300 lignes. |

Les 31 autres fichiers du module sont sous la cible ; la dette est faible et
localisée. **Le vrai problème de structure n'est pas la taille des fichiers,
c'est la taille du module** (C).

### D.7 Désalignements catalogue ↔ code

1. **La description catalogue d'`examens` sous-décrit le module.** En base :
   « Classes d'examen, candidatures…, dossiers, convocations et résultats ».
   Absents : frais d'examen (caisse), transmission opposable à la DEC,
   statistiques de réussite, numéros de candidat, parcours & prérequis. Cinq
   métiers vendus, neuf livrés — dont les deux qui engagent l'argent et la
   responsabilité.
2. **`exam_stats.dart` est un modèle de plateforme rangé dans un module
   d'école.** `features/examens/models/exam_stats.dart` est importé par quatre
   fichiers de `features/admin_groupe/` (espace ONLINE) et sert de source
   unique nationale. Un modèle partagé entre l'espace école offline et l'espace
   réseau online appartient à `core/` ou `data/models/`.
3. **Catégorie mono-module.** `EXAMENS & CERTIFICATION` (`display_order = 4`) ne
   porte qu'un module, comme `FORMATION PROFESSIONNELLE`. Ce sont les deux
   seules catégories dans ce cas sur neuf, et ce sont précisément les deux
   modules les plus lourds. La taxonomie annonce une famille et livre un
   élément.
4. **Trois verbes accordés en base sans implémentation** (`approve`, `manage`,
   `import`) — cf. D.5 n°8. Le catalogue promet une granularité que le code
   n'honore pas.
5. **`/user/examens/session/:id` n'apparaît dans `module_routes.dart` sous
   aucun slug** (`grep -n "examens" features/navigation/module_routes.dart` →
   seule `'examens': Routes.examens`). La route est correctement gardée par
   `ModuleScaffold(slug: 'examens')`, mais la table slug↔route ne la connaît
   pas : une navigation dynamique ne la retrouverait pas.

## E. Les cinq choses à faire en premier — EXAMENS

1. **Réparer la liste des candidats.** Ajouter la 9ᵉ valeur de `flex` **et**
   passer à `OfficialPdfKit.tableSection` ; en profiter pour ajouter les
   colonnes Filière/série et Lieu de naissance. Ajouter un test qui
   *construit* les 4 PDF du périmètre (aucun n'existe aujourd'hui).
   Gain : le document central du module existe. Effort : S.
   Entrée : `features/examens/services/exam_export_service.dart:90-121`.
2. **Poser le périmètre `own_classes` et le verrou d'année.** Une ligne
   `classScopeClause(ref, 'examens', column: 'ec.class_id')` dans
   `exam_candidates_provider.dart` et `examens_provider.dart` ; un
   `ref.watch(yearReadOnlyProvider)` dans les deux écrans. Gain : 7 profils
   Enseignant cessent de lire toute l'école ; plus d'écriture dans une année
   archivée. Effort : S. Entrée : `features/examens/providers/exam_candidates_provider.dart:126`.
3. **Aligner les verbes sur les actes** : retrait → `delete`, dépôt →
   `validate` (comme la réouverture), encaissement → `paiements-eleves/create`
   (déjà admis par `payments_insert`). Ajouter un test de source calqué sur
   `test/stage_correction_test.dart`. Gain : supprime le mode de défaillance
   silencieux le plus coûteux du module, et rend la caisse au comptable.
   Effort : S. Entrée : `features/examens/widgets/exam_candidate_views.dart:99-133`.
4. **Saisie en masse des résultats DEC**, sur le patron déjà écrit de
   `assignCandidateNumbers` (collage positionnel, contrôle des doublons,
   aperçu de l'appariement avant écriture). Gain : reporter une proclamation
   passe de 90-300 modales à un collage. Effort : M.
   Entrée : `features/examens/providers/exam_registration_provider.dart:388-448`.
5. **Rendre la transmission relisable et imprimable** : tuile cliquable →
   détail lu depuis `transmission_items`, PDF « bordereau » depuis le
   `snapshot` figé (jamais recalculé), et rectificatif branché sur
   `correctsId`. Gain : la preuve opposable devient une preuve. Effort : M.
   Entrée : `features/examens/widgets/transmissions_panel.dart:266-327`.

---
---

# BLOC 2 — FORMATION PROFESSIONNELLE (`formation-pro`)

## A. Vue d'ensemble de la catégorie

Une catégorie, un module, **3 916 lignes** : `stages` sert la filière technique
du METP — commanditaire de la démonstration. Il tient les entreprises d'accueil
(portée groupe), les conventions, les stages, l'évaluation du tuteur, et surtout
**l'attestation de fin de stage**, pièce obligatoire du dossier de baccalauréat.
Sa valeur n'est pas la liste, c'est **l'alerte** : le croisement
stages × classes d'examen produit « dossiers bloqués », et un dossier bloqué
coûte une année.

**Niveau de finition, comparé au reste** — la question posée en mission :
`stages` est **au-dessus de la moyenne des catégories que j'ai lues**. Il est le
seul des deux modules de ce rapport à poser le verrou d'année
(`stages_screen.dart:104`), le seul à appliquer `classScopeClause`
(`stages_provider.dart:142`) — et il l'applique alors qu'**aucun** profil n'est
en `own_classes` sur `stages`, quand `examens` ne l'applique pas alors que **7
profils le sont**. Il a un test de source dédié (`stage_correction_test.dart`)
qui interdit nommément le défaut « verbe UI ≠ verbe RLS ». Il reste trois trous
nets : l'attestation est un `MultiPage` hors `AttestationKit`, les exports ne
sont pas gardés sur `export`, et le sélecteur d'élève est un menu déroulant non
cherchable sur tout l'effectif.

---

## B. Fiche par module

### Stages — `stages`

| | |
|---|---|
| Route | `/user/stages` |
| Écran | `StagesScreen` — `features/stages/screens/stages_screen.dart` (582 l.) |
| Tables lues | `internships`, `internship_companies`, `students`, `classes`, `class_enrollments`, `national_exams`, `profiles` (tuteur école) |
| Tables écrites | `internships` (INSERT/UPDATE/DELETE), `internship_companies` (INSERT), `student_documents` (pièces de stage via `attachStudentDocumentOffline`) |
| Profondeur UI | **L2** — satisfaits 1,3,4,5,6,7,8,9 · manquants **n°2** (aucun tri) et **n°10** (582 l.) |
| Sortie document | conforme sur le kit et l'aperçu — **non conforme sur deux points** : attestation en `MultiPage` hors `AttestationKit`, et liste non paginée (détail D.4) |

**Ce que le module fait.** Il enregistre les stages (statut **déduit des dates**,
jamais demandé — `stage_actions.dart:243-251`), délivre l'attestation à l'unité
ou en lot (`stages_screen.dart:316-354`), produit convention et attestation en
PDF, et affiche en tête l'alerte « dossiers bloqués » : élèves en classe de bac
sans attestation acquise (`stages_provider.dart:161-182`).

**Ce qui manque.**

- **Les exports ne sont pas gardés sur `export`.** `_ExportBar`
  (`stages_screen.dart:202-205`) et les PDF de fiche
  (`stage_file_dialog.dart:381-394`) ne consultent aucun `canProvider`.
  `grep -rn "canProvider" features/stages` → 4 sites, tous `create`/`update`/`delete`.
  Comparer à `exam_session_screen.dart:271` (`action: 'export'`). Un profil en
  lecture seule exporte la liste nominative des stagiaires.
- **Le sélecteur d'élève est un menu déroulant sur tout l'effectif actif.**
  `stage_student_picker.dart:50-78` charge **tous** les élèves inscrits de
  l'année (10 364 élèves en base, tous établissements confondus ; par école,
  plusieurs centaines) dans un `DropdownButtonFormField`, sans recherche —
  seul le tri place les « needsAttestation » en tête. C'est exactement le
  défaut corrigé côté examens par `class_candidates_dialog.dart` (dont
  l'en-tête, l. 15-27, explique pourquoi).
- **Le sélecteur ignore `classScopeClause`** (`stage_student_picker.dart:63`)
  alors que la liste l'applique (`stages_provider.dart:142`). Un enseignant en
  `own_classes` pourrait créer un stage pour un élève qu'il ne verra pas
  ensuite.
- **Aucun tri** (critère §8 n°2) : ordre figé `start_date DESC`. Trier par date
  de fin ou par « attestation due » est le geste de juin.
- **Le graphique ignore les filtres.** `StagesStatusChart(internships: o.internships)`
  (`stages_screen.dart:137`) reçoit la liste **non filtrée**, alors que
  `ListResultHeader` et le tableau reçoivent `filtered`. Même travers que
  `examens` (D.5 n°9).
- **`stageTone` donne la même couleur (`kGreen`) à « En cours » et « Validé »**
  (`stages_views.dart:13-14`), sur un graphique où la couleur est le seul
  différenciateur hors étiquette.
- **`kExamsRequiringInternship` est une règle nationale gelée en Dart**
  (`stages_provider.dart:25`) et couvre le seul baccalauréat. Le **BTS**
  (ajouté au référentiel, tarif 5 000 F posé par le METP en base) n'y figure
  pas — un BTS sans attestation ne déclenchera aucune alerte. Comme les
  prérequis d'examen, cette règle appartient au référentiel du ministère.
- **Le module Stages ne produit aucune convocation ni relance des entreprises**,
  et `internship_companies` n'a pas d'écran propre : on ne peut que créer une
  entreprise depuis le formulaire de stage (`companiesProvider`,
  `stage_actions.dart:76-88`) — jamais la corriger, la désactiver ni voir
  combien d'élèves elle accueille. 40 entreprises en base, 290 stages.
- **La date d'attestation n'est pas bornée.** `issueAttestation`
  (`stage_actions.dart:228-244`) accepte n'importe quelle date, y compris
  antérieure au début du stage ou postérieure au jour même.

**Ce qui est en double.**

- **La charpente d'attestation est réimplémentée.**
  `stage_export_service.dart:39-73` (`_para`, `_signatureBlock`) et
  `:139-167` (« Je soussigné(e), responsable de … », « En foi de quoi la
  présente attestation lui est délivrée pour servir et valoir ce que de
  droit ») recopient `AttestationKit.formuleSoussigne` (l. 84),
  `AttestationKit.formuleFinale` (l. 95), `AttestationKit.paragraphe` (l. 150)
  et `AttestationKit.signature` (l. 104). Le fichier `attestation_kit.dart`
  existe précisément pour empêcher cela (en-tête l. 1-16). Foyer : `AttestationKit`.
- **Copie du jeu des diplômes à stage** — cf. D.2 n°2 du bloc 1 :
  `stages_provider.dart:25` est l'une des trois copies.
- **Copie de la règle « attestation délivrée »** — cf. D.2 n°3 du bloc 1.

**Ce que ce module partage.**

- **Produit** : `internships.attestation_issued_at` → **pièce
  `attestation_stage` du dossier de bac**, lue par `examens`
  (`exam_dossier_provider.dart:155-176`, `exam_dossier_actions.dart:234-239`)
  ; `internships` complets → alertes du cockpit ministériel
  (`admin_groupe/providers/ministry_exam_rows.dart`) et de l'espace Fondateur
  (`super_admin/providers/super_exams_provider.dart`).
- **Produit** : les KPI de `stagesOverviewProvider` → tableau de bord école
  (`features/user/screens/dashboard_examens_parts.dart:26`), sans recalcul.
- **Consomme** : `classes.exam_id` / `exam_status` (dérivés serveur) ·
  `class_enrollments` (`inscriptions`) · `students` (`eleves`) ·
  `national_exams` (référentiel ministère) · `profiles` (tuteur école, module
  `personnel`) · `student_documents` (`documents`) · `ExamErrorCard` de
  `features/examens/` (`stages_screen.dart:9`).

---

## C. Relations entre les modules — la chaîne, et où elle casse

```
  RÉFÉRENTIEL (ministère, /admin/referentiel-examens)
      national_exams ── exam_eligibility_rules
                 │
                 ▼  resolve_class_exam() + trigger  (SERVEUR, jamais rejoué en Dart)
        classes.exam_id / exam_status  ──────────────────────────────┐
                 │                                                   │
   ┌─────────────┴──────────────┐                                    │
   │  examens (accueil)         │                                    │
   │  classes d'examen · anomalies « à qualifier »  ⚠ SANS ACTION    │
   └─────────────┬──────────────┘                                    │
                 ▼                                                   ▼
        exam_sessions (national)                            stages : alerte
                 │                                     « dossiers bloqués »
                 ▼                                                   │
   ┌──────────────────────────────────────────┐                      │
   │ SESSION : inscrire → dossier → frais →   │◀── attestation ──────┘
   │ n° candidat → convocation → TRANSMISSION │    (internships)
   │ → résultat → statistiques                │
   └──────────────┬───────────────────────────┘
                  │ exam_candidates.result
                  ▼
        passage (cat. ÉVALUATION) : clôture des classes d'examen
        admis ⇒ passe · ajourné/absent ⇒ redouble · fraude ⇒ rien
                  │ seule écriture de `graduated`
                  ▼
        class_enrollments.promotion_* / status
```

**Les cinq ruptures de la chaîne**, dans l'ordre chronologique d'une année :

1. **En amont** — une classe « à qualifier » est signalée et **aucun geste ne
   la répare depuis le module** : ni surcharge (`exam_override_id` jamais
   écrit), ni renvoi vers le module `classes` où se saisit la filière. En prod
   la dérivation est propre (0 classe à qualifier, 116 classes d'examen), donc
   le trou ne se voit pas — jusqu'à la première filière nouvelle.
2. **À l'inscription** — le prérequis de diplôme n'est pas vérifié, et le lien
   examens↔stages n'est consulté que pour la pièce, jamais pour interdire.
3. **À la caisse** — le tarif ne se résout que si le ministère a visé l'examen
   **et** publié l'année scolaire. 3 groupes sur 7 ont un `frais_examens` qui
   ne vise aucun examen ; le module affiche alors « aucun montant fixé », sans
   dire pourquoi ni où regarder. Aucune session METP ne porte de `fee_amount`
   de repli (4 sessions sur 35 en ont un, toutes MEPSA).
4. **Au dépôt** — la transmission fige une liste qu'elle ne sait ni relire ni
   imprimer, et le rectificatif annoncé n'existe pas.
5. **Au retour** — les résultats se saisissent un par un, la DEC ne renvoie
   aucune note (`average` : 0 ligne sur 2 470 en prod), et les chiffres
   OFFICIELS de l'établissement ne descendent pas jusqu'à l'école.

**Le pont examens↔stages est le point sain de la chaîne** : une seule source de
vérité (`internships`), pas de re-cochage manuel, `kStagePieceCode` partagé. Sa
seule faiblesse est le désaccord de prédicat (D.2 n°3) et sa fragilité latente :
`updateInternship` réapplique `status ?? statusFromDates(...)`
(`stage_actions.dart:210`) et le formulaire de correction ne passe pas de statut
(`stage_form_dialog.dart:221-231`) ; **corriger les dates d'un stage déjà attesté
le fait redescendre de `valide` à `termine` — voire à `en_cours` si la fin est
repoussée**, auquel cas l'élève réapparaît « bloqué » côté Stages alors que sa
pièce reste satisfaite côté Examens. En base aujourd'hui : 116 stages `valide`
avec attestation, 0 attestation sur un autre statut — le défaut est **latent**,
pas actif.

---

## D. Synthèse de la catégorie FORMATION PROFESSIONNELLE

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `stages` | L'attestation de bac est un `MultiPage` hors `AttestationKit` | `stage_export_service.dart:114` vs `core/services/attestation_kit.dart:1-16, 57` | Un long commentaire d'évaluation pousse la signature en page 2 : la signature n'authentifie plus le texte. Pièce refusable au comptoir DEC. | S |
| 2 | `stages` | La liste PDF n'est pas paginée | `stage_export_service.dart:355-359` (`frame`+`table`) vs `official_pdf_kit.dart:518` (`kRowsPerBlock = 28`) | Max 18 stages/école aujourd'hui : **aucun document au-delà de ~28** | XS |
| 3 | `stages` | Exports non gardés sur `export` | `grep -rn "canProvider" features/stages` → 4 sites, aucun `'export'` ; cf. `exam_session_screen.dart:271` | Un lecteur seul exporte la liste nominative des stagiaires | XS |
| 4 | `stages` | Sélecteur d'élève : dropdown non cherchable sur tout l'effectif | `stage_student_picker.dart:50-78, 105-110` | Inutilisable dès quelques centaines d'élèves ; défaut déjà corrigé côté examens | S |
| 5 | `stages` | Le sélecteur ignore `classScopeClause` que la liste applique | `stage_student_picker.dart:63` vs `stages_provider.dart:142` | Stage créé pour un élève hors périmètre, puis invisible à son auteur | XS |
| 6 | `stages` | Corriger un stage attesté le dé-valide | `stage_actions.dart:210` + `stage_form_dialog.dart:221-231` | Un élève attesté réapparaît « dossier de bac bloqué » (latent : 0 cas en prod) | XS |
| 7 | `stages` | Aucun écran des entreprises d'accueil | `companiesProvider` (`stage_actions.dart:76-88`) : création seule, depuis le formulaire | 40 entreprises, aucune correction, aucune désactivation, aucun décompte | M |
| 8 | `stages` | `kExamsRequiringInternship` gelé en Dart, sans le BTS | `stages_provider.dart:25` ; BTS actif au référentiel + tarif 5 000 F en base | Un BTS sans attestation ne déclenche aucune alerte | S |
| 9 | `stages` | Aucun tri (critère §8 n°2) | `stages_screen.dart` : ordre `start_date DESC` figé | Impossible de trier par « attestation due » ou date de fin | XS |
| 10 | `stages` | Date d'attestation non bornée | `stage_actions.dart:228-244` | Attestation datable avant le début du stage | XS |
| 11 | `stages` | Le graphique ignore les filtres | `stages_screen.dart:137` (`o.internships`) vs `:212` (`filtered`) | Deux périmètres sur une même page, sans le dire | XS |

### D.2 Doublons et redondances — vue consolidée

| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|
| 1 | `stages` | Charpente et formules d'attestation | `stage_export_service.dart:39-73, 139-167` | `core/services/attestation_kit.dart:84-163` | Kit partagé contourné | `AttestationKit` |
| 2 | `stages`, `examens`, Réseau, Fondateur | Jeu des diplômes exigeant un stage (divergent) | `stages_provider.dart:25` | `ministry_exam_rows.dart:45` · `super_exams_provider.dart:31` | Constante nationale ×3 | `features/examens/models/` |
| 3 | `stages`, `examens` | Prédicat « attestation délivrée » | `stages_provider.dart:180` (avec statut) | `exam_dossier_provider.dart:162` · `exam_dossier_actions.dart:237` (sans statut) | Deux règles pour une donnée | `stages` (producteur) |
| 4 | `stages` | Bloc de signature PDF | `stage_export_service.dart:47-73` | `attestation_kit.dart:104-148` (`signature`) | Widget recopié | `AttestationKit.signature` |

### D.3 Données partagées HORS catégorie

| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|
| `internships.attestation_issued_at` | `stages` | `examens` (pièce `attestation_stage`) | Attestation émise ⇒ pièce satisfaite sans re-cochage ; `kStagePieceCode` partagé | Tous les dossiers de bac redeviennent incomplets ; l'alerte disparaît (précédent : mig 0065 avait supprimé l'exigence sans que le Dart suive) |
| `internships` (agrégats) | `stages` | espaces Réseau (`ministry_exam_rows.dart`) et Fondateur (`super_exams_provider.dart`) | Le jeu des diplômes à stage doit être identique des deux côtés | Une école « à risque » au ministère et « en règle » chez elle |
| `classes.exam_id` / `exam_status` | *serveur* (trigger) | `stages`, `examens`, `passage` | `exam_status = 'examen'` + code du diplôme = un stage est dû | L'alerte « dossiers bloqués » se vide en silence |
| `class_enrollments` (année active) | `inscriptions` | `stages` (liste + candidats stagiaires) | Le filtre `academic_year_id` est obligatoire : les inscriptions restent `active` d'une année sur l'autre | Une promotion partie depuis un an compte comme « bloquée pour le bac » (défaut déjà corrigé, `stages_provider.dart:127-134`) |
| `internship_companies` (`school_id IS NULL`) | `stages` | toutes les écoles du **groupe** | Bucket `by_group` : une entreprise sert plusieurs écoles | Re-saisie de « SOTEC » par école, doublons irrécupérables |
| `profiles` (tuteur école) | `personnel` | `stages` (`fetchStageDetail`, jointure `tut`) | — | Nom du tuteur vide sur la convention |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|
| `stages` — attestation de fin de stage | oui | oui (`stage_export_service.dart:83-84, 118-119`) | oui (`stage_file_dialog.dart:381`, `stage_attestation_dialog.dart`) | non | ⛔ **NON CONFORME** : `pw.MultiPage` (l. 114) pour une attestation, et `AttestationKit` contourné |
| `stages` — convention de stage | oui | oui (l. 215-223) | oui (`stage_file_dialog.dart:389`) | non | ⚠️ `MultiPage` acceptable ici (document multi-articles), mais le bloc signature reste recopié |
| `stages` — liste des stages | oui | oui (l. 329-359) | oui (`stages_screen.dart:361-374`) | non | ⚠️ `frame`+`table` non paginés (l. 355) ; 8 en-têtes / 8 `flex` ✅ ; **non gardé sur `export`** |
| `stages` — CSV | oui | s.o. | s.o. | non | ✅ conforme (BOM UTF-8 + `utf8.encode`, l. 456-460) |

Aucun `Printing.layoutPdf(` ni `PdfGoogleFonts` dans les deux catégories
(`grep -rn "Printing.layoutPdf(\|PdfGoogleFonts" features/examens features/stages`
→ vide) : les deux violations du balayage global n'atteignent pas ce périmètre.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|
| 1 | `stages` | Libellé menteur | `stages_screen.dart:250-252` — KPI « Stages », `sub: 'toutes années'` | « toutes années » | `stagesOverviewProvider` filtre `WHERE i.academic_year_id = ?` sur l'**année active** (`stages_provider.dart:135, 151`). Le compteur ne montre qu'une année. |
| 2 | `stages` + tableau de bord | Zéro menteur | `features/user/screens/dashboard_examens_parts.dart:26, 47, 87-95` | « ✅ aucun blocage » | `valueOrNull` : une lecture en échec vaut `null` → `blocked = 0` → la carte d'alerte, conditionnée à `> 0`, **disparaît**. La panne se lit comme un feu vert sur l'information la plus coûteuse du réseau. |
| 3 | `stages` | Couleur ambiguë | `stages_views.dart:13-14` | deux barres distinctes | « En cours » et « Validé » partagent `kGreen` sur le graphique par statut. |
| 4 | `stages` | Périmètre à deux vitesses | `stages_screen.dart:137` vs `:212` | — | Le graphique ignore recherche et filtres appliqués à la liste. |
| 5 | `stages` | Placeholder sur document officiel | `stage_export_service.dart:88-90, 141` | « Je soussigné(e), responsable de … » | Si `schoolName` est nul : « responsable de **L'établissement** » sur l'attestation de bac. |

### D.6 Dette de structure

| Fichier | Lignes | Couture de découpe proposée |
|---|---|---|
| `features/stages/screens/stages_screen.dart` | **582** | Extraire les KPI (`_kpis`, l. 244-311) dans `widgets/stages_kpis.dart` ; les deux exports (`_exportListPdf`, `_exportCsv`, l. 356-380) et `_ExportBar` (l. 393+) dans `widgets/stages_export_bar.dart` ; `_bulkIssue` (l. 313-354) dans `providers/stage_bulk_actions.dart`. Le `build` retombe sous 250 lignes. |
| `features/stages/widgets/stage_file_dialog.dart` | **511** | Séparer l'en-tête d'identité + sections de lecture (l. 60-220) du pied d'actions (`_corriger`/`_supprimer`/PDF, l. 220-396) : `stage_file_view.dart` + `stage_file_actions.dart`. |

Les 11 autres fichiers sont sous la cible. Dette faible.

### D.7 Désalignements catalogue ↔ code

1. **La description catalogue de `stages` est périmée.** En base :
   « L'attestation est une pièce obligatoire du dossier de **baccalauréat
   professionnel** ». Depuis la migration **0105** (13/08/2026) il n'y a qu'un
   seul baccalauréat au METP (`BAC_P` supprimé : 0 session, 0 candidat,
   0 classe, 0 règle, 0 tarif ; référentiel live confirmé — 17 diplômes, pas de
   `BAC_P`). Le texte de vente parle d'un diplôme qui n'existe plus.
   ⚠️ Ne pas « corriger » en refusionnant quoi que ce soit : la 0079 avait
   défait la fusion 0065, et la 0105 n'en est **pas** le retour (la distinction
   technique/professionnel est une **filière**, saisie par l'école).
2. **Catégorie mono-module** (`display_order = 5`) — même remarque qu'`examens`.
   Deux catégories sur neuf ne portent qu'un module, et ce sont les deux plus
   lourds.
3. **Le code du module dépend d'un autre module pour son chrome d'erreur** :
   `stages_screen.dart:9` importe `ExamErrorCard` de `features/examens/widgets/`.
   Assumé en commentaire, mais un widget d'erreur générique appartient à
   `core/widgets/`.
4. **Verbes accordés sans code** : `can_import`, `can_approve`, `can_manage`
   sont vrais en base pour Direction/Secrétariat sur `stages` ;
   `grep -rn "'import'\|'approve'\|'manage'" features/stages` → aucun résultat.
   Même travers qu'`examens` (D.5 n°8 du bloc 1).

## E. Les cinq choses à faire en premier — FORMATION PROFESSIONNELLE

1. **Refaire l'attestation sur `AttestationKit`** (`pw.Page`, formules et bloc
   signature du kit). Gain : la signature reste sous le texte qu'elle
   authentifie, et la charpente cesse de diverger de celle des cinq autres
   attestations de la plateforme. Effort : S.
   Entrée : `features/stages/services/stage_export_service.dart:114-172`.
2. **Paginer la liste des stages** (`OfficialPdfKit.tableSection`) **et garder
   tous les exports sur `export`** — deux corrections d'une ligne chacune, sur
   le même écran. Gain : le document existe au-delà de 28 stages ; un lecteur
   n'exporte plus une liste nominative. Effort : XS.
   Entrée : `features/stages/services/stage_export_service.dart:355` et
   `features/stages/screens/stages_screen.dart:202`.
3. **Unifier la règle « attestation délivrée » et le jeu des diplômes à stage.**
   Une constante et un prédicat uniques dans `features/examens/models/`,
   importés par `stages`, le pont dossier, le cockpit ministériel et l'espace
   Fondateur — et ajouter le **BTS**. Gain : supprime la seule divergence
   active de la catégorie (`BAC_TP` d'un seul côté) et la seule divergence
   latente du pont. Effort : S.
   Entrée : `features/stages/providers/stages_provider.dart:25, 180`.
4. **Remplacer le sélecteur d'élève par un champ cherchable scopé**, calqué sur
   `class_candidates_dialog.dart`, et lui appliquer `classScopeClause`. Gain :
   le module redevient utilisable dans un lycée réel. Effort : S.
   Entrée : `features/stages/widgets/stage_student_picker.dart:50-78`.
5. **Préserver le statut d'un stage attesté à la correction** : passer
   explicitement `status: 'valide'` quand `attestation_issued_at` existe, et
   corriger le KPI « toutes années » en « année en cours ». Gain : ferme le
   défaut latent du pont et le seul libellé menteur du module. Effort : XS.
   Entrée : `features/stages/providers/stage_actions.dart:210` et
   `features/stages/screens/stages_screen.dart:252`.

---

## Annexe — fiches mémoire consultées et points où ce rapport les prolonge

| Fiche | Ce qu'elle fixe | Ce que ce rapport ajoute |
|---|---|---|
| `examens-nationaux-socle.md` | classe d'examen **dérivée**, résolution 100 % SQL, scission école↔ministère | La dérivation est saine (0 anomalie sur 116 classes) mais **l'anomalie n'a aucune action côté école** et `exam_override_id` n'est écrit nulle part |
| `examens-stages-dossiers-reels.md` | « couverte si **attachée OU déclarée** », `recoverDeclared`, `levels` n'existe pas | Règle respectée à la lettre ; mais `updateDossier` survit comme seconde règle morte |
| `examens-frais-stats-convocations.md` | dette dérivée, taux sur résultats connus, `center_name` ajouté à `ExamCandidateRow` | **`center_name` a disparu** (`grep -rn "center" features/examens` → aucune occurrence métier) ; l'absence de centre sur la convocation est aujourd'hui documentée comme un choix |
| `tarif-examen-vise-l-examen-0103.md` | tarif visant l'**examen**, année **publiée** obligatoire | Vérifié en base : 11 tarifs METP visent un examen sur une année publiée ✅ ; **3 groupes privés ont un `frais_examens` qui ne vise rien** → invisible du module, sans message |
| `un-seul-baccalaureat-metp-0105.md` · `examens-metp-reels-dec.md` | un seul `BAC` au METP ; 0079 défait 0065 ; BAC_T→BAC n'est pas ce retour | Référentiel live conforme (17 diplômes, pas de `BAC_P`) ; **la description catalogue de `stages` parle encore du « bac professionnel »** |
| `metp-partage-dec-classes-passage.md` | DEC renvoie des **admis sans notes** ; jamais de palmarès d'examen | Vérifié : `average` renseigné sur **0 candidature sur 2 470**. `ResultChip` et le bloc « mentions » sont donc des chemins morts en pratique |
| `cloture-examen-classes.md` | `passage` = seul écrivain de `graduated` ; le niveau suivant change de cycle | Contrat confirmé (`cloture_examen_provider.dart:284-288`) ; c'est la seule sortie de `exam_candidates.result` |
| `referentiel-examens-au-ministere.md` | le référentiel appartient au ministère ; faille SECURITY DEFINER fermée (0070/0071) | **`kPrerequisites` reste une règle nationale gelée en Dart** dans l'espace école — même travers que celui que la RPC `exam_rule_vocabulary()` a corrigé |
| `archives-publications-dec.md` | la plateforme est gardienne, pas calculatrice ; `dec_code` seule clé fiable | `exam_publications`/`exam_official_results` **absents des sync-rules** → l'école ne voit jamais son chiffre officiel ; `dec_code` toujours à 0 école |
