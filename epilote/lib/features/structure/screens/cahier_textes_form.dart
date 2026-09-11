part of 'cahier_textes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE SÉANCE — date, classe, matière, enseignant, titre + contenu /
//  objectifs / devoirs / ressources. Offline-first.
// ════════════════════════════════════════════════════════════════════════════
class _LessonForm extends ConsumerStatefulWidget {
  const _LessonForm({this.entry});
  final LessonEntry? entry;
  @override
  ConsumerState<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<_LessonForm> {
  late DateTime _date;
  String? _classId, _subjectId, _staffId;
  String? _pickedSlotId; // séance EDT d'origine (cosmétique, non stockée)
  bool _teacherTouched = false; // l'enseignant a-t-il été choisi manuellement ?
  late final TextEditingController _title, _content, _objectives, _homework,
      _resources;
  bool _saving = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = e?.entryDate ?? DateTime.now();
    _classId = e?.classId;
    _subjectId = e?.subjectId;
    _staffId = e?.staffId;
    _teacherTouched = e?.staffId != null;
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _objectives = TextEditingController(text: e?.objectives ?? '');
    _homework = TextEditingController(text: e?.homework ?? '');
    _resources = TextEditingController(text: e?.resources ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _content, _objectives, _homework, _resources]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _pickDate() async {
    final d = await choisirDateScolaire(context, ref, initiale: _date);
    if (d != null) setState(() => _date = d);
  }

  /// Pré-remplit la séance depuis l'emploi du temps (cohérence EDT).
  void _pickSlot(TimetableSlot s) => setState(() {
        _pickedSlotId = s.id;
        _subjectId = s.subjectId;
        if (s.staffId.isNotEmpty) {
          _staffId = s.staffId;
          _teacherTouched = true;
        }
        if (_title.text.trim().isEmpty && (s.subjectName ?? '').isNotEmpty) {
          _title.text = s.subjectName!;
        }
      });

  Future<void> _save() async {
    if (_classId == null) return _snack('Choisissez une classe', kAccent);
    if (_subjectId == null) return _snack('Choisissez une matière', kAccent);
    if (_staffId == null) return _snack('Choisissez un enseignant', kAccent);
    if (_title.text.trim().isEmpty) {
      return _snack('Le titre de la séance est obligatoire', kAccent);
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    // Garde-fou anti-perte silencieuse (création seulement) : refuser si le
    // compte n'est pas rattaché ou sans année active, sinon le lot PowerSync
    // entier est rejeté sans message.
    if (!_isEdit) {
      final missing = missingWriteIds(
          groupId: profile?.groupId,
          schoolId: profile?.schoolId,
          actorId: profile?.id);
      if (missing.isNotEmpty) {
        setState(() => _saving = false);
        return _snack(writeIdentityMessage(missing), kRed);
      }
      if (!isUsableId(yearId)) {
        setState(() => _saving = false);
        return _snack('Aucune année scolaire active.', kRed);
      }
    }
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateLessonEntry(
            id: widget.entry!.id,
            classId: _classId!,
            subjectId: _subjectId!,
            staffId: _staffId!,
            entryDate: _date,
            title: _title.text,
            content: _content.text,
            objectives: _objectives.text,
            homework: _homework.text,
            resources: _resources.text,
          );
        } else {
          await createLessonEntry(
            groupId: profile!.groupId!,
            schoolId: profile.schoolId!,
            academicYearId: yearId!,
            classId: _classId!,
            subjectId: _subjectId!,
            staffId: _staffId!,
            entryDate: _date,
            title: _title.text,
            content: _content.text,
            objectives: _objectives.text,
            homework: _homework.text,
            resources: _resources.text,
          );
        }
      },
      success: _isEdit ? 'Séance modifiée' : 'Séance enregistrée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesForModuleProvider(_kSlug)).valueOrNull ?? const [];
    // Choix libre (un prof journalise pour n'importe quelle classe) : on ORDONNE
    // par niveau et on PRÉFIXE par le niveau → la structure reste lisible.
    final sortedClasses = [...classes]
      ..sort((a, b) {
        final o = (a.levelOrder ?? 999).compareTo(b.levelOrder ?? 999);
        return o != 0 ? o : a.name.compareTo(b.name);
      });
    final classItems = {
      for (final c in sortedClasses)
        c.id: ((c.levelCode ?? '').isNotEmpty)
            ? '${c.levelCode} · ${c.name}'
            : c.name,
    };
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final staff = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    // Cohérence EDT/Matières : matière limitée au programme de la classe, prof
    // pré-rempli depuis l'affectation, séances issues de l'emploi du temps.
    final program = _classId == null
        ? const <ClassSubjectOption>[]
        : ref.watch(classProgramProvider(_classId!)).valueOrNull ?? const [];
    final useProgram = program.isNotEmpty;
    final subjectItems = useProgram
        ? {for (final o in program) o.subjectId: o.subjectName}
        : {for (final s in subjects) s.id: s.name};
    final allSlots = ref.watch(timetableSlotsProvider).valueOrNull ?? const [];
    final daySlots = _classId == null
        ? const <TimetableSlot>[]
        : (allSlots
            .where((s) => s.classId == _classId && s.dayOfWeek == _date.weekday)
            .toList()
          ..sort((a, b) => a.hhmmStart.compareTo(b.hhmmStart)));
    final dateStr =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
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
                child: Text(_isEdit ? 'Modifier la séance' : 'Nouvelle séance',
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
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Lbl('Date'),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(children: [
                                Icon(Icons.event_rounded,
                                    size: 16, color: kTextMuted),
                                const SizedBox(width: 8),
                                Text(dateStr,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary)),
                              ]),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropField('Classe', Icons.class_rounded, _classId,
                        classItems, (v) {
                      // Changer de classe réinitialise le programme dérivé.
                      setState(() {
                        _classId = v;
                        _subjectId = null;
                        _staffId = null;
                        _teacherTouched = false;
                        _pickedSlotId = null;
                      });
                    }),
                  ),
                ]),
                if (_classId != null) ...[
                  const SizedBox(height: 14),
                  _SeancePicker(
                    weekday: _date.weekday,
                    slots: daySlots,
                    pickedId: _pickedSlotId,
                    onPick: _pickSlot,
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _DropField('Matière', Icons.menu_book_rounded,
                        _subjectId, subjectItems, (v) {
                      setState(() {
                        _subjectId = v;
                        _pickedSlotId = null;
                        // Prof auto-rempli depuis l'affectation (écrasable).
                        if (!_teacherTouched && useProgram) {
                          for (final o in program) {
                            if (o.subjectId == v && o.teacherId != null) {
                              _staffId = o.teacherId;
                              break;
                            }
                          }
                        }
                      });
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropField(
                        'Enseignant',
                        Icons.person_outline_rounded,
                        _staffId,
                        {for (final t in staff) t.id: t.fullName}, (v) {
                      setState(() {
                        _staffId = v;
                        _teacherTouched = true;
                      });
                    }),
                  ),
                ]),
                if (_classId != null && !useProgram)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Aucune matière au programme de cette classe (page Matières). '
                      'Toutes les matières sont proposées.',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted),
                    ),
                  ),
                const SizedBox(height: 14),
                const _Lbl('Titre de la séance *'),
                TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Ex. Les fractions — addition'),
                ),
                const SizedBox(height: 14),
                _Multi('Contenu de la séance', _content,
                    'Ce qui a été traité en classe…'),
                _Multi('Objectifs', _objectives,
                    'Compétences visées (facultatif)'),
                _Multi('Devoirs à faire', _homework,
                    'Travail donné aux élèves (facultatif)'),
                _Multi('Ressources', _resources,
                    'Manuel, pages, liens… (facultatif)'),
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
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Enregistrer' : 'Consigner'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
