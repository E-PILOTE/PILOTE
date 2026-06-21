import 'package:flutter/material.dart';

import 'admin_ui.dart';

/// Drapeau de la République du Congo (Brazzaville) — division diagonale
/// vert (haut-gauche) · bande jaune diagonale · rouge (bas-droite).
/// Dessiné en code (aucun asset requis), aux couleurs officielles de la
/// plateforme (kGreen / kAccent / kRed). Réutilisable (bandeaux, en-têtes).
class CongoFlag extends StatelessWidget {
  const CongoFlag({super.key, this.width = 44, this.height = 30, this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _CongoFlagPainter()),
      ),
    );
  }
}

class _CongoFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()..style = PaintingStyle.fill;

    // Vert : triangle haut-gauche (0,0)-(w,0)-(0,h)
    p.color = kGreen;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(0, h)
        ..close(),
      p,
    );

    // Rouge : triangle bas-droite (w,0)-(w,h)-(0,h)
    p.color = kRed;
    canvas.drawPath(
      Path()
        ..moveTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      p,
    );

    // Jaune : bande diagonale le long de (0,h)→(w,0)
    final band = w * 0.34;
    p.color = kAccent;
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(band, h)
        ..lineTo(w, 0)
        ..lineTo(w - band, 0)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
