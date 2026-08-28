part of 'paiements_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE D'UN PAIEMENT
//
//  ── CE QUI A CHANGÉ, ET POURQUOI ───────────────────────────────────────────
//  La liste « Frais concerné » déroulait `feeStructuresProvider`, c'est-à-dire
//  le CATALOGUE ENTIER de l'école et du réseau : les tarifs des autres niveaux,
//  et les frais d'examen que le module Examens est seul à savoir facturer. Un
//  caissier pouvait donc encaisser, sur un élève de 6e, un baccalauréat.
//
//  Pire, choisir une ligne pré-remplissait son montant PLEIN — en ignorant
//  l'exonération de l'élève, les mois réellement dus, et ce qui avait déjà été
//  versé sur ce frais. Sur un boursier à 50 %, le guichet proposait le double
//  de ce qu'il fallait encaisser.
//
//  La liste est désormais celle du DÉCOMPTE de cet élève : ce qui s'applique à
//  lui, et ce qu'il en reste. « Autre / libre » demeure toujours offert — une
//  caisse qui ne sait pas encaisser un cas non prévu pousse à encaisser hors
//  système, ce qui revient à ne rien encaisser du tout.
// ════════════════════════════════════════════════════════════════════════════
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

    // Même règle qu'à l'affichage : un barème disparu du décompte pendant que
    // la boîte était ouverte ne doit pas se retrouver rattaché en douce à ce
    // versement — la liste montrait alors « Autre / libre », et c'est cela qui
    // fait foi.
    final decompte = widget.row.enrollmentId == null
        ? null
        : ref.read(decompteDuProvider(widget.row.enrollmentId!)).valueOrNull;
    final feeId =
        (decompte?.lignes.any((l) => l.id == _feeId) ?? false) ? _feeId : null;

    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () => savePayment(
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        academicYearId: yearId!,
        studentId: widget.row.studentId,
        enrollmentId: widget.row.enrollmentId,
        feeStructureId: feeId,
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
    final enrId = widget.row.enrollmentId;
    final d = enrId == null
        ? null
        : ref.watch(decompteDuProvider(enrId)).valueOrNull;
    // ⚠️ Le décompte est un FLUX : une ligne peut être soldée par un autre
    // poste pendant que cette boîte est ouverte. Si la valeur sélectionnée
    // disparaissait des items, `DropdownButtonFormField` lèverait son assertion
    // « exactly one item » et l'écran virerait au rouge, en pleine saisie de
    // paiement. La ligne choisie reste donc proposée tant qu'elle est
    // sélectionnée, même soldée.
    final ouvertes = [...(d?.lignesOuvertes ?? const <LigneDu>[])];
    if (_feeId != null && !ouvertes.any((l) => l.id == _feeId)) {
      final encore = d?.lignes.where((l) => l.id == _feeId).firstOrNull;
      if (encore != null) ouvertes.add(encore);
    }
    // Le barème a disparu du décompte entier (retiré, changement de niveau) :
    // on retombe sur « Autre / libre » plutôt que sur une valeur fantôme.
    final valeur = ouvertes.any((l) => l.id == _feeId) ? _feeId : null;

    final choisie = ouvertes.where((l) => l.id == valeur).firstOrNull;
    final resteLigne = choisie == null ? null : d!.resteDe(choisie);
    final saisi = int.tryParse(_amount.text.trim().replaceAll(' ', ''));
    final depasse =
        resteLigne != null && saisi != null && saisi > resteLigne;

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
                if (d != null && !d.vide)
                  Text(
                      d.reste > 0
                          ? 'Reste à régler : ${fmtXaf(d.reste)} sur ${fmtXaf(d.net)}'
                          : 'Tout est réglé — ${fmtXaf(d.net)} encaissés.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: d.reste > 0
                              ? const Color(0xFFF59E0B)
                              : kGreen)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: valeur,
                  isExpanded: true,
                  decoration: adminFilledInput('Frais concerné',
                      icon: Icons.request_quote_rounded),
                  items: [
                    for (final l in ouvertes)
                      DropdownMenuItem(
                          value: l.id,
                          child: Text(
                              '${l.libelle} — reste ${fmtXaf(d!.resteDe(l))}',
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(
                        value: null, child: Text('Autre / libre')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _feeId = v;
                      // On pré-remplit le RESTE, pas le tarif : c'est la somme
                      // que la caisse attend réellement, exonération déduite et
                      // acomptes défalqués.
                      final l = ouvertes.where((x) => x.id == v).firstOrNull;
                      if (l != null) _amount.text = '${d!.resteDe(l)}';
                    });
                  },
                ),
                if (ouvertes.isEmpty && d != null && !d.vide) ...[
                  const SizedBox(height: 6),
                  Text(
                      'Toutes les lignes du décompte sont soldées. Un versement '
                      'supplémentaire sera enregistré comme libre.',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: adminFilledInput('Montant (FCFA)',
                      icon: Icons.payments_rounded),
                ),
                if (depasse) ...[
                  const SizedBox(height: 6),
                  // On AVERTIT, on ne bloque pas : un versement en avance est
                  // légitime, et refuser l'argent au comptoir ne réglerait rien.
                  // Mais un trop-perçu se rembourse, et mieux vaut le savoir
                  // avant d'imprimer le reçu.
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Ce montant dépasse le reste dû sur cette ligne '
                          '(${fmtXaf(resteLigne)}). L\'excédent devra être '
                          'remboursé ou réaffecté.',
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Color(0xFFB45309))),
                    ),
                  ]),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await choisirDateScolaire(context, ref,
                            initiale: _date, plafond: DateTime.now());
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
