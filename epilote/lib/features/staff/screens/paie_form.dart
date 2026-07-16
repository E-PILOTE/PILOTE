part of 'paie_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE BULLETIN DE PAIE — agent, base + primes − retenues = net (calculé
//  en direct), méthode, statut, référence. Pré-remplit la base depuis le contrat
//  de l'agent (staff_members) si disponible.
// ════════════════════════════════════════════════════════════════════════════
class _PayrollForm extends ConsumerStatefulWidget {
  const _PayrollForm({required this.month, required this.year, this.line});
  final int month, year;
  final PayrollLine? line;
  @override
  ConsumerState<_PayrollForm> createState() => _PayrollFormState();
}

class _PayrollFormState extends ConsumerState<_PayrollForm> {
  String? _staffId;
  final _base = TextEditingController(text: '0');
  final _bonuses = TextEditingController(text: '0');
  final _deductions = TextEditingController(text: '0');
  final _reference = TextEditingController();
  String _method = 'especes';
  String _status = 'pending';
  bool _saving = false;

  bool get _isEdit => widget.line != null;

  int get _net =>
      (int.tryParse(_base.text.trim().replaceAll(' ', '')) ?? 0) +
      (int.tryParse(_bonuses.text.trim().replaceAll(' ', '')) ?? 0) -
      (int.tryParse(_deductions.text.trim().replaceAll(' ', '')) ?? 0);

  @override
  void initState() {
    super.initState();
    final l = widget.line;
    if (l != null) {
      _staffId = l.staffId;
      _base.text = '${l.base}';
      _bonuses.text = '${l.bonuses}';
      _deductions.text = '${l.deductions}';
      _reference.text = l.reference ?? '';
      _method = kPayMethods.any((e) => e.$1 == l.method) ? l.method! : 'especes';
      _status = kPayStatuses.any((e) => e.$1 == l.status) ? l.status : 'pending';
    }
  }

  @override
  void dispose() {
    _base.dispose();
    _bonuses.dispose();
    _deductions.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_staffId == null) {
      _snack('Sélectionnez un agent');
      return;
    }
    final base = int.tryParse(_base.text.trim().replaceAll(' ', '')) ?? 0;
    if (base <= 0) {
      _snack('Salaire de base (> 0) requis');
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => savePayroll(
        id: widget.line?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        staffId: _staffId!,
        month: widget.month,
        year: widget.year,
        base: base,
        bonuses: int.tryParse(_bonuses.text.trim().replaceAll(' ', '')) ?? 0,
        deductions:
            int.tryParse(_deductions.text.trim().replaceAll(' ', '')) ?? 0,
        method: _method,
        status: _status,
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        createdBy: p?.id ?? '',
      ),
      success: _isEdit ? 'Bulletin modifié' : 'Bulletin créé',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: kRed));

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(staffDirectoryProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(
              context,
              _isEdit
                  ? 'Modifier le bulletin'
                  : 'Bulletin · ${kMonthNames[widget.month - 1]} ${widget.year}',
              Icons.payments_rounded),
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
                  onChanged: _isEdit ? null : (v) => setState(() => _staffId = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _base,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: adminFilledInput('Salaire de base (FCFA)',
                      icon: Icons.payments_rounded),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _bonuses,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: adminFilledInput('Primes (FCFA)',
                          icon: Icons.add_circle_outline_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _deductions,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: adminFilledInput('Retenues (FCFA)',
                          icon: Icons.remove_circle_outline_rounded),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 18, color: kGreen),
                    const SizedBox(width: 10),
                    const Text('Net à payer',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(fmtXaf(_net),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kGreen)),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _method,
                      isExpanded: true,
                      decoration: adminFilledInput('Méthode',
                          icon: Icons.account_balance_wallet_outlined),
                      items: [
                        for (final (v, l) in kPayMethods)
                          DropdownMenuItem(value: v, child: Text(l)),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'especes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: adminFilledInput('Statut',
                          icon: Icons.verified_outlined),
                      items: [
                        for (final (v, l) in kPayStatuses)
                          DropdownMenuItem(value: v, child: Text(l)),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'pending'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _reference,
                  decoration: adminFilledInput('Référence (facultatif)',
                      icon: Icons.tag_rounded),
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
