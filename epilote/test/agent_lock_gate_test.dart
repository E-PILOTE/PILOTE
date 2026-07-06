import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
