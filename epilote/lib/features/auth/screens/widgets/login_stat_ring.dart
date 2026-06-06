import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─── Style des anneaux — chaque stat a son propre rendu visuel ────────────────

enum StatRingStyle {
  /// Arc 270° avec halo lumineux
  arc,
  /// Segments pointillés (24 tirets)
  dashed,
  /// Deux anneaux concentriques décalés
  concentric,
  /// Anneau complet avec gradient de couleur
  gradient,
}

// ─── StatRing ─────────────────────────────────────────────────────────────────

class StatRing extends StatefulWidget {
  const StatRing({
    super.key,
    required this.rawValue,
    required this.sublabel,
    required this.color,
    required this.size,
    this.style    = StatRingStyle.arc,
    this.showText = true,
  });

  final String        rawValue;
  final String        sublabel;
  final Color         color;
  final double        size;
  final StatRingStyle style;
  /// Si false : seul le painter est rendu (pas de texte superposé).
  final bool          showText;

  @override
  State<StatRing> createState() => _StatRingState();
}

class _StatRingState extends State<StatRing>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  late final int    _target;
  late final String _suffix;

  @override
  void initState() {
    super.initState();
    final raw = widget.rawValue
        .replaceAll(' ', '').replaceAll(' ', '').replaceAll(' ', '');
    _suffix = raw.endsWith('+') ? '+' : '';
    _target = int.tryParse(raw.replaceAll('+', '')) ?? 0;

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final current   = (_target * _anim.value).round();
        final numFontSz = widget.size * 0.22;
        final lblFontSz = (widget.size * 0.115).clamp(11.0, 15.0);

        final CustomPainter painter = switch (widget.style) {
          StatRingStyle.arc        => _ArcPainter(progress: _anim.value,       color: widget.color),
          StatRingStyle.dashed     => _DashedPainter(progress: _anim.value,    color: widget.color),
          StatRingStyle.concentric => _ConcentricPainter(progress: _anim.value, color: widget.color),
          StatRingStyle.gradient   => _GradientRingPainter(progress: _anim.value, color: widget.color),
        };

        return SizedBox(
          width: widget.size, height: widget.size,
          child: CustomPaint(
            painter: painter,
            child: widget.showText
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${_fmt(current)}$_suffix',
                          style: TextStyle(
                            color: Colors.white, fontSize: numFontSz,
                            fontWeight: FontWeight.w800, letterSpacing: -0.5,
                            height: 1,
                          )),
                      const SizedBox(height: 4),
                      Text(widget.sublabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF8FBCD4),
                            fontSize: lblFontSz, height: 1.25,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ── Style 0 : arc 270° avec halo ──────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  static const _start = -math.pi * 0.75;
  static const _total =  math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final r    = (math.min(size.width, size.height) - 16) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Piste de fond
    canvas.drawArc(rect, _start, _total, false,
        Paint()..color = color.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round);

    if (progress <= 0) return;
    final sweep = _total * progress;

    // Halo
    canvas.drawArc(rect, _start, sweep, false,
        Paint()..color = color.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Arc principal
    canvas.drawArc(rect, _start, sweep, false,
        Paint()..color = color
            ..style = PaintingStyle.stroke..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.progress != progress;
}

// ── Style 1 : segments pointillés (24 tirets) ─────────────────────────────────

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  static const int    _count = 24;
  static const double _start = -math.pi * 0.75;
  static const double _total =  math.pi * 1.5;
  static const double _gap   = 0.10;

  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final r    = (math.min(size.width, size.height) - 16) / 2;
    final step = _total / _count;

    for (int i = 0; i < _count; i++) {
      final isActive = i < (_count * progress);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        _start + step * i, step - _gap, false,
        Paint()
          ..color = isActive ? color : color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 4.0 : 3.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedPainter o) => o.progress != progress;
}

// ── Style 2 : anneaux concentriques décalés ───────────────────────────────────

class _ConcentricPainter extends CustomPainter {
  const _ConcentricPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  static const _start = -math.pi * 0.75;
  static const _total =  math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final c      = Offset(size.width / 2, size.height / 2);
    final rOuter = (math.min(size.width, size.height) - 14) / 2;
    final rInner = rOuter - 9;

    // Pistes de fond
    for (final (r, w, a) in [(rOuter, 4.0, 0.18), (rInner, 3.0, 0.12)]) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), _start, _total, false,
          Paint()..color = color.withValues(alpha: a)
              ..style = PaintingStyle.stroke..strokeWidth = w
              ..strokeCap = StrokeCap.round);
    }

    if (progress <= 0) return;

    // Arc extérieur (vitesse normale)
    canvas.drawArc(Rect.fromCircle(center: c, radius: rOuter),
        _start, _total * progress, false,
        Paint()..color = color
            ..style = PaintingStyle.stroke..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round);

    // Arc intérieur (légèrement en retard)
    final inner = (_total * (progress - 0.15)).clamp(0.0, _total);
    if (inner > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: rInner),
          _start, inner, false,
          Paint()..color = color.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke..strokeWidth = 3.0
              ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ConcentricPainter o) => o.progress != progress;
}

// ── Style 3 : anneau complet avec gradient ────────────────────────────────────

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final r    = (math.min(size.width, size.height) - 16) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Fond
    canvas.drawCircle(c, r,
        Paint()..color = color.withValues(alpha: 0.13)
            ..style = PaintingStyle.stroke..strokeWidth = 4.5);

    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;

    // Halo
    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Arc dégradé
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle:   -math.pi / 2 + sweep,
      colors: [color.withValues(alpha: 0.35), color],
    ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()..shader = shader
            ..style = PaintingStyle.stroke..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GradientRingPainter o) => o.progress != progress;
}
