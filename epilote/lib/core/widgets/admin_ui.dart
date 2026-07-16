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

// ─── Carte conteneur ────────────────────────────────────────────────────────
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: accent != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            )
          : Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

// ─── Titre de section ───────────────────────────────────────────────────────
class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.icon, this.trailing, this.subtitle});
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: kNavy),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─── Carte KPI ──────────────────────────────────────────────────────────────
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: kTextMuted, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ],
      ),
    );
  }
}

// ─── Pastille de statut ─────────────────────────────────────────────────────
class AdminBadge extends StatelessWidget {
  const AdminBadge(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── État vide ──────────────────────────────────────────────────────────────
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: kNavy.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Barre de progression (quota) ───────────────────────────────────────────
class AdminProgressBar extends StatelessWidget {
  const AdminProgressBar({
    super.key,
    required this.value,
    required this.max,
    this.height = 8,
    this.color,
  });
  final num value;
  final num max;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final barColor = color ??
        (ratio >= 0.9 ? kRed : ratio >= 0.7 ? kAccent : kGreen);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: ratio.toDouble(),
        minHeight: height,
        backgroundColor: kSurface,
        valueColor: AlwaysStoppedAnimation(barColor),
      ),
    );
  }
}

// ─── Bouton d'action en-tête (style super_admin) ────────────────────────────
class AdminActionButton extends StatelessWidget {
  AdminActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    Color? color,
  }) : color = color ?? kNavy;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
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

// ─── En-tête de boîte de dialogue (bandeau navy) ────────────────────────────
class AdminDialogHeader extends StatelessWidget {
  const AdminDialogHeader({super.key, required this.title, required this.icon, this.subtitle});
  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kNavyDark, kNavy]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─── Pied de boîte de dialogue (Annuler / Action) ───────────────────────────
class AdminDialogFooter extends StatelessWidget {
  AdminDialogFooter({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
    Color? submitColor,
    this.submitIcon,
  }) : submitColor = submitColor ?? kNavy;
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final Color submitColor;
  final IconData? submitIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(submitIcon ?? Icons.check_rounded, size: 18),
            label: Text(submitLabel),
            style: FilledButton.styleFrom(
              backgroundColor: submitColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MODAL FORMULAIRE — style identique à « Nouvelle école » (SchoolFormDialog) :
//  fond blanc radius 18 + ombre, en-tête blanc à icône en dégradé + bouton
//  fermer carré, corps défilant, pied avec « Annuler » + bouton primaire pilule.
//  Réutilisable : à privilégier pour tout nouveau formulaire admin_groupe.
// ════════════════════════════════════════════════════════════════════════════
class AdminFormDialog extends StatelessWidget {
  AdminFormDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.width = 560,
    this.maxHeight = 720,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 20, 24, 20),
    this.saving = false,
    this.submitLabel,
    this.submitIcon,
    Color? submitColor,
    this.onSubmit,
  }) : submitColor = submitColor ?? kNavy;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final double width;
  final double maxHeight;
  final bool scrollable;
  final EdgeInsets bodyPadding;
  // Pied par défaut (si [footer] est null et [onSubmit] fourni).
  final bool saving;
  final String? submitLabel;
  final IconData? submitIcon;
  final Color submitColor;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final body0 = scrollable
        ? SingleChildScrollView(padding: bodyPadding, child: body)
        : Padding(padding: bodyPadding, child: body);

    Widget? foot = footer;
    foot ??= (onSubmit == null)
        ? null
        : Row(children: [
            TextButton.icon(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Annuler'),
              style: TextButton.styleFrom(foregroundColor: kTextMuted),
            ),
            const Spacer(),
            AdminPrimaryButton(
              label: submitLabel ?? 'Enregistrer',
              icon: submitIcon,
              color: submitColor,
              saving: saving,
              onTap: onSubmit!,
            ),
          ]);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── En-tête ──
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: kNavy.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 11.5, color: kTextMuted)),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: kTextMuted),
                ),
              ),
            ]),
          ),
          // ── Corps ──
          Flexible(child: body0),
          // ── Pied ──
          if (foot != null)
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: foot,
            ),
        ]),
      ),
    );
  }
}

/// Libellé de section de formulaire (barre navy + texte capitalisé) — identique
/// à `_SchFormLabel` de « Nouvelle école ».
class AdminFormSectionLabel extends StatelessWidget {
  const AdminFormSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
                color: kNavy, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: kNavy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ]),
      );
}

/// Séparateur de section de formulaire.
class AdminFormDivider extends StatelessWidget {
  const AdminFormDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Divider(color: kBorder, height: 1),
      );
}

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

/// Bouton primaire « pilule » à dégradé (style bouton enregistrer de l'école).
class AdminPrimaryButton extends StatelessWidget {
  AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    Color? color,
    this.saving = false,
  }) : color = color ?? kNavy;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.18) ?? color;
    return Opacity(
      opacity: saving ? 0.85 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saving ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [dark, color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (saving)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else if (icon != null)
                Icon(icon, color: Colors.white, size: 17),
              if (saving || icon != null) const SizedBox(width: 9),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bouton discret « Exporter PDF » (liseré rouge) — placé dans les en-têtes de
/// résultats. Ouvre l'aperçu PDF partagé (`showPdfPreviewDialog`).
class AdminPdfButton extends StatelessWidget {
  const AdminPdfButton({super.key, required this.onTap, this.label = 'Exporter PDF'});
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRed.withValues(alpha: 0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.picture_as_pdf_outlined, size: 15, color: kRed),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: kRed, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── Helpers de modal « détails » (style super_admin) ───────────────────────
class AdminModalIconBtn extends StatelessWidget {
  const AdminModalIconBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    ),
  );
}

class AdminModalSectionTitle extends StatelessWidget {
  const AdminModalSectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title.toUpperCase(),
    style: TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w800, color: kNavy, letterSpacing: 0.6),
  );
}

class AdminDetailCard extends StatelessWidget {
  const AdminDetailCard(this.rows, {super.key});
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder),
    ),
    child: Column(children: rows),
  );
}

class AdminDetailRow extends StatelessWidget {
  const AdminDetailRow(this.icon, this.label, this.value,
      {super.key, this.last = false, this.valueColor, this.mono = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final Color? valueColor;
  final bool mono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: kTextMuted),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: mono ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? kTextPrimary,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ),
    ]),
  );
}

class AdminMetaChip extends StatelessWidget {
  const AdminMetaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 6),
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    ]),
  );
}

// ─── Bannière d'erreur (formulaires) ────────────────────────────────────────
class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: kRed, fontSize: 12.5))),
        ],
      ),
    );
  }
}

