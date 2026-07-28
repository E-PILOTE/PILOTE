import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_department_dialog.dart';
import 'exam_result_bits.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CLASSEMENT DÉPARTEMENTAL — feuille montante.
//
//  Quinze départements, cinq colonnes : c'est un tableau, pas un encart. Sous
//  la courbe nationale il écrasait la section et n'était lisible ni l'un ni
//  l'autre. Il s'ouvre donc en pleine largeur, à la demande, depuis l'en-tête
//  de l'historique.
//
//  Le rang seul ne dit rien : un département peut être 12ᵉ et progresser plus
//  vite que le 3ᵉ. Chaque ligne porte donc son évolution en POINTS, et s'ouvre
//  sur sa trajectoire complète.
// ════════════════════════════════════════════════════════════════════════════

void showExamStandingsModal(
  BuildContext context, {
  required ExamHistory history,
  required List<DepartmentStanding> standings,
  required List<OfficialFigure> figures,
  required String yearLabel,
}) {
  showAdminBottomModal<void>(
    context,
    builder: (_) => _StandingsSheet(
      history: history,
      standings: standings,
      figures: figures,
      yearLabel: yearLabel,
    ),
  );
}

class _StandingsSheet extends StatelessWidget {
  const _StandingsSheet({
    required this.history,
    required this.standings,
    required this.figures,
    required this.yearLabel,
  });

  final ExamHistory history;
  final List<DepartmentStanding> standings;
  final List<OfficialFigure> figures;
  final String yearLabel;

  @override
  Widget build(BuildContext context) {
    final national = history.latest?.rate;
    return AdminBottomModal(
      icon: Icons.leaderboard_rounded,
      title: 'Classement départemental · ${history.examShortName}',
      subtitle: 'Session $yearLabel — taux calculés sur les présents, '
          'évolution en points',
      headerTrailing: national == null
          ? null
          : _HeaderRate(rate: national, label: 'national'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (standings.length >= 3) ...[
          _Podium(rows: standings.take(3).toList(), national: national),
          const SizedBox(height: 18),
        ],
        _StandingsTable(
          rows: standings,
          national: national,
          onTap: (r) => _openDepartment(context, r),
        ),
        const SizedBox(height: 14),
        Text(
          'Un rang se lit avec son évolution : un département en milieu de '
          'tableau qui gagne 5 points progresse plus vite que le premier qui '
          'en perd 1. Cliquez une ligne pour voir sa trajectoire.',
          style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.5),
        ),
      ]),
    );
  }

  /// Détail d'un département : sa trajectoire propre sur le même examen.
  void _openDepartment(BuildContext context, DepartmentStanding row) {
    final series = [
      for (final f in figures)
        if (f.scope == PubScope.departement &&
            f.examShortName == history.examShortName &&
            f.department == row.department &&
            f.passRate != null &&
            f.yearLabel != null)
          f,
    ]..sort((a, b) => a.yearLabel!.compareTo(b.yearLabel!));

    showDialog<void>(
      context: context,
      builder: (_) => DepartmentDetailDialog(
          row: row,
          exam: history.examShortName,
          series: series,
          national: history),
    );
  }
}

class _HeaderRate extends StatelessWidget {
  const _HeaderRate({required this.rate, required this.label});
  final double rate;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${rate.toStringAsFixed(2)} %',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: kNavy)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: kTextMuted)),
        ],
      );
}

// ─── Podium ─────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  const _Podium({required this.rows, this.national});
  final List<DepartmentStanding> rows;
  final double? national;

  @override
  Widget build(BuildContext context) {
    // Ordre visuel du podium : 2ᵉ · 1ᵉʳ · 3ᵉ.
    final order = [
      if (rows.length > 1) rows[1],
      rows[0],
      if (rows.length > 2) rows[2],
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in order) ...[
            Expanded(child: _PodiumStep(row: r, national: national)),
            if (r != order.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({required this.row, this.national});
  final DepartmentStanding row;
  final double? national;

  @override
  Widget build(BuildContext context) {
    final c = medalColor(row.rank);
    final gap = national == null ? null : row.rate - national!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.16), c.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(9)),
            child: Text('${row.rank}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(row.department,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
        ]),
        const SizedBox(height: 12),
        Text('${row.rate.toStringAsFixed(2)} %',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: kNavy)),
        Text(
            row.present == null
                ? 'effectifs non publiés'
                : '${row.admitted} admis sur ${row.present} présents',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        if (gap != null) ...[
          const SizedBox(height: 6),
          Text(
            gap >= 0
                ? '+${gap.toStringAsFixed(2)} pt vs national'
                : '${gap.toStringAsFixed(2)} pt vs national',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: gap >= 0 ? kGreen : kRed),
          ),
        ],
      ]),
    );
  }
}

// ─── Tableau ────────────────────────────────────────────────────────────────
class _StandingsTable extends StatelessWidget {
  const _StandingsTable(
      {required this.rows, required this.onTap, this.national});
  final List<DepartmentStanding> rows;
  final ValueChanged<DepartmentStanding> onTap;
  final double? national;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: kNavy.withValues(alpha: 0.05),
            child: Row(children: [
              _h('#', 5),
              _h('DÉPARTEMENT', 30),
              _h('ADMIS / PRÉSENTS', 22, end: true),
              _h('TAUX', 15, end: true),
              _h('VS NATIONAL', 16, end: true),
              _h('ÉVOL.', 13, end: true),
              const SizedBox(width: 22),
            ]),
          ),
          for (var i = 0; i < rows.length; i++)
            _Row(
              row: rows[i],
              national: national,
              striped: i.isOdd,
              onTap: () => onTap(rows[i]),
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
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.striped,
    required this.onTap,
    this.national,
  });
  final DepartmentStanding row;
  final bool striped;
  final VoidCallback onTap;
  final double? national;

  @override
  Widget build(BuildContext context) {
    final gap = national == null ? null : row.rate - national!;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: striped ? kNavy.withValues(alpha: 0.02) : null,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: row.rank <= 3
                ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medalColor(row.rank),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('${row.rank}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  )
                : Text('${row.rank}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kTextMuted)),
          ),
          _c(row.department, 30, bold: true),
          _c(row.present == null ? '—' : '${row.admitted} / ${row.present}', 22,
              end: true, muted: true),
          _c('${row.rate.toStringAsFixed(2)} %', 15,
              end: true, bold: true, color: kNavy),
          Expanded(
            flex: 16,
            child: gap == null
                ? Text('—',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))
                : Align(
                    alignment: Alignment.centerRight,
                    child: ExamGapPill(gap: gap),
                  ),
          ),
          _c(
              row.deltaPoints == null
                  ? '—'
                  : '${row.deltaPoints! >= 0 ? '+' : ''}'
                      '${row.deltaPoints!.toStringAsFixed(2)}',
              13,
              end: true,
              bold: true,
              color: row.deltaPoints == null
                  ? null
                  : (row.deltaPoints! >= 0 ? kGreen : kRed)),
          SizedBox(
            width: 22,
            child: Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
          ),
        ]),
      ),
    );
  }

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

/// Écart au national — la seule mesure qui situe un département : 62 % ne se
