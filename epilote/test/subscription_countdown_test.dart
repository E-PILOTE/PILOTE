import 'package:epilote/licensing/presentation/license_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 9);

  group('subscriptionCountdownLabel', () {
    test('validTo nul → null (abonnement perpétuel)', () {
      expect(subscriptionCountdownLabel(null, now), isNull);
    });

    test('échéance lointaine (> seuil) → null', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 45)), now);
      expect(r, isNull);
    });

    test('déjà dépassée → null (grace/hardLock prennent le relais)', () {
      final r = subscriptionCountdownLabel(now.subtract(const Duration(days: 2)), now);
      expect(r, isNull);
    });

    test('J-10 → libellé au pluriel', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 10)), now);
      expect(r, contains('dans 10 jours'));
    });

    test('J-1 → libellé au singulier', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 1)), now);
      expect(r, contains('dans 1 jour'));
      expect(r, isNot(contains('1 jours')));
    });

    test("J0 (jour même) → « aujourd'hui »", () {
      final r = subscriptionCountdownLabel(now.add(const Duration(hours: 6)), now);
      expect(r, contains("aujourd'hui"));
    });

    test('frontière : exactement au seuil max (30) → affiché', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 30)), now);
      expect(r, contains('dans 30 jours'));
    });
  });
}
