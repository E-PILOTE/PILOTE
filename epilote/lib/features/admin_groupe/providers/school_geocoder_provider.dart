import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'admin_geo_provider.dart'
    show GeoPlace, congoPlacesProvider, congoDepartmentsProvider;

// Réutilise le provider canonique des localités (asset immédiat + enrichissement
// Overpass en arrière-plan). On le ré-exporte pour les consommateurs du géocodage.
export 'admin_geo_provider.dart' show congoPlacesProvider, GeoPlace;

// ─── Géocodage offline des écoles ───────────────────────────────────────────
// Résout `schools.city` → coordonnées à partir de l'asset embarqué
// `congo_places.json` (1532 localités). 100 % local, aucun service externe.
// Sert à caler les écoles sans GPS et à géolocaliser à la création.

/// Normalise un nom de lieu pour comparaison : minuscules, sans accents,
/// espaces compactés + trim.
String normalizePlaceName(String raw) {
  const from = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaceeeeiiiinooooouuuuyy';
  final lower = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i == -1 ? ch : to[i]);
  }
  return b.toString();
}

/// Meilleure correspondance ville → coordonnées ; `null` si aucune.
/// D'abord une égalité normalisée, puis une correspondance approchée
/// (l'un contient l'autre) pour tolérer « Pointe-Noire » vs « Pointe Noire ».
LatLng? geocodeCity(List<GeoPlace> places, String? city) {
  if (city == null || city.trim().isEmpty) return null;
  final target = normalizePlaceName(city);
  if (target.isEmpty) return null;
  for (final p in places) {
    if (normalizePlaceName(p.name) == target) return p.coords;
  }
  for (final p in places) {
    final n = normalizePlaceName(p.name);
    if (n.length >= 4 && (n.contains(target) || target.contains(n))) {
      return p.coords;
    }
  }
  return null;
}

/// Closure de géocodage prête à l'emploi. Renvoie `null` tant que l'asset
/// charge (liste vide) ou si la ville est introuvable.
final schoolGeocoderProvider = Provider<LatLng? Function(String?)>((ref) {
  final places = ref.watch(congoPlacesProvider).valueOrNull ?? const [];
  return (city) => geocodeCity(places, city);
});

// ─── Localités par département (cascade de saisie) ───────────────────────────
// `congo_places.json` ne porte pas le département → on rattache chaque localité
// par POINT-DANS-POLYGONE sur les contours des 15 départements (asset ADM1).

/// Ray casting : le point est-il à l'intérieur de l'anneau ?
bool pointInRing(LatLng p, List<LatLng> ring) {
  var inside = false;
  final n = ring.length;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final yi = ring[i].latitude, xi = ring[i].longitude;
    final yj = ring[j].latitude, xj = ring[j].longitude;
    final crosses = (yi > p.latitude) != (yj > p.latitude) &&
        p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

int _placeRank(String t) => switch (t) {
      'city' => 0,
      'town' => 1,
      'village' => 2,
      'locality' => 3,
      'suburb' || 'neighbourhood' || 'quarter' => 4,
      _ => 5,
    };

/// Localités du département donné (triées ville→bourg→village, puis alpha).
/// `dept` nul/vide → toutes les localités. Repli sur toutes si le contour du
/// département n'est pas encore chargé (fail-soft, jamais de liste vide à tort).
final localitiesInDeptProvider =
    Provider.autoDispose.family<List<GeoPlace>, String?>((ref, dept) {
  final places = ref.watch(congoPlacesProvider).valueOrNull ?? const <GeoPlace>[];
  if (places.isEmpty) return const [];

  var result = places;
  if (dept != null && dept.trim().isNotEmpty) {
    final depts = ref.watch(congoDepartmentsProvider).valueOrNull ?? const [];
    final target = normalizePlaceName(dept);
    List<LatLng>? poly;
    for (final d in depts) {
      final dn = normalizePlaceName(d.name);
      if (dn == target || dn.contains(target) || target.contains(dn)) {
        poly = d.outline;
        break;
      }
    }
    if (poly != null && poly.length >= 3) {
      final filtered = places.where((p) => pointInRing(p.coords, poly!)).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
  }

  final sorted = [...result]..sort((a, b) {
    final r = _placeRank(a.type).compareTo(_placeRank(b.type));
    return r != 0 ? r : a.name.compareTo(b.name);
  });
  return sorted;
});
