import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/theme/palette.dart';

// ─── Contraste WCAG 2.x ─────────────────────────────────────────────────────

double _lin(int c) {
  final s = c / 255;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) {
  final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
  return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('EpilotePalette', () {
    test('les 3 identifiants résolvent vers une palette', () {
      for (final id in EpiloteThemeId.values) {
        expect(EpilotePalette.of(id), isNotNull, reason: '$id sans palette');
      }
    });

    // ── VERROU DE NON-RÉGRESSION ──────────────────────────────────────────
    // Clair == exactement les couleurs livrées aujourd'hui. Si ce test casse,
    // c'est que le chantier « thèmes » a changé l'apparence de l'existant —
    // ce qu'il ne doit JAMAIS faire.
    test('Clair reproduit les jetons actuels au hex près', () {
      const p = kPaletteClair;
      expect(p.navyDeep, const Color(0xFF091828));
      expect(p.navyDark, const Color(0xFF0F2340));
      expect(p.navy, const Color(0xFF1E3A5F));
      expect(p.green, const Color(0xFF009A44));
      expect(p.accent, const Color(0xFFFBBC04));
      expect(p.red, const Color(0xFFDC2626));
      expect(p.surface, const Color(0xFFF0F4F8));
      expect(p.cardBg, const Color(0xFFFFFFFF));
      expect(p.textPrimary, const Color(0xFF0F172A));
      expect(p.textMuted, const Color(0xFF64748B));
      expect(p.border, const Color(0xFFE2E8F0));
    });

    test('Melack est un noir franc, distinct du gris-bleu de Sombre', () {
      // Ce qui fait Melack : le fond est NOIR, pas gris. Si un jour quelqu'un
      // « harmonise » les deux palettes, ce test le dit.
      expect(_luminance(kPaletteMelack.surface),
          lessThan(_luminance(kPaletteSombre.surface)),
          reason: 'Melack doit être plus sombre que Sombre');
      expect(kPaletteMelack.navyDeep, const Color(0xFF000000));
    });

    // ── Contraste ─────────────────────────────────────────────────────────
    // Seules les palettes CRÉÉES par ce chantier sont tenues au seuil AA.
    for (final (name, p) in [
      ('Sombre', kPaletteSombre),
      ('Melack', kPaletteMelack),
    ]) {
      test('$name : texte lisible (WCAG AA 4.5:1)', () {
        expect(contrastRatio(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.textPrimary, p.cardBg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.textMuted, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.textMuted, p.cardBg), greaterThanOrEqualTo(4.5));
      });
    }

    // ── Dette documentée, volontairement NON corrigée ──────────────────────
    // Clair échoue AA sur textMuted/surface (4.31) — c'est ANTÉRIEUR au
    // chantier thèmes. L'exemption est nommée ici plutôt que le seuil abaissé
    // en silence : le jour où on corrige la dette, ce test casse et rappelle
    // de rétablir la règle générale. Voir spec §4.
    test('Clair : dette de contraste connue sur textMuted/surface', () {
      final r = contrastRatio(kPaletteClair.textMuted, kPaletteClair.surface);
      expect(r, lessThan(4.5), reason: 'dette corrigée ? réintégrer Clair au test AA');
      expect(r, greaterThan(4.0), reason: 'la dette ne doit pas EMPIRER');
      // Le reste de Clair, lui, tient le seuil.
      expect(contrastRatio(kPaletteClair.textPrimary, kPaletteClair.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrastRatio(kPaletteClair.textMuted, kPaletteClair.cardBg),
          greaterThanOrEqualTo(4.5));
    });
  });
}
