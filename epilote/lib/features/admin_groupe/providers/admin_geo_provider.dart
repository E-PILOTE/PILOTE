import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_logger.dart';

// ─── Données géographiques — République du Congo ──────────────────────────────
//
// Stratégie « assets d'abord » :
//   1. Les assets embarqués (snapshot OSM 2026-06) sont chargés IMMÉDIATEMENT
//      (~50 ms) → le masque géographique est présent dès la 1ère frame de la carte.
//   2. En arrière-plan, Overpass / geoBoundaries.org fournissent les données live ;
//      l'état est mis à jour silencieusement (pas de spinner de rechargement).
//
// En cas d'échec réseau : les assets restent définitivement → jamais de carte vide.

const _kAgent    = 'E-PILOTE-Congo/1.0 (gestion-scolaire; libemessenger@gmail.com)';
const _kOverpass = 'https://overpass-api.de/api/interpreter';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.coords,
    required this.type,
  });
  final String name;
  final LatLng coords;
  final String type; // city | town | village | hamlet | isolated_dwelling | locality
}

class CongoRoad {
  const CongoRoad({
    required this.name,
    required this.type,
    required this.points,
  });
  final String name;
  final String type; // trunk | primary | secondary | tertiary
  final List<LatLng> points;
}

class GeoDepartment {
  const GeoDepartment({
    required this.name,
    required this.centroid,
    required this.outline,
  });
  final String name;
  final LatLng centroid;
  final List<LatLng> outline;
}

// ─── Parsing ─────────────────────────────────────────────────────────────────

// Format asset : [[lat, lng], ...]
List<LatLng> _ringFromAsset(List raw) => raw
    .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
    .toList(growable: false);

// Format GeoJSON : [[lng, lat], ...]
List<LatLng> _ringFromGeoJson(List coords) => coords
    .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
    .toList(growable: false);

// ─── Chargement assets (snapshot OSM embarqué) ───────────────────────────────

Future<List<LatLng>> _boundaryFromAsset() async {
  final raw = await rootBundle.loadString('assets/geo/congo_adm0.json');
  final m = jsonDecode(raw) as Map<String, dynamic>;
  return _ringFromAsset(m['outer'] as List);
}

Future<List<GeoDepartment>> _deptsFromAsset() async {
  final raw = await rootBundle.loadString('assets/geo/congo_adm1.json');
  final list = jsonDecode(raw) as List;
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    final c = m['centroid'] as List;
    return GeoDepartment(
      name: m['name'] as String,
      centroid: LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()),
      outline: _ringFromAsset(m['outer'] as List),
    );
  }).toList(growable: false);
}

Future<List<GeoPlace>> _placesFromAsset() async {
  final raw = await rootBundle.loadString('assets/geo/congo_places.json');
  final list = jsonDecode(raw) as List;
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    return GeoPlace(
      name: m['name'] as String,
      coords: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
      type: m['type'] as String,
    );
  }).toList(growable: false);
}

// ─── Fetch live geoBoundaries (frontière nationale ADM0) ─────────────────────

Future<List<LatLng>> _fetchLiveBoundary() async {
  final meta = await http
      .get(
        Uri.parse(
            'https://www.geoboundaries.org/api/current/gbOpen/COG/ADM0/'),
        headers: {'User-Agent': _kAgent},
      )
      .timeout(const Duration(seconds: 15));
  if (meta.statusCode != 200) {
    throw Exception('geoBoundaries meta ${meta.statusCode}');
  }
  final geoUrl = (jsonDecode(meta.body)
      as Map<String, dynamic>)['simplifiedGeometryGeoJSON'] as String;

  final resp = await http
      .get(Uri.parse(geoUrl), headers: {'User-Agent': _kAgent})
      .timeout(const Duration(seconds: 30));
  if (resp.statusCode != 200) throw Exception('GeoJSON ${resp.statusCode}');

  final fc = jsonDecode(resp.body) as Map<String, dynamic>;
  final geom =
      (fc['features'] as List).first['geometry'] as Map<String, dynamic>;
  final type = geom['type'] as String;

  final List outerRing;
  if (type == 'MultiPolygon') {
    final polys = geom['coordinates'] as List;
    outerRing = (polys.reduce((a, b) =>
            (a as List)[0].length > (b as List)[0].length ? a : b)
        as List)[0] as List;
  } else {
    outerRing = (geom['coordinates'] as List)[0] as List;
  }
  return _ringFromGeoJson(outerRing);
}

// ─── Fetch live Overpass (15 départements ADM1 — réforme oct. 2024) ──────────

Future<List<GeoDepartment>> _fetchLiveDepts() async {
  const query = '[out:json][timeout:120];\n'
      'relation(192794);map_to_area->.cg;\n'
      'relation(area.cg)["boundary"="administrative"]["admin_level"="4"];\n'
      'out geom;';

  final resp = await http
      .post(
        Uri.parse(_kOverpass),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _kAgent,
        },
        body: {'data': query},
      )
      .timeout(const Duration(seconds: 125));
  if (resp.statusCode != 200) throw Exception('Overpass ${resp.statusCode}');

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final elements = json['elements'] as List? ?? [];

  final result = <GeoDepartment>[];
  for (final e in elements) {
    final m = e as Map<String, dynamic>;
    if (m['type'] != 'relation') continue;

    final tags = m['tags'] as Map? ?? {};
    final iso = tags['ISO3166-2'] as String? ?? '';
    if (!iso.startsWith('CG-') && iso.isNotEmpty) continue;

    final name = tags['name'] as String? ?? tags['name:fr'] as String? ?? iso;
    final members = m['members'] as List? ?? [];

    final outerWays = <List<LatLng>>[];
    for (final mem in members) {
      final mm = mem as Map<String, dynamic>;
      if (mm['role'] != 'outer') continue;
      final geom = mm['geometry'] as List? ?? [];
      final pts = geom.map((g) {
        final gm = g as Map<String, dynamic>;
        return LatLng(
          (gm['lat'] as num).toDouble(),
          (gm['lon'] as num).toDouble(),
        );
      }).toList();
      if (pts.isNotEmpty) outerWays.add(pts);
    }

    final outline = _chainWays(outerWays);
    if (outline.length < 3) continue;

    result.add(GeoDepartment(
      name: name,
      centroid: _polygonCentroid(outline),
      outline: outline,
    ));
  }

  if (result.isEmpty) throw Exception('aucun département CG retourné');
  return result..sort((a, b) => a.name.compareTo(b.name));
}

// ─── Fetch live Overpass (localités) ─────────────────────────────────────────

Future<List<GeoPlace>> _fetchLivePlaces() async {
  // Inclut tous les types jusqu'au hameau/localité pour couverture maximale Congo
  const query = '[out:json][timeout:90];\n'
      'relation(192794);map_to_area->.cg;\n'
      r'node(area.cg)["place"~"^(city|town|village|hamlet|isolated_dwelling|locality)$"]["name"];'
      '\nout body;';

  final resp = await http
      .post(
        Uri.parse(_kOverpass),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _kAgent,
        },
        body: {'data': query},
      )
      .timeout(const Duration(seconds: 95));
  if (resp.statusCode != 200) throw Exception('Overpass ${resp.statusCode}');

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final elements = json['elements'] as List? ?? [];

  return elements.map((e) {
    final m = e as Map<String, dynamic>;
    final tags = m['tags'] as Map? ?? {};
    return GeoPlace(
      name: tags['name'] as String? ?? '',
      coords: LatLng(
        (m['lat'] as num).toDouble(),
        (m['lon'] as num).toDouble(),
      ),
      type: tags['place'] as String? ?? 'village',
    );
  }).where((p) => p.name.isNotEmpty).toList(growable: false);
}

// ─── Notifiers (assets d'abord → live en arrière-plan) ───────────────────────

class _BoundaryNotifier
    extends AutoDisposeAsyncNotifier<List<LatLng>> {
  @override
  Future<List<LatLng>> build() async {
    ref.keepAlive();
    // Chargement immédiat depuis les assets embarqués → masque présent dès la 1ère frame
    final initial = await _boundaryFromAsset();
    // Fetch live en arrière-plan (met à jour silencieusement quand prêt)
    Future(_refreshLive);
    return initial;
  }

  Future<void> _refreshLive() async {
    try {
      final live = await _fetchLiveBoundary();
      state = AsyncData(live);
    } catch (e, st) {
      // Pas de rechargement visible : l'asset embarqué reste affiché.
      // Mais on trace l'échec — sinon une frontière périmée passerait inaperçue.
      appLogger.w('Frontière live (geoBoundaries) indisponible — '
          'asset embarqué conservé', error: e, stackTrace: st);
    }
  }
}

class _DeptsNotifier
    extends AutoDisposeAsyncNotifier<List<GeoDepartment>> {
  @override
  Future<List<GeoDepartment>> build() async {
    ref.keepAlive();
    final initial = await _deptsFromAsset();
    Future(_refreshLive);
    return initial;
  }

  Future<void> _refreshLive() async {
    try {
      final live = await _fetchLiveDepts();
      final current = state.valueOrNull ?? const <GeoDepartment>[];
      // Donnée régalienne : ne jamais régresser sous la couverture officielle
      // embarquée. OSM est crowdsourcé et peut être en retard sur la réforme
      // d'octobre 2024 (15 départements) → on n'accepte le live que s'il couvre
      // au moins autant de départements que l'asset vérifié.
      if (live.length >= current.length) {
        state = AsyncData(live);
      } else {
        appLogger.w('Départements live OSM (${live.length}) < asset officiel '
            '(${current.length}) — live rejeté, asset 15 dépts conservé');
      }
    } catch (e, st) {
      appLogger.w('Départements live (Overpass) indisponibles — '
          'asset officiel conservé', error: e, stackTrace: st);
    }
  }
}

class _PlacesNotifier
    extends AutoDisposeAsyncNotifier<List<GeoPlace>> {
  @override
  Future<List<GeoPlace>> build() async {
    ref.keepAlive();
    final initial = await _placesFromAsset();
    Future(_refreshLive);
    return initial;
  }

  Future<void> _refreshLive() async {
    try {
      final live = await _fetchLivePlaces();
      state = AsyncData(live);
    } catch (e, st) {
      appLogger.w('Localités live (Overpass) indisponibles — '
          'asset embarqué conservé', error: e, stackTrace: st);
    }
  }
}

// ─── Fetch live Overpass (réseau routier — trunk/primary/secondary/tertiary) ──
// Routes nationales et régionales du Congo, disponibles dans OSM.
// Seule la couche affichage est ici ; les isochrones nécessitent un serveur OSRM.

Future<List<CongoRoad>> _fetchLiveRoads() async {
  const query = '[out:json][timeout:120];\n'
      'relation(192794);map_to_area->.cg;\n'
      'way(area.cg)["highway"~"^(trunk|primary|secondary|tertiary)\$"];\n'
      'out geom;';

  final resp = await http
      .post(
        Uri.parse(_kOverpass),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _kAgent,
        },
        body: {'data': query},
      )
      .timeout(const Duration(seconds: 125));
  if (resp.statusCode != 200) throw Exception('Overpass roads ${resp.statusCode}');

  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final elements = json['elements'] as List? ?? [];

  final roads = <CongoRoad>[];
  for (final e in elements) {
    final m = e as Map<String, dynamic>;
    if (m['type'] != 'way') continue;
    final tags = m['tags'] as Map? ?? {};
    final type = tags['highway'] as String? ?? 'secondary';
    final name = tags['name'] as String? ??
        tags['ref'] as String? ??
        tags['int_ref'] as String? ??
        '';
    final geom = m['geometry'] as List? ?? [];
    final pts = geom.map((g) {
      final gm = g as Map<String, dynamic>;
      return LatLng(
          (gm['lat'] as num).toDouble(), (gm['lon'] as num).toDouble());
    }).toList();
    if (pts.length >= 2) roads.add(CongoRoad(name: name, type: type, points: pts));
  }
  if (roads.isEmpty) throw Exception('aucune route retournée');
  return roads;
}

class _RoadsNotifier extends AutoDisposeAsyncNotifier<List<CongoRoad>> {
  @override
  Future<List<CongoRoad>> build() async {
    ref.keepAlive();
    // Pas d'asset embarqué pour les routes (trop lourd) — débute vide
    // puis charge en arrière-plan.
    Future(_refreshLive);
    return const [];
  }

  Future<void> _refreshLive() async {
    try {
      final live = await _fetchLiveRoads();
      state = AsyncData(live);
    } catch (e, st) {
      // Pas d'asset routier embarqué → en cas d'échec la couche reste vide.
      appLogger.w('Réseau routier live (Overpass) indisponible — '
          'couche routes vide', error: e, stackTrace: st);
    }
  }
}

final congoRoadsProvider =
    AsyncNotifierProvider.autoDispose<_RoadsNotifier, List<CongoRoad>>(
  _RoadsNotifier.new,
);

// ─── Providers publics ────────────────────────────────────────────────────────

final congoBoundaryProvider =
    AsyncNotifierProvider.autoDispose<_BoundaryNotifier, List<LatLng>>(
  _BoundaryNotifier.new,
);

final congoDepartmentsProvider =
    AsyncNotifierProvider.autoDispose<_DeptsNotifier, List<GeoDepartment>>(
  _DeptsNotifier.new,
);

final congoPlacesProvider =
    AsyncNotifierProvider.autoDispose<_PlacesNotifier, List<GeoPlace>>(
  _PlacesNotifier.new,
);

// ─── Utilitaire : chaînage des ways OSM en anneau fermé ──────────────────────

List<LatLng> _chainWays(List<List<LatLng>> ways) {
  if (ways.isEmpty) return [];
  if (ways.length == 1) return ways.first;

  final result = <LatLng>[...ways.first];
  final remaining = ways.skip(1).map(List<LatLng>.from).toList();

  while (remaining.isNotEmpty) {
    final last = result.last;
    int bestIdx = -1;
    bool reverse = false;

    for (int i = 0; i < remaining.length; i++) {
      if (_close(last, remaining[i].first)) {
        bestIdx = i;
        reverse = false;
        break;
      }
      if (_close(last, remaining[i].last)) {
        bestIdx = i;
        reverse = true;
        break;
      }
    }

    if (bestIdx < 0) break;
    var way = remaining.removeAt(bestIdx);
    if (reverse) way = way.reversed.toList();
    result.addAll(way.skip(1));
  }
  return result;
}

bool _close(LatLng a, LatLng b) =>
    (a.latitude - b.latitude).abs() < 0.001 &&
    (a.longitude - b.longitude).abs() < 0.001;

// ─── Utilitaire : centroïde géométrique (shoelace formula) ───────────────────

LatLng _polygonCentroid(List<LatLng> ring) {
  double A = 0, cx = 0, cy = 0;
  for (int i = 0; i < ring.length - 1; i++) {
    final x0 = ring[i].longitude,     y0 = ring[i].latitude;
    final x1 = ring[i + 1].longitude, y1 = ring[i + 1].latitude;
    final cross = x0 * y1 - x1 * y0;
    A  += cross;
    cx += (x0 + x1) * cross;
    cy += (y0 + y1) * cross;
  }
  A *= 0.5;
  if (A.abs() < 1e-12) {
    return LatLng(
      ring.map((p) => p.latitude).reduce((a, b) => a + b) / ring.length,
      ring.map((p) => p.longitude).reduce((a, b) => a + b) / ring.length,
    );
  }
  return LatLng(cy / (6 * A), cx / (6 * A));
}
