import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_agent_provider.dart';
import 'widgets/agent_lock_background.dart';

const _kAccent = Color(0xFF3B8CFF);

/// Sélecteur du mode d'appareil, affiché une fois après la connexion du
/// personnel. Détermine si ce poste est **partagé** (verrou + bascule d'agent)
/// ou **personnel** (aucun verrou). Modifiable ensuite dans Paramètres.
class DeviceModeScreen extends ConsumerWidget {
  const DeviceModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AgentLockBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.devices_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text('Comment cet ordinateur est-il utilisé ?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                          'On configure la sécurité en conséquence. '
                          'Modifiable à tout moment dans les Paramètres.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13)),
                      const SizedBox(height: 24),
                      LayoutBuilder(builder: (context, c) {
                        final cards = [
                          _ModeCard(
                            icon: Icons.groups_rounded,
                            title: 'Poste partagé',
                            desc: 'Plusieurs agents utilisent ce même '
                                'ordinateur. Chacun ouvre sa session avec un '
                                'code PIN — les saisies sont attribuées à la '
                                'bonne personne.',
                            recommended: true,
                            onTap: () =>
                                _choose(ref, DeviceMode.shared),
                          ),
                          _ModeCard(
                            icon: Icons.person_rounded,
                            title: 'Poste personnel',
                            desc: 'Un seul agent utilise cet ordinateur. '
                                'Aucun verrou : vous travaillez directement '
                                'avec votre compte, sans code à chaque fois.',
                            recommended: false,
                            onTap: () =>
                                _choose(ref, DeviceMode.personal),
                          ),
                        ];
                        return c.maxWidth > 560
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 16),
                                    Expanded(child: cards[1]),
                                  ],
                                ),
                              )
                            : Column(children: [
                                cards[0],
                                const SizedBox(height: 16),
                                cards[1],
                              ]);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _choose(WidgetRef ref, DeviceMode mode) =>
      ref.read(deviceModeProvider.notifier).set(mode);
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.recommended,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String desc;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                width: recommended ? 1.5 : 1,
                color: recommended
                    ? _kAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.16)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const Spacer(),
                  if (recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Recommandé',
                          style: TextStyle(
                              color: _kAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(desc,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.4)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Choisir',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 15, color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
