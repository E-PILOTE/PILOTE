import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉCOR DE L'ÉCRAN DE DÉMARRAGE — ce qui est derrière, et rien d'autre
//
//  Sorti de `splash_screen.dart` (575 lignes) pour deux raisons : la règle des
//  500 lignes, et surtout parce que le fond et le contenu ne se relisent pas
//  ensemble. Le fond est une AMBIANCE ; le contenu est un DISCOURS. Les mêler
//  dans un fichier est ce qui a permis au discours de se répéter sans que
//  personne le voie.
//
//  ── LES COULEURS NATIONALES, ICI ET AILLEURS ──────────────────────────────
//  Le vert-jaune-rouge apparaissait CINQ fois sur cet écran : dans le logo,
//  deux fois dans le badge, dans la barre de progression et dans le liseré
//  vertical. Cinq drapeaux ne font pas cinq fois plus de République ; ils font
//  un écran qui bégaie.
//
//  Règle tenue depuis : le drapeau se dit UNE fois, en entier, à sa place —
//  dans le badge, à côté du nom du pays. Partout ailleurs le tricolore n'est
//  plus un drapeau mais un ACCENT : le liseré vertical fait 3 px de large et
//  s'éteint aux deux bouts, la barre de progression fait 330 px de long pour
//  3 de haut. Aucun des deux n'a la forme d'un drapeau, et c'est voulu.
// ════════════════════════════════════════════════════════════════════════════

// ─── Palette de l'écran — suit le thème actif, sauf le jaune ────────────────
// Le jaune du drapeau congolais (#FCDD09) n'est pas le doré de la marque
// (#FBBC04) : l'un cite un drapeau, l'autre habille une toque. Ils ne doivent
// pas être confondus, donc pas partagés.
Color get splashFond   => kNavyDeep;
Color get splashFondMi => kNavyDark;
Color get splashFondHt => kNavy;
Color get splashVert   => kGreen;
Color get splashRouge  => kRed;
const Color splashJaune = Color(0xFFFCDD09);

/// Le fond complet : dégradé, profondeur, halo respirant, liseré, grille.
class SplashDecor extends StatelessWidget {
  const SplashDecor({
    super.key,
    required this.pulse,
    required this.haloFade,
    required this.diametreHalo,
  });

  /// Battement lent (2 s) partagé avec l'anneau du logo — même souffle.
  final Animation<double> pulse;

  /// Fait apparaître le halo en même temps que l'anneau du logo.
  final Animation<double> haloFade;

  final double diametreHalo;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Dégradé diagonal principal
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [splashFond, splashFondMi, splashFondHt],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),

      // Profondeur radiale centrale
      Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0x201E3A5F), Colors.transparent],
          ),
        ),
      ),

      // Halo vert respirant derrière la marque
      Center(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, _) => FadeTransition(
            opacity: haloFade,
            child: Container(
              width: diametreHalo + pulse.value * 40,
              height: diametreHalo + pulse.value * 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  splashVert.withValues(alpha: 0.09 - pulse.value * 0.04),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ),

      // Liseré vertical gauche — accent, pas drapeau (3 px, éteint aux bouts)
      Positioned(
        left: 0, top: 0, bottom: 0,
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                splashVert.withValues(alpha: 0.60),
                splashJaune.withValues(alpha: 0.50),
                splashRouge.withValues(alpha: 0.40),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),

      // Grille de points
      const Positioned.fill(child: CustomPaint(painter: SplashGrillePainter())),
    ]);
  }
}

/// Grille de points décorative — statique, ne se repeint jamais.
class SplashGrillePainter extends CustomPainter {
  const SplashGrillePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 38.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SplashGrillePainter _) => false;
}
