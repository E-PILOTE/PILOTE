---
name: inscription-page-et-structure-academique
description: Page Inscriptions refaite au design plateforme (KPI/table/cartes/export/modal) ; PROCHAIN GROS BUILD = structure académique cycle→niveau→filière→classe gérée par la direction
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

## ✅ Page Inscriptions — refonte design plateforme (2026-06-22, commit b70a13f)
`features/students/screens/inscriptions_screen.dart` (+ `inscriptions_list_parts.dart`, provider `inscriptions_data_provider.dart`). **Page UNIQUE, pas d'onglets** (exigence user), au standard admin_groupe (réutilise `admin_ui.dart` : AdminCard/AdminStatCard/AdminBadge/AdminFormDialog/adminFilledInput/AdminPrimaryButton/AdminDetailCard).
- KPI compacts responsive (2→6 col), Inscrits par cycle, graphe évolution (Syncfusion area), barre de filtres (recherche + dropdowns cycle/type + segment statut + bascule table/cartes + export CSV + bouton « Inscrire » DANS la barre, jamais le topbar), table triable + cartes, fiche détail modale, valider/rejeter (statut « En attente » = filtre).
- **Formulaire** (`add_inscription_*.dart`) : wizard 5 étapes CONSERVÉ mais habillé « Nouvelle école » (modal `Center>Container` w720 responsive dans un `Dialog` transparent ; header dégradé ; `_StepIndicator` clair ; champs `_Field/_DropdownField/_DateField` = label au-dessus + `adminFilledInput` ; `_NavBar` = `AdminPrimaryButton`). Champs Vague 1a (commit bdc6ca9) : région, nationalité, groupe sanguin, fratrie, aide sociale, adresse tuteur, motif transfert, notes, created_by.
- Export CSV : `exportInscriptionsCsv()` (BOM UTF-8, `;`, path_provider → Documents).

## ⚠️ DETTE ASSUMÉE : KPI « par cycle » = HEURISTIQUE par NOM de classe
`inscriptionCycleOf(className)` dans le provider parse « 6ème A »→Collège, « CP1 »→Primaire, etc. C'est un **« à peu près »** (le user l'a refusé). Raison : `classes.level_id` est NULL et `school_levels` vide → pas de vrai chemin classe→cycle.

## 🎯 PROCHAIN GROS BUILD — Structure académique (fondation Phase 1, gérée par la DIRECTION)
**Recherche faite (base live) :** le référentiel congolais est seedé : `education_cycles` (prescolaire/primaire/college/lycee/formation_pro), `education_levels` (cycle_id+program_id ; Collège 6e/5e/4e/3e, Primaire CP1→CM2, Lycée 2nde/1ere/Tle, FP par filière×années), `education_programs` (filières FP). Kinkala a `school_cycles` = primaire/college/lycee. MAIS : l'écran Classes ne lie aucun niveau (`createClass` a un param `levelId` jamais utilisé) ; `school_levels` (FK de `classes.level_id`) est VIDE et **n'a pas de cycle_id** ; aucun écran ne laisse la direction gérer niveaux/filières.

**Plan (réel, pas heuristique) :**
1. **Migration** : `school_levels` += `cycle_id uuid REFERENCES education_cycles`, `program_id uuid REFERENCES education_programs` (filière), garder `is_active`. (+ indexes FK).
2. **Sync offline** : ajouter `school_levels`, `school_cycles`, `education_cycles`, `education_levels`, `education_programs` au `powersync_schema.dart` + sync-rules (référentiel global `group_id IS NULL` + per-school). ⚠️ redéploiement sync-rules (PAT).
3. **Écran « Structure académique » (direction, `/user/structure` ou dans Classes)** : cycles hérités (lecture, depuis school_cycles) → la direction ADOPTE les niveaux du référentiel (insert dans school_levels avec cycle_id + filière) + niveaux/filières perso → crée les **classes sous un niveau**.
4. **Classes** : `classes_screen` → picker de niveau OBLIGATOIRE (school_levels de l'école, groupés par cycle) → `classe.level_id` réel.
5. **Inscription + KPI** : remplacer `inscriptionCycleOf(nom)` par le vrai JOIN `classe→school_levels→education_cycles`. Le picker de classe à l'inscription se groupe par cycle/niveau.

**Exigences user (verbatim) :** « ne me mens jamais et ne me fais pas des à peu près » ; « c'est toi qui décide, je te fais confiance » ; design = celui de « Nouvelle école » ; tout responsive. Voir [[admin-groupe-espace]] (système éducatif), [[regle-taille-fichier-500]].

---

## ✅ AVANCEMENT 2026-06-22 (commits 454fec7, d949d72)
- **Dossier élève uploadé** (454fec7) : bucket privé `student-documents` (migration 0008) + RLS storage école ; upload réel FilePicker→Storage, ligne `student_documents` offline au submit ; studentId généré en amont (createStudent accepte `id`) ; dossier suit l'élève (réinscription = pièces conservées) ; provider `student_documents_provider`. 6 pièces (retiré nationalité/résidence).
- **Fondation structure FAITE** (d949d72) : migration 0009 `school_levels`+=`cycle_id`/`program_id` ; backfill = catalogue niveaux **PAR GROUPE** (⚠️ `school_levels` unique sur **(group_id, slug)** → catalogue GROUPE, school_id souvent NULL, PAS par école) depuis référentiel selon school_cycles (16 niveaux groupe Kinkala) ; 32 classes reliées par nom (bootstrap unique). Migration 0010 `classes`+=`cycle_code` (dénormalisé classe→niveau→cycle) → **KPI cycle RÉELS offline** (classes synchro SELECT*, AUCUN redéploiement) ; `inscriptionCycleFromCode(cycle_code)` dans le provider, heuristique nom = repli seulement. powersync_schema `classes`+=`cycle_code`.

## ✅ KPI multi-sections dynamiques (2026-06-22, commit d8dc7b0)
5 groupes KPI distincts & responsives sur la page Inscriptions, **tous dynamiques** (aucun en dur) :
- **Général** = `AdminStatCard` PLEINE TAILLE (exigence user « même taille que le Tableau de bord admin_groupe »), grille `mainAxisExtent 168`, cols 1→6 selon largeur.
- **Par cycle** (hérité école), **par niveau** (6e/5e… coloré par cycle via `LevelCount.cycleCode`), **par classe** (`ClassCount` : effectif + taux de remplissage `total/capacity` barre rouge si dépassé), **par filière** (`ProgramCount`, lycée/FP, accent doré — **masquée si vide**, jamais heuristique).
- Migration **0011** `classes` += `level_code`/`level_order` ; **0012** += `filiere_code`/`filiere_label` (dénormalisé classe→school_levels.program_id→education_programs ; NULL partout aujourd'hui car aucune filière adoptée → section filière s'allumera quand la direction créera des filières). powersync_schema `classes` += filiere_code/label. Sync offline via `classes` (SELECT *, **aucun redéploiement**).
- Provider `inscriptions_data_provider` : `byClass`/`byProgram` + `levelCycle`/`classCycle` maps ; query SELECT += c.id/capacity/filiere_label. Vérifié live Kinkala (collège) : 6e/5e/4e/3e=15, classes 15/45 places, filière masquée.

## ✅ REFONTE page + structure dérivée des classes (2026-06-22, commits 9ed7047→e460e27)
**Constat à l'écran** (capture) : 4 grilles KPI identiques (cycle/niveau/classe/filière) = distinction illisible ; « par cycle » vs « par classe » indistinguables ; un seul cycle (Collège) affiché alors que l'école a 3 cycles configurés.
**Décisions** :
- **Répartition unifiée** : 1 SEULE carte « Répartition des effectifs » + **toggle de dimension** `[Cycle · Niveau · Classe · Filière]` (compteur par dim + ligne d'aide expliquant Cycle ⊃ Niveau ⊃ Classe). `_BreakdownCard`/`_DimToggle`. Fini l'empilement redondant.
- **Structure dérivée 100% offline de `classes`** (déjà synchro, `SELECT *`) — PAS de school_cycles/school_levels, donc **AUCUN déploiement sync-rules requis**. `schoolStructureProvider` lit `classes` (cycle_code/level_code/filiere_label/capacity) → cycles/niveaux/classes/filières apparaissent dès qu'une **classe existe**. Logique : on n'inscrit QUE dans une classe → la structure pertinente = les classes. La direction crée une classe en 2nde → Lycée+2nde+classe apparaissent seuls. Inclut classes vides (0 inscrit).
- **Hero KPI** : « Redoublants » → **« Taux de remplissage »** (inscrits/capacité totale, `InscriptionStats.capacityTotal/fillRatio`).
- **Skeleton shimmer** (`_InscriptionsSkeleton`) remplace le `CircularProgressIndicator`.
- ⚠️ **school_cycles/school_levels/education_cycles** : ajoutés à powersync_schema + sync-rules + migration 0013 (school_cycles.id) **commités mais NON déployés** ; le provider ne les utilise PAS (dérivation via classes). Réutilisables plus tard pour un nudge « cycle configuré sans classe » (nécessiterait alors le déploiement). 0012 (filiere) + 0013 appliquées en base.
- **Données test** : Kinkala avait des **classes DOUBLONS** par niveau — `6e A` (cap60, 8 inscrits en 2024-2025) ET `6ème A` (cap45, 15 inscrits 2025-2026). Résolu en **scopant la structure à l'année active** (cf. ci-dessous), donc `6e A` (autre année) n'apparaît plus.

## ✅ Classes Primaire/Lycée créées + scoping année + tri multi-cycles (2026-06-22, commit 11adac2)
- **12 classes créées en base** (année courante a1=2025-2026, école Kinkala `d100…007`) : Primaire CP1 A→CM2 A (6, cap45), Lycée 2nde A + 1ère A/C + Tle A/C/D (6, cap50, `filiere_label` Série A/C/D + `filiere_code` serie_a/c/d). INSERT direct (cycle_code/level_code/level_order/level_id/filiere_* posés à la main — PAS de trigger, les migrations 0010/0011 étaient des backfills one-time). Kinkala année courante = 16 classes / 3 cycles. → page affiche **Cycle 3 · Niveau 13 · Classe 16 · Filière 3** (toggle filière apparaît).
- **schoolStructureProvider scopé `academic_year_id`=année active** (en plus de school_id) : supprime les classes d'autres années (doublons). Dynamique au changement d'**école/groupe** (schoolId via authNotifier) ET d'**année** (activeYearIdProvider) — rien de codé en dur.
- **Tri GLOBAL niveaux/classes** par `(cycleOrderOf(cycleCode), ordre dans cycle, nom)` : sans ça CP1/6ᵉ/2ⁿᵈᵉ (tous ordre 1 dans leur cycle) s'entremêlaient. Helper `cycleOrderOf()`.
- ⚠️ GUI : clics xdotool sur petites cibles (chips toggle) **non fiables** ; mécanisme prouvé (clic « Classe » a marché une fois) + compteurs corrects = vérification par la donnée. Lycée 1ère/Tle = séries (filières) posées en dur sur la classe ; la vraie gestion filières via structure académique (school_levels.program_id) reste à faire.

## ✅ Vue Classe groupée par niveau + filtre filière + catalogue séries (2026-06-22, commit 4cd3768)
- **Vue « Classe » GROUPÉE PAR NIVEAU** (`_ClassSection` + `_ClassGroup` + `_LevelGroupHeader`) : en-tête niveau (pill colorée « Niveau 6e ») + « N classe · M inscrit · X/Y places » puis les classes du niveau (couleur partagée par niveau). Lève la confusion niveau/classe (Niveau ⊃ Classes). `ClassCount`/`SchoolClassDef` portent `levelCode` ; map `classLevel` dans stats.
- **Filtre FILIÈRE** dans la barre (`_filiere` + dropdown conditionnel) : visible dès que l'école offre des filières (`filieresPresent` = `st.byProgram` → même à 0 inscrit, utile technique/pro). Barre de filtres passée en **Wrap responsive**.
- **Référentiel filières enrichi** (`education_programs`, global group_id NULL) : **+13 séries lycée** sur cycle `lycee` (id `82c6d72e…`) — général **A/C/D**, technique industriel **E/F1/F2/F3/F4/F6/F7**, tertiaire **G1/G2/G3**. Total **34 filières** (21 fp_* sur formation_pro + 13 serie_* sur lycee). Codes : serie_a…serie_g3. À RÉUTILISER dans l'écran Structure académique (la direction adopte une filière du référentiel OU en crée une perso group_id). Les filières user-créées (group_id renseigné) restent supportées par le modèle.
- Kinkala lycée : classes 1ère/Tle portent filiere_label « Série A/C/D » (filiere_code serie_a/c/d) → alignées sur le référentiel.

## ✅ Tiroir Classe/Filière + hiérarchie Niveau→Classe (2026-06-22, commits 70074a2, ca53a60)
- **Classe/Filière en TIROIR latéral droit** (`_BreakdownDrawer` ConsumerStatefulWidget, `showGeneralDialog` + SlideTransition) : protège la hauteur de la page quand l'école est technique (bcp de classes/filières). Carte principale = résumé compact ; détail (grille groupée par niveau + **recherche**) dans le tiroir. En-tête tiroir = style plateforme LÉGER (blanc + accent navy + `AdminModalIconBtn`), PAS le bandeau navy plein. Largeur tiroir = `(screenW*0.5).clamp(420,920)`.
- **FIN de la confusion Niveau vs Classe** (l'utilisateur avait raison : 1 classe/niveau → chiffres identiques) : **Classe n'est plus une dimension sœur**, c'est le **drill-down d'un Niveau**. Sélecteur = `[Cycle · Niveau · Filière]` (classe retirée). Chaque carte de niveau affiche son **nb de classes** + est CLIQUABLE (chevron) → tiroir des **sections** de ce niveau (`levelCode` filter, titre « Classes du niveau X »). Lien « Voir toutes les classes (N) ». Vérifié live : 1ere → tiroir « Niveau 1ere · 2 classes » = 1ère A + 1ère C. Hiérarchie Cycle⊃Niveau⊃Classe enfin lisible. Vue par défaut = **Niveau** (la plus riche).

## ⚠️ HONNÊTETÉ — la page Inscription n'est PAS 100% complète (audit 2026-06-22)
Solide : KPI, répartition (cycle/niveau/classe drill-down/filière), évolution, filtres (recherche+cycle+filière+type+statut), table+cartes, export CSV, ajout (wizard 5 étapes + documents bucket privé), valider/rejeter, fiche détail (avec section Dossier), skeleton, offline-first dynamique école/groupe/année. RESTE pour « parfait/complet » :
1. **Réinscription RÉELLE** : le formulaire crée TOUJOURS un nouvel élève ; « reinscription » n'est qu'un libellé de type. Pas de sélecteur d'élève existant ni de réutilisation du dossier. (gap principal)
2. **Garde-fou capacité de classe** (alerte si classe pleine) + **anti-doublon** (élève déjà inscrit cette année). `checkStudentQuota` = quota PLAN/abonnement, PAS la capacité classe.
3. **Pagination/virtualisation** du tableau pour gros effectifs (échelle nationale).
4. **Sorties PDF** (liste imprimable, attestation d'inscription) — CSV seulement aujourd'hui.

## ⏭️ RESTE (management direction) — dépend d'un DÉPLOIEMENT sync-rules
1. **Classes** (`classes_screen.dart`) : picker de NIVEAU obligatoire (school_levels du groupe groupés par cycle) → set `level_id` + `cycle_code`. `createClass` a déjà le param `levelId`.
2. **Écran « Structure académique »** (direction) : adopter niveaux référentiel + gérer FILIÈRES (lycée/FP via education_programs + school_levels.program_id) + créer classes sous niveau.
⚠️ **Dépendance** : synchroniser `school_levels` (+ éventuellement education_cycles/levels/programs pour l'adoption) offline → `powersync_schema` + **sync-rules + DÉPLOIEMENT (PAT `~/.epilote/powersync.pat`)**. C'est la prochaine étape « dans le bon ordre ».
