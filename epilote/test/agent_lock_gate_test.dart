import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/screens/widgets/agent_lock_gate.dart';
import 'package:epilote/features/structure/providers/academic_year_provider.dart';

void main() {
  testWidgets('déverrouillé → affiche l\'enfant, pas le verrou', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(false),
        needsDeviceModeChoiceProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    expect(find.text('CONTENU'), findsOneWidget);
    expect(find.text('Ouvrir une session'), findsNothing);
  });

  testWidgets('verrouillé → empile la vitrine par-dessus l\'enfant',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(true),
        needsDeviceModeChoiceProvider.overrideWithValue(false),
        switchableAgentsProvider.overrideWith((ref) => Stream.value(const [])),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
      ],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    // Au repos, la vitrine s'affiche avec son bouton d'ouverture de session.
    expect(find.text('Ouvrir une session'), findsOneWidget);
    expect(find.text('CONTENU'), findsOneWidget);
  });

  // Régression : monté dans `MaterialApp.builder` (frère du Navigator, donc SANS
  // Overlay ancêtre) — reproduit le vrai câblage. Le TextField de recherche et
  // les tooltips des profils exigent un Overlay ; jadis « No Overlay widget
  // found ». La porte doit fournir son propre Overlay.
  testWidgets('câblage réel (builder) → profils sans erreur Overlay',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(true),
        needsDeviceModeChoiceProvider.overrideWithValue(false),
        switchableAgentsProvider.overrideWith((ref) => Stream.value(const [
              AgentOption(
                  id: 'a1',
                  firstName: 'Marie',
                  lastName: 'Koumba',
                  role: 'secretaire'),
            ])),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
      ],
      child: MaterialApp(
        home: const Scaffold(body: Text('APP')),
        // Exactement comme main.dart : la porte enveloppe le Navigator.
        builder: (context, child) =>
            AgentLockGate(child: child ?? const SizedBox.shrink()),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Ouvrir une session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Grille de profils affichée (TextField recherche + tooltips) sans exception.
    expect(tester.takeException(), isNull);
    expect(find.text('Qui utilise ce poste ?'), findsOneWidget);
  });

  // Régression : le verrou doit RÉAPPARAÎTRE quand le provider repasse à true
  // APRÈS le montage (cas « Changer d'utilisateur » : aucun remontage, simple
  // changement de provider). L'ancien Overlay figeait son contenu à la création
  // (closure dans `initialEntries`) → le verrou ne revenait jamais.
  testWidgets('verrou déjà monté → réapparaît quand le provider repasse à true',
      (tester) async {
    final toggle = StateProvider<bool>((_) => false);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWith((ref) => ref.watch(toggle)),
        needsDeviceModeChoiceProvider.overrideWithValue(false),
        switchableAgentsProvider.overrideWith((ref) => Stream.value(const [])),
        currentSchoolProvider.overrideWith(
            (ref) => Stream.value(const {'name': 'Lycée de Kinkala'})),
      ],
      child: MaterialApp(
        home: const Scaffold(body: Text('APP')),
        builder: (context, child) =>
            AgentLockGate(child: child ?? const SizedBox.shrink()),
      ),
    ));
    await tester.pump();
    // Au départ déverrouillé : pas de vitrine.
    expect(find.text('Ouvrir une session'), findsNothing);

    // Bascule à true SANS remonter la porte (comme « Changer d'utilisateur »).
    final container = ProviderScope.containerOf(
        tester.element(find.text('APP')),
        listen: false);
    container.read(toggle.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // La vitrine DOIT réapparaître (échouait avec l'Overlay figé).
    expect(find.text('Ouvrir une session'), findsOneWidget);
  });
}
