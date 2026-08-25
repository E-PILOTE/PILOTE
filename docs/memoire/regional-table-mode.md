---
name: regional-table-mode
description: Vue régionale admin_groupe — ajout mode Tableau analytique (bascule Carte/Tableau) + opener fiche école réutilisable
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d4bb948-3b74-4035-ad23-3f3b70cbe1b4
---

✅ 2026-06-20 — Onglet « Vue régionale » du dashboard admin_groupe enrichi d'un **mode Tableau analytique** à côté de la carte (bascule `_ModeSwitch` Carte/Tableau dans `AdminRegionalView`, state `_regionalModeProv`).

**Périmètre tranché** : admin_groupe reste **scopé à son groupe** (RLS `auth_group_id()`) — PAS de vue plateforme entière (ça reste le rôle super_admin, qui a sa propre carte). Anti-redondance respectée : le tableau **lit/agrège**, il ne duplique PAS le registre CRUD « Mes Écoles » (`admin_schools_screen`).

**Fichiers neufs :**
- `providers/regional_table_provider.dart` : `RegionalTableRow` (SchoolDetail + hasGps + cycleCodes + completeness 0-100), `regionalTableRowsProvider` (compose `adminSchoolsProvider` + GPS de `adminRegionalProvider` + `_schoolCyclesProvider`), `RegionalTableQuery`/`regionalTableQueryProvider` (recherche/tri/filtres), `applyRegionalQuery`. Complétude = 11 critères de la création (code, address, city, department, phone, email, founded_year, director_id, logo_url, GPS, ≥1 cycle).
- `screens/regional_table_mode.dart` : `RegionalTableMode` — grille triable (École, Localisation, Cycles, Élèves, Personnel, É/Ens, GPS, Complétude, Statut), toolbar recherche + chips (type/Actives/Fiche incomplète) + synthèse % géolocalisées, clic ligne → fiche.
- `_schoolCyclesProvider` lit `school_cycles(school_id, cycle_id)` en 1 requête `inFilter`, mappe via `educationCatalogProvider.cycleById(...).code`.

**Réutilisation** : `admin_schools_screen.dart` expose désormais 3 fonctions publiques — `openSchoolDetailDialog(context, ref, SchoolDetail)` (ouvre `_SchoolDetailModal` 4 onglets), `schoolTypeLabel`, `schoolTypeColor`. Le clic sur une ligne du tableau ouvre la même fiche que « Mes Écoles » (zéro duplication).

**Pas encore fait (proposé, en attente)** : Tier 2 bandeau d'alertes actionnables dédié (sans-GPS/sans-directeur/sans-cycle), Tier 3 taux d'occupation (manque colonne `capacity` sur `schools` → migration) + ratio élèves/ens enrichi + timeline créations, Tier 4 pins carte colorés par occupation + clustering. Voir aussi [[admin-groupe-espace]], [[design-gouvernance-anti-redondance]].

analyze 0 issue ; hot reload OK sans erreur runtime (app testée en direct).

---

## ✅ 2026-06-20 (suite) — Refonte cockpit « Vue régionale » (carte) + formulaire orange poli

**Problème tranché** : la carte faisait DEUX métiers → doublon avec la page Écoles. Le `_DeptList` re-listait chaque école GPS individuellement (= registre déjà couvert par Écoles + Tableau). **Métier unique de la carte = territoire + pipeline de projets de création** (ni Écoles ni Dashboard ne le font).

**Colonne gauche réorganisée** dans `admin_regional_view.dart` (`_MapLayout`), `_DeptList` SUPPRIMÉ, remplacé par 2 widgets neufs in-file :
- **`_PipelinePanel`** (cœur du pilote) — watch `adminProjectsProvider`, projets groupés par statut `_kPipelineOrder` [etude,validation,budgetisation,construction,acheve], en-tête « PIPELINE D'EXPANSION » + badge actifs, bandeau `_PipelineStat` (budget cumulé `NumberFormat.decimalPattern('fr')` + nb achevés), clic projet → `SelectionProject`. Vide = invite bouton +.
- **`_CoveragePanel`** (équité, pas registre) — fusionne `data.depts` (non-GPS agrégés) + `data.gpsSchools` regroupés par dépt (`_DeptCoverage`), classé par total écoles desc, barre densité (orange + badge « sous-doté » si < 0.34), clic → `SelectionDept`. Total RÉEL par dépt (GPS+non-GPS).
- `_GlobalStats` (synthèse réseau) conservé en tête.

**Pont anti-doublon** : `_GpsSchoolDetailPanel` garde « Corriger la position » (action territoriale) + bouton navy **« Ouvrir la fiche complète »** → `openSchoolDetailDialog` (réutilise modale Écoles via `adminSchoolsProvider.valueOrNull.schools.firstOrNull` par id). La carte ne gère plus l'école, elle y renvoie. Imports : `admin_schools_provider.dart` + `admin_schools_screen.dart show openSchoolDetailDialog`.

**Formulaire orange poli** (`_ProjectFormDialog`) — garde dégradé + CTA orange, sections labellisées via `_ProjSection` (icône orange + libellé MAJ + filet) : Identification / Pilotage / Localisation / Impact attendu / Notes. Dropdown statut → **sélecteur pipeline visuel tappable** `_statusSelector()` (cercles+connecteurs+icônes, même langage que `_StatusPipeline`). Priorité → 3 chips `_PriorityChip`. Vérifié à l'écran : rendu pro, on-brand.

**Garde-fou villages CONFIRMÉ en prod (log live)** : `Localités live OSM (1424) < asset embarqué (1532) — live rejeté, asset conservé`. Idem dépts (12<15 rejeté). Cf. [[carte-donnees-geo]].

**Débordement Tableau corrigé** : en-tête + lignes partagent 1 seul scroll horizontal + même `tableW` (`_Header(tableW:)`).

⚙️ Dette : `admin_regional_view.dart` ~4500 lignes (panels in-file car `_selectionProv` privé ; extraction future = rendre la sélection publique).

⚠️ Piège GPU dev : redimensionner la fenêtre Linux sous `LIBGL_ALWAYS_SOFTWARE=1` crashe (`Timed out waiting for OpenGL frame` → `Lost connection`). NE PAS resize pendant un test ; lancer à la bonne taille. Le scroll molette `xdotool click 4` ne pénètre pas la ListView Flutter → agrandir la fenêtre au lancement. Cf. [[gui-testing-linux]].

analyze 0 issue ; aucune erreur runtime ; cockpit + formulaire testés en direct.

---

## ✅ 2026-06-20 (suite 2) — Tiers 2/3/4 + colonne `schools.capacity` (taux d'occupation)

Implémentation des 3 tiers restants + ajout d'une dimension occupation réelle.

**Migration prod APPLIQUÉE (autorisée par l'utilisateur)** : `database/migrations/0004_school_capacity.sql` — `alter table schools add column capacity integer check(>=0)`, nullable, additive, réversible. Vérifiée live (`capacity | integer | YES`).

**`capacity` câblé de bout en bout** :
- `admin_schools_provider.dart` : `SchoolDetail.capacity` + getter `occupancy` (= students/capacity, null si non renseigné) ; SELECT/mapping ; `create()` (`'capacity': ?capacity`) + `update()` (`'capacity': capacity`).
- `admin_schools_screen.dart` (`SchoolFormDialog`) : controller `_capacity`, champ « Capacité d'accueil (places) » à côté de Année de fondation (validator entier ≥0), Site web descendu sur sa propre ligne ; passé à create/update.

**Tier 2 — Bandeau d'alertes** (`regional_table_mode.dart` `_QualityAlerts`) : chips sans-GPS / sans-directeur / sans-cycle / fiche incomplète comptés sur les rows, chaque chip toggle `q.gap` (enum `RegionalGap` dans provider) ; état « Réseau complet » vert. Filtre `applyRegionalQuery` gère `gap`.

**Tier 3 — Occupation + charge** :
- `RegionalTableRow` : getters `studentsPerClass`/`loadLevel` (charge élèves/classe : <40 vert / 40-49 ambre / ≥50 rouge) ET `occupancyPct`/`occupancyLevel` (occupation : <70% ambre sous-occupé / 70-99% vert optimal / ≥100% rouge saturé / null inconnu).
- Tableau : colonne **É/CLASSE** (`_wLoad`, sort `RegionalSortKey.load`) + colonne **OCCUP.** (`_wOcc`, sort `RegionalSortKey.occupancy`), pastilles colorées. Helpers top-level `loadColor/loadLabel` + `occColor/occLabel`.
- `_CreationsTimeline` (histogramme créations par `foundedYear`) inséré dans `_RegionalAnalytics`.

**Tier 4 — Pins colorés + clustering carte** (`admin_regional_view.dart`) : enum `_PinColorMode {type, load, occupancy}` + `_pinColorModeProv` ; switch 3 boutons `_PinColorSwitch` (Type/Charge/Occup.) ; `_pinColor` + `_clusterWorstColor(group, levelById, scale)` générique (passe `loadColor` ou `occColor`) ; 2 maps `loadById`/`occById` construits depuis `regionalTableRowsProvider` ; clustering grille maison (z<9.5) inchangé ; `_MapLegend` adaptatif 3 modes. 

analyze 0 issue ; `flutter build linux --debug` ✓.

---

## 🗓️ 2026-08-03 — Partage vers la Vue Nationale : REPORTÉ APRÈS LA PRÉSENTATION

Décision du user. Généraliser `RegionalTableMode` (892 lignes) et son provider à
un second périmètre est un refactor à risque, sur un écran que la démonstration
ne traverse pas :

- le mode Tableau existe déjà côté **régional**, c'est-à-dire l'espace que le
  MINISTÈRE utilise — c'est celui qu'on montre ;
- ce qui manque est le tableau de la **Vue Nationale**, écran de l'**opérateur
  du SaaS** (super_admin), pas du ministère.

Reste à faire quand le sujet reviendra : périmètre partagé groupe/national,
groupe comme axe de regroupement (repli/dépli + totaux par groupe), colonnes
opérateur (abonnement, dernière activité), pagination côté serveur.

⚠️ Seul le rattachement départemental a été corrigé (la présence se lit sur les
ÉCOLES, plus sur le siège du groupe) — voir `activeGroupsTotal` dans
`national_map_provider.dart` : ne JAMAIS resommer `DeptMapEntry.activeGroups`.
