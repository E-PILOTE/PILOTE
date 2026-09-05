part of '../admin_reports_screen.dart';

// Section Finance et recouvrement.

class _FinanceSection extends StatelessWidget {
  const _FinanceSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final kpis = [
      _KD(
          label: 'Revenus (période)',
          value: fmtXaf(d.revenusTotal),
          icon: Icons.trending_up_rounded,
          color: kGreen,
          trend: d.periodLabel),
      _KD(
          label: 'Paiements',
          value: fmtInt(d.paiementsCount),
          sub: 'transactions confirmées',
          icon: Icons.receipt_long_rounded,
          color: kNavy),
      _KD(
          label: 'Élèves à jour',
          value: fmtInt(d.elevesAJour),
          sub: 'sur ${fmtInt(d.elevesTotal)}',
          icon: Icons.verified_rounded,
          color: kGreen,
          progress: d.elevesTotal > 0 ? d.elevesAJour / d.elevesTotal : 0,
          trend: '${d.tauxPaiement.toStringAsFixed(0)}%'),
      _KD(
          label: 'Élèves impayés',
          value: fmtInt(d.elevesImpayes),
          icon: Icons.warning_amber_rounded,
          color: kRed,
          trend: d.elevesImpayes > 0 ? 'À relancer' : 'Aucun',
          trendUp: d.elevesImpayes == 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Revenus encaissés par mois',
          subtitle: '${d.periodLabel} · paiements confirmés',
          points: d.revenueTrend,
          color: kGreen,
          icon: Icons.bar_chart_rounded,
          money: true,
        ),
        const SizedBox(height: 20),
        _RecoveryCard(data: d),
      ],
    );
  }
}

// ─── Carte taux de recouvrement ─────────────────────────────────────────────
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final taux = data.tauxPaiement;
    final color = _rateColor(taux);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: AdminSectionTitle('Taux de recouvrement',
                  icon: Icons.savings_rounded,
                  subtitle: 'Élèves ayant réglé au moins un paiement'),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text('${taux.toStringAsFixed(1)} %',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: (taux / 100).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _rateLegend('< 40%', kRed),
            const SizedBox(width: 14),
            _rateLegend('40 – 70%', kAccent),
            const SizedBox(width: 14),
            _rateLegend('≥ 70%', kGreen),
            const Spacer(),
            Text(
                '${fmtInt(data.elevesAJour)} à jour · ${fmtInt(data.elevesImpayes)} en attente',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ],
      ),
    );
  }

  Widget _rateLegend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · RESSOURCES HUMAINES
// ════════════════════════════════════════════════════════════════════════════
