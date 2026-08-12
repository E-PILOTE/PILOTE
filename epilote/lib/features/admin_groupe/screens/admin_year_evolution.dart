part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉVOLUTION PLURIANNUELLE — deux mesures, deux échelles, une seule lecture.
//
//  ⚠️ CE QUI N'ALLAIT PAS, ET QUI N'ÉTAIT PAS UNE QUESTION DE GOÛT.
//
//   • L'AIRE ÉTAIT DESSINÉE SOUS LES COLONNES. Syncfusion peint les séries dans
//     l'ordre de la liste : l'aire « Élèves » venait en premier, les colonnes
//     « Classes » par-dessus. Avec deux années, chaque colonne occupait un quart
//     de la zone de tracé — deux dalles opaques qui recouvraient la courbe
//     qu'on était venu lire. L'ordre est inversé : les colonnes servent de
//     repère de fond, la courbe passe devant.
//
//   • LA LARGEUR DES COLONNES ÉTAIT UNE FRACTION, DONC UNE SURPRISE. `width`
//     s'exprime en part de l'emplacement de catégorie : à deux années, 0,32
//     donnait des barres de deux cents pixels ; à douze, des traits de vingt.
//     On calcule désormais la fraction pour obtenir une ÉPAISSEUR CONSTANTE
//     (~34 px), quel que soit le nombre d'années à l'écran.
//
//   • L'AXE DES ÉLÈVES AFFICHAIT « 1500000 ». À l'échelle nationale visée, les
//     graduations devenaient illisibles : format compact français (« 1,5 M »).
//
//   • UNE ANNÉE EN BROUILLON PLONGE À ZÉRO — c'est exact, et c'est trompeur.
//     Aucune école ne s'y est encore inscrite parce qu'elle ne l'a pas reçue,
//     pas parce que ses effectifs se sont effondrés. La chute est donc NOMMÉE
//     sous le graphique plutôt que laissée à l'interprétation.
// ════════════════════════════════════════════════════════════════════════════

class _EvoPoint {
  const _EvoPoint(
      this.label, this.eleves, this.classes, this.brouillon, this.aVenir);
  final String label;
  final int eleves, classes;
  final bool brouillon;

  /// La rentrée de cette année n'a pas encore eu lieu.
  final bool aVenir;
}

/// Épaisseur visée d'une colonne, en pixels logiques.
const double _kEpaisseurColonne = 34;

class _EvolutionCard extends StatefulWidget {
  const _EvolutionCard({required this.years});
  final List<AdminYear> years;
  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  late final TooltipBehavior _tt = TooltipBehavior(
    enable: true,
    shared: true,
    color: kNavyDark,
    borderWidth: 0,
    textStyle: const TextStyle(fontSize: 12, color: Colors.white),
    canShowMarker: true,
  );

  @override
  Widget build(BuildContext context) {
    // Ordre chronologique (la liste source est triée DESC).
    final pts = widget.years.reversed
        .map((y) =>
            _EvoPoint(y.label, y.eleves, y.classes, y.isDraft, y.isFuture))
        .toList();
    final hasData = pts.any((p) => p.eleves > 0 || p.classes > 0);
    final brouillons =
        pts.where((p) => p.brouillon).map((p) => p.label).toList();
    // Une année publiée, à venir, sans un seul inscrit : le zéro est exact et
    // l'effondrement qu'il dessine est faux. Les écoles ont peut-être déjà
    // ouvert leurs classes — la courbe des élèves, elle, part de zéro.
    final aVenirVides = pts
        .where((p) => !p.brouillon && p.aVenir && p.eleves == 0)
        .map((p) => p.label)
        .toList();

    return AdminCard(
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead('Évolution des effectifs',
              icon: Icons.show_chart_rounded,
              tint: kGreen,
              subtitle:
                  'Élèves inscrits et classes ouvertes par année scolaire'),
          const SizedBox(height: 14),
          SizedBox(
            height: 285,
            child: !hasData
                ? const _ChartEmpty(
                    message: 'Les effectifs apparaîtront dès la préparation '
                        'des classes par les écoles.')
                : LayoutBuilder(
                    builder: (context, c) => _graphe(pts, c.maxWidth),
                  ),
          ),
          if (brouillons.isNotEmpty) ...[
            const SizedBox(height: 10),
            _NoteGraphe(
              icon: Icons.edit_note_rounded,
              color: kAccent,
              message: brouillons.length == 1
                  ? '${brouillons.first} retombe à zéro parce qu\'elle est '
                      'encore en brouillon : les écoles ne l\'ont pas reçue, '
                      'aucune inscription ne peut s\'y rattacher.'
                  : '${brouillons.join(', ')} retombent à zéro : ces années '
                      'sont encore en brouillon, les écoles ne les ont pas '
                      'reçues.',
            ),
          ],
          if (aVenirVides.isNotEmpty) ...[
            const SizedBox(height: 10),
            _NoteGraphe(
              icon: Icons.schedule_rounded,
              color: kNavy,
              message: aVenirVides.length == 1
                  ? '${aVenirVides.first} affiche zéro élève : sa rentrée n\'a '
                      'pas encore eu lieu et les inscriptions n\'y ont pas '
                      'commencé — ce n\'est pas une baisse d\'effectifs.'
                  : '${aVenirVides.join(', ')} affichent zéro élève : leur '
                      "rentrée n'a pas encore eu lieu — ce n'est pas une "
                      "baisse d'effectifs.",
            ),
          ],
        ],
      ),
    );
  }

  Widget _graphe(List<_EvoPoint> pts, double largeurCarte) {
    // Zone de tracé ≈ carte moins les deux axes. La fraction qui donne une
    // colonne de `_kEpaisseurColonne` pixels vaut `épaisseur × n / tracé`.
    final trace = (largeurCarte - 96).clamp(160.0, 6000.0);
    final largeurColonne =
        (_kEpaisseurColonne * pts.length / trace).clamp(0.04, 0.55);

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: _tt,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        alignment: ChartAlignment.near,
        overflowMode: LegendItemOverflowMode.wrap,
        iconHeight: 11,
        iconWidth: 11,
        textStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: kTextMuted,
        ),
      ),
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(width: 1, color: kBorder),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: kTextPrimary,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        numberFormat: NumberFormat.compact(locale: 'fr_FR'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: kBorder.withValues(alpha: 0.65),
          dashArray: const <double>[4, 5],
        ),
        labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'yClasses',
          opposedPosition: true,
          minimum: 0,
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(fontSize: 11, color: kTextMuted),
        ),
      ],
      series: <CartesianSeries<_EvoPoint, String>>[
        // Repère de fond : les classes. Volontairement discrètes — elles
        // situent, elles ne racontent pas.
        ColumnSeries<_EvoPoint, String>(
          dataSource: pts,
          xValueMapper: (p, _) => p.label,
          yValueMapper: (p, _) => p.classes,
          name: 'Classes',
          yAxisName: 'yClasses',
          width: largeurColonne,
          animationDuration: 900,
          // Un aplat de bleu marine à faible opacité vire au gris : `kNavy` est
          // une teinte très désaturée, et à 17 % les colonnes se lisaient comme
          // une série désactivée. Un dégradé les rend franchement bleues en
          // haut tout en les laissant s'effacer derrière la courbe en bas.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kNavy.withValues(alpha: 0.58),
              kNavy.withValues(alpha: 0.20),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        ),
        // Le récit : les élèves.
        SplineAreaSeries<_EvoPoint, String>(
          dataSource: pts,
          xValueMapper: (p, _) => p.label,
          yValueMapper: (p, _) => p.eleves,
          name: 'Élèves',
          animationDuration: 1100,
          splineType: SplineType.natural,
          borderColor: kGreen,
          borderWidth: 3,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kGreen.withValues(alpha: 0.22),
              kGreen.withValues(alpha: 0.01),
            ],
          ),
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 9,
            width: 9,
            color: kCardBg,
            borderColor: kGreen,
            borderWidth: 2.5,
          ),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne d'explication sous un graphique — ce que la courbe ne peut pas dire.
class _NoteGraphe extends StatelessWidget {
  const _NoteGraphe({
    required this.icon,
    required this.color,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}
