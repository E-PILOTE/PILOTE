import 'package:flutter/material.dart';

import 'auth_colors.dart';

// ─── FeatureCard — glass card avec entrée décalée + barre animée ──────────────

class FeatureCard extends StatefulWidget {
  const FeatureCard({
    super.key,
    required this.data,
    required this.delayMs,
  });

  final (IconData, Color, String, String) data;
  final int delayMs;

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _bar;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _bar   = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final f = widget.data;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: LayoutBuilder(
          builder: (_, c) {
            final h = c.maxHeight;

            // ── Padding vertical → hauteur intérieure réelle ─────────────────
            final vPad    = (h * 0.10).clamp(5.0, 12.0);
            final hPad    = (h * 0.12).clamp(8.0, 13.0);
            // Toutes les tailles sont basées sur innerH (sans padding),
            // pour garantir qu'aucun overflow ne survient quel que soit h.
            final innerH  = h - vPad * 2;
            // Icônes suffisamment grandes pour être lisibles (≥24px de boîte)
            final iconSz  = (innerH * 0.36).clamp(24.0, 34.0);
            final iconRad = (iconSz * 0.28).clamp(5.0, 9.0);
            final iconIco = (iconSz * 0.55).clamp(14.0, 19.0);
            final gap1    = (innerH * 0.05).clamp(2.0, 6.0);
            final gap2    = (innerH * 0.02).clamp(1.0, 3.0);
            final titleSz = (innerH * 0.14).clamp(9.5, 13.0);
            final subSz   = (innerH * 0.11).clamp(8.5, 10.5);
            // Barre dès que l'espace intérieur le permet
            const barH    = 2.5;
            final showBar = innerH >= 66;

            return Container(
              height: h,                      // force exactement la hauteur dispo
              clipBehavior: Clip.hardEdge,    // clip silencieux si contenu trop grand
              padding: EdgeInsets.symmetric(
                  horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône
                  Container(
                    width: iconSz, height: iconSz,
                    decoration: BoxDecoration(
                      color: f.$2.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(iconRad),
                      border: Border.all(
                          color: f.$2.withValues(alpha: 0.22), width: 1),
                    ),
                    child: Icon(f.$1, size: iconIco, color: f.$2),
                  ),
                  SizedBox(height: gap1),
                  // Titre
                  Text(f.$3,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white, fontSize: titleSz,
                        fontWeight: FontWeight.w700, height: 1.15,
                      )),
                  SizedBox(height: gap2),
                  // Sous-titre
                  Text(f.$4,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF8AAFC8), fontSize: subSz,
                        height: 1.15,
                      )),
                  // Barre animée (uniquement si espace intérieur suffisant)
                  if (showBar) ...[
                    SizedBox(height: gap1),
                    AnimatedBuilder(
                      animation: _bar,
                      builder: (_, _) => Stack(
                        children: [
                          Container(
                            height: barH,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _bar.value,
                            child: Container(
                              height: barH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  f.$2.withValues(alpha: 0.65),
                                  f.$2,
                                ]),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: f.$2.withValues(alpha: 0.45),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── AnimatedTricolorLine — ligne Congo qui défile en boucle ──────────────────
//
// Technique : gradient 2× la largeur + Translation (0 → -w) en boucle.
// Comme la séquence couleur se répète à mi-chemin, la transition est invisible.

class AnimatedTricolorLine extends StatefulWidget {
  const AnimatedTricolorLine({super.key, this.height = 3});
  final double height;

  @override
  State<AnimatedTricolorLine> createState() => _AnimatedTricolorLineState();
}

class _AnimatedTricolorLineState extends State<AnimatedTricolorLine>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            // child est const → ne sera pas reconstruit à chaque frame
            child: SizedBox(
              width: w * 2,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      kAuthCongoGreen,
                      kAuthCongoYellow,
                      kAuthCongoRed,
                      kAuthCongoGreen,
                      kAuthCongoYellow,
                      kAuthCongoRed,
                      kAuthCongoGreen,
                    ],
                    stops: [0.0, 0.167, 0.333, 0.5, 0.667, 0.833, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAuthCongoGreen.withValues(alpha: 0.55),
                      blurRadius: 8, spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: kAuthCongoYellow.withValues(alpha: 0.40),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: kAuthCongoRed.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            builder: (_, child) => Transform.translate(
              offset: Offset(-w * _ctrl.value, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
