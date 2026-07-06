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
/// un [Overlay] qui LEUR sert d'ancêtre.
///
/// ⚠️ Cet Overlay n'est monté **que** quand un écran est réellement affiché
/// (`showing`). Le garder monté en permanence (même vide, à l'écran de login ou
/// sur le tableau de bord) empilait un Overlay + AnimatedSwitcher en frère de
/// l'app : à chaque frame, `flushSemantics` levait `!child.attached`
/// (des centaines d'exceptions en debug, arbre d'accessibilité cassé). En ne le
/// montant qu'au besoin, l'app normale n'a aucune interférence sémantique.
///
/// [child] reste **toujours** `Stack.children[0]` (position stable) : le
/// Navigator n'est jamais reparenté, donc l'état de navigation est préservé.
/// La [ValueKey] force un Overlay neuf lors de la bascule mode → verrou (sinon
/// `Overlay.initialEntries`, lu une seule fois, figerait le premier contenu).
class AgentLockGate extends ConsumerWidget {
  const AgentLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsMode = ref.watch(needsDeviceModeChoiceProvider);
    final locked = ref.watch(needsAgentUnlockProvider);
    final showing = needsMode || locked;

    return Stack(
      children: [
        child,
        if (showing)
          Positioned.fill(
            child: Overlay(
              key: ValueKey(needsMode ? 'device-mode' : 'agent-lock'),
              initialEntries: [
                OverlayEntry(
                  maintainState: true,
                  builder: (_) => needsMode
                      ? const DeviceModeScreen()
                      : const AgentLockScreen(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
