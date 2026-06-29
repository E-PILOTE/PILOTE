part of 'paiements_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE PAIEMENTS D'UN ÉLÈVE — total payé, historique, + Nouveau paiement.
// ════════════════════════════════════════════════════════════════════════════
class _StudentPaymentsSheet extends ConsumerWidget {
  const _StudentPaymentsSheet({
    required this.row,
    required this.canEdit,
    required this.onChanged,
  });
  final StudentPayRow row;
  final bool canEdit;
  final VoidCallback onChanged;

  Color _statusColor(String? s) => switch (s) {
        'confirmed' => kGreen,
        'pending' => const Color(0xFFF59E0B),
        'cancelled' => kRed,
        _ => kTextMuted,
      };

  Future<void> _delete(BuildContext context, WidgetRef ref, PaymentRow p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce paiement ?'),
        content: Text('${fmtXaf(p.amount)} du ${p.date ?? '—'} sera supprimé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runModuleWrite(context, () => deletePayment(p.id),
        success: 'Paiement supprimé');
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentPaymentsProvider(row.studentId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.studentName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text('Total réglé : ${fmtXaf(row.paid)}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kGreen)),
                    ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _PaymentForm(row: row, onSaved: onChanged),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouveau paiement'),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AdminEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucun paiement',
                        message: 'Enregistrez le premier paiement de cet élève.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: payments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    final c = _statusColor(p.status);
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(fmtXaf(p.amount),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: c.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5)),
                                    child: Text(paymentStatusLabel(p.status),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: c)),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                    '${p.feeName ?? 'Frais'} · ${p.date ?? '—'} · '
                                    '${paymentMethodLabel(p.method)}'
                                    '${p.receipt != null ? ' · ${p.receipt}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: kTextMuted)),
                              ]),
                        ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () => _delete(context, ref, p),
                          ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Montant (> 0) requis'), backgroundColor: kRed));
      return;
    }
    final p = ref.read(authNotifierProvider).valueOrNull;
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => savePayment(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        studentId: widget.row.studentId,
        enrollmentId: widget.row.enrollmentId,
        feeStructureId: _feeId,
        amount: amount,
        date: _date.toIso8601String().substring(0, 10),
        method: _method,
        status: _status,
        recordedBy: p?.id ?? '',
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
