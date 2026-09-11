part of 'subject_detail_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES TROIS GESTES D'AFFECTATION
//
//  Affecter la matière à des classes, corriger son coefficient effectif et
//  son volume horaire, désigner le professeur.
// ════════════════════════════════════════════════════════════════════════════

class _AssignClassDialog extends ConsumerStatefulWidget {
  const _AssignClassDialog({required this.subject});
  final SubjectModel subject;
  @override
  ConsumerState<_AssignClassDialog> createState() => _AssignClassDialogState();
}

class _AssignClassDialogState extends ConsumerState<_AssignClassDialog> {
  final Set<String> _picked = {};
  bool _saving = false;

  Future<void> _save() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || _picked.isEmpty) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        for (final classId in _picked) {
          await assignSubjectToClass(
            groupId: groupId,
            schoolId: schoolId,
            subjectId: widget.subject.id,
            classId: classId,
          );
        }
      },
      success: '${widget.subject.name} ajoutée à ${_picked.length} classe(s)',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assignableClassesProvider(widget.subject.id));
    final candidates = async.valueOrNull ?? const <CandidateClass>[];

    return AdminFormDialog(
      icon: Icons.add_rounded,
      title: 'Affecter « ${widget.subject.name} »',
      subtitle: 'Toutes classes · coef. hérité du défaut, ajustable ensuite',
      width: 460,
      saving: _saving,
      submitLabel: 'Affecter (${_picked.length})',
      submitIcon: Icons.check_rounded,
      onSubmit: (_saving || _picked.isEmpty) ? null : _save,
      body: candidates.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                  'Toutes les classes éligibles ont déjà cette matière, ou '
                  'aucune classe n\'existe pour ce niveau.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted)),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                child: Column(children: [
                  for (final c in candidates)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: kNavy,
                      value: _picked.contains(c.id),
                      onChanged: (v) => setState(() =>
                          v == true ? _picked.add(c.id) : _picked.remove(c.id)),
                      title: Text(c.label,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                ]),
              ),
              ),
            ),
    );
  }
}

// ─── Éditer coefficient effectif / volume horaire ────────────────────────────
class _AssignmentEditDialog extends ConsumerStatefulWidget {
  const _AssignmentEditDialog({required this.subject, required this.a});
  final SubjectModel subject;
  final SubjectAssignment a;
  @override
  ConsumerState<_AssignmentEditDialog> createState() =>
      _AssignmentEditDialogState();
}

class _AssignmentEditDialogState extends ConsumerState<_AssignmentEditDialog> {
  late bool _inherit = widget.a.coefOverride == null;
  late int _coef = widget.a.effectiveCoef;
  late final _hours = TextEditingController(
      text: widget.a.weeklyHours?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final h = int.tryParse(_hours.text.trim());
    final ok = await runModuleWrite(
      context,
      () => updateAssignment(
        id: widget.a.id,
        coefficient: _inherit ? null : _coef,
        weeklyHours: h,
        clearCoefficient: _inherit,
      ),
      success: 'Programme de ${widget.a.className} mis à jour',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.tune_rounded,
      title: widget.a.className,
      subtitle: '${widget.subject.name} · coefficient dans cette classe',
      width: 420,
      saving: _saving,
      submitLabel: 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kNavy,
          value: _inherit,
          onChanged: (v) => setState(() {
            _inherit = v;
            if (v) _coef = widget.subject.coefficient;
          }),
          title: Text('Hériter du coef. par défaut',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          subtitle: Text('Coef. par défaut = ${widget.subject.coefficient}',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        ),
        if (!_inherit) ...[
          const SizedBox(height: 8),
          Text('Coefficient de cette classe',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            _Step(
                icon: Icons.remove_rounded,
                onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
            Expanded(
              child: Center(
                child: Text('$_coef',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kNavy)),
              ),
            ),
            _Step(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Volume horaire hebdomadaire (optionnel)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _hours,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13.5),
          decoration:
              adminFilledInput('Ex. 4', icon: Icons.schedule_outlined),
        ),
      ]),
    );
  }
}

// ─── Affecter le professeur ──────────────────────────────────────────────────
class _TeacherPickerDialog extends ConsumerStatefulWidget {
  const _TeacherPickerDialog({required this.subject, required this.a});
  final SubjectModel subject;
  final SubjectAssignment a;
  @override
  ConsumerState<_TeacherPickerDialog> createState() =>
      _TeacherPickerDialogState();
}

class _TeacherPickerDialogState extends ConsumerState<_TeacherPickerDialog> {
  late String? _teacherId = widget.a.teacherId;
  bool _saving = false;

  Future<void> _save() async {
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => setAssignmentTeacher(
        groupId: groupId,
        schoolId: schoolId,
        subjectId: widget.subject.id,
        classId: widget.a.classId,
        teacherId: _teacherId,
      ),
      success: 'Professeur mis à jour',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final teachers =
        ref.watch(schoolTeachersProvider).valueOrNull ?? const <SchoolTeacher>[];
    final hasSel = _teacherId == null || teachers.any((t) => t.id == _teacherId);
    return AdminFormDialog(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Professeur',
      subtitle: '${widget.subject.name} · ${widget.a.className}',
      width: 420,
      saving: _saving,
      submitLabel: 'Enregistrer',
      submitIcon: Icons.check_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enseignant titulaire',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: hasSel ? _teacherId : null,
          isExpanded: true,
          style: TextStyle(fontSize: 13.5, color: kTextPrimary),
          icon: Icon(Icons.expand_more_rounded,
              size: 18, color: kTextMuted),
          decoration: adminFilledInput('Non affecté'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Non affecté')),
            for (final t in teachers)
              DropdownMenuItem(value: t.id, child: Text(t.fullName)),
          ],
          onChanged: (v) => setState(() => _teacherId = v),
        ),
        if (teachers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Aucun enseignant enregistré. Ajoutez le personnel depuis '
                '« Personnel ».',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Icon(icon, size: 20, color: kNavy),
          ),
        ),
      );
}
