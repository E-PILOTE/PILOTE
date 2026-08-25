import 'package:flutter/material.dart';

import 'admin_tokens.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHROME DES MODALES — une seule famille visuelle pour tout l'espace admin.
//
//  Trois formes, un seul en-tête et un seul pied :
//   • `AdminFormDialog`  — boîte centrée (formulaires, fiches de détail) ;
//   • `showAdminSidePanel` — panneau latéral pleine hauteur (saisies longues) ;
//   • `showAdminConfirm` — confirmation courte (dont les gestes destructifs).
//
//  Elles partagent `AdminModalHeader` / `AdminModalFooter` : un changement de
//  style se fait une fois, et aucune modale ne peut dériver seule. C'est ce qui
//  manquait — chaque écran rehaussait son propre `AlertDialog`, avec des rayons,
//  des ombres et des boutons de fermeture différents d'une page à l'autre.
// ════════════════════════════════════════════════════════════════════════════

/// Rayon des angles de toute modale. Une seule valeur, partout.
const double kModalRadius = 18;

/// Largeur de référence d'une modale (formulaire comme panneau latéral).
const double kModalWidth = 560;

// ─── En-tête partagé ────────────────────────────────────────────────────────
/// En-tête blanc à icône en dégradé + bouton fermer carré.
///
/// Porte SON bouton de fermeture : n'en ajoutez jamais un second par-dessus
/// (un `Stack`/`Positioned` au-dessus de l'en-tête produit deux croix
/// superposées — le défaut que ce widget existe pour empêcher).
class AdminModalHeader extends StatelessWidget {
  const AdminModalHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,
    this.topRadius = kModalRadius,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Couleur de la pastille d'icône. `kNavy` par défaut ; une modale de
  /// classement peut y mettre sa médaille, une suppression son rouge.
  final Color? accent;

  /// Contenu inséré avant le bouton fermer (un chiffre clé, un badge).
  final Widget? trailing;

  /// 0 en panneau latéral, où l'en-tête est collé au bord de l'écran.
  final double topRadius;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kNavy;
    final dark = Color.lerp(color, Colors.black, 0.25) ?? color;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [dark, color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.30),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 12)],
        InkWell(
          onTap: onClose ?? () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
          ),
        ),
      ]),
    );
  }
}

// ─── Pied partagé ───────────────────────────────────────────────────────────
/// Pied de modale : liseré supérieur + contenu aligné.
class AdminModalFooter extends StatelessWidget {
  const AdminModalFooter({
    super.key,
    required this.child,
    this.bottomRadius = kModalRadius,
  });
  final Widget child;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: child,
      );
}

/// Couple « Annuler / action primaire » — le pied par défaut d'une saisie.
class AdminModalActions extends StatelessWidget {
  const AdminModalActions({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.submitIcon,
    this.submitColor,
    this.saving = false,
    this.cancelLabel = 'Annuler',
    this.onCancel,
    this.leading,
  });

  final String submitLabel;
  final VoidCallback onSubmit;
  final IconData? submitIcon;
  final Color? submitColor;
  final bool saving;
  final String cancelLabel;
  final VoidCallback? onCancel;

  /// Action secondaire poussée à gauche (ex. « Exporter »).
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(children: [
        TextButton.icon(
          onPressed:
              saving ? null : (onCancel ?? () => Navigator.of(context).pop()),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: Text(cancelLabel),
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
        ),
        if (leading != null) ...[const SizedBox(width: 8), leading!],
        const Spacer(),
        AdminPrimaryButton(
          label: submitLabel,
          icon: submitIcon,
          color: submitColor,
          saving: saving,
          onTap: onSubmit,
        ),
      ]);
}


// ─── Libellés et séparateurs de formulaire ──────────────────────────────────
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

// ─── Bouton primaire ────────────────────────────────────────────────────────
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
