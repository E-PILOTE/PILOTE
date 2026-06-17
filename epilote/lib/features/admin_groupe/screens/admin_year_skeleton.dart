part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SKELETON — chargement (shimmer) calqué sur la vraie disposition de la page.
// ════════════════════════════════════════════════════════════════════════════

class _YearsSkeleton extends StatelessWidget {
  const _YearsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF0),
      highlightColor: const Color(0xFFF5F7FA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 90),
        children: [
          // En-tête : icône + titres + 3 boutons
          Row(
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
              const SizedBox(width: 16),
              _box(150, 44, r: 8),
              const SizedBox(width: 10),
              _box(150, 44, r: 8),
              const SizedBox(width: 10),
              _box(140, 44, r: 8),
            ],
          ),
          const SizedBox(height: 18),
          // Sélecteur d'année
          _box(double.infinity, 104, r: 14),
          const SizedBox(height: 18),
          // KPI grid (responsive)
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 196,
                ),
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 16),
              );
            },
          ),
          const SizedBox(height: 22),
          // Évolution
          _box(double.infinity, 330, r: 16),
          const SizedBox(height: 16),
          // Analytics row (dept + donut)
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 820) {
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
          const SizedBox(height: 16),
          // Table adoption
          _box(double.infinity, 300, r: 16),
        ],
      ),
    );
  }
}
