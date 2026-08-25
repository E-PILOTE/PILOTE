part of 'conges_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE DEMANDE DE CONGÉ — agent, type, période (jours calculés), motif.
// ════════════════════════════════════════════════════════════════════════════
class _LeaveForm extends ConsumerStatefulWidget {
  const _LeaveForm({this.request});
  final LeaveRequest? request;
  @override
  ConsumerState<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends ConsumerState<_LeaveForm> {
  String? _staffId;
  String _type = 'annuel';
  DateTime? _start, _end;
  final _reason = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.request != null;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    if (r != null) {
      _staffId = r.staffId;
      _type = kLeaveTypes.any((e) => e.$1 == r.leaveType) ? r.leaveType : 'annuel';
      _start = DateTime.tryParse(r.startDate ?? '');
      _end = DateTime.tryParse(r.endDate ?? '');
      _reason.text = r.reason ?? '';
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _days =>
      (_start != null && _end != null && !_end!.isBefore(_start!))
          ? leaveDays(_start!, _end!)
          : 0;

  Future<void> _pick(bool start) async {
    final base = start ? (_start ?? DateTime.now()) : (_end ?? _start ?? DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (d != null) {
      setState(() {
        if (start) {
          _start = d;
          if (_end != null && _end!.isBefore(d)) _end = d;
        } else {
          _end = d;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_staffId == null) {
      _snack('Sélectionnez un agent');
      return;
    }
    if (_start == null || _end == null || _days == 0) {
      _snack('Période invalide (début ≤ fin)');
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final missing = missingWriteIds(
        groupId: p?.groupId, schoolId: p?.schoolId, actorId: p?.id);
    if (missing.isNotEmpty) {
      _snack(writeIdentityMessage(missing));
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveLeaveRequest(
        id: widget.request?.id,
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        staffId: _staffId!,
        leaveType: _type,
        startDate: _start!.toIso8601String().substring(0, 10),
        endDate: _end!.toIso8601String().substring(0, 10),
        daysCount: _days,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      ),
      success: _isEdit ? 'Demande modifiée' : 'Demande enregistrée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: kRed));

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier la demande' : 'Nouvelle demande',
              Icons.beach_access_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  isExpanded: true,
                  decoration: adminFilledInput('Agent',
                      icon: Icons.person_outline_rounded),
                  items: [
                    for (final a in agents)
                      DropdownMenuItem(
                          value: a.id,
                          child: Text(a.lastFirst,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _staffId = v),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: adminFilledInput('Type de congé',
                      icon: Icons.category_outlined),
                  items: [
                    for (final (slug, label) in kLeaveTypes)
                      DropdownMenuItem(value: slug, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'annuel'),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _DF('Début', _fmt(_start), () => _pick(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _DF('Fin', _fmt(_end), () => _pick(false))),
                ]),
                const SizedBox(height: 10),
                if (_days > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(children: [
                      Icon(Icons.today_rounded, size: 16, color: kNavy),
                      const SizedBox(width: 8),
                      Text('$_days jour${_days > 1 ? 's' : ''} de congé',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kNavy)),
                    ]),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: adminFilledInput('Motif (facultatif)',
                      icon: Icons.notes_rounded),
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

class _DF extends StatelessWidget {
  const _DF(this.label, this.value, this.onTap);
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              adminFilledInput(label, icon: Icons.calendar_today_rounded),
          child: Text(value,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      );
}
