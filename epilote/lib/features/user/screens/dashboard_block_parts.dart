part of 'user_dashboard_screen.dart';

// Lien d'en-tête « Voir » → page du module (drill-down, garde le retour).
// Réutilisé par les blocs Finances / Discipline (cohérent avec les KPI Scolarité).
Widget _dashSeeAll(BuildContext context, String route) => TextButton(
      onPressed: () => context.push(route),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Voir',
            style: TextStyle(
                color: kNavy, fontWeight: FontWeight.w700, fontSize: 13)),
        Icon(Icons.chevron_right_rounded, size: 18, color: kNavy),
      ]),
    );

// ─── Bloc SCOLARITÉ (vue d'ensemble + statistiques) ───────────────────────────
// Extrait en widget (comme Finance/Médical/Discipline) pour pouvoir être
// ordonné par la persona de rôle. Auto-titré + espacement de fin homogène.
class _ScolariteBlock extends StatelessWidget {
  const _ScolariteBlock({
    required this.showClasses,
    required this.showEleves,
    required this.showInscriptions,
  });
  final bool showClasses, showEleves, showInscriptions;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AdminSectionTitle("Vue d'ensemble", icon: Icons.insights_rounded),
      const SizedBox(height: 14),
      _KpiGrid(
        showClasses: showClasses,
        showEleves: showEleves,
        showInscriptions: showInscriptions,
      ),
      const SizedBox(height: 24),
      const AdminSectionTitle('Statistiques', icon: Icons.bar_chart_rounded),
      const SizedBox(height: 14),
      const _ChartsRow(),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Bloc FINANCE (comptable / direction) ─────────────────────────────────────
class _FinanceBlock extends ConsumerWidget {
  const _FinanceBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pay = ref.watch(paymentsSummaryProvider).valueOrNull ??
        const PaymentsSummary(0, 0);
    final dep = ref.watch(expensesTotalProvider).valueOrNull ?? 0;
    final solde = pay.encaisse - dep;
    final recouvre = pay.encaisse + pay.attente;

    // Lien direct vers la page Paiements (seule page Finance réelle aujourd'hui).
    // Les cartes Encaissé / En attente y mènent ; Dépenses / Solde non (pas de
    // page dédiée). Gardé sous permission `can_read` (verrou 3).
    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? const {};
    final canPay = perms['paiements-eleves']?.canRead ?? false;
    final toPay = canPay ? () => context.push(Routes.paiements) : null;

    final cards = <Widget>[
      AdminStatCard(
        label: 'Encaissé',
        value: _xaf(pay.encaisse),
        subtitle: 'FCFA',
        icon: Icons.payments_rounded,
        color: kGreen,
        onTap: toPay,
      ),
      AdminStatCard(
        label: 'En attente',
        value: _xaf(pay.attente),
        subtitle: 'FCFA',
        icon: Icons.schedule_rounded,
        color: kAccent,
        onTap: toPay,
      ),
      AdminStatCard(
        label: 'Dépenses',
        value: _xaf(dep),
        subtitle: 'année · FCFA',
        icon: Icons.trending_down_rounded,
        color: const Color(0xFFEF4444),
      ),
      AdminStatCard(
        label: 'Solde',
        value: _xaf(solde),
        subtitle: 'FCFA',
        icon: Icons.account_balance_rounded,
        color: kNavy,
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AdminSectionTitle('Finances',
          icon: Icons.account_balance_wallet_rounded,
          trailing: canPay ? _dashSeeAll(context, Routes.paiements) : null),
      const SizedBox(height: 14),
      _StatGrid(cards),
      if (recouvre > 0) ...[
        const SizedBox(height: 14),
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _ChartTitle('Recouvrement', Icons.donut_large_rounded),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  textStyle: TextStyle(fontSize: 11, color: kTextMuted),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries<DashboardSlice, String>>[
                  DoughnutSeries<DashboardSlice, String>(
                    dataSource: [
                      DashboardSlice('Encaissé', pay.encaisse),
                      DashboardSlice('En attente', pay.attente),
                    ],
                    xValueMapper: (s, _) => s.label,
                    yValueMapper: (s, _) => s.value,
                    pointColorMapper: (s, _) =>
                        s.label == 'Encaissé' ? kGreen : kAccent,
                    innerRadius: '62%',
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Bloc MÉDICAL (infirmier / direction) ─────────────────────────────────────
class _MedicalBlock extends ConsumerWidget {
  const _MedicalBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicalSummaryProvider).valueOrNull ??
        const MedicalSummary(0, 0, 0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AdminSectionTitle('Infirmerie', icon: Icons.local_hospital_rounded),
      const SizedBox(height: 14),
      if (m.total == 0)
        const _EmptyMini(
          icon: Icons.health_and_safety_outlined,
          text: 'Aucune visite à l\'infirmerie enregistrée pour le moment.',
        )
      else
        _StatGrid([
          AdminStatCard(
            label: 'Visites ce mois',
            value: '${m.month}',
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF0EA5E9),
          ),
          AdminStatCard(
            label: 'Total visites',
            value: '${m.total}',
            icon: Icons.local_hospital_rounded,
            color: kNavy,
          ),
          AdminStatCard(
            label: 'Suivi requis',
            value: '${m.followUp}',
            icon: Icons.event_repeat_rounded,
            color: m.followUp > 0 ? kAccent : kTextMuted,
          ),
        ]),
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Bloc DISCIPLINE (cpe / surveillant / direction) ──────────────────────────
class _DisciplineBlock extends ConsumerWidget {
  const _DisciplineBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(disciplineSummaryProvider).valueOrNull ??
        const DisciplineSummary(0, 0, 0);

    // Le bloc ne s'affiche que si `discipline` est lisible (verrou 3) → la page
    // Discipline est toujours accessible depuis ici.
    void toDiscipline() => context.push(Routes.discipline);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AdminSectionTitle('Discipline',
          icon: Icons.gavel_rounded,
          trailing: _dashSeeAll(context, Routes.discipline)),
      const SizedBox(height: 14),
      if (d.yearTotal == 0)
        const _EmptyMini(
          icon: Icons.shield_outlined,
          text: 'Aucun incident disciplinaire enregistré cette année.',
        )
      else
        _StatGrid([
          AdminStatCard(
            label: 'Ce mois',
            value: '${d.month}',
            icon: Icons.report_problem_rounded,
            color: const Color(0xFFEF4444),
            onTap: toDiscipline,
          ),
          AdminStatCard(
            label: 'Total (année)',
            value: '${d.yearTotal}',
            icon: Icons.gavel_rounded,
            color: kNavy,
            onTap: toDiscipline,
          ),
          AdminStatCard(
            label: 'À notifier',
            value: '${d.unnotified}',
            icon: Icons.notification_important_rounded,
            color: d.unnotified > 0 ? kAccent : kTextMuted,
            onTap: toDiscipline,
          ),
        ]),
      const SizedBox(height: 24),
    ]);
  }
}
