import 'package:epilote/licensing/application/license_service.dart';
import 'package:epilote/licensing/domain/ports.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  final now = DateTime.utc(2026, 7, 4, 12);

  Map<String, dynamic> claims({
    String group = 'g1',
    int version = 1,
    List<String> modules = const ['notes'],
  }) =>
      {
        'group_id': group,
        'plan': 'pro',
        'modules': modules,
        'quotas': const {},
        'valid_to': now.add(const Duration(days: 30)).toIso8601String(),
        'offline_window': 2592000,
        'version': version,
        'issued_at': now.toIso8601String(),
      };

  LicenseService build({
    required FakeStore store,
    required FakeGateway gateway,
    required Map<String, dynamic>? Function(String) decoder,
  }) =>
      LicenseService(
        verifier: FakeVerifier(decoder),
        store: store,
        gateway: gateway,
        clock: FakeClock(now),
      );

  group('bootstrap', () {
    test('coffre vide → Entitlement.none (fail-soft)', () async {
      final svc = build(store: FakeStore(), gateway: FakeGateway(), decoder: (_) => null);
      final e = await svc.bootstrap();
      expect(e.isEnforced, false);
    });

    test('coffre avec token valide → entitlement enforced', () async {
      final store = FakeStore(TrustState(
        token: 'tok', version: 1, timeHighWater: now, lastSyncAt: now));
      final svc = build(store: store, gateway: FakeGateway(), decoder: (_) => claims());
      final e = await svc.bootstrap();
      expect(e.isEnforced, true);
      expect(e.grantsModule('notes'), true);
    });
  });

  group('refresh', () {
    test('token frais valide → écrit et met à jour (version montante)', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 1, timeHighWater: now, lastSyncAt: now));
      final svc = build(
        store: store,
        gateway: FakeGateway('new'),
        decoder: (t) => t == 'new' ? claims(version: 2) : claims(version: 1),
      );
      final e = await svc.refresh(expectedGroupId: 'g1');
      expect(e.isEnforced, true);
      expect(store.current!.version, 2);
      expect(store.current!.token, 'new');
    });

    test('rollback (version < repère) → conserve l’ancienne, aucune écriture', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 5, timeHighWater: now, lastSyncAt: now));
      final svc = build(
        store: store,
        gateway: FakeGateway('new'),
        decoder: (_) => claims(version: 3), // plus ancienne
      );
      await svc.refresh(expectedGroupId: 'g1');
      expect(store.current!.version, 5);   // inchangé
      expect(store.writes, 0);
    });

    test('mauvaise identité → conserve, aucune écriture', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 1, timeHighWater: now, lastSyncAt: now));
      final svc = build(
        store: store,
        gateway: FakeGateway('new'),
        decoder: (_) => claims(group: 'AUTRE', version: 2),
      );
      await svc.refresh(expectedGroupId: 'g1');
      expect(store.current!.token, 'old');
      expect(store.writes, 0);
    });

    test('hors ligne (gateway null) → conserve', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 1, timeHighWater: now, lastSyncAt: now));
      final svc = build(store: store, gateway: FakeGateway(), decoder: (_) => claims());
      final e = await svc.refresh(expectedGroupId: 'g1');
      expect(e.isEnforced, true);
      expect(store.writes, 0);
    });

    test('signature KO (verifier null) → conserve', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 1, timeHighWater: now, lastSyncAt: now));
      final svc = build(store: store, gateway: FakeGateway('bad'), decoder: (_) => null);
      await svc.refresh(expectedGroupId: 'g1');
      expect(store.writes, 0);
    });

    test('échec d’écriture → renvoie l’état courant (pas d’exception)', () async {
      final store = FakeStore(TrustState(
        token: 'old', version: 1, timeHighWater: now, lastSyncAt: now))
        ..failWrite = true;
      final svc = build(store: store, gateway: FakeGateway('new'),
        decoder: (_) => claims(version: 2));
      final e = await svc.refresh(expectedGroupId: 'g1');
      expect(e.isEnforced, true); // ancienne conservée
    });
  });

  group('bestKnownNow (anti recul d’horloge)', () {
    test('repère haute-eau dans le futur → l’emporte sur l’horloge murale', () {
      final store = FakeStore();
      final svc = build(store: store, gateway: FakeGateway(), decoder: (_) => null);
      final future = now.add(const Duration(days: 5));
      final state = TrustState(
        token: 't', version: 1, timeHighWater: future, lastSyncAt: now);
      expect(svc.bestKnownNow(state), future);
    });
  });
}
