import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/providers/vitrine_messages_provider.dart';
import 'package:epilote/features/auth/providers/vitrine_partners_provider.dart';
import 'package:epilote/features/auth/screens/agent_lock_screen.dart';
import 'package:epilote/features/auth/screens/device_mode_screen.dart';
import 'package:epilote/features/auth/screens/widgets/vitrine_clock.dart';
import 'package:epilote/features/structure/providers/academic_year_provider.dart';

/// Captures visuelles (goldens) des états de l'écran-verrou, pour inspection.
/// Générer/rafraîchir avec : flutter test --update-goldens test/agent_lock_capture_test.dart
void main() {
  // Horloge FIGÉE : la vitrine affiche l'heure et la date courantes ; sans ce
  // gel, les goldens cassaient chaque jour (date) et chaque minute (heure).
  setUp(() => debugVitrineClock = () => DateTime(2026, 1, 15, 10, 30));
  tearDown(() => debugVitrineClock = null);

  const agents = [
    AgentOption(id: 'a1', firstName: 'Marie', lastName: 'Koumba', role: 'secretaire'),
    AgentOption(id: 'a2', firstName: 'Alain', lastName: 'Ngoma', role: 'comptable'),
    AgentOption(id: 'a3', firstName: 'Jean', lastName: 'Bantou', role: 'directeur'),
    AgentOption(id: 'a4', firstName: 'Paul', lastName: 'Loemba', role: 'surveillant'),
    AgentOption(id: 'a5', firstName: 'Sylvie', lastName: 'Mabiala', role: 'cpe'),
    AgentOption(id: 'a6', firstName: 'Théo', lastName: 'Okemba', role: 'comptable'),
  ];

  Future<void> pumpLock(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 832);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        switchableAgentsProvider.overrideWith((ref) => Stream.value(agents)),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
        serviceMessagesProvider.overrideWith((ref) => Stream.value(const [
              'E-PILOTE 3.0 — les bulletins PDF sont disponibles dans Évaluation.',
              'Maintenance planifiée dimanche de 22h à 23h.',
            ])),
      ],
      child: const MaterialApp(home: Scaffold(body: AgentLockScreen())),
    ));
    await tester.pump();
  }

  testWidgets('capture — vitrine', (tester) async {
    await pumpLock(tester);
    await expectLater(find.byType(AgentLockScreen),
        matchesGoldenFile('goldens/lock_vitrine.png'));
  });

  testWidgets('capture — vitrine avec partenaires (repli texte)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 832);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        switchableAgentsProvider.overrideWith((ref) => Stream.value(agents)),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
        serviceMessagesProvider.overrideWith(
            (ref) => Stream.value(const ['E-PILOTE 3.0 disponible.'])),
        // Groupe opté in + partenaires vivants (logo null → repli sur le nom).
        groupPartnerOptInProvider.overrideWith((ref) => Stream.value(true)),
        vitrinePartnersProvider.overrideWith((ref) => Stream.value(const [
              PartnerVitrineItem(name: 'MEPSA'),
              PartnerVitrineItem(name: 'UNICEF Éducation'),
            ])),
      ],
      child: const MaterialApp(home: Scaffold(body: AgentLockScreen())),
    ));
    await tester.pump();
    await expectLater(find.byType(AgentLockScreen),
        matchesGoldenFile('goldens/lock_vitrine_partners.png'));
  });

  testWidgets('capture — profils', (tester) async {
    await pumpLock(tester);
    await tester.tap(find.text('Ouvrir une session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // révélation
    await tester.pump(const Duration(milliseconds: 50));  // profils enrôlés
    await tester.pump(const Duration(milliseconds: 700)); // cascade terminée
    await expectLater(find.byType(AgentLockScreen),
        matchesGoldenFile('goldens/lock_profils.png'));
  });

  testWidgets('capture — PIN', (tester) async {
    await pumpLock(tester);
    await tester.tap(find.text('Ouvrir une session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // révélation
    await tester.pump(const Duration(milliseconds: 50));  // profils enrôlés
    await tester.pump(const Duration(milliseconds: 700)); // cascade terminée
    await tester.tap(find.text('Marie Koumba').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await expectLater(find.byType(AgentLockScreen),
        matchesGoldenFile('goldens/lock_pin.png'));
  });

  testWidgets('capture — mode d\'appareil', (tester) async {
    tester.view.physicalSize = const Size(1280, 832);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: DeviceModeScreen())),
    ));
    await tester.pump();
    await expectLater(find.byType(DeviceModeScreen),
        matchesGoldenFile('goldens/device_mode.png'));
  });
}
