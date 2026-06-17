part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DIALOGUES — champ date, nouvelle année, passage d'année.
// ════════════════════════════════════════════════════════════════════════════

// ─── Champ date partagé ────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kNavy)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 4),
          );
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 15, color: kTextMuted),
            const SizedBox(width: 8),
            Text(value != null ? _fmt.format(value!) : 'Choisir…',
                style: TextStyle(
                    fontSize: 13, color: value != null ? kNavy : kTextMuted)),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Dialogue : nouvelle année ─────────────────────────────────────────────────
class _YearDialog extends ConsumerStatefulWidget {
  const _YearDialog();
  @override
  ConsumerState<_YearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends ConsumerState<_YearDialog> {
  final _label = TextEditingController();
  DateTime? _start, _end;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_label.text.trim().isEmpty || _start == null || _end == null) {
      setState(() => _error = 'Libellé et dates requis');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      setState(() => _error = 'La date de fin doit suivre le début');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminCalendarServiceProvider)
          .createYear(label: _label.text, start: _start!, end: _end!);
      ref.invalidate(adminAcademicYearsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.event_rounded,
      title: 'Nouvelle année scolaire',
      subtitle: 'Définissez la prochaine année du groupe',
      width: 480,
      saving: _saving,
      submitLabel: 'Créer',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel("IDENTITÉ DE L'ANNÉE"),
          const SizedBox(height: 14),
          TextField(
              controller: _label,
              decoration: adminFilledInput('Libellé (ex. 2026-2027)',
                  icon: Icons.label_outline_rounded)),
          const AdminFormDivider(),
          const AdminFormSectionLabel('PÉRIODE'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _DateField(
                    label: 'Début',
                    value: _start,
                    onPick: (d) => setState(() => _start = d))),
            const SizedBox(width: 12),
            Expanded(
                child: _DateField(
                    label: 'Fin',
                    value: _end,
                    onPick: (d) => setState(() => _end = d))),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Créée NON courante. Toutes les écoles du groupe '
                  "l'hériteront à leur prochaine synchro.",
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

// ─── Dialogue : passage d'année ────────────────────────────────────────────────
class _RolloverDialog extends ConsumerStatefulWidget {
  const _RolloverDialog({required this.years});
  final List<AdminYear> years;
  @override
  ConsumerState<_RolloverDialog> createState() => _RolloverDialogState();
}

class _RolloverDialogState extends ConsumerState<_RolloverDialog> {
  String? _sourceId;
  final _label = TextEditingController();
  DateTime? _start, _end;
  bool _copyCalendar = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AdminYear? def;
    for (final y in widget.years) {
      if (y.isCurrent) {
        def = y;
        break;
      }
    }
    def ??= widget.years.isNotEmpty ? widget.years.first : null;
    _sourceId = def?.id;
    _applyPrefill(def);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  AdminYear? get _source {
    for (final y in widget.years) {
      if (y.id == _sourceId) return y;
    }
    return null;
  }

  void _applyPrefill(AdminYear? y) {
    if (y == null) return;
    _label.text = _nextLabel(y.label);
    _start = DateTime(y.startDate.year + 1, y.startDate.month, y.startDate.day);
    _end = DateTime(y.endDate.year + 1, y.endDate.month, y.endDate.day);
  }

  String _nextLabel(String label) {
    final m = RegExp(r'(\d{4})\s*[-/]\s*(\d{4})').firstMatch(label);
    if (m != null) return '${int.parse(m[1]!) + 1}-${int.parse(m[2]!) + 1}';
    final y = RegExp(r'(\d{4})').firstMatch(label);
    if (y != null) return '${int.parse(y[1]!) + 1}';
    return '';
  }

  Future<void> _submit() async {
    final src = _source;
    if (src == null ||
        _label.text.trim().isEmpty ||
        _start == null ||
        _end == null) {
      setState(() => _error = 'Source, libellé et dates requis');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      setState(() => _error = 'La date de fin doit suivre le début');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminCalendarServiceProvider).rolloverYear(
            sourceYearId: src.id,
            label: _label.text,
            start: _start!,
            end: _end!,
            copyCalendar: _copyCalendar,
          );
      ref.invalidate(adminAcademicYearsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.move_up_rounded,
      title: "Passage d'année",
      subtitle: 'Créer la prochaine rentrée du groupe',
      width: 500,
      saving: _saving,
      submitLabel: 'Lancer le passage',
      submitIcon: Icons.move_up_rounded,
      submitColor: kGreen,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminFormSectionLabel('ANNÉE SOURCE'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _sourceId,
            isExpanded: true,
            decoration:
                adminFilledInput('Année source', icon: Icons.history_rounded),
            items: widget.years
                .map((y) => DropdownMenuItem(
                      value: y.id,
                      child: Text(
                          '${y.label}${y.isCurrent ? "  · en cours" : ""}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _sourceId = v;
              _applyPrefill(_source);
            }),
          ),
          const AdminFormDivider(),
          const AdminFormSectionLabel('NOUVELLE ANNÉE'),
          const SizedBox(height: 14),
          TextField(
              controller: _label,
              decoration: adminFilledInput('Libellé de la nouvelle année',
                  icon: Icons.label_outline_rounded)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _DateField(
                    label: 'Début',
                    value: _start,
                    onPick: (d) => setState(() => _start = d))),
            const SizedBox(width: 12),
            Expanded(
                child: _DateField(
                    label: 'Fin',
                    value: _end,
                    onPick: (d) => setState(() => _end = d))),
          ]),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _copyCalendar = !_copyCalendar),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _copyCalendar ? kGreen.withValues(alpha: 0.06) : kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _copyCalendar
                        ? kGreen.withValues(alpha: 0.4)
                        : kBorder),
              ),
              child: Row(children: [
                Icon(Icons.event_note_rounded,
                    size: 18, color: _copyCalendar ? kGreen : kTextMuted),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Reporter le calendrier (trimestres & séquences, +1 an)',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kNavy),
                  ),
                ),
                Checkbox(
                  value: _copyCalendar,
                  activeColor: kGreen,
                  onChanged: (v) => setState(() => _copyCalendar = v ?? false),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: kNavy),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Année créée NON courante. Les écoles prépareront leurs '
                  'classes ; définissez-la courante le jour de la rentrée.',
                  style:
                      TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AdminErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}
