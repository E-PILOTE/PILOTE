import 'package:epilote/core/utils/subscription_days.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'INVARIANT QUI TIENT LES DEUX RÉGLAGES ENSEMBLE
//
//  L'échéance est annoncée par deux canaux réglés séparément :
//    🔔 la cloche  → `notif_reminder_days` (cron pg, seuils CSV)
//    🟠 le bandeau → `subscription_alert_days` (fenêtre d'alerte)
//
//  Ils ont déjà divergé deux fois : cloche à J-30 quand le bandeau attendait
//  J-7 (corrigé par la migration 0097), puis l'inverse dès qu'on a ramené le
//  bandeau à J-5 sans toucher aux rappels. La règle qui empêche la rechute :
//  au moins un rappel DOIT tomber à l'intérieur de la fenêtre du bandeau.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('parseReminderDays', () {
    test('CSV nominal → trié du plus lointain au plus proche', () {
      expect(parseReminderDays('30,15,7,1,0'), [30, 15, 7, 1, 0]);
    });

    test('espaces et ordre quelconque tolérés', () {
      expect(parseReminderDays(' 1 , 30,  7 '), [30, 7, 1]);
    });

    test('fragments non numériques ignorés, pas de rejet global', () {
      // Miroir du parseur SQL : `where t ~ '^[0-9]+$'`.
      expect(parseReminderDays('30, abc, 7'), [30, 7]);
    });

    test('champ vide → liste vide (le SQL retombera sur son défaut)', () {
      expect(parseReminderDays(''), isEmpty);
    });
  });

  group('remindersCoverAlertWindow', () {
    test('défauts livrés (30,15,7,1,0 avec une alerte à 5) : cohérent', () {
      expect(
        remindersCoverAlertWindow(
          reminderDays: parseReminderDays('30,15,7,1,0'),
          alertDays: kSubscriptionAlertDays,
        ),
        isTrue,
      );
    });

    test('RÉGRESSION : 30,15,7 avec une alerte à 5 → trou détecté', () {
      // La cloche se tairait pendant les 5 jours qui décident du paiement.
      expect(
        remindersCoverAlertWindow(
          reminderDays: parseReminderDays('30,15,7'),
          alertDays: 5,
        ),
        isFalse,
      );
    });

    test('un seuil exactement égal à la fenêtre compte comme dedans', () {
      expect(
        remindersCoverAlertWindow(reminderDays: const [5], alertDays: 5),
        isTrue,
      );
    });

    test('aucun rappel du tout → trou', () {
      expect(
        remindersCoverAlertWindow(reminderDays: const [], alertDays: 5),
        isFalse,
      );
    });
  });

  group('le seuil livré', () {
    test('la constante de repli vaut 5', () {
      // Elle doit rester alignée sur le défaut SQL de la migration 0106
      // (`effective_alert_days` et `get_subscription_settings`).
      expect(kSubscriptionAlertDays, 5);
    });
  });
}
