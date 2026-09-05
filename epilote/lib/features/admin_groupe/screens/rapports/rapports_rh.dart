part of '../admin_reports_screen.dart';

// Section Ressources humaines.

class _RhSection extends StatelessWidget {
  const _RhSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.personnelTotal == 0) {
      return const AdminEmptyState(
        icon: Icons.badge_outlined,
        title: 'Aucun personnel',
        message:
            'Les statuts d\'emploi s\'afficheront ici dès l\'enregistrement du personnel.',
      );
    }

    final kpis = [
      _KD(
          label: 'Personnel',
          value: fmtInt(d.personnelTotal),
          sub: 'agents actifs',
          icon: Icons.badge_rounded,
          color: kNavy),
      _KD(
          label: 'Recrutés (période)',
          value: '+${fmtInt(d.personnelNouveau)}',
          sub: d.periodLabel,
          icon: Icons.person_add_alt_1_rounded,
          color: kGreen),
      _KD(
          label: 'Fonctionnaires',
          value: fmtInt(d.fonctionnaires),
          sub: '${d.tauxFonctionnaires.toStringAsFixed(0)} % du personnel',
          icon: Icons.workspace_premium_rounded,
          color: kAccent,
          progress: d.tauxFonctionnaires / 100),
      _KD(
          label: 'Non fonctionnaires',
          value: fmtInt(d.nonFonctionnaires),
          sub: 'contractuels & vacataires',
          icon: Icons.handshake_rounded,
          color: _kPurple),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final donut = _CategoryDonut(
            title: 'Par type de contrat',
            subtitle: 'Statut d\'emploi',
            icon: Icons.pie_chart_rounded,
            slices: _contractSlices(d.staffByContract),
            centerValue: fmtInt(d.personnelTotal),
            centerLabel: 'agents',
          );
          final ratio = _DistributionBars(
            title: 'Personnel par établissement',
            subtitle: 'Effectif par école',
            icon: Icons.account_balance_rounded,
            data: {for (final s in d.schoolRows) s.name: s.staff},
            emptyMessage: 'Aucun personnel rattaché.',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              donut,
              const SizedBox(height: 18),
              ratio,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: donut),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: ratio),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Recrutements par mois',
          subtitle: '${d.periodLabel} · nouvelles embauches',
          points: d.hireTrend,
          color: kNavy,
          icon: Icons.show_chart_rounded,
        ),
      ],
    );
  }

  List<_Slice> _contractSlices(Map<String, int> raw) {
    const labels = {
      'permanent': 'Permanents',
      'contractuel': 'Contractuels',
      'vacataire': 'Vacataires',
      'stagiaire': 'Stagiaires',
    };
    final out = <_Slice>[];
    var i = 0;
    raw.forEach((k, v) {
      if (v <= 0) return;
      out.add(_Slice(labels[k] ?? k, v, _kPalette[i % _kPalette.length]));
      i++;
    });
    return out;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · ÉTABLISSEMENTS (tableau + drill-down)
// ════════════════════════════════════════════════════════════════════════════
