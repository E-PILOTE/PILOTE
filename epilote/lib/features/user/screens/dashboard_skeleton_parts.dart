part of 'user_dashboard_screen.dart';

// ─── Squelette de chargement (shimmer) du tableau de bord ─────────────────────
// Affiché UNIQUEMENT au tout premier chargement (avant que permissions + modules
// + école aient produit leur première valeur). Une fois des données présentes
// (même issues du cache offline), on ne shimmer plus jamais : un re-sync en
// arrière-plan ne doit pas clignoter par-dessus le contenu déjà affiché.
//
// La silhouette calque la vraie mise en page (bannière → carte année → frise
// calendrier → blocs métier) pour que la bascule squelette → contenu soit fluide
// et sans saut de disposition.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerPanel(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
        children: [
          // Bannière école (même hauteur/rayon que _SchoolBanner).
          const SkeletonBox(height: 108, radius: 20),
          const SizedBox(height: 18),
          // Carte année scolaire + frise calendrier.
          const SkeletonBox(height: 78, radius: 14),
          const SizedBox(height: 12),
          const SkeletonBox(height: 60, radius: 12),
          const SizedBox(height: 22),
          // Deux blocs métier fantômes (titre + tuiles).
          for (var i = 0; i < 2; i++) ...[
            const _SkeletonBlock(),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

/// Bloc métier fantôme : bandeau de titre + rangée de 3 tuiles KPI.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SkeletonBox(width: 180, height: 18, radius: 8),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              const Expanded(child: SkeletonBox(height: 96, radius: 14)),
            ],
          ],
        ),
      ],
    );
  }
}
