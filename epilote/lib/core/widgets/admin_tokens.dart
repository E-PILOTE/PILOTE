import 'package:flutter/material.dart';

import '../theme/palette.dart';

// ─── Design tokens — la palette ACTIVE, sous les noms historiques ───────────
//
// Ces jetons ne sont plus `const` : c'est ce qui rend les thèmes possibles.
// Toute couleur qui varie à l'exécution tue le `const` — c'est le prix du
// thème, pas celui d'une astuce (cf. spec §2.3).
//
// ⚠️ Ce sont des variables globales, écrites par `applyPalette` UNIQUEMENT.
// Ne jamais les réaffecter ailleurs. Ne jamais les capturer dans un `final`
// top-level : la valeur serait figée au démarrage et ne suivrait plus le
// thème (bug muet, invisible à `flutter analyze`) — utiliser un getter.
Color kNavyDeep    = kPaletteClair.navyDeep;
Color kNavyDark    = kPaletteClair.navyDark;
Color kNavy        = kPaletteClair.navy;
Color kGreen       = kPaletteClair.green;
Color kAccent      = kPaletteClair.accent;
Color kRed         = kPaletteClair.red;
Color kSurface     = kPaletteClair.surface;
Color kCardBg      = kPaletteClair.cardBg;
Color kTextPrimary = kPaletteClair.textPrimary;
Color kTextMuted   = kPaletteClair.textMuted;
Color kBorder      = kPaletteClair.border;

/// Palette actuellement appliquée (source de vérité pour `AppTheme.from`).
EpilotePalette get activePalette => _active;
EpilotePalette _active = kPaletteClair;

/// Bascule les jetons sur [p]. Unique porte d'écriture des couleurs globales.
///
/// N'entraîne AUCUN rebuild par elle-même : l'appelant doit reconstruire
/// l'arbre (`MaterialApp(key: ValueKey(themeId))` dans `main.dart`).
void applyPalette(EpilotePalette p) {
  _active = p;
  kNavyDeep = p.navyDeep;
  kNavyDark = p.navyDark;
  kNavy = p.navy;
  kGreen = p.green;
  kAccent = p.accent;
  kRed = p.red;
  kSurface = p.surface;
  kCardBg = p.cardBg;
  kTextPrimary = p.textPrimary;
  kTextMuted = p.textMuted;
  kBorder = p.border;
}

/// Couleur du ministère de tutelle. METP en violet, MEPSA au bleu de la
/// marque : c'est déjà le code que lisent les tableaux de bord d'examens, on
/// le conserve pour ne pas réapprendre au lecteur ce qu'il sait déjà lire.
///
/// ⚠️ Fonction et non constante : `kNavy` change avec le thème (voir
/// l'avertissement en tête de fichier). Les libellés, eux, vivent dans
/// `core/constants/tutelle.dart`.
Color couleurTutelle(String? t) =>
    (t ?? '').toLowerCase().contains('metp') ? const Color(0xFF7C3AED) : kNavy;

/// Couleur du statut d'une licence de tutelle. Les LIBELLÉS vivent dans
/// `core/constants/licence_statut.dart` — même partage que `couleurTutelle`.
///
/// ⚠️ Un brouillon est GRIS, pas ambre : il n'alerte de rien, il n'est pas
/// encore un marché. C'est « échue » qui doit attirer l'oeil.
Color couleurStatutLicence(String? s) => switch (s) {
      'active' => kGreen,
      // ⚠️ « Suspendue » est ROUGE et « échue » ambre, pas l'inverse. L'ambre
      // dit « ça arrive » ; le rouge dit « quelqu'un l'a arrêté ». Une
      // suspension est une décision, et elle doit se voir comme telle.
      'suspendue' => kRed,
      'echue' => kAccent,
      'resiliee' => kTextPrimary,
      _ => kTextMuted,
    };

// ─── Formateurs ─────────────────────────────────────────────────────────────

/// 1500000 → "1 500 000"
String fmtInt(num value) {
  final s = value.round().abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$buf';
}

/// 1500000 → "1 500 000 FCFA"
String fmtXaf(num value) => '${fmtInt(value)} FCFA';

/// 1250000 → "1,25 M" / 12000 → "12,0 k" / 800 → "800"
String fmtCompact(num value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1).replaceAll('.', ',')} k';
  }
  return value.round().toString();
}

// ─── Helpers couleurs métier ────────────────────────────────────────────────
Color planColor(String? slug) => switch (slug) {
  'gratuit'        => kTextMuted,
  'institutionnel' => kNavy,
  'premium'        => kAccent,
  'pro'            => kGreen,
  _                => kNavy,
};

Color statusColor(String? status) => switch (status) {
  'active'    => kGreen,
  'trial'     => kAccent,
  'suspended' => kRed,
  'expired'   => kRed,
  'cancelled' => kTextMuted,
  _           => kTextMuted,
};

String statusLabel(String? status) => switch (status) {
  'active'    => 'Actif',
  'trial'     => "Période d'essai",
  'suspended' => 'Suspendu',
  'expired'   => 'Expiré',
  'cancelled' => 'Résilié',
  _           => status ?? '—',
};

// ─── Décoration de champ partagée ───────────────────────────────────────────
InputDecoration adminInputDecoration(String label, {IconData? icon, String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: kTextMuted) : null,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: kNavy, width: 1.6),
      ),
    );

/// Décoration d'input « pleine » (fond kSurface, hint) — style « Nouvelle école ».
InputDecoration adminFilledInput(String hint, {IconData? icon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
      prefixIcon:
          icon != null ? Icon(icon, size: 18, color: kTextMuted) : null,
      filled: true,
      fillColor: kSurface,
      isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kNavy, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kRed)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
