import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BANDEAU DE TÊTE DE L'HISTORIQUE — le taux de la dernière session en grand,
//  son évolution à côté, l'assiette dessous, et trois repères de période.
//  C'est la réponse à « où en est cet examen » avant même de lire la courbe.
// ════════════════════════════════════════════════════════════════════════════
class ExamHistoryHero extends StatelessWidget {
  const ExamHistoryHero({super.key, required this.history});
  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final last = history.latest;
    if (last == null) return const SizedBox.shrink();
    final points = history.points;
    final best = points.reduce((a, b) => b.rate > a.rate ? b : a);
    final worst = points.reduce((a, b) => b.rate < a.rate ? b : a);
    final gain = history.totalGain;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kNavy.withValues(alpha: 0.10), kNavy.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy.withValues(alpha: 0.16)),
      ),
      child: LayoutBuilder(builder: (ctx, c) {
        final head = _Head(history: history, last: last);
        final stats = _Stats(
          points: points.length,
          best: best,
          worst: worst,
          gain: gain,
        );
        if (c.maxWidth < 720) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [head, const SizedBox(height: 14), stats]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          head,
          const SizedBox(width: 24),
          Expanded(child: stats),
        ]);
      }),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.history, required this.last});
  final ExamHistory history;
  final HistoryPoint last;

  @override
  Widget build(BuildContext context) {
    final d = last.deltaPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${history.examShortName} · ${last.yearLabel}',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(last.rate.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: kNavy)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 3),
            child: Text('%',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: d == null
                ? Text('première session',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted))
                : _DeltaPill(points: d),
          ),
        ]),
        const SizedBox(height: 5),
        Text('${last.admitted} admis sur ${last.present} présents',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.points,
    required this.best,
    required this.worst,
    required this.gain,
  });
  final int points;
  final HistoryPoint best;
  final HistoryPoint worst;
  final double? gain;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Tile(
            label: 'Meilleure session',
            value: '${best.rate.toStringAsFixed(2)} %',
            sub: best.yearLabel,
            color: kGreen,
            icon: Icons.trending_up_rounded,
          ),
          _Tile(
            label: 'Plus faible',
            value: '${worst.rate.toStringAsFixed(2)} %',
            sub: worst.yearLabel,
            color: kRed,
            icon: Icons.trending_down_rounded,
          ),
          _Tile(
            label: 'Sur la période',
            value: gain == null
                ? '—'
                : '${gain! >= 0 ? '+' : ''}${gain!.toStringAsFixed(2)} pt',
            sub: '$points session(s)',
            color: (gain ?? 0) >= 0 ? kGreen : kRed,
            icon: Icons.stacked_line_chart_rounded,
          ),
        ],
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                  Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: kTextMuted)),
                ]),
          ),
        ]),
      );
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.points});
  final double points;

  @override
  Widget build(BuildContext context) {
    final c = points >= 0 ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            points >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: c),
        const SizedBox(width: 4),
        Text('${points.abs().toStringAsFixed(2)} pt',
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c)),
        const SizedBox(width: 4),
        Text('vs session précédente',
            style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.85))),
      ]),
    );
  }
}
