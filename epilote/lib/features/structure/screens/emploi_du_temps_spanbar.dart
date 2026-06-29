part of 'emploi_du_temps_screen.dart';

// ─── Empan temporel : Jour/Semaine/Mois/Trimestre/Semestre/Année ─────────────
//  Jour/Semaine = grille de trame ; Mois→Année = projection calendaire. Une
//  seconde ligne contextuelle affiche le sélecteur adapté (jour, mois ◀▶,
//  trimestre, semestre).
class _SpanBar extends StatelessWidget {
  const _SpanBar({
    required this.span,
    required this.focusedDay,
    required this.monthLabel,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.trimesterLabels,
    required this.trimesterIndex,
    required this.semester,
    required this.onSpan,
    required this.onDay,
    required this.onTrimester,
    required this.onSemester,
  });
  final TtSpan span;
  final int focusedDay;
  final String monthLabel;
  final VoidCallback onPrevMonth, onNextMonth;
  final List<String> trimesterLabels;
  final int trimesterIndex, semester;
  final ValueChanged<TtSpan> onSpan;
  final ValueChanged<int> onDay, onTrimester, onSemester;

  static const _days = [1, 2, 3, 4, 5, 6];
  static const _items = <(TtSpan, IconData, String)>[
    (TtSpan.jour, Icons.today_rounded, 'Jour'),
    (TtSpan.semaine, Icons.calendar_view_week_rounded, 'Semaine'),
    (TtSpan.mois, Icons.calendar_view_month_rounded, 'Mois'),
    (TtSpan.trimestre, Icons.view_timeline_outlined, 'Trim.'),
    (TtSpan.semestre, Icons.balance_rounded, 'Sem.'),
    (TtSpan.annuel, Icons.event_note_rounded, 'Année'),
  ];

  @override
  Widget build(BuildContext context) {
    final sub = _subRow();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Segment d'empan (6 choix).
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            for (final (s, icon, label) in _items)
              Expanded(
                child: InkWell(
                  onTap: () => onSpan(s),
                  borderRadius: BorderRadius.circular(7),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: span == s ? kNavy : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 15,
                              color: span == s ? Colors.white : kTextMuted),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: span == s
                                        ? Colors.white
                                        : kTextMuted)),
                          ),
                        ]),
                  ),
                ),
              ),
          ]),
        ),
        if (sub != null) ...[const SizedBox(height: 10), sub],
      ]),
    );
  }

  Widget? _subRow() {
    switch (span) {
      case TtSpan.jour:
        final today = DateTime.now().weekday;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final d in _days) ...[
              _DayChip(
                label: frDaysShort[d],
                selected: d == focusedDay,
                isToday: d == today,
                onTap: () => onDay(d),
              ),
              if (d != _days.last) const SizedBox(width: 6),
            ],
          ]),
        );
      case TtSpan.mois:
        return Row(children: [
          _StepBtn(icon: Icons.chevron_left_rounded, onTap: onPrevMonth),
          Expanded(
            child: Center(
              child: Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
          ),
          _StepBtn(icon: Icons.chevron_right_rounded, onTap: onNextMonth),
        ]);
      case TtSpan.trimestre:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < trimesterLabels.length; i++) ...[
              _DayChip(
                label: trimesterLabels[i],
                selected: i == trimesterIndex,
                isToday: false,
                onTap: () => onTrimester(i),
              ),
              if (i != trimesterLabels.length - 1) const SizedBox(width: 6),
            ],
          ]),
        );
      case TtSpan.semestre:
        return Row(children: [
          for (final s in const [1, 2]) ...[
            _DayChip(
              label: s == 1 ? '1ᵉʳ semestre' : '2ᵉ semestre',
              selected: s == semester,
              isToday: false,
              onTap: () => onSemester(s),
            ),
            if (s == 1) const SizedBox(width: 6),
          ],
        ]);
      case TtSpan.semaine:
      case TtSpan.annuel:
        return null;
    }
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Icon(icon, size: 20, color: kNavy),
        ),
      );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });
  final String label;
  final bool selected, isToday;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kNavy : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? kNavy
                  : isToday
                      ? kNavy.withValues(alpha: 0.4)
                      : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kTextPrimary)),
          if (isToday) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: selected ? Colors.white : kNavy,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
