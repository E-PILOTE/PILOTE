part of 'discipline_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE INCIDENT — élève, date, type, description, sanction (+ date),
//  parents notifiés, suivi. S'ajuste à son contenu. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class _IncidentForm extends ConsumerStatefulWidget {
  const _IncidentForm({this.incident});
  final DisciplineIncident? incident;
  @override
  ConsumerState<_IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends ConsumerState<_IncidentForm> {
  String? _studentId;
  String _type = 'indiscipline';
  String _sanction = 'avertissement';
  DateTime _date = DateTime.now();
  DateTime? _sanctionDate;
  bool _parentNotified = false;
  final _desc = TextEditingController();
  final _follow = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.incident != null;

  @override
  void initState() {
    super.initState();
    final i = widget.incident;
    if (i != null) {
      _studentId = i.studentId;
      _type = i.type;
      _sanction = (i.sanction ?? 'avertissement');
      _date = DateTime.tryParse(i.date) ?? DateTime.now();
      _sanctionDate =
          i.sanctionDate != null ? DateTime.tryParse(i.sanctionDate!) : null;
      _parentNotified = i.parentNotified;
      _desc.text = i.description ?? '';
      _follow.text = i.followUp ?? '';
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    _follow.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _key(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<DateTime?> _pick(DateTime init) => showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(init.year - 1),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx)
              .copyWith(colorScheme: ColorScheme.light(primary: kNavy)),
          child: child!,
        ),
      );

  Future<void> _save() async {
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Choisissez un élève'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    final missing = missingWriteIds(
        groupId: p?.groupId, schoolId: p?.schoolId, actorId: p?.id);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(writeIdentityMessage(missing)), backgroundColor: kRed));
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveIncident(
        id: widget.incident?.id,
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        academicYearId: yearId,
        studentId: _studentId!,
        date: _key(_date),
        type: _type,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        sanction: _sanction,
        sanctionDate:
            _sanction == 'aucune' || _sanctionDate == null ? null : _key(_sanctionDate!),
        parentNotified: _parentNotified,
        followUp: _follow.text.trim().isEmpty ? null : _follow.text.trim(),
        reportedBy: p.id,
      ),
      success: _isEdit ? 'Incident modifié' : 'Incident enregistré',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    // L'incident est écrit quoi qu'il arrive. La suite ne peut plus le défaire.
    if (sanctionMetFinALaScolarite(_sanction)) {
      await _proposerExclusion(yearId);
      if (!mounted) return;
    }
    Navigator.pop(context);
  }

  /// Une exclusion définitive met fin à la scolarité. On PROPOSE de fermer
  /// l'inscription — on ne le fait jamais tout seul : c'est un acte de
  /// l'établissement, et le chef d'établissement peut vouloir attendre le
  /// conseil de discipline, ou la notification aux parents.
  Future<void> _proposerExclusion(String yearId) async {
    final insc = await inscriptionActive(_studentId!, yearId);
    if (!mounted) return;
    if (insc == null) return; // rien d'ouvert à fermer

    final eleve = ref.read(vsStudentsProvider(_kSlug)).valueOrNull
        ?.where((s) => s.id == _studentId)
        .map((s) => s.name)
        .firstOrNull;

    final fermer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.gavel_rounded, color: kRed, size: 32),
        title: const Text('Fermer l\'inscription ?'),
        content: Text(
          'L\'exclusion définitive met fin à la scolarité de '
          '${eleve ?? 'cet élève'} dans l\'établissement '
          '(${insc.className}).\n\n'
          'Fermer son inscription avec le motif « Exclusion disciplinaire » ? '
          'Sans cela, il continuera de figurer dans l\'effectif de sa classe.\n\n'
          'Vous pouvez refuser maintenant et le faire plus tard depuis sa '
          'fiche — par exemple après le conseil de discipline. La sanction '
          'reste enregistrée dans les deux cas.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Pas maintenant')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Fermer l\'inscription'),
          ),
        ],
      ),
    );
    if (fermer != true || !mounted) return;

    await runModuleWrite(
      context,
      () => prononcerExclusion(
        enrollmentId: insc.id,
        sanctionDate: _sanctionDate == null ? null : _key(_sanctionDate!),
        motivation: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      ),
      success: 'Inscription fermée — motif : exclusion disciplinaire',
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(vsStudentsProvider(_kSlug)).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context,
              _isEdit ? 'Modifier l\'incident' : 'Nouvel incident',
              Icons.gavel_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                VsStudentField(
                  students: students,
                  selectedId: _studentId,
                  enabled: !_isEdit,
                  onSelect: (id) => setState(() => _studentId = id),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _dateField('Date', _date, () async {
                    final d = await _pick(_date);
                    if (d != null) setState(() => _date = d);
                  })),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _drop('Type', Icons.category_outlined, _type,
                        kIncidentTypes, (v) => setState(() => _type = v!)),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: adminFilledInput('Description des faits',
                      icon: Icons.notes_rounded),
                ),
                const SizedBox(height: 14),
                _drop('Sanction', Icons.balance_rounded, _sanction, kSanctions,
                    (v) => setState(() => _sanction = v!)),
                if (_sanction != 'aucune') ...[
                  const SizedBox(height: 14),
                  _dateField(
                      'Date de la sanction (facultatif)',
                      _sanctionDate ?? _date, () async {
                    final d = await _pick(_sanctionDate ?? _date);
                    if (d != null) setState(() => _sanctionDate = d);
                  }, value: _sanctionDate, optional: true),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _follow,
                  maxLines: 2,
                  decoration: adminFilledInput('Suivi / mesures (facultatif)',
                      icon: Icons.task_alt_rounded),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _parentNotified,
                  activeThumbColor: kGreen,
                  onChanged: (v) => setState(() => _parentNotified = v),
                  title: const Text('Parents notifiés',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, _isEdit),
        ]),
      ),
    );
  }

  Widget _dateField(String label, DateTime shown, VoidCallback onTap,
      {DateTime? value, bool optional = false}) {
    final display = optional && value == null ? '—' : _fmt(shown);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration:
            adminFilledInput(label, icon: Icons.calendar_today_rounded),
        child: Text(display,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _drop(String label, IconData icon, String value,
      List<(String, String)> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: adminFilledInput(label, icon: icon),
      items: [
        for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l)),
      ],
      onChanged: onChanged,
    );
  }
}
