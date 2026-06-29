part of 'emploi_du_temps_screen.dart';

// ─── Formulaire « séance exceptionnelle » (kind = extra) ─────────────────────
class _ExtraSessionForm extends ConsumerStatefulWidget {
  const _ExtraSessionForm({required this.date, required this.classId});
  final DateTime date;
  final String classId;
  @override
  ConsumerState<_ExtraSessionForm> createState() => _ExtraSessionFormState();
}

class _ExtraSessionFormState extends ConsumerState<_ExtraSessionForm> {
  String? _subjectId;
  String? _teacherId;
  String? _roomId;
  String _start = '08:00';
  String _end = '09:00';
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final cur = (start ? _start : _end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(cur.first) ?? 8,
          minute: cur.length > 1 ? int.tryParse(cur[1]) ?? 0 : 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = v : _end = v);
  }

  int _min(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 +
        (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  Future<void> _save() async {
    if (_subjectId == null || _min(_end) <= _min(_start)) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => createException(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        date: widget.date,
        kind: 'extra',
        newSubjectId: _subjectId,
        newClassId: widget.classId,
        newStaffId: _teacherId,
        newRoomId: _roomId,
        newStartTime: _start,
        newEndTime: _end,
        reason: _reason.text,
        createdBy: p?.id,
      ),
      success: 'Séance exceptionnelle ajoutée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(classProgramProvider(widget.classId)).valueOrNull ??
        const [];
    final rooms = ref.watch(roomsProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 18, color: Color(0xFF14B8A6)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Séance exceptionnelle',
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
            child: ListView(padding: const EdgeInsets.all(18), children: [
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
                ],
                onChanged: (v) => setState(() {
                  _subjectId = v;
                  _teacherId = program
                      .firstWhere((o) => o.subjectId == v,
                          orElse: () => const ClassSubjectOption(
                              subjectId: '', subjectName: ''))
                      .teacherId;
                }),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _TimeBox(
                        label: 'Début', value: _start, onTap: () => _pick(true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _TimeBox(
                        label: 'Fin', value: _end, onTap: () => _pick(false))),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _roomId,
                isExpanded: true,
                decoration: adminFilledInput('Salle (facultatif)',
                    icon: Icons.meeting_room_outlined),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final r in rooms)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _roomId = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reason,
                decoration: adminFilledInput('Motif (facultatif)',
                    icon: Icons.notes_rounded),
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
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6)),
                  onPressed: _saving || _subjectId == null ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Ajouter'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox(
      {required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: adminFilledInput(label, icon: Icons.schedule_rounded),
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ),
      );
}
