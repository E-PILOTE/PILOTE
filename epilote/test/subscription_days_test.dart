import 'package:epilote/core/utils/subscription_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('daysUntilDate', () {
    // Le cas qui a produit le bug : `subscription_end` est un DATE, donc parsé
    // à minuit, tandis que « maintenant » porte l'heure courante. La
    // soustraction brute donnait 21,6 j, tronqués à 21, pendant que le bandeau
    // (déjà normalisé) affichait 22 sur la même page.
    test('même journée entamée → compte des JOURS civils, pas des durées', () {
      final now = DateTime(2026, 8, 9, 10, 30); // 10 h 30
      final end = DateTime(2026, 8, 31); // minuit

      expect(daysUntilDate(end, now), 22);
      // Preuve du contraste avec l'ancien calcul :
      expect(end.difference(now).inDays, 21);
    });

    test('insensible à l\'heure : minuit et 23 h 59 donnent le même nombre', () {
      final end = DateTime(2026, 8, 31);
      expect(daysUntilDate(end, DateTime(2026, 8, 9, 0, 0)),
          daysUntilDate(end, DateTime(2026, 8, 9, 23, 59)));
    });

    test('échéance aujourd\'hui → 0', () {
      expect(daysUntilDate(DateTime(2026, 8, 9), DateTime(2026, 8, 9, 16)), 0);
    });

    test('échéance hier → -1 (dépassement)', () {
      expect(daysUntilDate(DateTime(2026, 8, 8), DateTime(2026, 8, 9, 1)), -1);
    });

    test('sans échéance → null (abonnement perpétuel)', () {
      expect(daysUntilDate(null, DateTime(2026, 8, 9)), isNull);
    });

    test('traverse un changement de mois et d\'année', () {
      expect(daysUntilDate(DateTime(2027, 1, 1), DateTime(2026, 12, 25, 8)), 7);
    });
  });

  group('règles de statut partagées', () {
    test('active et trial ouvrent des droits', () {
      expect(isEntitlingStatus('active'), true);
      expect(isEntitlingStatus('trial'), true);
      expect(isEntitlingStatus('expired'), false);
    });

    test('la grâce ne vaut que pour une expiration naturelle', () {
      expect(isNaturalExpiry('expired'), true);
      expect(isNaturalExpiry('active'), true); // cron en retard
      expect(isNaturalExpiry('suspended'), false); // impayé
      expect(isNaturalExpiry('cancelled'), false); // résilié
    });
  });
}
