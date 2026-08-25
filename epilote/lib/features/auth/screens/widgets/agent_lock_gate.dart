import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/active_agent_provider.dart';
import '../agent_lock_screen.dart';
import '../device_mode_screen.dart';

/// Décision pure (testable) : faut-il armer le re-verrouillage automatique ?
/// Uniquement en poste PARTAGÉ, avec un agent réellement actif, ET un délai > 0
/// (0 = désactivé par réglage). En personnel ou vitrine déjà affichée → non.
bool shouldArmAutoLock({
  required DeviceMode? mode,
  required bool hasActiveAgent,
  int minutes = kAutoLockDefaultMinutes,
}) =>
    mode == DeviceMode.shared && hasActiveAgent && minutes > 0;

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
        // Détecteur d'inactivité : re-verrouille un poste partagé abandonné.
        _InactivityAutoLock(child: child),
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

/// Enveloppe l'app et re-verrouille un poste PARTAGÉ après [kAutoLockIdle] sans
/// interaction (souris ou clavier). Le re-verrouillage se limite à effacer
/// l'agent actif → la vitrine revient et réclame le PIN. Il NE déconnecte PAS
/// la session appareil et NE purge RIEN : le travail hors-ligne est préservé
/// (cf. « Verrouiller ≠ Déconnecter »).
class _InactivityAutoLock extends ConsumerStatefulWidget {
  const _InactivityAutoLock({required this.child});
  final Widget child;
  @override
  ConsumerState<_InactivityAutoLock> createState() =>
      _InactivityAutoLockState();
}

class _InactivityAutoLockState extends ConsumerState<_InactivityAutoLock> {
  Timer? _timer;

  int get _minutes => ref.read(autoLockMinutesProvider);

  bool get _armed => shouldArmAutoLock(
        mode: ref.read(deviceModeProvider).mode,
        hasActiveAgent: ref.read(selectedAgentIdProvider) != null,
        minutes: _minutes,
      );

  /// Repousse l'échéance à chaque interaction ; désarme si non pertinent.
  void _bump() {
    _timer?.cancel();
    if (_armed) _timer = Timer(Duration(minutes: _minutes), _lock);
  }

  void _lock() {
    // Efface juste l'agent actif → re-verrouillage. Aucune déconnexion/purge.
    if (ref.read(selectedAgentIdProvider) != null) {
      ref.read(selectedAgentIdProvider.notifier).state = null;
    }
  }

  bool _onKey(KeyEvent _) {
    _bump();
    return false; // ne consomme pas l'évènement
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // Armer après le premier frame (providers lisibles).
    WidgetsBinding.instance.addPostFrameCallback((_) => _bump());
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ré-arme quand l'agent actif ou le mode d'appareil change (ne se déclenche
    // que sur changement réel, pas à chaque frame).
    ref.listen(selectedAgentIdProvider, (_, _) => _bump());
    ref.listen(deviceModeProvider, (_, _) => _bump());
    ref.listen(autoLockMinutesProvider, (_, _) => _bump());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _bump(),
      onPointerMove: (_) => _bump(),
      onPointerSignal: (_) => _bump(),
      child: widget.child,
    );
  }
}
