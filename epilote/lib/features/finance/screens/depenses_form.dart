part of 'depenses_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE DÉPENSE — intitulé, montant XAF, date, catégorie, description.
// ════════════════════════════════════════════════════════════════════════════
class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({this.expense});
  final Expense? expense;
  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'fournitures';
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _title.text = e.title;
      _amount.text = '${e.amount}';
      _desc.text = e.description ?? '';
      _category = e.category ?? 'autre';
      _date = DateTime.tryParse(e.date ?? '') ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim().replaceAll(' ', ''));
    if (_title.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Intitulé et montant (> 0) requis'),
          backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => saveExpense(
        id: widget.expense?.id,
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        title: _title.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        amount: amount,
        date: _date.toIso8601String().substring(0, 10),
        category: _category,
        createdBy: p?.id ?? '',
      ),
      success: _isEdit ? 'Dépense modifiée' : 'Dépense enregistrée',
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, _isEdit ? 'Modifier la dépense' : 'Nouvelle dépense',
              Icons.trending_down_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                TextField(
                  controller: _title,
                  decoration: adminFilledInput('Intitulé',
                      icon: Icons.label_outline_rounded),
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
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration:
                      adminFilledInput('Catégorie', icon: Icons.category_outlined),
                  items: [
                    for (final (v, l) in kExpenseCategories)
                      DropdownMenuItem(value: v, child: Text(l)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'autre'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _desc,
                  maxLines: 2,
                  decoration: adminFilledInput('Description (facultatif)',
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
