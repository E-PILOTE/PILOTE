import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Coquille « réseau social » 3 colonnes PARTAGÉE — Annonces & Agenda.
//
//  Layout FLUIDE, bord à bord : les rails ont une largeur fixe, le centre est
//  Expanded et occupe TOUT l'espace restant. Pas de Center, pas de largeur
//  plafonnée → aucun vide latéral, quelle que soit la taille d'écran (27"+).
//  Les rails apparaissent progressivement selon la largeur disponible.
// ════════════════════════════════════════════════════════════════════════════

const double kFeedLeftRailWidth  = 312;
const double kFeedRightRailWidth = 360;
const double kFeedGutter         = 20;
const double kFeedMinCenter      = 440;

// ─── Seuils sur la LARGEUR DISPONIBLE (LayoutBuilder, pas MediaQuery) ─────
// Réutilisés par announcements_feed.dart pour adapter padding & colonnes.
bool feedShowRail(double availW) =>
    availW >= kFeedMinCenter + kFeedRightRailWidth + kFeedGutter; // 820
bool feedShowLeftRail(double availW) =>
    availW >=
    kFeedMinCenter + kFeedLeftRailWidth + kFeedRightRailWidth + kFeedGutter * 2; // 1172

class FeedScaffold extends StatelessWidget {
  const FeedScaffold({
    super.key,
    required this.center,
    required this.rightRail,
    this.leftRail,
  });

  final Widget  center;
  final Widget  rightRail;
  final Widget? leftRail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kSurface,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;

        // Trop étroit pour un rail → le centre prend tout (mode 1 colonne).
        if (!feedShowRail(w)) return center;

        final showLeft = leftRail != null && feedShowLeftRail(w);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLeft) ...[
              SizedBox(width: kFeedLeftRailWidth, child: leftRail),
              const SizedBox(width: kFeedGutter),
            ],
            // Centre : Expanded → remplit tout l'espace restant (bord à bord).
            Expanded(child: center),
            const SizedBox(width: kFeedGutter),
            SizedBox(width: kFeedRightRailWidth, child: rightRail),
          ],
        );
      }),
    );
  }
}
