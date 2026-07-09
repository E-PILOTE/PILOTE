import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:epilote/features/admin_groupe/widgets/school_satellite_view.dart';
import 'package:epilote/features/admin_groupe/providers/wayback_provider.dart';

void main() {
  testWidgets('affiche la vue satellite + frise si versions dispo', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        waybackReleasesProvider.overrideWith((ref) async => [
              WaybackRelease(
                  releaseNum: 1,
                  date: DateTime(2020, 1, 1),
                  tileUrlTemplate: 'https://x/{z}/{y}/{x}'),
            ]),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SchoolSatelliteView(
              center: LatLng(-4.26, 15.27), title: 'EP Test', height: 200),
        ),
      ),
    ));
    await t.pump(); // laisse résoudre le provider
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(SchoolSatelliteView), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('sans versions (hors-ligne) : pas de frise, pas de crash',
      (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        waybackReleasesProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SchoolSatelliteView(center: LatLng(-4.26, 15.27), height: 200),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(SchoolSatelliteView), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('indisponible'), findsOneWidget);
  });
}
