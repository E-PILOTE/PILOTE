import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'auth_colors.dart';
import 'login_anim_widgets.dart';

/// Fond plein écran de l'écran-verrou : langage visuel du login, sobre et
/// institutionnel. Filigrane logo E-PILOTE en « respiration » très lente +
/// ligne tricolore animée. Aucun clignotement.
class AgentLockBackground extends StatefulWidget {
  const AgentLockBackground({super.key});

  @override
  State<AgentLockBackground> createState() => _AgentLockBackgroundState();
}

class _AgentLockBackgroundState extends State<AgentLockBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient diagonal (login).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kAuthNavyDeep, kAuthNavyDark, kAuthNavy],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Grille de points décorative.
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
        // Filigrane logo qui respire (échelle 1.0↔1.04, opacité ~5,5 %).
        Center(
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_breath.value);
              return Opacity(
                opacity: 0.04 + 0.02 * t,
                child: Transform.scale(scale: 1.0 + 0.04 * t, child: child),
              );
            },
            child: SvgPicture.asset(
              'assets/icons/logo.svg',
              width: 460,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
        // Voile tricolore qui dérive lentement (très discret).
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, _) => CustomPaint(
              painter: _TricolorVeilPainter(phase: _breath.value),
            ),
          ),
        ),
        // Ligne tricolore animée en bas (réutilisée du login).
        const Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedTricolorLine(height: 3),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);
    const spacing = 36.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}

class _TricolorVeilPainter extends CustomPainter {
  _TricolorVeilPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final dy = math.sin(phase * 2 * math.pi) * 0.04;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1, -1 + dy),
        end: Alignment(1, 1 + dy),
        colors: [
          kAuthCongoGreen.withValues(alpha: 0.06),
          Colors.transparent,
          kAuthCongoYellow.withValues(alpha: 0.05),
          Colors.transparent,
          kAuthCongoRed.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_TricolorVeilPainter old) => old.phase != phase;
}
