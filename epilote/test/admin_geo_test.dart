import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/admin_groupe/providers/admin_geo_provider.dart';

// Vérifie que les données géographiques embarquées (assets/geo) sont chargées
// et géographiquement cohérentes avec la République du Congo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  // Emprise réelle du Congo (avec petite marge)
  bool inCongo(double lat, double lng) =>
      lat >= -5.3 && lat <= 4.0 && lng >= 10.9 && lng <= 19.0;

  test('Frontière nationale : anneau fermé, dans l\'emprise du Congo', () async {
    final ring = await container.read(congoBoundaryProvider.future);
    expect(ring.length, greaterThan(100));
    expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-6));
    expect(ring.first.longitude, closeTo(ring.last.longitude, 1e-6));
    for (final p in ring) {
      expect(inCongo(p.latitude, p.longitude), isTrue,
          reason: 'point hors Congo: $p');
    }
  });

  test('15 départements avec noms attendus et contours non vides', () async {
    // Réforme du 8 octobre 2024 : 12 → 15 départements (ajout de Congo-Oubangui,
    // Djoué-Léfini, Nkéni-Alima). L'asset congo_adm1.json est à jour.
    final depts = await container.read(congoDepartmentsProvider.future);
    expect(depts.length, 15);
    final names = depts.map((d) => d.name).toSet();
    for (final expected in const [
      'Bouenza', 'Brazzaville', 'Cuvette', 'Cuvette-Ouest', 'Kouilou',
      'Likouala', 'Lékoumou', 'Niari', 'Plateaux', 'Pointe-Noire',
      'Pool', 'Sangha', 'Congo-Oubangui', 'Djoué-Léfini', 'Nkéni-Alima',
    ]) {
      expect(names.contains(expected), isTrue, reason: 'manque: $expected');
    }
    for (final d in depts) {
      expect(d.outline.length, greaterThanOrEqualTo(3));
      expect(inCongo(d.centroid.latitude, d.centroid.longitude), isTrue,
          reason: 'centroïde hors Congo: ${d.name}');
    }
  });

  test('Localités : >300 lieux, types valides, dans l\'emprise', () async {
    final places = await container.read(congoPlacesProvider.future);
    expect(places.length, greaterThan(300));
    // Types OSM place=* réellement présents dans l'asset (villes → hameaux).
    const validTypes = {
      'city', 'town', 'village', 'hamlet', 'suburb', 'quarter',
      'neighbourhood', 'isolated_dwelling', 'locality',
    };
    for (final p in places) {
      expect(validTypes.contains(p.type), isTrue, reason: 'type: ${p.type}');
      expect(inCongo(p.coords.latitude, p.coords.longitude), isTrue,
          reason: 'lieu hors Congo: ${p.name}');
    }
    // Les grandes villes réelles doivent être présentes
    final names = places.map((p) => p.name).toSet();
    expect(names.contains('Brazzaville'), isTrue);
    expect(names.contains('Pointe-Noire'), isTrue);
  });
}
