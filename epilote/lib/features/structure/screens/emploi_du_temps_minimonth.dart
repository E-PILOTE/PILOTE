part of 'emploi_du_temps_screen.dart';

// ─── Mini-calendrier d'un mois (colonnes Lun→Sam) ────────────────────────────
class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.from,
    required this.to,
    required this.effByDate,
    required this.excDates,
    required this.holidays,
    required this.dense,
    required this.onTapDay,
  });
  final DateTime month; // 1er du mois
  final DateTime from, to;
  final Map<String, int> effByDate; // séances effectives par date ouvrée
  final Set<String> excDates; // dates avec exception(s)
  final List<SchoolHoliday> holidays;
  final bool dense;
  final void Function(DateTime date)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final y = month.year, m = month.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final today = _ymdOnly(DateTime.now());

    // Construit les semaines (6 colonnes Lun→Sam, dimanche ignoré).
    final weeks = <List<DateTime?>>[];
    var row = List<DateTime?>.filled(6, null);
    for (var dd = 1; dd <= daysInMonth; dd++) {
      final date = DateTime(y, m, dd);
      final wd = date.weekday;
      if (wd == 7) {
        if (row.any((e) => e != null)) weeks.add(row);
        row = List<DateTime?>.filled(6, null);
        continue;
      }
      if (wd == 1 && row.any((e) => e != null)) {
        weeks.add(row);
        row = List<DateTime?>.filled(6, null);
      }
      row[wd - 1] = date;
    }
    if (row.any((e) => e != null)) weeks.add(row);

    final cell = dense ? 30.0 : 46.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_frMonthsFull[m]} $y',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          for (var d = 1; d <= 6; d++)
            Expanded(
              child: Center(
                child: Text(_frWeekdayLetters[d],
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        for (final w in weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              for (final date in w)
                Expanded(
                  child: _DayCell(
                    date: date,
                    inRange: date != null &&
                        !_ymdOnly(date).isBefore(from) &&
                        !_ymdOnly(date).isAfter(to),
                    holiday: date == null ? null : holidayOn(date, holidays),
                    sessions: date == null ? 0 : (effByDate[_ymd(date)] ?? 0),
                    hasException: date != null && excDates.contains(_ymd(date)),
                    isToday: date != null && _ymdOnly(date) == today,
                    size: cell,
                    dense: dense,
                    onTap: onTapDay,
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inRange,
    required this.holiday,
    required this.sessions,
    required this.hasException,
    required this.isToday,
    required this.size,
    required this.dense,
    required this.onTap,
  });
  final DateTime? date;
  final bool inRange;
  final SchoolHoliday? holiday;
  final int sessions;
  final bool hasException, isToday, dense;
  final double size;
  final void Function(DateTime date)? onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null || !inRange) {
      return SizedBox(height: size, child: const SizedBox.shrink());
    }
    final off = holiday != null;
    final offColor =
        holiday?.isFerie == true ? const Color(0xFF8B5CF6) : kRed;
    final hasCourse = !off && sessions > 0;
    // Intensité « heatmap » selon le nombre de séances.
    final bg = off
        ? offColor.withValues(alpha: 0.10)
        : hasCourse
            ? kNavy.withValues(alpha: (0.06 + sessions * 0.05).clamp(0.06, 0.30))
            : Colors.transparent;

    final inner = Stack(children: [
      Container(
        height: size,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: isToday
              ? Border.all(color: kNavy, width: 1.6)
              : off
                  ? Border.all(color: offColor.withValues(alpha: 0.25))
                  : Border.all(color: kBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${date!.day}',
                  style: TextStyle(
                      fontSize: dense ? 10.5 : 12,
                      fontWeight: FontWeight.w700,
                      color: off ? offColor : kTextPrimary)),
              if (off && !dense)
                Text(holiday!.isFerie ? 'férié' : 'congé',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8.5, color: offColor))
              else if (hasCourse)
                dense
                    ? Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                            color: kNavy, shape: BoxShape.circle))
                    : Text('$sessions séance${sessions > 1 ? 's' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
            ]),
      ),
      // Pastille « exception ce jour » (annulation/ajout/déplacement).
      if (hasException)
        Positioned(
          top: 3,
          right: 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Color(0xFFF59E0B), shape: BoxShape.circle),
          ),
        ),
    ]);

    final tappable = onTap == null || off
        ? inner
        : InkWell(
            onTap: () => onTap!(date!),
            borderRadius: BorderRadius.circular(7),
            child: inner,
          );

    if (off) {
      return Tooltip(
          message: '${holiday!.label} — ${holiday!.rangeLabel}', child: tappable);
    }
    return tappable;
  }
}
