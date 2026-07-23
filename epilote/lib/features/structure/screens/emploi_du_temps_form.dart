part of 'emploi_du_temps_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE CRÉNEAU — jour(s), horaires (trame standard + libre), matière
//  (LIMITÉE au programme de la classe), enseignant (pré-rempli depuis
//  l'affectation), salle. Détection de conflits EN DIRECT : prof/classe =
//  blocage, salle = avertissement. À la création : multi-jours (un créneau
//  posé d'un coup sur plusieurs jours, jours en conflit ignorés). Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class _SlotForm extends ConsumerStatefulWidget {
  const _SlotForm({
    required this.classId,
    this.slot,
    this.presetDay,
    this.presetStart,
    this.presetEnd,
  });
  final String classId;
  final TimetableSlot? slot;
  final int? presetDay;
  final String? presetStart, presetEnd;
  @override
  ConsumerState<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends ConsumerState<_SlotForm> {
  int _day = 1; // édition : jour unique
  final Set<int> _days = {}; // création : jours multiples
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 0);
  String? _subjectId, _staffId;
  String? _roomId; // salle référencée (registre) — null = aucune
  String? _legacyRoom; // ancien texte libre conservé si pas dans le registre
  bool _saving = false;
  bool _teacherTouched = false; // l'utilisateur a-t-il choisi le prof à la main ?

  bool get _isEdit => widget.slot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.slot;
    if (s != null) {
      _day = s.dayOfWeek;
      _start = _parse(s.hhmmStart);
      _end = _parse(s.hhmmEnd);
      _subjectId = s.subjectId;
      _staffId = s.staffId;
      _teacherTouched = true;
      _roomId = s.roomId;
      if (s.roomId == null && (s.room ?? '').trim().isNotEmpty) {
        _legacyRoom = s.room!.trim(); // créneau legacy : on garde son libellé
      }
    } else {
      _days.add(widget.presetDay ?? 1);
      if (widget.presetStart != null) _start = _parse(widget.presetStart!);
      if (widget.presetEnd != null) _end = _parse(widget.presetEnd!);
    }
  }

  TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(
        hour: int.tryParse(p.first) ?? 8,
        minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_min(_end) <= _min(picked)) {
          _end = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        }
      } else {
        _end = picked;
      }
    });
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  // Matière choisie dans le programme → pré-remplir l'enseignant affecté.
  void _onSubject(String? v, List<ClassSubjectOption> program) {
    setState(() {
      _subjectId = v;
      if (!_teacherTouched && v != null) {
        for (final o in program) {
          if (o.subjectId == v && (o.teacherId ?? '').isNotEmpty) {
            _staffId = o.teacherId;
            break;
          }
        }
      }
    });
  }

  Future<void> _save(Set<int> creatableDays) async {
    if (_subjectId == null) return _snack('Choisissez une matière', kAccent);
    if (_staffId == null) return _snack('Choisissez un enseignant', kAccent);
    if (_min(_end) <= _min(_start)) {
      return _snack('L\'heure de fin doit suivre l\'heure de début', kAccent);
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    // Garde-fou anti-perte silencieuse (création seulement) : un id d'identité
    // ou d'année vide ferait rejeter tout le lot PowerSync sans message.
    if (!_isEdit) {
      final missing = missingWriteIds(
          groupId: profile?.groupId,
          schoolId: profile?.schoolId,
          actorId: profile?.id);
      if (missing.isNotEmpty) return _snack(writeIdentityMessage(missing), kRed);
      if (!isUsableId(yearId)) {
        return _snack('Aucune année scolaire active.', kRed);
      }
    }
    final gid = profile?.groupId, sid = profile?.schoolId, aid = yearId;
    final actor = profile?.id;
    final rooms = ref.read(roomsProvider).valueOrNull ?? const <Room>[];
    final roomName = _roomId != null
        ? rooms.where((r) => r.id == _roomId).map((r) => r.name).firstOrNull
        : _legacyRoom;
    setState(() => _saving = true);

    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateTimetableSlot(
            id: widget.slot!.id,
            subjectId: _subjectId!,
            staffId: _staffId!,
            dayOfWeek: _day,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
            room: roomName,
            roomId: _roomId,
          );
        } else {
          // Garantit une version active (brouillon créé si nécessaire).
          final versionId = await ensureActiveVersionId(
            groupId: gid!,
            schoolId: sid!,
            academicYearId: aid!,
            createdBy: actor,
          );
          for (final d in creatableDays) {
            await createTimetableSlot(
              groupId: gid,
              schoolId: sid,
              academicYearId: aid,
              classId: widget.classId,
              subjectId: _subjectId!,
              staffId: _staffId!,
              dayOfWeek: d,
              startTime: _fmt(_start),
              endTime: _fmt(_end),
              room: roomName,
              roomId: _roomId,
              versionId: versionId,
            );
          }
        }
      },
      success: _successMsg(creatableDays),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  String _successMsg(Set<int> creatable) {
    if (_isEdit) return 'Créneau modifié';
    final skipped = _days.length - creatable.length;
    final base = creatable.length > 1
        ? 'Créneau ajouté à ${creatable.length} jours'
        : 'Créneau ajouté';
    return skipped > 0 ? '$base · $skipped ignoré(s) (conflit)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final program =
        ref.watch(classProgramProvider(widget.classId)).valueOrNull ?? const [];
    final staff = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    final all = ref.watch(timetableSlotsProvider).valueOrNull ?? const [];
    final rooms = ref.watch(roomsProvider).valueOrNull ?? const <Room>[];
    final avail =
        ref.watch(teacherAvailabilityProvider).valueOrNull ?? const [];

    // Effectif de la classe (contrôle capacité salle).
    final klass = ref
        .watch(classesProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.classId)
        .firstOrNull;
    final effectif = klass?.studentCount ?? 0;
    final selRoom = rooms.where((r) => r.id == _roomId).firstOrNull;
    final selCap = selRoom?.capacity;
    final overCapacity = selCap != null && effectif > 0 && effectif > selCap;

    // Options matière = programme de la classe (+ la matière courante en édition
    // si elle est hors programme, pour ne pas la perdre).
    final options = [...program];
    if (_isEdit &&
        _subjectId != null &&
        !options.any((o) => o.subjectId == _subjectId)) {
      options.insert(
          0,
          ClassSubjectOption(
              subjectId: _subjectId!,
              subjectName:
                  '${widget.slot!.subjectName ?? 'Matière'} (hors programme)'));
    }

    // Conflits + disponibilités par jour candidat.
    final candDays = _isEdit ? {_day} : _days;
    final hard = <SlotConflict>[];
    final roomC = <SlotConflict>[];
    final blockedDays = <int>{};
    var availHard = false; // prof indisponible (DUR)
    var availSoft = false; // prof « à éviter » (SOUPLE)
    final valid = _subjectId != null && _min(_end) > _min(_start);
    if (valid) {
      for (final d in candDays) {
        final c = conflictsForCandidate(
          all: all,
          classId: widget.classId,
          day: d,
          start: _fmt(_start),
          end: _fmt(_end),
          staffId: _staffId ?? '',
          room: selRoom?.name ?? _legacyRoom,
          roomId: _roomId,
          excludeId: widget.slot?.id,
        );
        final h = c.where((x) => x.kind != ConflictKind.room).toList();
        if (h.isNotEmpty) blockedDays.add(d);
        hard.addAll(h);
        roomC.addAll(c.where((x) => x.kind == ConflictKind.room));
        // Disponibilité enseignant.
        final v = availabilityViolation(
          avail: avail,
          staffId: _staffId ?? '',
          day: d,
          start: _fmt(_start),
          end: _fmt(_end),
        );
        if (v == 'unavailable') {
          blockedDays.add(d);
          availHard = true;
        } else if (v == 'preference_against') {
          availSoft = true;
        }
      }
    }
    final creatableDays = candDays.difference(blockedDays);
    // Rien à enregistrer ? → bouton désactivé.
    final nothingToSave = candDays.isEmpty || creatableDays.isEmpty;
    final allBlocked = valid && candDays.isNotEmpty && creatableDays.isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Icon(_isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  size: 18, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_isEdit ? 'Modifier le créneau' : 'Nouveau créneau',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                if (klass != null) ...[
                  ClassContextBanner(
                    className: klass.name,
                    cycleName: scopeCycleName(klass.cycleCode),
                    levelName: klass.levelName ?? klass.levelCode,
                    subtitle: 'Emploi du temps de la classe',
                  ),
                  const SizedBox(height: 16),
                ],
                _Lbl(_isEdit ? 'Jour' : 'Jours'),
                if (_isEdit)
                  DropdownButtonFormField<int>(
                    initialValue: _day,
                    isExpanded: true,
                    decoration:
                        adminFilledInput('Jour', icon: Icons.today_rounded),
                    items: [
                      for (var d = 1; d <= 6; d++)
                        DropdownMenuItem(value: d, child: Text(frDays[d])),
                    ],
                    onChanged: (v) => setState(() => _day = v ?? 1),
                  )
                else
                  _DayChips(
                    selected: _days,
                    blocked: blockedDays,
                    onToggle: (d) => setState(() =>
                        _days.contains(d) ? _days.remove(d) : _days.add(d)),
                  ),
                const SizedBox(height: 14),
                const _Lbl('Séance standard'),
                _PeriodChips(
                  start: _fmt(_start),
                  end: _fmt(_end),
                  onPick: (s, e) => setState(() {
                    _start = _parse(s);
                    _end = _parse(e);
                  }),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _TimeField(
                          'Début', _fmt(_start), () => _pickTime(true))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _TimeField(
                          'Fin', _fmt(_end), () => _pickTime(false))),
                ]),
                const SizedBox(height: 14),
                const _Lbl('Matière'),
                if (options.isEmpty)
                  const _InfoNote(
                    'Aucune matière au programme de cette classe. Affectez des '
                    'matières (page Matières) avant de bâtir l\'emploi du temps.',
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _subjectId,
                    isExpanded: true,
                    decoration: adminFilledInput('Choisir une matière',
                        icon: Icons.menu_book_rounded),
                    items: [
                      for (final o in options)
                        DropdownMenuItem(
                            value: o.subjectId,
                            child: Text(o.subjectName,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => _onSubject(v, options),
                  ),
                const SizedBox(height: 14),
                const _Lbl('Enseignant'),
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  isExpanded: true,
                  decoration: adminFilledInput('Choisir un enseignant',
                      icon: Icons.person_outline_rounded),
                  items: [
                    for (final t in staff)
                      DropdownMenuItem(
                          value: t.id,
                          child: Text(t.fullName,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() {
                    _staffId = v;
                    _teacherTouched = true;
                  }),
                ),
                const SizedBox(height: 14),
                const _Lbl('Salle (facultatif)'),
                if (rooms.isEmpty)
                  const _InfoNote(
                    'Aucune salle déclarée. Ajoutez vos salles dans Paramètres ▸ '
                    'Salles pour fiabiliser les conflits et le contrôle de capacité.',
                  )
                else
                  DropdownButtonFormField<String?>(
                    initialValue: _roomId,
                    isExpanded: true,
                    decoration: adminFilledInput('Choisir une salle',
                        icon: Icons.place_outlined),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Aucune salle')),
                      for (final r in rooms)
                        DropdownMenuItem(
                          value: r.id,
                          child: Text(
                              '${r.name}${r.capacity != null ? ' · ${r.capacity} pl.' : ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _roomId = v),
                  ),
                if (_roomId == null && _legacyRoom != null) ...[
                  const SizedBox(height: 8),
                  _InfoNote('Ancienne salle : « $_legacyRoom » (texte libre). '
                      'Choisissez une salle du registre pour la fiabiliser.'),
                ],
                if (overCapacity) ...[
                  const SizedBox(height: 8),
                  _CapacityNote(effectif: effectif, capacity: selCap),
                ],
                if (hard.isNotEmpty || roomC.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _FormConflict(hard: hard, roomC: roomC, allBlocked: allBlocked),
                ],
                if (availHard || availSoft) ...[
                  const SizedBox(height: 10),
                  _AvailNote(hard: availHard, soft: availSoft),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: allBlocked ? kRed : kNavy),
                  onPressed: _saving || (valid && nothingToSave)
                      ? null
                      : () => _save(creatableDays),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(allBlocked
                          ? 'Conflit'
                          : _isEdit
                              ? 'Enregistrer'
                              : creatableDays.length > 1
                                  ? 'Ajouter (${creatableDays.length})'
                                  : 'Ajouter'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
