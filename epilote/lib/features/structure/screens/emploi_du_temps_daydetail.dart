part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DÉTAIL D'UN JOUR (vue Mois) — gestion des EXCEPTIONS à la trame pour une date
//  précise : annuler une séance prévue (prof absent…), la rétablir, ou ajouter
//  une séance EXCEPTIONNELLE (rattrapage, devoir surveillé). 100% offline.
//  Ouvert au clic sur une case-jour ouvrée du mini-calendrier.
// ════════════════════════════════════════════════════════════════════════════
extension _EdtDayDetail on _EdtPageState {
  void _openDayDetail(DateTime date, List<TimetableSlot> shown) {
    // Séances de la trame ce jour-là (créneaux dont le jour de semaine colle).
    final daySlots = [
      for (final s in shown)
        if (s.dayOfWeek == date.weekday) s
    ]..sort((a, b) => a.hhmmStart.compareTo(b.hhmmStart));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayExceptionsSheet(
        date: date,
        daySlots: daySlots,
        classId: _view == TtView.classe ? _scope.classId : null,
        className: _view == TtView.classe ? _scope.label : null,
      ),
    );
  }
}

class _DayExceptionsSheet extends ConsumerWidget {
  const _DayExceptionsSheet({
    required this.date,
    required this.daySlots,
    required this.classId,
    required this.className,
  });
  final DateTime date;
  final List<TimetableSlot> daySlots;
  final String? classId, className;

  bool _sameDate(DateTime a) =>
      a.year == date.year && a.month == date.month && a.day == date.day;

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, TimetableSlot s) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    await runModuleWrite(
      context,
      () => createException(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        slotId: s.id,
        date: date,
        kind: 'cancelled',
        createdBy: p?.id,
      ),
      success: 'Séance annulée ce jour',
    );
  }

  Future<void> _restore(BuildContext context, String exId) =>
      runModuleWrite(context, () => deleteException(exId),
          success: 'Séance rétablie');

  void _addExtra(BuildContext context) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ExtraSessionForm(date: date, classId: classId!),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(timetableExceptionsProvider).valueOrNull ?? const [];
    final exForDate = [for (final e in all) if (_sameDate(e.date)) e];
    final cancelledBySlot = {
      for (final e in exForDate)
        if (e.isCancelled && e.slotId != null) e.slotId!: e
    };
    final extras = [for (final e in exForDate) if (e.isExtra) e];
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final dateLabel = '${frDays[date.weekday]} ${date.day} '
        '${_frMonthsFull[date.month].toLowerCase()} ${date.year}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(children: [
              Icon(Icons.event_note_rounded, size: 19, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      if (className != null)
                        Text(className!,
                            style:
                                TextStyle(fontSize: 12, color: kTextMuted)),
                    ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _DaySectionLabel('Séances prévues (trame)'),
                if (daySlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Aucune séance prévue ce jour.',
                        style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                  )
                else
                  for (final s in daySlots)
                    _ScheduledRow(
                      slot: s,
                      cancelled: cancelledBySlot[s.id],
                      canCancel: canCreate,
                      canRestore: canDelete,
                      onCancel: () => _cancel(context, ref, s),
                      onRestore: (id) => _restore(context, id),
                    ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _DaySectionLabel('Séances exceptionnelles'),
                  for (final e in extras)
                    _ExtraRow(
                      exc: e,
                      canDelete: canDelete,
                      onDelete: () => _restore(context, e.id),
                    ),
                ],
                if (classId != null && canCreate) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _addExtra(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14B8A6),
                        side: const BorderSide(color: Color(0xFF14B8A6)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter une séance exceptionnelle'),
                  ),
                ] else if (classId == null) ...[
                  const SizedBox(height: 12),
                  Text(
                      'Choisissez une classe (vue « Classe ») pour ajouter une '
                      'séance exceptionnelle.',
                      style: TextStyle(
                          fontSize: 11.5, color: kTextMuted.withValues(alpha: 0.9))),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _DaySectionLabel extends StatelessWidget {
  const _DaySectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({
    required this.slot,
    required this.cancelled,
    required this.canCancel,
    required this.canRestore,
    required this.onCancel,
    required this.onRestore,
  });
  final TimetableSlot slot;
  final TimetableException? cancelled;
  final bool canCancel, canRestore;
  final VoidCallback onCancel;
  final ValueChanged<String> onRestore;

  @override
  Widget build(BuildContext context) {
    final isCancelled = cancelled != null;
    final color = _subjectColor(slot.subjectId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: isCancelled ? kRed.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isCancelled ? kRed.withValues(alpha: 0.3) : kBorder),
      ),
      child: Row(children: [
        Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
                color: isCancelled ? kRed : color,
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.subjectName ?? 'Matière',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCancelled ? kRed : kTextPrimary)),
                Text(
                    '${slot.timeLabel}'
                    '${(slot.teacherName ?? '').isNotEmpty ? ' · ${slot.teacherName}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
        ),
        if (isCancelled)
          canRestore
              ? TextButton(
                  onPressed: () => onRestore(cancelled!.id),
                  child: const Text('Rétablir'))
              : Text('Annulée',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kRed))
        else if (canCancel)
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Annuler'),
          ),
      ]),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow(
      {required this.exc, required this.canDelete, required this.onDelete});
  final TimetableException exc;
  final bool canDelete;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: teal.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.add_circle_outline_rounded, size: 18, color: teal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exc.subjectName ?? 'Séance exceptionnelle',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                Text(
                    [
                      exc.newTimeLabel,
                      if ((exc.staffName ?? '').isNotEmpty) exc.staffName,
                      if ((exc.roomName ?? '').isNotEmpty) exc.roomName,
                    ].where((e) => (e ?? '').isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
        ),
        if (canDelete)
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.close_rounded, size: 16, color: kTextMuted),
            ),
          ),
      ]),
    );
  }
}
