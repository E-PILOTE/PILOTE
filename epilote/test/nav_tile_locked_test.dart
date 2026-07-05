import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/core/widgets/app_shell/nav_models.dart';
import 'package:epilote/core/widgets/app_shell/nav_tile.dart';

void main() {
  const entry = NavEntry.item(
    icon: Icons.people_rounded,
    label: 'Élèves',
    route: '/user/eleves',
  );

  Widget host(NavTile tile) => MaterialApp(
        home: Scaffold(
          // Fond sombre : les tuiles dessinent en blanc translucide.
          backgroundColor: const Color(0xFF0F2438),
          body: tile,
        ),
      );

  testWidgets('tuile normale → le clic navigue', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(NavTile(
      entry: entry,
      isActive: false,
      expanded: true,
      badge: 0,
      onTap: () => tapped++,
    )));
    await tester.tap(find.text('Élèves'));
    expect(tapped, 1);
    // Pas de cadenas.
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('tuile verrouillée → clic MORT (onTap jamais appelé) + cadenas',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(NavTile(
      entry: entry,
      isActive: false,
      expanded: true,
      badge: 0,
      locked: true,
      onTap: () => tapped++,
    )));
    await tester.tap(find.text('Élèves'));
    expect(tapped, 0, reason: 'un module verrouillé ne doit jamais naviguer');
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('verrouillée ne peut pas paraître active (pas de liseré actif)',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(NavTile(
      entry: entry,
      isActive: true, // même marquée active…
      expanded: true,
      badge: 0,
      locked: true, // … le verrou prime
      onTap: () => tapped++,
    )));
    await tester.tap(find.text('Élèves'));
    expect(tapped, 0);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });
}
