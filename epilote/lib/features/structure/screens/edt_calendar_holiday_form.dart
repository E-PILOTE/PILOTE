part of 'edt_settings_screen.dart';

// ─── Formulaire d'ajout d'un jour non ouvré ────────────────────────────────

// ─── Formulaire d'ajout d'un jour non ouvré ──────────────────────────────────
class _HolidayForm extends ConsumerStatefulWidget {
  const _HolidayForm();
  @override
  ConsumerState<_HolidayForm> createState() => _HolidayFormState();
}

class _HolidayFormState extends ConsumerState<_HolidayForm> {
  final _label = TextEditingController();
  String _kind = 'vacances';
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    // ⚠️ FERMÉ PAR DÉFAUT. Le repli `année ± 1` n'avait aucun rapport avec
    // l'année scolaire : il laissait choisir une date hors bornes. Or le
    // déclencheur `fn_check_holiday_period` refuse en 23514 une vacance qui
    // sort de l'année — et `23xxx` figure dans `_fatalResponseCodes` du
    // connecteur : le LOT ENTIER d'écritures en attente est jeté, pas
    // seulement cette ligne. `_save` exige déjà l'année, mais il la lit d'un
    // AUTRE provider : entre les deux lectures, la fenêtre pouvait s'ouvrir
    // grande puis l'écriture partir. « Je ne sais pas » se traite comme
    // « pas maintenant », jamais comme « sans limite ».
    final picked = await choisirDateScolaire(context, ref,
        initiale: (start ? _start : _end) ?? _start ?? DateTime.now());
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end == null || _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        if (_start == null || _start!.isAfter(picked)) _start = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _start == null || _end == null) return;
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    final missing = missingWriteIds(
        groupId: profile?.groupId,
        schoolId: profile?.schoolId,
        actorId: profile?.id);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(writeIdentityMessage(missing)), backgroundColor: kRed));
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => createHoliday(
        groupId: profile!.groupId!,
        schoolId: profile.schoolId!,
        academicYearId: yearId,
        label: _label.text,
        kind: _kind,
        startDate: _start!,
        endDate: _end!,
      ),
      success: 'Jour non ouvré ajouté',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _label.text.trim().isNotEmpty && _start != null && _end != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Icon(Icons.event_busy_outlined, size: 18, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Ajouter un jour non ouvré',
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
            child: ListView(
                padding: const EdgeInsets.all(18),
                shrinkWrap: true,
                children: [
              DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration:
                    adminFilledInput('Type', icon: Icons.category_outlined),
                items: [
                  for (final (v, l) in kHolidayKinds)
                    DropdownMenuItem(value: v, child: Text(l)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 'vacances'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _label,
                onChanged: (_) => setState(() {}),
                decoration: adminFilledInput(
                    _kind == 'ferie'
                        ? 'Libellé (ex. Fête de l\'Indépendance)'
                        : 'Libellé (ex. Vacances de Noël)',
                    icon: Icons.label_outline_rounded),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _DateField(
                    label: 'Début',
                    value: _start,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Fin',
                    value: _end,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ]),
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
                  onPressed: _saving || !valid ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              adminFilledInput(label, icon: Icons.calendar_today_rounded),
          child: Text(
              value == null
                  ? '—'
                  : '${value!.day.toString().padLeft(2, '0')}/'
                      '${value!.month.toString().padLeft(2, '0')}/${value!.year}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: value == null ? kTextMuted : kTextPrimary)),
        ),
      );
}
