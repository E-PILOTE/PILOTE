---
name: regional-satellite-cockpit
description: Vue régionale admin_groupe — temps réel + Vue école satellite datée (Esri Wayback) + géocodage GPS + découpe du fichier
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a40fc29-8762-4c8e-bbec-655c8bf3d09a
---

**Cockpit territorial admin_groupe** (Tableau de bord → Vue régionale) refondu 2026-07-09, branche `feat/poste-vitrine-securite`, GUI-vérifié en réel (paul admin_groupe). Spec + plan dans `docs/superpowers/{specs,plans}/2026-07-09-cockpit-regional-satellite*`.

**Livré :**
- **Temps réel** (mig `0037`) : `schools`/`students`/`school_projects` ajoutées à `supabase_realtime` + `REPLICA IDENTITY FULL` (filtre `group_id` non-PK). `adminRegionalProvider` s'abonnait déjà (débounce 2 s→invalidateSelf) mais tables non publiées = mort silencieux → corrigé. Vérifié : école/projet apparaît sur la carte à la seconde. Voir [[realtime-publication-requirement]].
- **Vue satellite datée** : la vraie « vue rue » pour le Congo = **satellite objectif** (aucune captation confiée aux écoles → pas de mauvaise foi ; aucun live/vidéo satellite n'existe, que des clichés datés ; pas de surveillance des *personnes* par satellite → ça reste la donnée de présence). Source **Esri Wayback** (195 versions datées, WMTS **sans clé API ni coût**) + Esri courant. `wayback_provider.dart` (`parseWaybackConfig` URL→`{z}/{y}/{x}`, liste vide hors-ligne) + widget `SchoolSatelliteView(center,title)` (mini-FlutterMap + curseur de dates). Injecté dans panneau **détail école** ET **détail projet** (« Vue satellite du site »). ⚠️ Google Maps EXCLU : pas de support desktop Linux/Windows, et n'apporterait rien.
- **Fondation GPS** : `school_geocoder_provider.dart` (`geocodeCity` sur l'asset `congo_places.json` 1532 lieux — RÉUTILISE le `congoPlacesProvider` canonique d'`admin_geo_provider`, ne pas re-créer). `geocodeMissingProvider` = bouton « Géolocaliser N écoles » (backfill source=`geocoded`). Géoloc auto à la création d'école (via ville). Vérifié : 2 écoles → 100 % GPS.
- **Projets** : création par clic carte (placement mode) déjà là ; + vue satellite du site.
- **Découpe** : `admin_regional_view.dart` (5089 l) éclaté en 14 **part-files** `screens/regional/*.dart` (`part of '../admin_regional_view.dart';`, convention projet). Tête 333 l ; chaque part ≤500 sauf `regional_map.dart` (737, `_OsmMap` = 1 widget) et `regional_project_dialog.dart` (513). Split au script sur les frontières `// ───`.
- **Tests géo pré-existants remis au vert** : `admin_geo_test` attendait 12 départements → **15** (réforme oct. 2024, asset `congo_adm1` à jour) ; types de localités élargis aux valeurs OSM réelles (hamlet/suburb/…). Suite : **175 tests verts**, analyze 0, build linux OK.

**Reste** : slider Wayback (drag) non testé au pixel (classifier flaky) mais rendu live confirmé ; base satellite/Charge/Occup/PDF/Mapillary non re-cliqués (features existantes). Aucune erreur runtime sur tout le parcours.

**Passe « qualité pilotage gouvernemental » (2026-07-10, non commité, GUI non re-vérifiée — entrée X bloquée) :**
- **Fiabilité routes** : `_overpassPost` = fallback multi-miroirs Overpass (kumi.systems→overpass-api.de→private.coffee) car l'endpoint public seul 504-ait systématiquement ; les 3 fetchers (routes/dépts live/localités) y passent.
- **Bug `depts` vs `allDepts`** (même racine que KPI/PDF) : choroplèthe départementale + bordures se lisaient sur `data.depts` (écoles SANS GPS) → tout transparent dès géolocalisation. Fix = `allDepts` (toutes écoles) + bordures épaissies (2.2px/85%). Légende resynchronisée (alphas + « 0 % active »).
- **Création projet durcie** : liste des 15 dépts = source unique `_ProjectFormDialog._departments` (coercition à null si hors liste → plus de crash DropdownButton « exactly one item ») ; garde-fou géo (refus clic hors bbox Congo) ; **pré-remplissage département** au clic (centroïde le plus proche, `_nearestDeptName`).
- **Boîte à outils carte pro** (tout NEUF) : `Scalebar` (flutter_map 7), contrôles zoom/±/**recadrage Congo** (`_MapControls`), **lecture coordonnées curseur** (`onPointerHover`→`_CoordReadout`), **outil mesure de distance** (mode clic→polyline+total km, `_MeasureBanner`), **frise satellite datée Wayback SUR LA CARTE PRINCIPALE** (`_WaybackFrieze`, `_waybackIndexProv`, TileLayer keyée par URL), **export image PNG** de la carte (`RepaintBoundary`→`toImage`→Téléchargements→`launchUrl`).
- **Découpe** : contrôles+widgets sortis dans `regional/regional_map_controls.dart` (281 l) ; `regional_map.dart` 1232→952 (le `_OsmMapState` reste 1 widget cohésif, non fractionnable en part).
- Non implémenté (assumé, non-bloquant) : outil mesure de SURFACE, calque étiquettes hybride parfois coupé par arcgisonline (errno 104, hors contrôle, non fatal).
