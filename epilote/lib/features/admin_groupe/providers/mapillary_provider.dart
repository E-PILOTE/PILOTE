import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─── Vue rue Mapillary — imagerie au niveau du sol ───────────────────────────
//
// Mapillary (Meta) = photos de rue participatives. Couverture au Congo limitée
// aux axes des grandes villes (Brazzaville, Pointe-Noire). Les images NE sont
// PAS en temps réel : ce sont des clichés d'archive datés.
//
// Le token ci-dessous est un *client token* public (lecture seule des données
// publiques) — c'est l'usage prévu côté client. Le *client secret* ne doit
// JAMAIS être embarqué dans l'app.
const _kMapillaryToken =
    'MLY|27757907297126048|f97c9e47e31e5c6a9a1e9b1338bf39a1';

const _kGraph = 'https://graph.mapillary.com/images';

class MapillaryImage {
  const MapillaryImage({
    required this.id,
    required this.thumbUrl,
    required this.coords,
    this.capturedAt,
  });
  final String id;
  final String thumbUrl;
  final LatLng coords;
  final DateTime? capturedAt;
}

/// Images au sol les plus proches d'un point, triées par distance croissante.
/// Clé = coordonnées arrondies (cache par zone d'environ 100 m).
final mapillaryNearbyProvider = FutureProvider.autoDispose
    .family<List<MapillaryImage>, ({double lat, double lng})>((ref, p) async {
  ref.keepAlive();

  // bbox ≈ 1,3 km de côté : assez large pour capter un axe, assez petit pour
  // ne pas déclencher l'erreur « reduce the amount of data » de l'API.
  const d = 0.012;
  final bbox =
      '${p.lng - d},${p.lat - d},${p.lng + d},${p.lat + d}';

  final uri = Uri.parse(_kGraph).replace(queryParameters: {
    'access_token': _kMapillaryToken,
    'fields': 'id,thumb_1024_url,computed_geometry,captured_at',
    'bbox': bbox,
    'limit': '30',
  });

  final resp = await http.get(uri).timeout(const Duration(seconds: 20));
  if (resp.statusCode != 200) {
    throw Exception('Mapillary ${resp.statusCode}');
  }

  final data =
      (jsonDecode(resp.body) as Map<String, dynamic>)['data'] as List? ?? [];

  final center = LatLng(p.lat, p.lng);
  const distance = Distance();
  final images = <MapillaryImage>[];

  for (final e in data) {
    final m = e as Map<String, dynamic>;
    final geom = m['computed_geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List?;
    final thumb = m['thumb_1024_url'] as String?;
    if (coords == null || thumb == null) continue;

    final cap = m['captured_at'];
    images.add(MapillaryImage(
      id: m['id'] as String,
      thumbUrl: thumb,
      coords: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      capturedAt: cap is num
          ? DateTime.fromMillisecondsSinceEpoch(cap.toInt())
          : null,
    ));
  }

  images.sort(
      (a, b) => distance(center, a.coords).compareTo(distance(center, b.coords)));
  return images;
});
