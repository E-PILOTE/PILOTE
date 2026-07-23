part of 'edt_settings_screen.dart';

// ─── Formulaire créneau de trame ─────────────────────────────────────────────
class _PeriodForm extends ConsumerStatefulWidget {
  const _PeriodForm({this.period, this.nextIndex = 0, this.cycleCode});
  final SchoolPeriod? period;
  final int nextIndex;
  final String? cycleCode; // cycle auquel rattacher un nouveau créneau
  @override
  ConsumerState<_PeriodForm> createState() => _PeriodFormState();
}

class _PeriodFormState extends ConsumerState<_PeriodForm> {
  late final TextEditingController _label;
  String _kind = 'cours';
  String _start = '08:00';
  String _end = '08:55';
  bool _saving = false;

  bool get _isEdit => widget.period != null;

  @override
  void initState() {
    super.initState();
    final p = widget.period;
    _label = TextEditingController(text: p?.label ?? '');
    if (p != null) {
      _kind = p.kind;
      _start = p.hhmmStart;
      _end = p.hhmmEnd;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Le libellé est requis'), backgroundColor: kAccent));
      return;
    }
    if (_hhmmToMin(_end) <= _hhmmToMin(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('L\'heure de fin doit suivre l\'heure de début'),
          backgroundColor: kAccent));
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    if (!_isEdit) {
      final missing = missingWriteIds(
          groupId: profile?.groupId,
          schoolId: profile?.schoolId,
          actorId: profile?.id);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(writeIdentityMessage(missing)),
            backgroundColor: kRed));
        return;
      }
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateSchoolPeriod(
            id: widget.period!.id,
            label: _label.text,
            kind: _kind,
            startTime: _start,
            endTime: _end,
          );
        } else {
          await createSchoolPeriod(
            groupId: profile!.groupId!,
            schoolId: profile.schoolId!,
            cycleCode: widget.cycleCode,
            label: _label.text,
            periodIndex: widget.nextIndex,
            kind: _kind,
            startTime: _start,
            endTime: _end,
          );
        }
      },
      success: _isEdit ? 'Créneau modifié' : 'Créneau ajouté',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.schedule_rounded,
      title: _isEdit ? 'Modifier le créneau' : 'Nouveau créneau de trame',
      width: 440,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Ajouter',
      onSubmit: _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const AdminFormSectionLabel('NATURE'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _kind,
          isExpanded: true,
          decoration: adminFilledInput('Type', icon: Icons.category_outlined),
          items: [
            for (final k in kPeriodKinds)
              DropdownMenuItem(value: k.$1, child: Text(k.$2)),
          ],
          onChanged: (v) => setState(() => _kind = v ?? 'cours'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: adminFilledInput('Libellé (ex. M1, Récré, Pause)',
              icon: Icons.label_outline),
        ),
        const SizedBox(height: 16),
        const AdminFormSectionLabel('HORAIRE'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _TimeField(
              label: 'Début',
              value: _start,
              onTap: () async {
                final v = await _pickHhmm(context, _start);
                if (v != null) {
                  setState(() {
                    _start = v;
                    if (_hhmmToMin(_end) <= _hhmmToMin(v)) {
                      final m = _hhmmToMin(v) + 55;
                      _end =
                          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TimeField(
              label: 'Fin',
              value: _end,
              onTap: () async {
                final v = await _pickHhmm(context, _end);
                if (v != null) setState(() => _end = v);
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

