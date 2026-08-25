import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/exam_archives_provider.dart';
import '../services/exam_statistics_pdf_service.dart';
import 'exam_history_hero.dart';
import 'exam_standings_modal.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HISTORIQUE DES RÉSULTATS — chiffres OFFICIELS de la DEC, empilés.
//
//  Ce qu'on vient y lire tient en une phrase : où en est l'examen, et dans
//  quel sens il va. La section le dit donc dans cet ordre — le taux de la
//  dernière session en grand, son évolution à côté, puis la courbe qui la
//  porte. Le classement des départements, lui, est un tableau de quinze
//  lignes : il s'ouvre en feuille montante (`exam_standings_modal.dart`)
//  plutôt que d'écraser la courbe.
//
//  Une évolution s'exprime en points de pourcentage, jamais en « % de hausse » :
//  passer de 43,65 % à 48,48 % est un gain de 4,83 POINTS, pas de 11 %. La
//  seconde formulation, exacte arithmétiquement, tromperait tout le monde.
// ════════════════════════════════════════════════════════════════════════════
final _selectedExamProvider = StateProvider.autoDispose<String?>((_) => null);

class ExamHistorySection extends ConsumerWidget {
  const ExamHistorySection({super.key, required this.figures});

  /// Reçus de l'écran, qui résout le chargement une fois pour toute la page.
  /// La section ne s'abonne plus au provider : quatre abonnements pour deux
  /// requêtes multipliaient les reconstructions sans rien apporter.
  final List<OfficialFigure> figures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = buildNationalHistory(figures);
    if (histories.isEmpty) return const SizedBox.shrink();

    // Défaut = l'examen au plus gros effectif : c'est celui dont la
    // trajectoire engage le plus le réseau.
    final byWeight = [...histories]..sort((a, b) =>
        (b.latest?.present ?? 0).compareTo(a.latest?.present ?? 0));
    final selected =
        ref.watch(_selectedExamProvider) ?? byWeight.first.examShortName;
    final history = histories.firstWhere(
      (h) => h.examShortName == selected,
      orElse: () => histories.first,
    );

    final years = history.points.map((p) => p.yearLabel).toList();
    final standings = years.isEmpty
        ? const <DepartmentStanding>[]
        : departmentStandings(
            figures,
            examShortName: history.examShortName,
            yearLabel: years.last,
            previousYearLabel: years.length > 1 ? years[years.length - 2] : null,
          );

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle(
              'Historique des résultats',
              icon: Icons.timeline_rounded,
              subtitle: 'Chiffres officiels publiés par la DEC — taux calculés '
                  'sur les présents',
            ),
          ),
          if (standings.isNotEmpty) ...[
            _StandingsButton(
              count: standings.length,
              onTap: () => showExamStandingsModal(
                context,
                history: history,
                standings: standings,
                figures: figures,
                yearLabel: years.last,
              ),
            ),
            const SizedBox(width: 10),
          ],
          AdminPdfButton(
            label: 'Statistiques officielles',
            onTap: () => _openPdf(context, ref, history, standings),
          ),
        ]),
        if (histories.length > 1) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in histories)
                ChoiceChip(
                  label: Text(h.examShortName,
                      style: const TextStyle(fontSize: 12.5)),
                  selected: h.examShortName == history.examShortName,
                  onSelected: (_) => ref
                      .read(_selectedExamProvider.notifier)
                      .state = h.examShortName,
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        ExamHistoryHero(history: history),
        const SizedBox(height: 16),
        _TrendChart(history: history),
      ]),
    );
  }

  void _openPdf(BuildContext context, WidgetRef ref, ExamHistory history,
      List<DepartmentStanding> standings) {
    final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
        'Groupe scolaire';
    showPdfPreviewDialog(
      context,
      title: 'Statistiques ${history.examShortName}',
      subtitle: 'Session ${history.latest?.yearLabel ?? '—'}',
      pdfFileName: 'statistiques_examen.pdf',
      build: (_) => ExamStatisticsPdfService.buildPdf(
          groupName: groupName, history: history, standings: standings),
      onDownload: () => ExamStatisticsPdfService.download(
          groupName: groupName, history: history, standings: standings),
    );
  }
}

/// Accès au classement — chiffré, pour dire ce qu'on trouvera derrière.
class _StandingsButton extends StatelessWidget {
  const _StandingsButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kNavy.withValues(alpha: 0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.leaderboard_rounded, size: 15, color: kNavy),
              const SizedBox(width: 6),
              Text('Classement départemental',
                  style: TextStyle(
                      color: kNavy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: kNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      );
}

// ─── Trajectoire nationale ──────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.history});
  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final points = history.points;
    if (points.isEmpty) return const SizedBox.shrink();
    if (points.length == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.show_chart_rounded, size: 19, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Une seule session archivée : la courbe apparaîtra dès qu\'une '
              'deuxième publication sera déposée.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ),
        ]),
      );
    }

    final rates = points.map((p) => p.rate);
    final maxRate = rates.reduce((a, b) => a > b ? a : b);
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    // Échelle resserrée SOUS le minimum de la série. Caler l'axe sur zéro
    // rendrait quatre taux voisins (62,81 → 66,45 %) visuellement identiques :
    // la tendance, seule chose qu'on vienne lire ici, disparaîtrait. Chaque
    // point porte sa valeur exacte, donc l'échelle n'induit personne en erreur.
    final span = maxRate - minRate;
    final base = span < 0.01 ? maxRate - 1 : minRate - span * 0.55;
    final top = span < 0.01 ? maxRate + 1 : maxRate + span * 0.35;

    return Container(
      height: 268,
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 6),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: AxisLine(color: kBorder),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted),
        ),
        primaryYAxis: NumericAxis(
          minimum: base,
          maximum: top,
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: MajorGridLines(width: 0.6, color: kBorder),
          labelFormat: '{value} %',
          // L'échelle est resserrée, donc ses bornes tombent sur des décimales
          // arbitraires : « 62.077 % » sur une graduation ne veut rien dire et
          // salit la lecture. Les valeurs exactes sont sur les points.
          decimalPlaces: 0,
          interval: _axisInterval(base, top),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
        ),
        tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x : point.y %'),
        series: <CartesianSeries<HistoryPoint, String>>[
          SplineAreaSeries<HistoryPoint, String>(
            dataSource: points,
            xValueMapper: (p, _) => p.yearLabel,
            yValueMapper: (p, _) => p.rate,
            borderColor: kNavy,
            borderWidth: 2.6,
            gradient: LinearGradient(
              colors: [
                kNavy.withValues(alpha: 0.34),
                kNavy.withValues(alpha: 0.02),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            markerSettings: MarkerSettings(
              isVisible: true,
              height: 8,
              width: 8,
              borderWidth: 2.4,
              borderColor: kNavy,
              color: kCardBg,
            ),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.top,
              builder: (data, _, _, _, _) => _PointLabel(point: data as HistoryPoint),
            ),
          ),
        ],
      ),
    );
  }
}

/// Graduation entière la plus lisible pour l'amplitude affichée : jamais plus
/// de cinq lignes, jamais une valeur à virgule.
double _axisInterval(double base, double top) {
  final span = top - base;
  for (final step in const [1.0, 2.0, 5.0, 10.0, 20.0, 25.0, 50.0]) {
    if (span / step <= 5) return step;
  }
  return 100;
}

/// Étiquette d'un point : le taux, et l'évolution qui l'a amené là.
class _PointLabel extends StatelessWidget {
  const _PointLabel({required this.point});
  final HistoryPoint point;

  @override
  Widget build(BuildContext context) {
    final d = point.deltaPoints;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${point.rate.toStringAsFixed(2)} %',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w900, color: kNavy)),
      Text(
          d == null
              ? '${point.admitted}/${point.present}'
              : '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} pt',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: d == null ? kTextMuted : (d >= 0 ? kGreen : kRed))),
    ]);
  }
}
