part of '../admin_modules_screen.dart';

// Graphique d’adoption : coquille et aiguillage.

class _ModuleAdoptionChart extends ConsumerWidget {
  const _ModuleAdoptionChart({
    this.filterModuleId,
    this.filterSchoolId,
  });
  final String? filterModuleId;
  final String? filterSchoolId;

  // ── helpers ────────────────────────────────────────────────────────────────

  Color _barColor(double pct) => pct >= 80
      ? kGreen
      : pct >= 50
          ? kNavy
          : pct > 0
              ? kAccent
              : kTextMuted;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminModuleAdoptionProvider);

    return AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.insights_rounded,
                    size: 18, color: kNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adoption des modules par école',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      filterModuleId != null
                          ? 'Filtré sur un module — écoles utilisatrices en surbrillance'
                          : filterSchoolId != null
                              ? 'Filtré sur une école — modules actifs à droite'
                              : 'Modules adoptés par école (% du catalogue)',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Légende ────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Legend(color: kGreen,     label: '≥ 80 % du catalogue'),
                _Legend(color: kNavy,      label: '≥ 50 %'),
                _Legend(color: kAccent,    label: '< 50 %'),
                _Legend(color: kTextMuted, label: 'Aucun module'),
              ],
            ),

            const SizedBox(height: 16),

            // ── Contenu async ──────────────────────────────────────────
            async.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: kNavy, strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(messageErreur(e),
                    style: TextStyle(color: kRed, fontSize: 12)),
              ),
              data: _buildData,
            ),
          ],
        ),
      ),
    );
  }

  // ── contenu data ───────────────────────────────────────────────────────────

  Widget _buildData(ModuleAdoptionData data) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aucune donnée — configurez des profils d\'accès '
          'et assignez-les aux utilisateurs.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
      );
    }

    // Calcul : nb de modules utilisés par chaque école
    final schoolModCount = <String, int>{};
    for (final e in data.ranking) {
      for (final sid in e.schoolIds) {
        schoolModCount[sid] = (schoolModCount[sid] ?? 0) + 1;
      }
    }
    // Écoles triées par nb décroissant de modules adoptés
    final schools = data.schoolNames.entries.toList()
      ..sort((a, b) =>
          (schoolModCount[b.key] ?? 0).compareTo(schoolModCount[a.key] ?? 0));

    return LayoutBuilder(builder: (_, cx) {
      final wide   = cx.maxWidth > 600;
      final total  = data.ranking.length;
      final chartH = (schools.length * 42.0 + 40.0).clamp(120.0, 360.0);

      final leftPanel =
          _buildSchoolsChart(schools, schoolModCount, data, chartH, total);
      final rightPanel = filterModuleId != null
          ? _buildModuleBreakdown(data)
          : filterSchoolId != null
              ? _buildSchoolDetail(schoolModCount, data)
              : _buildDonutPanel(data);

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: leftPanel),
            const SizedBox(width: 20),
            Container(width: 1, color: kBorder, height: chartH + 50),
            const SizedBox(width: 20),
            SizedBox(width: 210, child: rightPanel),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftPanel,
          const SizedBox(height: 16),
          Divider(color: kBorder),
          const SizedBox(height: 16),
          rightPanel,
        ],
      );
    });
  }

  // ── panel gauche : écoles (barres % catalogue) ────────────────────────────

}
