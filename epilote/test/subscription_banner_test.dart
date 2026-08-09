import 'package:epilote/core/widgets/subscription_banner.dart';
import 'package:epilote/features/admin_groupe/providers/subscription_access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Bandeau d'abonnement (admin_groupe) — ce que l'admin VOIT, pas ce que la
//  fonction pure calcule.
//
//  Le bandeau s'allumait à 30 jours de l'échéance : un mois d'alerte quotidienne
//  sur toutes les pages, qu'on cesse de lire bien avant qu'elle devienne vraie.
//  Fenêtre ramenée à 7 j, et réglable (`platform_settings.subscription_alert_days`).
//
//  Cas de référence : le groupe METP de la capture du 2026-08-09 — échéance au
//  31/08, soit 22 jours restants. Le bandeau annonçait « expire dans 22 jours ».
//  Il doit désormais rester ÉTEINT.
// ════════════════════════════════════════════════════════════════════════════

Future<void> _pump(WidgetTester tester, SubscriptionAccess access) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionAccessProvider.overrideWith((ref) async => access),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SubscriptionBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SubscriptionAccess _access(int daysLeft, {int alertDays = 7}) =>
    computeSubscriptionAccess(
      status: 'active',
      end: DateTime(2026, 8, 9).add(Duration(days: daysLeft)),
      today: DateTime(2026, 8, 9),
      alertDays: alertDays,
    );

void main() {
  group('SubscriptionBanner — fenêtre d\'alerte', () {
    testWidgets('RÉGRESSION : à 22 j (cas METP) le bandeau est invisible',
        (tester) async {
      await _pump(tester, _access(22));

      expect(find.textContaining('expire dans'), findsNothing);
      expect(find.text('Renouveler'), findsNothing);
      // Le widget se réduit à rien : aucune place prise dans le shell.
      expect(tester.getSize(find.byType(SubscriptionBanner)), Size.zero);
    });

    testWidgets('à 8 j : toujours éteint (hors fenêtre)', (tester) async {
      await _pump(tester, _access(8));
      expect(find.textContaining('expire dans'), findsNothing);
    });

    testWidgets('à 7 j : le bandeau s\'allume, au pluriel', (tester) async {
      await _pump(tester, _access(7));
      expect(find.text('Votre abonnement expire dans 7 jours.'), findsOneWidget);
      expect(find.text('Renouveler'), findsOneWidget);
    });

    testWidgets('à 1 j : singulier, pas « 1 jours »', (tester) async {
      await _pump(tester, _access(1));
      expect(find.text('Votre abonnement expire dans 1 jour.'), findsOneWidget);
    });

    testWidgets('le jour même : « aujourd\'hui », jamais « dans 0 jour »',
        (tester) async {
      await _pump(tester, _access(0));
      expect(find.text("Votre abonnement expire aujourd'hui."), findsOneWidget);
    });

    testWidgets('réglage à 30 j : 22 j rallume le bandeau', (tester) async {
      // Preuve que le seuil n'est plus en dur mais bien piloté par le réglage.
      await _pump(tester, _access(22, alertDays: 30));
      expect(
          find.text('Votre abonnement expire dans 22 jours.'), findsOneWidget);
    });
  });

  group('SubscriptionBanner — après échéance (inchangé)', () {
    testWidgets('grâce : message de dépassement, quel que soit alertDays',
        (tester) async {
      await _pump(tester, _access(-3));
      expect(find.textContaining('Abonnement expiré depuis 3 jours'),
          findsOneWidget);
    });

    testWidgets('au-delà de la grâce : lecture seule', (tester) async {
      await _pump(tester, _access(-40));
      expect(find.textContaining('création d\'écoles et d\'utilisateurs '
          'suspendue'), findsOneWidget);
    });

    testWidgets('abonnement lointain : rien du tout', (tester) async {
      await _pump(tester, _access(200));
      expect(tester.getSize(find.byType(SubscriptionBanner)), Size.zero);
    });
  });
}
