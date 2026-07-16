import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'admin_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Composants PARTAGÉS des pages structurelles de l'espace personnel scolaire.
// Alignés sur le langage de design admin_groupe (admin_ui.dart) : en-tête de
// page riche + skeletons shimmer. À utiliser par TOUTES les pages staff —
// jamais de variante locale (cohérence inter-pages).
// ═════════════════════════════════════════════════════════════════════════════

// ─── En-tête de page riche (gradient navy, badges, action) ─────────────────────
/// Bannière standard des pages structurelles staff : icône en pastille,
/// titre + sous-titre, badges contextuels (rôle / école / état) et action
/// facultative à droite. Même gradient que la bannière du dashboard.
class StaffPageHeader extends StatelessWidget {
  const StaffPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Badges contextuels (ex. `AdminBadge` rôle, école, « Hors ligne »).
  final List<Widget> badges;

  /// Action à droite (ex. `AdminActionButton`, indicateur de synchro).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavyDark, kNavy],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (badges.isNotEmpty && compact) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: badges),
                ],
              ],
            ),
          ),
          if (badges.isNotEmpty && !compact) ...[
            const SizedBox(width: 12),
            Wrap(spacing: 6, children: badges),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Badge translucide blanc pour `StaffPageHeader.badges` (lisible sur navy).
class HeaderChip extends StatelessWidget {
  const HeaderChip({super.key, required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ]),
      );
}

// ─── Skeletons shimmer (états de chargement) ────────────────────────────────────
// Mêmes couleurs que le skeleton admin_groupe (admin_schools_screen).

const Color _kSkelBase      = Color(0xFFE8ECF0);
const Color _kSkelHighlight = Color(0xFFF5F7FA);

/// Enveloppe shimmer standard : `ShimmerPanel(child: …)` autour de
/// n'importe quelle composition de [SkeletonBox].
class ShimmerPanel extends StatelessWidget {
  const ShimmerPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: _kSkelBase,
        highlightColor: _kSkelHighlight,
        child: child,
      );
}

/// Boîte blanche arrondie — brique de base des skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Skeleton de FIL (annonces / événements / notifications) : en-tête de page
/// + N fausses cartes empilées. Largeur contrainte par [maxWidth].
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.cards = 4, this.maxWidth = 900});
  final int cards;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ShimmerPanel(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              // Un squelette n'a rien à faire défiler : `shrinkWrap` le rend
              // utilisable AUSSI dans une Column (sinon « Vertical viewport was
              // given unbounded height » → carré rouge à la place du squelette).
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SkeletonBox(height: 86, radius: 14),
                const SizedBox(height: 16),
                const SkeletonBox(height: 52, radius: 12),
                const SizedBox(height: 16),
                ...List.generate(
                  cards,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonBox(height: 120, radius: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Skeleton de FORMULAIRE (profil / paramètres) : en-tête + sections empilées.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.sections = 3, this.maxWidth = 760});
  final int sections;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ShimmerPanel(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SkeletonBox(height: 96, radius: 14),
                const SizedBox(height: 20),
                ...List.generate(
                  sections,
                  (_) => const Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(width: 180, height: 18, radius: 8),
                    ),
                    SizedBox(height: 12),
                    SkeletonBox(height: 150, radius: 12),
                    SizedBox(height: 20),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Skeleton MAÎTRE-DÉTAIL (messagerie / calendrier) : colonne gauche de
/// tuiles + panneau de détail à droite. S'empile verticalement sous 900 px.
class SplitSkeleton extends StatelessWidget {
  const SplitSkeleton({super.key, this.leftWidth = 340});
  final double leftWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonBox(height: 48, radius: 12),
        const SizedBox(height: 12),
        ...List.generate(
          6,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: SkeletonBox(height: 64, radius: 12),
          ),
        ),
      ],
    );
    return ShimmerPanel(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: leftWidth, child: leftColumn),
                const SizedBox(width: 20),
                const Expanded(
                  child: SkeletonBox(height: 480, radius: 14),
                ),
              ])
            : ListView(children: [leftColumn]),
      ),
    );
  }
}
