part of 'infirmerie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE PASSAGE — élève, date/heure, symptômes, diagnostic, traitement,
//  médication, repos (h), parents notifiés, suivi requis (+ notes). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class _VisitForm extends ConsumerStatefulWidget {
  const _VisitForm({this.visit});
  final InfirmaryVisit? visit;
  @override
  ConsumerState<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends ConsumerState<_VisitForm> {
  String? _studentId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _symptoms = TextEditingController();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  final _medication = TextEditingController();
  final _rest = TextEditingController();
  final _follow = TextEditingController();
  bool _parentNotified = false;
  bool _followUpRequired = false;
  bool _saving = false;

  bool get _isEdit => widget.visit != null;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    if (v != null) {
      _studentId = v.studentId;
      _date = DateTime.tryParse(v.date) ?? DateTime.now();
      if (v.time != null && v.time!.length >= 5) {
        final parts = v.time!.split(':');
        _time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0);
      }
      _symptoms.text = v.symptoms ?? '';
      _diagnosis.text = v.diagnosis ?? '';
      _treatment.text = v.treatment ?? '';
      _medication.text = v.medication ?? '';
      _rest.text = v.restHours?.toString() ?? '';
      _follow.text = v.followUpNotes ?? '';
      _parentNotified = v.parentNotified;
      _followUpRequired = v.followUpRequired;
    }
  }

  @override
  void dispose() {
    _symptoms.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    _medication.dispose();
    _rest.dispose();
    _follow.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Choisissez un élève'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
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
      () => saveVisit(
        id: widget.visit?.id,
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        studentId: _studentId!,
        date: _date.toIso8601String().substring(0, 10),
        time: _timeStr(_time),
        symptoms: _symptoms.text.trim().isEmpty ? null : _symptoms.text.trim(),
        diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
        treatment: _treatment.text.trim().isEmpty ? null : _treatment.text.trim(),
        medication: _medication.text.trim().isEmpty ? null : _medication.text.trim(),
        restHours: int.tryParse(_rest.text.trim()),
        parentNotified: _parentNotified,
        followUpRequired: _followUpRequired,
        followUpNotes: _follow.text.trim().isEmpty ? null : _follow.text.trim(),
        staffId: p.id,
      ),
      success: _isEdit ? 'Passage modifié' : 'Passage enregistré',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(vsStudentsProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context,
              _isEdit ? 'Modifier le passage' : 'Nouveau passage',
              Icons.local_hospital_rounded),
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
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(_date.year - 1),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: adminFilledInput('Date',
                            icon: Icons.calendar_today_rounded),
                        child: Text(_fmt(_date),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: _time);
                        if (t != null) setState(() => _time = t);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: adminFilledInput('Heure',
                            icon: Icons.schedule_rounded),
                        child: Text(_timeStr(_time),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _symptoms,
                  maxLines: 2,
                  decoration: adminFilledInput('Symptômes / motif',
                      icon: Icons.sick_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _diagnosis,
                  decoration: adminFilledInput('Diagnostic',
                      icon: Icons.monitor_heart_rounded),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _treatment,
                  maxLines: 2,
                  decoration: adminFilledInput('Traitement / soins prodigués',
                      icon: Icons.healing_rounded),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _medication,
                      decoration: adminFilledInput('Médication',
                          icon: Icons.medication_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rest,
                      keyboardType: TextInputType.number,
                      decoration: adminFilledInput('Repos (h)',
                          icon: Icons.bed_rounded),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _follow,
                  maxLines: 2,
                  decoration: adminFilledInput('Notes de suivi (facultatif)',
                      icon: Icons.event_note_rounded),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _parentNotified,
                  activeThumbColor: kGreen,
                  onChanged: (v) => setState(() => _parentNotified = v),
                  title: const Text('Parents notifiés',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _followUpRequired,
                  activeThumbColor: const Color(0xFFF59E0B),
                  onChanged: (v) => setState(() => _followUpRequired = v),
                  title: const Text('Suivi requis',
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
}
