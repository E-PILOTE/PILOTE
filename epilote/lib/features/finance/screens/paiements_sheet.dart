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
    // Le solde à ce jour, s'il est connu. `valueOrNull` et non `.future` : un
    // reçu doit sortir même si le décompte n'a pas encore chargé — la ligne
    // manquera, le papier existera.
    final d = row.enrollmentId == null
        ? null
        : ref.read(decompteDuProvider(row.enrollmentId!)).valueOrNull;
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
          // `vide` ⇒ aucun barème publié : on ne sait rien du solde, et la
          // ligne est omise plutôt qu'imprimée à zéro.
          resteDu: (d == null || d.vide) ? null : d.reste,
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

  /// Rendre l'argent, en le disant. Le remboursement conserve la ligne
  /// d'encaissement — c'est le seul moyen de justifier la sortie de caisse.
  Future<void> _rembourser(
      BuildContext context, WidgetRef ref, PaymentRow p) async {
    final saisie = await showDialog<SaisieRemboursement>(
      context: context,
      builder: (_) => RemboursementDialog(encaisse: p.amount, date: p.date),
    );
    if (saisie == null || !context.mounted) return;
    final actor = ref.read(authNotifierProvider).valueOrNull?.id;
    if (actor == null) return;

    await runModuleWrite(
      context,
      () => refundPayment(
        id: p.id,
        montant: saisie.montant,
        encaisse: p.amount,
        motif: saisie.motif,
        actorId: actor,
      ),
      success: 'Remboursement enregistré',
    );
    onChanged();
  }

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
                      Text(
                          '$className'
                          '${row.matricule == null ? '' : ' · ${row.matricule}'}',
                          style: TextStyle(fontSize: 12, color: kTextMuted)),
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
              error: (e, _) => Center(child: Text(messageErreur(e))),
              data: (payments) {
                // ── CE QU'IL DOIT, AVANT CE QU'IL A VERSÉ ──────────────────
                // L'en-tête n'annonçait que « Total réglé » : le caissier
                // voyait ce qui était entré et jamais ce qui manquait — la
                // seule question que pose la famille au guichet.
                //
                // ⚠️ DANS la zone défilante, et non en tête fixe. Un décompte
                // à huit lignes fait 200 px ; ajouté aux 120 px d'en-tête et de
                // bouton, il ne laissait plus rien à l'`Expanded` sur une
                // feuille tirée à sa taille minimale — débordement garanti sur
                // un téléphone.
                final entete = row.enrollmentId == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: DecompteCard(enrollmentId: row.enrollmentId!),
                      );

                if (payments.isEmpty) {
                  return ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      entete,
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: AdminEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Aucun paiement',
                          message:
                              'Enregistrez le premier paiement de cet élève.',
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: payments.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    if (index == 0) return entete;
                    final i = index - 1;
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
                        if (canEdit && peutRembourserPaiement(p.status))
                          IconButton(
                            tooltip: 'Rembourser',
                            icon: Icon(Icons.undo_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () => _rembourser(context, ref, p),
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
