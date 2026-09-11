part of '../admin_reports_screen.dart';

// Section Synthèse et faits marquants.

class _SyntheseSection extends StatelessWidget {
  const _SyntheseSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.insights_rounded,
        title: 'Aucune donnée à analyser',
        message:
            'Dès que vos écoles enregistreront élèves, personnel et paiements, '
            'les rapports se rempliront automatiquement.',
      );
    }

    final kpis = [
      _KD(
        label: 'Établissements',
        value: '${d.schoolsTotal}',
        sub: '${d.schoolsActives} actif(s) · ${d.coveredDepts} dépt.',
        icon: Icons.account_balance_rounded,
        color: kNavy,
        progress: d.schoolsTotal > 0 ? d.schoolsActives / d.schoolsTotal : 0,
        trend: '${d.schoolsActives}/${d.schoolsTotal}',
      ),
      _KD(
        label: 'Élèves',
        value: fmtInt(d.elevesTotal),
        sub: '${d.studentsF} F · ${d.studentsM} G',
        icon: Icons.groups_rounded,
        color: kGreen,
        trend: d.elevesNouveaux > 0 ? '+${d.elevesNouveaux} période' : 'Effectif',
        trendUp: true,
      ),
      _KD(
        label: 'Personnel',
        value: fmtInt(d.personnelTotal),
        sub: '${d.fonctionnaires} fonct. · ${d.nonFonctionnaires} contr.',
        icon: Icons.badge_rounded,
        color: kAccent,
        trend: d.personnelNouveau > 0
            ? '+${d.personnelNouveau} période'
            : 'Effectif actif',
      ),
      _KD(
        label: 'Classes',
        value: fmtInt(d.classesTotal),
        sub: 'salles actives',
        icon: Icons.class_rounded,
        color: _kPurple,
        trend: d.elevesTotal > 0 && d.classesTotal > 0
            ? '${(d.elevesTotal / d.classesTotal).round()} élèves/classe'
            : '—',
      ),
      _KD(
        label: 'Revenus (période)',
        value: _compactXaf(d.revenusTotal),
        sub: '${d.paiementsCount} paiement(s)',
        icon: Icons.trending_up_rounded,
        color: kGreen,
        trend: 'FCFA',
      ),
      _KD(
        label: 'Recouvrement',
        value: '${d.tauxPaiement.toStringAsFixed(0)}%',
        sub: '${d.elevesAJour}/${d.elevesTotal} à jour',
        icon: Icons.verified_rounded,
        color: _rateColor(d.tauxPaiement),
        progress: d.tauxPaiement / 100,
        trend: d.elevesImpayes > 0 ? '${d.elevesImpayes} impayés' : 'Complet',
        trendUp: d.elevesImpayes == 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final trend = _TrendChart(
            title: 'Évolution des inscriptions',
            subtitle: d.periodLabel,
            points: d.enrollmentTrend,
            color: kGreen,
            icon: Icons.show_chart_rounded,
          );
          final donut = _CategoryDonut(
            title: 'Types d\'établissement',
            subtitle: 'Public · Privé',
            icon: Icons.pie_chart_rounded,
            slices: [
              _Slice('Public', d.publicCount, _kBlue),
              _Slice('Privé', d.priveCount, kGreen),
            ],
            centerValue: fmtInt(d.schoolsTotal),
            centerLabel: 'écoles',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              trend,
              const SizedBox(height: 18),
              donut,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: trend),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: donut),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _HighlightsStrip(data: d),
      ],
    );
  }
}

// ─── Bandeau « faits marquants » ─────────────────────────────────────────────
class _HighlightsStrip extends StatelessWidget {
  const _HighlightsStrip({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Faits marquants de la période',
              icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 14),
          Wrap(spacing: 24, runSpacing: 14, children: [
            _Highlight(
                icon: Icons.person_add_alt_1_rounded,
                color: kGreen,
                value: '+${fmtInt(d.elevesNouveaux)}',
                label: 'nouveaux élèves'),
            _Highlight(
                icon: Icons.badge_rounded,
                color: kNavy,
                value: '+${fmtInt(d.personnelNouveau)}',
                label: 'recrutements'),
            _Highlight(
                icon: Icons.female_rounded,
                color: _kPink,
                value: '${d.pctFilles.toStringAsFixed(0)}%',
                label: 'de filles'),
            _Highlight(
                icon: Icons.supervisor_account_rounded,
                color: _kPurple,
                value: '1 : ${d.ratioEncadrement.toStringAsFixed(0)}',
                label: 'encadrement (agent/élèves)'),
            _Highlight(
                icon: Icons.account_balance_wallet_rounded,
                color: _kOrange,
                value: _compactXaf(d.revenuMoyenParEleve),
                label: 'revenu moyen / élève'),
            _Highlight(
                icon: Icons.workspace_premium_rounded,
                color: kAccent,
                value: '${d.tauxFonctionnaires.toStringAsFixed(0)}%',
                label: 'de fonctionnaires'),
          ]),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ],
        ),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · EFFECTIFS
// ════════════════════════════════════════════════════════════════════════════
