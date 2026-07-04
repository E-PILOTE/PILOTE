import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/admin_groupe/providers/subscription_access_provider.dart';

void main() {
  // Date de référence fixe pour des tests déterministes.
  final today = DateTime(2026, 7, 4);
  SubscriptionAccess compute(String status, DateTime? end) =>
      computeSubscriptionAccess(status: status, end: end, today: today);

  group('computeSubscriptionAccess', () {
    test('active avec fin future → active, écriture autorisée', () {
      final a = compute('active', DateTime(2026, 12, 31));
      expect(a.phase, SubscriptionPhase.active);
      expect(a.canWrite, true);
    });

    test('trial avec fin future → active', () {
      expect(compute('trial', DateTime(2026, 8, 1)).phase, SubscriptionPhase.active);
    });

    test('sans date de fin → active (abonnement perpétuel)', () {
      final a = compute('active', null);
      expect(a.phase, SubscriptionPhase.active);
      expect(a.daysLeft, isNull);
    });

    test('expiré dans la fenêtre de grâce → grace, écriture ENCORE autorisée', () {
      // fin il y a 10 jours (< 15 j de grâce)
      final a = compute('expired', DateTime(2026, 6, 24));
      expect(a.phase, SubscriptionPhase.grace);
      expect(a.canWrite, true);
    });

    test('borne exacte de grâce (J+15) → encore grace', () {
      final a = compute('expired', DateTime(2026, 6, 19)); // 15 j avant
      expect(a.phase, SubscriptionPhase.grace);
    });

    test('expiré au-delà de la grâce → readOnly, écriture bloquée', () {
      final a = compute('expired', DateTime(2026, 6, 1)); // 33 j avant
      expect(a.phase, SubscriptionPhase.readOnly);
      expect(a.canWrite, false);
    });

    test('suspended (impayé) → readOnly immédiat, sans grâce', () {
      // même expiré d'hier seulement : pas de grâce pour un impayé.
      final a = compute('suspended', DateTime(2026, 7, 3));
      expect(a.phase, SubscriptionPhase.readOnly);
    });

    test('cancelled → readOnly', () {
      expect(compute('cancelled', DateTime(2026, 6, 30)).phase,
          SubscriptionPhase.readOnly);
    });

    test('active mais date déjà dépassée (cron en retard) → grace, robuste', () {
      // le statut n'a pas encore été basculé mais la date est passée
      final a = compute('active', DateTime(2026, 7, 1)); // 3 j avant
      expect(a.phase, SubscriptionPhase.grace);
    });

    test('expiresSoon vrai quand actif et échéance ≤ 30 j', () {
      final a = compute('active', DateTime(2026, 7, 20)); // 16 j
      expect(a.phase, SubscriptionPhase.active);
      expect(a.expiresSoon, true);
    });

    test('unknown() est fail-soft (écriture autorisée)', () {
      expect(SubscriptionAccess.unknown().canWrite, true);
    });
  });
}
