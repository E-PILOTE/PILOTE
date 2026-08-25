import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const svc = AgentPinService();
  const a = 'agent-1';
  const b = 'agent-2';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PIN — création / vérification', () {
    test('setPin puis verify avec le bon code → vrai, mauvais → faux', () async {
      expect(await svc.hasPin(a), isFalse);
      await svc.setPin(a, '1234');
      expect(await svc.hasPin(a), isTrue);
      expect(await svc.verifyPin(a, '1234'), isTrue);
      expect(await svc.verifyPin(a, '0000'), isFalse);
    });

    test('setPin enregistre la date de création (reset Phase 2)', () async {
      expect(await svc.pinSetAt(a), isNull);
      await svc.setPin(a, '1234');
      expect(await svc.pinSetAt(a), isNotNull);
    });
  });

  group('Cooldown — échecs persistés par agent', () {
    test('recordFail incrémente le compteur, clearFails remet à zéro', () async {
      expect(await svc.failCount(a), 0);
      await svc.recordFail(a);
      await svc.recordFail(a);
      expect(await svc.failCount(a), 2);
      await svc.clearFails(a);
      expect(await svc.failCount(a), 0);
    });

    test('les échecs sont isolés par agent', () async {
      await svc.recordFail(a);
      expect(await svc.failCount(a), 1);
      expect(await svc.failCount(b), 0);
    });

    test('après 5 échecs, lockedUntil est dans le futur', () async {
      for (var i = 0; i < 5; i++) {
        await svc.recordFail(a);
      }
      final until = await svc.lockedUntil(a);
      expect(until, isNotNull);
      expect(until!.isAfter(DateTime.now()), isTrue);
    });

    test('avant 5 échecs, aucun verrouillage', () async {
      await svc.recordFail(a);
      expect(await svc.lockedUntil(a), isNull);
    });
  });

  group('Récemment utilisés', () {
    test('recordUsage classe le plus récent en premier, sans doublon', () async {
      await svc.recordUsage(a);
      await svc.recordUsage(b);
      await svc.recordUsage(a); // a redevient le plus récent
      final recents = await svc.recentIds();
      expect(recents.first, a);
      expect(recents.contains(b), isTrue);
      expect(recents.where((e) => e == a).length, 1);
    });
  });
}
