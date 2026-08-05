---
name: ministere-palmares-eleves-reseau
description: "Espace ministère : meilleurs élèves (palmarès par examen) + élèves du réseau + dossier de l'élève — règles gelées et pièges"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-26T18:35:02.699Z
---

**2026-07-26 — Deux écrans ajoutés à l'espace admin_groupe** (commit `16aacb2`), sur proposition du user : « les 5-10 meilleurs élèves du groupe pour les bourses » et « voir le détail des écoles / chercher un élève ou un agent par établissement ».

**⚠️ Ce qui existait DÉJÀ et ne doit pas être refait** : la fiche école 4 onglets (Infos/Cycles/Utilisateurs/Stats, `schools/school_detail_dialog.dart`, ouvrable depuis Écoles + carte + tableau analytique) et la **recherche du personnel par établissement** (`admin_users_screen` : recherche nom/email/matricule + filtre école + filtre rôle). Le vrai trou était les **élèves**.

## Palmarès national (`/admin/palmares`)
**Base = moyenne à l'EXAMEN D'ÉTAT (`exam_candidates.average`), jamais le contrôle continu.** Une moyenne de bulletin n'est pas comparable entre écoles (enseignants/exigences/coefficients) : classer là-dessus récompense l'indulgence d'un correcteur et se conteste devant la 1ʳᵉ famille écartée. L'examen d'État est la seule épreuve commune, donc la seule opposable. Le contrôle continu est affiché à part et jamais classé entre écoles.

Règles gelées (tests `test/merit_ranking_test.dart`) : **ex æquo = même rang** (1,2,2,4) et le `topN` **ne coupe jamais** un groupe d'égalité ; admis **sans moyenne = hors classement et signalés** (jamais en fin de liste) ; **mention via `mentionFor`** (cf. [[bareme-mention-source-unique]]), jamais relue de la base ; `femaleShare` **`null` sur sélection vide**, jamais 0 %. PDF officiel = `OfficialPdfKit` + `showPdfPreviewDialog`, portant **périmètre + assiette** (sans quoi non opposable).

⚠️ **0 bulletin dans toute la base** au 26/07 → un palmarès bâti sur `bulletins.overall_average` aurait affiché un écran vide ; et les **368 notes existantes sont toutes dans UNE classe** (3ème A Kinkala) → un « top 10 national » aurait sorti 10 élèves de la même école.

## Élèves du réseau (`/admin/eleves`)
**Recherche serveur bornée, pas une liste** — cible 1000+ écoles. Plafond `kStudentSearchLimit = 200`, **troncature DITE à l'écran**. Terme **assaini** (`safeSearch`) avant le filtre PostgREST : une virgule y changerait la requête. Périmètre restreint à identité + scolarité — **médical et discipline ne remontent jamais au groupe** (même règle que `sync_medical`/`sync_discipline`). Lecture seule.

⚠️ **`classes` DOIT être désambiguïsé** : `classes!class_enrollments_class_id_fkey(...)`. `class_enrollments` porte **deux** FK vers `classes` (`class_id` + `previous_class_id`) → sans le hint, PostgREST refuse l'imbrication et l'écran entier tombe en erreur.

## Vérification
Les deux requêtes ont été **testées en réel** contre PostgREST avec un vrai jeton `admin_groupe` (login REST `token?grant_type=password`) avant de coder l'UI — méthode à réutiliser. GUI vérifié : palmarès (10 lauréats/59 admis, 7 écoles, 50 % filles, podium ex æquo), PDF, recherche « okemba » (14), filtre école Kinkala (63). Correctifs de rendu au passage : podium en **hauteur minimale** (fixe → débordement 1 px sur les marches ex æquo) et **gouttière de colonnes** dans les deux tableaux + `OfficialPdfKit.table` (« Comptabilité et GestionPool »).

Voir [[cockpit-metp-pilotage]], [[examens-nationaux-socle]], [[design-gouvernance-anti-redondance]].

---

## 2026-07-27 — Dossier de l'élève, filtres territoire/filière, notes par matière
Commits `1a4acd6` (dossier + filtres + export) et `6776aad` (résultats + palmarès par examen). App **v3.0.7**.

### Dossier de l'élève (ouvert depuis les DEUX écrans)
Une seule fiche fait autorité : `showStudentDossierDialog(context, studentId, distinction:)`. Le palmarès n'a PAS sa propre fiche « lauréat » — il ouvre le même dossier en y ajoutant un bandeau de distinction. Ce bandeau porte **toujours le périmètre du rang** (`MeritFilter.scopeLabel`) : un 1ᵉʳ filtré sur une filière n'est pas un 1ᵉʳ national.
Confidentialité tenue **et écrite dans le document** : `blood_group`/`allergies` et les notes de suivi CPE ne sont **jamais requêtés** au niveau groupe.

### Résultats par matière (remplace « équipe enseignante »)
`computeResults()` dans `student_results_provider.dart` — **fonction pure, testée** (`test/student_results_test.dart`). Trois règles qui décident si un élève PARAÎT en échec :
- une **absence n'est pas un zéro** (exclue, jamais comptée 0) ;
- un **barème n'est pas toujours /20** → ramener via `evaluations.max_score` ;
- une matière non notée **reste visible** (« non évaluée ») sans peser sur la moyenne générale.
Seules les évaluations `status='published'` comptent. La **moyenne de la classe** est affichée à côté de celle de l'élève (12/20 dans une classe à 9 ≠ dans une classe à 15). Mention via `mentionFor`.

### ⚠️ Un palmarès porte sur UN examen
L'option « tous les examens » a été **supprimée** : classer ensemble CEPE et Baccalauréat n'a pas plus de sens que classer sur des bulletins. `resolveExam(data, current)` choisit l'examen le plus représenté et remplace un examen devenu vide. Au 27/07 **un seul examen a des résultats (BET, 59 admis)** — le mélange ne se voyait donc pas, d'où l'urgence de fermer la porte avant.

### ⚠️ PIÈGE PDF — `TooManyPagesException`
`OfficialPdfKit.frame()` enveloppe son contenu dans un `pw.Padding`, **qui ne sait pas se scinder**. Un tableau plus haut qu'une page fait boucler `MultiPage` et **le document ne sort PAS DU TOUT**. Parades, toutes dans le kit :
- `OfficialPdfKit.paginate(rows, first:, next:)` + **un cadre par bloc** + `pw.NewPage()` avant chaque bloc « (suite) » (sinon l'intertitre reste orphelin) ;
- `maxLines: 1` sur chaque cellule (hauteur de ligne déterministe) ;
- écrêtage visible « … » **avant** la coupe muette du moteur ;
- `kpiGrid(width: null)` = répartition sur toute la largeur ; **jamais `crossAxisAlignment: stretch` dans une `Row`** de `MultiPage` (hauteur non bornée → infinie → refus de générer).
Tests : `test/pdf_pagination_test.dart`, `group_students_pdf_test.dart`, `student_dossier_pdf_test.dart` — ils **génèrent vraiment** le PDF (200 lignes, 30 matières).

### Filtres serveur vérifiés en live
`schools!inner` + `.eq('schools.department', …)`. Filière = **INNER JOIN conditionnel** : `class_enrollments!inner(... classes!class_enrollments_class_id_fkey!inner(...))` + cadrage `academic_year_id` sur l'année courante. **Hors filtre filière, garder le LEFT JOIN** sinon les élèves sans classe disparaissent. Anti-rafale **350 ms** sur la saisie (sans lui : 7 requêtes de 200 élèves pour « Mabiala »).

### ⚠️ Libellés — suivre la base, pas la traduction supposée
`class_enrollments.inscription_type` est contraint à **`('new','reinscription','transfer')`**. Les libellés visaient « nouvelle »/« transfert » → le code brut « new » s'affichait dans le dossier.

### Données de démo (seeds appliqués en PROD, additifs et idempotents)
`seed_teaching.sql` puis `seed_results.sql` (scratchpad de session) : 7 écoles avec directeur, 297/297 élèves avec responsable, **31/31 classes** avec enseignants ET notes, **matières professionnelles par filière** (8→12 matières/classe), 602 évaluations publiées, 5 692 notes. Le niveau d'un élève dérive de sa **moyenne à l'examen d'État** quand elle existe → la major du palmarès (18,60) affiche 14,65 en contrôle continu, pas 8.

### 🐛 Dette connue — polices PDF hors ligne
`OfficialPdfKit.loadFonts()` utilise `PdfGoogleFonts.notoSans*()`, qui **télécharge** depuis `fonts.gstatic.com`. Sans réseau et sans cache, repli sur Helvetica **qui n'a pas d'Unicode** → accents cassés sur tous les documents officiels. Produit offline-first : à corriger en embarquant les TTF dans `assets/fonts/`.

---

## 2026-07-28 — Palmarès filtrable par TERRITOIRE et FILIÈRE (mig 0064)
`get_passage_merit` accepte `p_department` et `p_filiere_label`. **Le filtre doit être EN BASE** : la fonction coupe à `p_limit` (200) après tri national, or il y a **216 élèves classables** — filtrer côté client aurait donné « les meilleurs du Niari parmi les 200 meilleurs du pays », faux sans le dire. Vérifié live : Niari 32, Électrotechnique 6.
- Les **options** des listes déroulantes se lisent sur le classement NON restreint (2ᵉ appel), sinon choisir « Niari » ferait disparaître les autres départements et on ne pourrait plus en sortir.
- `PassageFilter.scopeLabel(période)` = **source unique** du périmètre (écran + PDF + bandeau de distinction) ; ordre fixe pour que le même périmètre produise toujours la même phrase. Tests dans `passage_merit_test.dart`.
- ⚠️ `create or replace function` avec une signature élargie crée une SURCHARGE → `drop function ...(types anciens)` d'abord, sinon PostgREST « function name is not unique ».
