// Marqué `golden` : ces tests comparent un RENDU à une image de référence.
// L'image a été produite sous Linux ; le même widget sortirait avec un
// antialiasing et un hinting de police différents sous Windows, et le test
// échouerait sans qu'aucun défaut n'existe. La CI Windows les écarte donc,
// la CI Linux — qui fait foi — les exécute.
@Tags(['golden'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Preuve visuelle du masque géographique « Congo seul » : rend le polygone
// monde + le « trou » (frontière nationale réelle) au-dessus d'un fond coloré,
// sans tuiles réseau. Le rendu attendu : le Congo apparaît en clair (fond
// visible) tandis que tout l'extérieur est assombri, avec la frontière tracée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Masque Congo — rendu hors-ligne', (tester) async {
    final raw = await rootBundle.loadString('assets/geo/congo_adm0.json');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final ring = (m['outer'] as List)
        .map((p) =>
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();

    const worldRect = [
      LatLng(-85, -180),
      LatLng(-85, 180),
      LatLng(85, 180),
      LatLng(85, -180),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 520,
            height: 520,
            child: FlutterMap(
              options: MapOptions(
                // Fond vif pour visualiser l'effet du masque (zones non-Congo
                // assombries, Congo laissé en clair).
                backgroundColor: const Color(0xFF2E7D32),
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(
                    const LatLng(-5.2, 11.0),
                    const LatLng(3.8, 18.8),
                  ),
                  padding: const EdgeInsets.all(20),
                ),
              ),
              children: [
                PolygonLayer(polygons: [
                  Polygon(
                    points: worldRect,
                    holePointsList: [ring],
                    color: const Color(0xFFEDF1F6).withValues(alpha: 0.86),
                  ),
                  Polygon(
                    points: ring,
                    borderStrokeWidth: 2.2,
                    borderColor: const Color(0xFF1E3A5F),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FlutterMap),
      matchesGoldenFile('goldens/congo_mask.png'),
    );
  });
}
