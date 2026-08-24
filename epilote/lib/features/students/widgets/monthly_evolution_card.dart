import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/theme/chart_palette.dart';
import '../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GRAPHE D'ÉVOLUTION MENSUEL (réutilisable) — flux du mois en colonnes, stock
//  cumulé en bandeau. Utilisé par Inscriptions (rythme de la campagne) et
//  Élèves (croissance de l'effectif).
//
//  ── CE QUI AVAIT DÉJÀ ÉTÉ CORRIGÉ, ET QUI RESTE VRAI ───────────────────────
//
//   • LE FOND DU GRAPHIQUE RESTAIT CLAIR EN THÈME SOMBRE. Sans
//     `backgroundColor: Colors.transparent`, Syncfusion peint sa propre
//     surface : une dalle blanche au milieu d'une carte `kCardBg` foncée.
//
//   • LA LARGEUR DES COLONNES ÉTAIT UNE FRACTION, DONC UNE SURPRISE. `width`
//     s'exprime en part de l'emplacement de catégorie : à deux mois, 0,55
//     donnait des dalles de deux cents pixels ; à douze, des traits de vingt.
//     On calcule la fraction qui donne une ÉPAISSEUR CONSTANTE.
//
//   • LES AXES N'AVAIENT PAS DE MINIMUM. Syncfusion cadre alors sur les
//     données : une courbe de cumul allant de 280 à 310 remplissait toute la
//     hauteur et dessinait une explosion d'effectif là où il y avait +10 %.
//     Un graphique de volume qui ne part pas de zéro ment par construction.
//
//   • LA LÉGENDE ÉTAIT UN `Row`, qui débordait sous ~260 px. `Wrap`.
//
//  ── LA REFONTE — CE QUI N'ÉTAIT PAS QU'UNE QUESTION DE GOÛT ────────────────
//
//   • ⚠️ IL Y AVAIT DEUX AXES Y SUR UN MÊME TRACÉ. C'est le défaut classique
//     de la visualisation de données. Le flux mensuel (quelques dizaines) et
//     l'effectif cumulé (quelques centaines) n'ont aucune échelle commune :
//     l'endroit où la courbe croise les colonnes est donc fixé par le cadrage,
//     pas par les chiffres. Le graphe FABRIQUAIT une corrélation — selon le
//     cadrage, la courbe passait au-dessus ou en dessous des colonnes sans
//     qu'une seule donnée n'ait bougé. Deux mesures d'échelles différentes se
//     lisent en DEUX tracés. D'où deux panneaux, alignés au pixel par un
//     `labelsExtent` commun et partageant une seule ligne de mois.
//
//   • LES COULEURS ÉCHOUAIENT À LA MESURE, pas au goût. `kNavy` a une chroma
//     de 0,074 : en aplat, il « lit gris ». `kAccent` jaune tient 1,66:1 sur
//     une carte blanche, quand 3:1 est le minimum. Les séries prennent
//     désormais leurs teintes dans `core/theme/chart_palette.dart`, où le
//     détail des mesures est consigné.
//
//   • LES DÉGRADÉS SUR LES COLONNES ont disparu. Un dégradé saturé sur une
//     grande surface lit lourd ; l'aplat fin lit net. Idem pour l'aire : un
//     lavis à 10 %, pas un bloc.
//
//   • LA GRILLE ÉTAIT EN POINTILLÉS. Un pointillé se lit comme un seuil ou une
//     projection ; ce n'était qu'une grille. Filet plein, une nuance au-dessus
//     du fond.
//
//   • UN MARQUEUR SUR CHAQUE POINT faisait un collier de perles sur douze
//     mois. Un seul repère, au dernier point, avec sa valeur écrite : c'est
//     celui qu'on vient lire.
//
//   • L'INFOBULLE PORTE LES TROIS CHIFFRES du mois survolé, sur les deux
//     panneaux. Séparer les tracés ne devait pas obliger à survoler deux fois
//     pour reconstituer « 12 validées, 3 en attente, 148 au total » — c'était
//     déjà la raison d'être de l'infobulle partagée d'origine.
// ════════════════════════════════════════════════════════════════════════════

/// Un mois du graphe.
///
/// [count] = flux principal du mois (colonne du bas), [cumul] = stock à la fin
/// de ce mois (bandeau du bas), [stack] = flux secondaire empilé par-dessus
/// [count] (0 partout = pas de seconde série).
class EvoPoint {
  const EvoPoint(this.label, this.count, this.cumul, {this.stack = 0});
  final String label;
  final int count, cumul;
  final int stack;

  /// Hauteur totale de la colonne (les deux segments empilés).
  int get total => count + stack;
}

/// Épaisseur visée d'une colonne, en pixels logiques. Une colonne se plafonne
/// à 24 px : au-delà, elle remplit son emplacement et l'air disparaît.
const double _kEpaisseurColonne = 22;

/// Largeur FIXE réservée aux libellés de l'axe Y, sur les DEUX panneaux.
///
/// ⚠️ C'est elle qui aligne les deux tracés. Sans elle, Syncfusion dimensionne
/// chaque gouttière sur son plus large libellé — « 40 » d'un côté, « 900 » de
/// l'autre — et les colonnes ne tombent plus au-dessus de leur propre courbe.
const double _kGouttiereY = 36;

const double _kHauteurFlux = 172;
const double _kHauteurCumul = 76;

class MonthlyEvolutionCard extends StatefulWidget {
  const MonthlyEvolutionCard({
    super.key,
    required this.points,
    this.barLabel = 'Entrées du mois',
    this.lineLabel = 'Effectif cumulé',
    this.stackLabel,
    this.note,
    this.emptyMessage =
        'Pas encore assez d\'historique pour tracer une évolution.',
    this.barColor,
    this.lineColor,
    this.stackColor,
  });

  final List<EvoPoint> points;
  final String barLabel, lineLabel;

  /// Libellé de la série empilée. `null` → une seule série de colonnes.
  final String? stackLabel;

  /// Ligne d'explication sous le graphe — ce que la courbe ne peut pas dire.
  final String? note;

  /// Message affiché tant qu'il n'y a pas deux mois à comparer.
  final String emptyMessage;

  /// Couleurs de série. `null` → la palette de graphique du thème courant.
  ///
  /// ⚠️ Résolues dans `build`, jamais dans le constructeur : un jeton de
  /// couleur capturé à la construction resterait figé sur le thème de
  /// démarrage et ne suivrait plus une bascule Clair/Sombre.
  final Color? barColor, lineColor, stackColor;

  @override
  State<MonthlyEvolutionCard> createState() => _MonthlyEvolutionCardState();
}

class _MonthlyEvolutionCardState extends State<MonthlyEvolutionCard> {
  // Deux instances : un `TooltipBehavior` porte l'état du tracé auquel il est
  // attaché — le partager entre deux graphes les fait se marcher dessus.
  late final TooltipBehavior _ttFlux = _bulle();
  late final TooltipBehavior _ttCumul = _bulle();

  TooltipBehavior _bulle() => TooltipBehavior(
        enable: true,
        color: Colors.transparent,
        elevation: 0,
        borderWidth: 0,
        // Le contenu est reconstruit à chaque survol : les couleurs y sont
        // relues, donc l'infobulle suit une bascule de thème.
        builder: (data, _, _, _, _) => data is EvoPoint
            ? _BulleMois(point: data, carte: widget)
            : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final empile = widget.stackLabel != null && pts.any((p) => p.stack > 0);

    // Un seul mois ne fait pas une évolution : on le dit, au lieu de laisser
    // la section disparaître sans un mot.
    if (pts.length < 2) {
      return AdminCard(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Icon(Icons.timeline_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.emptyMessage,
                style:
                    TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
          ),
        ]),
      );
    }

    final palette = ChartPalette.of(context);
    final cBar = widget.barColor ?? palette.serie1;
    final cStack = widget.stackColor ?? palette.serie2;
    final cCumul = widget.lineColor ?? palette.serie3;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10, right: 4),
            // `Wrap` et non `Row` : trois entrées ne tiennent pas sur une carte
            // étroite, et un débordement de légende barre le graphe entier.
            child: Wrap(spacing: 16, runSpacing: 6, children: [
              _LegendDot(color: cBar, label: widget.barLabel),
              if (empile) _LegendDot(color: cStack, label: widget.stackLabel!),
              _LegendDot(color: cCumul, label: widget.lineLabel, line: true),
            ]),
          ),
          SizedBox(
            height: _kHauteurFlux,
            child: LayoutBuilder(
              builder: (context, c) =>
                  _panneauFlux(pts, empile, c.maxWidth, cBar, cStack),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(height: _kHauteurCumul, child: _panneauCumul(pts, cCumul)),
          if (widget.note != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 2),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 14, color: kTextMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(widget.note!,
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted, height: 1.4)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Panneau du haut : le flux du mois, sur son échelle ─────────────────────
  Widget _panneauFlux(List<EvoPoint> pts, bool empile, double largeurCarte,
      Color cBar, Color cStack) {
    // Zone de tracé ≈ carte moins la gouttière. La fraction qui donne une
    // colonne de `_kEpaisseurColonne` pixels vaut `épaisseur × n / tracé`.
    final trace = (largeurCarte - _kGouttiereY - 24).clamp(140.0, 6000.0);
    final largeurColonne =
        (_kEpaisseurColonne * pts.length / trace).clamp(0.05, 0.6);
    final maxFlux = pts.fold<int>(0, (m, p) => p.total > m ? p.total : m);

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: _ttFlux,
      primaryXAxis: _axeMois(muet: true),
      primaryYAxis: NumericAxis(
        minimum: 0,
        interval: _pas(maxFlux),
        labelsExtent: _kGouttiereY,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        // Filet PLEIN : un pointillé se lit comme un seuil ou une projection.
        majorGridLines: MajorGridLines(width: 1, color: kBorder),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
      ),
      series: <CartesianSeries<EvoPoint, String>>[
        if (empile) ...[
          StackedColumnSeries<EvoPoint, String>(
            name: widget.barLabel,
            dataSource: pts,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.count,
            width: largeurColonne,
            animationDuration: 650,
            color: cBar,
            // Ce filet n'est pas un contour de séparation : c'est l'ÉCART, en
            // couleur de surface, que deux segments empilés doivent laisser
            // entre eux. Syncfusion n'expose pas d'écart — on le peint.
            borderColor: kCardBg,
            borderWidth: 1.5,
          ),
          // Le segment du haut porte seul l'arrondi : l'appliquer aussi à celui
          // du bas laisserait une encoche claire à la jonction des deux.
          StackedColumnSeries<EvoPoint, String>(
            name: widget.stackLabel!,
            dataSource: pts,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.stack,
            width: largeurColonne,
            animationDuration: 650,
            color: cStack,
            borderColor: kCardBg,
            borderWidth: 1.5,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ] else
          ColumnSeries<EvoPoint, String>(
            name: widget.barLabel,
            dataSource: pts,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.count,
            width: largeurColonne,
            animationDuration: 650,
            color: cBar,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
      ],
    );
  }

  // ── Panneau du bas : le stock cumulé, sur SA propre échelle ────────────────
  Widget _panneauCumul(List<EvoPoint> pts, Color cCumul) {
    final dernier = pts.length - 1;

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      tooltipBehavior: _ttCumul,
      primaryXAxis: _axeMois(muet: false),
      // Pas de graduation ici : la valeur qu'on vient lire est écrite au bout
      // de la courbe, et le survol donne le reste. Un libellé direct vaut mieux
      // qu'une grille, et une grille mieux qu'un second axe.
      primaryYAxis: NumericAxis(
        minimum: 0,
        labelsExtent: _kGouttiereY,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: const MajorGridLines(width: 0),
        axisLabelFormatter: (d) => ChartAxisLabel('', d.textStyle),
      ),
      series: <CartesianSeries<EvoPoint, String>>[
        SplineAreaSeries<EvoPoint, String>(
          name: widget.lineLabel,
          dataSource: pts,
          xValueMapper: (p, _) => p.label,
          yValueMapper: (p, _) => p.cumul,
          animationDuration: 900,
          splineType: SplineType.natural,
          borderColor: cCumul,
          borderWidth: 2,
          // Lavis, pas bloc : l'aire situe le niveau, elle ne le crie pas.
          color: cCumul.withValues(alpha: 0.10),
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 8,
            width: 8,
            color: cCumul,
            // Anneau en couleur de carte : le repère reste lisible là où il
            // croise sa propre courbe.
            borderColor: kCardBg,
            borderWidth: 2,
          ),
          // ⚠️ Un seul point porte sa valeur : le dernier. Douze marqueurs font
          // un collier de perles et douze nombres font du bruit — personne ne
          // les lit. On étiquette le point qu'on vient chercher.
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            builder: (data, point, series, index, seriesIndex) =>
                index == dernier && data is EvoPoint
                    ? _EtiquetteFin(valeur: data.cumul)
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// L'axe des mois. `muet` → l'axe existe (il cadre le tracé) mais ne réécrit
  /// pas les mois : ils ne sont portés qu'UNE fois, tout en bas.
  CategoryAxis _axeMois({required bool muet}) => CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(width: 1, color: kBorder),
        majorTickLines: const MajorTickLines(size: 0),
        // Sans marge, `CategoryAxis` colle la première et la dernière colonne
        // aux bords du tracé et les COUPE EN DEUX. Le mois de la rentrée est
        // toujours le premier, et c'est le plus chargé de l'année : sa colonne
        // s'affichait sciée par l'axe, moitié moins haute en apparence que sa
        // voisine à valeur égale.
        plotOffset: _kEpaisseurColonne / 2 + 4,
        // Douze « sept. 25 » sur une carte étroite se chevauchaient en bouillie.
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        labelStyle: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: kTextMuted),
        axisLabelFormatter: muet ? (d) => ChartAxisLabel('', d.textStyle) : null,
      );
}

/// Graduation entière : sans elle, un axe plafonnant à 3 affiche « 0 ; 0,5 ;
/// 1 ; 1,5 » — des demi-élèves. Au-delà de 5, l'ajustement automatique de
/// Syncfusion tombe déjà sur des entiers.
double? _pas(int max) => max <= 5 ? 1.0 : null;

/// La valeur du dernier point, posée au bout de la courbe.
class _EtiquetteFin extends StatelessWidget {
  const _EtiquetteFin({required this.valeur});
  final int valeur;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: kBorder),
        ),
        // ⚠️ Le texte ne porte JAMAIS la couleur de la série : l'identité vient
        // de la pastille de légende, le chiffre reste en encre.
        child: Text(fmtInt(valeur),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
      );
}

/// Les trois chiffres du mois survolé, en une seule bulle.
class _BulleMois extends StatelessWidget {
  const _BulleMois({required this.point, required this.carte});
  final EvoPoint point;
  final MonthlyEvolutionCard carte;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final empile = carte.stackLabel != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: kNavyDark,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 5),
          _ligne(carte.barColor ?? palette.serie1, carte.barLabel, point.count),
          if (empile)
            _ligne(carte.stackColor ?? palette.serie2, carte.stackLabel!,
                point.stack),
          _ligne(
              carte.lineColor ?? palette.serie3, carte.lineLabel, point.cumul),
        ],
      ),
    );
  }

  Widget _ligne(Color c, String label, int valeur) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text('$label  ',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Text(fmtInt(valeur),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(
      {required this.color, required this.label, this.line = false});
  final Color color;
  final String label;
  final bool line;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: line ? 16 : 10,
          height: line ? 3 : 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(line ? 2 : 3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kTextMuted)),
      ]);
}
