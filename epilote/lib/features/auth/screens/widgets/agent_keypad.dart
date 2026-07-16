import 'package:flutter/material.dart';

import 'auth_colors.dart';

/// Pavé numérique de l'écran-verrou (thème sombre, sur la feuille bleu nuit).
/// PIN à 4 chiffres → auto-validation, donc **pas de bouton valider** : bas de
/// pavé = [·] [0] [⌫] (convention iOS/Android). [enabled] false pendant une
/// pause anti-force-brute.
class AgentKeypad extends StatelessWidget {
  const AgentKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in children)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                ),
            ],
          ),
        );

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            row([for (final d in line) _DigitKey(d, enabled ? onDigit : null)]),
          row([
            const SizedBox(width: 66, height: 54),
            _DigitKey('0', enabled ? onDigit : null),
            _IconKey(
              icon: Icons.backspace_outlined,
              onTap: enabled ? onBackspace : null,
              semantic: 'Effacer',
            ),
          ]),
        ],
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, this.onDigit);
  final String digit;
  final ValueChanged<String>? onDigit;

  @override
  Widget build(BuildContext context) => _KeyShell(
        onTap: onDigit == null ? null : () => onDigit!(digit),
        semantic: digit,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
}

class _IconKey extends StatelessWidget {
  const _IconKey({required this.icon, this.onTap, required this.semantic});
  final IconData icon;
  final VoidCallback? onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) => _KeyShell(
        onTap: onTap,
        semantic: semantic,
        child: Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.85)),
      );
}

class _KeyShell extends StatelessWidget {
  const _KeyShell({required this.child, this.onTap, required this.semantic});
  final Widget child;
  final VoidCallback? onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantic,
        child: SizedBox(
          width: 66,
          height: 54,
          child: Material(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(kAuthRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(kAuthRadius),
              // Curseur main sur toute touche active (règle : tout cliquable).
              mouseCursor: onTap == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
        ),
      );
}
