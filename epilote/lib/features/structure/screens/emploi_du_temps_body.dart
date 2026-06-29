part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CORPS DE LA PAGE EDT (extension de l'état) : sélecteur d'entité, navigation
//  de mois, et rendu du contenu (grille de trame OU projection calendaire).
// ════════════════════════════════════════════════════════════════════════════
extension _EdtBody on _EdtPageState {
  // Décale le mois affiché (empan « Mois »), borné à l'année active.
  void _stepMonth(int delta, AcademicYearModel? year) {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    if (year != null) {
      final lo = DateTime(year.startDate.year, year.startDate.month);
      final hi = DateTime(year.endDate.year, year.endDate.month);
      if (next.isBefore(lo) || next.isAfter(hi)) return;
    }
    mutate(() => _focusedMonth = next);
  }

  // ── Sélecteur (couverture cycle/niveau/classe OU picker enseignant/salle) ───
  Widget _selector(
      List<ClassModel> sorted, List<TimetableSlot> all, Set<String> conformeIds) {
    switch (_view) {
      case TtView.ensemble:
      case TtView.classe:
        return ScopeDrilldownPanel(
          title: _view == TtView.classe
              ? 'Choisir la classe'
              : 'Conformité des emplois du temps',
          metricLabel: 'Programme OK',
          unitNoun: 'classes',
          selected: _scope,
          onSelect: _onScope,
          units: [
            for (final c in sorted)
              ScopeUnit(
                cycleCode: c.cycleCode,
                levelCode: c.levelCode,
                levelOrder: c.levelOrder ?? 999,
                classId: c.id,
                className: c.name,
                ok: conformeIds.contains(c.id),
              ),
          ],
        );
      case TtView.enseignant:
        final teachers = <String, String>{};
        for (final s in all) {
          if (s.staffId.isNotEmpty) {
            teachers[s.staffId] = s.teacherName ?? 'Enseignant';
          }
        }
        final entries = teachers.entries.toList()
          ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
        if (entries.isNotEmpty && _teacherId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) mutate(() => _teacherId = entries.first.key);
          });
        }
        return _EntityPicker(
          icon: Icons.person_outline_rounded,
          label: 'Enseignant',
          hint: 'Choisir un enseignant',
          value: _teacherId,
          items: [for (final e in entries) (e.key, e.value)],
          onChanged: (v) => mutate(() => _teacherId = v),
        );
      case TtView.salle:
        final roomNames = <String>{
          for (final s in all)
            if ((s.room ?? '').trim().isNotEmpty) s.room!.trim()
        }.toList()
          ..sort();
        if (roomNames.isNotEmpty && _room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) mutate(() => _room = roomNames.first);
          });
        }
        return _EntityPicker(
          icon: Icons.meeting_room_outlined,
          label: 'Salle',
          hint: 'Choisir une salle',
          value: _room,
          items: [for (final r in roomNames) (r, r)],
          onChanged: (v) => mutate(() => _room = v),
        );
    }
  }

  // ── Corps : calendrier maître (établissement) OU grille d'entité ───────────
  Widget _content(
    List<TimetableSlot> all,
    List<TimetableSlot> shown,
    String? title,
    Set<String> conflictIds,
    List<SchoolPeriod> periods,
    Map<String, ClassModel> classById,
    Map<String, int> requiredByClass,
    List<SchoolHoliday> holidays,
    List<TimetableException> exceptions,
    ({DateTime from, DateTime to, String label}) range,
    bool canAdd,
    bool canEditSlot,
    bool canDelSlot,
  ) {
    // Empan calendaire (mois/trimestre/semestre/année) = projection de la trame
    // sur le calendrier réel, quelle que soit la vue (établissement ou entité).
    if (_span.isCalendar) {
      return _CalendarProjection(
        view: _view,
        entityTitle: _view == TtView.ensemble ? null : title,
        classId: _view == TtView.classe ? _scope.classId : null,
        slots: shown,
        holidays: holidays,
        exceptions: exceptions,
        from: range.from,
        to: range.to,
        periodLabel: range.label,
        dense: _span != TtSpan.mois,
        // Jour cliquable en vue Mois → gestion des exceptions de ce jour.
        onTapDay: (_span == TtSpan.mois && (canEditSlot || canAdd))
            ? (date) => _openDayDetail(date, shown)
            : null,
      );
    }

    if (_view == TtView.ensemble) {
      final trameRanges = <(String, String)>[
        for (final p in periods)
          if (p.isCourse && (_scope.cycle == null || p.cycleCode == _scope.cycle))
            (p.hhmmStart, p.hhmmEnd)
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const AdminSectionTitle('Calendrier de l\'établissement',
            icon: Icons.calendar_month_rounded,
            subtitle:
                'Tous les cours de la semaine — cliquer un cours pour le consulter'),
        const SizedBox(height: 14),
        _MasterCalendar(
          slots: shown,
          days: _visibleDays,
          trameRanges: trameRanges,
          conflictIds: conflictIds,
          colorByClass: true,
          editable: false,
          onTapSlot: (s) => _openSlotDrawer(s, false, false, all),
          onTapEmpty: (_, _, _) {},
        ),
      ]);
    }

    // Vue entité (classe / enseignant / salle).
    if (title == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AdminEmptyState(
          icon: Icons.touch_app_outlined,
          title: _view == TtView.classe
              ? 'Sélectionnez une classe'
              : _view == TtView.enseignant
                  ? 'Aucun enseignant à l\'emploi du temps'
                  : 'Aucune salle utilisée',
          message: _view == TtView.classe
              ? 'Choisissez une classe dans la couverture ci-dessus.'
              : 'Construisez d\'abord des créneaux depuis la vue « Classe ».',
        ),
      );
    }

    final klass = _view == TtView.classe ? classById[_scope.classId] : null;
    // Ossature trame (cours + récré/pause) du cycle de la classe — sert de
    // canevas à la grille (cases vides cliquables, bandes récré/pause).
    final trame = klass == null
        ? const <SchoolPeriod>[]
        : [
            for (final p in periods)
              if (p.cycleCode == null || p.cycleCode == klass.cycleCode) p
          ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
        ),
        if (_view == TtView.classe && klass != null)
          _ClassActionsMenu(
            className: klass.name,
            canEdit: canEditSlot || canAdd,
            onDuplicate: () => _duplicateTo(klass),
            onClear: canDelSlot ? () => _clearClass(klass) : null,
          ),
      ]),
      const SizedBox(height: 16),
      _Kpis(slots: shown, mode: _view),
      const SizedBox(height: 16),
      // Conformité au programme (classe uniquement).
      if (klass != null) ...[
        _ProgramCompliance(classId: klass.id, slots: shown),
        const SizedBox(height: 16),
      ],
      _ConflictBanner(slots: shown, conflictIds: conflictIds),
      if (shown.isEmpty && trame.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AdminEmptyState(
            icon: Icons.event_note_rounded,
            title: 'Emploi du temps vide',
            message: _view == TtView.classe
                ? 'Aucun créneau pour cette classe. Ajoutez les cours de la semaine.'
                : 'Aucun créneau pour cette sélection.',
            actionLabel: canAdd ? 'Ajouter un créneau' : null,
            onAction: canAdd ? () => _openSlotForm() : null,
          ),
        )
      else
        _TimetableGrid(
          slots: shown,
          mode: _view,
          days: _visibleDays,
          trame: trame,
          conflictIds: conflictIds,
          canAdd: canAdd,
          canDelete: canDelSlot,
          canMove: canEditSlot,
          onTapSlot: (s) => _openSlotDrawer(s, canEditSlot, canDelSlot, all),
          onTapEmpty: (day, start, end) =>
              _openSlotForm(day: day, start: start, end: end),
          onDelete: _deleteSlot,
          onMove: (s, day, start, end) => _moveSlot(s, day, start, end, all),
        ),
    ]);
  }
}
