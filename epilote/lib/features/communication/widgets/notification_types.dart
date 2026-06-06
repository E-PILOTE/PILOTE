import 'package:flutter/material.dart';

// ─── Design tokens du module communication ──────────────────────────────────────
const kCommNavy  = Color(0xFF1E3A5F);
const kCommGreen = Color(0xFF009A44);
const kCommCard  = Colors.white;
const kCommText  = Color(0xFF0F172A);
const kCommSub   = Color(0xFF64748B);
const kCommBg    = Color(0xFFF0F4F8);
const kCommBorder = Color(0xFFE2E8F0);

// ─── Configuration des types de notification ────────────────────────────────────
const _typeConfig = {
  'payment':      (icon: Icons.payment_rounded,         color: Color(0xFF009A44), label: 'Paiement'),
  'invoice':      (icon: Icons.description_rounded,      color: Color(0xFF0EA5E9), label: 'Facture'),
  'subscription': (icon: Icons.card_membership_rounded, color: Color(0xFF7C3AED), label: 'Abonnement'),
  'alert':        (icon: Icons.warning_amber_rounded,   color: Color(0xFFF59E0B), label: 'Alerte'),
  'system':       (icon: Icons.settings_rounded,        color: Color(0xFF64748B), label: 'Système'),
  'group':        (icon: Icons.school_rounded,          color: Color(0xFF1E3A5F), label: 'Groupe'),
  'security':     (icon: Icons.security_rounded,        color: Color(0xFFEF4444), label: 'Sécurité'),
};

({IconData icon, Color color, String label}) notifTypeInfo(String type) =>
    _typeConfig[type] ??
    (icon: Icons.notifications_rounded, color: kCommSub, label: type);
