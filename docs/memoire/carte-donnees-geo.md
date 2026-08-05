---
name: carte-donnees-geo
description: "État et provenance des données géo de la carte régionale (congo_places.json), filtrage frontière, GeoNames en attente, vue rue"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7da1bcc-2439-4035-98e1-16e7b92e17f8
---

# Données géo carte régionale (admin_groupe)

**Fait :** `assets/geo/congo_places.json` = **1532 localités 100% Congo-Brazzaville** (2026-06-03). Source = OpenStreetMap via Overpass (requête par relation-frontière `area["ISO3166-1"="CG"]`, PAS bbox). Schéma : `{name,lat,lng,type}` (city/town/village/hamlet/isolated_dwelling/locality/suburb/quarter/neighbourhood). Seul Ouesso ajouté à la main (absent d'OSM).

**Why :** la version précédente (6817 entrées « régénérées Overpass ») était contaminée — 5387 localités étaient du Cameroun (Ambam, Ebolowa, Mbalmayo…), Gabon (Bitam, Makokou, Moanda…), RDC (Kinshasa, Mbandaka…), Guinée éq. (Mongomo). Filtrées par point-in-polygone avec `congo_adm0.json` (clé `outer`, paires `[lat,lng]`, anneau fermé 888 pts).

**How to apply :**
- Dédup par `(nom normalisé sans accents, round(lat,2), round(lng,2))`.
- Overpass **exige un User-Agent** sinon `406 Not Acceptable` (Apache). UA utilisé : `EPiloteCongo/1.0`.
- **✅ GeoNames FUSIONNÉ (2026-07-10, commit `238f460`)** : `download.geonames.org/export/dump/CG.zip` a répondu cette fois (le time-out de juin était transitoire). Parser `CG.txt` classe P (PPL→village, PPLA*→town, PPLC→city, PPLX→quarter, PPLL→locality, PPLF→hamlet ; skip PPLQ/PPLW/PPLH abandonnés). **1551 → 6966 lieux** (corridor Sembé–Souanké 3 → 73 ; villages ruraux OSM n'avait pas). OSM ne donne que **1524 lieux NOMMÉS** pour tout le Congo → GeoNames est LA source dense. Le guard `_PlacesNotifier` (`live.length >= current.length`) protège désormais : live OSM (1524) < asset (6966) → toujours rejeté, asset riche conservé.
  - ⚠️ **NE PAS hard-filtrer GeoNames CG par `congo_adm0.json`** : le polygone (888 pts, simplifié) est trop grossier et **découpe des villages frontaliers légitimes** (33 hors-polygone, dont **Ngouala/Ngbala** demandés par l'utilisateur). GeoNames CG est **codé par pays à la source** (pas de bbox) → aucune contamination étrangère (le « Mongomo » détecté est un village du SUD Congo lat −3, pas la ville de Guinée éq. à +1.6/+11.3). Le filtre-polygone de juin visait un dump **bbox** Overpass (qui, lui, raflait Cameroun/Gabon/RDC) — cas différent.
  - Perf carte : dataset dense → culling des étiquettes de localités sur emprise visible + tampon 60 % (`_labelBounds`/`_viewEscapedLabelBounds` dans `regional_map.dart`). Villages nom z≥9, hameaux z≥11, quartiers z≥12.5.

**Carte affichée d'emblée (régression corrigée 2026-06-03) :** `AdminRegionalView.build` ne doit JAMAIS gater la carte derrière `adminRegionalProvider` (données écoles Supabase). Avant, un `.when(loading: spinner)` + `Future.wait` sans timeout = spinner infini si réseau lent → carte jamais affichée. Désormais : `_MapLayout` rendu TOUJOURS avec `async.valueOrNull ?? AdminRegionalData.empty`, marqueurs écoles superposés à l'arrivée des données, chip non-bloquant `_MapDataStatus` (chargement/erreur/0 école), + `.timeout(20s)` sur la requête. **How to apply :** garder ce découplage — la carte géo (assets embarqués) ne dépend jamais d'un appel réseau.

**⚠️ EXCEPTION à « live d'abord » — couche DÉPARTEMENTS (donnée régalienne, 2026-06-03) :** pour les 15 départements, l'asset embarqué `congo_adm1.json` (vérifié complet : 15 dépts dont les 3 de la réforme du 8 oct. 2024 — Congo-Oubangui/Mossaka, Nkéni-Alima/Gamboma, Djoué-Léfini/Odziba) **prime sur le live OSM**. `_DeptsNotifier._refreshLive` (`admin_geo_provider.dart`) n'accepte le résultat Overpass que si `live.length >= current.length` — sinon OSM (crowdsourcé, en retard sur la réforme) pourrait silencieusement faire retomber la choroplèthe à 12 dépts en pleine démo. **Ne PAS rétablir un `state = AsyncData(live)` inconditionnel.** La règle « live d'abord » reste valable pour boundary/places/roads, PAS pour les départements officiels. La réforme 12→15 est confirmée (lois 24-2024 du 8 oct. 2024, JO sgg.cg).

**Vue rue (ministre veut voir toits + ruelles) :** dans `admin_regional_view.dart` — `maxZoom` MapOptions relevé 14→19 (toits/ruelles visibles sur satellite Esri z19 en ville), Esri `maxNativeZoom` 18→19. `national_map_screen.dart` (super_admin, OSM seul z12) laissé inchangé.

**Visionneuse Mapillary INTÉGRÉE (2026-06-03) :** bouton `_StreetViewFab` ouvre désormais un panneau DANS l'app (`MapillaryViewerDialog`, `lib/features/admin_groupe/widgets/mapillary_viewer.dart`), PAS le navigateur. Photos au sol récupérées via Graph API (`mapillary_provider.dart` → `mapillaryNearbyProvider` family, bbox ±0.012°≈1.3km, tri par distance, défilables).
- **Contrainte clé :** pas de WebView Flutter sur Linux desktop → impossible d'embarquer le viewer JS interactif Mapillary. La solution = afficher les images JPEG via API (marche partout). Aucune vue rue n'est temps réel (photos d'archive datées) — c'est normal, expliqué et accepté par l'utilisateur.
- **Token Mapillary :** client token (lecture publique) en dur dans `mapillary_provider.dart` = `MLY|27757907297126048|f97c9e47...`. ⚠️ Le **client secret** NE doit JAMAIS être mis dans l'app (exposé dans le binaire) — gardé hors code. Couverture Congo limitée aux axes Brazzaville/Pointe-Noire.
**How to apply :** pour toute imagerie sol future, passer par l'API images (JPEG natif), jamais par WebView sur desktop.
