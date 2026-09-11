# SCOLARITÉ — analyse

**Slug catégorie** : `scolarite` · **Modules** : 7
**Code concerné** : `features/students/` (86 fichiers, 25 896 l.) · `features/cartes/`
(11 fichiers, 2 690 l.) · `features/vie_scolaire/` pour le seul module `orientation`
(3 fichiers, 968 l.) — **29 554 lignes au total**
**Date** : 2026-09-08

> **Couverture.** Périmètre lu intégralement pour les 7 écrans d'entrée, leurs
> `part` files, les 17 providers de `students/`, les 3 de `cartes/`, les 3 fichiers
> `orientation`, les 21 services et les 3 sous-écrans de `documents`
> (`registre_matricule`, `etat_rentree`, `registre`). Lecture par échantillon
> ciblé (grep + extraits) pour l'assistant d'inscription en 5 étapes
> (`add_inscription_*`, 1 878 l.) et l'import de listes (`import_*`, 1 758 l.) :
> les mécanismes y sont documentés dans la mémoire projet
> ([[import-listes-eleves]], [[inscription-branchee-sur-la-caisse]]) et j'ai
> vérifié les points qu'elle signale comme fragiles plutôt que relu chaque widget.
> **Zone non couverte** : le rendu visuel des 12 services PDF (leur conformité
> structurelle est vérifiée, pas leur mise en page à l'œil).
>
> **Vérifications live** : catalogue `modules`/`profile_permissions` interrogé sur
> le projet `wqpdamlnrwgozfvzjjpo`, `powersync/config/sync-rules.yaml` relu.

---

## A. Vue d'ensemble de la catégorie

La catégorie couvre le **cycle de vie de l'élève** : il entre (`inscriptions`),
il figure (`eleves`), son dossier se constitue (`documents`), sa famille se
joint (`annuaire`), on lui remet une pièce d'identité scolaire (`cartes`), on le
conseille (`orientation`), il part (`transferts`). C'est la catégorie **la plus
mûre de la plateforme** : `_isStaffRole`/offline-first respecté à 100 %
(1 seul appel en ligne, documenté — `national_lookup_provider.dart:134`), 41/41
producteurs PDF sur `OfficialPdfKit`, aucun `Printing.layoutPdf(`, un test
gardien dédié (`test/perimetre_scolarite_test.dart`).

Les 7 modules forment bien un tout, avec **deux réserves de cohérence** :

- **`cartes` est l'intrus opérationnel.** Il est le seul module de la catégorie
  dont le code vit hors de `features/students/`, le seul hors du périmètre du
  test gardien, et **le seul qui n'applique pas le verrou 4** alors que la base
  le lui pose (§ D.7, D.1-#1).
- **`orientation` est un intrus de rangement** — code dans `features/vie_scolaire/`
  — mais son appartenance métier à SCOLARITÉ est **justifiée** (§ D.7).

Manque évident : **rien ne constate une ARRIVÉE**. `transferts` est un registre
de départs ; l'école d'accueil repasse par l'assistant d'inscription. Le pendant
symétrique n'existe pas (§ D.1-#8).

---

## B. Fiche par module

### Élèves — `eleves`

| | |
|---|---|
| Route | `/user/eleves` (+ `/user/eleves/:id` → **redirection** vers `/user/eleves`, `app_router.dart:557-560`) |
| Écran | `ElevesScreen` — `features/students/screens/eleves_screen.dart` (503 l.) + 5 `part` (`eleves_parts` 394, `eleves_liste_parts` 354, `eleves_drawer` 236, `eleves_actions_parts` 502, `eleves_edit` 465, `eleves_kpi_parts` 67) ≈ **2 521 l.** |
| Tables lues | `students`, `class_enrollments`, `classes`, `student_tutors`, `student_documents`, `student_transfers`, `issued_documents` |
| Tables écrites | `students` (update, `is_active=0`), `class_enrollments` (via `setEnrollmentExit`/`changeEnrollmentClass`/`revertEnrollmentToValidation`), `student_tutors`, `student_transfers`, `issued_documents` |
| Profondeur UI | **L3** (9/10) — manque le n° 10 (503 l. > 500) |
| Sortie document | conforme (`students_pdf_service` + `attestations_pdf_service`) — réserve : mention « vue filtrée » absente (D.4) |

**Ce que le module fait** — Registre des PERSONNES effectivement scolarisées :
`students ⨝ class_enrollments (status='active', année active)`, filtré
`COALESCE(s.is_active,1)<>0` et **scopé sur le profil d'accès**
(`students_registry_provider.dart:133,160-161`). KPI démographiques cliquables,
panneau Cycle▸Niveau▸Classe, courbe d'évolution, sélection + actions groupées,
tiroir détail portant tout le cycle de vie (changer de classe, annuler
l'inscription, transférer/radier avec motif normalisé, désactiver, certificat de
scolarité, carte scolaire).

**Ce qui manque**
- **Aucune réactivation.** `deactivateStudent` (`students_provider.dart:351-357`)
  n'a pas de symétrique : `grep -rn "is_active = 1" lib/features/students` ne rend
  que le commentaire d'interdiction (`students_provider.dart:36`). Un élève
  désactivé par erreur — geste à un clic, confirmation générique
  (`eleves_actions_parts.dart:142-145`) — **ne peut plus revenir par l'interface**.
  *Impact : irréversible depuis l'app ; correction en base seulement.*
- **Le PDF « EFFECTIF DES ÉLÈVES » ne dit pas qu'il est filtré.**
  `_previewPdf(filtered)` (`eleves_screen.dart:301,452`) passe la liste filtrée à
  `StudentsPdfService.buildPdf`, dont le bloc titre
  (`students_pdf_service.dart:59-74`) n'expose que école / année / date et un KPI
  « Élèves : N ». Filtrer sur « Internes » puis imprimer produit un document
  d'État intitulé *EFFECTIF DES ÉLÈVES — Lycée X — 2025-2026* annonçant 42 élèves
  pour une école qui en a 800. Doctrine §4-règle 3 à moitié tenue : le contenu
  suit le filtre, le papier se tait. *Impact : chiffre faux affirmé, sur le
  document qui sort de l'école.*
- **Le certificat de radiation n'est jamais réémissible.**
  `delivrerCertificatRadiation` n'est appelé qu'à l'instant de la sortie
  (`eleves_actions_parts.dart:119`) ; `grep -rn "delivrerCertificatRadiation" lib/`
  ne rend que ce site. L'élève sorti quitte `studentsRegistryProvider`
  (`ce.status='active'`), donc son tiroir n'est plus atteignable. Or
  `peutDelivrerRadiation` accepte `withdrawn|transferred|graduated`
  ([[attestations-emises]]) : la capacité existe, aucun écran ne l'expose.
  *Impact : une famille qui revient une semaine plus tard repart sans papier.*
- Le slug est recopié en dur ligne 352 (`studentsRegistryProvider('eleves')`)
  alors que `_kSlug` est déclaré ligne 56 précisément contre cela.

**Ce qui est en double** — Référentiel des cycles (couleur/nom) redéclaré
`eleves_screen.dart:59-76` alors que `scope_drilldown_panel.dart:16-38` expose
déjà `scopeCycleColor/Name/Order` publiquement — et que cet écran importe ce
fichier (ligne 34). Foyer proposé : `scopeCycle*` (cf. D.2-#1).

**Ce que ce module partage** — Produit l'effectif de référence
(`studentsRegistryProvider`) consommé par `documents` et `annuaire` (mêmes
lignes, slug différent) ; produit les sorties d'effectif lues par `classes`,
`paiements-eleves`, `presences-eleves`, `passage`. Consomme `classes`
(`classesForModuleProvider`), `niveaux` (cycle/niveau dénormalisés),
`frais-scolarite` (indirectement, via le tiroir), `cartes`
(`imprimerCarteEleve`, ligne 13).

---

### Inscriptions — `inscriptions`

| | |
|---|---|
| Route | `/user/inscriptions` |
| Écran | `InscriptionsScreen` — `features/students/screens/inscriptions_screen.dart` (617 l.) + 9 `part` (list 523, kpi 131, filtres 387, page 104, actions 516, dossier 487, frais 322, edit 590+56) ≈ **3 733 l.**, plus l'assistant `add_inscription_*` (1 878 l.) et l'import (`import_*`, 1 758 l.) |
| Tables lues | `class_enrollments`, `students`, `classes`, `student_tutors`, `student_documents`, `fee_structures`/`payments` (via `frais_inscription_provider`, `decompte_du_provider`) |
| Tables écrites | `students`, `class_enrollments`, `student_tutors`, `student_documents`, `payments` (encaissement du frais d'inscription) |
| Profondeur UI | **L3** (9/10) — manque le n° 10 (617 l.) |
| Sortie document | conforme (`inscriptions_pdf_service`, `inscription_fiche_service` fiche + lot, reçu de paiement) — réserve « vue filtrée » (D.4) |

**Ce que le module fait** — Le **guichet des admissions** : `status != 'active'`
(`inscriptions_data_provider.dart:218`), scopé profil (ligne 212). Valider fait
SORTIR le dossier vers Élèves. Assistant 5 étapes avec recherche nationale par
INE, import de listes CSV (`;` + Windows-1252, rejet avant écriture), validation
et rejet groupés, réouverture d'un rejet (`reopenRejectedEnrollment`), carte
« Frais d'inscription » branchée sur la caisse, fiche d'inscription imprimable à
l'unité et en lot.

**Ce qui manque**
- **Le pipeline ne filtre pas `students.is_active`.**
  `inscriptions_data_provider.dart:214-224` : la seule condition sur `students` est
  la jointure (ligne 239). Un élève désactivé dont le dossier est resté
  `pending_validation` **reste compté dans le KPI « En attente » à vie**, sans
  aucun moyen de le faire disparaître autrement qu'en le validant. Comparer avec
  `students_registry_provider.dart:160` et `documents_provider.dart:117`, qui
  posent le filtre. *Impact : compteur de travail qui ne descend jamais.*
- **La courbe « Effectif cumulé » de cette page ne dit pas le même nombre que
  celle de la page Élèves.** `yearInscriptionTotalsProvider`
  (`inscriptions_rythme_provider.dart:80-99`) lit `class_enrollments` **sans
  jointure à `students`**, donc sans `is_active` ; `effectifEvolutionProvider`
  (`students_registry_provider.dart:231-247`) joint `students` et filtre
  (ligne 240). Deux graphes, deux réponses, même école, même année. Le second
  porte un commentaire de 20 lignes expliquant pourquoi le filtre est
  indispensable (lignes 201-221) — le premier ne l'a pas reçu.
  *Impact : le fondateur arbitre entre ses propres écrans.*
- **Le filtre de statut ne couvre pas `transferred`/`graduated`.**
  `inscriptions_filtres_parts.dart:379-384` offre `all | pending_validation |
  rejected | withdrawn`. Un élève transféré apparaît sous « Tous » et sous aucun
  segment. *Impact : mineur, mais l'onglet « Sorties » ment sur son périmètre.*
- **`checkStudentQuota` est une garde vide.** `students_provider.dart:193-198`
  retourne `null` inconditionnellement ; elle est appelée
  (`add_inscription_screen.dart:330-337`) et sa valeur traitée comme « quota OK ».
  Le fichier l'assume en 25 lignes de commentaire (le compte est au niveau
  GROUPE, l'appareil ne l'a pas) et renvoie sur le journal `sync_failures`. À
  garder tel quel **ou** à supprimer avec son appel — mais pas à laisser sous une
  signature qui promet un contrôle.

**Ce qui est en double** — `_cycleColor` (`inscriptions_screen.dart:33-40`) et le
référentiel `InscriptionCycle` (`inscriptions_data_provider.dart:39-68`)
redoublent `scopeCycleColor/Name/Order` (D.2-#1). L'heuristique par NOM de classe
(`inscriptionCycleOf`, lignes 71-91) est en revanche un **repli légitime**
(classes sans `level_id`), pas un doublon.

**Ce que ce module partage** — **Producteur unique** de `students` +
`class_enrollments` + `student_tutors` : toute la plateforme en dépend (49
fichiers touchent `class_enrollments`). Consomme `classes`/`niveaux`
(`schoolStructureProvider`), `frais-scolarite` et `paiements-eleves`
(`frais_inscription_provider`, `savePayment`), `documents` (`kRequiredDocTypes`
pour l'avertissement de dossier incomplet).

---

### Orientation — `orientation`

| | |
|---|---|
| Route | `/user/orientation` (`app_router.dart:666`) |
| Écran | `OrientationScreen` — **`features/vie_scolaire/screens/orientation_screen.dart`** (403 l.) + `orientation_sheet.dart` (221) + `orientation_provider.dart` (344) = **968 l.** |
| Tables lues | `student_orientations`, `class_enrollments`, `classes`, `education_levels`, `education_programs`, `trimesters` |
| Tables écrites | `student_orientations` (upsert sur clé métier + `idDeterministe`, delete) |
| Profondeur UI | **L2** (7/10) — manquent n° 1 (recherche seulement DANS une classe ouverte et si > 8 élèves, `orientation_screen.dart:294`), n° 2 (aucun tri), n° 9 (aucune sortie document) |
| Sortie document | **aucune** — `grep -n "showPdfPreviewDialog\|OfficialPdfKit" lib/features/vie_scolaire/screens/orientation_*.dart lib/features/vie_scolaire/providers/orientation_provider.dart` → 0 résultat |

**Ce que le module fait** — Recommandations d'orientation par élève × trimestre.
KPI (orientés / effectif / parents consultés / **réorientés sans fiche**),
panneau de couverture Cycle▸Niveau▸Classe, ouverture d'une classe → liste →
fiche (niveau cible, filière cible, recommandation, parents consultés). Le
périmètre du module est correctement appliqué via
`classesForModuleProvider(kSlugOrientation)` (`orientation_provider.dart:65`) et
l'identité d'écriture via `buildWriteIdentity` (`orientation_sheet.dart:79`).

**Ce qui manque**
- **Rien ne sort de l'orientation.** Aucun PDF, aucun export CSV. C'est pourtant
  la décision qu'on **notifie à la famille** et qu'on transmet à l'établissement
  d'accueil. Le kit existe (`OfficialPdfKit`, `AttestationKit`), 12 services PDF
  vivent à côté dans `students/services/`. *Impact : la recommandation reste
  dans l'écran ; l'école la retape.*
- **La couverture peut dépasser 100 %.** Le numérateur
  (`orientation_provider.dart:87-95`) compte `DISTINCT o.student_id` joints à
  `class_enrollments (status='active')` **sans `students.is_active`** ; le
  dénominateur est `c.studentCount`, qui, lui, filtre `COALESCE(s.is_active,1)<>0`
  (`class_provider.dart:79-80`). Désactiver un élève déjà orienté fait passer sa
  classe à « 13 / 12 orientés ». *Impact : faible en volume, décrédibilisant à
  l'écran.*
- **Le panorama n'est pas réactif.** `orientationOverviewProvider` est un
  `FutureProvider` (ligne 60) invalidé à la main (`orientation_screen.dart:68`) ;
  toute écriture venue d'un autre poste (ou du conseil de classe) ne remonte pas
  tant qu'on ne change pas de trimestre. Le reste de la catégorie est en
  `StreamProvider`/`db.watch`.
- **Aucune vue « tous les orientés »** : sans ouvrir une classe, on ne peut pas
  lister les élèves orientés de l'école, ni chercher un nom.

**Ce qui est en double** — Néant. Le module réutilise `ScopeDrilldownPanel` et le
kit `vs_kit` sans redéclarer de référentiel.

**Ce que ce module partage** — Consomme `passage` (`ce.promotion_decision =
'reoriente'`, ligne 128 — c'est le conseil de classe qui alimente la file « à
orienter ») et `niveaux` (référentiel national `education_levels` /
`education_programs`). Ne produit rien pour d'autres modules : `student_orientations`
n'est lu que par lui (`grep -rln "student_orientations" lib/features/` → 1 fichier).

---

### Transferts — `transferts`

| | |
|---|---|
| Route | `/user/transferts` |
| Écran | `TransfertsScreen` — `features/students/screens/transferts_screen.dart` (304 l.) + `transferts_parts` (483) + `transferts_form` (419) = **1 206 l.** |
| Tables lues | `student_transfers`, `students`, `class_enrollments`, `classes`, `school_groups`, `schools` |
| Tables écrites | `student_transfers` (insert/update/**delete**), `class_enrollments` (update à l'approbation) |
| Profondeur UI | **L3** (9/10) — manque le n° 2 (aucun tri de colonne) |
| Sortie document | conforme (`transfers_pdf_service` + `showPdfPreviewDialog`) — réserve « vue filtrée » |

**Ce que le module fait** — Registre formel des départs, cycle
`pending → approved/rejected → completed`. Destination en cascade
groupe → école sœur, avec repli « hors plateforme » en texte libre. À
l'approbation, l'inscription bascule `transferred`. Périmètre profil appliqué
sur la liste (`transfers_provider.dart:97`) **et** sur le sélecteur d'élève
(ligne 202).

**Ce qui manque**
- **⛔ Le motif normalisé n'est jamais écrit par ce module.**
  `approveTransfer` (`transfers_provider.dart:344-356`) écrit
  `withdrawal_reason` (texte libre, `'Transfert'` par défaut) et **pas
  `withdrawal_motif`**. `grep -rn "withdrawal_motif" lib/` rend 4 sites
  d'écriture — `class_provider.dart:622,675`, `non_revenus_provider.dart:230`,
  `discipline_provider.dart:232` — **aucun dans `features/students/`**. Le
  formulaire ne le demande d'ailleurs pas : `transferts_form.dart:171` propose
  « **Motif (optionnel)** », un `TextField` libre. Or [[motifs-de-sortie-eleve]]
  pose « Motif OBLIGATOIRE aux deux points de sortie » et le tiroir Élève
  l'applique (`eleves_actions_parts.dart:89,421-430`, bouton inactif sans motif).
  **Conséquence** : tout départ traité par le module *fait pour ça* sort avec
  `withdrawal_motif = NULL` et **n'entre pas dans `v_sorties_par_motif`** — la vue
  qui porte la déperdition scolaire et la part de filles par motif.
  *Impact : la statistique nationale de déperdition perd la voie officielle.*
- **⛔ `_submit` teste `== null`, pas `isUsableId`.**
  `transferts_form.dart:45-50` : `if (groupId == null || schoolId == null)`.
  Une chaîne **vide** passe. `createTransfer` écrit alors `group_id = ''` dans une
  colonne `uuid NOT NULL` → `22P02` à la remontée → **le LOT PowerSync ENTIER est
  jeté**. C'est exactement le motif de `core/utils/write_identity.dart` (dont
  l'en-tête, lignes 22-24, note que 20 comptes enseignants sur 67 avaient
  `school_id`/`group_id` NULL en production), et exactement le défaut déjà
  corrigé dans le tiroir Élève (`eleves_actions_parts.dart:67-81`). Le message
  « Profil incomplet » ne nomme même pas ce qui manque, là où
  `writeIdentityMessage` le fait.
- **Aucun certificat de radiation à l'approbation.** Le tiroir Élève le propose
  au moment de la sortie (`eleves_actions_parts.dart:119`) ; `_approve`
  (`transferts_screen.dart:106-117`) ne propose rien. Deux chemins pour le même
  acte, un seul délivre le papier.
- **`exportTransfersCsv` est du code mort.** `transfers_provider.dart:387-412`
  (26 l.) : `grep -rn "exportTransfersCsv" lib/` → sa seule déclaration.
- `deleteTransfer` (ligne 382) supprime définitivement une ligne de registre
  formel, sans trace ; le dialogue le dit (« définitivement »), rien ne le
  journalise.

**Ce qui est en double** — L'écriture d'une sortie d'inscription existe en deux
exemplaires : `setEnrollmentExit` (`class_provider.dart:662-682`, avec motif) et
l'`UPDATE class_enrollments` inline de `approveTransfer`
(`transfers_provider.dart:345-355`, sans motif). Foyer proposé :
`setEnrollmentExit`, seul point d'écriture d'une sortie.

**Ce que ce module partage** — Produit `class_enrollments.status='transferred'`
lu par `eleves`, `classes`, `paiements-eleves`, `passage`, `evaluation`.
Consomme `eleves` (candidats) et le référentiel d'écoles du groupe
(`school_groups`/`schools`). **Devrait** consommer `core/utils/sortie_motif.dart`
(`motifsPour(transfert: true)`) — il ne l'importe pas.

---

### Documents — `documents`

| | |
|---|---|
| Route | `/user/documents` + 3 sous-routes : `/user/documents/etat-rentree`, `/user/documents/registre-matricule`, `/user/documents/registre` (toutes sous `ModuleScaffold(slug: 'documents')`) |
| Écran | `DocumentsScreen` — `features/students/screens/documents_screen.dart` (329 l.) + `documents_parts` (525) + `documents_detail` (475) ; sous-écrans `etat_rentree_screen` (316), `registre_matricule_screen` (307), `registre_screen` (254) |
| Tables lues | `student_documents`, `students`, `class_enrollments`, `classes`, `issued_documents`, `profiles` (état de rentrée), `student_tutors` (registre matricule) |
| Tables écrites | `student_documents` (insert offline via `attachStudentDocumentOffline`, update `is_verified`/`expiry_date`, **delete**) |
| Profondeur UI | **L2** (8/10) — manquent n° 2 (aucun tri) et n° 7 (aucune action primaire dans la barre ; le dépôt vit dans le détail) |
| Sortie document | **non conforme** — l'export ne suit pas la vue affichée (voir ci-dessous et D.4) |

**Ce que le module fait** — Conformité des pièces que l'école **REÇOIT** :
checklist des 3 pièces exigées (`kRequiredDocTypes`), deux vues (« Par élève » /
« Registre »), panneau de conformité Cycle▸Niveau▸Classe, dépôt **offline-first**
(`documents_detail.dart:52`, file d'attente + écriture immédiate de la ligne),
vérification, expiration, consultation par URL signée avec repli fichier local
(lignes 89-98). Il porte aussi les trois documents réglementaires : **état de
rentrée**, **registre matricule**, **documents délivrés**.

**Ce qui manque**
- **⛔ Le bouton PDF exporte autre chose que ce qui est à l'écran.**
  En vue « Registre », l'en-tête affiche « N / M **pièces** »
  (`documents_parts.dart:225-228`) et le bouton PDF juste à côté appelle
  `_previewPdf(filteredDossiers)` (`documents_screen.dart:236-238`), c'est-à-dire
  la liste **des dossiers par élève**, titrée « Dossiers documentaires ». Doctrine
  §4-règle 3 violée frontalement. *Impact : l'agent croit imprimer sa vue.*
- **Le registre « Documents délivrés » ne s'imprime pas.**
  `grep -n "showPdfPreviewDialog" lib/features/students/screens/registre_screen.dart`
  → 0. C'est le seul des trois documents réglementaires sans sortie, alors qu'il
  répond à « qui a délivré ce papier, et quand ? » — la question qu'on pose quand
  un document revient contesté.
- **Le registre matricule perd ses en-têtes de colonne dès la page 2.**
  `registre_matricule_pdf_service.dart:168-182` construit **un seul `pw.Table`**
  de 13 colonnes à largeurs fixes, sans répétition d'en-tête ;
  `OfficialPdfKit.tableSection` la ré-émet à chaque bloc
  (`official_pdf_kit.dart:565-595`). Sur 800 élèves ≈ 20 pages, une seule porte
  les intitulés. *Impact : pièce réglementaire illisible passé la première page.*
  (Même patron, risque moindre car tables bornées, dans
  `etat_rentree_pdf_service.dart:248,305,370`.)
- **Les sous-écrans n'héritent pas du périmètre du module.**
  `registreMatriculeProvider` (`registre_matricule_provider.dart:110-122`) et
  `registreDocumentsProvider` (`registre_provider.dart:55-65`) n'appellent ni
  `classScopeClause` ni `permissionsLoaded`. Un membre en `documents =
  own_classes` — la vue « Par élève » lui montre 12 dossiers — clique
  « Registre matricule » et obtient **l'école entière** avec état civil, adresse
  et téléphone du tuteur. Le test gardien ne couvre que
  `documents_provider.dart` (`test/perimetre_scolarite_test.dart:57`).
  *Nuance honnête : un grand livre est par nature exhaustif ; à trancher — mais
  aujourd'hui c'est un effet de bord, pas une décision.*
- **Un dépôt refusé ne dit rien.** `documents_detail.dart:22-26` : sans
  `schoolId`/`groupId`, `_upload` fait `return;` — pas de sélecteur de fichier,
  pas de message. Le bouton est actif et le clic est avalé. `writeIdentityMessage`
  existe pour ce cas exact et est utilisé six lignes plus loin dans d'autres
  écrans de la catégorie (`annuaire_form.dart:89`).
- **⚠️ L'état de rentrée compte les élèves désactivés.**
  `etat_rentree_provider.dart:180-196` : `WHERE e.school_id = ? AND
  e.academic_year_id = ? AND e.status = 'active'`, `LEFT JOIN students` **sans**
  `COALESCE(s.is_active,1)<>0`. Les pages Élèves, Classes et Paiements, elles,
  filtrent ([[eleve-desactive-ne-compte-plus]], 28 sites corrigés le 16/08). Le
  document qui part à la circonscription — et d'où sortent les **dotations** —
  est donc le seul de la catégorie à sur-compter. La règle 3 de son propre
  en-tête (lignes 23-25) parle d'un élève *radié* (statut d'inscription) ; elle
  ne couvre pas la désactivation administrative, qui ne touche pas le statut.
- `deleteStudentDocument` (`documents_provider.dart:272-274`) supprime la ligne
  et **laisse le fichier Storage orphelin** (le commentaire le dit) : aucun
  ménage n'est prévu.

**Ce qui est en double** — Le découpage en blocs paginés est réimplémenté dans
`enrollment_pdf_shared.dart:63-95` (`_kFirstRows`/`_kNextRows` + section par
cycle) alors que `OfficialPdfKit.paginate`/`tableSection`
(`official_pdf_kit.dart:479-596`) fait la même chose. Doublon **assumé et testé**
(`test/enrollment_pdf_pagination_test.dart`), mais deux endroits où se tromper.
Foyer proposé : `OfficialPdfKit`, en y remontant la notion de « premier bloc plus
court ».

**Ce que ce module partage** — Produit `student_documents` (lu par `inscriptions`
pour l'avertissement de dossier incomplet, `inscriptions_actions.dart:206-219`)
et `issued_documents`, **registre partagé avec les RH** (`cartes` y écrit,
`staff/screens/personnel_dossier_sheet.dart:39` aussi — attestation de travail).
Consomme `eleves` (`studentsRegistryProvider('documents')`), `personnel`
(`profiles` pour le volet Personnel de l'état de rentrée).

---

### Annuaire — `annuaire`

| | |
|---|---|
| Route | `/user/annuaire` |
| Écran | `AnnuaireScreen` — `features/students/screens/annuaire_screen.dart` (285 l.) + `annuaire_parts` (542) + `annuaire_detail` (333) + `annuaire_form` (342) = **1 502 l.** |
| Tables lues | `student_tutors`, `students` (via `studentsRegistryProvider('annuaire')`), `classes` |
| Tables écrites | `student_tutors` (add/update/delete, gardés permissions) |
| Profondeur UI | **L2** (8/10) — manquent n° 2 (aucun tri) et n° 7 (pas d'action primaire dans la barre) |
| Sortie document | conforme (`annuaire_pdf_service` + aperçu) — réserve « vue filtrée » |

**Ce que le module fait** — Répertoire des familles : élève actif + ses tuteurs,
téléphone cliquable (`tel:`), KPI de **couverture contact**, bascule « Sans
contact », panneau de couverture par cycle/niveau/classe, CRUD tuteur dans le
détail. Le périmètre est hérité du registre sous son propre slug
(`annuaire_provider.dart:78`) et les 4 KPI comptent désormais le même ensemble
que la liste (lignes 104-124) — les deux points verrouillés par
`test/perimetre_scolarite_test.dart:116-140`.

**Ce qui manque**
- **Le commentaire de `schoolTutorsProvider` est faux depuis le 2026-08-29.**
  `annuaire_provider.dart:28-29` affirme : « Elle écarte aussi les tuteurs d'un
  élève désactivé, que `students` ne descend plus (`is_active = true`) ». Or le
  filtre a été **retiré des sync-rules** (`powersync/config/sync-rules.yaml:255-267`,
  avec 12 lignes expliquant pourquoi) : `SELECT * FROM students WHERE school_id =
  bucket.sid`, sans condition. La requête (lignes 38-44) ne filtre pas non plus.
  *Impact aujourd'hui : nul à l'écran* (`familiesProvider` regroupe sur le
  registre, qui filtre) *— mais c'est un commentaire qui autorisera le prochain
  lecteur à s'appuyer sur une garantie inexistante.*
- **Aucun tri.** Une école de 800 familles n'a que l'ordre `last_name` figé au
  SQL. Pas de tri par classe, ni par « sans contact d'abord ».
- **Aucune action groupée**, alors que le geste métier évident est « exporter les
  numéros de la 6ᵉ A » ou « relancer les 43 familles sans contact » : le bouton
  « Sans contact » filtre, puis il faut recopier.
- **Aucun export CSV.** Le PDF existe ; un annuaire sert aussi à alimenter un
  outil de SMS. `grep -n "csv\|Csv" lib/features/students/providers/annuaire_provider.dart`
  → 0.

**Ce qui est en double** — Néant.

**Ce que ce module partage** — Seul écran qui écrit `student_tutors` en dehors de
l'assistant d'inscription et du tiroir Élève. `student_tutors` est lu par
`registre_matricule_provider.dart`, `student_dossier_provider.dart` et
`evaluation/providers/non_revenus_provider.dart` (contact des non revenus).
Consomme `eleves`.

---

### Cartes scolaires — `cartes`

| | |
|---|---|
| Route | `/user/cartes` |
| Écran | `CartesScreen` — **`features/cartes/screens/cartes_screen.dart`** (302 l.) + `cartes_parts` (334) + `cartes_filtres_barre` (218) + import photos (821) ; providers 515 ; services 500. **Le dessin de la carte vit dans `students/services/`** (`carte_scolaire_pdf_service` 211, `carte_scolaire_dessin` 301, `carte_scolaire_modele` 102) |
| Tables lues | `classes`, `class_enrollments`, `students`, `education_cycles` |
| Tables écrites | `students.photo_url` (via `updateStudent`), `issued_documents` (une ligne **par élève**) |
| Profondeur UI | **L2** (8/10) — manquent n° 1 (aucun champ de recherche : `grep -n "TextField" lib/features/cartes/screens/cartes_screen.dart lib/features/cartes/screens/cartes_parts.dart lib/features/cartes/screens/cartes_filtres_barre.dart` → 0) et n° 2 (aucun tri) |
| Sortie document | conforme (`showPdfPreviewDialog` + `OfficialPdfKit`, `pw.Page` pour la planche, registre d'émission alimenté) |

> **Levée d'ambiguïté demandée.** `features/cartes/` contient **exclusivement**
> la campagne de **cartes scolaires des élèves** : `cartes_provider` (classes ×
> avancement photo), `import_photos_*` (appariement de fichiers photo aux
> élèves), `cartes_actions` (planche A4 de 10 cartes recto-verso). **Aucune
> cartographie.** La carte nationale de tutelle vit ailleurs :
> `features/super_admin/screens/national_map_screen.dart` (808 l.) et
> `features/admin_groupe/screens/regional/regional_map.dart` (1 045 l.).
> ⚠️ **`00-CATALOGUE.md:115` range `features/cartes/` sous l'espace Tutelle** —
> c'est une erreur du catalogue (cf. D.7-#3).

**Ce que le module fait** — La campagne de rentrée : compter les **visages
manquants** avant de proposer d'imprimer, classe par classe ; import de photos
en masse avec appariement et validation avant écriture ; planche A4 de 10 cartes ;
duplicata à l'unité depuis le tiroir Élève. La doctrine du module est
remarquable (l'écran refuse de faire découvrir un cadre vide aux ciseaux,
`cartes_actions.dart:53-87`) et l'écriture est offline-first de bout en bout.

**Ce qui manque**
- **⛔ Le verrou 4 n'est jamais posé.**
  `grep -rn "classScopeClause\|permissionsLoaded" lib/features/cartes/` → **0
  résultat**. `cartesClassesProvider` (`cartes_provider.dart:72-95`) et
  `cartesElevesProvider` (lignes 155-187) filtrent sur `academic_year_id` /
  `class_id` et **rien d'autre** — pas même `school_id`. Or la base **pose** ce
  verrou : sur le projet live, le profil « Enseignant » a
  `modules.slug='cartes'` avec `can_read = true` et
  `data_scope = 'own_classes'` (7 lignes `profile_permissions`, comme les 6
  autres modules de la catégorie). Un enseignant restreint à ses deux classes
  ouvre `/user/cartes` et lit **toute l'école** : nom, INE, date et lieu de
  naissance, statut d'interne et **`blood_group`** (donnée de santé,
  `cartes_provider.dart:157,178`). C'est le même oubli, au même endroit, que
  celui réparé quatre fois dans `students/providers/` — et `cartes` est
  précisément le seul module de la catégorie **hors du périmètre du test
  gardien** (`test/perimetre_scolarite_test.dart:46,52-59` ne balaie que
  `lib/features/students/providers`).
  *Impact : fuite nominative + santé sur le profil enseignant livré en base.*
- **⛔ Le bouton d'impression groupée contourne le verbe `export`.**
  Le bouton par classe est gardé (`cartes_parts.dart:225-233`,
  `PermissionGate(slug:'cartes', action:'export')`), le bouton « Éditer la
  sélection » ne l'est pas (`cartes_screen.dart:290-299` : `if
  (onImprimerSelection != null) FilledButton.icon(...)`). Sur le profil
  « Enseignant », `can_export = false` (vérifié en base) : il ne peut pas
  imprimer UNE classe, il peut imprimer TOUTES.
- **Les cartes ignorent `students.is_active`.** `peutDelivrerCarte(status)`
  (`carte_scolaire_modele.dart:38`) ne regarde que le statut d'inscription. Un
  élève désactivé — absent de la liste Élèves — est compté dans « élèves » et
  « avec photo » (`cartes_provider.dart:81-83`) et **reçoit une carte** sur la
  planche. Troisième compteur d'effectif de la catégorie qui diverge (avec
  Inscriptions et État de rentrée).
- **`peutProduireDesCartes` est du code mort.** `cartes_actions.dart:222-225` :
  `grep -rn "peutProduireDesCartes" lib/` → sa seule déclaration. Le commentaire
  la présente comme « le rôle sert de garde-fou local » — garde-fou que personne
  n'appelle : un rôle `eleve` ou `parent` n'est arrêté que par le verrou 3.
- **L'erreur s'affiche brute.** `cartes_screen.dart:79` :
  `AdminErrorBanner(message: '$e')` — les 6 autres modules passent par
  `messageErreur(e)`. Une secrétaire lit un message SQLite.
- Pas de recherche : retrouver un élève pour un duplicata oblige à passer par la
  page Élèves (`eleves_screen.dart:13`, `imprimerCarteEleve`).

**Ce qui est en double** — Le module **importe** `ScopeDrilldownPanel` depuis
`features/students/widgets/` (`cartes_screen.dart:7`) et le service PDF depuis
`features/students/services/` (`cartes_provider.dart:26`) : pas de duplication de
code, mais une dépendance croisée qui montre que le découpage en dossiers ne suit
pas le module (D.7-#3).

**Ce que ce module partage** — Écrit `students.photo_url` (consommé par
`eleves`, `inscriptions`, `personnel`, bulletins) et alimente `issued_documents`
(une ligne par élève, `cartes_actions.dart:124-133`). Consomme `eleves` (le
tiroir appelle `imprimerCarteEleve`), `classes`, `niveaux`.

---

## C. Relations entre les modules DE cette catégorie

```
                        ┌──────────────────────────────────────────┐
                        │  import CSV (Excel FR ; Windows-1252)     │
                        └────────────────┬─────────────────────────┘
                                         ▼
   recherche nationale (INE, RPC)   ┌──────────────┐   validation
   ───────────────────────────────► │ INSCRIPTIONS │ ─────────────►  ÉLÈVES
                                    │  status ≠    │                (status =
                                    │  'active'    │ ◄───────────    'active')
                                    └──────┬───────┘  revertEnrollment
                                           │
                             frais d'inscription (→ FINANCE)
                                           │
        ┌──────────────────┬───────────────┴──────┬──────────────────┐
        ▼                  ▼                      ▼                  ▼
   DOCUMENTS           ANNUAIRE                CARTES           ORIENTATION
   (pièces reçues)    (tuteurs)            (photo + planche)   (recommandation)
        │                  │                      │                  ▲
        │  studentsRegistryProvider(slug) ────────┘                  │
        │  ⚠ CARTES ne l'utilise PAS                       promotion_decision
        │                                                   = 'reoriente'
        ▼                                                    (← PASSAGE)
   issued_documents  ◄──── carte scolaire, certificats, attestation RH
   (registre d'émission)
        ▲
        │  ⛔ AUCUN lien : DOCUMENTS ne sait pas ÉMETTRE
        │     (les certificats ne partent que du tiroir ÉLÈVES)
        │
   ÉLÈVES ──── sortie (motif normalisé ✓) ──► class_enrollments.withdrawal_motif
        │                                                 ▲
        └──── createTransfer(completed) ──► TRANSFERTS ────┘
                                              ⛔ approveTransfer n'écrit PAS
                                                 withdrawal_motif
```

**Ce qui tient.** L'axe `inscriptions → eleves` est net et testé (deux
provideurs disjoints sur `status`, pas de doublon d'effectif) ; le drill-down
Cycle▸Niveau▸Classe est un composant unique partagé par 4 des 7 modules ; le
périmètre profil est appliqué de façon homogène dans `students/providers/` et
verrouillé par un test de source.

**Où la chaîne casse — trois ruptures.**

1. **La sortie a deux portes, une seule est réglementaire.** Le tiroir Élève
   exige un motif normalisé, alimente le registre des transferts *et* délivre le
   certificat de radiation. Le module Transferts — la porte que son nom désigne —
   ne fait aucune des trois. Résultat : le même acte produit des données de
   qualité différente selon le clic.
2. **`documents` reçoit, personne n'émet depuis `documents`.** Le registre des
   documents délivrés vit sous ce module, mais aucune délivrance ne part de lui :
   `delivrerCertificatScolarite`/`Radiation` ne sont appelés que depuis
   `eleves_actions_parts.dart:119,161`. Le secrétaire qui travaille dans
   « Documents » doit sortir du module pour faire le geste que le module raconte.
3. **`cartes` est branché sur les données de la catégorie sans en partager les
   garde-fous** : il lit `students` en direct au lieu de
   `studentsRegistryProvider`, et perd du même coup le périmètre, le filtre
   `is_active` et le squelette de chargement.

---

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `cartes` | Verrou 4 (`data_scope`) jamais appliqué → tout enseignant lit l'école entière, `blood_group` compris | `grep -rn "classScopeClause\|permissionsLoaded" lib/features/cartes/` → 0 ; `cartes_provider.dart:72-95,155-164` ; base live : profil « Enseignant » = `cartes`/`own_classes`/`can_read=true` | Fuite nominative + donnée de santé sur le profil livré par défaut | **S** (copier le patron de `students_registry_provider.dart:133`) |
| 2 | `transferts` | `withdrawal_motif` jamais écrit ; formulaire « Motif (optionnel) » en texte libre | `transfers_provider.dart:344-356` ; `transferts_form.dart:171` ; `grep -rn "withdrawal_motif" lib/` → 4 sites, aucun dans `students/` | La déperdition scolaire nationale perd la voie officielle du transfert | **S** (appeler `setEnrollmentExit` + `motifsPour(transfert:true)`) |
| 3 | `transferts` | `_submit` teste `== null` au lieu de `isUsableId` → `group_id=''` → `22P02` → **lot PowerSync entier perdu** | `transferts_form.dart:45-50` vs `write_identity.dart:29` et `eleves_actions_parts.dart:74-81` | Une matinée de saisie (inscriptions, paiements, présences) disparaît sans message | **XS** |
| 4 | `documents` | L'état de rentrée compte les élèves désactivés (aucun `s.is_active`) alors qu'Élèves/Classes/Paiements les excluent | `etat_rentree_provider.dart:180-196` vs `students_registry_provider.dart:160`, `class_provider.dart:79-80` | Le document qui décide des **dotations** sur-compte | **XS** |
| 5 | `documents` | Le bouton PDF de la vue « Registre » exporte les dossiers par élève | `documents_screen.dart:236-238` + `documents_parts.dart:225-228` | Doctrine §4-3 : on n'imprime pas ce qui est à l'écran | **XS** |
| 6 | `cartes` | « Éditer la sélection » non gardé par `export`, alors que le bouton par classe l'est | `cartes_screen.dart:290-299` vs `cartes_parts.dart:225-233` | Un profil sans droit d'export imprime toute l'école | **XS** |
| 7 | `eleves` | Certificat de radiation non réémissible (offert seulement à l'instant de la sortie) | `grep -rn "delivrerCertificatRadiation" lib/` → 1 site (`eleves_actions_parts.dart:119`) ; capacité présente (`peutDelivrerRadiation`) | Une famille qui revient repart sans papier | **S** |
| 8 | catégorie | Aucun module ne constate une **arrivée** : `student_transfers` n'est lu que par `from_school_id` | `transfers_provider.dart:118` ; `grep -rn "to_school_id" lib/features/` → écriture seule | L'école d'accueil ne voit pas venir l'élève qu'on lui envoie ; doublon d'identité | **M** |
| 9 | `orientation` | Aucune sortie document | `grep -n "showPdfPreviewDialog\|OfficialPdfKit" lib/features/vie_scolaire/{screens/orientation_*,providers/orientation_provider}.dart` → 0 | La recommandation ne quitte pas l'écran ; l'école la retape | **S** |
| 10 | tous (7/7) | Aucun PDF ne porte la mention « vue filtrée » | `grep -rn "vue filtrée" lib/features/students lib/features/cartes` → 0 ; l'infrastructure existe (`core/services/fiche_detail_pdf.dart:204`) | Un extrait filtré ressemble à un état complet | **S** (un paramètre `filtre` par service) |
| 11 | `documents` | Registre matricule : en-têtes de colonne non répétées après la page 1 | `registre_matricule_pdf_service.dart:168-182` vs `official_pdf_kit.dart:565-595` | 19 pages sur 20 illisibles sur une pièce réglementaire | **S** |
| 12 | `documents` | Registre « Documents délivrés » sans aucune sortie imprimable | `grep -n "showPdfPreviewDialog" .../registre_screen.dart` → 0 | Le journal anti-fraude ne se produit pas devant l'inspection | **S** |
| 13 | `documents` | Un dépôt de pièce refusé pour identité manquante est **silencieux** | `documents_detail.dart:22-26` (`return;` sans message) | 20 comptes sur 67 étaient concernés en juillet (`write_identity.dart:22-24`) | **XS** |
| 14 | `inscriptions` | Pipeline et courbe cumulée sans `s.is_active` ; la courbe contredit celle d'Élèves | `inscriptions_data_provider.dart:214-224` ; `inscriptions_rythme_provider.dart:80-99` vs `students_registry_provider.dart:240` | Deux écrans, deux effectifs ; KPI « En attente » qui ne descend jamais | **XS** |
| 15 | `eleves` | Aucune réactivation d'un élève désactivé | `grep -rn "is_active = 1" lib/features/students` → 0 écriture | Geste à un clic, irréversible sans intervention en base | **S** |
| 16 | `orientation` | Couverture pouvant dépasser 100 % (numérateur sans `is_active`, dénominateur avec) | `orientation_provider.dart:87-95` vs `class_provider.dart:79-80` | « 13 / 12 orientés » | **XS** |
| 17 | `annuaire` | Ni tri, ni actions groupées, ni export CSV | `annuaire_screen.dart:92-108` (filtre seul) ; `grep -n "csv" .../annuaire_provider.dart` → 0 | Relancer 43 familles sans contact se fait à la main | **S** |
| 18 | `orientation` | Ni recherche globale, ni tri, ni liste « tous les orientés » ; panorama non réactif (`FutureProvider`) | `orientation_screen.dart:294` (recherche conditionnée à une classe ouverte + > 8 élèves) ; `orientation_provider.dart:60` | Écran de saisie plus que de pilotage | **M** |
| 19 | `documents` | Sous-écrans (registre matricule, documents délivrés) hors périmètre du module | `registre_matricule_provider.dart:110-122`, `registre_provider.dart:55-65` : ni `classScopeClause` ni `permissionsLoaded` | Un membre `own_classes` accède à l'école entière par la porte de derrière | **S** (ou décision explicite) |
| 20 | `documents` | Fichiers Storage orphelins après suppression d'une pièce | `documents_provider.dart:272-274` (le commentaire l'assume) | Croissance du bucket, pièces supprimées encore lisibles par URL signée | **M** |

### D.2 Doublons et redondances — vue consolidée

| # | Modules concernés | Ce qui est dupliqué | A (`fichier:ligne`) | B (`fichier:ligne`) | Nature | Foyer proposé |
|---|---|---|---|---|---|---|
| 1 | `eleves`, `inscriptions`, + 9 domaines hors catégorie | Référentiel des cycles (code → couleur / nom / ordre / icône) | `students/widgets/scope_drilldown_panel.dart:16-38,384-391` (déjà **public**) | `students/screens/eleves_screen.dart:59-76` · `students/screens/inscriptions_screen.dart:33-40` · `students/providers/inscriptions_data_provider.dart:39-68` · `students/services/enrollment_pdf_shared.dart:11-40` — et hors catégorie `classes/screens/classes_screen.dart:24,32,40`, `structure/screens/programmes_screen.dart:28,39,49`, `structure/services/programmes_pdf_service.dart:15,23,31`, `structure/screens/academic_structure_screen.dart:22,34`, `structure/screens/subject_detail_dialog.dart:20`, `staff/widgets/staff_kit.dart:104`, `staff/screens/personnel_cycle_kpis.dart:58`, `admin_groupe/screens/schools/school_detail_tabs.dart:69,78` | **14 copies**, pas de divergence fonctionnelle constatée aujourd'hui (les 5 codes + l'alias `fp`/`formation_pro` sont partout) — mais aucune source unique | `core/utils/cycles.dart` (à créer) ou promotion de `scopeCycle*` ; puis test de source interdisant un littéral `'prescolaire'` hors de ce fichier |
| 2 | `transferts`, `eleves` | Écriture d'une sortie d'inscription | `classes/providers/class_provider.dart:662-682` (`setEnrollmentExit`, **avec** motif) | `students/providers/transfers_provider.dart:344-356` (`UPDATE` inline, **sans** motif) | Divergence réelle : les deux chemins ne produisent pas la même donnée | `setEnrollmentExit`, point d'écriture unique |
| 3 | `documents`, `eleves`, `inscriptions` | Pagination de tableau PDF en blocs | `core/services/official_pdf_kit.dart:479-596` (`paginate` + `tableSection`, répète les en-têtes) | `students/services/enrollment_pdf_shared.dart:63-95` (`_kFirstRows`/`_kNextRows`) | Doublon **assumé et testé** (`test/enrollment_pdf_pagination_test.dart`) — deux endroits où se tromper | `OfficialPdfKit`, en y remontant « premier bloc plus court » |
| 4 | `inscriptions` | Compteurs de l'année vs compteurs du guichet | `inscriptions_rythme_provider.dart:80-99` (`enrolled`, cumul — **sans** `is_active`) | `students_registry_provider.dart:231-247` (`effectifEvolutionProvider` — **avec**) | Deux réponses au même « combien d'élèves ? » sur deux pages voisines | Une seule lecture d'effectif, celle du registre |
| 5 | `documents` | Chemin de lecture des pièces | `documents_provider.dart:91-142` (`schoolDocumentsProvider`, avec périmètre) | `documents_provider.dart:147-179` (`studentDocRowsProvider`, sans, mais ciblé par `student_id`) | **Légitime** (un détail n'a pas à re-scoper une clé déjà résolue) — signalé pour éviter un faux positif à la fusion | — |

*Faux positifs écartés* : `ScopeDrilldownPanel` réutilisé par 18 fichiers hors
catégorie est un **partage voulu**, pas un doublon ; `inscriptionCycleOf`
(heuristique par nom de classe) est un **repli** documenté pour les classes sans
`level_id`, pas une seconde source.

### D.3 Données partagées HORS catégorie

| Donnée / table | Module producteur | Modules consommateurs (slug) | Contrat implicite | Risque si rompu |
|---|---|---|---|---|
| `students` (identité, `photo_url`, `ine`, `is_active`) | `inscriptions` (création), `eleves` (cycle de vie), `cartes` (`photo_url`) | `classes`, `notes`, `bulletins`, `conseils`, `passage`, `examens`, `stages`, `frais-scolarite`, `paiements-eleves`, `presences-eleves`, `discipline`, `infirmerie`, `cantine`, `bibliotheque`, Rapports & Dashboard (`features/user/`), espace Réseau | « Un élève de la liste est actif » = `COALESCE(is_active,1)<>0`. **Le filtre est à la charge de chaque lecteur** : les sync-rules ne le posent plus (`sync-rules.yaml:255-267`, retrait assumé du 2026-08-29) | Effectifs, dettes et taux de recouvrement divergents d'un écran à l'autre — déjà survenu ([[eleve-desactive-ne-compte-plus]]) ; 3 lecteurs de la catégorie ne le posent toujours pas (D.1 #4, #14, et `cartes`) |
| `class_enrollments` (`status`, `withdrawal_motif`, `is_repeating`, `promotion_decision`) | `inscriptions`, `eleves`, `transferts` | **49 fichiers / 12 domaines** (`grep -rln "class_enrollments" lib/features/`) | `status='active'` = scolarisé ; `withdrawal_motif` ∈ nomenclature fermée mig. 0082 ; `is_repeating` lu tantôt en SQL (`= 1`), tantôt en Dart (`== 1 \|\| == true`), tantôt `== true` seul (`admin_groupe/providers/student_dossier_provider.dart:410`) | Motif absent ⇒ `v_sorties_par_motif` incomplète (D.1-#2) ; lecture `== true` seule ⇒ redoublants comptés à 0 côté Réseau — **à vérifier sur poste réel**, signalé comme non couvert par [[inscription-branchee-sur-la-caisse]] |
| `student_tutors` | `annuaire`, `inscriptions` | `evaluation` (`non_revenus_provider` : contacter les non revenus), espace Réseau (`student_dossier_provider`) | `is_primary_contact` désigne le numéro qu'on compose ; `school_id` posé par trigger (mig. 0110) | `primaryTutorProvider` fait `LIMIT 1` sur `is_primary_contact=1` : sans principal coché, l'école a des numéros et aucun ne se présente (`students_registry_provider.dart:79-86`) |
| `student_documents` | `documents` | `inscriptions` (avertissement de dossier incomplet, `inscriptions_actions.dart:206-219`) | 3 pièces exigées = `kRequiredDocTypes` (`documents_provider.dart:19-23`) — source unique respectée | Élargir la liste sans prévenir Inscriptions changerait le sens de « dossier complet » à la validation groupée |
| `issued_documents` | `documents` (`registre_documents.dart`), `cartes`, **et `personnel` (RH)** | `documents` (registre), `eleves` (duplicatas) | Journal partagé élèves + agents ; `noterDocumentEmis` **ne lève jamais** et s'abstient sans identité valide (lignes 14-25) | Un membre ayant `documents` en lecture voit les attestations de travail délivrées aux agents (`staff/screens/personnel_dossier_sheet.dart:39`) — pas de salaire, mais un fait RH dans un registre scolaire |
| `students.photo_url` | `cartes` (import de masse), `eleves`/`inscriptions` (webcam) | `bulletins`, `personnel`, `presences-eleves` (avatars) | URL publique calculée hors ligne par `queueAvatarUpload`, octets envoyés au retour du réseau | Une photo « présente » en base peut être introuvable sur un poste : `preparerCartes` mesure l'écart réel (`cartes_provider.dart:189-236`) — bonne pratique à généraliser |
| `academic_years` | `structure` (hors catégorie) | les 7 modules | ⚠️ **`academic_years.school_id` est NULL** : les années sont portées par le GROUPE ([[non-revenus-et-exclusion]]). Toutes les requêtes de la catégorie passent par `activeYearIdProvider`, jamais par une résolution maison | Résoudre « l'année précédente » par identifiant désignerait une ligne sans inscription — piège évité ici |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` ? | `showPdfPreviewDialog` ? | `Printing.layoutPdf(` ? | Verdict |
|---|---|---|---|---|---|
| `eleves` | PDF effectif + certificat scolarité + certificat radiation + CSV | ✅ (`students_pdf_service.dart:25,55,59,69` ; `attestations_pdf_service` via `AttestationKit`, 42 réf.) | ✅ (`eleves_screen.dart:311`) | ❌ aucun | **Conforme** — réserve : pas de mention « vue filtrée » (`students_pdf_service.dart:59-67`) |
| `inscriptions` | PDF liste + fiche unitaire + **lot de fiches** + reçu de paiement + CSV | ✅ (`inscriptions_pdf_service.dart:23,59,67,77` ; `inscription_fiche_service.dart`, 12 réf.) | ✅ (`fiche_inscription_actions.dart:44,118`) | ❌ | **Conforme** — même réserve |
| `orientation` | **aucune** | — | — | ❌ | **Aucune sortie** (D.1-#9) |
| `transferts` | PDF registre | ✅ (`transfers_pdf_service.dart`, 10 réf.) | ✅ (`transferts_screen.dart:164`) | ❌ | **Conforme** — réserve « vue filtrée » |
| `documents` | PDF dossiers · état de rentrée · registre matricule · **rien pour les documents délivrés** | ✅ (`documents_pdf_service` 10 réf., `etat_rentree_pdf_service` 4, `registre_matricule_pdf_service` 4) | ✅ (`documents_screen.dart:156`, `etat_rentree_screen.dart:43`, `registre_matricule_screen.dart:47`) | ❌ | **Non conforme** : (a) l'export ne suit pas la vue affichée (`documents_screen.dart:236`) ; (b) tables à la main sans répétition d'en-tête (`registre_matricule_pdf_service.dart:168`, `etat_rentree_pdf_service.dart:248,305,370`) ; (c) registre des délivrances non imprimable |
| `annuaire` | PDF répertoire | ✅ (`annuaire_pdf_service.dart`, 10 réf.) | ✅ (`annuaire_screen.dart:126`) | ❌ | **Conforme** — réserve « vue filtrée » ; pas d'export CSV |
| `cartes` | Planche A4 + carte unitaire | ✅ (`carte_scolaire_pdf_service.dart`, 4 réf., **`pw.Page`** ×2 — jamais `MultiPage`) | ✅ (`cartes_actions.dart:145,204`) | ❌ | **Conforme** — et alimente `issued_documents` ligne par élève. Réserve : impression groupée non gardée par `export` |

**Mesures du périmètre** (commentaires retirés, comme dans `22-transversal-documents.md`) :

- `grep -rn "Printing\.layoutPdf(" lib/features/students lib/features/cartes lib/features/vie_scolaire/screens/orientation_*.dart` → **0** (les 9 survivances de la plateforme sont toutes hors catégorie : 6 dans Fondateur, 1 Réseau, 1 `structure`, 1 `super_admin`).
- `grep -rn "PdfGoogleFonts" lib/features/students lib/features/cartes` → **0**.
- `grep -rn "OfficialPdfKit.tableSection" lib/features/students lib/features/cartes` → **0** — la catégorie n'utilise **jamais** l'API prescrite : elle passe soit par `OfficialPdfKit.table` (annuaire, documents, transferts, fiche d'inscription), soit par son propre `enrollment_pdf_shared` (élèves, inscriptions), soit par `pw.Table` à la main (registre matricule, état de rentrée). Les deux premiers sont testés ; le troisième est le vrai écart.
- 12 services PDF dans `students/services/` + 1 dans `cartes/services/` = **le plus gros gisement documentaire de la plateforme**, et il est propre sur l'essentiel.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe vraiment |
|---|---|---|---|---|---|
| 1 | `inscriptions` | Case morte | `students_provider.dart:193-198` + appel `add_inscription_screen.dart:330-337` | Le quota d'élèves est vérifié avant création | `checkStudentQuota` retourne `null` inconditionnellement. Le fichier l'assume en 25 lignes (le compte est au niveau GROUPE) et renvoie sur `sync_failures` — mais la signature promet un contrôle |
| 2 | `cartes` | Case morte | `cartes_actions.dart:222-225` | « Le rôle sert de garde-fou local » | `peutProduireDesCartes` n'est appelée nulle part (`grep -rn` → 1 déclaration) |
| 3 | `transferts` | Code mort | `transfers_provider.dart:387-412` | — | `exportTransfersCsv` (26 l.) n'a aucun appelant ; le module n'offre pas d'export CSV |
| 4 | `annuaire` | Commentaire menteur | `annuaire_provider.dart:28-29` | « Elle écarte les tuteurs d'un élève désactivé, que `students` ne descend plus (`is_active = true`) » | Le filtre a été **retiré** des sync-rules le 2026-08-29 (`powersync/config/sync-rules.yaml:255-267`) et la requête (l.38-44) n'en pose aucun. Sans effet visible aujourd'hui, mais c'est une garantie inexistante offerte au prochain lecteur |
| 5 | `documents` | Refus silencieux | `documents_detail.dart:22-26` | Bouton « Ajouter » actif | Sans `schoolId`/`groupId`, `return;` — pas de sélecteur, pas de message. Concernait 20 comptes sur 67 en juillet |
| 6 | `documents` | Zéro menteur assumé | `students/services/registre_documents.dart:128-130` | Le registre répond « combien de cartes cet enfant a-t-il reçues ? » | Le `catch (_) {}` avale l'échec d'écriture : le document sort, la ligne peut manquer. Arbitrage **explicite** (« le document passe avant son enregistrement », règle 1) — mais le registre est alors un minorant, et rien ne le dit à l'écran |
| 7 | `inscriptions` | Zéro permissif | `inscriptions_actions.dart:206-214` | « N dossier(s) incomplet(s) » à la validation groupée | Une lecture ratée rend `[]` = dossier complet ⇒ la mention affiche 0. Arbitrage documenté (ne pas barrer l'entrée d'un enfant), effet non signalé |
| 8 | `cartes` | Erreur brute | `cartes_screen.dart:79` | Message d'erreur | `AdminErrorBanner(message: '$e')` — exception SQLite affichée telle quelle ; les 6 autres modules passent par `messageErreur(e)` |
| 9 | `inscriptions` | Compteur bloqué | `inscriptions_data_provider.dart:214-224` | KPI « En attente : N » | Un élève désactivé au dossier `pending_validation` y reste indéfiniment : aucune action de l'écran ne peut l'en retirer |

**Ce que la catégorie fait bien sur cet axe** (à ne pas re-signaler) : les
`catch (_)` restants (11 occurrences) sont tous accompagnés de leur raison ; les
actions groupées d'Élèves et d'Inscriptions comptent et NOMMENT les échecs
(`eleves_screen.dart:192-201`, `inscriptions_screen.dart:246-273`) après avoir
été le contraire ; le registre matricule refuse de se présenter comme complet
quand des lignes manquent (`registre_matricule_pdf_service.dart:132-149`) ;
la préparation des cartes mesure les visages **réellement chargés** et non
`photo_url` (`cartes_provider.dart:189-236`) ; l'état de rentrée compte à part
les élèves sans sexe, sans date de naissance et sans classe
(`etat_rentree_provider.dart:200,320-325`).

### D.6 Dette de structure

**13 fichiers > 500 lignes** (`wc -l`), tous dans `features/students/` :

| Fichier | Lignes | Couture de découpe proposée |
|---|---|---|
| `screens/add_inscription_steps_1_2.dart` | 710 | Une étape = un fichier : `add_inscription_step_identite.dart` (état civil + recherche nationale) / `add_inscription_step_tuteurs.dart`. La couture est déjà nommée par le nom du fichier. |
| `widgets/inscription_form_kit.dart` | 683 | Séparer le **sélecteur en cascade** (`CycleLevelClassPicker`, `ClassPickerEntry`) des champs de saisie génériques → `widgets/cycle_level_class_picker.dart` + `widgets/inscription_fields.dart`. Le premier est déjà consommé hors catégorie (`structure/screens/academic_structure_screen.dart:9`), il mérite son fichier. |
| `screens/inscriptions_screen.dart` | 617 | Extraire `build` de la colonne haute (KPI → bandeau → import → rythme → drill-down) en `inscriptions_entete_parts.dart` ; le corps de l'écran retombe sous 300 l. |
| `screens/add_inscription_steps_3_5.dart` | 609 | Idem #1 : `..._step_scolarite.dart` / `..._step_pieces.dart` / `..._step_resume.dart`. |
| `screens/inscriptions_edit.dart` | 590 | Le modal d'édition porte 3 étapes (identité, tuteurs, scolarité) : une par fichier, comme l'assistant. |
| `screens/add_inscription_screen.dart` | 559 | Sortir la **soumission** (`_submit`, ~140 l. de reprise-après-échec, lignes 290-450) en `services/soumission_inscription.dart` — pur, donc testable, ce qu'il n'est pas aujourd'hui. |
| `screens/annuaire_parts.dart` | 542 | Table et cartes sont deux présentations indépendantes : `annuaire_table.dart` / `annuaire_cards.dart`. |
| `services/import_liste_eleves.dart` | 540 | **Ne pas découper** : fichier pur, 30 tests, cohésion forte (détection séparateur → décodage → mapping → validation). La règle des 500 vise la lisibilité, pas la dispersion d'un algorithme. |
| `screens/documents_parts.dart` | 525 | `documents_grid.dart` (vue par élève) / `documents_registry_table.dart` (vue registre) — les deux vues du `_byStudent`. |
| `screens/inscriptions_list_parts.dart` | 523 | `inscriptions_table.dart` / `inscriptions_cards.dart`. |
| `screens/inscriptions_actions.dart` | 516 | Sortir les **dialogues** (retrait avec motif, rejet, réouverture) en `inscriptions_dialogs.dart` ; garder les actions. |
| `screens/eleves_screen.dart` | 503 | Sortir les 4 actions groupées (`_bulkChangeClass`, `_bulkRevert`, `_bulkExport`, `_confirmeDebordement`) en `eleves_bulk_actions.dart` — même geste que celui déjà fait pour `eleves_actions_parts`. |
| `screens/eleves_actions_parts.dart` | 502 | Le dialogue de sortie avec motif (lignes 369-490) mérite `eleves_exit_dialog.dart` : c'est le point d'entrée de la nomenclature nationale. |

⚠️ **Règle du socle §7** : chaque découpe doit emporter la mise à jour de
`test/perimetre_scolarite_test.dart` (qui indexe des **chemins** de fichiers,
lignes 52-59) dans le même commit — sinon les sondes deviennent vertes et
aveugles.

Deux fichiers **flirtent** avec le seuil sans le franchir :
`vie_scolaire/screens/orientation_screen.dart` (403, alerte à 400) et
`students/screens/inscriptions_dossier.dart` (487).

### D.7 Désalignements catalogue ↔ code

1. **`orientation` : rangement, pas appartenance.** Le module est en catégorie
   `scolarite` en base (vérifié live, `display_order = 3`) et son code vit dans
   `features/vie_scolaire/` (`app_router.dart:75,666`).
   **Verdict : simple rangement, à laisser.** Le module lit `student_orientations`
   et `class_enrollments.promotion_decision`, partage le kit `vs_kit` avec
   Présences/Discipline/Infirmerie/Cantine, et sa donnée d'entrée vient du
   **conseil de classe** (`passage`). Métier : c'est bien de la scolarité (le
   parcours de l'élève) ; code : la cohésion technique est avec `vie_scolaire`.
   Le déplacer coûterait plus que ce qu'il rapporte. **À noter dans le catalogue**,
   pas à corriger dans le code.
2. **`cartes` : appartenance ET rangement à corriger.** Le code est dans
   `features/cartes/`, mais le **dessin** de la carte et son **modèle** sont dans
   `features/students/services/` (`carte_scolaire_pdf_service.dart`,
   `carte_scolaire_dessin.dart`, `carte_scolaire_modele.dart`, 614 l. au total,
   importés par `cartes_provider.dart:26` et `cartes_actions.dart:31`). Un module,
   deux dossiers, sans raison. Et c'est *exactement* la frontière où le verrou 4
   s'est perdu (D.1-#1). Proposition : rapatrier les trois services sous
   `features/cartes/services/`, et **étendre `test/perimetre_scolarite_test.dart`
   à `lib/features/cartes/providers`**.
3. **⛔ `00-CATALOGUE.md:115` range `features/cartes/` sous l'espace « Tutelle ».**
   C'est faux : `features/cartes/` ne contient aucune cartographie (§ B, module
   `cartes`). La carte nationale est
   `features/super_admin/screens/national_map_screen.dart` +
   `features/super_admin/providers/national_map_provider.dart` ; la carte régionale
   `features/admin_groupe/screens/regional/regional_map.dart`. **Le catalogue doit
   dire `features/tutelle/`, `features/super_admin/`, `features/admin_groupe/regional/`.**
   La collision est purement lexicale ; le mot « cartes » désigne ici les cartes
   d'identité scolaires des élèves.
4. **`ScopeDrilldownPanel` est un composant de plateforme rangé dans un module.**
   `features/students/widgets/scope_drilldown_panel.dart` (455 l.) est importé par
   **18 fichiers de 8 autres domaines** (`cartes`, `evaluation`, `examens`,
   `finance`, `staff`, `structure`, `vie_scolaire`, plus 4 fichiers de la
   catégorie). Sa place est `core/widgets/`.
5. **`00-INVENTAIRE.md` se trompe sur deux cibles de la catégorie.**
   Ligne 82 : `/user/eleves/:id` → l'inventaire dit `InscriptionsScreen` ; le
   routeur fait une **redirection** vers `/user/eleves`
   (`app_router.dart:557-560`, route morte volontairement conservée).
   Ligne 92 : `/user/m/:slug` → l'inventaire dit `TransfertsScreen` ; le routeur
   construit `ModuleComingSoonScreen` (`app_router.dart:585-591`). Le générateur a
   ramassé le `builder:` suivant. **Corollaire** : l'inventaire annonce « 1
   placeholder » ; il y en a **2 écrans de placeholder** (`espace-parent` et
   l'hôte générique `/user/m/:slug`) — même si, comme le dit le catalogue, aucun
   module actif n'y atterrit.
6. **Un slug recopié en dur** : `eleves_screen.dart:352`
   (`studentsRegistryProvider('eleves')`) contourne la constante `_kSlug` déclarée
   ligne 56 « une seule fois » précisément contre cela.
7. Le catalogue live donne `display_order = 3` à **`transferts` ET `orientation`**
   (vérifié en base). Sans effet fonctionnel (les routes sont dédiées), mais
   l'ordre de la barre latérale est alors décidé par un tri instable.

---

## E. Les cinq choses à faire en premier

1. **Poser le verrou 4 sur `cartes`** — module `cartes`.
   *Gain* : referme une fuite nominative **et de santé** (`blood_group`) sur le
   profil « Enseignant » livré par défaut en base, à trois semaines d'un
   déploiement national. C'est le seul point de la catégorie qui expose des
   données que l'école a explicitement choisi de restreindre.
   *Effort* : **S** — copier `classScopeClause(ref, 'cartes', column: 'c.id')` +
   `permissionsLoaded` depuis `students_registry_provider.dart:132-133`, ajouter
   `school_id` aux deux requêtes, garder `_EnTeteClasses` par `PermissionGate`
   (`export`), puis **étendre `test/perimetre_scolarite_test.dart` à
   `lib/features/cartes/providers`** pour que ça ne se reperde pas.
   *Fichier d'entrée* : `lib/features/cartes/providers/cartes_provider.dart:72`.

2. **Rendre au module Transferts le motif normalisé et le garde-fou d'identité** —
   module `transferts`.
   *Gain* : (a) les départs traités par la voie officielle réintègrent
   `v_sorties_par_motif`, c'est-à-dire la statistique de déperdition scolaire que
   le ministère publie ; (b) supprime un chemin d'écriture qui peut faire perdre
   **tout un lot PowerSync** (inscriptions et paiements de la matinée compris) sur
   un compte au `group_id` vide — cas mesuré à 20/67 en juillet.
   *Effort* : **S** — remplacer l'`UPDATE` inline par `setEnrollmentExit`,
   remplacer le champ « Motif (optionnel) » par `motifsPour(transfert: true)` avec
   bouton inactif tant qu'aucun motif n'est choisi, et remplacer
   `== null` par `isUsableId` + `writeIdentityMessage`.
   *Fichiers d'entrée* : `lib/features/students/providers/transfers_provider.dart:344`
   et `lib/features/students/screens/transferts_form.dart:45,171`.

3. **Réconcilier les compteurs d'effectif sur `students.is_active`** — modules
   `documents` (état de rentrée), `inscriptions`, `orientation`, `cartes`.
   *Gain* : le document qui part à la circonscription — et d'où sortent les
   dotations — cesse de sur-compter ; les deux courbes « effectif cumulé » de
   Inscriptions et d'Élèves disent enfin le même nombre ; la couverture
   d'orientation ne dépasse plus 100 % ; un élève désactivé cesse de recevoir une
   carte. Quatre corrections d'une ligne, un seul invariant.
   *Effort* : **XS** ×4 — `AND COALESCE(s.is_active, 1) <> 0`, plus une jointure
   `students` là où elle manque (`inscriptions_rythme_provider`).
   *Fichiers d'entrée* : `etat_rentree_provider.dart:193`,
   `inscriptions_rythme_provider.dart:93`, `inscriptions_data_provider.dart:217`,
   `orientation_provider.dart:93`, `cartes_provider.dart:87`.
   *À accompagner d'un test de source* sur le modèle de
   `test/offline_booleen_test.dart` : toute lecture d'effectif joignant
   `class_enrollments` à `students` doit porter le filtre.

4. **Mettre les documents en accord avec ce qui est à l'écran** — modules
   `documents`, `eleves`, `inscriptions`, `annuaire`, `transferts`.
   *Gain* : (a) le bouton PDF de la vue « Registre » cesse d'exporter les
   dossiers ; (b) les six PDF de la catégorie annoncent la **vue filtrée** au lieu
   de laisser un extrait passer pour un état complet — c'est la version
   documentaire du « zéro menteur », sur des papiers qui quittent l'école ;
   (c) le registre matricule répète ses en-têtes de colonne au-delà de la page 1.
   *Effort* : **S** — un paramètre `filtre` traversant les 6 `buildPdf` (le
   patron existe déjà : `core/services/fiche_detail_pdf.dart:204`), un
   `if (_byStudent)` sur l'`onExportPdf`, et le passage de
   `registre_matricule_pdf_service._table` à `OfficialPdfKit.tableSection`.
   *Fichiers d'entrée* : `lib/features/students/screens/documents_screen.dart:236`,
   `lib/features/students/services/students_pdf_service.dart:59`,
   `lib/features/students/services/registre_matricule_pdf_service.dart:168`.

5. **Ouvrir la délivrance depuis le module qui la raconte** — module `documents`
   (avec `eleves`).
   *Gain* : le certificat de radiation redevient réémissible (aujourd'hui il
   n'existe qu'à la seconde de la sortie — une famille qui revient repart les
   mains vides, alors que `peutDelivrerRadiation` accepte les statuts passés) ;
   le secrétariat cesse de sortir du module « Documents » pour faire le geste que
   ce module journalise ; et le registre des délivrances devient imprimable pour
   l'inspection.
   *Effort* : **S/M** — une action « Délivrer » dans le détail d'un dossier de
   `documents_screen` et dans le dossier d'inscription (où les statuts sortis sont
   déjà listés, `inscriptions_data_provider.dart:218`), plus un
   `showPdfPreviewDialog` sur `registre_screen`.
   *Fichiers d'entrée* : `lib/features/students/services/attestation_actions.dart:118`,
   `lib/features/students/screens/inscriptions_dossier.dart:108`,
   `lib/features/students/screens/registre_screen.dart:28`.
