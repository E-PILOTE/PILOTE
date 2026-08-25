import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/events_provider.dart';
import 'staff_feed_ui.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Calendrier mensuel STAFF (lecture seule) — variante légère de la vue
// calendrier admin (`event_calendar.dart`, part de events_screen.dart, trop
// couplée : tokens privés + _EventCard éditable). Même langage visuel :
// grille mensuelle + panneau « détail du jour ». 100 % local, aucun réseau.
// ═════════════════════════════════════════════════════════════════════════════

class StaffEventCalendar extends StatefulWidget {
  const StaffEventCalendar({
    super.key,
    required this.events,
    required this.onTapEvent,
  });
  final List<EventModel> events;
  final void Function(EventModel) onTapEvent;

  @override
  State<StaffEventCalendar> createState() => _StaffEventCalendarState();
}

class _StaffEventCalendarState extends State<StaffEventCalendar> {
  late DateTime _month; // 1er du mois affiché
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Map<String, List<EventModel>> get _byDay {
    final map = <String, List<EventModel>>{};
    for (final e in widget.events) {
      final d = e.date;
      if (d == null) continue;
      map.putIfAbsent(_key(d), () => []).add(e);
    }
    return map;
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    final selectedEvents =
        _selected != null ? (byDay[_key(_selected!)] ?? const <EventModel>[]) : const <EventModel>[];
    final wide = MediaQuery.sizeOf(context).width >= 980;

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthHeader(
          month: _month,
          onPrev: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          onToday: _goToday,
        ),
        const SizedBox(height: 10),
        const _WeekdayHeader(),
        const SizedBox(height: 4),
        _MonthGrid(
          month: _month,
          byDay: byDay,
          selected: _selected,
          onPick: (d) => setState(() => _selected = d),
        ),
      ],
    );

    final dayPanel = _DayPanel(
      selected: _selected,
      events: selectedEvents,
      onTapEvent: widget.onTapEvent,
    );

    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: grid),
              const SizedBox(width: 18),
              Container(width: 1, height: 420, color: kBorder),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: dayPanel),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              grid,
              const SizedBox(height: 16),
              Divider(color: kBorder, height: 1),
              const SizedBox(height: 16),
              dayPanel,
            ]),
    );
  }
}

// ─── En-tête de mois (‹ › + Aujourd'hui) ────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final DateTime month;
  final VoidCallback onPrev, onNext, onToday;

  @override
  Widget build(BuildContext context) {
    final mois = kMoisLongFr[month.month - 1];
    final label = '${mois[0].toUpperCase()}${mois.substring(1)} ${month.year}';
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: kNavy)),
      const SizedBox(width: 6),
      IconButton(
        onPressed: onPrev,
        icon: Icon(Icons.chevron_left_rounded, size: 22, color: kTextMuted),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        onPressed: onNext,
        icon: Icon(Icons.chevron_right_rounded, size: 22, color: kTextMuted),
        visualDensity: VisualDensity.compact,
      ),
      const Spacer(),
      OutlinedButton(
        onPressed: onToday,
        style: OutlinedButton.styleFrom(
          foregroundColor: kNavy,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text("Aujourd'hui", style: TextStyle(fontSize: 12)),
      ),
    ]);
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();
  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) => Row(
        children: _days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kTextMuted)),
                  ),
                ))
            .toList(),
      );
}

// ─── Grille mensuelle ───────────────────────────────────────────────────────
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
    required this.onPick,
  });
  final DateTime month;
  final Map<String, List<EventModel>> byDay;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7; // lundi = 0
    final cells = <DateTime?>[
      ...List.filled(leading, null),
      ...List.generate(
          daysInMonth, (i) => DateTime(month.year, month.month, i + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.15,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final d = cells[i];
        if (d == null) return const SizedBox.shrink();
        final dayEvents = byDay['${d.year}-${d.month}-${d.day}'] ?? const [];
        final isSel = selected != null &&
            selected!.year == d.year &&
            selected!.month == d.month &&
            selected!.day == d.day;
        final isToday = d == today;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onPick(d),
            child: Container(
              decoration: BoxDecoration(
                color: isSel ? kNavy.withValues(alpha: 0.10) : kCardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSel ? kNavy : (isToday ? kGreen : kBorder),
                  width: isSel || isToday ? 1.4 : 1,
                ),
              ),
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday ? kGreen : kTextPrimary,
                      )),
                  const Spacer(),
                  if (dayEvents.isNotEmpty)
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: dayEvents
                          .take(3)
                          .map((e) => Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: e.isPast ? kTextMuted : kGreen,
                                  shape: BoxShape.circle,
                                ),
                              ))
                          .toList(),
                    ),
                  if (dayEvents.length > 3)
                    Text('+${dayEvents.length - 3}',
                        style:
                            TextStyle(fontSize: 8, color: kTextMuted)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Panneau « détail du jour » ─────────────────────────────────────────────
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.selected,
    required this.events,
    required this.onTapEvent,
  });
  final DateTime? selected;
  final List<EventModel> events;
  final void Function(EventModel) onTapEvent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected != null ? fmtDateFullFr(selected) : 'Aucun jour sélectionné',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text('${events.length} événement${events.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Aucun événement ce jour',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
            )
          else
            ...events.map((e) => _DayEventTile(event: e, onTap: () => onTapEvent(e))),
        ],
      );
}

class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.event, required this.onTap});
  final EventModel event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = event.isPast ? kTextMuted : kGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (event.startTime != null)
                          '${event.startTime}${event.endTime != null ? ' – ${event.endTime}' : ''}',
                        if ((event.location ?? '').isNotEmpty) event.location!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: kTextMuted),
            ]),
          ),
        ),
      ),
    );
  }
}
