import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/exam_archives_provider.dart';
import 'exam_result_bits.dart';

// ─── Détail d'un département ────────────────────────────────────────────────
class DepartmentDetailDialog extends StatelessWidget {
  const DepartmentDetailDialog({
    super.key,
    required this.row,
    required this.exam,
    required this.series,
    required this.national,
  });

  final DepartmentStanding row;
  final String exam;
  final List<OfficialFigure> series;
  final ExamHistory national;

  @override
  Widget build(BuildContext context) {
    final medal = medalColor(row.rank);
    return AdminFormDialog(
      icon: Icons.emoji_events_rounded,
      accent: medal,
      title: row.department,
      subtitle: '$exam · rang ${row.rank} · '
          '${row.admitted ?? '—'} admis sur ${row.present ?? '—'} présents',
      headerTrailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${row.rate.toStringAsFixed(2)} %',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, color: kNavy)),
          if (row.deltaPoints != null)
            Text(
                '${row.deltaPoints! >= 0 ? '+' : ''}'
                '${row.deltaPoints!.toStringAsFixed(2)} pt',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: row.deltaPoints! >= 0 ? kGreen : kRed)),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Trajectoire du département'),
        const SizedBox(height: 10),
        if (series.isEmpty)
          Text(
            'Une seule session connue pour ce département : aucune trajectoire '
            'à tracer tant qu\'une deuxième publication n\'est pas archivée.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          )
        else
          for (var i = 0; i < series.length; i++)
            _YearRow(
              figure: series[i],
              previous: i == 0 ? null : series[i - 1],
              national: _nationalRate(series[i].yearLabel!),
            ),
      ]),
      footer: Row(children: [
        Expanded(
          child: Text(
            'Chiffres relevés sur les publications de la DEC.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        AdminPrimaryButton(
          label: 'Fermer',
          onTap: () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }

  double? _nationalRate(String year) {
    for (final p in national.points) {
      if (p.yearLabel == year) return p.rate;
    }
    return null;
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({required this.figure, this.previous, this.national});
  final OfficialFigure figure;
  final OfficialFigure? previous;
  final double? national;

  @override
  Widget build(BuildContext context) {
    final rate = figure.passRate!;
    final delta = previous?.passRate == null ? null : rate - previous!.passRate!;
    final gap = national == null ? null : rate - national!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(figure.yearLabel ?? '—',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            Text(
                '${figure.admitted ?? '—'} admis sur '
                '${figure.present ?? '—'} présents',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
            if (gap != null) ...[
              const SizedBox(height: 4),
              ExamGapPill(gap: gap),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rate.toStringAsFixed(2)} %',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: kNavy)),
          Text(
              delta == null
                  ? 'référence'
                  : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} pt',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: delta == null
                      ? kTextMuted
                      : (delta >= 0 ? kGreen : kRed))),
        ]),
      ]),
    );
  }
}
