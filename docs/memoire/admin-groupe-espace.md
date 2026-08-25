---
name: admin-groupe-espace
description: Espace admin_groupe complet (10 écrans + sidebar dynamique) livré le 2026-06-01 — état et décisions non évidentes
metadata: 
  node_type: memory
  type: project
  originSessionId: b9adb2ad-c65e-49c2-96b0-08a58aee1dd5
---

Espace **admin_groupe** entièrement implémenté le 2026-06-01 (`lib/features/admin_groupe/`), même style que super_admin, toutes les routes `/admin/*` câblées dans `app_router.dart` (plus aucun placeholder). Vérifié : `flutter analyze` 0 erreur + `flutter build linux --debug` OK.

**10 écrans** : dashboard, mes écoles (CRUD modal), utilisateurs (CRUD modal), profils d'accès, rapports, abonnement, journal d'audit, paramètres, mon profil, vue module (`/admin/modules/:slug`).

**Why:** demande utilisateur « crée tout … complet et parfait ». L'admin_groupe est un promoteur/ministère multi-écoles qui pilote son groupe en ligne (KPIs temps réel).

**How to apply:** pour toute évolution de cet espace, suivre ces décisions non évidentes (sinon RLS casse ou incohérence) :
- **Supabase direct** (`supabase.from()`), JAMAIS PowerSync — c'est du personnel scolaire qui est offline-first. Voir [[role-admin-groupe]].
- Scope **strictement `group_id`** ; jamais de données hors groupe.
- **Sidebar dynamique** = `adminNavModulesProvider` : lit `school_groups.plan_id` → `plan_modules` → catégories/modules accessibles. Icônes modules = **emojis** rendus en `Text` (pas `IconData`).
- **Paramètres en lecture seule** : `school_groups` n'est modifiable que par super_admin (RLS) → l'écran propose « Demander une modification » qui insère un `support_tickets` (`category='modification_groupe'`). Idem changement de plan (`category='changement_plan'`).
- **Mon profil éditable** : `profiles` autorise `id=auth.uid()` → édition directe + `auth.updateUser` pour le mot de passe.
- AppShell rôle-aware : badges notif/msg masqués hors super_admin (évite des fetch super-scopés qui échouent en RLS).
- **Dashboard premium redesigné (2026-06-01)** : `screens/admin_dashboard_screen.dart` est un tableau de bord à 2 onglets — « Vue d'ensemble » + « Vue régionale » (rendu paresseux : la carte ne charge qu'à l'ouverture de l'onglet). Réutilise les *patterns* super_admin (KPI animés à sparklines Syncfusion, carte OSM par département via flutter_map, centre de gouvernance) SANS toucher au code super_admin (évite des régressions sur l'espace fini). Fichiers : `providers/admin_dashboard_provider.dart` enrichi (enrollmentTrend/revenueTrend/schoolsByDept/studentsByDept/genre/personnel + getters coveredDepts/enrollmentGrowth/tauxOccupationEleves), nouveau `providers/admin_regional_provider.dart`, nouveau `screens/admin_regional_view.dart`. Centroïdes des 12 départements dupliqués (réf. stable — `schools` n'a pas de lat/lng). **Stratégie données** : afficher les vraies données (écoles/élèves/départements/genre/tendance d'inscription via `created_at`) et empty-state proprement les KPI opérationnels (assiduité, réussite, revenus, enseignants) car la base live n'a partout que des écoles + élèves. Vérifié : `flutter analyze` 0 issue + `flutter build linux --debug` OK.
- **Refonte « centre de commandement » (2026-06-01, 2ᵉ passe)** — audit + redesign production. Vérifié : `flutter analyze` 0 issue sur les 4 fichiers touchés + `flutter build linux --debug` OK.
  - **BUG D'AFFICHAGE corrigé (le « contenu disparaît sur grand écran »)** : un `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` placé dans un `ListView` (hauteur verticale non bornée) → contrainte de hauteur infinie → le contenu s'effondre/disparaît dès que la fenêtre dépasse ~840 px. **Fix canonique = envelopper le Row dans `IntrinsicHeight`** (`_ChartsRow.build`). Ne jamais remettre `stretch` dans un Row sous ListView sans `IntrinsicHeight`.
  - **⚠️ PAS de `ConstrainedBox(maxWidth:1520)` sur le dashboard** (2026-06-02, bogue corrigé) : ce wrapper limitait le contenu à 1520 px sur 27 pouces → supprimé ; `_Overview.build` retourne directement un `ListView`. KPI section : `cols = w >= 1920 ? 8 : (w >= 1280 ? 4 : ...)` pour remplir la ligne sur grands écrans.
  - **Section RH · Phase 3 (`_RhSection`)** : nomenclature métier validée → **« Fonctionnaires de l'État »** = `staff_members.contract_type='permanent'` (titulaires) vs **« Personnel non fonctionnaire »** = contractuel/vacataire/stagiaire. Provider enrichi : `fonctionnaires`/`nonFonctionnaires`/`staffByContract`/`staffByDept`/`hireTrend` + getters `tauxFonctionnaires`/`personnelAdministratif`. Empty-state propre si `personnelTotal==0`.
  - **Centre de décision (`_RiskCenter` « Établissements à surveiller »)** : score de risque PAR établissement calculé depuis `SchoolSummary` (inactif=5 / 0 élève=4 / 0 personnel=4 / 0 classe=3 / surcharge >50 élèves-classe=2 / encadrement >35 élèves-agent=2) → niveaux critique≥6 / élevé≥3 / modéré. **Complémentaire** (ne pas dupliquer) de `_buildAlerts` (alertes niveau groupe) et `_TopSchools` (les meilleurs).
  - **⚠️ `CameraConstraint.contain` ET `containCenter` INTERDITS sur flutter_map 7.x** (2026-06-02, crash grave reconfirmé) : `contain` → viewport > bounds → `constrain()` retourne null → assertion crash. `containCenter` → `constrain(camera)` crée toujours un NOUVEL objet `MapCamera` via `withPosition()` ; avec `initialCameraFit` + providers async, une rebuild déclenche `options=` avant que la caméra soit dans les bounds → assertion `constrain(camera)==camera` échoue. **FIX DÉFINITIF = `const CameraConstraint.unconstrained()`** → `constrain(c)=c` (même référence → `==` trivial). Le focus Congo est garanti par `initialCameraFit: CameraFit.bounds(congoBounds, padding:28)` + `minZoom: 5.8`.
  - **`initialCameraFit: CameraFit.bounds(bounds:..., padding:...)`** : bonne pratique pour afficher uniquement le Congo au démarrage, quelle que soit la taille d'écran. Remplace `initialCenter`+`initialZoom` statiques. À combiner avec `CameraConstraint.unconstrained()` (jamais avec contain/containCenter).
  - **Architecture données géo (2026-06-02) — RÈGLE ABSOLUE : données live, pas de hardcoding** :
    - Provider `admin_geo_provider.dart` : `congoBoundaryProvider` (ADM0 via geoBoundaries.org API → simplifiedGeometryGeoJSON) + `congoDepartmentsProvider` (ADM1 Overpass, filtre `relation(192794);map_to_area->.cg` + `ISO3166-2 starts CG-`) + `congoPlacesProvider` (Overpass, même filtre area). Repli automatique sur `assets/geo/` si réseau indisponible.
    - **⚠️ Overpass EXIGE `User-Agent` header** (ex: `'E-PILOTE-Congo/1.0 (libemessenger@gmail.com)'`) — sans lui → 406 Not Acceptable, silence total. Toujours inclure.
    - **⚠️ bbox Congo (-5.2,11.0,3.8,18.8) inclut 6 pays voisins** → JAMAIS filtrer par bbox seul. Toujours utiliser `relation(192794);map_to_area->.cg` + double check ISO3166-2=CG-*.
    - **Satellite Esri WorldImagery** (aucune clé API) : URL `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` (**ordre y/x**, pas x/y). Overlay hybride : `Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}`.
    - **Masque géographique** : `Polygon(points: worldRect, holePointsList: [congoRing])` — worldRect = `[(-85,-180),(-85,180),(85,180),(85,-180)]`. Couleur du masque adapte au fond (clair sur OSM, sombre sur satellite).
    - **Étiquettes depts** : `MarkerLayer` aux centroïdes (`GeoDepartment.centroid` calculé par shoelace formula depuis le polygone OSM réel).
    - **Villes (city/town) actives par défaut** (`_showCitiesLayerProv` default true) ; villages (`_showVillagesLayerProv`) désactivés par défaut. 9 villes portent une étiquette, 78 bourgs = cercle seul.
    - Assets `assets/geo/congo_adm0.json` / `congo_adm1.json` / `congo_places.json` = snapshot OSM 2026-06, repli seulement.
  - **Carte régionale enrichie** : (1) **bug corrigé** — `AdminSchoolPin.students` était codé en dur à `0` ; `admin_regional_provider` calcule désormais l'effectif réel par école (`studentsBySchool`). (2) Marqueurs = **bulles proportionnelles** (√ effectif, 30→60 px) avec légende. (3) **Filtres** type (public/privé/mixte) + « actives » → recompute client-side via `_applyFilter` (le département sélectionné est re-résolu sur la vue filtrée pour éviter des comptes périmés). (4) `_TypeMix` (répartition par type) + détail par école avec effectif réel. **Overflow corrigé (2026-06-02)** : `Marker.height = dia + (isSelected ? 52 : 40)` (marge 20 px min, évite le BOTTOM OVERFLOWED sur 27 pouces) ; `width = isSelected ? 200 : (dia+60).clamp(0,200)`.
- **Plan du groupe de test vianney : Premium → Institutionnel** (raison : le seed démo crée 8 écoles, or `fn_enforce_school_quota` bloque à max 5 sur Premium ; Institutionnel est un **superset** de modules → la sidebar reste pleine, aucune régression).
- **Données démo seedées (groupe vianney UNIQUEMENT, group_id=`da3954ca-e2a4-486e-ac07-a2ebf992f2c6`)** : 8 écoles (7 actives + #8 inactive, ids `d1000000-0000-4000-8000-00000000000X`, X=1..8), 28 classes, 294 élèves+inscriptions, 84 staff (50 fonctionnaires / 34 non / 47 enseignants), 85 profils, ~1075 paiements (205 en juin, ~7,7 M XAF). `academic_year` `da000000-…-a1`. **Réversibilité** : supprimer les lignes où `group_id='da3954ca-…'` puis les comptes `auth.users` `id LIKE 'e0000000-%'` (FK `staff_members.id→profiles.id→auth.users.id` ; trigger `fn_handle_new_user` recrée les profiles). Comptes seedés = **sans mot de passe / non confirmés** (aucun login possible → pas de risque sécurité), strictement scoping groupe.

- **Mes Écoles redesigné (2026-06-02)** : `screens/admin_schools_screen.dart` réécrit au standard super_admin — shimmer skeleton, 6 KPI cards animées (hover FadeTransition+SlideTransition, bande accent 3 px, barre de progression), filter bar stylisée (Container blanc/bordure, search+toggle+reset+add gradient navy), `_ResultHeader`, dual view table/cartes. Colonnes table : NOM·TYPE·DÉPARTEMENT·ÉLÈVES·PERSONNEL·CLASSES·STATUT·ACTIONS. `SchoolFormDialog` conservé identique. `flutter analyze` 0 issue.
- **Utilisateurs redesigné (2026-06-02)** : `screens/admin_users_screen.dart` même pattern — 4 KPIs, filter bar, toggle table/cartes, table avec hover rows, `_RoleBadge` coloré par rôle, `_SmallBadge` école/profil. `UserFormDialog` + `ResetPasswordDialog` conservés identiques. `flutter analyze` 0 issue.
- **Parité disposition stricte super_admin ↔ admin_groupe (2026-06-03)** — **RÈGLE pour tout écran admin_groupe** : la *disposition* doit être le miroir 1:1 de son jumeau super_admin (Mes Écoles↔Groupe Scolaire `school_groups_screen.dart`, Utilisateurs↔Administrateurs `administrators_screen.dart`) ; **seul le contenu des données change**. **Why:** demandé/corrigé 2× par l'utilisateur (« doit etre pareil juste le contenu des données qui est different », « le meme design »). **How to apply:** PAS de `_PageHeader` en corps de page (le titre vient de l'AppShell) ; le bouton « Nouveau… » vit dans la **ligne 1 de la filter bar** (gradient navy `[0xFF1A2F5A,0xFF1E3A5F]`, grisé `kTextMuted` si quota atteint) ; ordre du corps = `_KpiGrid` → `_FilterBar(onAdd)` → `_ResultHeader` → table/cartes. Le shimmer doit suivre (KPI grid en 1er, pas de bloc header). **KPI overflow** : si 4 colonnes, utiliser `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 116)` au lieu de `childAspectRatio` (sinon cartes trop courtes → RenderFlex overflow) ; 3 colonnes/aspect 2.6 ne déborde pas. Vérifié `flutter analyze` 0 issue + build linux + app lancée.

- **Finalisation 4 chantiers (2026-06-03)** — demande utilisateur (« KPI Utilisateurs trop petits ; la création d'école doit s'afficher sur la carte Vue régionale ; implémente en totalité Rapports + Abonnement »). Vérifié : `flutter analyze` 0 erreur (8 infos pré-existantes, mon code neuf 0 lint) + `flutter build linux --debug` ✓.
  - **Grille KPI canonique = `cols = maxWidth > 800 ? 3 : 2` + `childAspectRatio: 2.6`** (PAS `mainAxisExtent:116`, PAS 4 colonnes — corrige la note plus haut). La page **Utilisateurs** passe de 4 cartes courtes à **6 cartes** (Total/Enseignants/Administration/Actifs/Connectés 7j/Inactifs) au même gabarit que son jumeau Administrateurs. Getters ajoutés à `AdminUsersData` : `inactifs`, `enseignants`, `administration` (= total − enseignants). Shimmer aligné (3 col, 6 items).
  - **École créée → carte Vue régionale (impératif)** : `AdminSchoolsService` n'invalidait que `adminSchoolsProvider` → la carte ne se rafraîchissait jamais. Fix = helper **`_refreshAll()`** (invalide `adminSchoolsProvider` + `adminRegionalProvider` + `adminDashboardProvider`) appelé dans create/update/setActive. En plus, `adminRegionalProvider` a reçu un **canal Realtime** (`schools`+`students`, filtre `group_id`, debounce 2 s → `invalidateSelf`) pour la robustesse multi-session. Une école sans GPS ni département tombe dans la bulle « Non précisé » (jamais perdue).
  - **Rapports — export PDF réel** : nouveau `services/reports_pdf_service.dart` (style document officiel calqué sur `regional_pdf_service.dart` : bandeau tricolore, emblème `assets/icons/logo.svg` rasterisé, en-tête RÉPUBLIQUE DU CONGO, footer paginé). `ReportsPdfService.printReport({data, periodLabel})` via `Printing.layoutPdf` (+ `downloadReport` FilePicker). `admin_reports_screen.dart` : `_ActionBar` devient `ConsumerStatefulWidget` (busy + try/catch snackbar), le placeholder « disponible prochainement » est remplacé. Sections PDF : synthèse 6 KPI, structure, finance, RH, table établissements. Grilles KPI réalignées à 2.6.
  - **Abonnement — section Facturation (lecture seule)** : RLS `invoices_select = is_super_admin() OR group_id=auth_group_id()` (vérifiée live) → l'admin_groupe **lit** ses factures, mais UPDATE/INSERT sont super_admin only ⇒ **jamais** de bouton « marquer payé » côté admin_groupe. `admin_subscription_provider` : `AdminSubscriptionData.invoices` (List<InvoiceDetail>) + getters `billedTotal/paidTotal/outstandingTotal/overdueCount`, fetch `group_invoices` filtré `group_id` (join `school_groups`+`subscription_plans`), `group_invoices` ajouté au canal Realtime. `admin_subscription_screen` : section « Facturation » (synthèse 3 tuiles + liste `_InvoiceRow`). **Réutilisation, zéro duplication** : modèles `InvoiceDetail`/`ReceiptModel` + services `InvoicePdfService`/`ReceiptPdfService` importés depuis `super_admin/` (utilitaires purs/stateless, pas de couplage data-layer). N° de reçu reconstruit `INV-→REC-` quand `storedReceiptNumber` absent (`InvoiceDetail.fromMap` ne lit pas `receipt_number`) — donne le même n° que la base.

**Vérification finale (2026-06-02)** : `flutter analyze` 0 issue sur les 4 fichiers admin_groupe touchés + `flutter build linux --debug` ✓.

---

### Passe UI/UX 4 pages (2026-06-04)

4 corrections demandées par l'utilisateur après la livraison du système éducatif.

#### Journal d'audit — KPI overflow corrigé
`GridView.count(childAspectRatio: 2.6)` → `LayoutBuilder + Wrap + SizedBox(w)` dans `_KpiGrid` et `_KpiSkeleton`. Le ratio fixe forçait une hauteur insuffisante quand le subtitle était long → texte clippé. La grille `Wrap` s'adapte maintenant à la hauteur naturelle de chaque `AdminStatCard`.

#### Abonnement — contenu disparaît sur grand écran (fix) + redesign KPI
- **Cause** : `_Body.build()` retournait un `ListView` simple. Sur grand écran, le `ListView` pouvait recevoir `maxWidth = ∞` de son parent, transmis aux enfants `LayoutBuilder` → `(∞ - gap*(n-1)) / n = ∞` → `SizedBox(width: ∞)` → contenu invisible.
- **Fix** : même pattern que Mes Écoles / Utilisateurs : `LayoutBuilder(constraints.maxWidth.isFinite ? w : MediaQuery.width - 80)` + `SingleChildScrollView(SizedBox(width: w, child: Padding(Column(...))))`.
- **KPI redesign** : `_QuotaItem` redesigné pour matcher exactement `AdminStatCard` — icône dans container 44×44 (radius 11), valeur `24px w800`, label `12.5px kTextMuted`, ligne quota `11px grey.shade400`, barre de progression. Couleur passe au rouge si quota ≥ 90 %.

#### Paramètres — layout pleine largeur + section "Mes demandes"
- **Layout** : `_TabScaffold` remplace `ListView(Center(ConstrainedBox(maxWidth:720)))` par `LayoutBuilder + SingleChildScrollView + SizedBox(w) + Padding(Column(children))` → le contenu occupe toute la largeur comme les autres pages.
- **Fonctionnalité manquante — Mes demandes au support** : nouveau widget `_SupportHistoryCard` dans le tab Général. Lit `adminSupportTicketsProvider` (nouveau, `support_tickets` WHERE `group_id=auth_group_id()`, tri `created_at DESC`, limit 20). Affiche la liste des demandes avec statut coloré + réponse de la plateforme si disponible + bouton "Nouvelle demande" (→ `_RequestUpdateDialog` existante). Provider `SupportTicketItem` + `adminSupportTicketsProvider` ajoutés dans `admin_settings_provider.dart`.

#### Mes Écoles — modal détail enrichi (4 onglets)
- `_SchoolDetailModal` passe de 2 à 4 onglets : **Informations** · **Cycles** · **Utilisateurs** · **Statistiques**.
- **Onglet Cycles** (`_SchoolCyclesTab`) : lit `educationCatalogProvider` + `schoolEducationProvider(schoolId)`. Affiche pour chaque cycle assigné : section colorée avec en-tête (icône/couleur selon code cycle), puis filières sélectionnées avec leurs niveaux en chips, ou niveaux généraux en chips. Si rien d'assigné → AdminEmptyState.
- **Onglet Utilisateurs** (`_SchoolUsersTab`) : nouveau `schoolUsersProvider(schoolId)` (FutureProvider.family) dans `admin_schools_provider.dart`. Requête `profiles.school_id=schoolId` + join `access_profiles(name)`. Affiche liste avec avatar coloré par rôle, nom complet, badge rôle (`roleLabel` importé depuis `admin_users_provider.dart`) + badge profil d'accès (si lié), badge actif/inactif.
- **Modèle `SchoolUser`** : `id, fullName, role, isActive, accessProfileName?` — ajouté à `admin_schools_provider.dart`.
- `flutter analyze` 0 issue + `flutter build linux --debug` ✓ + plateforme relancée.

**Test :** `vianney@epilote.cg` / `‹secret — gestionnaire de mots de passe›` (plan **Institutionnel** depuis le seed — superset de modules, sidebar bien remplie ; données démo réelles → KPI/carte/RH/risques peuplés). Lancer : `cd /home/melack/E-PILOTE/epilote && flutter run -d linux`.

---

### Profils d'accès — refonte complète (2026-06-03)

**Migration DB appliquée (`extend_profile_permissions_nine_actions`)** :
- `profile_permissions` : 9 actions explicites — `can_read, can_create, can_update, can_delete, can_export, can_import, can_validate, can_approve, can_manage` (toutes BOOL NOT NULL DEFAULT false). `can_write` recréé en **colonne générée** (`can_create OR can_update`).
- `access_profiles.role_type` : TEXT avec CHECK sur les 10 codes ERP standard (`proviseur|directeur|secretaire|comptable|enseignant|surveillant|directeur_etudes|chef_travaux|consultant|autre`).
- `data_scope` reste un **enum Postgres** (`own_school|own_classes`) — toujours caster `::data_scope` dans le SQL brut.

**RPC `set_profile_permissions` réécrite (SECURITY DEFINER)** :
- Auth : `super_admin` OU `admin_groupe` du même groupe. Clamp hiérarchique : un profil ne peut pas accorder plus que son créateur (sauf super_admin/admin_groupe). Trace dans `audit_logs`.

**Modal `ProfileWizardDialog` (2 étapes)** dans `admin_access_screen.dart` :
- Étape 1 : chips 10 presets, nom, type de profil, description.
- Étape 2 : matrice repliable par catégorie, 9 bascules par module, scope de données, badges sensibles (⚠ orange : delete/export/import/validate/approve/manage).
- **Bug critique corrigé** : `body` doit être `Widget?` avec `??=` pour spinner — sinon le spinner écrase l'erreur.

**Seed standard (2026-06-03)** : 70 profils créés (7 groupes × 10 rôles), permissions scopées au plan d'abonnement de chaque groupe. Script idempotent (skip si role_type déjà présent pour ce group_id). Stats : 224 permissions pour plan complet (41 modules), 153 pour Saint-Pierre (25 modules), 64 pour Bethel (plan limité).

---

### Mise à jour carte scolaire (2026-06-02) — carte décisionnelle METP

**Migrations Supabase appliquées :**
- `schools` : + `latitude double`, `longitude double`, `location_source text` (`gps`|`geocoded`|`manual`), `location_captured_at timestamptz`
- Nouvelle table `school_projects` : `id, group_id, name, latitude, longitude, status (etude|validation|budgetisation|construction|acheve), school_type, department, city, budget_xaf, beneficiaries_est, priority (haute|moyenne|basse), description, comments, school_id (FK→schools), created_by (FK→auth.users), created_at, updated_at` + RLS group_id scopé + trigger updated_at

**Provider `admin_regional_provider.dart` réécrit :**
- `AdminSchoolPin` enrichi : `id, latitude?, longitude?, locationSource?, locationCapturedAt?` + getter `hasGps`, `gpsCoords`
- Nouveau modèle `AdminProjectPin` : lat/lng requis + tous les champs projets
- `AdminRegionalData` : + `gpsSchools` (écoles géolocalisées individuellement)
- Nouveau `adminProjectsProvider` (FutureProvider séparé → invalidation granulaire sur CRUD projet)
- `AdminProjectService` : `createProject`, `updateProject`, `deleteProject`, `patchSchoolGps`

**Vue `admin_regional_view.dart` réécrite (1ère vraie carte décisionnelle) :**
- **3 couches toggleables** : GPS (écoles individuelles), Départements (bulles agrégées, fallback sans GPS), Projets (marqueurs carrés par statut)
- **Mode placement** : FAB orange `+` → bannière "appuyez pour placer" → tap carte → `_pendingProjectCoordsProv` → `ref.listen` → dialog `_ProjectFormDialog`
- **Formulaire projet** : nom, description, statut, priorité, type, département (dropdown 12 dépt), ville, budget FCFA, bénéficiaires, commentaires
- **Panneau droit contextuel** : Projet > École GPS > Département > Analyse régionale
- `_ProjectDetailPanel` : pipeline de statut visuel (5 étapes), budget, commentaires, edit+delete
- `_GpsSchoolDetailPanel` : coords copiables, source badge (GPS terrain/Géocodé/Manuel)
- `_StatusPipeline` : stepper horizontal 5 étapes avec indicateurs visuels
- `_LayerToggleBar` : toggles GPS/Départements/Projets dans le panneau gauche
- `_GlobalStats` : + stat GPS (X géolocalisées / Y sans GPS)
- `flutter analyze` 0 issue ✓

**Comment ajouter des coords GPS à une école :** `AdminProjectService.patchSchoolGps(schoolId, lat, lng)` — en attente d'un bouton « Recapturer GPS » sur le modal détail école (à ajouter dans `_SchoolDetailModal`).

---

### Passe finale 5 chantiers — Profils/Rapports/Abonnement/Audit/Paramètres (2026-06-04)

Demande utilisateur : rendre ces 5 pages « parfaites et complètes ». **Tout vérifié contre la base live** (project `wqpdamlnrwgozfvzjjpo`) puis `flutter analyze` (espace admin_groupe = **0 issue**, projet entier = 0 erreur, seuls infos/`_FilterChip` hors-scope super_admin) + `flutter build linux --debug` ✓ (binaire `build/linux/x64/debug/bundle/epilote` produit).

- **Rapports — réécriture interactive complète** (`admin_reports_screen.dart` ~1100 lignes + `admin_reports_provider.dart`). Architecture **1 seul chargement réseau** (`reportsSnapshotProvider`, keepAlive) puis **ré-agrégation locale instantanée** par filtre (`reportDataProvider` famille). Sélecteur de période (Année/T1/T2/T3/**Perso** via `showDateRangePicker`), filtre école + **drill-down** (clic sur une ligne du tableau → `reportFilterProvider.copyWith(schoolId:…)` → bascule section Synthèse), 5 sections (Synthèse/Effectifs/Finance/RH/Établissements), graphes Syncfusion (tendances spline aire + spline, donuts, barres de distribution top-8+Autres, jauge de recouvrement, parité). PDF print + download via `ReportsPdfService.printReport/downloadReport({required ReportData data})`. **⚠️ API Syncfusion 33.2.8 pré-vérifiée** : `axisLabelFormatter` = `ChartAxisLabel Function(AxisLabelRenderDetails)`, `ChartAxisLabel(String,TextStyle?)`, `TooltipBehavior.builder` = 5 params positionnels, `CategoryAxis.labelRotation` = int.
- **Audit — provider OK + données démo seedées**. `admin_audit_provider.dart` correct : facettes (HEAD `count`, tables/rôles distincts), liste paginée `.range`, **noms d'acteurs résolus via `profiles(id,first_name,last_name)` — JAMAIS `profiles(email)`** (email vit dans auth.users, ce join planterait). **Bug d'inférence corrigé** : `_adminAuditRealtimeProvider` DOIT avoir le type explicite `final AutoDisposeProvider<void> = Provider.autoDispose<void>(…)` (sinon top_level_cycle car les facettes le `watch` et il `invalidate` les facettes). **19 lignes audit_logs seedées pour le groupe test** `da3954ca-…` (10 INSERT/7 UPDATE/2 DELETE, 8 acteurs, 12 tables, 4 rôles, étalées 2026-05-07→06-04, avec old/new_values JSON pour le diff). Avant : 0 ligne → page vide. Réversibilité : `DELETE FROM audit_logs WHERE group_id='da3954ca-e2a4-486e-ac07-a2ebf992f2c6'`.
- **Paramètres — persistance réelle confirmée**. Table **`group_settings` EXISTE** en live (PK `group_id`, colonnes `general/notifications/security` jsonb + `updated_by/updated_at`) — corrige l'ancienne note « pas de table settings ». `AdminSettingsService._upsertSettings` fait un **upsert `onConflict:'group_id'`** (relit l'état courant pour ne remplacer qu'un bloc, les 3 jsonb étant NOT NULL). RLS `group_settings` : SELECT (groupe), INSERT/UPDATE (`is_admin_groupe() AND group_id=auth_group_id()`) ✓. `payment_configs` CRUD réel (colonnes `configured_by/configured_at`, enum `provider`), RLS write = admin_groupe du groupe. `requestGroupUpdate`/`requestPlanChange` → `support_tickets` (RLS INSERT `group_id=auth_group_id() AND submitted_by=auth.uid()` ✓, `status`∈{open,…}, `priority`∈{low,medium,high,urgent}, `category` = varchar libre).
- **Profils d'accès — RPC vérifiée OK**. `admin_access_provider.savePermissions` appelle `set_profile_permissions(p_profile_id, p_perms)` — noms exacts confirmés vs signature DB. La fonction (SECURITY DEFINER) : auth super_admin/admin_groupe même groupe, **clamp hiérarchique** (`v_full` pour admins, sinon intersection avec les droits de l'appelant), cast `::data_scope` (défaut `own_school`), delete+insert propre, trace `audit_logs`.
- **Abonnement — tous les plans dispo**. 4 plans actifs en live (Gratuit 0 / Premium 150k / Pro 350k / Institutionnel 900k), triés par prix → un groupe peut monter OU descendre. Familles de modules via `plan_modules⋈modules⋈module_categories` (112 plan_modules, 41 modules, 8 catégories). Changement de plan = ticket `category='changement_plan'` avec garde anti-doublon (`hasPendingRequest`). Groupe test = Institutionnel (trial, end=null → `daysLeft` null, pas de crash).
- **Lints corrigés cette passe** : 6× `sort_constructors_first` (factories remontées au-dessus des champs dans admin_settings_provider.dart), 1× `use_null_aware_elements` (`'founded_year': ?foundedYear` dans admin_schools_provider.dart), 8× `prefer_single_quotes` (admin_settings_screen.dart).

---

### Système éducatif Congo — cycles / filières / niveaux dans « Mes Écoles » (2026-06-04)

Demande : dans le formulaire de création/édition d'école, **gestion complète des cycles scolaires congolais** sans valeurs codées en dur, centralisée en base, extensible (futur supérieur), gérable dynamiquement par l'admin. Livré + `flutter analyze` admin_groupe **0 issue** + `flutter build linux --debug` ✓ + **plateforme relancée** ✓.

**Hiérarchie** : `Cycle └── Programme (filière, si applicable) └── Niveau`. `group_id NULL` = référentiel global partagé ; `group_id` défini = personnalisation propre au groupe.

**6 tables créées** (migrations `education_cycles_schema` + `education_cycles_seed`) :
- `education_cycles` (id, code, name, description, order_index, **has_programs** bool, group_id NULL=global, is_active, ts). Index unique partiel `code WHERE group_id IS NULL`.
- `education_programs` (filières : id, **cycle_id** FK, code, name, description, order_index, group_id, is_active, ts).
- `education_levels` (id, **cycle_id** FK, **program_id** FK NULL=niveau général, code, name, order_index, group_id, is_active, ts).
- Jonctions école↔offre : `school_cycles`(school_id,cycle_id,group_id, PK(school_id,cycle_id)), `school_education_programs`(school_id,program_id,group_id, PK), `school_education_levels`(school_id,level_id,group_id, PK). **⚠️ noms `school_education_programs/levels`** car `school_levels` (catalogue niveaux par groupe, FK de `classes.level_id`) et `school_programs` (table SYLLABI : subject_id/level_id/title/content) **EXISTENT DÉJÀ avec un autre sens — NE PAS TOUCHER**.

**RLS** : cycles SELECT (`is_super_admin() OR group_id IS NULL OR =auth_group_id()`), write **super_admin only**. programs/levels SELECT idem, write (`is_super_admin() OR (is_admin_groupe() AND group_id=auth_group_id())`) → l'admin ne peut PAS modifier les lignes globales (group_id NULL), seulement créer/modifier/désactiver les SIENNES. Jonctions SELECT (`super_admin OR group_id=auth_group_id()`), ALL idem write. → **« Désactiver une filière globale » = ne pas la sélectionner pour l'école** (mécanisme par école via jonction) ; modifier/désactiver ne vise que les filières perso du groupe.

**Seed global (group_id NULL)** : 5 cycles (prescolaire/primaire/college/lycee/formation_pro, ce dernier `has_programs=true`), 16 niveaux généraux (PS/MS/GS · CP1→CM2 · 6e→3e · 2nde/1ere/Tle), 21 filières FP (codes `fp_*`), 63 niveaux FP (1ère/2ème/3ème année par filière, codes `fp_<x>_a1..a3`). 4ème année = optionnelle, ajoutée par l'admin.

**Flutter** : `providers/education_provider.dart` — modèles `EducationCycle/Program/Level` (getter `isCustom => groupId!=null`), `EducationCatalog` (helpers `activeCycles`, `programsOf`, `generalLevelsOf`, `levelsOfProgram`…), `educationCatalogProvider` (FutureProvider autoDispose+keepAlive, la RLS renvoie global+groupe), `schoolEducationProvider(schoolId)` (family → `SchoolEducationSelection{cycleIds,programIds,levelIds}`), `EducationService` (`saveSchoolEducation` = delete+insert des 3 jonctions ; `createProgram/createLevel` renvoient le **nouvel id** via `.select('id').single()` pour auto-sélection ; `updateProgram`, `setProgramActive`, `setLevelActive`).
- `admin_schools_provider.dart` : `AdminSchoolsService.create(...)` renvoie désormais **`Future<String>`** (id via `.select('id').single()`) pour câbler les jonctions à la création.
- `admin_schools_screen.dart` `SchoolFormDialog` : section « CYCLES D'ENSEIGNEMENT » (après IDENTITÉ OFFICIELLE). Chips cycles (multi-select navy) → carte par cycle sélectionné → FP affiche filières (chips bleus, menu Renommer/Désactiver sur les perso) puis niveaux par filière ; cycles généraux affichent leurs niveaux (chips verts). Boutons « + Ajouter » filière/niveau (prompt → service → auto-select). `_eduChip` = GestureDetector toggle + PopupMenuButton sibling (pas de gesture imbriqué). En édition, `initState` charge la sélection via `ref.read(schoolEducationProvider(id).future)`. `_submit` : create/update école → `eduSvc.saveSchoolEducation(...)`. Point dot violet = item perso (group-scoped).

**Évolution future (supérieur)** : ajouter un cycle `superieur` (+ filières Licence/Master/Doctorat/BTS comme programs, semestres comme levels) = pur INSERT de données, **zéro refacto** (toute l'UI lit le référentiel). Les autres modules (inscriptions, classes, stats…) brancheront sur `school_cycles/education_levels`.

---

### Passe finale Abonnement + Mes Écoles + Paramètres (2026-06-04)

Demande utilisateur : Abonnement dates manquantes, KPI non propres, matrice trop étroite, ajout graphe ; logo école dans le formulaire ; actions groupées dans le tableau des écoles ; logo groupe + infos manquantes dans Paramètres.

#### Abonnement — 4 améliorations

**1. Dates Début/Échéance** : la card plan en haut affichait « — » car la table `school_groups` du groupe test avait `subscription_start/end = NULL`. Fix DB via Supabase MCP :
```sql
UPDATE school_groups
SET subscription_start = '2026-05-29', subscription_end = '2026-06-28'
WHERE id = 'da3954ca-e2a4-486e-ac07-a2ebf992f2c6' AND subscription_start IS NULL;
```
L'affichage lit directement `sub.start` / `sub.end` (déjà câblés dans `GroupSubscription`).

**2. KPI 4 colonnes dynamiques** (`_QuotaGrid`) :
- `cols = c.maxWidth > 800 ? 4 : 2` (était 3 → 4ᵉ card orpheline)
- Skeleton `_grid()` : signature `int Function(double) cols` + `double? aspectRatio` → `tileW/aspectRatio` = hauteur calculée, plus de `tileH` hardcodé.

**3. Matrice comparatif full-width** (`_ComparisonMatrix`, `_MatrixHeaderRow`, `_MatrixDataRow`) :
- `LayoutBuilder` calcule `planColW = (maxWidth - 180) / plans.length` si `maxWidth > minTableW` (180 + plans.length×120).
- Sinon fallback `SingleChildScrollView` horizontal.
- `_MatrixHeaderRow`/`_MatrixDataRow` prennent `labelColW` + `planColW` comme params (plus de largeurs hardcodées).

**4. Graphe Syncfusion `_QuotaChart`** :
- Modèle `_QChartData(label, used, maxVal, color)` — getter `pct`, `unlimited`, `displayMax`.
- `SfCartesianChart` avec **2 séries `BarSeries`** empilées : usage (couleur pleine) + capacité restante (couleur α 0.07) → effet barre segmentée.
- **⚠️ RÈGLE ABSOLUE axes Syncfusion BarSeries** : `primaryXAxis: CategoryAxis` reçoit `xValueMapper` (String), `primaryYAxis: NumericAxis` reçoit `yValueMapper` (double). L'inversion provoque un crash runtime `type 'String' is not a subtype of type 'num' in type cast` au moment où Syncfusion tente de caster la String en num pour positionner le point. **BarSeries transpose visuellement** (barres horizontales) mais les mappings data restent x=catégorie / y=valeur.
- Axe Y intelligent : `xMax = max(5.0, maxPct * 1.5).ceilToDouble()` → zoom sur les faibles % (0.6% visible, pas écrasé à zéro).
- Ressource limitée : si tous les quotas sont illimités, `_QuotaChart` retourne `SizedBox.shrink()`.
- Placé dans `_Body.build` entre `_QuotaGrid` et `AdminSectionTitle('Changer de plan')`.

#### Paramètres — `_GroupInfoCard` redessinée

`admin_settings_screen.dart` :
- `_GroupLogo` : container 72×72 radius 16, `CachedNetworkImage` si `logoUrl!=null` sinon initiales (2 lettres, dégradé navy).
- Badges : `_GroupTypeBadge` (type d'organisation), plan badge (navy/green/orange selon slug), statut badge, slug grisé.
- `_InfoGrid` : 2 colonnes responsives (`LayoutBuilder`, ≥600px → 2 col). Champs : département, année fondation, email, téléphone, plan, statut abonnement + `_subEndLabel` (jours restants / « Expiré » / « Aucune échéance »).
- Section lock + bouton « Demander une modification » inchangés.

`admin_settings_provider.dart` :
- `GroupProfile` reçoit `logoUrl` + `subscriptionStart`.
- Query enrichie : `logo_url, subscription_start`.

**Lint corrigé** : `prefer_single_quotes` ligne 432 (`"Pour toute modification..."` → `'Pour toute modification...'`).

#### Mes Écoles — logo école + actions groupées

`admin_schools_screen.dart` :
- **Logo upload** : `_SchoolLogoUploadBox` (FileImage/placeholder, bouton icône appareil-photo overlay), `_SchoolAvatar` (CachedNetworkImage/initiales), `_pickAndUploadLogo(ref, schoolId)` → `file_picker` + `supabase.storage.from('school-logos').upload(...)` → URL publique → update `schools.logo_url`.
- **Actions groupées** : `Set<String> _selectedIds` dans `_SchoolsState`, `_BulkActionBar` (sélecteur-tout + compteur + bouton Activer/Désactiver), `_CheckSquare` (AnimatedSwitcher check icon), `_bulkSetActive(bool)` → `AdminSchoolsService.setActiveBulk(ids, val)`.
- `admin_schools_provider.dart` : `SchoolDetail.logoUrl` ajouté, `setActiveBulk(List<String> ids, bool active)` dans `AdminSchoolsService`.

#### AdminStatCard — overflow hardening

`admin_ui.dart` : label + subtitle passent à `maxLines: 2` + `TextOverflow.ellipsis`. Prévient le RenderFlex BOTTOM OVERFLOW sur les KPI à libellé long (ex: « Jours restants »). Pattern à suivre pour tout nouveau `AdminStatCard`.

#### `flutter analyze` 0 issue, build ✓, app relancée (PID 449021)

---

### Paramètres — passe enrichissement « piloter des centaines d'écoles » (2026-06-04)

`admin_settings_screen.dart` enrichi sur les 4 onglets (TabController length:4), persistance dans les **3 blobs jsonb existants** de `group_settings` (aucune migration DB) :

- **Général** : `_GroupStatsCard` (Aperçu = 2 `AdminStatCard` Écoles/Utilisateurs actifs + 2 `_QuotaBar` quotas plan via `adminGroupStatsProvider`) ; `_PedagogyCard` (système de notation numeric_20/numeric_10/letter/competence + barème + durée cours + nb trimestres).
- **Facturation** : `_FeePolicyCard` (échéances par défaut, pénalité retard %, jours de grâce, remise fratrie %, bourse max %).
- **Notifications** : 3 sections ajoutées dans `_NotificationsCard` (partagent le `_s` unique) — Seuils d'alerte (assiduité/note/impayés), Rappels automatiques de paiement (toggle + 3 jours), Destinataires par rôle (4 toggles).
- **Sécurité** : `_RetentionCard`/section Conservation des données (rétention données + audit, auto-archivage) ; `_RecentLoginsCard` (`adminRecentLoginsProvider`, avatar initiales + rôle + badge Aujourd'hui/Cette semaine) ; `_RgpdActionsCard` (toast-only, **aucune écriture DB**).

**⚠️ INVARIANT MERGE-PATCH (non négociable)** : le blob `group_settings.general` est édité par **3 cartes réparties sur 2 onglets** (`_GeneralPrefsCard` régional + `_PedagogyCard` + `_FeePolicyCard` facturation). Chaque `_save()` DOIT `await ref.read(adminGroupSettingsProvider.future)` puis `current.general.copyWith(...seulement ses propres champs...)` avant `saveGeneral()`. Sinon une sauvegarde écrase les champs des 2 autres cartes avec des valeurs périmées. Les blobs `notifications` et `security` n'ont qu'un éditeur chacun (`_s` unique) → pas de patch nécessaire.

Providers ajoutés dans `admin_settings_provider.dart` (session précédente) : `GroupStats`+`adminGroupStatsProvider`, `RecentLogin`+`adminRecentLoginsProvider` ; modèles `GeneralSettings`(15 ch.)/`NotificationSettings`(20 ch.)/`SecuritySettings`(10 ch.) ; `AdminSettingsService.saveGeneral/saveNotifications/saveSecurity` via `_upsertSettings` (relit + merge 3 blobs, `onConflict:'group_id'`).

analyze 0 issue, `flutter build linux --debug` ✓, run propre (Dart VM Service up, 0 overflow). ⚠️ App GTK desktop → pas de screenshot possible via preview_* (outils web) ; confirmation visuelle = navigation manuelle vers Paramètres.

## Page « Années scolaires » refondue premium (2026-06-08)
Page `/admin/annees` passée de basique → tableau de bord analytique complet, cohérent avec le design system (`admin_ui` + Syncfusion). Découpée en library + 3 parts + 2 providers (tous ≤500) :
- `screens/admin_academic_years_screen.dart` (library, ~407) : header, **bandeau sélecteur d'année** (pilote les analyses), **ligne KPI** (élèves/classes/écoles préparées/départements couverts + variation N-1 via `_delta`), orchestration. `selectedAdminYearIdProvider`.
- `screens/admin_year_analytics.dart` (part, ~491) : **évolution pluriannuelle** (SplineArea élèves + Column classes, 2 axes Y), **répartition par département** (BarSeries horizontal, règle axes respectée X=CategoryAxis dept / Y=NumericAxis élèves), **donut type d'établissement** (public/privé/mixte), **table adoption par école**.
- `screens/admin_year_management.dart` (part, ~179) : `_YearCard` (statut+métriques+adoption progress + actions Calendrier/Définir courante/Archiver) + `_Metric`.
- `screens/admin_year_dialogs.dart` (part, ~398) : `_DateField`, `_YearDialog`, `_RolloverDialog`.
- `providers/admin_year_analytics_provider.dart` (NEW, ~179) : `AdminYearAnalytics` (byDepartment/byType/bySchool + ecolesPreparees/departementsCouverts/moyenneElevesParClasse/tauxAdoption), `adminYearAnalyticsProvider.family(yearId)` (agrégation client-side : schools×classes×enrollments par dept/type/école). `schools.department` + `school_type` (public/prive/mixte) exploités. Données test : 7 écoles / 8 départements Congo / 3 types / 2 années / 326 inscrits.
- `admin_academic_year_provider.dart` réduit à 359 (liste années + calendrier + AdminCalendarService).
0 lint, build linux ✓. ⚠️ Visible seulement connecté en **admin_groupe** (l'app tournait en proviseur).

### Correctifs 2026-06-09 (page testée en vrai via X11/scrot — voir [[gui-testing-linux]])
- **BUG page BLANCHE (cause racine)** : `_AnalyticsRow` retournait `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` directement sous le `ListView` → `stretch` force la hauteur des enfants = axe transverse non borné → **« BoxConstraints forces an infinite height »** → tout le sliver `_Body` échoue → corps **100% blanc** (+ cascade d'assertions `!semantics.parentDataDirty` qui ne sont QUE des dommages collatéraux, pas la cause). **Fix = `CrossAxisAlignment.start`** (les 2 cartes s'auto-dimensionnent, hauteurs déjà proches). ⚠️ `IntrinsicHeight` EXCLU ici car Syncfusion n'implémente pas les intrinsèques (autre crash). Règle générale : **jamais `Row(stretch)` sous un ListView** ; cf. même piège résolu autrement (`IntrinsicHeight`) dans `_ChartsRow` du dashboard, mais avec charts → préférer `start`.
- **KPI overflow 19px** : `GridView.count(childAspectRatio)` débordait (hauteur dépend de la largeur) → remplacé par `GridView.builder` + `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 190)` (hauteur FIXE, robuste à toute largeur). `AdminStatCard` ≈162px en 1 ligne ; 190 couvre label/sous-titre sur 2 lignes.
- **Incohérence 294 vs 240 corrigée (réseau ACTIF)** : le KPI « élèves » comptait toutes les inscriptions actives (294) y compris celles d'écoles **désactivées**, alors que les ventilations (dépt/type/école/donut) ne portent que sur les écoles actives (240). Le groupe test a 9 écoles dont **2 inactives** (Les Aiglons/Pointe-Noire = 54 élèves, Étoile du Nord/Sangha = 0). **Fix = tout scoper au réseau actif** : `adminAcademicYearsProvider` filtre classes+inscriptions par `activeIds` (et sélectionne désormais `school_id` sur les enrollments) ; `adminYearAnalyticsProvider` dérive `classes/eleves` de `bySchool` (actives) au lieu de `*.length`. Résultat cohérent partout : **240 élèves · 24 classes · 7 écoles actives · 6/7 préparées (86%) · 6 dépts couverts** (l'ancien « 7/7 / 100% » était FAUX : il comptait l'école inactive dans l'adoption). Pointe-Noire disparaît correctement du graphe départements.
- Vérifié visuellement (X11) : KPI=donut=somme barres dépt=240, légende donut 16+4+4=24 classes / 5+1+1=7 écoles. `flutter analyze` projet entier 0 issue.

### Passe premium 2026-06-09 (2ᵉ) — 7 chantiers, tous vérifiés à l'écran via X11
Demande user : skeleton, overflow KPI, modal pauvre, actions (export PDF), sélecteur stats par année, section archivage statique, contenu non pleine largeur sur 27".
1. **Pleine largeur 27"** : supprimé `Center > ConstrainedBox(maxWidth:1160)` dans `_Body` → `ListView` plein cadre (les enfants s'étirent). Vérifié à 2560px : plus de marges vides. (Même leçon que le dashboard, cf. note plus haut « PAS de ConstrainedBox ».)
2. **Skeleton** : nouveau part `admin_year_skeleton.dart` (`_YearsSkeleton`, `Shimmer.fromColors` base `0xFFE8ECF0`/highlight `0xFFF5F7FA`) calqué sur la vraie dispo (header+sélecteur+KPI grid+chart+row+table). Remplace le `CircularProgressIndicator` du `loading:`.
3. **KPI overflow** : `mainAxisExtent` 190→**196** (marge si label+sous-titre 2 lignes ; AdminStatCard ≈162px 1 ligne).
4. **Export PDF** : nouveau `services/admin_year_pdf_service.dart` (`AcademicYearPdfService.printReport/downloadReport({year, analytics, allYears})`) — document officiel (bandeau tricolore, emblème SVG rasterisé via `vg.loadPicture`+canvas scale, en-tête RÉPUBLIQUE DU CONGO, footer paginé) : titre+statut, grille 6 KPI, évolution pluriannuelle, ventilation dépt/type, préparation par école. **Bouton `_ExportYearButton`** (ConsumerStatefulWidget, lit `adminYearAnalyticsProvider(...).future`, état `Génération…`) dans `_Header`. Vérifié : clic → busy→idle, **0 exception** (génération réussie, fonts Google téléchargées).
5. **Sélecteur stats** : `_YearStrip`→`_StatsSelectorBar` (carte « Statistiques par année » + libellé explicatif + chips `_YearChips`) → le rôle « pilote les KPI/graphes » est explicite.
6. **Section archivage dynamique** : `_ManagementSection` (dans `admin_year_management.dart`) + `_SegFilter` segmented (Toutes/Actives/Archivées avec compteurs live, `_yearFilterProvider` StateProvider) ; cartes triées courante-d'abord ; empty-state par filtre. Remplace la liste statique.
7. **Modal calendrier enrichi** : `admin_year_calendar_dialog.dart` — `_CalendarSummary` (bandeau 3 stats : nb trimestres/séquences/trimestre courant) + empty-state premium (icône+guidage) ; largeur 580→620.
- ⚠️ **Démo DB** : mes clics de test ont archivé les 2 années → restauré 2025-2026 (current, unlocked) / 2024-2025 (archivée) → bon état démo + exerce le filtre (Actives 1 / Archivées 1).
- Tailles : `admin_academic_years_screen.dart` 499, `admin_year_pdf_service.dart` 574 (cohérent avec `reports_pdf_service` ~600). `flutter analyze` 0 issue.
- ⚠️ **Scroll GUI Flutter desktop (X11)** : le wheel `xdotool` en coords **fenêtre** (`--window`) NE scrolle PAS ; en coords **absolues écran** (fenêtre à 0,0, pointeur sur le contenu, `xdotool click --repeat N 5`) ÇA marche. Clavier (Next/End) ne scrolle pas non plus. Cf. [[gui-testing-linux]]. ⚠️ `xdotool windowsize` est ignoré si la fenêtre est **maximisée** → d'abord `wmctrl -ir <id> -b remove,maximized_vert,maximized_horz`.

### GOUVERNANCE CALENDRIER — ministère écrit, école lit (DÉCISION 2026-06-09)
**Règle non négociable** : `academic_years` / `trimesters` / `sequences` sont écrits **UNIQUEMENT par admin_groupe (ministère, online Supabase) ou super_admin**. Les écoles les **LISENT** (héritage via PowerSync sync-rules, portée groupe). Décidé par l'utilisateur (« le calendrier livré uniquement par admin groupe, les écoles utilisent simplement »).
- **Pourquoi** : supprime *par construction* le risque de **perte silencieuse** (le connecteur `powersync_connector.dart` abandonne toute transaction violant une contrainte `23xxx` — donc `uq_ay_current_group` provoquait une perte invisible si 2 écoles posaient `is_current` hors-ligne). Mono-écrivain online = plus jamais de collision. Dissout aussi la duplication de logique année online/offline. Colle au réel (calendrier national METP).
- **Nuance préservée** : l'école « adopte » une année en créant ses **CLASSES** (`copySchoolClassesToYear`, données opérationnelles propres) — ça reste autorisé. Seul le *calendrier* est read-only côté école.
- **Appliqué** :
  1. RLS migration `calendar_write_ministry_only` : sur les 3 tables, policy `<t>_select` (SELECT = `is_super_admin() OR group_id=auth_group_id()`) + `<t>_write_ministry` (ALL = `is_super_admin() OR (is_admin_groupe() AND group_id=auth_group_id())`). L'ancienne `<t>_tenant` (qui autorisait `school_id=auth_school_id()` en write) est supprimée. ⚠️ N'affecte PAS la synchro descendante (les sync-rules lisent via réplication, hors RLS) → pas de redéploiement dashboard requis ; le calendrier continue d'arriver sur tous les appareils du groupe.
  2. `structure/providers/academic_year_provider.dart` réécrit : **8 fonctions d'écriture calendrier retirées** (étaient du code mort, 0 appelant : createAcademicYear/setCurrentAcademicYear/rolloverAcademicYear/createTrimester/createSequence/setCurrent{Trimester,Sequence}/setAcademicYearLocked). Restent : lecteurs + `yearContentCountProvider` + `copySchoolClassesToYear` (dédup classes durcie `.trim()`).
  3. `school_calendar_screen.dart` + `calendar_detail.dart` étaient **déjà read-only** (tooltip « définies par le groupe et héritées ») ; corrigé le vide trompeur (« Créez une année » → « héritées du groupe »).
- **Connecteur — perte d'upload désormais OBSERVABLE** (`powersync_connector.dart`) : sur erreur fatale (22/23/42501), au lieu d'abandonner en silence, on journalise (`debugPrint`) + on expose `lastFatalUploadError` (`ValueNotifier<UploadDropInfo?>`) → diagnostic + futur écran « santé de synchro ». Vaut pour TOUTE table (futurs modules : `uq_enrollment_active_student_year`, etc.).
- **Intégrité année (DB)** : `uq_ay_current_group`/`uq_ay_current_school` (1 courante par périmètre) ✓ ; `trimesters UNIQUE(year,number)`+CHECK 1-3 ✓ ; `sequences` CHECK 1-6 ✓. **AJOUTÉ 2026-06-09** (migration `calendar_date_and_sequence_constraints`) : CHECK `end_date > start_date` sur les 3 tables + `UNIQUE(trimester_id, sequence_number)`. **Volontairement NON ajouté** : inclusion (trim⊆année, séq⊆trim) et non-chevauchement — exigeraient triggers/exclusion `btree_gist`, risque sur le chemin d'écriture ministère pour valeur marginale (écrivain unique contrôlé + validation client `_CalEntryDialog`/`_YearDialog` qui imposent fin>début). À ajouter par triggers si un jour requis.
- **Dérive schéma PowerSync corrigée** (`powersync_schema.dart`) : `grades` local était une définition périmée totalement désynchro de la table réelle (normalisée via `evaluation_id`) → réaligné ; +2 colonnes manquantes à `attendance_entries`. `evaluations`/`bulletins` étaient déjà OK. ⚠️ s'applique au prochain rebuild (schéma figé à l'init).
- **Démo** : calendrier national 2025-2026 seedé (3 trimestres + 6 séquences, T3 courant) pour le groupe test. `flutter analyze` 0, `build linux --debug` ✓.

### Restyle des modals « comme Nouvelle école » (2026-06-09, 3ᵉ)
Demande : les modals des Années doivent avoir le **même design que le modal « Nouvelle école »** (`SchoolFormDialog`) — en-tête BLANC à icône en dégradé + bouton fermer carré, labels de section à barre navy, inputs « pleins » (fond `kSurface`), pied blanc avec « Annuler » + bouton primaire **pilule à dégradé**. (Différent du `AdminDialogHeader` global = bandeau navy plein, utilisé par 9 autres écrans → **NON modifié** pour ne rien casser.)
**Nouveaux widgets réutilisables dans `core/widgets/admin_ui.dart`** (à privilégier pour tout futur formulaire admin) :
- `AdminFormDialog({icon, title, subtitle, body, footer?, width, maxHeight, scrollable, bodyPadding, saving, submitLabel, submitIcon, submitColor, onSubmit})` — scaffold complet (Dialog transparent + carte blanche radius 18 + ombre + en-tête blanc/icône dégradé/close carré + `Flexible` corps + pied). Si `footer` null et `onSubmit` fourni → pied par défaut « Annuler » + `AdminPrimaryButton`. Pour un viewer (calendrier), passer `scrollable:false`, `bodyPadding:zero`, `footer:` custom.
- `AdminFormSectionLabel(text)` (barre navy 3×13 + texte 10.5 w800 letterSpacing 1.1), `AdminFormDivider`, `adminFilledInput(hint, {icon})` (fond `kSurface`, hint), `AdminPrimaryButton({label, icon, color, saving, onTap})` (pilule dégradé `[lerp(color,black,.18), color]`, gère couleur arbitraire → vert pour « Lancer le passage »).
Les 4 modals Années (`_YearDialog`, `_RolloverDialog`, `AdminYearCalendarDialog`, `_CalEntryDialog`) réécrits avec ces widgets. Vérifié à l'écran (X11) : les 4 affichent le style école. 0 lint, build OK. ⚠️ `admin_ui.dart` à 963 lignes (dette pré-existante, fichier design-system central — pas scindé pour éviter le churn d'imports).
