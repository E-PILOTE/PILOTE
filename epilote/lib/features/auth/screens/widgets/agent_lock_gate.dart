import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/active_agent_provider.dart';
import '../agent_lock_screen.dart';

/// Porte du verrou : empile [AgentLockScreen] par-dessus [child] quand
/// l'appareil doit être déverrouillé (poste partagé, aucun agent choisi).
/// Branché dans `MaterialApp.builder` → couvre toutes les routes.
class AgentLockGate extends ConsumerWidget {
  const AgentLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(needsAgentUnlockProvider);
    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: locked
              ? const AgentLockScreen(key: ValueKey('agent-lock'))
              : const SizedBox.shrink(key: ValueKey('agent-unlocked')),
        ),
      ],
    );
  }
}
