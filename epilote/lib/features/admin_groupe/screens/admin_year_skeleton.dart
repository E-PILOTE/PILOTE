part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SKELETON — chargement (shimmer) calqué sur la vraie disposition de la page.
//
//  ⚠️ Les couleurs viennent des JETONS, pas de deux hex figés. La version
//  précédente clignotait en `#E8ECF0` → `#F5F7FA` : sur les thèmes Sombre et
//  Melack, dont le fond est presque noir, l'écran de chargement était un éclair
//  blanc avant que la page ne s'affiche en sombre. `kBorder` → `kSurface` suit
//  la palette active, comme le fait déjà `ShimmerPanel` (staff_ui.dart).
// ════════════════════════════════════════════════════════════════════════════

class _YearsSkeleton extends StatelessWidget {
  const _YearsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(r)),
      );

  /// Filet de chapitre : la ligne qui sépare « Vue d'ensemble » d'« Analyses ».
  Widget _chapitre() => Row(
        children: [
          _box(150, 13, r: 6),
          const SizedBox(width: 14),
          Expanded(child: _box(double.infinity, 1, r: 1)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: kBorder,
      highlightColor: kSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 90),
        children: [
          // En-tête : icône + titres + commandes.
          //
          // Le seuil est celui de `_Header` : sous 1 000 px, les commandes y
          // descendent d'une ligne. Un squelette qui ne suivrait pas ferait
          // sauter la page au moment où les données arrivent — c'est justement
          // ce qu'un squelette existe pour éviter.
          LayoutBuilder(builder: (context, c) {
            final titre = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(46, 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(260, 18, r: 8),
                      const SizedBox(height: 8),
                      _box(420, 12, r: 6),
                    ],
                  ),
                ),
              ],
            );
            final boutons = [
              _box(44, 44, r: 8),
              _box(140, 44, r: 8),
              _box(160, 44, r: 8),
              _box(150, 44, r: 8),
            ];
            if (c.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titre),
                  const SizedBox(width: 16),
                  for (final (i, b) in boutons.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    b,
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titre,
                const SizedBox(height: 14),
                Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: boutons),
              ],
            );
          }),
          const SizedBox(height: 18),
          // Lentille d'année : identité (46 + marges) + filet + rail (56 + marges).
          _box(double.infinity, 161, r: 14),
          const SizedBox(height: _kGapChapitre),
          _chapitre(),
          const SizedBox(height: _kGapTitre),
          // KPI grid — seuils et `mainAxisExtent` STRICTEMENT ceux de `_KpiRow`.
          // Deux colonnes ici et quatre là-bas, et la page saute d'un demi-écran
          // à l'instant précis où les données arrivent.
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 740 ? 4 : (c.maxWidth >= 470 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 190,
                ),
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 16),
              );
            },
          ),
          const SizedBox(height: _kGapCarte),
          // Frise
          _box(double.infinity, 250, r: 16),
          const SizedBox(height: _kGapChapitre),
          _chapitre(),
          const SizedBox(height: _kGapTitre),
          // Évolution
          _box(double.infinity, 330, r: 16),
          const SizedBox(height: _kGapCarte),
          // Analytics row (dept + donut) — même seuil que `_AnalyticsRow`.
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 720) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _box(double.infinity, 360, r: 16)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _box(double.infinity, 360, r: 16)),
                  ],
                );
              }
              return Column(
                children: [
                  _box(double.infinity, 340, r: 16),
                  const SizedBox(height: 16),
                  _box(double.infinity, 320, r: 16),
                ],
              );
            },
          ),
          const SizedBox(height: _kGapCarte),
          // Table adoption
          _box(double.infinity, 300, r: 16),
        ],
      ),
    );
  }
}
