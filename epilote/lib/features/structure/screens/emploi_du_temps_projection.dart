part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PROJECTION CALENDAIRE — vues Mois / Trimestre / Semestre / Année.
//  Un EDT scolaire est une TRAME hebdomadaire récurrente ; ces vues la projettent
//  sur le CALENDRIER RÉEL d'une période [from, to] en EXCLUANT les jours non
//  ouvrés (`school_holidays` : fériés + vacances) et les dimanches. On en tire :
//   • un calendrier (mini-mois, jours ouvrés vs fériés/vacances, séances/jour) ;
//   • le VOLUME RÉEL de la période (jours ouvrés, séances et heures projetées) —
//     la vraie mesure « annuelle/trimestrielle » que la seule trame hebdo ne
//     donne pas ;
//   • (vue Classe) le volume horaire projeté PAR MATIÈRE sur la période.
// ════════════════════════════════════════════════════════════════════════════

const _frMonthsFull = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
  'Septembre', 'Octobre', 'Novembre', 'Décembre'
];
const _frWeekdayLetters = ['', 'L', 'M', 'M', 'J', 'V', 'S']; // Lun→Sam

DateTime _ymdOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Borne temporelle d'un empan calendaire, calculée à partir de l'année active,
/// des trimestres et de la position courante (mois/trimestre/semestre choisis).
({DateTime from, DateTime to, String label}) edtSpanRange({
  required TtSpan span,
  required AcademicYearModel? year,
  required List<TrimesterModel> trims,
  required DateTime focusedMonth,
  required int trimesterIndex,
  required int semester,
}) {
  final yStart = _ymdOnly(year?.startDate ?? DateTime(focusedMonth.year, 1, 1));
  final yEnd = _ymdOnly(year?.endDate ?? DateTime(focusedMonth.year, 12, 31));
  switch (span) {
    case TtSpan.mois:
      final from = DateTime(focusedMonth.year, focusedMonth.month, 1);
      final to = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
      return (from: from, to: to, label: '${_frMonthsFull[from.month]} ${from.year}');
    case TtSpan.trimestre:
      if (trims.isNotEmpty) {
        final i = trimesterIndex.clamp(0, trims.length - 1);
        final t = trims[i];
        return (from: _ymdOnly(t.startDate), to: _ymdOnly(t.endDate), label: t.label);
      }
      // Repli : tiers de l'année si aucun trimestre déclaré.
      final span3 = yEnd.difference(yStart).inDays ~/ 3;
      final i = trimesterIndex.clamp(0, 2);
      final from = yStart.add(Duration(days: span3 * i));
      final to = i == 2 ? yEnd : yStart.add(Duration(days: span3 * (i + 1) - 1));
      return (from: from, to: to, label: '${i + 1}ᵉ trimestre');
    case TtSpan.semestre:
      final midDays = yEnd.difference(yStart).inDays ~/ 2;
      final mid = yStart.add(Duration(days: midDays));
      return semester == 1
          ? (from: yStart, to: mid, label: '1ᵉʳ semestre')
          : (from: mid.add(const Duration(days: 1)), to: yEnd, label: '2ᵉ semestre');
    case TtSpan.annuel:
      return (from: yStart, to: yEnd, label: year?.label ?? 'Année');
    default:
      return (from: yStart, to: yEnd, label: '');
  }
}

class _CalendarProjection extends StatelessWidget {
  const _CalendarProjection({
    required this.view,
    required this.entityTitle,
    required this.classId,
    required this.slots,
    required this.holidays,
    required this.exceptions,
    required this.from,
    required this.to,
    required this.periodLabel,
    required this.dense,
    required this.onTapDay,
  });
  final TtView view;
  final String? entityTitle; // null en vue Établissement
  final String? classId; // classe sélectionnée (vue Classe) — cadre les 'extra'
  final List<TimetableSlot> slots;
  final List<SchoolHoliday> holidays;
  final List<TimetableException> exceptions;
  final DateTime from, to;
  final String periodLabel;
  final bool dense; // mini-mois compacts (trimestre/semestre/année) vs grand mois
  final void Function(DateTime date)? onTapDay; // jour cliquable (mois)

  @override
  Widget build(BuildContext context) {
    // 1) Trame hebdo agrégée : séances + minutes par jour de semaine (1..6).
    final countByWeekday = List<int>.filled(7, 0);
    final minutesByWeekday = List<int>.filled(7, 0);
    final subjMinByWeekday = <String, List<int>>{}; // subjectName → [7]
    final slotById = {for (final s in slots) s.id: s};
    for (final s in slots) {
      final d = s.dayOfWeek;
      if (d < 1 || d > 6) continue;
      countByWeekday[d] += 1;
      minutesByWeekday[d] += s.durationMinutes;
      final name = (s.subjectName ?? 'Matière').trim();
      (subjMinByWeekday[name] ??= List<int>.filled(7, 0))[d] += s.durationMinutes;
    }
    final excByDate = exceptionsByDate(exceptions);
    final shownIds = slotById.keys.toSet();
    int extraMin(TimetableException e) {
      int m(String? t) {
        if (t == null || t.length < 5) return 0;
        return (int.tryParse(t.substring(0, 2)) ?? 0) * 60 +
            (int.tryParse(t.substring(3, 5)) ?? 0);
      }
      final d = m(e.newEndTime) - m(e.newStartTime);
      return d > 0 ? d : 0;
    }

    // 2) Balayage des dates → jours ouvrés + séances/heures EFFECTIVES (trame ±
    //    exceptions du jour) ; on mémorise par date pour le mini-calendrier.
    final workingByWeekday = List<int>.filled(7, 0);
    var feriesDays = 0, vacancesDays = 0;
    var workingDays = 0, sessions = 0, minutes = 0, cancels = 0, extras = 0;
    final effByDate = <String, int>{}; // séances effectives par date ouvrée
    final excDates = <String>{}; // dates avec au moins une exception
    final a = _ymdOnly(from), b = _ymdOnly(to);
    for (var d = a; !d.isAfter(b); d = d.add(const Duration(days: 1))) {
      if (d.weekday == 7) continue; // dimanche = non travaillé
      final h = holidayOn(d, holidays);
      if (h != null) {
        h.isFerie ? feriesDays++ : vacancesDays++;
        continue;
      }
      workingByWeekday[d.weekday] += 1;
      workingDays++;
      var dSess = countByWeekday[d.weekday];
      var dMin = minutesByWeekday[d.weekday];
      final key = _ymd(d);
      for (final e in excByDate[key] ?? const <TimetableException>[]) {
        if (e.isCancelled && shownIds.contains(e.slotId)) {
          dSess -= 1;
          dMin -= slotById[e.slotId]?.durationMinutes ?? 0;
          cancels++;
          excDates.add(key);
        } else if (e.isExtra &&
            (view == TtView.ensemble || e.newClassId == classId)) {
          dSess += 1;
          dMin += extraMin(e);
          extras++;
          excDates.add(key);
        } else if (e.isMoved && shownIds.contains(e.slotId)) {
          excDates.add(key); // relocalisée : neutre sur le total
        }
      }
      sessions += dSess < 0 ? 0 : dSess;
      minutes += dMin < 0 ? 0 : dMin;
      effByDate[key] = dSess < 0 ? 0 : dSess;
    }

    // 3) Volume projeté par matière (vue Classe).
    final subjectHours = <(String, double)>[
      for (final e in subjMinByWeekday.entries)
        (
          e.key,
          [for (var d = 1; d <= 6; d++) e.value[d] * workingByWeekday[d]]
                  .fold<int>(0, (s, x) => s + x) /
              60.0,
        ),
    ]..sort((x, y) => y.$2.compareTo(x.$2));

    // 4) Mois couverts par la période.
    final months = <DateTime>[];
    var cur = DateTime(a.year, a.month);
    final lastMonth = DateTime(b.year, b.month);
    while (!cur.isAfter(lastMonth)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (entityTitle != null) ...[
        Text(entityTitle!,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 14),
      ],
      _ProjectionSummary(
        periodLabel: periodLabel,
        workingDays: workingDays,
        feries: feriesDays,
        vacances: vacancesDays,
        sessions: sessions,
        hours: minutes / 60.0,
        cancels: cancels,
        extras: extras,
      ),
      const SizedBox(height: 16),
      if (slots.isEmpty)
        const AdminEmptyState(
          icon: Icons.event_busy_outlined,
          title: 'Rien à projeter',
          message:
              'Aucun créneau dans cette sélection. La projection se base sur la '
              'trame hebdomadaire.',
        )
      else
        LayoutBuilder(builder: (ctx, c) {
          final monthW = dense ? 250.0 : 360.0;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final m in months)
                SizedBox(
                  width: months.length == 1 ? c.maxWidth : monthW,
                  child: _MiniMonth(
                    month: m,
                    from: a,
                    to: b,
                    effByDate: effByDate,
                    excDates: excDates,
                    holidays: holidays,
                    dense: dense,
                    onTapDay: onTapDay,
                  ),
                ),
            ],
          );
        }),
      if (view == TtView.classe && subjectHours.isNotEmpty) ...[
        const SizedBox(height: 18),
        _SubjectVolumeTable(subjectHours: subjectHours, label: periodLabel),
      ],
    ]);
  }
}

// ─── Bandeau de synthèse de la période ───────────────────────────────────────
class _ProjectionSummary extends StatelessWidget {
  const _ProjectionSummary({
    required this.periodLabel,
    required this.workingDays,
    required this.feries,
    required this.vacances,
    required this.sessions,
    required this.hours,
    required this.cancels,
    required this.extras,
  });
  final String periodLabel;
  final int workingDays, feries, vacances, sessions, cancels, extras;
  final double hours;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color)>[
      (Icons.event_available_rounded, '$workingDays', 'Jours ouvrés', kNavy),
      (Icons.menu_book_rounded, '$sessions', 'Séances projetées',
          const Color(0xFF0EA5E9)),
      (Icons.timer_outlined, '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} h',
          'Heures projetées', kGreen),
      if (cancels > 0)
        (Icons.event_busy_rounded, '$cancels', 'Séances annulées', kRed),
      if (extras > 0)
        (Icons.add_circle_outline_rounded, '$extras', 'Séances en plus',
            const Color(0xFF14B8A6)),
      (Icons.flag_outlined, '$feries', 'Fériés', const Color(0xFF8B5CF6)),
      (Icons.beach_access_outlined, '$vacances', 'Jours de vacances',
          const Color(0xFFF59E0B)),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Text('Projection · $periodLabel',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: kTextPrimary)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (ic, v, l, c) in items)
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(ic, size: 17, color: c),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: c)),
                          Text(l,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10.5, color: kTextMuted)),
                        ]),
                  ),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

// ─── Volume horaire projeté par matière (vue Classe) ─────────────────────────
class _SubjectVolumeTable extends StatelessWidget {
  const _SubjectVolumeTable({required this.subjectHours, required this.label});
  final List<(String, double)> subjectHours;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxH = subjectHours.first.$2 <= 0 ? 1.0 : subjectHours.first.$2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.stacked_bar_chart_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Volume horaire projeté par matière · $label',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary)),
          ),
        ]),
        const SizedBox(height: 12),
        for (final (name, h) in subjectHours)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              SizedBox(
                width: 130,
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (h / maxH).clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: kSurface,
                    valueColor:
                        AlwaysStoppedAnimation(_subjectColor(name)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${h.toStringAsFixed(h % 1 == 0 ? 0 : 1)} h',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: kNavy)),
            ]),
          ),
      ]),
    );
  }
}
