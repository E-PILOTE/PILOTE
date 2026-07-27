import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HISTORIQUE DES RÉSULTATS — chiffres OFFICIELS de la DEC, empilés.
//
//  Deux lectures, celles-là mêmes que le ministère publie chaque année :
//   • la TRAJECTOIRE nationale d'un examen, année après année ;
//   • le CLASSEMENT ordinal des départements sur la dernière session, avec
//     l'évolution de chacun en POINTS.
//
//  Une évolution s'exprime en points de pourcentage, jamais en « % de hausse » :
//  passer de 43,65 % à 48,48 % est un gain de 4,83 POINTS, pas de 11 %. La
//  seconde formulation, exacte arithmétiquement, tromperait tout le monde.
// ════════════════════════════════════════════════════════════════════════════
final _selectedExamProvider = StateProvider.autoDispose<String?>((_) => null);

class ExamHistorySection extends ConsumerWidget {
  const ExamHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final figures = ref.watch(officialFiguresProvider).valueOrNull ?? const [];
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
        const AdminSectionTitle(
          'Historique des résultats',
          icon: Icons.timeline_rounded,
          subtitle: 'Chiffres officiels publiés par la DEC — taux calculés sur '
              'les présents',
        ),
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
        const SizedBox(height: 18),
        _Trend(history: history),
        if (standings.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Classement départemental · ${years.last}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 10),
          _Standings(rows: standings),
        ],
      ]),
    );
  }
}

// ─── Trajectoire nationale ──────────────────────────────────────────────────
class _Trend extends StatelessWidget {
  const _Trend({required this.history});
  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final points = history.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final rates = points.map((p) => p.rate);
    final maxRate = rates.reduce((a, b) => a > b ? a : b);
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    // Base de l'échelle placée SOUS le minimum de la série. Caler les barres
    // sur zéro rendrait quatre taux voisins (62,81 → 66,45 %) visuellement
    // identiques : la tendance, seule chose qu'on vienne lire ici,
    // disparaîtrait. Chaque barre porte sa valeur exacte au-dessus, donc
    // l'échelle resserrée n'induit personne en erreur.
    final base = maxRate - minRate < 0.01
        ? maxRate - 1
        : minRate - (maxRate - minRate) * 0.6;
    final gain = history.totalGain;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final p in points) ...[
          Expanded(child: _Bar(point: p, maxRate: maxRate, base: base)),
          if (p != points.last) const SizedBox(width: 10),
        ],
      ]),
      if (gain != null) ...[
        const SizedBox(height: 12),
        Text(
          '${points.first.yearLabel} → ${points.last.yearLabel} : '
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)} points '
          'sur ${points.length} sessions',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gain >= 0 ? kGreen : kRed),
        ),
      ],
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.point, required this.maxRate, required this.base});
  final HistoryPoint point;
  final double maxRate;

  /// Bas de l'échelle — voir `_Trend`.
  final double base;

  @override
  Widget build(BuildContext context) {
    final span = maxRate - base;
    final h = span <= 0 ? 92.0 : ((point.rate - base) / span) * 92;
    final d = point.deltaPoints;

    return Column(children: [
      Text('${point.rate.toStringAsFixed(2)} %',
          maxLines: 1,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w900, color: kNavy)),
      const SizedBox(height: 5),
      Container(
        height: h.clamp(6, 92),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ),
      const SizedBox(height: 6),
      Text(point.yearLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: kTextMuted)),
      Text('${point.admitted} / ${point.present}',
          maxLines: 1,
          style: TextStyle(fontSize: 10, color: kTextMuted)),
      if (d != null)
        Text('${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)} pt',
            maxLines: 1,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: d >= 0 ? kGreen : kRed))
      else
        // Première session : rien à comparer. Un « +0,00 » y ferait croire à
        // une stagnation mesurée.
        Text('référence', style: TextStyle(fontSize: 10.5, color: kTextMuted)),
    ]);
  }
}

// ─── Classement départemental ───────────────────────────────────────────────
class _Standings extends StatelessWidget {
  const _Standings({required this.rows});
  final List<DepartmentStanding> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(children: [
              _h('#', 5),
              _h('DÉPARTEMENT', 34),
              _h('ADMIS / PRÉSENTS', 25, end: true),
              _h('TAUX', 18, end: true),
              _h('ÉVOL.', 18, end: true),
            ]),
          ),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                _c('${r.rank}', 5,
                    bold: r.rank <= 3,
                    color: r.rank <= 3 ? const Color(0xFFD4AF37) : null),
                _c(r.department, 34, bold: true),
                _c(
                    r.present == null
                        ? '—'
                        : '${r.admitted} / ${r.present}',
                    25,
                    end: true,
                    muted: true),
                _c('${r.rate.toStringAsFixed(2)} %', 18,
                    end: true, bold: true, color: kNavy),
                _c(
                    r.deltaPoints == null
                        ? '—'
                        : '${r.deltaPoints! >= 0 ? '+' : ''}'
                            '${r.deltaPoints!.toStringAsFixed(2)}',
                    18,
                    end: true,
                    bold: true,
                    color: r.deltaPoints == null
                        ? null
                        : (r.deltaPoints! >= 0 ? kGreen : kRed)),
              ]),
            ),
        ]),
      );

  static Widget _h(String t, int flex, {bool end = false}) => Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );

  static Widget _c(String t, int flex,
          {bool end = false,
          bool bold = false,
          bool muted = false,
          Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (muted ? kTextMuted : kTextPrimary))),
      );
}
