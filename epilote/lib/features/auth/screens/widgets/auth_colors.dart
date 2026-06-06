// ─── Design System — Couleurs Auth Screens ───────────────────────────────────
// Partagées par login_screen, login_form_card, login_hero_panel.
// Toutes les couleurs sont des constantes de compilation (zéro coût runtime).

import 'package:flutter/material.dart';

const kAuthNavy        = Color(0xFF1E3A5F);
const kAuthNavyDark    = Color(0xFF0F2340);
const kAuthNavyDeep    = Color(0xFF091828);
const kAuthDanger      = Color(0xFFDC2626);
const kAuthCongoGreen  = Color(0xFF009A44);
const kAuthCongoYellow = Color(0xFFFCDD09);
const kAuthCongoRed    = Color(0xFFDC2626);
const kAuthSlate       = Color(0xFF64748B);
const kAuthTextPrimary = Color(0xFF0F172A);

/// Bandeau tricolore Congo (3 rectangles côte à côte).
/// [height] hauteur du drapeau, [barWidth] largeur de chaque bande.
Widget congoFlag({double barWidth = 14, double height = 24, double radius = 2}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [kAuthCongoGreen, kAuthCongoYellow, kAuthCongoRed]
            .map((c) => Container(width: barWidth, height: height, color: c))
            .toList(),
      ),
    );
