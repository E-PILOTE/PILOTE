part of 'notes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE ÉVALUATION — création / édition. À la création : classe → matière
//  (limitée au programme de la classe) → type → date → barème → coefficient →
//  trimestre. À l'édition, classe et matière sont verrouillées (des notes
//  peuvent déjà exister).
// ════════════════════════════════════════════════════════════════════════════
class _EvaluationForm extends ConsumerStatefulWidget {
  const _EvaluationForm({
    this.evaluation,
    this.presetClassId,
    this.presetTrimesterId,
  });
  final Evaluation? evaluation;
  final String? presetClassId, presetTrimesterId;
  @override
  ConsumerState<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends ConsumerState<_EvaluationForm> {
  final _title = TextEditingController();
  final _maxScore = TextEditingController(text: '20');
  final _coef = TextEditingController(text: '1');
  String? _classId;
  String? _subjectId;
  String _type = 'controle';
  String? _trimesterId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.evaluation != null;

  @override
  void initState() {
    super.initState();
    final e = widget.evaluation;
    if (e != null) {
      _title.text = e.title;
      _maxScore.text = e.maxScore.toStringAsFixed(0);
      _coef.text = '${e.coefficient}';
      _classId = e.classId;
      _subjectId = e.subjectId;
      _type = e.type;
      _trimesterId = e.trimesterId;
      _date = e.date ?? DateTime.now();
    } else {
      // Création depuis l'atelier d'une classe : pré-sélection.
      _classId = widget.presetClassId;
      _trimesterId = widget.presetTrimesterId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _maxScore.dispose();
    _coef.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: kNavy)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final max = double.tryParse(_maxScore.text.trim().replaceAll(',', '.'));
    final coef = int.tryParse(_coef.text.trim());
    if (_classId == null ||
        _subjectId == null ||
        _title.text.trim().isEmpty ||
        max == null ||
        max <= 0 ||
        coef == null ||
        coef <= 0) {
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateEvaluation(
            id: widget.evaluation!.id,
            title: _title.text,
            type: _type,
            trimesterId: _trimesterId,
            date: _date,
            maxScore: max,
            coefficient: coef,
          );
        } else {
          await createEvaluation(
            groupId: p?.groupId ?? '',
            schoolId: p?.schoolId ?? '',
            academicYearId: yearId,
            classId: _classId!,
            subjectId: _subjectId!,
            trimesterId: _trimesterId,
            title: _title.text,
            type: _type,
            date: _date,
            maxScore: max,
            coefficient: coef,
            createdBy: p?.id ?? '',
          );
        }
      },
      success: _isEdit ? 'Évaluation modifiée' : 'Évaluation créée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider).valueOrNull ?? const [];
    final sorted = [...classes]
      ..sort((a, b) => (a.levelOrder ?? 999).compareTo(b.levelOrder ?? 999));
    final program = _classId == null
        ? const <ClassSubjectOption>[]
        : ref.watch(classProgramProvider(_classId!)).valueOrNull ?? const [];
    final yearId = ref.watch(activeYearIdProvider);
    final trims = (yearId != null
            ? ref.watch(trimestersProvider(yearId)).valueOrNull
            : null) ??
        const [];
    final dateLabel = '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              const Icon(Icons.grade_rounded, size: 18, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_isEdit ? 'Modifier l\'évaluation' : 'Nouvelle évaluation',
                    style: const TextStyle(
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
            child: ListView(padding: const EdgeInsets.all(18), children: [
              DropdownButtonFormField<String>(
                initialValue: _classId,
                isExpanded: true,
                decoration:
                    adminFilledInput('Classe', icon: Icons.groups_2_rounded),
                items: [
                  for (final c in sorted)
                    DropdownMenuItem(
                        value: c.id,
                        child: Text(
                            [c.name, if ((c.filiereLabel ?? '').isNotEmpty) '· ${c.filiereLabel}'].join(' '),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _isEdit
                    ? null
                    : (v) => setState(() {
                          _classId = v;
                          _subjectId = null;
                        }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                isExpanded: true,
                decoration: adminFilledInput('Matière',
                    icon: Icons.menu_book_outlined),
                items: [
                  for (final o in program)
                    DropdownMenuItem(
                        value: o.subjectId,
                        child: Text(o.subjectName,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // En édition, garantir l'item courant même hors programme.
                  if (_isEdit &&
                      _subjectId != null &&
                      !program.any((o) => o.subjectId == _subjectId))
                    DropdownMenuItem(
                        value: _subjectId,
                        child: Text(widget.evaluation!.subjectName ?? 'Matière')),
                ],
                onChanged: _isEdit ? null : (v) => setState(() => _subjectId = v),
              ),
              if (_classId != null && program.isEmpty && !_isEdit) ...[
                const SizedBox(height: 6),
                const Text(
                    'Aucune matière au programme de cette classe (page Matières).',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFF59E0B))),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: adminFilledInput('Titre (ex. Composition n°1)',
                    icon: Icons.title_rounded),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration:
                    adminFilledInput('Type', icon: Icons.category_outlined),
                items: [
                  for (final (v, l) in kEvaluationTypes)
                    DropdownMenuItem(value: v, child: Text(l)),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'controle'),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: adminFilledInput('Date',
                          icon: Icons.calendar_today_rounded),
                      child: Text(dateLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxScore,
                    keyboardType: TextInputType.number,
                    decoration: adminFilledInput('Barème (/)',
                        icon: Icons.straighten_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _coef,
                    keyboardType: TextInputType.number,
                    decoration: adminFilledInput('Coeff',
                        icon: Icons.scale_rounded),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _trimesterId,
                isExpanded: true,
                decoration: adminFilledInput('Trimestre (facultatif)',
                    icon: Icons.date_range_rounded),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final t in trims)
                    DropdownMenuItem(value: t.id, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _trimesterId = v),
              ),
            ]),
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
                      : Text(_isEdit ? 'Enregistrer' : 'Créer'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
