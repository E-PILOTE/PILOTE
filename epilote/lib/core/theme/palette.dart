import 'package:flutter/material.dart';

/// Les trois thèmes d'E-PILOTE.
///
/// Le thème est une APPARENCE, jamais un droit ni une protection : il est
/// choisi librement par l'agent, donc il ne peut rien garder. Un futur « mode
/// sécurisé » (masquage au repos, filigrane) serait imposé par la direction et
/// vivrait sur un axe séparé — il pourra forcer [EpiloteThemeId.melack] sans
/// que Melack ne le porte. Voir spec `2026-07-16-themes-clair-sombre-melack`.
enum EpiloteThemeId {
  clair,
  sombre,
  melack;

  /// Libellé affiché à l'utilisateur.
  String get label => switch (this) {
        EpiloteThemeId.clair => 'Clair',
        EpiloteThemeId.sombre => 'Sombre',
        EpiloteThemeId.melack => 'Melack',
      };

  /// Sous-titre du sélecteur.
  String get description => switch (this) {
        EpiloteThemeId.clair => 'Lumineux · par défaut',
        EpiloteThemeId.sombre => 'Confort en faible lumière',
        EpiloteThemeId.melack => 'Poste classifié · contraste élevé',
      };

  static EpiloteThemeId parse(String? name) =>
      EpiloteThemeId.values.firstWhere((e) => e.name == name,
          orElse: () => EpiloteThemeId.clair);
}

/// Les 11 jetons de couleur de la plateforme, sous forme de données pures.
///
/// C'est l'unique source des couleurs : `admin_ui.dart` ne fait qu'exposer la
/// palette active sous les noms historiques (`kNavy`, `kSurface`…) pour que les
/// 121 fichiers consommateurs n'aient pas à changer.
@immutable
class EpilotePalette {
  const EpilotePalette({
    required this.id,
    required this.brightness,
    required this.navyDeep,
    required this.navyDark,
    required this.navy,
    required this.green,
    required this.accent,
    required this.red,
    required this.surface,
    required this.cardBg,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
  });

  final EpiloteThemeId id;
  final Brightness brightness;

  /// Chrome (sidebar / en-tête) — du plus sombre au plus clair.
  final Color navyDeep;
  final Color navyDark;
  final Color navy;

  /// Accents sémantiques.
  final Color green;
  final Color accent;
  final Color red;

  /// Fonds et texte.
  final Color surface;
  final Color cardBg;
  final Color textPrimary;
  final Color textMuted;
  final Color border;

  static EpilotePalette of(EpiloteThemeId id) => switch (id) {
        EpiloteThemeId.clair => kPaletteClair,
        EpiloteThemeId.sombre => kPaletteSombre,
        EpiloteThemeId.melack => kPaletteMelack,
      };
}

/// ── CLAIR ────────────────────────────────────────────────────────────────
/// Strictement les couleurs livrées avant le chantier « thèmes ». Ces valeurs
/// sont verrouillées au hex près par `test/palette_test.dart` : le thème ne
/// doit JAMAIS changer l'apparence de l'existant.
const EpilotePalette kPaletteClair = EpilotePalette(
  id: EpiloteThemeId.clair,
  brightness: Brightness.light,
  navyDeep: Color(0xFF091828),
  navyDark: Color(0xFF0F2340),
  navy: Color(0xFF1E3A5F),
  green: Color(0xFF009A44),
  accent: Color(0xFFFBBC04),
  red: Color(0xFFDC2626),
  surface: Color(0xFFF0F4F8),
  cardBg: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF0F172A),
  textMuted: Color(0xFF64748B),
  border: Color(0xFFE2E8F0),
);

/// ── SOMBRE ───────────────────────────────────────────────────────────────
/// Sombre confortable : gris-bleu, pas noir. Les accents sont ÉCLAIRCIS par
/// rapport à Clair — le vert Congo `#009A44` est illisible sur fond foncé.
const EpilotePalette kPaletteSombre = EpilotePalette(
  id: EpiloteThemeId.sombre,
  brightness: Brightness.dark,
  navyDeep: Color(0xFF0A0F16),
  navyDark: Color(0xFF111823),
  navy: Color(0xFF1B2634),
  green: Color(0xFF22C55E),
  accent: Color(0xFFFBBF24),
  red: Color(0xFFF87171),
  surface: Color(0xFF0D1117),
  cardBg: Color(0xFF161B22),
  textPrimary: Color(0xFFE6EDF3),
  textMuted: Color(0xFF8B949E),
  border: Color(0xFF2D333B),
);

/// ── MELACK ───────────────────────────────────────────────────────────────
/// « Poste classifié ». Noir carbone quasi pur, neutres FROIDS, contraste plus
/// élevé que Sombre, vert phosphore évoquant le terminal sécurisé. Ce qui le
/// distingue de Sombre au premier coup d'œil : le fond est noir et non gris, et
/// la chrome (navyDeep = noir pur) disparaît dans l'écran.
const EpilotePalette kPaletteMelack = EpilotePalette(
  id: EpiloteThemeId.melack,
  brightness: Brightness.dark,
  navyDeep: Color(0xFF000000),
  navyDark: Color(0xFF04070B),
  navy: Color(0xFF080D14),
  green: Color(0xFF00E08A),
  accent: Color(0xFFFFB300),
  red: Color(0xFFFF3B30),
  surface: Color(0xFF05080C),
  cardBg: Color(0xFF0B1017),
  textPrimary: Color(0xFFE8F0F7),
  textMuted: Color(0xFF7D8B9A),
  border: Color(0xFF1B2531),
);
