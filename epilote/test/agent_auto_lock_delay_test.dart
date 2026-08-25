import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/auth/screens/widgets/agent_lock_gate.dart';

/// Le poste partagé doit tenir le délai ANNONCÉ à l'agent (5 min par défaut).
/// Se re-verrouiller plus tôt, c'est réclamer un PIN au milieu d'une saisie.
void main() {
  Future<ProviderContainer> monterPoste(WidgetTester tester,
      {int minutes = kAutoLockDefaultMinutes}) async {
    SharedPreferences.setMockInitialValues({
      'device_mode': 'shared',
      'auto_lock_minutes': minutes,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        needsAgentUnlockProvider.overrideWithValue(false),
        needsDeviceModeChoiceProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: const Scaffold(body: Text('APP')),
        builder: (context, child) =>
            AgentLockGate(child: child ?? const SizedBox.shrink()),
      ),
    ));
    final container =
        ProviderScope.containerOf(tester.element(find.text('APP')),
            listen: false);
    // La préférence disque est relue en asynchrone : laisser le mode se charger.
    await tester.pump();
    await tester.pump();
    // Un agent ouvre sa session → le compte à rebours s'arme.
    container.read(selectedAgentIdProvider.notifier).state = 'agent-1';
    await tester.pump();
    return container;
  }

  testWidgets('5 min annoncées → toujours ouvert à 4 min 59', (tester) async {
    final c = await monterPoste(tester);
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(c.read(selectedAgentIdProvider), 'agent-1',
        reason: 'le poste s\'est re-verrouillé AVANT le délai annoncé');
  });

  testWidgets('5 min annoncées → verrouillé une fois le délai passé',
      (tester) async {
    final c = await monterPoste(tester);
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    expect(c.read(selectedAgentIdProvider), isNull,
        reason: 'le poste abandonné aurait dû se re-verrouiller');
  });

  testWidgets('une interaction repousse l\'échéance d\'autant', (tester) async {
    final c = await monterPoste(tester);
    await tester.pump(const Duration(minutes: 4));
    // L'agent bouge la souris : le compte à rebours repart de zéro.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(minutes: 4));
    expect(c.read(selectedAgentIdProvider), 'agent-1',
        reason: 'l\'interaction n\'a pas repoussé le re-verrouillage');
  });
}
