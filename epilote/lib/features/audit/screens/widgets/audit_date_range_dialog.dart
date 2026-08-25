import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';

/// Calendrier de période compact (deux mois côte à côte + raccourcis).
class AuditDateRangeDialog extends StatefulWidget {
  const AuditDateRangeDialog({super.key, this.initialFrom, this.initialTo});
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<AuditDateRangeDialog> createState() => _AuditDateRangeDialogState();
}

class _AuditDateRangeDialogState extends State<AuditDateRangeDialog> {
  late DateTime? _from;
  late DateTime? _to;

  static final _first = DateTime(DateTime.now().year - 5);

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  void _applyQuick(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _from = today.subtract(Duration(days: days - 1));
      _to = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canApply = _from != null && _to != null;
    final conflict = canApply && _from!.isAfter(_to!);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 740),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1A2F5A), kNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: kNavy.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(Icons.date_range_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sélectionner une période',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(height: 2),
                      Text('Cliquez sur une date de début, puis une date de fin',
                          style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: kTextMuted),
                    ),
                  ),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border(
                    top: BorderSide(color: kBorder),
                    bottom: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                Text('Raccourcis :',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ...[
                  (1, "Aujourd'hui"),
                  (7, '7 jours'),
                  (30, '30 jours'),
                  (90, '3 mois'),
                  (365, '1 an'),
                ].map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _applyQuick(p.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kBorder),
                          ),
                          child: Text(p.$2,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kNavy)),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CalendarPanel(
                      label: 'Date de début',
                      labelColor: kGreen,
                      selected: _from,
                      firstDate: _first,
                      lastDate: _to ?? today,
                      onChanged: (d) => setState(() => _from = d),
                    ),
                  ),
                  Container(width: 1, color: kBorder),
                  Expanded(
                    child: _CalendarPanel(
                      label: 'Date de fin',
                      labelColor: kRed,
                      selected: _to,
                      firstDate: _from ?? _first,
                      lastDate: today,
                      onChanged: (d) => setState(() => _to = d),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(children: [
                Expanded(
                  child: canApply
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: conflict
                                ? kRed.withValues(alpha: 0.07)
                                : kNavy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: conflict
                                  ? kRed.withValues(alpha: 0.3)
                                  : kNavy.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              conflict
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 14,
                              color: conflict ? kRed : kGreen,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                conflict
                                    ? 'La fin doit être après le début'
                                    : '${_fmt(_from!)}  →  ${_fmt(_to!)}'
                                        '  ·  ${_to!.difference(_from!).inDays + 1} j',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: conflict ? kRed : kNavy,
                                ),
                              ),
                            ),
                          ]),
                        )
                      : Text('Sélectionnez les deux dates',
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
                ),
                const SizedBox(width: 12),
                if (_from != null || _to != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                    child: Text('Effacer', style: TextStyle(color: kTextMuted)),
                  ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Annuler', style: TextStyle(color: kTextMuted)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canApply && !conflict
                      ? () => Navigator.of(context)
                          .pop(DateTimeRange(start: _from!, end: _to!))
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Appliquer'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.label,
    required this.labelColor,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });
  final String label;
  final Color labelColor;
  final DateTime? selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final safeLast = lastDate.isBefore(firstDate) ? firstDate : lastDate;
    final safeInit = selected != null &&
            !selected!.isBefore(firstDate) &&
            !selected!.isAfter(safeLast)
        ? selected!
        : (today.isBefore(firstDate)
            ? firstDate
            : (today.isAfter(safeLast) ? safeLast : today));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: labelColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: labelColor)),
            if (selected != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_p(selected!.day)}/${_p(selected!.month)}/${selected!.year}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor),
                ),
              ),
            ],
          ]),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
                primary: labelColor, onPrimary: Colors.white),
          ),
          child: CalendarDatePicker(
            key: ValueKey('${firstDate}_$safeLast'),
            initialDate: safeInit,
            firstDate: firstDate,
            lastDate: safeLast,
            onDateChanged: onChanged,
          ),
        ),
      ],
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
