import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/presentation/license_banner.dart';
import 'package:epilote/licensing/presentation/license_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEnt extends EntitlementNotifier {
  _FakeEnt(this._e);
  final Entitlement _e;
  @override
  Future<Entitlement> build() async => _e;
}

Entitlement _ent({required DateTime validTo, required Duration offlineWindow, bool hardLockable = true}) {
  final now = DateTime.now().toUtc();
  return Entitlement(
    license: License(
      groupId: 'g', plan: 'p', modules: const {'eleves'}, quotas: const {},
      validFrom: null, validTo: validTo, offlineWindow: offlineWindow,
      version: 1, issuedAt: now, hardLockable: hardLockable),
    lastSyncAt: now,
  );
}

Future<void> _pump(WidgetTester tester, Entitlement e) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [entitlementProvider.overrideWith(() => _FakeEnt(e))],
    child: const MaterialApp(home: Scaffold(body: LicenseBanner())),
  ));
  await tester.pump();
}

void main() {
  final now = DateTime.now().toUtc();

  testWidgets('phase active + échéance J-5 → bandeau compte à rebours', (tester) async {
    await _pump(tester, _ent(validTo: now.add(const Duration(days: 5)), offlineWindow: const Duration(days: 30)));
    expect(find.textContaining('expire dans 5 jours'), findsOneWidget);
  });

  testWidgets('phase active + échéance lointaine → aucun bandeau', (tester) async {
    await _pump(tester, _ent(validTo: now.add(const Duration(days: 90)), offlineWindow: const Duration(days: 30)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('hardLock (échu, hardLockable) → message de suspension rouge', (tester) async {
    await _pump(tester, _ent(validTo: now.subtract(const Duration(days: 1)), offlineWindow: const Duration(days: 30)));
    expect(find.textContaining('suspendu'), findsOneWidget);
    expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
  });
}
