part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CRÉER / MODIFIER UNE CLASSE
// ════════════════════════════════════════════════════════════════════════════

class _ClassFormModal extends ConsumerStatefulWidget {
  const _ClassFormModal(
      {required this.cycle, required this.level, this.existing});
  final StructCycle cycle;
  final StructLevel level;
  final StructClass? existing;
  @override
  ConsumerState<_ClassFormModal> createState() => _ClassFormModalState();
}

class _ClassFormModalState extends ConsumerState<_ClassFormModal> {
  late final _name = TextEditingController(
      text: widget.existing?.name ?? '${widget.level.code} A');
  late final _capacity = TextEditingController(
      text: widget.existing?.capacity != null
          ? '${widget.existing!.capacity}'
          : '');
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  String? _filiereCode;
  String? _filiereLabel;
  String? _teacherId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _filiereLabel = widget.existing?.filiereLabel;
    _teacherId = widget.existing?.teacherId;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la classe est obligatoire.', kRed);
      return;
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    // Garde-fou anti-perte silencieuse : à la création, refuser franchement si
    // le compte n'est pas rattaché ou sans année active — sinon Postgres rejette
    // la ligne et abandonne tout le lot PowerSync sans message.
    if (!_isEdit) {
      final missing = missingWriteIds(
        groupId: profile?.groupId,
        schoolId: profile?.schoolId,
        actorId: profile?.id,
      );
      if (missing.isNotEmpty) {
        _snack(writeIdentityMessage(missing), kRed);
        setState(() => _saving = false);
        return;
      }
      if (!isUsableId(yearId)) {
        _snack('Aucune année scolaire active : impossible de créer une classe.',
            kRed);
        setState(() => _saving = false);
        return;
      }
    }
    try {
      if (_isEdit) {
        await updateClassInfo(
          classId: widget.existing!.id,
          name: name,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim(),
          mainTeacherId: _teacherId,
          clearTeacher: _teacherId == null,
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      } else {
        await createStructuredClass(
          schoolId: profile!.schoolId!,
          groupId: profile.groupId!,
          academicYearId: yearId!,
          name: name,
          levelId: widget.level.id,
          cycleCode: widget.cycle.code,
          levelCode: widget.level.code,
          levelOrder: widget.level.order,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim().isEmpty ? null : _room.text.trim(),
          mainTeacherId: _teacherId,
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        _snack(_isEdit ? 'Classe modifiée.' : 'Classe créée.', kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(messageErreur(e), kRed);
      }
    }
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver la classe ?'),
        content: Text(
            'La classe « ${widget.existing!.name} » sera archivée (masquée). '
            'Les inscriptions existantes sont conservées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await archiveClass(widget.existing!.id);
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Classe archivée.', kTextMuted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(messageErreur(e), kRed);
      }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final filieresAsync = widget.cycle.hasPrograms
        ? ref.watch(cycleFilieresProvider(widget.cycle.code))
        : null;
    final teachers =
        ref.watch(schoolTeachersProvider).valueOrNull ?? const <SchoolTeacher>[];
    return InscriptionModalFrame(
      width: 560,
      maxHeight: 680,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InscriptionHeader(
          icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
          title: _isEdit ? 'Modifier la classe' : 'Nouvelle classe',
          subtitle: '${widget.cycle.name} · Niveau ${widget.level.name}',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filieresAsync != null)
                  filieresAsync.maybeWhen(
                    data: (fils) => fils.isEmpty
                        ? const SizedBox.shrink()
                        : FormDropdown<String>(
                            label: 'Filière / série',
                            value:
                                _filiereCode ?? _codeForLabel(fils, _filiereLabel),
                            items: {for (final f in fils) f.code: f.name},
                            onChanged: (v) => setState(() {
                              _filiereCode = v;
                              _filiereLabel =
                                  v == null ? null : fils.firstWhere((f) => f.code == v).name;
                            }),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                FormTextField(
                    controller: _name,
                    label: 'Nom de la classe *',
                    icon: Icons.class_outlined),
                Row(children: [
                  Expanded(
                    child: FormTextField(
                        controller: _capacity,
                        label: 'Capacité',
                        keyboardType: TextInputType.number,
                        icon: Icons.event_seat_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormTextField(
                        controller: _room,
                        label: 'Salle',
                        icon: Icons.meeting_room_outlined),
                  ),
                ]),
                FormDropdown<String>(
                  label: 'Professeur principal',
                  value: _teacherId ?? '',
                  items: {
                    '': 'Non assigné',
                    for (final t in teachers) t.id: t.fullName,
                  },
                  onChanged: (v) =>
                      setState(() => _teacherId = (v == null || v.isEmpty) ? null : v),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _archive,
                      icon: const Icon(Icons.archive_outlined, size: 17),
                      label: const Text('Archiver la classe'),
                      style: TextButton.styleFrom(foregroundColor: kRed),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AdminDialogFooter(
          saving: _saving,
          submitLabel: _isEdit ? 'Enregistrer' : 'Créer la classe',
          submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
          submitColor: _isEdit ? kNavy : kGreen,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: _save,
        ),
      ]),
    );
  }

  String? _codeForLabel(List<StructFiliere> fils, String? label) {
    if (label == null) return null;
    for (final f in fils) {
      if (f.name == label) return f.code;
    }
    return null;
  }
}
