import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_colors.dart';
import 'login_anim_widgets.dart';
import 'login_stat_widgets.dart';

// ─── Données statiques ────────────────────────────────────────────────────────

const _kPhrases = [
  ['TRANSFORMEZ VOTRE ÉCOLE',   "EN INSTITUTION D'EXCELLENCE"],
  ['GÉREZ VOS ÉLÈVES',          'AVEC PRÉCISION ET SIMPLICITÉ'],
  ['SUPERVISEZ EN TEMPS RÉEL',  'LES PERFORMANCES SCOLAIRES'],
];

/// Features — (icône, couleur, titre, sous-titre)
const _kFeatures = [
  (Icons.hub_rounded,         kAuthCongoGreen,   'Gestion centralisée',  'Multi-établissements'),
  (Icons.people_alt_rounded,  Color(0xFF3B82F6), 'Collaboration fluide', 'Entre enseignants'),
  (Icons.shield_rounded,      kAuthCongoYellow,  'Données protégées',    'Chiffrement SSL'),
  (Icons.bolt_rounded,        Color(0xFFF97316), 'Temps réel',           'Sync instantanée'),
];

// ─── Hero Panel ───────────────────────────────────────────────────────────────

class LoginHeroPanel extends StatefulWidget {
  const LoginHeroPanel({super.key});

  @override
  State<LoginHeroPanel> createState() => _LoginHeroPanelState();
}

class _LoginHeroPanelState extends State<LoginHeroPanel>
    with SingleTickerProviderStateMixin {

  // ── Typewriter ──────────────────────────────────────────────────────────────
  int    _phraseIdx  = 0;
  int    _charCount  = 0;
  bool   _isDeleting = false;
  Timer? _timer;

  // ── Entrée animée ────────────────────────────────────────────────────────────
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(-0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _scheduleNext(delay: 800);
  }

  @override
  void dispose() { _timer?.cancel(); _anim.dispose(); super.dispose(); }

  void _scheduleNext({int delay = 65}) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delay), _tick);
  }

  void _tick() {
    if (!mounted) return;
    final phrase   = _kPhrases[_phraseIdx];
    final totalLen = phrase[0].length + phrase[1].length;
    setState(() {
      if (_isDeleting) {
        _charCount--;
        if (_charCount <= 0) {
          _charCount = 0; _isDeleting = false;
          _phraseIdx = (_phraseIdx + 1) % _kPhrases.length;
          _scheduleNext(delay: 400);
        } else { _scheduleNext(delay: 32); }
      } else {
        _charCount++;
        if (_charCount >= totalLen) {
          _charCount = totalLen; _isDeleting = true;
          _scheduleNext(delay: 2800);
        } else { _scheduleNext(delay: 65); }
      }
    });
  }

  String _line1() {
    final p = _kPhrases[_phraseIdx][0];
    return _charCount >= p.length ? p : p.substring(0, _charCount);
  }

  String _line2() {
    final p0 = _kPhrases[_phraseIdx][0];
    final p1 = _kPhrases[_phraseIdx][1];
    if (_charCount <= p0.length) return '';
    return p1.substring(0, _charCount - p0.length);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // ── Toutes les tailles interpolées (largeur + hauteur) ───────────────
        // Plages étendues jusqu'à 1600/1200 pour couvrir les 27" et 4K.
        final hPad      = _lerp(w, 480, 1600, 20.0, 60.0);
        final titleSz   = _lerp2(w, h, 480, 1600, 400, 1200, 18.0, 42.0);
        final greetSz   = _lerp2(w, h, 480, 1600, 400, 1200, 17.0, 30.0);
        final subSz     = _lerp(w, 480, 1600, 10.0, 14.5);
        final emojiSz   = _lerp2(w, h, 480, 1600, 400, 1200, 20.0, 36.0);
        final spacingMd = _lerp2(w, h, 480, 1600, 400, 1200, 5.0, 18.0);

        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              width:  w,
              height: h,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.centerRight,
                  colors: [
                    kAuthNavyDeep.withValues(alpha: 0.90),
                    kAuthNavyDark.withValues(alpha: 0.55),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── En-tête — centré verticalement dans son espace flex ────
                  // Expanded croît avec l'écran. ClipRect absorbe silencieusement
                  // tout dépassement sur les très petits écrans.
                  Expanded(
                    flex: 25,
                    child: ClipRect(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            _greeting(greetSz, subSz, emojiSz),
                            SizedBox(height: spacingMd * 1.2),
                            _typewriterBlock(titleSz),
                            if (h > 480) ...[
                              SizedBox(height: spacingMd * 0.8),
                              _description(w),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Séparateur respiratoire proportionnel
                  SizedBox(height: (h * 0.022).clamp(8.0, 24.0)),

                  // ── Stats 2×2 — s'étend proportionnellement à la hauteur ───
                  Expanded(
                    flex: 31,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _statsSection(),
                    ),
                  ),

                  SizedBox(height: spacingMd),

                  // ── Séparateur tricolore ──────────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _separator(),
                  ),

                  SizedBox(height: spacingMd),

                  // ── Features 2×2 — s'étend proportionnellement ───────────
                  // FeatureCard gère l'overflow via innerH — aucun risque
                  Expanded(
                    flex: 28,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _featuresSection(),
                    ),
                  ),

                  SizedBox(height: (h * 0.012).clamp(4.0, 14.0)),

                  // ── Crédibilité — toujours visible, flex restant = 0 ──────
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                    child: _credibilityRow(),
                  ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _lerp(double x, double xMin, double xMax, double vMin, double vMax) {
    if (x <= xMin) return vMin;
    if (x >= xMax) return vMax;
    return vMin + (vMax - vMin) * ((x - xMin) / (xMax - xMin));
  }

  /// Interpolation bilinéaire : dépend à la fois de w et de h.
  double _lerp2(double w, double h,
      double wMin, double wMax,
      double hMin, double hMax,
      double vMin, double vMax) {
    final tw = ((w - wMin) / (wMax - wMin)).clamp(0.0, 1.0);
    final th = ((h - hMin) / (hMax - hMin)).clamp(0.0, 1.0);
    final t  = (tw + th) / 2.0;
    return vMin + (vMax - vMin) * t;
  }

  // ── Salutation dynamique selon l'heure ──────────────────────────────────────
  Widget _greeting(double greetSz, double subSz, double emojiSz) {
    final hour = DateTime.now().hour;
    final String text  = hour >= 5 && hour < 12 ? 'Bonjour'
        : hour >= 12 && hour < 18 ? 'Bon après-midi'
        : hour >= 18 && hour < 22 ? 'Bonsoir'
        : 'Bonne nuit';
    final String emoji = hour >= 5 && hour < 12 ? '☀️'
        : hour >= 12 && hour < 18 ? '🌤️'
        : hour >= 18 && hour < 22 ? '🌆'
        : '🌙';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(emoji, style: TextStyle(fontSize: emojiSz)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: TextStyle(
                  color: Colors.white, fontSize: greetSz,
                  fontWeight: FontWeight.w800,
                )),
            Text('Bienvenue sur E-PILOTE Congo',
                style: TextStyle(
                  color: const Color(0xFF7A9AB5), fontSize: subSz,
                )),
          ],
        ),
      ],
    );
  }

  // ── Typewriter ─────────────────────────────────────────────────────────────
  Widget _typewriterBlock(double fontSize) {
    final l1 = _line1();
    final l2 = _line2();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l1.isEmpty ? '​' : l1,
          style: TextStyle(
            color: Colors.white, fontSize: fontSize,
            fontWeight: FontWeight.w900, height: 1.15, letterSpacing: 0.3,
          ),
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                l2.isEmpty && l1.isNotEmpty ? '​' : l2,
                style: TextStyle(
                  color: kAuthCongoGreen, fontSize: fontSize,
                  fontWeight: FontWeight.w900, height: 1.15, letterSpacing: 0.3,
                ),
              ),
            ),
            _BlinkingCursor(
              color: l1.length < _kPhrases[_phraseIdx][0].length
                  ? Colors.white : kAuthCongoGreen,
            ),
          ],
        ),
      ],
    );
  }

  // ── Description responsive ──────────────────────────────────────────────────
  Widget _description(double w) {
    final sz = _lerp(w, 480, 1600, 11.0, 15.0);
    return Text(
      'La plateforme de gestion scolaire la plus avancée du Congo. '
      'Moderne, sécurisée, performante.',
      style: TextStyle(
        color: const Color(0xFF7A9AB5), fontSize: sz, height: 1.55,
      ),
    );
  }

  // ── Stats 2×2 avec widgets différenciés ────────────────────────────────────
  Widget _statsSection() {
    return const Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: StatArcCard()),
              SizedBox(width: 8),
              Expanded(child: StatRadialCard()),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: StatColumnCard()),
              SizedBox(width: 8),
              Expanded(child: StatPyramidCard()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Séparateur — diviseur avec 3 points tricolores ─────────────────────────
  Widget _separator() {
    return Row(
      children: [
        Expanded(child: Divider(
            color: Colors.white.withValues(alpha: 0.10), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [kAuthCongoGreen, kAuthCongoYellow, kAuthCongoRed]
                .map((c) => Container(
                      width: 5, height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.withValues(alpha: 0.55),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(child: Divider(
            color: Colors.white.withValues(alpha: 0.10), height: 1)),
      ],
    );
  }

  // ── Features 2×2 animées ────────────────────────────────────────────────────
  Widget _featuresSection() {
    const delays = [800, 960, 1120, 1280];
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: FeatureCard(data: _kFeatures[0], delayMs: delays[0])),
              const SizedBox(width: 8),
              Expanded(child: FeatureCard(data: _kFeatures[1], delayMs: delays[1])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: FeatureCard(data: _kFeatures[2], delayMs: delays[2])),
              const SizedBox(width: 8),
              Expanded(child: FeatureCard(data: _kFeatures[3], delayMs: delays[3])),
            ],
          ),
        ),
      ],
    );
  }

  // ── Ligne de crédibilité (sans étoiles — déplacées en bas de page) ──────────
  Widget _credibilityRow() {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: kAuthCongoGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
                color: kAuthCongoGreen.withValues(alpha: 0.35), width: 1.2),
          ),
          child: const Icon(Icons.verified_rounded, size: 15, color: kAuthCongoGreen),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conforme aux normes internationales · ISO 27001',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white, fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  )),
              Text('MEPSA · METP · République du Congo',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF5A7A92), fontSize: 9.5)),
            ],
          ),
        ),
        // Badge SSL compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: kAuthCongoGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: kAuthCongoGreen.withValues(alpha: 0.25), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 9, color: kAuthCongoGreen),
              SizedBox(width: 3),
              Text('SSL', style: TextStyle(
                  color: kAuthCongoGreen, fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Curseur clignotant ────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});
  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: _ctrl.value > 0.5 ? 1.0 : 0.0,
        child: Container(
          width: 2.5, height: 28,
          margin: const EdgeInsets.only(left: 3, top: 2),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
