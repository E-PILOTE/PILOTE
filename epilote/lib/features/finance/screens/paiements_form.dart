part of 'paiements_screen.dart';

// ─── Formulaire d'un paiement ────────────────────────────────────────────────
class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm({required this.row, required this.onSaved});
  final StudentPayRow row;
  final VoidCallback onSaved;
  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  String? _feeId;
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'especes';
  String _status = 'confirmed';
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim().replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Montant (> 0) requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);

    // `enrollment_id` et `academic_year_id` sont NOT NULL en base. Les écrire
    // vides ferait REFUSER la ligne par le serveur, ce qui abandonne le lot
    // PowerSync entier et emporte le travail des autres modules — sans le
    // moindre message.
    final missing = [
      ...missingWriteIds(
          groupId: p?.groupId, schoolId: p?.schoolId, actorId: p?.id),
      if (!isUsableId(widget.row.enrollmentId)) 'inscription de l\'élève',
      if (!isUsableId(yearId)) 'année scolaire active',
    ];
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(writeIdentityMessage(missing)),
        backgroundColor: kRed,
        duration: const Duration(seconds: 6),
      ));
      return;
    }

    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => savePayment(
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        academicYearId: yearId!,
        studentId: widget.row.studentId,
        enrollmentId: widget.row.enrollmentId,
        feeStructureId: _feeId,
        amount: amount,
        date: _date.toIso8601String().substring(0, 10),
        method: _method,
        status: _status,
        recordedBy: p.id,
      ),
      success: 'Paiement enregistré',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fees = ref.watch(feeStructuresProvider).valueOrNull ?? const [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          vsFormHeader(context, 'Nouveau paiement', Icons.payments_rounded),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                Text(widget.row.studentName,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _feeId,
                  isExpanded: true,
                  decoration: adminFilledInput('Frais concerné',
                      icon: Icons.request_quote_rounded),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Autre / libre')),
                    for (final f in fees)
                      DropdownMenuItem(
                          value: f.id,
                          child: Text('${f.name} (${fmtXaf(f.amount)})',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _feeId = v;
                      final f = fees.where((x) => x.id == v).firstOrNull;
                      if (f != null) _amount.text = '${f.amount}';
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: adminFilledInput('Montant (FCFA)',
                      icon: Icons.payments_rounded),
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
                        child: Text(_fmtDate(_date),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _method,
                      isExpanded: true,
                      decoration: adminFilledInput('Méthode',
                          icon: Icons.account_balance_wallet_rounded),
                      items: [
                        for (final (v, l) in kPaymentMethods)
                          DropdownMenuItem(value: v, child: Text(l)),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'especes'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration:
                      adminFilledInput('Statut', icon: Icons.verified_rounded),
                  items: [
                    for (final (v, l) in kPaymentStatuses)
                      DropdownMenuItem(value: v, child: Text(l)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'confirmed'),
                ),
              ],
            ),
          ),
          vsFormActions(context, _saving, _save, false),
        ]),
      ),
    );
  }
}
