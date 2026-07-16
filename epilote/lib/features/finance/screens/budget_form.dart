part of 'budget_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE LIGNE BUDGÉTAIRE — poste, montant prévu, réalisé, notes.
// ════════════════════════════════════════════════════════════════════════════
class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({this.line});
  final BudgetLine? line;
  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  String _category = 'personnel';
  final _budgeted = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.line != null;

  @override
  void initState() {
    super.initState();
    final l = widget.line;
    if (l != null) {
      _category =
          kBudgetCategories.any((e) => e.$1 == l.category) ? l.category : 'autre';
      _budgeted.text = '${l.budgeted}';
      _notes.text = l.notes ?? '';
    }
  }

  @override
  void dispose() {
    _budgeted.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final budgeted = int.tryParse(_budgeted.text.trim().replaceAll(' ', ''));
    if (budgeted == null || budgeted <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Montant prévu (> 0) requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveBudgetLine(
        id: widget.line?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        category: _category,
        budgeted: budgeted,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      success: _isEdit ? 'Ligne modifiée' : 'Ligne créée',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier la ligne' : 'Nouvelle ligne',
              Icons.account_balance_wallet_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration:
                      adminFilledInput('Poste', icon: Icons.category_outlined),
                  items: [
                    for (final (slug, label) in kBudgetCategories)
                      DropdownMenuItem(value: slug, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'autre'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _budgeted,
                  keyboardType: TextInputType.number,
                  decoration: adminFilledInput('Montant prévu (FCFA)',
                      icon: Icons.savings_rounded),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: kTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Le réalisé est calculé automatiquement à partir des '
                          'dépenses de ce poste.',
                          style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: adminFilledInput('Notes (facultatif)',
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
