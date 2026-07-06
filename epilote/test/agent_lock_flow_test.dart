import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/screens/agent_lock_screen.dart';
import 'package:epilote/features/structure/providers/academic_year_provider.dart';

/// Vérifie l'enchaînement réel de l'écran-verrou : vitrine → clic « Ouvrir une
/// session » → grille de profils → sélection → pavé PIN (création).
void main() {
  testWidgets('vitrine → profils → PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});

    const agents = [
      AgentOption(
          id: 'a1', firstName: 'Marie', lastName: 'Koumba', role: 'secretaire'),
      AgentOption(
          id: 'a2', firstName: 'Alain', lastName: 'Ngoma', role: 'comptable'),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        switchableAgentsProvider.overrideWith((ref) => Stream.value(agents)),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
      ],
      child: const MaterialApp(home: Scaffold(body: AgentLockScreen())),
    ));
    await tester.pump();

    // 1. Vitrine au repos.
    expect(find.text('Ouvrir une session'), findsOneWidget);
    expect(find.text('Qui utilise ce poste ?'), findsNothing);

    // 2. Clic → la feuille profils monte.
    await tester.tap(find.text('Ouvrir une session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Qui utilise ce poste ?'), findsOneWidget);
    expect(find.text('Marie Koumba'), findsWidgets);

    // 3. Sélection d'un agent → pavé PIN (création, aucun PIN existant).
    await tester.tap(find.text('Alain Ngoma').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Choisissez un code à 4 chiffres'), findsOneWidget);
  });

  testWidgets('reset admin_groupe → PIN existant redemandé en création',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const svc = AgentPinService();
    // L'agent a DÉJÀ un PIN local (créé « maintenant »)…
    await svc.setPin('a1', '1234');
    // …mais admin_groupe a demandé un reset POSTÉRIEUR (synchro serveur).
    final resetAt = DateTime.now().add(const Duration(hours: 1));
    final agents = [
      AgentOption(
          id: 'a1',
          firstName: 'Marie',
          lastName: 'Koumba',
          role: 'secretaire',
          pinResetRequestedAt: resetAt),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        switchableAgentsProvider.overrideWith((ref) => Stream.value(agents)),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
      ],
      child: const MaterialApp(home: Scaffold(body: AgentLockScreen())),
    ));
    await tester.pump();
    await tester.tap(find.text('Ouvrir une session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Marie Koumba').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Malgré le PIN local, le reset force la CRÉATION d'un nouveau code.
    expect(find.text('Choisissez un code à 4 chiffres'), findsOneWidget);
    expect(find.text('Saisissez votre code à 4 chiffres'), findsNothing);
  });
}
