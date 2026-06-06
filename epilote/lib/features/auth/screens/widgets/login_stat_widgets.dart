import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'auth_colors.dart';

// ─── Modèle de point commun ───────────────────────────────────────────────────

class _Pt {
  const _Pt(this.x, this.y);
  final String x;
  final double y;
}

// ─── CountUpText ──────────────────────────────────────────────────────────────

class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.rawValue,
    required this.style,
    this.delayMs = 650,
  });

  final String    rawValue;
  final TextStyle style;
  final int       delayMs;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  late final int    _target;
  late final String _suffix;

  @override
  void initState() {
    super.initState();
    final raw = widget.rawValue
        .replaceAll(' ', '').replaceAll(' ', '').replaceAll(' ', '');
    _suffix = raw.endsWith('+') ? '+' : '';
    _target = int.tryParse(raw.replaceAll('+', '')) ?? 0;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Text(
          '${_fmt((_target * _anim.value).round())}$_suffix',
          style: widget.style,
        ),
      );
}

// ─── Shell commun ─────────────────────────────────────────────────────────────

class _Shell extends StatelessWidget {
  const _Shell({required this.color, required this.child});
  final Color  color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        padding: const EdgeInsets.all(8),
        child: child,
      );
}

// ─── Helpers responsive ───────────────────────────────────────────────────────

const _kLblColor = Color(0xFF8FBCD4);

/// Taille du nombre : pilotée par la min des deux dimensions disponibles.
/// Plafond relevé pour les grands écrans (27" et plus).
double _numSz(double w, double h) =>
    min(w * 0.20, h * 0.26).clamp(12.0, 32.0);

/// Taille du libellé.
double _lblSz(double w, double h) =>
    min(w * 0.09, h * 0.13).clamp(9.0, 15.0);

// ─── Stat 0 : SplineArea — croissance groupes scolaires (vert) ───────────────
// Courbe montante avec remplissage dégradé : premium + unique vs les 3 autres.

class StatArcCard extends StatelessWidget {
  const StatArcCard({super.key});

  static const _color = kAuthCongoGreen;

  // Évolution fictive mais réaliste des groupes scolaires
  static const _data = [
    _Pt('2019', 280),
    _Pt('2020', 320),
    _Pt('2021', 365),
    _Pt('2022', 410),
    _Pt('2023', 455),
    _Pt('2024', 500),
  ];

  @override
  Widget build(BuildContext context) {
    return _Shell(
      color: _color,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountUpText(
                rawValue: '500+',
                style: TextStyle(
                  color: Colors.white, fontSize: _numSz(w, h),
                  fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text('GROUPES scolaires',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kLblColor, fontSize: _lblSz(w, h),
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 3),
              Expanded(
                child: SfCartesianChart(
                  backgroundColor: Colors.transparent,
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  primaryXAxis: const CategoryAxis(
                      isVisible: false, borderColor: Colors.transparent),
                  primaryYAxis: const NumericAxis(
                      isVisible: false, borderColor: Colors.transparent,
                      minimum: 200, maximum: 560),
                  series: <CartesianSeries>[
                    // Zone de remplissage dégradée
                    SplineAreaSeries<_Pt, String>(
                      dataSource: _data,
                      xValueMapper: (d, _) => d.x,
                      yValueMapper: (d, _) => d.y,
                      animationDuration: 1800,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _color.withValues(alpha: 0.45),
                          _color.withValues(alpha: 0.04),
                        ],
                      ),
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                    ),
                    // Ligne principale nette par-dessus
                    SplineSeries<_Pt, String>(
                      dataSource: _data,
                      xValueMapper: (d, _) => d.x,
                      yValueMapper: (d, _) => d.y,
                      color: _color,
                      width: 2.2,
                      animationDuration: 1800,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        shape: DataMarkerType.circle,
                        width: 5, height: 5,
                        borderWidth: 1.5,
                        color: _color,
                        borderColor: Colors.white.withValues(alpha: 0.8),
                      ),
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Stat 1 : Bar chart horizontal (bleu) — couverture départements ───────────
// Barres horizontales : lisible d'un coup d'œil, digne d'un tableau de bord
// institutionnel. Ordre croissant → l'œil lit la hiérarchie naturellement.

class StatRadialCard extends StatelessWidget {
  const StatRadialCard({super.key});

  static const _color = Color(0xFF3B82F6);

  // Données classées du moins au plus couvert → barre la plus longue en haut
  static const _data = [
    _Pt('Kouilou',     14),
    _Pt('Cuvette',     18),
    _Pt('Pool',        25),
    _Pt('Pte-Noire',   35),
    _Pt('Brazzaville', 42),
  ];
  static const _shades = [0.30, 0.45, 0.62, 0.80, 1.0];

  @override
  Widget build(BuildContext context) {
    return _Shell(
      color: _color,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountUpText(
                rawValue: '15',
                style: TextStyle(
                  color: Colors.white, fontSize: _numSz(w, h),
                  fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text('DÉPARTEMENTS couverts',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kLblColor, fontSize: _lblSz(w, h),
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 3),
              Expanded(
                child: SfCartesianChart(
                  backgroundColor: Colors.transparent,
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  primaryXAxis: const CategoryAxis(
                      isVisible: false, borderColor: Colors.transparent),
                  primaryYAxis: const NumericAxis(
                      isVisible: false, borderColor: Colors.transparent,
                      minimum: 0, maximum: 50),
                  series: <CartesianSeries>[
                    BarSeries<_Pt, String>(
                      dataSource: _data,
                      xValueMapper: (d, _) => d.x,
                      yValueMapper: (d, _) => d.y,
                      animationDuration: 1600,
                      borderRadius: BorderRadius.circular(3),
                      spacing: 0.18,
                      pointColorMapper: (_, i) =>
                          _color.withValues(alpha: _shades[i]),
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Stat 2 : Column chart (jaune) ────────────────────────────────────────────

class StatColumnCard extends StatelessWidget {
  const StatColumnCard({super.key});

  static const _color = kAuthCongoYellow;
  static const _data = [
    _Pt('2020', 28000),
    _Pt('2021', 34000),
    _Pt('2022', 39000),
    _Pt('2023', 44000),
    _Pt('2024', 48000),
    _Pt('2025', 52000),
  ];

  @override
  Widget build(BuildContext context) {
    return _Shell(
      color: _color,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final nSz = _numSz(w, h);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountUpText(
                rawValue: '50 000+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (nSz * 0.85).clamp(10.0, 20.0),
                  fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text('UTILISATEURS potentiels',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kLblColor, fontSize: _lblSz(w, h),
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 3),
              Expanded(
                child: SfCartesianChart(
                  backgroundColor: Colors.transparent,
                  plotAreaBorderWidth: 0,
                  margin: EdgeInsets.zero,
                  primaryXAxis: const CategoryAxis(
                      isVisible: false, borderColor: Colors.transparent),
                  primaryYAxis: const NumericAxis(
                      isVisible: false, borderColor: Colors.transparent),
                  series: <CartesianSeries>[
                    ColumnSeries<_Pt, String>(
                      dataSource: _data,
                      xValueMapper: (d, _) => d.x,
                      yValueMapper: (d, _) => d.y,
                      color: _color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      spacing: 0.18,
                      animationDuration: 1600,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Stat 3 : Pyramid chart (teal) ────────────────────────────────────────────

class StatPyramidCard extends StatelessWidget {
  const StatPyramidCard({super.key});

  static const _color = Color(0xFF14B8A6);
  static const _data = [
    _Pt('Pilotage',   5),
    _Pt('Groupes',  200),
    _Pt('Écoles',   800),
    _Pt('Classes', 8000),
  ];
  static const _shades = [1.0, 0.78, 0.56, 0.36];

  @override
  Widget build(BuildContext context) {
    return _Shell(
      color: _color,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountUpText(
                rawValue: '200+',
                style: TextStyle(
                  color: Colors.white, fontSize: _numSz(w, h),
                  fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text('ÉTABLISSEMENTS partenaires',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kLblColor, fontSize: _lblSz(w, h),
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 3),
              Expanded(
                child: SfPyramidChart(
                  backgroundColor: Colors.transparent,
                  margin: EdgeInsets.zero,
                  series: PyramidSeries<_Pt, String>(
                    dataSource: _data,
                    xValueMapper: (d, _) => d.x,
                    yValueMapper: (d, _) => d.y,
                    animationDuration: 1600,
                    pointColorMapper: (_, i) =>
                        _color.withValues(alpha: _shades[i]),
                    dataLabelSettings:
                        const DataLabelSettings(isVisible: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
