import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/active_agent_provider.dart';
import '../agent_lock_screen.dart';
import '../device_mode_screen.dart';

/// Porte du verrou : empile par-dessus [child], selon l'état :
/// 1. mode d'appareil non choisi → [DeviceModeScreen] ;
/// 2. poste partagé non déverrouillé → [AgentLockScreen] ;
/// 3. sinon → rien.
/// Branché dans `MaterialApp.builder` → couvre toutes les routes.
class AgentLockGate extends ConsumerWidget {
  const AgentLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsMode = ref.watch(needsDeviceModeChoiceProvider);
    final locked = ref.watch(needsAgentUnlockProvider);

    final Widget overlay = needsMode
        ? const DeviceModeScreen(key: ValueKey('device-mode'))
        : locked
            ? const AgentLockScreen(key: ValueKey('agent-lock'))
            : const SizedBox.shrink(key: ValueKey('agent-unlocked'));

    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: overlay,
        ),
      ],
    );
  }
}
