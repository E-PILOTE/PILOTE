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

    test('expiresSoon vrai quand actif et échéance ≤ 7 j (défaut)', () {
      final a = compute('active', DateTime(2026, 7, 10)); // 6 j
      expect(a.phase, SubscriptionPhase.active);
      expect(a.expiresSoon, true);
    });

    test('borne exacte de la fenêtre d\'alerte (J-7) → alerté', () {
      expect(compute('active', DateTime(2026, 7, 11)).expiresSoon, true);
    });

    test('J-8 → PAS encore alerté (le bandeau reste éteint)', () {
      final a = compute('active', DateTime(2026, 7, 12));
      expect(a.phase, SubscriptionPhase.active);
      expect(a.expiresSoon, false);
    });

    test('régression : à 22 j le bandeau ne s\'allume plus (valait 30 en dur)', () {
      expect(compute('active', DateTime(2026, 7, 26)).expiresSoon, false);
    });

    test('alerte CONFIGURABLE : alertDays=30 → 16 j déclenche de nouveau', () {
      final a = computeSubscriptionAccess(
          status: 'active', end: DateTime(2026, 7, 20), today: today,
          alertDays: 30);
      expect(a.expiresSoon, true);
      expect(a.alertDays, 30);
    });

    test('expiresSoon faux dès que la date est dépassée (c\'est la grâce)', () {
      expect(compute('active', DateTime(2026, 7, 3)).expiresSoon, false);
    });

    test('échéance AUJOURD\'HUI → 0 j restant, encore actif et alerté', () {
      final a = compute('active', today);
      expect(a.phase, SubscriptionPhase.active);
      expect(a.daysLeft, 0);
      expect(a.expiresSoon, true);
    });

    test('unknown() est fail-soft (écriture autorisée)', () {
      expect(SubscriptionAccess.unknown().canWrite, true);
    });

    test('grâce CONFIGURABLE : graceDays=5, échu depuis 10 j → readOnly', () {
      final a = computeSubscriptionAccess(
          status: 'active', end: DateTime(2026, 6, 24), today: today, graceDays: 5);
      expect(a.phase, SubscriptionPhase.readOnly);
    });

    test('grâce par défaut (15) sur la même date → grace (preuve du non-codage en dur)', () {
      final a = computeSubscriptionAccess(
          status: 'active', end: DateTime(2026, 6, 24), today: today);
      expect(a.phase, SubscriptionPhase.grace);
    });
  });
}
