import 'package:flutter/material.dart';

// ─── Design tokens — identiques à l'espace super_admin ──────────────────────
const Color kNavyDeep    = Color(0xFF091828);
const Color kNavyDark    = Color(0xFF0F2340);
const Color kNavy        = Color(0xFF1E3A5F);
const Color kGreen       = Color(0xFF009A44);
const Color kAccent      = Color(0xFFFBBC04);
const Color kRed         = Color(0xFFDC2626);
const Color kSurface     = Color(0xFFF0F4F8);
const Color kCardBg      = Colors.white;
const Color kTextPrimary = Color(0xFF0F172A);
const Color kTextMuted   = Color(0xFF64748B);
const Color kBorder      = Color(0xFFE2E8F0);

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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
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
              style: const TextStyle(
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
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5)),
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
  const AdminActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.color = kNavy,
  });
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
        side: const BorderSide(color: kBorder),
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
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kNavy, width: 1.6),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [kNavyDark, kNavy]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
  const AdminDialogFooter({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
    this.submitColor = kNavy,
    this.submitIcon,
  });
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
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : onCancel,
            child: const Text('Annuler', style: TextStyle(color: kTextMuted)),
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
    style: const TextStyle(
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
      border: last ? null : const Border(bottom: BorderSide(color: kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: kTextMuted),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
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
          const Icon(Icons.error_outline_rounded, color: kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: kRed, fontSize: 12.5))),
        ],
      ),
    );
  }
}
