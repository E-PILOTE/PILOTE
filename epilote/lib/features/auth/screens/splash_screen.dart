import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'widgets/splash_decor.dart';
import 'widgets/splash_pied.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉCRAN DE DÉMARRAGE — 3,2 s, et il ne doit dire chaque chose QU'UNE FOIS
//
//  ── CE QUI N'ALLAIT PAS (constaté le 2026-09-06) ──────────────────────────
//  L'écran affichait `logo.svg`, qui n'est pas une icône mais un BLOC COMPLET :
//  il porte déjà, gravés dedans, les mots « E-PILOTE », « CONGO », « GESTION
//  SCOLAIRE » et une barre tricolore. À 46 px (barre de connexion, en-tête de
//  PDF) ces mots sont illisibles et le bloc se lit comme une icône. Ici il
//  était affiché entre 80 et 140 px : tout redevenait lisible.
//
//  Le même écran empilait alors :
//
//     dans le rond  « E-PILOTE » + « CONGO » + « GESTION SCOLAIRE » + tricolore
//     dessous       « E-PILOTE CONGO » jusqu'en 46 px
//     dessous       « Plateforme Nationale de Gestion Scolaire »
//     dessous       [drapeau] République du Congo [drapeau]   ← deux fois
//     dessous       barre de progression tricolore
//     à gauche      liseré vertical tricolore
//     en pied       « … · République du Congo »              ← le pays, 2ᵉ fois
//
//  Le nom du produit TROIS fois, sa vocation DEUX fois, le pays DEUX fois, les
//  couleurs nationales CINQ fois. Et quatre cercles concentriques autour d'un
//  logo qui portait déjà les siens.
//
//  ── LA RÈGLE APPLIQUÉE ────────────────────────────────────────────────────
//  Une idée, un endroit, une fois.
//
//     la marque   →  `logo_marque.svg` : le même dessin, SANS un seul mot
//     le nom      →  le titre, en typographie, avec son reflet
//     la vocation →  le sous-titre
//     le pays     →  le badge, avec UN drapeau entier
//     la tutelle  →  le pied
//     la version  →  lue dans le binaire, plus jamais tapée
//
//  Rien n'a été retiré de ce que l'écran DIT : seules les répétitions sont
//  parties. Le propos tient, il ne bégaie plus.
// ════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ─── Contrôleurs ──────────────────────────────────────────────────────────
  late final AnimationController _main;    // 3200 ms — séquence principale
  late final AnimationController _pulse;   // 2000 ms repeat — souffle du halo
  late final AnimationController _dots;    // 800 ms repeat  — points de charge
  late final AnimationController _shimmer; // 2600 ms repeat — reflet du titre

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

    // 3200 ms : exactement la durée minimale tenue par `auth_provider.dart`.
    // Les deux doivent rester égales — sinon la séquence se coupe en plein
    // milieu, ou l'écran reste figé après sa fin.
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

    // ── Séquence staggerée ──────────────────────────────────────────────────
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

    // Les boucles s'arrêtent quand la séquence est finie : le routeur prend la
    // main, plus personne ne regarde. Inutile de faire tourner trois
    // contrôleurs pendant que l'écran suivant se construit — c'est justement
    // le moment où la machine a le plus à faire.
    _main.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dots.stop();
        _pulse.stop();
        _shimmer.stop();
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
      backgroundColor: splashFond,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Toutes les tailles sont responsives
          // 0,145 et non 0,12 : le bloc complet paraissait plus gros qu'il
          // n'était parce qu'il était REMPLI (trois lignes de texte). La
          // marque nue, à la même taille, se perdait sous un titre de 46 px.
          final logoSz    = (math.min(w, h) * 0.145).clamp(96.0, 168.0);
          final ringOuter = logoSz * 1.46;
          final titleSz   = (math.min(w, h) * 0.042).clamp(26.0, 46.0);
          final subSz     = (math.min(w, h) * 0.018).clamp(11.0, 16.0);
          final progressW = (w * 0.26).clamp(220.0, 380.0);
          final gap1      = (h * 0.040).clamp(20.0, 50.0);
          final gap2      = (h * 0.008).clamp(6.0,  14.0);
          final gap3      = (h * 0.026).clamp(16.0, 36.0);
          final gap4      = (h * 0.055).clamp(32.0, 72.0);

          return Stack(children: [
            Positioned.fill(
              child: SplashDecor(
                pulse: _pulse,
                haloFade: _ringFade,
                diametreHalo: ringOuter * 1.6,
              ),
            ),

            Center(
              child: _contenu(
                logoSz: logoSz,
                ringOuter: ringOuter,
                titleSz: titleSz,
                subSz: subSz,
                progressW: progressW,
                gap1: gap1, gap2: gap2, gap3: gap3, gap4: gap4,
              ),
            ),

            Positioned(
              bottom: (h * 0.034).clamp(18.0, 36.0),
              left: 0, right: 0,
              child: Align(
                child: SplashPied(opacity: _footerFade, subSz: subSz),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── CONTENU CENTRAL ────────────────────────────────────────────────────────
  Widget _contenu({
    required double logoSz,
    required double ringOuter,
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
        _marque(logoSz, ringOuter),
        SizedBox(height: gap1),
        _titre(titleSz),
        SizedBox(height: gap2),
        _sousTitre(subSz),
        SizedBox(height: gap3),
        FadeTransition(opacity: _flagFade, child: _badgePays(subSz)),
        SizedBox(height: gap4),
        FadeTransition(
            opacity: _progressFade, child: _progression(progressW, subSz)),
        SizedBox(height: gap2 * 2),
        FadeTransition(opacity: _dotsFade, child: _points()),
      ],
    );
  }

  // ── LA MARQUE ──────────────────────────────────────────────────────────────
  //
  // ⚠️ `logo_marque.svg`, PAS `logo.svg` : la variante sans texte. Voir
  // l'en-tête du fichier — c'est toute la correction de cet écran.
  //
  // La marque porte DÉJÀ deux anneaux dessinés dans le SVG (le vert plein et le
  // pointillé). L'écran n'en ajoute donc plus qu'UN, qui respire, à distance.
  // Le disque blanc intermédiaire qui traînait entre les deux ne faisait qu'un
  // cerne de plus autour d'un logo qui n'en demandait pas.
  Widget _marque(double logoSz, double ringOuter) {
    return ScaleTransition(
      scale: _logoScale,
      child: FadeTransition(
        opacity: _logoFade,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => FadeTransition(
                opacity: _ringFade,
                child: Container(
                  width:  ringOuter + _pulse.value * 12,
                  height: ringOuter + _pulse.value * 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: splashVert.withValues(
                          alpha: 0.13 + _pulse.value * 0.11),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/icons/logo_marque.svg',
              width: logoSz,
              height: logoSz,
            ),
          ],
        ),
      ),
    );
  }

  // ── LE NOM ─────────────────────────────────────────────────────────────────
  Widget _titre(double titleSz) {
    return FadeTransition(
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
    );
  }

  // ── LA VOCATION ────────────────────────────────────────────────────────────
  Widget _sousTitre(double subSz) {
    return FadeTransition(
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
    );
  }

  // ── LE PAYS ────────────────────────────────────────────────────────────────
  //
  // UN drapeau, à gauche du nom, dans le sens de lecture. Il y en avait deux,
  // identiques — pas même en miroir — de part et d'autre du texte. La symétrie
  // coûtait un doublon, et le second drapeau n'ajoutait rien que le premier ne
  // disait déjà. Vert–Jaune–Rouge : l'ordre du drapeau congolais.
  Widget _badgePays(double subSz) {
    final flagH = (subSz * 1.3).clamp(14.0, 20.0);
    final flagW = (flagH * 0.44).clamp(5.5, 9.0);

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: subSz * 1.6, vertical: subSz * 0.8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [splashVert, splashJaune, splashRouge]
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
        ],
      ),
    );
  }

  // ── LA PROGRESSION ─────────────────────────────────────────────────────────
  //
  // 330 px de long pour 3 de haut : à ce rapport, le vert-jaune-rouge ne se lit
  // plus comme un drapeau mais comme une ligne de lumière. C'est pour ça qu'il
  // peut rester ici alors que le badge, lui, porte le vrai drapeau.
  Widget _progression(double progressW, double subSz) {
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
                          colors: [splashVert, splashJaune, splashRouge],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: splashVert.withValues(alpha: 0.45),
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

  // ── LES POINTS ─────────────────────────────────────────────────────────────
  Widget _points() {
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
              color: splashVert.withValues(alpha: 0.2 + v * 0.8),
            ),
          );
        }),
      ),
    );
  }
}
