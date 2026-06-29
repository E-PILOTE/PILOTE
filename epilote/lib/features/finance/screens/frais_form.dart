part of 'frais_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE BARÈME — nom, type, montant XAF, jour d'échéance (mensualité),
//  niveau concerné (optionnel = toute l'école). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class _FeeForm extends ConsumerStatefulWidget {
  const _FeeForm({this.fee});
  final FeeStructure? fee;
  @override
  ConsumerState<_FeeForm> createState() => _FeeFormState();
}

class _FeeFormState extends ConsumerState<_FeeForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _dueDay = TextEditingController();
  String _type = 'mensualite';
  String? _levelId;
  bool _saving = false;

  bool get _isEdit => widget.fee != null;

  @override
  void initState() {
    super.initState();
    final f = widget.fee;
    if (f != null) {
      _name.text = f.name;
      _amount.text = '${f.amount}';
      _dueDay.text = f.dueDay?.toString() ?? '';
      _type = f.feeType;
      _levelId = f.levelId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim().replaceAll(' ', ''));
    if (_name.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nom et montant (> 0) requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveFeeStructure(
        id: widget.fee?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        name: _name.text.trim(),
        feeType: _type,
        amount: amount,
        dueDay: int.tryParse(_dueDay.text.trim()),
        levelId: _levelId,
      ),
      success: _isEdit ? 'Barème modifié' : 'Barème créé',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(schoolLevelOptionsProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier le barème' : 'Nouveau barème',
              Icons.request_quote_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _name,
                  decoration: adminFilledInput('Nom (ex. Mensualité 6e)',
                      icon: Icons.label_outline_rounded),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration:
                      adminFilledInput('Type', icon: Icons.category_outlined),
                  items: [
                    for (final (v, l) in kFeeTypes)
                      DropdownMenuItem(value: v, child: Text(l)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'autre'),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: adminFilledInput('Montant (FCFA)',
                          icon: Icons.payments_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _dueDay,
                      keyboardType: TextInputType.number,
                      decoration: adminFilledInput('Éch. (jour)',
                          icon: Icons.event_rounded),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _levelId,
                  isExpanded: true,
                  decoration: adminFilledInput('Niveau concerné',
                      icon: Icons.stairs_rounded),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Toute l\'école')),
                    for (final l in levels)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setState(() => _levelId = v),
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
