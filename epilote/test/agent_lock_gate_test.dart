import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/screens/widgets/agent_lock_gate.dart';

void main() {
  testWidgets('déverrouillé → affiche l\'enfant, pas le verrou', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [needsAgentUnlockProvider.overrideWithValue(false)],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    expect(find.text('CONTENU'), findsOneWidget);
    expect(find.text('Qui utilise ce poste ?'), findsNothing);
  });

  testWidgets('verrouillé → empile le verrou par-dessus l\'enfant',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(true),
        switchableAgentsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(
        home: AgentLockGate(child: Text('CONTENU')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Qui utilise ce poste ?'), findsOneWidget);
  });
}
