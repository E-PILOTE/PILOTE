import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'admin_geo_provider.dart' show GeoPlace, congoPlacesProvider;

// Réutilise le provider canonique des localités (asset immédiat + enrichissement
// Overpass en arrière-plan). On le ré-exporte pour les consommateurs du géocodage.
export 'admin_geo_provider.dart' show congoPlacesProvider;

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
