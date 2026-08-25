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

  test('actif, échéance proche (J-5) → expiringSoon', () {
    expect(b('active', now.add(const Duration(days: 5))), DunningBucket.expiringSoon);
  });

  test('actif, échéance J-6 → null (au-delà du seuil « proche »)', () {
    // Le seau « échoit bientôt » du recouvrement suit la MÊME fenêtre que le
    // bandeau de l'admin de groupe (`kSubscriptionAlertDays`, réglable) : le
    // super_admin et son client doivent voir la même urgence le même jour.
    expect(b('active', now.add(const Duration(days: 6))), isNull);
  });

  test('seuil élargi : soonDays=7 rattrape J-7', () {
    expect(
      bucketDunning(
          status: 'active',
          end: now.add(const Duration(days: 7)),
          now: now,
          soonDays: 7),
      DunningBucket.expiringSoon,
    );
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
