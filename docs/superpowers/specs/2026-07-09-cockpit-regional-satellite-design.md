# Cockpit régional & Vue école satellite — Design

- **Date** : 2026-07-09
- **Espace** : `admin_groupe` → Tableau de bord → **Vue régionale** (`admin_regional_view.dart`)
- **Branche** : `feat/poste-vitrine-securite` (travaux en cours)
- **Statut** : design validé (brainstorming) — à implémenter après plan

---

## 1. Vision

Offrir au ministère un **cockpit territorial stratégique** : on voit **toutes les écoles du groupe positionnées sur la carte du Congo**, leur **disposition spatiale** (départements, densité, couverture), on **crée et suit des projets de construction** de nouvelles écoles, et on dispose d'une **vue satellite datée de chaque école** — objective, sans intervention ni bonne foi requise du terrain.

Principe directeur retenu au cours du brainstorming : **la vérification visuelle passe par le satellite (donnée objective), jamais par une captation confiée aux écoles** (risque de mauvaise foi / captation sélective). Le suivi des *personnes* (présence du personnel, activité) relève de la **donnée** (modules Présences déjà en base), pas de l'image.

---

## 2. Objectifs / Non-objectifs

### Objectifs
1. **Temps réel** : toute création/modification d'école, d'effectif ou de projet rafraîchit la carte en direct, y compris depuis une autre session. *(déjà livré — migration 0037)*
2. **Fondation GPS fiable** : chaque école a une position exacte (capture à la création, correction, amorçage par géocodage des écoles existantes sans GPS).
3. **Vue école satellite** : imagerie haute-résolution centrée sur le GPS de chaque école, + **frise datée** (évolution du site / avancement chantier) — 100 % satellite gratuit.
4. **Projets de construction** : créer, positionner, suivre le pipeline d'expansion (étude → validation → budgétisation → construction → achevé). *(socle déjà présent — à consolider)*
5. **Découpe** de `admin_regional_view.dart` (5089 lignes) en modules cohérents ≤ 500 lignes, au fil de l'ajout du panneau satellite.

### Non-objectifs (honnêteté technique — cf. §5)
- ❌ **Vidéo live d'une école par satellite** : physiquement impossible (résolution + cadence). Non promis, non construit.
- ❌ **Surveillance des personnes par satellite** (présence enseignants, activité en classe) : sous la résolution ET la cadence satellite. Assurée **par la donnée** (modules Présences), documentée comme approche compagnon, hors de ce périmètre.
- ❌ **Captation vidéo/photo confiée aux écoles** : écartée (mauvaise foi possible). Aucun bucket/table de capture, aucune boucle de notification « demande de vue ».
- ❌ **Imagerie satellite commerciale payante** (Planet/Maxar) : hors périmètre v1 (gratuit d'abord). Réservée à une évolution ultérieure budgétée.

---

## 3. Contraintes d'architecture (non négociables)

- **Deux chemins de données selon le rôle** :
  - **`admin_groupe`** (le ministère/admin qui consulte le cockpit) = **online, `supabase.from(...)` direct** + Realtime. C'est le consommateur principal de cette feature.
  - **Personnel scolaire** (directeurs) = offline-first PowerSync. *Non concerné par la captation ici* (on ne leur demande rien pour le satellite).
- **Cibles desktop** : `linux` + `windows` présents → **flutter_map uniquement** (pas de `google_maps_flutter`, non supporté desktop). La feature reste dans `flutter_map` (couches de tuiles).
- **Aucune clé API payée, aucun secret client** : l'imagerie retenue (Esri World Imagery + Esri Wayback) est servie **sans authentification**.
- **Ne jamais gater la synchro PowerSync** sur quoi que ce soit (C4/ADR-0006).
- **Fichiers Dart ≤ 500 lignes** (règle projet) — d'où la découpe.

---

## 4. État existant (à conserver / réutiliser)

`admin_regional_view.dart` (5089 lignes) contient déjà, et fonctionne :
- Carte `flutter_map` avec masque géographique Congo, fonds **OSM / satellite Esri / hybride** (`_TileStyle`).
- Écoles **agrégées par département** (bulles `_deptCoords`, 15 départements réforme oct. 2024) + écoles **géolocalisées** positionnées individuellement (`AdminSchoolPin.hasGps`).
- Coloration des pins par **Type / Charge (élèves·classe) / Occupation (élèves·capacité)** (`_PinColorMode`).
- Couches **Villages & Routes** via Overpass (`admin_geo_provider.dart`, asset `congo_places.json` = 1532 localités + `congo_adm0/adm1`).
- **Pipeline de projets** de construction (`school_projects`, CRUD `AdminProjectService`, statut/budget/priorité/bénéficiaires), panneaux `_PipelinePanel` / `_ProjectDetailPanel` / `_StatusPipeline`.
- **Analytique** territoriale (distances réelles Haversine), timeline des créations, couverture départementale, panneau « couches disponibles vs manquantes ».
- **Mode Tableau** (`regional_table_mode.dart`) + export **PDF officiel** (`regional_pdf_service.dart`).
- **Vue rue Mapillary** (`mapillary_viewer.dart` / `mapillary_provider.dart`).

Providers de données (admin online) : `adminRegionalProvider` (écoles+effectifs, **Realtime désormais actif**), `adminProjectsProvider`, `adminProjectServiceProvider`, `admin_geo_provider` (villages/routes/frontières), `regional_table_provider`.

**Décision sur la Vue rue Mapillary** : elle est **remplacée** comme mécanisme central par la Vue école satellite. Mapillary est **conservé en couche bonus** là où il existe (axes Brazzaville/Pointe-Noire), mais n'est plus la promesse principale. Aucune suppression destructive : le viewer reste accessible.

---

## 5. Réalité technique du satellite (le socle d'honnêteté)

Deux limites physiques cadrent tout :

- **Résolution** : meilleur commercial ≈ 0,3 m/pixel ; **gratuit haute-réso (Esri)** ≈ 0,3–1 m selon la zone. Un humain ≈ 0,5 m = **1 pixel** → on voit **bâtiments, cour, toits, véhicules**, jamais les personnes. ⇒ surveillance du personnel par satellite = **impossible**.
- **Cadence** : orbite basse = survol ~90 s par passage, revisite en jours ; géostationnaire = 36 000 km, incapable de résoudre un bâtiment. ⇒ **pas de live**, uniquement des **clichés datés**.

**Ce que le satellite fait parfaitement** (et sans mauvaise foi possible) : confirmer qu'une école **existe** au GPS déclaré (anti-école-fantôme), **mesurer l'emprise** au sol, **suivre l'avancement d'un chantier** via comparaison d'images datées.

**Source retenue — Esri Wayback** (vérifiée le 2026-07-09) :
- **195 versions datées** de l'imagerie mondiale Esri (2014 → 2026-06-30), haute-résolution.
- Tuiles **WMTS sans clé API** : `https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/{release}/{z}/{y}/{x}`.
- Config des versions : `https://s3-us-west-2.amazonaws.com/config.maptiles.arcgis.com/waybackconfig.json` (itemTitle = date, itemURL = template, layerIdentifier).
- Couche de **métadonnées** par version → date réelle d'acquisition par tuile (v2, optionnel).
- Se branche exactement comme la couche satellite Esri actuelle (`TileLayer(urlTemplate: …)`).

Sentinel-2 (gratuit, 10 m, daté) : **écarté en v1** (10 m = une école ≈ 2-3 pixels, trop grossier pour voir le bâtiment). Noté comme couche « paysage/changement » optionnelle future.

---

## 6. Design détaillé

### 6.1 Temps réel — LIVRÉ
Migration **0037** (`ALTER PUBLICATION supabase_realtime ADD TABLE schools, students, school_projects` + `REPLICA IDENTITY FULL`). Vérifié en prod : 3 tables publiées, replica identity `full`. Le `adminRegionalProvider` s'abonnait déjà (débounce 2 s → `invalidateSelf`) ; les événements arrivent désormais. **Rien à coder** — reste une vérif E2E GUI dans l'espace admin_groupe.

### 6.2 Fondation GPS (le pivot)
Sans position exacte, pas de vue école. Colonnes `schools.latitude/longitude/location_source/location_captured_at` **déjà présentes**.

- **Géocodage offline (amorçage + secours)** : nouveau `schoolGeocoderProvider` qui charge `congo_places.json` (réutilise le modèle `GeoPlace` déjà chargé par `admin_geo_provider`) et résout `schools.city` (normalisation accents/casse) → `LatLng`. `location_source = 'geocoded'`. Sert à **caler les 19 écoles actuellement sans GPS** et toute future école dont on ne saisit que la ville.
- **Correction manuelle** : le dialogue `_SchoolGpsDialog` existe déjà (`patchSchoolGps`, `source='manual'`) → on le conserve/renforce (recherche d'adresse via `congo_places`, glisser le pin sur la carte).
- **Capture à la création d'école** : le formulaire « Nouvelle école » (`admin_schools_screen.dart`) propose de **positionner sur la carte** ou de **déduire du champ ville** (géocodage) → l'école naît géolocalisée. `source='manual'` si posé à la main, `'geocoded'` sinon.
- **Aucune dépendance `geolocator`** ajoutée (admin sur desktop, pas de GPS matériel) : le positionnement se fait à la carte + géocodage.

### 6.3 Vue école satellite
Nouveau module `satellite/` :
- **`wayback_provider.dart`** :
  - `waybackReleasesProvider` (FutureProvider, `keepAlive`) : télécharge une fois `waybackconfig.json`, renvoie `List<WaybackRelease{ releaseNum, date, tileUrlTemplate }>` triée par date décroissante. Dégradation propre si hors-ligne (liste vide → panneau affiche « imagerie datée indisponible », la vue Esri courante reste).
  - Modèle `WaybackRelease` immuable.
- **`school_satellite_view.dart`** (widget, ≤ 500 l) : intégré au **panneau détail d'école** (`school_detail_panel.dart`) :
  - **Vue actuelle** : mini-`FlutterMap` non interactif (ou interactif léger) centré sur le GPS de l'école, zoom bâtiment (~z18), fond satellite Esri, marqueur école.
  - **Frise datée (Wayback)** : sélecteur de version (curseur/segmenté) qui échange la `TileLayer` par la version choisie ; **date affichée** ; mode **avant/après** (deux dates comparées côte à côte ou slider). Objectif : voir l'évolution du site / le chantier.
  - **États** : école sans GPS → CTA « Définir la position » (ouvre 6.2) ; imagerie indisponible → message réseau + réessai.
- **Réutilisation** : mêmes conventions de `TileLayer` que `_OsmMap`. Aucune nouvelle table, aucun bucket, aucun secret.

### 6.4 Projets de construction (consolidation)
Le socle existe (`school_projects`, CRUD, pipeline, panneaux). On **confirme et complète** dans la découpe :
- Création d'un projet **par clic sur la carte** (coordonnées pré-remplies) — déjà partiellement là (`_ProjectFormDialog(initialCoords)`).
- **Vue satellite du site du projet** : le panneau projet (`project_detail_panel.dart`) réutilise `school_satellite_view` centré sur les coords du projet → on voit le terrain **avant** construction, et la frise datée suit l'avancement.
- Realtime projets (0037) → un projet créé apparaît en direct.
- Rien de neuf en base ; on réutilise `AdminProjectService` et `adminProjectsProvider`.

### 6.5 Surveillance du personnel (compagnon, hors périmètre)
Documenté, non construit ici : la présence/activité des personnes relève des **modules Présences (RH personnel + présences élèves)** déjà en base — surveillance par la donnée, infalsifiable, croisée aux effectifs. Le cockpit satellite confirme le **contenant** (le bâtiment existe/fonctionne) ; la donnée de présence confirme le **contenu**. À relier plus tard (KPI de présence sur le panneau école).

### 6.6 Découpe de `admin_regional_view.dart`
Éclatement le long des coutures de cohésion, en logeant la Vue école. Structure cible sous `screens/regional/` :

```
screens/regional/
  regional_view.dart          (entrée : layout 3 colonnes + bascule Carte/Tableau)
  map/
    osm_map.dart              (_OsmMap : FlutterMap + couches + masque Congo)
    map_tile_switcher.dart    (fond OSM/satellite/hybride)
    map_markers.dart          (place, dept label, pins écoles/clusters, projets)
  panels/
    dept_detail_panel.dart
    school_detail_panel.dart  (+ intègre satellite/school_satellite_view)
    project_detail_panel.dart (+ vue satellite du site)
    coverage_panel.dart
    pipeline_panel.dart
  analytics/
    regional_analytics.dart
    territorial_analysis.dart
    creations_timeline.dart
    data_gaps.dart
  bars/
    filter_bar.dart  layer_toggle_bar.dart  legend.dart
    global_stats.dart  export_bar.dart  pin_color_switch.dart
  dialogs/
    project_form_dialog.dart
    school_gps_dialog.dart
  satellite/
    wayback_provider.dart
    school_satellite_view.dart
```

Principe (règle projet) : **on ne découpe que ce qu'on touche + le strict nécessaire** pour loger proprement la feature. Priorité : extraire `map/`, `panels/` (dont school), `dialogs/`, `satellite/`. Les blocs `analytics/` et `bars/` suivent si on les modifie. Aucun découpage arbitraire au milieu d'un widget.

---

## 7. Modèle de données

**Aucune nouvelle table, aucun nouveau bucket.**
- `schools` : colonnes GPS déjà présentes (`latitude, longitude, location_source ∈ {gps, geocoded, manual}, location_captured_at`).
- `school_projects` : déjà présente (statut/budget/priorité/bénéficiaires/coords).
- Realtime : `schools`, `students`, `school_projects` publiées + `REPLICA IDENTITY FULL` (0037, livré).
- Imagerie satellite : **externe, sans état en base** (tuiles Esri/Wayback à la volée).
- Assets réutilisés : `congo_places.json`, `congo_adm0.json`, `congo_adm1.json`.

---

## 8. Gestion d'erreurs & dégradation

| Situation | Comportement |
|---|---|
| École sans GPS | Panneau : CTA « Définir la position » (carte + géocodage ville). Pas de vue satellite tant que non positionnée. |
| Ville introuvable au géocodage | Retombe sur le centroïde départemental ; invite à poser le pin manuellement. |
| `waybackconfig.json` injoignable (hors-ligne) | Frise datée masquée ; la vue satellite Esri courante reste affichée ; message discret + réessai. |
| Tuiles satellite lentes/HS | `TileLayer` gère le fallback ; fond de carte visible sous les tuiles. |
| Realtime déconnecté | Fail-soft : rafraîchissement au chargement/pull ; données locales de la dernière charge conservées (comportement `adminRegionalProvider` existant). |
| Aucun projet / aucune école | États vides déjà présents, conservés. |

---

## 9. Tests

- **Unitaires** :
  - `schoolGeocoderProvider` : normalisation (accents/casse), correspondance exacte et approchée, secours département, ville inconnue.
  - `waybackReleasesProvider` : parsing `waybackconfig.json` (mock), tri par date, liste vide si erreur réseau.
  - Helpers GPS existants (distances Haversine) : non-régression.
- **Golden/Widget** (avec précaution overlay — cf. [[overlay-builder-golden-blindspot]]) : `school_satellite_view` états (avec GPS / sans GPS / imagerie indisponible).
- **Vérif GUI réelle** (Linux, `GDK_SCALE=1`) : espace admin_groupe → Vue régionale → créer une école, la géolocaliser, voir la vue satellite + frise datée ; créer un projet par clic carte ; vérifier le **temps réel** (modifier une école dans une 2ᵉ session → la carte bouge).
- **Analyse** : `flutter analyze` à 0 issue ; chaque nouveau fichier ≤ 500 lignes.

---

## 10. Séquencement de livraison

1. **Temps réel** — ✅ livré (0037), à vérifier GUI.
2. **Découpe** map/panels/dialogs (prépare le terrain, sans changement fonctionnel) → analyze 0, non-régression GUI.
3. **Fondation GPS** — géocodeur `congo_places` + backfill des 19 écoles + capture à la création + correction.
4. **Vue école satellite** — `wayback_provider` + `school_satellite_view` (vue actuelle → frise datée → avant/après).
5. **Projets** — vue satellite du site + création par clic carte (consolidation).
6. **Compagnon présence** (KPI) — ultérieur, hors ce périmètre.

---

## 11. Hors périmètre (YAGNI)

- Imagerie commerciale payante (Planet/Maxar), tasking à la demande.
- Vidéo live / flux caméra / WebRTC.
- Captation confiée aux écoles (photos/vidéos utilisateurs), bucket & notifications associés.
- Densité population / isochrones OSRM / projections démographiques (dépendent de données d'institutions nationales — cf. panneau « couches manquantes »).
- Détection automatique de bâtiments par IA sur l'imagerie.

---

## Références code
- `epilote/lib/features/admin_groupe/screens/admin_regional_view.dart` (à découper)
- `epilote/lib/features/admin_groupe/providers/admin_regional_provider.dart` (Realtime écoles/effectifs)
- `epilote/lib/features/admin_groupe/providers/admin_geo_provider.dart` (`GeoPlace`, `congo_places.json`)
- `epilote/lib/features/admin_groupe/screens/regional_table_mode.dart` (mode Tableau)
- `database/migrations/0037_realtime_regional_map_tables.sql` (livré)
- Esri Wayback config : `config.maptiles.arcgis.com/waybackconfig.json`
