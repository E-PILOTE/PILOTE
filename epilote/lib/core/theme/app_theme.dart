import 'package:flutter/material.dart';

import 'palette.dart';

/// Thème E-PILOTE CONGO
/// Couleurs principales : Vert Congo + Or
class AppTheme {
  AppTheme._();

  /// `ThemeData` construit depuis la palette active.
  ///
  /// L'essentiel des couleurs de l'app ne passe PAS par ici (les écrans lisent
  /// les jetons `kNavy`/`kSurface`… directement) : ce ThemeData habille les
  /// widgets Material natifs (dialogues, champs, menus) pour qu'ils s'accordent
  /// aux jetons plutôt que de rester blancs sur un fond noir.
  static ThemeData from(EpilotePalette p) {
    final dark = p.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.green,
        brightness: p.brightness,
        primary: dark ? p.green : primary,
        secondary: p.accent,
        surface: p.cardBg,
        error: p.red,
        onSurface: p.textPrimary,
      ),
      scaffoldBackgroundColor: p.surface,
      canvasColor: p.cardBg,
      dividerColor: p.border,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? p.navyDeep : primary,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardBg,
        elevation: dark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: dark ? BorderSide(color: p.border) : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardBg,
        titleTextStyle: TextStyle(
            color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.cardBg,
        textStyle: TextStyle(color: p.textPrimary, fontSize: 13),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(backgroundColor: WidgetStatePropertyAll(p.cardBg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.cardBg),
      drawerTheme: DrawerThemeData(backgroundColor: p.cardBg),
      listTileTheme: ListTileThemeData(
        textColor: p.textPrimary,
        iconColor: p.textMuted,
      ),
      iconTheme: IconThemeData(color: p.textMuted),
      textTheme: dark
          ? Typography.whiteMountainView.apply(
              bodyColor: p.textPrimary, displayColor: p.textPrimary)
          : Typography.blackMountainView.apply(
              bodyColor: p.textPrimary, displayColor: p.textPrimary),
      // Boutons à 8px (convention plateforme) — sinon Material 3 = pilule.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? p.surface : Colors.grey[50],
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? p.green : primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.green.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: dark ? p.green : primary, fontSize: 12),
        side: const BorderSide(color: Colors.transparent),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ─── Palette ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF006B3C);       // Vert Congo
  static const Color primaryLight = Color(0xFF2E9E6B);
  static const Color primaryDark = Color(0xFF004A2A);
  static const Color secondary = Color(0xFFFBBC04);     // Or/Jaune
  static const Color accent = Color(0xFFE63946);        // Rouge (alertes)

  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Colors.white;

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Thème clair ──────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: secondary,
          surface: surfaceLight,
          error: error,
        ),
        scaffoldBackgroundColor: backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: textLight,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textLight,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceLight,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: textLight,
            minimumSize: const Size(88, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Boutons à 8px (convention plateforme) — sinon Material 3 = pilule.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: primaryLight.withValues(alpha: 0.1),
          labelStyle: const TextStyle(color: primary, fontSize: 12),
          side: const BorderSide(color: Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );

  // ─── Thème sombre ─────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          primary: primaryLight,
          secondary: secondary,
          surface: surfaceDark,
          error: error,
        ),
        scaffoldBackgroundColor: backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: textLight,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: surfaceDark,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
