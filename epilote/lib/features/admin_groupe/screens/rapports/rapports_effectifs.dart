part of '../admin_reports_screen.dart';

// Section Effectifs et parité.

class _EffectifsSection extends StatelessWidget {
  const _EffectifsSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.elevesTotal == 0) {
      return const AdminEmptyState(
        icon: Icons.groups_outlined,
        title: 'Aucun élève',
        message: 'Les effectifs apparaîtront ici dès la première inscription.',
      );
    }

    final kpis = [
      _KD(
          label: 'Élèves',
          value: fmtInt(d.elevesTotal),
          sub: 'effectif total',
          icon: Icons.groups_rounded,
          color: kGreen),
      _KD(
          label: 'Nouveaux (période)',
          value: '+${fmtInt(d.elevesNouveaux)}',
          sub: d.periodLabel,
          icon: Icons.person_add_alt_1_rounded,
          color: kNavy),
      _KD(
          label: 'Filles',
          value: fmtInt(d.studentsF),
          sub: '${d.pctFilles.toStringAsFixed(1)} %',
          icon: Icons.female_rounded,
          color: _kPink,
          progress: d.pctFilles / 100),
      _KD(
          label: 'Garçons',
          value: fmtInt(d.studentsM),
          sub: '${d.pctGarcons.toStringAsFixed(1)} %',
          icon: Icons.male_rounded,
          color: _kBlue,
          progress: d.pctGarcons / 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Inscriptions par mois',
          subtitle: '${d.periodLabel} · nouveaux élèves',
          points: d.enrollmentTrend,
          color: kGreen,
          icon: Icons.show_chart_rounded,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final parity = _ParityCard(data: d);
          final byDept = _DistributionBars(
            title: 'Élèves par département',
            subtitle: 'Répartition géographique',
            icon: Icons.map_rounded,
            data: d.studentsByDept,
            emptyMessage: 'Aucune donnée géographique.',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              parity,
              const SizedBox(height: 18),
              byDept,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: parity),
                const SizedBox(width: 18),
                Expanded(child: byDept),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Carte parité (filles / garçons) ────────────────────────────────────────
class _ParityCard extends StatelessWidget {
  const _ParityCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Parité',
              icon: Icons.wc_rounded, subtitle: 'Filles / garçons'),
          const SizedBox(height: 18),
          _ParityRow(
              label: 'Filles',
              count: d.studentsF,
              total: d.elevesTotal,
              color: _kPink),
          const SizedBox(height: 14),
          _ParityRow(
              label: 'Garçons',
              count: d.studentsM,
              total: d.elevesTotal,
              color: _kBlue),
          const SizedBox(height: 18),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.balance_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _parityComment(d.pctFilles),
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  String _parityComment(double pctF) {
    if (pctF == 0) return 'Aucune donnée de genre renseignée.';
    final gap = (pctF - 50).abs();
    if (gap <= 5) return 'Équilibre filles/garçons quasi parfait.';
    if (pctF > 50) return 'Majorité de filles (+${gap.toStringAsFixed(0)} pts).';
    return 'Majorité de garçons (+${gap.toStringAsFixed(0)} pts).';
  }
}

class _ParityRow extends StatelessWidget {
  const _ParityRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
          const Spacer(),
          Text('${fmtInt(count)}  ·  ${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        AdminProgressBar(
            value: count, max: total <= 0 ? 1 : total, height: 9, color: color),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · FINANCE
// ════════════════════════════════════════════════════════════════════════════
