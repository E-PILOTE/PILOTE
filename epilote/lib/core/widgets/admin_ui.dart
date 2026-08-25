import 'package:flutter/material.dart';

import 'admin_tokens.dart';

export 'admin_date_field.dart';
export 'admin_dialog_legacy.dart';
export 'admin_modal.dart';
export 'admin_modal_shapes.dart';
export 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BIBLIOTHÈQUE UI DE L'ESPACE ADMIN — cartes, sections, KPI, états.
//
//  Point d'entrée unique : ce fichier ré-exporte les jetons de couleur
//  (`admin_tokens.dart`) et le chrome des modales (`admin_modal.dart`). Un
//  écran importe `admin_ui.dart` et dispose de l'ensemble ; la découpe est
//  interne, elle sert à ce que chaque famille tienne dans un fichier lisible.
// ════════════════════════════════════════════════════════════════════════════

// ─── Carte conteneur ────────────────────────────────────────────────────────
class AdminCard extends StatefulWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accent,
    this.hoverable = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;

  /// Léger relief au survol (ombre portée plus ample, liseré teinté).
  ///
  /// STRICTEMENT OPTIONNEL : les 170 cartes existantes gardent exactement leur
  /// rendu et leur coût — sans ce drapeau, aucun `MouseRegion`, aucune
  /// animation implicite, aucun `AnimatedContainer` n'est construit.
  final bool hoverable;

  @override
  State<AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<AdminCard> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final contenu = widget.accent != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(padding: widget.padding, child: widget.child),
            ],
          )
        : Padding(padding: widget.padding, child: widget.child);

    if (!widget.hoverable) {
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
        child: contenu,
      );
      if (widget.onTap == null) return card;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: widget.onTap, child: card),
      );
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _survol ? kNavy.withValues(alpha: 0.30) : kBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _survol ? 0.10 : 0.04),
            blurRadius: _survol ? 18 : 10,
            offset: Offset(0, _survol ? 6 : 3),
          ),
        ],
      ),
      child: contenu,
    );
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: widget.onTap == null
          ? card
          : GestureDetector(onTap: widget.onTap, child: card),
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
      // ── POURQUOI UN LayoutBuilder ICI ────────────────────────────────────
      // Ces cartes vivent presque toujours dans une grille à `mainAxisExtent`
      // fixe. Dès qu'une colonne devient étroite, le libellé ET le sous-titre
      // passent chacun sur deux lignes, et la hauteur nécessaire dépasse la
      // hauteur allouée : « BOTTOM OVERFLOWED BY 6 PIXELS ». Rehausser
      // l'extent ne règle rien — le même défaut revient au libellé suivant, à
      // l'autre thème, ou dès que l'utilisateur agrandit la police du système.
      //
      // La hauteur disponible est donc RENDUE au texte : quand elle est
      // bornée, libellé et sous-titre deviennent flexibles et se tronquent
      // proprement. Le débordement cesse d'être possible par construction.
      // Quand elle ne l'est pas (carte posée dans une colonne qui défile),
      // `Flexible` déclencherait une assertion — on garde alors la mise en
      // page naturelle.
      child: LayoutBuilder(builder: (context, c) {
        final bounded = c.maxHeight.isFinite;
        final label = Text(this.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5, color: kTextMuted, fontWeight: FontWeight.w600));
        final sub = subtitle == null
            ? null
            : Text(subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400));

        return Column(
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
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 14),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            if (bounded) Flexible(child: label) else label,
            if (sub != null) ...[
              const SizedBox(height: 2),
              if (bounded) Flexible(child: sub) else sub,
            ],
          ],
        );
      }),
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
