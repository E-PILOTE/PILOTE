import 'package:epilote/features/super_admin/widgets/subscription_cycle_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Le bloc « Cycle d'abonnement » de l'écran Paramètres super_admin.
//
//  Les quatre réglages d'un même cycle vivaient dans deux onglets : on en
//  changeait un sans voir l'autre. Ce bloc les réunit, montre la frise de
//  l'escalade, et surtout PRÉVIENT quand l'échelle se troue.
// ════════════════════════════════════════════════════════════════════════════

Future<void> _pump(
  WidgetTester tester, {
  required String alert,
  required String reminders,
  String grace = '15',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SubscriptionCycleSection(
            alertCtrl: TextEditingController(text: alert),
            reminderCtrl: TextEditingController(text: reminders),
            graceCtrl: TextEditingController(text: grace),
            trialCtrl: TextEditingController(text: '3'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SubscriptionCycleSection', () {
    testWidgets('réglage livré (5 + 30,15,7,1,0) : frise complète, aucune alerte',
        (t) async {
      await _pump(t, alert: '5', reminders: '30,15,7,1,0');

      // Les rappels lointains, puis le bandeau, puis les rappels proches.
      expect(find.text('J-30 🔔'), findsOneWidget);
      expect(find.text('J-15 🔔'), findsOneWidget);
      expect(find.text('J-7 🔔'), findsOneWidget);
      expect(find.text('J-5 🟠 bandeau'), findsOneWidget);
      expect(find.text('J-1 🔔'), findsOneWidget);
      expect(find.text('J0 🔔 échéance'), findsOneWidget);
      expect(find.text('J+15 🔴 lecture seule'), findsOneWidget);

      expect(find.textContaining('Aucun rappel'), findsNothing);
    });

    testWidgets('trou détecté : des rappels tous hors de la fenêtre', (t) async {
      await _pump(t, alert: '5', reminders: '30,15,7');
      expect(
        find.textContaining('Aucun rappel ne tombe dans la fenêtre'),
        findsOneWidget,
      );
    });

    testWidgets('rappel manquant le jour même : signalé aussi', (t) async {
      await _pump(t, alert: '5', reminders: '30,15,7,1');
      expect(find.textContaining('Aucun rappel le jour même'), findsOneWidget);
    });

    testWidgets('la frise suit le délai de grâce', (t) async {
      await _pump(t, alert: '5', reminders: '5,0', grace: '30');
      expect(find.text('J+30 🔴 lecture seule'), findsOneWidget);
    });

    testWidgets('un champ vidé ne casse pas la frise', (t) async {
      // Le super_admin efface le champ pour le retaper : le bloc doit tenir,
      // et la frise retomber sur le défaut compilé plutôt que sur « J-0 ».
      await _pump(t, alert: '', reminders: '');
      expect(find.text('J-5 🟠 bandeau'), findsOneWidget);
      expect(find.text('J0 échéance'), findsOneWidget);
    });
  });
}
