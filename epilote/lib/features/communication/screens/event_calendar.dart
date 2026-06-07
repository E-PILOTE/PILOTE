part of 'events_screen.dart';

// ─── Vue calendrier (grille mensuelle + détail du jour) ───────────────────────
class _EventCalendar extends StatefulWidget {
  const _EventCalendar({required this.events, required this.showGroup, required this.onEdit});
  final List<EventModel> events;
  final bool showGroup;
  final void Function(EventModel) onEdit;

  @override
  State<_EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<_EventCalendar> {
  late DateTime _month;   // 1er du mois affiché
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  // Événements indexés par jour (yyyy-mm-dd)
  Map<String, List<EventModel>> get _byDay {
    final map = <String, List<EventModel>>{};
    for (final e in widget.events) {
      final d = e.date;
      if (d == null) continue;
      final key = '${d.year}-${d.month}-${d.day}';
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    final selectedEvents = _selected != null ? (byDay[_key(_selected!)] ?? const []) : const [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Grille mensuelle ────────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthHeader(
                  month: _month,
                  onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  onToday: () {
                    final now = DateTime.now();
                    setState(() {
                      _month = DateTime(now.year, now.month);
                      _selected = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                const SizedBox(height: 10),
                const _WeekdayHeader(),
                const SizedBox(height: 4),
                Expanded(child: _MonthGrid(
                  month: _month,
                  byDay: byDay,
                  selected: _selected,
                  onPick: (d) => setState(() => _selected = d),
                )),
              ],
            ),
          ),
        ),
        Container(width: 1, color: _kBorder),
        // ── Détail du jour sélectionné ──────────────────────────────────────
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selected != null
                      ? _fmtFull.format(_selected!)[0].toUpperCase() +
                          _fmtFull.format(_selected!).substring(1)
                      : 'Aucun jour sélectionné',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText),
                ),
                const SizedBox(height: 4),
                Text('${selectedEvents.length} événement${selectedEvents.length > 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11, color: _kSub)),
                const SizedBox(height: 12),
                Expanded(
                  child: selectedEvents.isEmpty
                      ? const Center(
                          child: Text('Aucun événement ce jour',
                              style: TextStyle(fontSize: 12, color: _kSub)))
                      : ListView(
                          children: selectedEvents
                              .map((e) => _EventCard(
                                    event: e,
                                    showGroup: widget.showGroup,
                                    onEdit: () => widget.onEdit(e),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(month);
    return Row(children: [
      Text(label[0].toUpperCase() + label.substring(1),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kNavy)),
      const SizedBox(width: 8),
      IconButton(
        onPressed: onPrev,
        icon: const Icon(Icons.chevron_left_rounded, size: 22, color: _kSub),
        visualDensity: VisualDensity.compact,
      ),
      IconButton(
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded, size: 22, color: _kSub),
        visualDensity: VisualDensity.compact,
      ),
      const Spacer(),
      OutlinedButton(
        onPressed: onToday,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kNavy,
          side: const BorderSide(color: _kBorder),
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
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _kSub)),
                  ),
                ))
            .toList(),
      );
}

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
      ...List.generate(daysInMonth, (i) => DateTime(month.year, month.month, i + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.05,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final d = cells[i];
        if (d == null) return const SizedBox.shrink();
        final key = '${d.year}-${d.month}-${d.day}';
        final dayEvents = byDay[key] ?? const [];
        final isSel = selected != null &&
            selected!.year == d.year && selected!.month == d.month && selected!.day == d.day;
        final isToday = d == today;

        return GestureDetector(
          onTap: () => onPick(d),
          child: Container(
            decoration: BoxDecoration(
              color: isSel ? _kNavy.withValues(alpha: 0.10) : _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel ? _kNavy : (isToday ? _kGreen : _kBorder),
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
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday ? _kGreen : _kText,
                    )),
                const Spacer(),
                if (dayEvents.isNotEmpty)
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    children: dayEvents.take(3).map((e) {
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: e.isPublished ? _kGreen : _kAmber,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                if (dayEvents.length > 3)
                  Text('+${dayEvents.length - 3}',
                      style: const TextStyle(fontSize: 8, color: _kSub)),
              ],
            ),
          ),
        );
      },
    );
  }
}
