import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ─── Design tokens du module communication ──────────────────────────────────────
// Alias du module vers les jetons globaux. Des GETTERS, pas des `const` : ils
// doivent suivre le thème (un `final`/`const` les figerait au démarrage).
Color get kCommNavy   => kNavy;
Color get kCommGreen  => kGreen;
Color get kCommCard   => kCardBg;
Color get kCommText   => kTextPrimary;
Color get kCommSub    => kTextMuted;
Color get kCommBg     => kSurface;
Color get kCommBorder => kBorder;

// ─── Configuration des types de notification ────────────────────────────────────
Map<String, ({IconData icon, Color color, String label})> get _typeConfig => {
  'payment':      (icon: Icons.payment_rounded,         color: kGreen, label: 'Paiement'),
  'invoice':      (icon: Icons.description_rounded,      color: const Color(0xFF0EA5E9), label: 'Facture'),
  'subscription': (icon: Icons.card_membership_rounded, color: const Color(0xFF7C3AED), label: 'Abonnement'),
  'alert':        (icon: Icons.warning_amber_rounded,   color: const Color(0xFFF59E0B), label: 'Alerte'),
  'system':       (icon: Icons.settings_rounded,        color: kTextMuted, label: 'Système'),
  'group':        (icon: Icons.school_rounded,          color: kNavy, label: 'Groupe'),
  'security':     (icon: Icons.security_rounded,        color: const Color(0xFFEF4444), label: 'Sécurité'),
};

({IconData icon, Color color, String label}) notifTypeInfo(String type) =>
    _typeConfig[type] ??
    (icon: Icons.notifications_rounded, color: kCommSub, label: type);
