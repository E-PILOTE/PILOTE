# Cockpit régional & Vue école satellite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire de la Vue régionale (admin_groupe) un cockpit territorial parfait : temps réel, GPS fiable par école, vue satellite datée par école/projet, projets de construction, fichier découpé — et vérifier que TOUTE la page fonctionne.

**Architecture:** admin_groupe = online `supabase.from()` + Realtime. Carte = `flutter_map` (couches de tuiles, pas de Google Maps — cibles desktop). Satellite = Esri World Imagery + Esri Wayback (tuiles WMTS **sans clé API ni coût**). GPS = géocodage offline via `congo_places.json`. Découpe via `part`/`part of` (convention projet existante).

**Tech Stack:** Flutter, Riverpod, flutter_map ^7, latlong2, http, PowerSync/Supabase, Syncfusion (existant).

## Global Constraints

- **Fichiers Dart ≤ 500 lignes** (alerte 400). Découper le long des coutures de cohésion, jamais au milieu d'un widget.
- **admin_groupe uniquement online** : `supabase.from(...)` / Realtime. JAMAIS `db.watch()` ici.
- **Aucune clé API payée, aucun secret client.** Imagerie Esri/Wayback servie sans auth.
- **Cibles desktop (linux/windows)** → `flutter_map` uniquement. Ne PAS ajouter `google_maps_flutter`.
- **Ne jamais gater la synchro PowerSync** (C4/ADR-0006).
- **Découpe = `part of` du fichier tête** `admin_regional_view.dart` (garde sa position et ses imports ; classes privées restent visibles). Parts sous `lib/features/admin_groupe/screens/regional/`.
- Commandes depuis `epilote/`. `flutter analyze` doit rester à **0 issue**. GUI Linux : `GDK_SCALE=1`.
- Devise XAF. `.withValues(alpha:)` (pas `withOpacity`). `inFilter()` (pas `in_()`).

---

## File Structure

**Fichier tête (garde sa place + ses imports) :**
- `lib/features/admin_groupe/screens/admin_regional_view.dart` — imports + directives `part` + `AdminRegionalView` (public) + `_MapLayout` (entrée layout). Cible finale ≤ 500 l.

**Parts créés (`part of '../admin_regional_view.dart';`) sous `screens/regional/` :**
- `regional_state.dart` — enums `_TileStyle`, `_PinColorMode`, providers d'état, `_RegionalFilter`, `_kWorldRect`.
- `regional_bars.dart` — `_ModeSwitch`, `_ModeBtn`, `_FilterBar`, `_LayerToggleBar`, `_PinColorSwitch`, `_TileBtn`, `_FilterChip`, `_MapTileSwitcher`, `_GlobalStats`, `_StatPill`, `_RegionalExportBar(+State)`.
- `regional_map.dart` — `_OsmMap(+State)`, `_MapDataStatus`, `_StreetViewFab`, `_GeoLoadingOverlay`, `_PlaceMarker`, `_DeptLabel`, `_MapLegend`.
- `regional_panels.dart` — `_PipelinePanel`, `_PipelineStat`, `_DeptCoverage`, `_CoveragePanel`, `_DeptDetail`.
- `regional_school_panel.dart` — `_GpsSchoolDetailPanel`, `_CoordRow` (**+ intègre la Vue satellite**).
- `regional_project_panel.dart` — `_ProjectDetailPanel`, `_IconBtn`, `_StatusPipeline`.
- `regional_analytics.dart` — `_RegionalAnalytics`, `_CreationsTimeline`, `_TerritorialAnalysis`, `_TerritorialKpi`, `_DataGaps`.
- `regional_dialogs.dart` — `_ProjectFormDialog(+State)`, `_ProjSection`, `_PriorityChip`, `_SchoolGpsDialog(+State)`.
- `regional_widgets.dart` — `_MiniChip`, `_DetailKpi`, `_TypeMix`, `_AnalyticKpi`, fonctions utilitaires (`_typeColorForPin`, `_typeLabel`, `_locationSource*`, `_fmtDate`, etc.), `_IsolationStat`, `_TerritorialReport`.

**Nouveaux modules autonomes (vrais fichiers, imports propres) :**
- `lib/features/admin_groupe/providers/school_geocoder_provider.dart` — géocodage ville→coords via `congo_places.json`.
- `lib/features/admin_groupe/providers/wayback_provider.dart` — versions datées Esri Wayback.
- `lib/features/admin_groupe/widgets/school_satellite_view.dart` — widget vue satellite + frise datée.

**Migration :** `database/migrations/0037_realtime_regional_map_tables.sql` — ✅ déjà appliquée/vérifiée (livrée).

**Tests :**
- `epilote/test/school_geocoder_test.dart`
- `epilote/test/wayback_provider_test.dart`
- `epilote/test/school_satellite_view_test.dart`

---

## Phase 0 — Temps réel (déjà livré, à vérifier)

### Task 0: Vérifier le temps réel en GUI

**Files:** aucun (vérification). Migration 0037 déjà en prod.

**Interfaces:**
- Consumes: `adminRegionalProvider` (Realtime schools/students déjà câblé).
- Produces: rien (gate de vérification).

- [ ] **Step 1 : Confirmer la publication en base**

Dans le dashboard Supabase → Database → Replication → publication `supabase_realtime`, vérifier que `schools`, `students`, `school_projects` y figurent. (Déjà confirmé le 2026-07-09 : les 3 tables publiées + `REPLICA IDENTITY FULL`.) Alternative SQL via Management API — passer le nom de publication en littéral échappé pour éviter que l'API l'interprète comme une colonne :
```bash
curl -s -X POST "https://api.supabase.com/v1/projects/wqpdamlnrwgozfvzjjpo/database/query" \
  -H "Authorization: Bearer $SUPABASE_PAT" -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{"query":"select tablename from pg_publication_tables where pubname='supabase_realtime' and tablename in ('schools','students','school_projects') order by 1"}
JSON
```
Expected : les 3 tables listées. (PAT dans la mémoire `supabase-credentials`.)

- [ ] **Step 2 : Vérif E2E dans l'app**

Lancer l'app (`GDK_SCALE=1 flutter run -d linux`), se connecter en **admin_groupe** (paul@epilote.cg), ouvrir Tableau de bord → Vue régionale. Dans une 2ᵉ session (ou via SQL), modifier une école (`update schools set name=... where group_id=...`). 
Expected : la carte se rafraîchit seule en < 3 s (débounce 2 s).

- [ ] **Step 3 : Commit** (rien à committer ; cocher la case)

---

## Phase 1 — Découpe de `admin_regional_view.dart`

> Chaque tâche : créer le part avec l'en-tête `part of '../admin_regional_view.dart';`, **couper** les classes indiquées du fichier tête, les **coller** dans le part (inchangées), ajouter la directive `part '...';` dans le fichier tête. Aucune modification de logique, aucun import à changer (les parts héritent des imports de la tête). Vérif : `flutter analyze` = 0, l'app compile, non-régression GUI.

### Task 1.1 : Extraire l'état (`regional_state.dart`)

**Files:**
- Create: `epilote/lib/features/admin_groupe/screens/regional/regional_state.dart`
- Modify: `epilote/lib/features/admin_groupe/screens/admin_regional_view.dart`

**Interfaces:**
- Produces: tous les providers d'état et enums, désormais dans un part (même bibliothèque → visibilité inchangée).

- [ ] **Step 1 : Créer le part**

Créer `regional/regional_state.dart` :
```dart
part of '../admin_regional_view.dart';
```
Puis **déplacer** depuis `admin_regional_view.dart` vers ce part : le bloc `// ─── State providers ───` et tout ce qui suit jusqu'à `_RegionalFilter` inclus — soit les enums `_TileStyle` (l.82) et `_PinColorMode` (l.101), leurs providers `_pinColorModeProv`, `_tileStyleProv`, les providers d'état de couches/filtre/sélection, `const _kWorldRect` (l.108), et la classe `_RegionalFilter` (l.116-171). (Les repères de ligne datent de l'état initial ; se fier aux noms.)

- [ ] **Step 2 : Déclarer le part dans la tête**

Dans `admin_regional_view.dart`, juste après les `import ...;`, ajouter :
```dart
part 'regional/regional_state.dart';
```

- [ ] **Step 3 : Analyser**

Run: `cd epilote && flutter analyze lib/features/admin_groupe/screens/`
Expected: `No issues found!`

- [ ] **Step 4 : Compiler**

Run: `cd epilote && flutter build linux --debug`
Expected: build réussi.

- [ ] **Step 5 : Commit**

```bash
git add epilote/lib/features/admin_groupe/screens/admin_regional_view.dart epilote/lib/features/admin_groupe/screens/regional/regional_state.dart
git commit -m "refactor(carte): extrait l'état de la Vue régionale (part regional_state)"
```

### Task 1.2 : Extraire les widgets utilitaires (`regional_widgets.dart`)

**Files:**
- Create: `epilote/lib/features/admin_groupe/screens/regional/regional_widgets.dart`
- Modify: `epilote/lib/features/admin_groupe/screens/admin_regional_view.dart`

**Interfaces:**
- Produces: `_MiniChip`, `_DetailKpi`, `_TypeMix`, `_AnalyticKpi`, `_IsolationStat`, `_TerritorialReport`, et les fonctions utilitaires `_typeColorForPin`, `_typeLabel`, `_locationSourceLabel`, `_locationSourceColor`, `_fmtDate`, `_fmtShort`, `_status`, `roadColor` si top-level, etc. — utilisés par tous les autres parts.

- [ ] **Step 1 : Créer le part** avec `part of '../admin_regional_view.dart';`, y déplacer le bloc `// ─── Widgets utilitaires locaux ───` (classes `_MiniChip`, `_DetailKpi`, `_TypeMix`, `_AnalyticKpi`) + le bloc `// ─── Fonctions utilitaires ───` + `_IsolationStat` + `_TerritorialReport`.
- [ ] **Step 2 : Déclarer** `part 'regional/regional_widgets.dart';` dans la tête.
- [ ] **Step 3 : Analyser** — Run: `cd epilote && flutter analyze lib/features/admin_groupe/screens/` — Expected: `No issues found!`
- [ ] **Step 4 : Compiler** — Run: `cd epilote && flutter build linux --debug` — Expected: succès.
- [ ] **Step 5 : Commit**
```bash
git add epilote/lib/features/admin_groupe/screens/
git commit -m "refactor(carte): extrait les widgets/utilitaires (part regional_widgets)"
```

### Task 1.3 : Extraire les barres (`regional_bars.dart`)

**Files:** Create `regional/regional_bars.dart`; Modify `admin_regional_view.dart`.
**Interfaces:** Produces `_ModeSwitch`, `_ModeBtn`, `_FilterBar`, `_LayerToggleBar`, `_PinColorSwitch`, `_TileBtn`, `_FilterChip`, `_MapTileSwitcher`, `_GlobalStats`, `_StatPill`, `_RegionalExportBar(+State)`.

- [ ] **Step 1 : Créer le part** (`part of`), y déplacer les classes ci-dessus (blocs « Bascule Carte/Tableau », « Filtres type », « Toggles de couches », `_PinColorSwitch`, « Sélecteur de fond », `_FilterChip`, « Statistiques globales », « Export PDF officiel »).
- [ ] **Step 2 : Déclarer** `part 'regional/regional_bars.dart';`.
- [ ] **Step 3 : Analyser** — `cd epilote && flutter analyze lib/features/admin_groupe/screens/` — Expected `No issues found!`.
- [ ] **Step 4 : Compiler** — `cd epilote && flutter build linux --debug`.
- [ ] **Step 5 : Commit** — `git add ... && git commit -m "refactor(carte): extrait les barres (part regional_bars)"`.

### Task 1.4 : Extraire la carte (`regional_map.dart`)

**Files:** Create `regional/regional_map.dart`; Modify `admin_regional_view.dart`.
**Interfaces:** Produces `_OsmMap(+State)`, `_MapDataStatus`, `_StreetViewFab`, `_GeoLoadingOverlay`, `_PlaceMarker`, `_DeptLabel`, `_MapLegend`.

- [ ] **Step 1 : Créer le part**, y déplacer `_OsmMap` + `_OsmMapState` (bloc « Carte OSM »), `_MapDataStatus`, `_StreetViewFab`, `_GeoLoadingOverlay`, `_PlaceMarker`, `_DeptLabel`, `_MapLegend`.
- [ ] **Step 2 : Déclarer** `part 'regional/regional_map.dart';`.
- [ ] **Step 3 : Analyser** — Expected `No issues found!`.
- [ ] **Step 4 : Compiler** — `flutter build linux --debug`.
- [ ] **Step 5 : Commit** — `-m "refactor(carte): extrait le widget carte (part regional_map)"`.

> Note : `regional_map.dart` sera ~700 l (`_OsmMap` est volumineux). Acceptable en transitoire ; la Task 3.3 en sortira la logique de tuiles satellite. Ne pas re-découper `_OsmMap` au milieu d'un widget.

### Task 1.5 : Extraire les panneaux dept/coverage/pipeline (`regional_panels.dart`)

**Files:** Create `regional/regional_panels.dart`; Modify head.
**Interfaces:** Produces `_PipelinePanel`, `_PipelineStat`, `_DeptCoverage`, `_CoveragePanel`, `_DeptDetail`.

- [ ] **Step 1 : Créer le part**, déplacer les blocs « Pipeline d'expansion », « Couverture territoriale » (`_DeptCoverage`, `_CoveragePanel`) et « Panneau détail département » (`_DeptDetail`).
- [ ] **Step 2 : Déclarer** `part 'regional/regional_panels.dart';`.
- [ ] **Step 3 : Analyser** — Expected `No issues found!`.
- [ ] **Step 4 : Compiler.**
- [ ] **Step 5 : Commit** — `-m "refactor(carte): extrait les panneaux dept/couverture (part regional_panels)"`.

### Task 1.6 : Extraire les panneaux école & projet

**Files:** Create `regional/regional_school_panel.dart` + `regional/regional_project_panel.dart`; Modify head.
**Interfaces:** Produces `_GpsSchoolDetailPanel`, `_CoordRow` (école) ; `_ProjectDetailPanel`, `_IconBtn`, `_StatusPipeline` (projet).

- [ ] **Step 1 : Créer `regional_school_panel.dart`** (`part of`), déplacer `_GpsSchoolDetailPanel` + `_CoordRow`.
- [ ] **Step 2 : Créer `regional_project_panel.dart`** (`part of`), déplacer `_ProjectDetailPanel`, `_IconBtn`, `_StatusPipeline`.
- [ ] **Step 3 : Déclarer** les deux `part '...';` dans la tête.
- [ ] **Step 4 : Analyser + compiler** — Expected `No issues found!`, build OK.
- [ ] **Step 5 : Commit** — `-m "refactor(carte): extrait les panneaux école/projet (parts dédiés)"`.

### Task 1.7 : Extraire analytics & dialogues

**Files:** Create `regional/regional_analytics.dart` + `regional/regional_dialogs.dart`; Modify head.
**Interfaces:** Produces `_RegionalAnalytics`, `_CreationsTimeline`, `_TerritorialAnalysis`, `_TerritorialKpi`, `_DataGaps` (analytics) ; `_ProjectFormDialog(+State)`, `_ProjSection`, `_PriorityChip`, `_SchoolGpsDialog(+State)` (dialogues).

- [ ] **Step 1 : Créer `regional_analytics.dart`**, déplacer les blocs « Analyse régionale », « Timeline des créations », « Analyse territoriale », `_DataGaps`.
- [ ] **Step 2 : Créer `regional_dialogs.dart`**, déplacer `_ProjectFormDialog`+State+`_ProjSection`+`_PriorityChip` et `_SchoolGpsDialog`+State.
- [ ] **Step 3 : Déclarer** les deux `part '...';`.
- [ ] **Step 4 : Analyser + compiler.**
- [ ] **Step 5 : Vérif GUI non-régression** : lancer l'app admin_groupe → Vue régionale ; ouvrir un dépt, une école GPS (si présente), un projet, la bascule Tableau, l'export PDF. Expected : identique à avant.
- [ ] **Step 6 : Commit** — `-m "refactor(carte): extrait analytics & dialogues (parts dédiés)"`.

### Task 1.8 : Vérifier la taille des fichiers

- [ ] **Step 1 : Mesurer**

Run: `cd epilote && wc -l lib/features/admin_groupe/screens/admin_regional_view.dart lib/features/admin_groupe/screens/regional/*.dart | sort -n`
Expected : chaque fichier ≤ 500 l, sauf `regional_map.dart` (transitoire, sera réduit en Task 3.3). Si un autre part dépasse 500, le re-scinder le long d'une couture (ex. `regional_bars.dart` → `regional_bars.dart` + `regional_export.dart`) et committer.

---

## Phase 2 — Fondation GPS

### Task 2.1 : Provider de géocodage offline (`school_geocoder_provider.dart`)

**Files:**
- Create: `epilote/lib/features/admin_groupe/providers/school_geocoder_provider.dart`
- Test: `epilote/test/school_geocoder_test.dart`
- Modify (si besoin d'exposer les places) : `epilote/lib/features/admin_groupe/providers/admin_geo_provider.dart`

**Interfaces:**
- Consumes: asset `assets/geo/congo_places.json` (format `[{name,lat,lng,type}]`), modèle `GeoPlace` (déjà défini dans `admin_geo_provider.dart`).
- Produces:
  - `String normalizePlaceName(String raw)` — minuscule, sans accents, trim, espaces compactés.
  - `LatLng? geocodeCity(List<GeoPlace> places, String? city)` — meilleure correspondance nom ; `null` si aucune.
  - `final congoPlacesProvider = FutureProvider<List<GeoPlace>>` — charge l'asset une fois.
  - `final schoolGeocoderProvider = Provider<LatLng? Function(String?)>` — closure prête à l'emploi.

- [ ] **Step 1 : Écrire les tests (échouants)**

Créer `epilote/test/school_geocoder_test.dart` :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:epilote/features/admin_groupe/providers/admin_geo_provider.dart';
import 'package:epilote/features/admin_groupe/providers/school_geocoder_provider.dart';

void main() {
  test('normalizePlaceName enlève accents/casse/espaces', () {
    expect(normalizePlaceName('  Ouésso '), 'ouesso');
    expect(normalizePlaceName('Pointe-Noire'), 'pointe-noire');
    expect(normalizePlaceName('BRAZZAVILLE'), 'brazzaville');
  });

  test('geocodeCity trouve une correspondance exacte (normalisée)', () {
    const places = [
      GeoPlace(name: 'Ouésso', coords: LatLng(1.61, 16.05), type: 'city'),
      GeoPlace(name: 'Brazzaville', coords: LatLng(-4.26, 15.27), type: 'city'),
    ];
    final r = geocodeCity(places, 'ouesso');
    expect(r, isNotNull);
    expect(r!.latitude, closeTo(1.61, 1e-6));
  });

  test('geocodeCity renvoie null si ville inconnue ou vide', () {
    const places = [GeoPlace(name: 'Brazzaville', coords: LatLng(-4.26, 15.27), type: 'city')];
    expect(geocodeCity(places, 'VilleInexistante'), isNull);
    expect(geocodeCity(places, null), isNull);
    expect(geocodeCity(places, ''), isNull);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd epilote && flutter test test/school_geocoder_test.dart`
Expected: FAIL — `school_geocoder_provider.dart` / symboles non définis.

- [ ] **Step 3 : Implémenter le provider**

Créer `epilote/lib/features/admin_groupe/providers/school_geocoder_provider.dart` :
```dart
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'admin_geo_provider.dart' show GeoPlace;

/// Normalise un nom de lieu pour comparaison : minuscules, sans accents,
/// espaces compactés/trim.
String normalizePlaceName(String raw) {
  const from = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
  const to   = 'aaaaaceeeeiiiinooooouuuuyy';
  var s = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i == -1 ? ch : to[i]);
  }
  return b.toString();
}

/// Meilleure correspondance ville → coordonnées, `null` si aucune.
LatLng? geocodeCity(List<GeoPlace> places, String? city) {
  if (city == null || city.trim().isEmpty) return null;
  final target = normalizePlaceName(city);
  for (final p in places) {
    if (normalizePlaceName(p.name) == target) return p.coords;
  }
  // Correspondance approchée : le nom saisi contient/est contenu.
  for (final p in places) {
    final n = normalizePlaceName(p.name);
    if (n.contains(target) || target.contains(n)) return p.coords;
  }
  return null;
}

/// Localités du Congo chargées depuis l'asset (offline, 1532 lieux).
final congoPlacesProvider = FutureProvider<List<GeoPlace>>((ref) async {
  final raw = await rootBundle.loadString('assets/geo/congo_places.json');
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list
      .map((m) => GeoPlace(
            name: m['name'] as String,
            coords: LatLng((m['lat'] as num).toDouble(),
                (m['lng'] as num).toDouble()),
            type: m['type'] as String? ?? 'locality',
          ))
      .toList();
});

/// Closure de géocodage prête à l'emploi (retourne null tant que l'asset charge).
final schoolGeocoderProvider = Provider<LatLng? Function(String?)>((ref) {
  final places = ref.watch(congoPlacesProvider).valueOrNull ?? const [];
  return (city) => geocodeCity(places, city);
});
```

Vérifier que `GeoPlace` a bien un constructeur `const GeoPlace({required name, required coords, required type})`. Sinon, adapter le test (le constructeur réel est dans `admin_geo_provider.dart:25`).

- [ ] **Step 4 : Lancer, vérifier le succès**

Run: `cd epilote && flutter test test/school_geocoder_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5 : Analyser**

Run: `cd epilote && flutter analyze lib/features/admin_groupe/providers/school_geocoder_provider.dart test/school_geocoder_test.dart`
Expected: `No issues found!`

- [ ] **Step 6 : Commit**

```bash
git add epilote/lib/features/admin_groupe/providers/school_geocoder_provider.dart epilote/test/school_geocoder_test.dart
git commit -m "feat(carte): géocodage offline des écoles via congo_places (schoolGeocoderProvider)"
```

### Task 2.2 : Backfill GPS des écoles sans position + service

**Files:**
- Modify: `epilote/lib/features/admin_groupe/providers/admin_regional_provider.dart` (ajout méthode `patchSchoolGps` existe déjà dans `AdminProjectService` ; on ajoute un helper de géocodage de masse).

**Interfaces:**
- Consumes: `schoolGeocoderProvider`, `AdminProjectService.patchSchoolGps` (déjà : `{schoolId, latitude, longitude, source}`).
- Produces: `Future<int> geocodeMissingSchoolGps(WidgetRef ref)` — géocode toutes les écoles sans GPS mais avec `city`, écrit `source='geocoded'`, retourne le nombre corrigé.

- [ ] **Step 1 : Écrire le test**

Créer `epilote/test/geocode_missing_test.dart` (unitaire pur sur la logique de sélection) :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:epilote/features/admin_groupe/providers/admin_regional_provider.dart';
import 'package:epilote/features/admin_groupe/providers/school_geocoder_provider.dart';

void main() {
  test('un pin sans GPS mais avec ville est éligible au géocodage', () {
    const pin = AdminSchoolPin(
      id: '1', name: 'EP Test', type: 'public', isActive: true,
      students: 0, city: 'Ouésso', department: 'Sangha',
    );
    expect(pin.hasGps, isFalse);
    expect(pin.city, isNotNull);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec/compilation** — Run: `cd epilote && flutter test test/geocode_missing_test.dart` — Expected: PASS si `AdminSchoolPin` déjà importable (ce test valide surtout le modèle). Sinon corriger l'import.

- [ ] **Step 3 : Implémenter le helper**

Dans `admin_regional_provider.dart`, ajouter après `AdminProjectService` :
```dart
/// Géocode en masse les écoles du groupe sans GPS mais avec une ville connue.
/// Retourne le nombre d'écoles corrigées. `source='geocoded'`.
final geocodeMissingProvider =
    Provider.autoDispose<Future<int> Function()>((ref) {
  return () async {
    final data = await ref.read(adminRegionalProvider.future);
    final geocode = ref.read(schoolGeocoderProvider);
    final svc = ref.read(adminProjectServiceProvider);
    var fixed = 0;
    // Les écoles sans GPS vivent dans les agrégats départementaux.
    final noGps = data.depts.expand((d) => d.schools).where((s) => !s.hasGps);
    for (final s in noGps) {
      final coords = geocode(s.city);
      if (coords == null) continue;
      await svc.patchSchoolGps(
        schoolId: s.id,
        latitude: coords.latitude,
        longitude: coords.longitude,
        source: 'geocoded',
      );
      fixed++;
    }
    if (fixed > 0) ref.invalidate(adminRegionalProvider);
    return fixed;
  };
});
```
Ajouter l'import `import 'school_geocoder_provider.dart';` en tête du fichier.

- [ ] **Step 4 : Bouton dans la barre carte** — Dans `regional_bars.dart` (part), ajouter au `_GlobalStats` ou près de l'export un bouton « Géolocaliser les écoles (N sans position) » qui appelle `ref.read(geocodeMissingProvider)()` et affiche un SnackBar « N écoles géolocalisées ». Le compteur N = `ref.watch(adminRegionalProvider).valueOrNull?.noGpsCount ?? 0` ; masquer le bouton si N==0.

- [ ] **Step 5 : Analyser** — Run: `cd epilote && flutter analyze lib/features/admin_groupe/` — Expected: `No issues found!`.

- [ ] **Step 6 : Vérif GUI + backfill réel** — Lancer admin_groupe → Vue régionale → cliquer « Géolocaliser les écoles ». Expected : les 19 écoles passent en pins individuels (source « Géocodé »). Vérifier en base : `select count(latitude) from schools where group_id=...` > 0.

- [ ] **Step 7 : Commit**
```bash
git add epilote/lib/features/admin_groupe/ epilote/test/geocode_missing_test.dart
git commit -m "feat(carte): backfill GPS des écoles sans position (géocodage congo_places)"
```

### Task 2.3 : Capturer le GPS à la création d'une école

**Files:**
- Modify: `epilote/lib/features/admin_groupe/screens/admin_schools_screen.dart` (formulaire « Nouvelle école »).

**Interfaces:**
- Consumes: `schoolGeocoderProvider`.
- Produces: à la création, si l'utilisateur ne pose pas de pin, on géocode le champ ville → `latitude/longitude/location_source='geocoded'` dans l'insert `schools`.

- [ ] **Step 1 : Localiser l'insert** — Run: `cd epilote && grep -n "insert\|from('schools')\|city\|latitude" lib/features/admin_groupe/screens/admin_schools_screen.dart | head`.
- [ ] **Step 2 : Implémenter** — dans la soumission du formulaire, après avoir lu `city`, calculer `final coords = ref.read(schoolGeocoderProvider)(city);` et, si non nul et qu'aucune coordonnée manuelle n'a été saisie, ajouter à l'objet inséré : `'latitude': coords.latitude, 'longitude': coords.longitude, 'location_source': 'geocoded', 'location_captured_at': DateTime.now().toIso8601String()`. Importer `school_geocoder_provider.dart`.
- [ ] **Step 3 : Analyser** — Expected `No issues found!`.
- [ ] **Step 4 : Vérif GUI** — Créer une école « EP Démo » ville « Dolisie » sans poser de pin. Expected : elle apparaît géolocalisée à Dolisie sur la carte (temps réel).
- [ ] **Step 5 : Commit** — `-m "feat(ecoles): géolocalisation auto à la création via la ville"`.

---

## Phase 3 — Vue école satellite

### Task 3.1 : Provider Esri Wayback (`wayback_provider.dart`)

**Files:**
- Create: `epilote/lib/features/admin_groupe/providers/wayback_provider.dart`
- Test: `epilote/test/wayback_provider_test.dart`

**Interfaces:**
- Consumes: `https://s3-us-west-2.amazonaws.com/config.maptiles.arcgis.com/waybackconfig.json` (HTTP GET).
- Produces:
  - `class WaybackRelease { final int releaseNum; final DateTime date; final String tileUrlTemplate; }`
  - `List<WaybackRelease> parseWaybackConfig(String json)` — trié par date décroissante.
  - `final waybackReleasesProvider = FutureProvider<List<WaybackRelease>>` (keepAlive) — liste vide si erreur réseau.

- [ ] **Step 1 : Écrire le test**

Créer `epilote/test/wayback_provider_test.dart` :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/wayback_provider.dart';

const _sample = '''
{
  "32246": {
    "itemTitle": "World Imagery (Wayback 2026-06-30)",
    "itemURL": "https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/32246/{level}/{row}/{col}"
  },
  "10842": {
    "itemTitle": "World Imagery (Wayback 2018-03-15)",
    "itemURL": "https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/10842/{level}/{row}/{col}"
  }
}
''';

void main() {
  test('parseWaybackConfig extrait, date et trie décroissant', () {
    final r = parseWaybackConfig(_sample);
    expect(r.length, 2);
    expect(r.first.date.year, 2026); // plus récent d'abord
    expect(r.first.releaseNum, 32246);
    expect(r.last.date.year, 2018);
  });

  test('tileUrlTemplate est converti au format flutter_map {z}/{y}/{x}', () {
    final r = parseWaybackConfig(_sample);
    expect(r.first.tileUrlTemplate, contains('{z}/{y}/{x}'));
    expect(r.first.tileUrlTemplate, isNot(contains('{level}')));
  });

  test('parse tolère un JSON vide/mauvais → liste vide', () {
    expect(parseWaybackConfig('{}'), isEmpty);
    expect(parseWaybackConfig('null'), isEmpty);
  });
}
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run: `cd epilote && flutter test test/wayback_provider_test.dart` — Expected: FAIL (symboles non définis).

- [ ] **Step 3 : Implémenter**

Créer `epilote/lib/features/admin_groupe/providers/wayback_provider.dart` :
```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const _kWaybackConfig =
    'https://s3-us-west-2.amazonaws.com/config.maptiles.arcgis.com/waybackconfig.json';

/// Une version datée de l'imagerie mondiale Esri (Wayback).
class WaybackRelease {
  const WaybackRelease({
    required this.releaseNum,
    required this.date,
    required this.tileUrlTemplate,
  });
  final int releaseNum;
  final DateTime date;
  final String tileUrlTemplate; // format flutter_map : .../{z}/{y}/{x}
}

final _dateRe = RegExp(r'(\d{4})-(\d{2})-(\d{2})');

/// Parse le waybackconfig.json → versions triées par date décroissante.
List<WaybackRelease> parseWaybackConfig(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) return const [];
  final out = <WaybackRelease>[];
  decoded.forEach((key, v) {
    if (v is! Map) return;
    final title = v['itemTitle'] as String? ?? '';
    final url = v['itemURL'] as String?;
    final m = _dateRe.firstMatch(title);
    final num = int.tryParse(key);
    if (url == null || m == null || num == null) return;
    // Esri WMTS : /tile/{release}/{level}/{row}/{col} → flutter_map {z}/{y}/{x}
    final tmpl = url
        .replaceAll('{level}', '{z}')
        .replaceAll('{row}', '{y}')
        .replaceAll('{col}', '{x}');
    out.add(WaybackRelease(
      releaseNum: num,
      date: DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      tileUrlTemplate: tmpl,
    ));
  });
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Versions datées Esri Wayback (mise en cache ; liste vide si hors-ligne).
final waybackReleasesProvider = FutureProvider<List<WaybackRelease>>((ref) async {
  ref.keepAlive();
  try {
    final resp = await http
        .get(Uri.parse(_kWaybackConfig))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return const [];
    return parseWaybackConfig(resp.body);
  } catch (_) {
    return const [];
  }
});
```

- [ ] **Step 4 : Lancer, vérifier le succès** — Run: `cd epilote && flutter test test/wayback_provider_test.dart` — Expected: PASS (3 tests).
- [ ] **Step 5 : Analyser** — Expected `No issues found!`.
- [ ] **Step 6 : Commit** — `git add ... && git commit -m "feat(carte): provider Esri Wayback (imagerie satellite datée, sans clé)"`.

### Task 3.2 : Widget Vue satellite (`school_satellite_view.dart`)

**Files:**
- Create: `epilote/lib/features/admin_groupe/widgets/school_satellite_view.dart`
- Test: `epilote/test/school_satellite_view_test.dart`

**Interfaces:**
- Consumes: `waybackReleasesProvider`, `flutter_map`, `latlong2`.
- Produces: `class SchoolSatelliteView extends ConsumerStatefulWidget { const SchoolSatelliteView({required LatLng center, String? title, double height}); }` — mini-carte satellite centrée + sélecteur de version datée + libellé date. Si `waybackReleasesProvider` vide → n'affiche que l'imagerie Esri courante (pas de frise).

- [ ] **Step 1 : Écrire le test widget**

Créer `epilote/test/school_satellite_view_test.dart` :
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:epilote/features/admin_groupe/widgets/school_satellite_view.dart';
import 'package:epilote/features/admin_groupe/providers/wayback_provider.dart';

void main() {
  testWidgets('affiche la carte satellite sans planter, frise si versions', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        waybackReleasesProvider.overrideWith((ref) async => const [
          WaybackRelease(releaseNum: 1, date: _d(2020), tileUrlTemplate: 'x/{z}/{y}/{x}'),
        ]),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SchoolSatelliteView(center: LatLng(-4.26, 15.27), title: 'EP Test'),
        ),
      ),
    ));
    await t.pump(); // laisse résoudre le provider
    expect(find.byType(SchoolSatelliteView), findsOneWidget);
  });
}

DateTime _d(int y) => DateTime(y, 1, 1);
```

- [ ] **Step 2 : Lancer, vérifier l'échec** — Run: `cd epilote && flutter test test/school_satellite_view_test.dart` — Expected: FAIL (widget non défini).

- [ ] **Step 3 : Implémenter le widget**

Créer `epilote/lib/features/admin_groupe/widgets/school_satellite_view.dart` :
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/admin_ui.dart' show kNavy, kBorder, kTextMuted, kTextPrimary;
import '../providers/wayback_provider.dart';

const _esriCurrent =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Vue satellite d'un point (école/projet) : imagerie Esri courante + frise
/// datée Esri Wayback (curseur). Aucune clé API. Dégrade proprement hors-ligne.
class SchoolSatelliteView extends ConsumerStatefulWidget {
  const SchoolSatelliteView({
    super.key,
    required this.center,
    this.title,
    this.height = 240,
  });
  final LatLng center;
  final String? title;
  final double height;

  @override
  ConsumerState<SchoolSatelliteView> createState() => _SchoolSatelliteViewState();
}

class _SchoolSatelliteViewState extends ConsumerState<SchoolSatelliteView> {
  int _releaseIndex = -1; // -1 = imagerie courante (non datée)

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(waybackReleasesProvider).valueOrNull ?? const [];
    final useWayback = _releaseIndex >= 0 && _releaseIndex < releases.length;
    final urlTemplate =
        useWayback ? releases[_releaseIndex].tileUrlTemplate : _esriCurrent;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: widget.height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: 17,
              minZoom: 12,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey(urlTemplate),
                urlTemplate: urlTemplate,
                userAgentPackageName: 'com.epilote.congo',
                maxNativeZoom: 19,
                maxZoom: 19,
              ),
              MarkerLayer(markers: [
                Marker(
                  point: widget.center,
                  width: 30, height: 30,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                ),
              ]),
            ],
          ),
        ),
      ),
      if (releases.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.history_rounded, size: 14, color: kTextMuted),
          const SizedBox(width: 6),
          Text(
            useWayback
                ? 'Imagerie du ${DateFormat('MMM yyyy', 'fr').format(releases[_releaseIndex].date)}'
                : 'Imagerie la plus récente',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
        ]),
        Slider(
          value: (_releaseIndex + 1).toDouble(),
          min: 0,
          max: releases.length.toDouble(),
          divisions: releases.length,
          activeColor: kNavy,
          label: useWayback
              ? DateFormat('yyyy-MM').format(releases[_releaseIndex].date)
              : 'Actuelle',
          onChanged: (v) => setState(() => _releaseIndex = v.round() - 1),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Frise datée indisponible (hors-ligne).',
              style: const TextStyle(fontSize: 10, color: kTextMuted)),
        ),
    ]);
  }
}
```
Vérifier les noms de couleurs importées depuis `admin_ui.dart` (adapter si `kNavy/kBorder/...` diffèrent).

- [ ] **Step 4 : Lancer, vérifier le succès** — Run: `cd epilote && flutter test test/school_satellite_view_test.dart` — Expected: PASS.
- [ ] **Step 5 : Analyser** — Expected `No issues found!`.
- [ ] **Step 6 : Commit** — `-m "feat(carte): widget Vue satellite datée (Esri + Wayback)"`.

### Task 3.3 : Injecter la Vue satellite dans le panneau école

**Files:**
- Modify: `epilote/lib/features/admin_groupe/screens/regional/regional_school_panel.dart` (part `_GpsSchoolDetailPanel`).

**Interfaces:**
- Consumes: `SchoolSatelliteView(center:, title:)`, `AdminSchoolPin.gpsCoords`.

- [ ] **Step 1 : Ajouter l'import dans le fichier tête** — Dans `admin_regional_view.dart`, ajouter `import '../widgets/school_satellite_view.dart';` (les parts héritent des imports de la tête).
- [ ] **Step 2 : Insérer le widget** — Dans `_GpsSchoolDetailPanel.build`, après le bloc « COORDONNÉES GPS » (le `Container` des coordonnées) et avant le bouton « Corriger la position », ajouter :
```dart
const SizedBox(height: 14),
const Text('VUE SATELLITE',
    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
        color: kTextMuted, letterSpacing: 0.8)),
const SizedBox(height: 8),
SchoolSatelliteView(center: school.gpsCoords!, title: school.name),
```
(`school.gpsCoords!` est non-null ici car ce panneau ne s'affiche que pour une école GPS.)

- [ ] **Step 3 : Analyser** — Expected `No issues found!`.
- [ ] **Step 4 : Vérif GUI** — admin_groupe → Vue régionale → cliquer une école géolocalisée → le panneau montre la carte satellite zoomée sur le bâtiment + le curseur de dates ; glisser le curseur change l'imagerie (dates différentes).
- [ ] **Step 5 : Commit** — `-m "feat(carte): Vue satellite datée dans le panneau détail d'école"`.

---

## Phase 4 — Projets de construction

### Task 4.1 : Vue satellite du site dans le panneau projet

**Files:**
- Modify: `epilote/lib/features/admin_groupe/screens/regional/regional_project_panel.dart` (`_ProjectDetailPanel`).

**Interfaces:**
- Consumes: `SchoolSatelliteView(center:)`, `AdminProjectPin.coords`.

- [ ] **Step 1 : Insérer** — Dans `_ProjectDetailPanel.build`, ajouter une section « VUE SATELLITE DU SITE » avec `SchoolSatelliteView(center: project.coords, title: project.name)` (voir le pattern exact de la Task 3.3). L'import du widget est déjà en tête (Task 3.3 Step 1).
- [ ] **Step 2 : Analyser** — Expected `No issues found!`.
- [ ] **Step 3 : Vérif GUI** — Ouvrir un projet → voir le terrain en satellite + frise datée (permet de voir le site avant/pendant construction).
- [ ] **Step 4 : Commit** — `-m "feat(carte): Vue satellite du site dans le panneau projet"`.

### Task 4.2 : Confirmer la création de projet par clic carte

**Files:**
- Read/verify: `regional/regional_map.dart` (`_OsmMap` — gestion `onTap`) + `regional/regional_dialogs.dart` (`_ProjectFormDialog(initialCoords)`).

**Interfaces:**
- Consumes: `AdminProjectService.createProject` (existant).

- [ ] **Step 1 : Vérifier le flux existant** — Run: `cd epilote && grep -n "onTap\|initialCoords\|_ProjectFormDialog\|createProject" lib/features/admin_groupe/screens/regional/regional_map.dart lib/features/admin_groupe/screens/regional/regional_dialogs.dart`.
- [ ] **Step 2 : Si un mode « ajouter un projet » par clic existe déjà**, le tester en GUI (clic sur la carte → dialogue pré-rempli aux coords). Sinon, ajouter un bouton flottant « + Projet ici » qui active un mode : le prochain clic carte ouvre `_ProjectFormDialog(initialCoords: point)`. Réutiliser `MapOptions.onTap`.
- [ ] **Step 3 : Analyser + Vérif GUI** — créer un projet par clic ; il apparaît en temps réel (0037).
- [ ] **Step 4 : Commit** — `-m "feat(carte): création de projet par clic sur la carte"`.

---

## Phase 5 — Audit complet de la page (« tout doit fonctionner parfaitement »)

### Task 5.1 : Passe d'audit fonctionnel GUI

**Files:** aucun (sauf correctifs découverts).

- [ ] **Step 1 : Checklist GUI exhaustive** (admin_groupe, `GDK_SCALE=1`) — cocher chaque item, capturer une anomalie s'il y en a :
  - [ ] Carte se charge, masque Congo visible, frontière tracée.
  - [ ] Bascule Carte/Tableau fonctionne dans les deux sens.
  - [ ] Fonds OSM / Satellite / Hybride commutent.
  - [ ] Couches Villages / Routes s'activent (Overpass, patienter 15-90 s).
  - [ ] Coloration pins Type / Charge / Occupation change les couleurs.
  - [ ] Filtres type d'établissement filtrent.
  - [ ] Clic bulle département → panneau détail dépt.
  - [ ] Clic école géolocalisée → panneau + **Vue satellite datée**.
  - [ ] « Corriger la position » ouvre le dialogue GPS et sauvegarde.
  - [ ] « Géolocaliser les écoles » backfill (si écoles sans GPS).
  - [ ] Pipeline projets : créer / modifier / supprimer / clic-carte.
  - [ ] Clic projet → panneau + **Vue satellite du site**.
  - [ ] Analytique (analyse régionale, timeline créations, analyse territoriale) s'affiche sans NaN/overflow.
  - [ ] Panneau « couches disponibles vs manquantes » cohérent.
  - [ ] Export PDF officiel génère le document.
  - [ ] **Temps réel** : modifier une école dans une 2ᵉ session → la carte bouge < 3 s.
  - [ ] Vue rue Mapillary (bonus) : bouton présent, ouvre le viewer.
- [ ] **Step 2 : Runtime errors** — via DTD `get_runtime_errors` après chaque interaction : Expected `No runtime errors found`.
- [ ] **Step 3 : Corriger** toute anomalie trouvée (un commit par correctif, message `fix(carte): ...`).

### Task 5.2 : Vérification finale du dépôt

- [ ] **Step 1 : Analyse globale** — Run: `cd epilote && flutter analyze` — Expected: `No issues found!`.
- [ ] **Step 2 : Tests** — Run: `cd epilote && flutter test` — Expected: tous verts.
- [ ] **Step 3 : Taille des fichiers** — Run: `cd epilote && wc -l lib/features/admin_groupe/screens/admin_regional_view.dart lib/features/admin_groupe/screens/regional/*.dart lib/features/admin_groupe/widgets/school_satellite_view.dart lib/features/admin_groupe/providers/wayback_provider.dart lib/features/admin_groupe/providers/school_geocoder_provider.dart` — Expected: chaque fichier ≤ 500 l.
- [ ] **Step 4 : Mémoire projet** — mettre à jour l'index mémoire (`MEMORY.md` + fiche `regional-satellite-cockpit.md`) : temps réel 0037, vue satellite Wayback, géocodage congo_places, découpe.
- [ ] **Step 5 : Commit final** — `-m "chore(carte): audit complet Vue régionale + mémoire projet"`.

---

## Self-Review (couverture spec)

- **§6.1 Temps réel** → Phase 0 (livré + vérif). ✅
- **§6.2 Fondation GPS** → Tasks 2.1 (géocodeur), 2.2 (backfill), 2.3 (création). ✅
- **§6.3 Vue école satellite** → Tasks 3.1 (Wayback), 3.2 (widget), 3.3 (injection école). ✅
- **§6.4 Projets** → Tasks 4.1 (satellite site), 4.2 (clic carte). ✅
- **§6.5 Personnel** → hors périmètre (documenté), pas de task — conforme à la spec. ✅
- **§6.6 Découpe** → Phase 1 (Tasks 1.1–1.8). ✅
- **§7 Données** → aucune nouvelle table/bucket ; 0037 livré. ✅
- **§8 Erreurs/dégradation** → gérés dans widgets (Wayback vide, sans GPS) + Task 5.1. ✅
- **§9 Tests** → tests unitaires (2.1, 3.1), widget (3.2), GUI (0, 2.2, 2.3, 3.3, 4.x, 5.1). ✅
- **Précision utilisateur « toute la page parfaite »** → Phase 5 (audit exhaustif). ✅

Cohérence des types : `WaybackRelease{releaseNum,date,tileUrlTemplate}`, `SchoolSatelliteView({center,title,height})`, `geocodeCity(places,city)`, `schoolGeocoderProvider → LatLng? Function(String?)`, `geocodeMissingProvider → Future<int> Function()` — utilisés de façon identique partout.
