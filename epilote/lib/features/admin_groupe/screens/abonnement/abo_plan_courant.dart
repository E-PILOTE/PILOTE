part of '../admin_subscription_screen.dart';

// Mécanique de l’abonnement, formule en cours, facture en attente.

class _MecaniqueAbonnement extends StatelessWidget {
  const _MecaniqueAbonnement({required this.data, required this.sub});

  final AdminSubscriptionData data;
  final GroupSubscription sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        AdminSectionTitle('Changer de plan',
            icon: Icons.swap_horiz_rounded,
            subtitle: 'Comparez les offres et envoyez une demande à la plateforme',
            trailing: AdminBadge('${data.plans.length} offres', color: kNavy)),
        const SizedBox(height: 12),
        if (data.pendingRequest != null) ...[
          _PendingRequestBanner(t: data.pendingRequest!),
          const SizedBox(height: 12),
        ],
        _PlansGrid(
          plans: data.plans,
          currentPlanId: sub.planId,
          locked: data.hasPendingRequest,
        ),
        if (data.plans.length > 1) ...[
          const SizedBox(height: 24),
          const AdminSectionTitle('Comparatif des offres',
              icon: Icons.table_chart_rounded,
              subtitle: 'Limites et familles de modules par plan'),
          const SizedBox(height: 12),
          _ComparisonMatrix(data: data),
        ],
        if (data.tickets.isNotEmpty) ...[
          const SizedBox(height: 24),
          AdminSectionTitle('Mes demandes',
              icon: Icons.history_rounded,
              subtitle: 'Suivi de vos demandes de changement de plan',
              trailing: AdminBadge('${data.tickets.length}', color: kNavy)),
          const SizedBox(height: 12),
          ...data.tickets.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TicketRow(t: t),
              )),
        ],
      ],
    );
  }
}

// ─── Carte plan courant ───────────────────────────────────────────────────────
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.sub, this.enAttente});
  final GroupSubscription sub;

  /// Facture de renouvellement déjà émise et non réglée, s'il y en a une.
  ///
  /// ⚠️ Depuis 0190, la plateforme émet cette facture TOUTE SEULE, sept jours
  /// avant l'échéance — donc AVANT que le bandeau « expire dans 5 jours » ne
  /// s'allume. Sans ce champ, l'écran continuait de proposer « Renouveler mon
  /// abonnement » à quelqu'un dont la facture attendait déjà : il cliquait, et
  /// le dialogue lui répondait « facture déjà en attente ». On lui montre
  /// désormais la somme due, ce qu'elle couvre, et rien à cliquer.
  final InvoiceDetail? enAttente;

  @override
  Widget build(BuildContext context) {
    final pColor = planColor(sub.planSlug);
    return AdminCard(
      accent: pColor,
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 620;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: pColor, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('Plan ${sub.planName}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                      const SizedBox(width: 10),
                      AdminBadge(statusLabel(sub.status), color: statusColor(sub.status),
                          icon: Icons.circle, ),
                    ]),
                    const SizedBox(height: 2),
                    Text(sub.priceXaf == 0
                            ? 'Gratuit'
                            : '${fmtXaf(sub.priceXaf)} / ${sub.periodSuffix}',
                        style: TextStyle(fontSize: 13, color: kTextMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            if (sub.description != null && sub.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(sub.description!, style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5)),
            ],
          ],
        );
        final right = Column(
          crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodLine(label: 'Début', date: sub.start),
            const SizedBox(height: 6),
            _PeriodLine(label: 'Échéance', date: sub.end),
            const SizedBox(height: 10),
            if (sub.expired)
              AdminBadge('Abonnement expiré', color: kRed, icon: Icons.error_rounded)
            else if (sub.expireSoon)
              AdminBadge('Expire dans ${sub.daysLeft} j', color: kAccent, icon: Icons.timelapse_rounded)
            else if (sub.daysLeft != null)
              AdminBadge('${sub.daysLeft} jours restants', color: kGreen, icon: Icons.check_circle_rounded),
            // La facture déjà émise passe AVANT le bouton : proposer de
            // renouveler quand la somme est déjà due n'amène qu'un refus poli.
            if (enAttente != null) ...[
              const SizedBox(height: 12),
              _FactureEnAttente(facture: enAttente!),
            ]
            // Réabonnement en libre-service : visible dès que l'échéance
            // approche ou est dépassée. Génère une facture de renouvellement du
            // MÊME plan (cf. showRenewSubscriptionDialog / create_renewal_invoice).
            else if (sub.expired || sub.expireSoon) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showRenewSubscriptionDialog(context, sub),
                icon: const Icon(Icons.autorenew_rounded, size: 17),
                label: const Text('Renouveler mon abonnement'),
                style: FilledButton.styleFrom(
                  backgroundColor: sub.expired ? kRed : kNavy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        );
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            left, const SizedBox(height: 16), Divider(color: kBorder), const SizedBox(height: 12), right,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left), const SizedBox(width: 20), right,
        ]);
      }),
    );
  }
}

// ─── La facture que la plateforme a déjà émise ────────────────────────────────
//
//  Elle remplace le bouton « Renouveler » : la démarche est faite, il reste à
//  payer. Trois informations, et pas une de plus — le numéro (c'est lui qu'on
//  cite au téléphone), la somme, et la période couverte. Le détail vit plus bas,
//  dans la section Facturation.
class _FactureEnAttente extends StatelessWidget {
  const _FactureEnAttente({required this.facture});
  final InvoiceDetail facture;

  static String _jour(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final enRetard = facture.isOverdue;
    final couleur = enRetard ? kRed : kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_rounded, size: 16, color: couleur),
            const SizedBox(width: 7),
            Text(
              enRetard ? 'Facture en retard' : 'Facture à régler',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: couleur),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${facture.invoiceNumber} · ${fmtXaf(facture.amountXaf)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            'Période du ${_jour(facture.periodStart)} '
            'au ${_jour(facture.periodEnd)}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _PeriodLine extends StatelessWidget {
  const _PeriodLine({required this.label, required this.date});
  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final txt = date == null
        ? '—'
        : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label : ', style: TextStyle(fontSize: 12, color: kTextMuted)),
      Text(txt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Grille quotas ────────────────────────────────────────────────────────────
