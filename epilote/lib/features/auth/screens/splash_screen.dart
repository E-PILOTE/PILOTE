import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── Palette — cohérente avec auth_colors.dart ────────────────────────────────
Color get _kPrimaryDeep => kNavyDeep;
Color get _kPrimaryDark => kNavyDark;
Color get _kPrimary => kNavy;
Color get _kCongoGreen => kGreen;
const Color _kCongoYellow  = Color(0xFFFCDD09);
Color get _kCongoRed => kRed;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ─── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _main;    // 3200 ms — séquence principale
  late final AnimationController _pulse;   // 2000 ms repeat — halo logo
  late final AnimationController _dots;    // 800 ms repeat  — loader dots
  late final AnimationController _shimmer; // 2600 ms repeat — titre shimmer

  // ─── Animations staggerées ────────────────────────────────────────────────
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _flagFade;
  late final Animation<double> _progressFade;
  late final Animation<double> _progressVal;
  late final Animation<double> _dotsFade;
  late final Animation<double> _footerFade;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..forward();

    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _dots = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();

    _shimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();

    // ── Séquence staggerée ───────────────────────────────────────────────────
    _logoFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.00, 0.18, curve: Curves.easeIn));

    _logoScale = Tween<double>(begin: 0.15, end: 1.0).animate(
        CurvedAnimation(parent: _main,
            curve: const Interval(0.00, 0.30, curve: Curves.elasticOut)));

    _ringFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.18, 0.40, curve: Curves.easeOut));

    _titleFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.26, 0.46, curve: Curves.easeOut));

    _titleSlide = Tween<Offset>(
        begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(parent: _main,
            curve: const Interval(0.26, 0.46, curve: Curves.easeOut)));

    _subtitleFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.38, 0.55, curve: Curves.easeOut));

    _flagFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.48, 0.63, curve: Curves.easeOut));

    _progressFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.58, 0.70, curve: Curves.easeOut));

    _progressVal = CurvedAnimation(parent: _main,
        curve: const Interval(0.62, 0.99, curve: Curves.easeInOut));

    _dotsFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.64, 0.76, curve: Curves.easeOut));

    _footerFade = CurvedAnimation(parent: _main,
        curve: const Interval(0.72, 0.86, curve: Curves.easeOut));

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmer, curve: Curves.easeInOut));

    // Stopper les loopers quand l'écran est quitté (routeur prend la main)
    _main.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dots.stop();
      }
    });
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    _dots.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimaryDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Toutes les tailles sont responsives
          final logoSz   = (math.min(w, h) * 0.12).clamp(80.0, 140.0);
          final ringOuter = logoSz * 1.46;
          final ringInner = logoSz * 1.24;
          final titleSz  = (math.min(w, h) * 0.042).clamp(26.0, 46.0);
          final subSz    = (math.min(w, h) * 0.018).clamp(11.0, 16.0);
          final progressW = (w * 0.26).clamp(220.0, 380.0);
          final gap1     = (h * 0.040).clamp(20.0, 50.0);
          final gap2     = (h * 0.008).clamp(6.0,  14.0);
          final gap3     = (h * 0.026).clamp(16.0, 36.0);
          final gap4     = (h * 0.055).clamp(32.0, 72.0);

          return Stack(children: [
            // ── Fond ──────────────────────────────────────────────────────
            Positioned.fill(child: _buildBackground(logoSz, ringOuter)),

            // ── Contenu centré ────────────────────────────────────────────
            Center(
              child: _buildCenter(
                logoSz: logoSz,
                ringOuter: ringOuter,
                ringInner: ringInner,
                titleSz: titleSz,
                subSz: subSz,
                progressW: progressW,
                gap1: gap1, gap2: gap2, gap3: gap3, gap4: gap4,
              ),
            ),

            // ── Footer institutionnel ──────────────────────────────────────
            Positioned(
              bottom: (h * 0.034).clamp(18.0, 36.0),
              left: 0, right: 0,
              child: FadeTransition(
                opacity: _footerFade,
                child: Column(children: [
                  Text(
                    "Agréée par le Ministère de l'Éducation  ·  République du Congo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF4A6580),
                      fontSize: subSz * 0.80,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: (h * 0.005).clamp(3.0, 6.0)),
                  Text(
                    'MEPSA  ·  METP  ·  v3.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF2E4A62),
                      fontSize: subSz * 0.72,
                      letterSpacing: 0.5,
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── FOND ───────────────────────────────────────────────────────────────────
  Widget _buildBackground(double logoSz, double ringOuter) {
    return Stack(children: [
      // Gradient diagonal principal
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kPrimaryDeep, _kPrimaryDark, _kPrimary],
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

      // Halo vert Congo pulsant derrière le logo
      Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) => FadeTransition(
            opacity: _ringFade,
            child: Container(
              width:  ringOuter * 1.6 + _pulse.value * 40,
              height: ringOuter * 1.6 + _pulse.value * 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _kCongoGreen.withValues(alpha: 0.09 - _pulse.value * 0.04),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ),

      // Ligne tricolore verticale gauche — signature Congo
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
                _kCongoGreen.withValues(alpha: 0.60),
                _kCongoYellow.withValues(alpha: 0.50),
                _kCongoRed.withValues(alpha: 0.40),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),

      // Grille de points décoratifs
      const Positioned.fill(child: CustomPaint(painter: _SplashDotPainter())),
    ]);
  }

  // ── CENTRE ─────────────────────────────────────────────────────────────────
  Widget _buildCenter({
    required double logoSz,
    required double ringOuter,
    required double ringInner,
    required double titleSz,
    required double subSz,
    required double progressW,
    required double gap1,
    required double gap2,
    required double gap3,
    required double gap4,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── Logo texte (SVG remplacé — filtre non supporté) ──────────────
        ScaleTransition(
          scale: _logoScale,
          child: FadeTransition(
            opacity: _logoFade,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anneau externe pulsant
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Container(
                    width:  ringOuter + _pulse.value * 12,
                    height: ringOuter + _pulse.value * 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _kCongoGreen.withValues(
                            alpha: 0.13 + _pulse.value * 0.11),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // Anneau intérieur fixe
                Container(
                  width: ringInner, height: ringInner,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                // Logo SVG officiel (filtres retirés pour flutter_svg)
                SvgPicture.asset(
                  'assets/icons/logo.svg',
                  width: logoSz,
                  height: logoSz,
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: gap1),

        // ── Titre avec shimmer ────────────────────────────────────────────
        FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleSlide,
            child: AnimatedBuilder(
              animation: _shimmerAnim,
              builder: (_, child) => ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    Colors.white,
                    Color(0xFFE8F0F8),
                    Colors.white,
                    Color(0xFFCFE2F3),
                  ],
                  stops: [
                    (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                    _shimmerAnim.value.clamp(0.0, 1.0),
                    (_shimmerAnim.value + 0.1).clamp(0.0, 1.0),
                    (_shimmerAnim.value + 0.4).clamp(0.0, 1.0),
                  ],
                ).createShader(rect),
                child: child!,
              ),
              child: Text(
                'E-PILOTE CONGO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSz,
                  fontWeight: FontWeight.w800,
                  letterSpacing: titleSz * 0.16,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: gap2),

        // ── Sous-titre ────────────────────────────────────────────────────
        FadeTransition(
          opacity: _subtitleFade,
          child: Text(
            'Plateforme Nationale de Gestion Scolaire',
            style: TextStyle(
              color: const Color(0xFF6B8BA4),
              fontSize: subSz,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        SizedBox(height: gap3),

        // ── Badge drapeau Congo (CORRECT : Vert–Jaune–Rouge) ─────────────
        FadeTransition(
          opacity: _flagFade,
          child: _buildFlagBadge(subSz),
        ),

        SizedBox(height: gap4),

        // ── Barre de progression tricolore ────────────────────────────────
        FadeTransition(
          opacity: _progressFade,
          child: _buildProgressBar(progressW, subSz),
        ),

        SizedBox(height: gap2 * 2),

        // ── Dots loader ───────────────────────────────────────────────────
        FadeTransition(
          opacity: _dotsFade,
          child: _buildDots(),
        ),
      ],
    );
  }

  // ── BADGE DRAPEAU ──────────────────────────────────────────────────────────
  // Drapeau Congo correct : Vert – Jaune – Rouge (gauche → droite)
  Widget _buildFlagBadge(double subSz) {
    final flagColors = [_kCongoGreen, _kCongoYellow, _kCongoRed];
    final flagH = (subSz * 1.3).clamp(14.0, 20.0);
    final flagW = (flagH * 0.44).clamp(5.5, 9.0);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: subSz * 1.6, vertical: subSz * 0.8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drapeau gauche — Vert–Jaune–Rouge ✓
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: flagColors
                  .map((c) => Container(width: flagW, height: flagH, color: c))
                  .toList(),
            ),
          ),
          SizedBox(width: subSz),
          Text(
            'République du Congo',
            style: TextStyle(
              color: const Color(0xFF8AAFC8),
              fontSize: subSz * 0.90,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: subSz),
          // Drapeau droit — identique (pas de miroir)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: flagColors
                  .map((c) => Container(width: flagW, height: flagH, color: c))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── BARRE PROGRESSION ──────────────────────────────────────────────────────
  Widget _buildProgressBar(double progressW, double subSz) {
    return SizedBox(
      width: progressW,
      child: AnimatedBuilder(
        animation: _progressVal,
        builder: (_, _) {
          final v = _progressVal.value;
          final label = v < 0.25 ? 'Initialisation de la plateforme...'
              : v < 0.50 ? 'Vérification des accès...'
              : v < 0.80 ? 'Chargement des modules...'
              : v < 0.98 ? 'Synchronisation des données...'
              : '✓  Prêt';

          return Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [_kCongoGreen, _kCongoYellow, _kCongoRed],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kCongoGreen.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: subSz * 0.9),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF4E6B84),
                  fontSize: subSz * 0.82,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── DOTS LOADER ────────────────────────────────────────────────────────────
  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final v = math.sin(
            (_dots.value * math.pi * 2) - (i * math.pi * 0.66),
          ).abs();
          return Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCongoGreen.withValues(alpha: 0.2 + v * 0.8),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Grille de points décorative (static — shouldRepaint: false) ──────────────
class _SplashDotPainter extends CustomPainter {
  const _SplashDotPainter();

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
  bool shouldRepaint(_SplashDotPainter _) => false;
}
