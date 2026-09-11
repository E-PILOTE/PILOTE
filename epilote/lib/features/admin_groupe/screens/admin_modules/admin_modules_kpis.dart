part of '../admin_modules_screen.dart';

// Bandeau de cartouches et donnees d’adoption.

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.catalog, required this.catColors});
  final AdminModulesCatalog catalog;
  final Map<String, Color> catColors;

  @override
  Widget build(BuildContext context) {
    final totalMods = catalog.moduleCount;
    final activatedMods = catalog.categories
        .expand((c) => c.modules)
        .where((m) => m.authorizedProfiles > 0)
        .length;
    final profiles    = catalog.totalProfiles;
    final coveragePct = totalMods > 0
        ? (activatedMods / totalMods * 100).round()
        : 0;
    // Catégories ayant au moins 1 module activé (profil attribué)
    final activeCats = catalog.categories
        .where((c) => c.modules.any((m) => m.authorizedProfiles > 0))
        .length;
    final catCoverage = catalog.categories.isNotEmpty
        ? activeCats / catalog.categories.length
        : 0.0;
    // Profils : taux de couverture modules activés
    final profileCoverage =
        totalMods > 0 ? activatedMods / totalMods : 0.0;

    return LayoutBuilder(
      builder: (_, constraints) {
        final w    = constraints.maxWidth;
        final cols = w >= 1000 ? 4 : (w >= 600 ? 2 : 1);
        const gap  = 16.0;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kNavy,
                icon: Icons.widgets_rounded,
                value: '$totalMods',
                label: 'Modules',
                sub: 'inclus dans le plan',
                progress: totalMods > 0 ? activatedMods / totalMods : 0.0,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kGreen,
                icon: Icons.shield_rounded,
                value: '$activatedMods',
                label: 'Modules activés',
                sub: '$coveragePct% de couverture',
                progress: totalMods > 0 ? activatedMods / totalMods : 0.0,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kNavy,
                icon: Icons.groups_rounded,
                value: '$profiles',
                label: "Profils d'accès",
                sub: '$coveragePct% des modules couverts',
                progress: profileCoverage,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _ModKpiCard(
                color: kAccent,
                icon: Icons.category_rounded,
                value: '${catalog.categories.length}',
                label: 'Catégories',
                sub: '$activeCats catégorie${activeCats > 1 ? 's' : ''} active${activeCats > 1 ? 's' : ''}',
                progress: catCoverage,
                catSwatches: [
                  for (final c in catalog.categories)
                    catColors[c.slug] ?? kNavy,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Carte KPI verticale — même design que le Tableau de bord :
/// barre couleur (4 px) + icon (44 px) + valeur (24 px) + label + spark.
class _ModKpiCard extends StatelessWidget {
  const _ModKpiCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    this.progress,
    this.catSwatches,
  });
  final Color        color;
  final IconData     icon;
  final String       value;
  final String       label;
  final String       sub;
  final double?      progress;    // null = pas de spark
  final List<Color>? catSwatches; // mini swatches de couleurs catégories

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre accent top
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 14),
                  // Valeur
                  Text(value,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  // Label
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  // Sous-titre
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  // Mini swatches catégories (carte "Catégories" uniquement)
                  if (catSwatches != null && catSwatches!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final c in catSwatches!)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ],
                  // Spark (barre de progression ou espace vide)
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: kBorder,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(progress! * 100).round()}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Données graphe adoption ───────────────────────────────────────────────────

class _AdoptData {
  const _AdoptData({
    required this.label,
    required this.pct,
    required this.color,
    required this.detail,
  });
  final String label;
  final double pct;   // 0–100
  final Color  color;
  final String detail; // '3/5'
}

class _DonutSlice {
  const _DonutSlice(this.label, this.count, this.color);
  final String label;
  final int    count;
  final Color  color;
}

// ── Graphe décisionnel : adoption des modules par école ───────────────────────
