import 'package:epilote/core/utils/subscription_days.dart';
import 'package:epilote/core/widgets/school_subscription_banner.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Compte à rebours d'échéance côté ÉCOLE.
//
//  Ce compte à rebours dérivait de `license.validTo` et s'allumait 30 jours
//  avant — un seuil en dur, dans un widget qui ne s'affichait QUE pour les
//  groupes détenteurs d'une licence signée (liste pilote). Résultat : l'école
//  s'inquiétait trois semaines avant son admin de groupe… quand elle voyait
//  quelque chose.
//
//  Il dérive désormais de la date d'échéance SYNCHRONISÉE du groupe et du même
//  seuil que le bandeau admin (migration 0106). Les cas ci-dessous reprennent
//  un à un ceux de l'ancienne suite, sur la nouvelle API.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  final now = DateTime(2026, 7, 5, 9);
  const alert = kSubscriptionAlertDays; // 5

  int? window(DateTime? end, {int alertDays = alert}) =>
      alertDaysLeft(end, alertDays: alertDays, today: now);

  group('alertDaysLeft — la fenêtre', () {
    test('échéance nulle → null (abonnement perpétuel)', () {
      expect(window(null), isNull);
    });

    test('échéance lointaine (> seuil) → null', () {
      expect(window(now.add(const Duration(days: 45))), isNull);
    });

    test('déjà dépassée → null (grâce / lecture seule prennent le relais)', () {
      expect(window(now.subtract(const Duration(days: 2))), isNull);
    });

    test('juste hors fenêtre (J-6 pour un seuil de 5) → null', () {
      expect(window(now.add(const Duration(days: 6))), isNull);
    });

    test('frontière : exactement au seuil → affiché', () {
      expect(window(now.add(const Duration(days: alert))), alert);
    });

    test('seuil élargi à 30 : J-22 rallume le compte à rebours', () {
      expect(window(now.add(const Duration(days: 22)), alertDays: 30), 22);
    });

    test('RÉGRESSION : une DATE se compare en jours civils, pas en durées', () {
      // `subscription_end` se parse à minuit ; `now` porte 9 h. Une
      // soustraction brute donnerait 4,6 j tronqués à 4 — et le dernier jour
      // payé disparaîtrait du compte à rebours.
      expect(window(DateTime(2026, 7, 10)), 5);
      expect(window(DateTime(2026, 7, 5)), 0);
    });
  });

  group('schoolCountdownMessage — ce que le personnel lit', () {
    test('J-3 → pluriel', () {
      final m = schoolCountdownMessage(daysLeft: 3, willSuspendModules: false);
      expect(m, contains('dans 3 jours'));
    });

    test('J-1 → singulier, jamais « 1 jours »', () {
      final m = schoolCountdownMessage(daysLeft: 1, willSuspendModules: false);
      expect(m, contains('dans 1 jour'));
      expect(m, isNot(contains('1 jours')));
    });

    test("J0 → « aujourd'hui », jamais « dans 0 jour »", () {
      final m = schoolCountdownMessage(daysLeft: 0, willSuspendModules: false);
      expect(m, contains("aujourd'hui"));
      expect(m, isNot(contains('0 jour')));
    });

    test('sans licence à hard-lock : aucune suspension promise', () {
      // Annoncer une coupure qui ne vient pas apprend à ignorer les suivantes.
      final m = schoolCountdownMessage(daysLeft: 2, willSuspendModules: false);
      expect(m, isNot(contains('suspendu')));
      expect(m, contains('administration'));
    });

    test('avec licence à hard-lock : la suspension est annoncée', () {
      final m = schoolCountdownMessage(daysLeft: 2, willSuspendModules: true);
      expect(m, contains('suspendu'));
    });
  });
}
