import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/constants/routes.dart';
import 'package:epilote/core/widgets/app_shell/app_sidebar.dart';
import 'package:epilote/core/widgets/app_shell/nav_models.dart';
import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/presentation/license_providers.dart';

/// Vérification d'INTÉGRATION de la sidebar : le hard-lock (ADR-0009) rend les
/// tuiles de MODULE inaccessibles (cadenas + clic mort), tandis que le Tableau de
/// bord et les pages hors abonnement restent vivants. Exerce le vrai câblage
/// `app_sidebar.dart` → `moduleSlugForLocation` → `NavTile.locked`.

class _FakeEnt extends EntitlementNotifier {
  _FakeEnt(this._e);
  final Entitlement _e;
  @override
  Future<Entitlement> build() async => _e;
}

/// Licence expirée au-delà de la grâce. [hardLockable] pilote privé vs public.
Entitlement _expired({required bool hardLockable}) {
  final now = DateTime.now().toUtc();
  return Entitlement(
    license: License(
      groupId: 'g', plan: 'p', modules: const {'eleves'}, quotas: const {},
      validFrom: null, validTo: now.subtract(const Duration(days: 40)),
      offlineWindow: const Duration(days: 30), version: 1, issuedAt: now,
      hardLockable: hardLockable),
    lastSyncAt: now,
  );
}

// Sidebar minimale : une entrée MODULE (/user/eleves) + une entrée NEUTRE
// (Tableau de bord). Seule la première doit se verrouiller en hard-lock.
final _sections = <NavSection>[
  const NavSection(title: '', pinnedTop: true, entries: [
    NavEntry.item(
        icon: Icons.dashboard_rounded,
        label: 'Tableau de bord',
        route: Routes.userDashboard),
  ]),
  const NavSection(title: 'SCOLARITÉ', entries: [
    NavEntry.item(
        icon: Icons.people_rounded, label: 'Élèves', route: Routes.eleves),
  ]),
];

Future<void> _pump(WidgetTester tester, Entitlement e) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [entitlementProvider.overrideWith(() => _FakeEnt(e))],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 260,
          height: 700,
          child: AppSidebar(
            sections: _sections,
            expanded: true,
            currentLocation: Routes.userDashboard,
            messageBadge: 0,
            profile: null,
            onNavigate: (_) {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump(); // laisse résoudre l'AsyncNotifier
  await tester.pump(const Duration(milliseconds: 250)); // animations sidebar
}

void main() {
  testWidgets('groupe expiré → tuile module cadenassée, Dashboard intact',
      (tester) async {
    await _pump(tester, _expired(hardLockable: true));
    expect(find.text('Élèves'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    // Le module porte un cadenas ; le dashboard non → exactement un cadenas.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('flag hard_lock absent (fail-soft) → aucune tuile cadenassée',
      (tester) async {
    await _pump(tester, _expired(hardLockable: false));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('aucune licence (dormant) → aucune tuile cadenassée (fail-soft)',
      (tester) async {
    await _pump(tester, const Entitlement.none());
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });
}
