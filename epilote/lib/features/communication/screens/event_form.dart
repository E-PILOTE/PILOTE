part of 'events_screen.dart';

// ─── Dialogue de création / édition d'événement ───────────────────────────────
class _EventFormDialog extends ConsumerStatefulWidget {
  const _EventFormDialog({required this.groups, required this.onSaved, this.event});
  final List<EventGroupOption> groups;
  final EventModel? event;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends ConsumerState<_EventFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  String?   _groupId;
  DateTime? _eventDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _audience = 'all';
  bool   _published = false;
  bool   _saving = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl    = TextEditingController(text: e?.title ?? '');
    _descCtrl     = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _groupId   = e?.groupId ?? (widget.groups.length == 1 ? widget.groups.first.id : null);
    _eventDate = e?.date;
    _endDate   = e?.endDate != null ? DateTime.tryParse(e!.endDate!) : null;
    _startTime = _parseTime(e?.startTime);
    _endTime   = _parseTime(e?.endTime);
    _audience  = e?.targetAudience ?? 'all';
    _published = e?.isPublished ?? false;
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null) return null;
    final p = t.split(':');
    if (p.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockGroup = widget.groups.length == 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.event_rounded, color: _kNavy, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_isEdit ? "Modifier l'événement" : 'Nouvel événement',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: _kSub),
              ]),
              const SizedBox(height: 18),

              if (!lockGroup) ...[
                _label('Groupe scolaire'),
                DropdownButtonFormField<String>(
                  initialValue: _groupId,
                  isExpanded: true,
                  hint: const Text('Sélectionner…', style: TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => _groupId = v),
                  items: widget.groups
                      .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  decoration: _deco(),
                ),
                const SizedBox(height: 12),
              ],

              _label('Titre'),
              TextField(controller: _titleCtrl, style: const TextStyle(fontSize: 13), decoration: _deco(hint: 'Ex. Réunion parents-professeurs')),
              const SizedBox(height: 12),

              _label('Description'),
              TextField(controller: _descCtrl, maxLines: 3, style: const TextStyle(fontSize: 13), decoration: _deco(hint: 'Détails de l\'événement…')),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _DateField(label: 'Date', value: _eventDate, onPick: (d) => setState(() => _eventDate = d))),
                const SizedBox(width: 12),
                Expanded(child: _DateField(label: 'Date de fin (option.)', value: _endDate, onPick: (d) => setState(() => _endDate = d))),
              ]),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _TimeField(label: 'Heure début', value: _startTime, onPick: (t) => setState(() => _startTime = t))),
                const SizedBox(width: 12),
                Expanded(child: _TimeField(label: 'Heure fin', value: _endTime, onPick: (t) => setState(() => _endTime = t))),
              ]),
              const SizedBox(height: 12),

              _label('Lieu'),
              TextField(controller: _locationCtrl, style: const TextStyle(fontSize: 13), decoration: _deco(hint: 'Ex. Salle polyvalente')),
              const SizedBox(height: 12),

              _label('Public concerné'),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
                items: _audienceLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                    .toList(),
                decoration: _deco(),
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _published,
                activeThumbColor: _kGreen,
                onChanged: (v) => setState(() => _published = v),
                title: const Text('Publier immédiatement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                subtitle: const Text('Visible par le public concerné', style: TextStyle(fontSize: 11, color: _kSub)),
              ),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_isEdit ? 'Enregistrer' : 'Créer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
      );

  InputDecoration _deco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: _kSub),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
        filled: true,
        fillColor: _kBg,
      );

  String _fmtT(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_groupId == null) {
      _snack('Sélectionnez un groupe');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Le titre est requis');
      return;
    }
    if (_eventDate == null) {
      _snack('La date est requise');
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id ?? '';
      await saveEvent(
        client: client,
        createdBy: uid,
        id: widget.event?.id,
        groupId: _groupId!,
        schoolId: widget.event?.schoolId,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        eventDate: DateFormat('yyyy-MM-dd').format(_eventDate!),
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        startTime: _startTime != null ? _fmtT(_startTime!) : null,
        endTime: _endTime != null ? _fmtT(_endTime!) : null,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        targetAudience: _audience,
        isPublished: _published,
      );
      if (mounted) {
        Navigator.pop(context);
        _snack(_isEdit ? 'Événement mis à jour' : 'Événement créé', ok: true);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: ok ? _kGreen : _kRed));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
          ),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) onPick(d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: _kSub),
                const SizedBox(width: 8),
                Text(value != null ? DateFormat('dd/MM/yyyy').format(value!) : '—',
                    style: TextStyle(fontSize: 12, color: value != null ? _kText : _kSub)),
              ]),
            ),
          ),
        ],
      );
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onPick});
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
          ),
          InkWell(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
              if (t != null) onPick(t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: _kSub),
                const SizedBox(width: 8),
                Text(value != null ? value!.format(context) : '—',
                    style: TextStyle(fontSize: 12, color: value != null ? _kText : _kSub)),
              ]),
            ),
          ),
        ],
      );
}
