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
///
/// ⚠️ Ces écrans sont montés en frère du Navigator (via `MaterialApp.builder`),
/// donc SANS Overlay ancêtre. Or `Tooltip`, `TextField` (EditableText),
/// `DropdownButton`… exigent un Overlay au build. On héberge donc l'écran dans
/// un [Overlay] **stable** (jamais recréé) : l'animation d'apparition vit à
/// l'intérieur (via un [AnimatedSwitcher] enfant). Un Overlay recréé/détruit par
/// un AnimatedSwitcher externe déclenchait une assertion Semantics
/// (`!child.attached`) au reparentage — d'où l'Overlay stable + [IgnorePointer].
class AgentLockGate extends ConsumerWidget {
  const AgentLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsMode = ref.watch(needsDeviceModeChoiceProvider);
    final locked = ref.watch(needsAgentUnlockProvider);
    final showing = needsMode || locked;

    final Widget content = needsMode
        ? const DeviceModeScreen(key: ValueKey('device-mode'))
        : locked
            ? const AgentLockScreen(key: ValueKey('agent-lock'))
            : const SizedBox.shrink(key: ValueKey('agent-unlocked'));

    return Stack(
      children: [
        child,
        // Overlay STABLE (monté en permanence) pour fournir un Overlay ancêtre ;
        // l'animation se fait à l'intérieur, l'Overlay lui-même n'est jamais
        // reparenté. IgnorePointer laisse passer les clics quand rien n'est vu.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !showing,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  maintainState: true,
                  builder: (_) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
