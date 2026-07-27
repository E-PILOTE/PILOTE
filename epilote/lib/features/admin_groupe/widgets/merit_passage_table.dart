import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/passage_merit_provider.dart';
import 'merit_podium.dart' show MeritPodium;

// ════════════════════════════════════════════════════════════════════════════
//  TABLEAU DES MEILLEURS ÉLÈVES DES CLASSES DE PASSAGE.
//
//  La colonne « Moy. classe » n'est pas décorative : elle est ce qui distingue
//  un excellent élève d'un élève d'une classe indulgente. Une commission qui
//  lit 16/20 sans savoir que la classe est à 15 se trompe de candidat.
// ════════════════════════════════════════════════════════════════════════════
const _kFlex = <int>[6, 22, 22, 13, 9, 10, 10, 13];

class MeritPassageTable extends StatelessWidget {
  const MeritPassageTable({
    super.key,
    required this.rows,
    required this.onTap,
  });

  final List<RankedPassage> rows;
  final ValueChanged<RankedPassage> onTap;

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          const _HeaderRow(),
          for (var i = 0; i < rows.length; i++)
            _Row(
              row: rows[i],
              striped: i.isOdd,
              onTap: () => onTap(rows[i]),
            ),
        ]),
      );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  static const _labels = [
    'RANG',
    'ÉLÈVE',
    'ÉTABLISSEMENT',
    'CLASSE',
    'NIV.',
    'MOY.',
    'MOY. CL.',
    'MENTION',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Row(children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              flex: _kFlex[i],
              child: Padding(
                padding:
                    EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 10),
                child: Text(
                  _labels[i],
                  textAlign: i >= 5 ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: kTextMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6),
                ),
              ),
            ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.striped, required this.onTap});

  final RankedPassage row;
  final bool striped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final isPodium = row.rank <= 3;
    final medal = MeritPodium.medalColor(row.rank);
    // Au-dessus de sa classe = vert. C'est l'information que la commission
    // cherche : l'élève se détache-t-il de son propre groupe ?
    final above = (e.delta ?? 0) > 0;

    Widget cell(int i, String text,
            {Color? color, FontWeight? weight, double size = 12.5}) =>
        Expanded(
          flex: _kFlex[i],
          child: Padding(
            padding: EdgeInsets.only(right: i == _kFlex.length - 1 ? 0 : 10),
            child: Text(
              text,
              textAlign: i >= 5 ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? kTextMuted,
                  fontSize: size,
                  fontWeight: weight ?? FontWeight.w500),
            ),
          ),
        );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: striped ? kCardBg.withValues(alpha: 0.4) : Colors.transparent,
          border:
              Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Expanded(
            flex: _kFlex[0],
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPodium
                      ? medal.withValues(alpha: 0.18)
                      : kBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('${row.rank}',
                    style: TextStyle(
                        color: isPodium ? medal : kTextMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Expanded(
            flex: _kFlex[1],
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(children: [
                Flexible(
                  child: Text(e.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                if (row.exAequo) ...[
                  const SizedBox(width: 6),
                  _Tag('ex æquo', kTextMuted),
                ],
              ]),
            ),
          ),
          cell(2, e.schoolName, color: kTextPrimary, weight: FontWeight.w600),
          cell(3, e.className),
          cell(4, e.levelCode ?? '—'),
          cell(5, e.average.toStringAsFixed(2),
              color: above ? kGreen : kTextPrimary,
              weight: FontWeight.w800,
              size: 13),
          cell(6, e.classAverage?.toStringAsFixed(2) ?? '—'),
          cell(7, e.mention, color: kNavy, weight: FontWeight.w700, size: 12),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );
}
