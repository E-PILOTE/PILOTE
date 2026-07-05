import 'package:epilote/features/super_admin/providers/dunning_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 9);
  DunningBucket? b(String status, DateTime? end) =>
      bucketDunning(status: status, end: end, now: now);

  test('sans date de fin → null (hors recouvrement)', () {
    expect(b('active', null), isNull);
  });

  test('actif, échéance lointaine (J-30) → null', () {
    expect(b('active', now.add(const Duration(days: 30))), isNull);
  });

  test('actif, échéance proche (J-7) → expiringSoon', () {
    expect(b('active', now.add(const Duration(days: 7))), DunningBucket.expiringSoon);
  });

  test('actif, échéance J-8 → null (au-delà du seuil « proche »)', () {
    expect(b('active', now.add(const Duration(days: 8))), isNull);
  });

  test('échu depuis 10 j (naturel, ≤ grâce 15) → inGrace', () {
    expect(b('active', now.subtract(const Duration(days: 10))), DunningBucket.inGrace);
  });

  test('échu depuis 16 j (> grâce) → overdue', () {
    expect(b('active', now.subtract(const Duration(days: 16))), DunningBucket.overdue);
  });

  test('suspendu → overdue immédiat (pas de grâce)', () {
    expect(b('suspended', now.subtract(const Duration(days: 1))), DunningBucket.overdue);
  });

  test('résilié → overdue immédiat', () {
    expect(b('cancelled', now.subtract(const Duration(days: 1))), DunningBucket.overdue);
  });
}
