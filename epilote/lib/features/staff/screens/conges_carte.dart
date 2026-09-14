part of 'conges_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  COMMENT UNE DEMANDE DE CONGÉ S'AFFICHE — et ce qu'elle apprend à qui la
//  tranche.
//
//  Sorti de `conges_screen.dart` le 2026-09-10 : l'ajout du décompte de
//  l'agent y avait fait passer le fichier de 478 à 552 lignes, au-dessus du
//  plafond de 500 que ce dépôt se donne. La coupe suit une couture de
//  cohésion — tout ce qui concerne le RENDU d'une demande — et non un
//  nombre de lignes.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Carte demande ───────────────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.req,
    required this.conso,
    required this.canReview,
    required this.canDelete,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
  });
  final LeaveRequest req;

  /// Ce que cet agent a déjà obtenu sur l'année scolaire. `null` = aucune
  /// demande antérieure — pas la même chose qu'un total à zéro non lu.
  final ConsommationConges? conso;

  final bool canReview, canDelete;
  final VoidCallback onApprove, onReject, onEdit, onDelete;

  /// Ce que l'agent a déjà obtenu et engagé cette année scolaire.
  ///
  /// Le DROIT annuel n'y figure pas — il n'est pas encore établi (cf.
  /// `solde_conges_provider.dart`). On écrit donc ce qu'on sait, et on dit
  /// franchement ce qu'on ne sait pas : afficher un reliquat calculé sur un
  /// droit inventé ferait refuser des congés sur un chiffre faux.
  Widget _decompte() {
    final k = conso;
    final deja = k?.approuves ?? 0;
    final attente = k?.enAttente ?? 0;
    final autres = k?.horsDecompte ?? 0;

    final morceaux = <String>[
      deja == 0
          ? 'aucun congé annuel accordé cette année'
          : '$deja jour${deja > 1 ? 's' : ''} de congé annuel déjà accordé'
              '${deja > 1 ? 's' : ''}',
      if (attente > 0) '$attente en instruction (celle-ci comprise)',
      if (autres > 0)
        "$autres jour${autres > 1 ? 's' : ''} sur d'autres motifs",
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.history_toggle_off_rounded, size: 15, color: kTextMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(morceaux.join(' · '),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                    'Droit annuel non établi — le reliquat ne peut pas encore '
                    "être calculé. Décompte sur l'année scolaire.",
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = req;
    final c = _leaveColor(r.status);
    final period = [
      if ((r.startDate ?? '').isNotEmpty) r.startDate!,
      if ((r.endDate ?? '').isNotEmpty) r.endDate!,
    ].join(' → ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.staffName.isEmpty ? '—' : r.staffName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(leaveStatusLabel(r.status),
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
          ),
          if (canDelete || (canReview && r.status != 'pending'))
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: kTextMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canReview && r.isPending)
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer', style: TextStyle(color: kRed))),
              ],
            )
          else
            const SizedBox(width: 8),
        ]),
        const SizedBox(height: 4),
        Text(
            '${leaveTypeLabel(r.leaveType)} · ${r.daysCount} jour'
            '${r.daysCount > 1 ? 's' : ''}${period.isNotEmpty ? ' · $period' : ''}',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: kNavy)),
        if ((r.reason ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(r.reason!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
        if (r.status == 'rejected' && (r.rejectionReason ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text('Refus : ${r.rejectionReason!.trim()}',
              style: TextStyle(fontSize: 11.5, color: kRed)),
        ],
        // ── LE DÉCOMPTE DE L'AGENT, SOUS LA DEMANDE QU'ON INSTRUIT ────────
        //  Il n'apparaît que sur les demandes EN ATTENTE : c'est là qu'une
        //  décision se prend. Sur une demande déjà tranchée, il ne ferait que
        //  du bruit.
        if (canReview && r.isPending) _decompte(),
        if (canReview && r.isPending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approuver'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
