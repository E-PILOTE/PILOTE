part of 'paiements_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE PAIEMENTS D'UN ÉLÈVE — total payé, historique, + Nouveau paiement.
// ════════════════════════════════════════════════════════════════════════════
class _StudentPaymentsSheet extends ConsumerWidget {
  const _StudentPaymentsSheet({
    required this.row,
    required this.className,
    required this.canEdit,
    required this.onChanged,
  });
  final StudentPayRow row;
  final String className;
  final bool canEdit;
  final VoidCallback onChanged;

  /// Ouvre l'aperçu du reçu. Un paiement annulé imprime son annulation plutôt
  /// que de se taire : c'est ce qui rend le papier opposable dans les deux sens.
  void _recu(BuildContext context, WidgetRef ref, PaymentRow p) {
    final acteur =
        ref.read(authNotifierProvider).valueOrNull?.fullName ?? 'Le caissier';
    showPdfPreviewDialog(
      context,
      title: 'Reçu de paiement',
      subtitle: p.receipt,
      pdfFileName: '${p.receipt ?? 'recu'}.pdf',
      build: (_) => construireRecuPaiement(
        recu: RecuPaiement(
          numero: p.receipt ?? '—',
          eleve: row.studentName,
          matricule: row.matricule,
          classe: className,
          montant: p.amount,
          date: DateTime.tryParse(p.date ?? '') ?? DateTime.now(),
          methode: paymentMethodLabel(p.method),
          encaissePar: acteur,
          motifFrais: p.feeName,
          annuleLe: p.status == 'cancelled' ? p.date : null,
          motifAnnulation: p.cancellationReason,
        ),
      ),
    );
  }

  Color _statusColor(String? s) => switch (s) {
        'confirmed' => kGreen,
        'pending' => const Color(0xFFF59E0B),
        'cancelled' => kRed,
        _ => kTextMuted,
      };

  /// Annuler, jamais effacer : sur de l'argent public, une ligne qui disparaît
  /// laisse une caisse fausse que plus personne ne sait expliquer.
  Future<void> _annuler(
      BuildContext context, WidgetRef ref, PaymentRow p) async {
    final saisi = await showDialog<String>(
      context: context,
      builder: (_) => _MotifAnnulationDialog(paiement: p),
    );
    if (saisi == null || !context.mounted) return;

    final probleme = motifAnnulationInvalide(saisi);
    if (probleme != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(probleme), backgroundColor: kRed));
      return;
    }
    final actor = ref.read(authNotifierProvider).valueOrNull?.id;
    if (actor == null) return;

    await runModuleWrite(
      context,
      () => cancelPayment(id: p.id, motif: saisi, actorId: actor),
      success: 'Paiement annulé',
    );
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
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text('Total réglé : ${fmtXaf(row.paid)}',
                          style: TextStyle(
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
                        color: kCardBg,
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
                                    style: TextStyle(
                                        fontSize: 11.5, color: kTextMuted)),
                                if (p.cancellationReason != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                        'Annulé — ${p.cancellationReason}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: kRed)),
                                  ),
                              ]),
                        ),
                        IconButton(
                          tooltip: 'Imprimer le reçu',
                          icon: Icon(Icons.receipt_long_rounded,
                              size: 18, color: kNavy),
                          onPressed: () => _recu(context, ref, p),
                        ),
                        if (canEdit && peutAnnulerPaiement(p.status))
                          IconButton(
                            tooltip: 'Annuler ce paiement',
                            icon: Icon(Icons.block_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () => _annuler(context, ref, p),
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

// ─── Motif d'annulation ──────────────────────────────────────────────────────
//
// ⚠️ La boîte POSSÈDE son contrôleur et le libère elle-même.
//
// `await showDialog` rend la main dès le `Navigator.pop`, PAS à la fin de
// l'animation de sortie : libérer le contrôleur depuis l'appelant juste après
// l'attente le détruit pendant que le TextField en dépend encore, et l'écran
// vire au rouge sur « _dependents.isEmpty is not true ». Constaté à l'écran le
// 2026-08-04, comme sur la boîte de reconnexion la semaine d'avant.
class _MotifAnnulationDialog extends StatefulWidget {
  const _MotifAnnulationDialog({required this.paiement});
  final PaymentRow paiement;
  @override
  State<_MotifAnnulationDialog> createState() => _MotifAnnulationDialogState();
}

class _MotifAnnulationDialogState extends State<_MotifAnnulationDialog> {
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paiement;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Annuler ce paiement ?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '${fmtXaf(p.amount)} du ${p.date ?? '—'} sera marqué ANNULÉ. '
          'La ligne et son reçu restent au dossier — rien n\'est effacé.',
          style: TextStyle(fontSize: 13, color: kTextMuted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motif,
          autofocus: true,
          maxLines: 2,
          decoration: adminFilledInput('Motif de l\'annulation',
              icon: Icons.edit_note_rounded),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Renoncer')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kRed),
          onPressed: () => Navigator.pop(context, _motif.text),
          child: const Text('Annuler le paiement'),
        ),
      ],
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
