import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../../core/widgets/admin_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  LE VOCABULAIRE DE L'ÉCRAN DES ABONNEMENTS — déclaré UNE fois
//
//  Couleurs, libellés de statut, format d'un montant et d'une date. Neuf
//  fichiers s'en servent ; aucun ne le redéclare.
//
//  ⚠️ `kSubOrange`, `kSubPurple`, `kSubBlue` et `kSubRed` sont des `const` et
//  doivent le rester : plusieurs `const Row(...)` de l'écran les portent, et
//  un simple getter les ferait sortir du contexte constant.
// ═════════════════════════════════════════════════════════════════════════════

/// Message lisible d'une erreur base : un garde-fou métier (ex. « Activation
/// refusée : aucun reçu payé… ») remonte via PostgrestException.message — on
/// l'affiche tel quel plutôt que le `toString()` verbeux (code, hint, détails).
String cleanDbError(Object e) =>
    e is PostgrestException ? e.message : e.toString();

// ─── Couleurs ────────────────────────────────────────────────────────────
Color get kSubNavy => kNavy;
Color get kSubGreen => kGreen;
Color get kSubGold => kAccent;
const kSubOrange = Color(0xFFFF6B35);
const kSubPurple = Color(0xFF7C3AED);
const kSubBlue = Color(0xFF0EA5E9);
const kSubRed = Color(0xFFEF4444);
Color get kSubSurface => kSurface;
Color get kSubBg => kCardBg;
Color get kSubBorder => kBorder;
Color get kSubText => kTextPrimary;
Color get kSubMuted => kTextMuted;

// ─── Statut d'abonnement ────────────────────────────────────────────────
const kSubStatusLabels = {
  'trial': 'Essai',
  'active': 'Actif',
  'suspended': 'Suspendu',
  'expired': 'Expiré',
  'cancelled': 'Annulé',
};

Color subStatusColor(String s) => switch (s) {
  'trial' => kSubGold,
  'active' => kSubGreen,
  'suspended' => kSubOrange,
  'expired' => kSubRed,
  'cancelled' => kSubMuted,
  _ => kSubMuted,
};

IconData subStatusIcon(String s) => switch (s) {
  'trial' => Icons.hourglass_top_rounded,
  'active' => Icons.check_circle_rounded,
  'suspended' => Icons.pause_circle_rounded,
  'expired' => Icons.event_busy_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.help_rounded,
};

String subStatusLabel(String s) => kSubStatusLabels[s] ?? s;

Color subTypeColor(String t) => t == 'public' ? kSubNavy : kSubPurple;
IconData subTypeIcon(String t) =>
    t == 'public' ? Icons.account_balance_rounded : Icons.business_rounded;

// ─── Monnaie / dates ─────────────────────────────────────────────────────

String subMoney(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String subDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}
