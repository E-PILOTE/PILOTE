part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE BLOC DE RÉSULTATS — le compteur « n dossiers sur N », l'export PDF, et le
//  squelette affiché pendant le chargement.
//
//  Ce qui reste d'inscriptions_page_parts.dart après découpe : l'entête KPI
//  est passée dans inscriptions_kpi_parts.dart, la barre de filtres dans
//  inscriptions_filtres_parts.dart.
// ════════════════════════════════════════════════════════════════════════════

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {super.key, required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) => Row(children: [
        // « inscrit » était faux : la requête du provider exclut
        // `status = 'active'`, donc cette page ne montre QUE des dossiers non
        // encore validés. L'élève inscrit, lui, vit dans la page Élèves.
        Text('$filtered dossier${filtered > 1 ? 's' : ''}',
            style: TextStyle(
                color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        if (filtered < total) ...[
          const SizedBox(width: 8),
          Text('sur $total',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
        ],
        const Spacer(),
        if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
      ]);
}

// ─── Skeleton de chargement (shimmer, calqué sur la vraie page) ──────────────
class _InscriptionsSkeleton extends StatelessWidget {
  const _InscriptionsSkeleton();

  Widget _box(double w, double h, {double r = 12}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    // Jetons de thème, pas des gris figés : ce squelette est le TOUT PREMIER
    // écran affiché à l'ouverture du module. En gris clair codé en dur, il
    // éclatait en blanc sur le fond sombre avant même que la page existe.
    return Shimmer.fromColors(
      baseColor: kSurface,
      highlightColor: kBorder,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero KPI (6 cartes responsives)
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1180
                  ? 6
                  : c.maxWidth >= 920
                      ? 4
                      : c.maxWidth >= 600
                          ? 3
                          : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 12),
              );
            }),
            const SizedBox(height: 26),
            // Carte « Répartition » (en-tête + grille)
            _box(double.infinity, 320, r: 12),
            const SizedBox(height: 26),
            // Évolution
            _box(180, 16, r: 6),
            const SizedBox(height: 12),
            _box(double.infinity, 230, r: 12),
            const SizedBox(height: 22),
            // Barre de filtres
            _box(double.infinity, 110, r: 8),
            const SizedBox(height: 18),
            // Quelques lignes de tableau
            for (var i = 0; i < 6; i++) ...[
              _box(double.infinity, 52, r: 10),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
