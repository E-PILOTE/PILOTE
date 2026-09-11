part of '../admin_dashboard_screen.dart';

// Section ressources humaines.

class _RhSection extends StatelessWidget {
  const _RhSection({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.personnelTotal;
    final fonc  = data.fonctionnaires;
    final non   = data.nonFonctionnaires;
    final tauxF = data.tauxFonctionnaires;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            "Ressources humaines · statut d'emploi",
            icon: Icons.badge_rounded,
            subtitle: "Fonctionnaires de l'État vs personnel non fonctionnaire",
            trailing: total == 0
                ? null
                : _PillChip(
                    label: '$total agents',
                    color: kNavy,
                    icon: Icons.groups_rounded,
                  ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const _ChartEmpty(
              message:
                  "Aucune donnée de personnel pour le moment.\nLes statuts d'emploi s'afficheront ici dès l'enregistrement du personnel.",
            )
          else
            LayoutBuilder(
              builder: (ctx, c) {
                final headline =
                    _RhHeadline(fonc: fonc, non: non, total: total, tauxF: tauxF);
                final breakdown = _RhBreakdown(data: data);
                if (c.maxWidth < 740) {
                  return Column(
                    children: [
                      headline,
                      const SizedBox(height: 20),
                      breakdown,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: headline),
                    const SizedBox(width: 26),
                    Expanded(flex: 4, child: breakdown),
                  ],
                );
              },
            ),
          if (total > 0) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: kBorder),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _MiniStat(emoji: '👨‍🏫', value: '${data.enseignantsTotal} enseignants'),
                _MiniStat(emoji: '🗂️', value: '${data.personnelAdministratif} administratifs'),
                _MiniStat(emoji: '🏢', value: '${data.coveredDepts} départements'),
                _MiniStat(emoji: '🏫', value: '${data.ecolesActives} écoles actives'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RhHeadline extends StatelessWidget {
  const _RhHeadline({
    required this.fonc,
    required this.non,
    required this.total,
    required this.tauxF,
  });
  final int fonc, non, total;
  final double tauxF;

  @override
  Widget build(BuildContext context) {
    final tauxN = 100 - tauxF;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RhTile(
                label: "Fonctionnaires de l'État",
                hint: 'Agents titulaires (permanents)',
                value: fonc,
                pct: tauxF,
                color: kNavy,
                icon: Icons.account_balance_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RhTile(
                label: 'Non fonctionnaires',
                hint: 'Contractuels · vacataires · stagiaires',
                value: non,
                pct: tauxN,
                color: _kTeal,
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: fonc <= 0 ? 0 : fonc,
                child: Container(height: 12, color: kNavy),
              ),
              Expanded(
                flex: non <= 0 ? 0 : non,
                child: Container(height: 12, color: _kTeal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _LegendDot(color: kNavy, text: 'Fonctionnaires ${tauxF.toStringAsFixed(0)} %'),
            const SizedBox(width: 16),
            _LegendDot(color: _kTeal, text: 'Non fonct. ${tauxN.toStringAsFixed(0)} %'),
          ],
        ),
      ],
    );
  }
}

class _RhTile extends StatelessWidget {
  const _RhTile({
    required this.label,
    required this.hint,
    required this.value,
    required this.pct,
    required this.color,
    required this.icon,
  });
  final String label, hint;
  final int value;
  final double pct;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text('${pct.toStringAsFixed(0)} %',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(fmtInt(value),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  height: 1)),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      ),
    );
  }
}

class _RhBreakdown extends StatelessWidget {
  const _RhBreakdown({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.personnelTotal;
    const order = ['permanent', 'contractuel', 'vacataire', 'stagiaire'];
    final rows = <(String, int)>[
      for (final k in order)
        if ((data.staffByContract[k] ?? 0) > 0) (k, data.staffByContract[k]!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Détail par type de contrat',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 14),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LegendDot(color: _contractColor(k), text: _contractLabel(k)),
                    const Spacer(),
                    Text('$v',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                    const SizedBox(width: 6),
                    Text('· ${total == 0 ? 0 : (v / total * 100).round()} %',
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
                const SizedBox(height: 7),
                AdminProgressBar(
                    value: v, max: total, color: _contractColor(k), height: 7),
              ],
            ),
          ),
      ],
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

String _contractLabel(String c) => switch (c) {
      'permanent' => 'Titulaires (permanents)',
      'contractuel' => 'Contractuels',
      'vacataire' => 'Vacataires',
      'stagiaire' => 'Stagiaires',
      _ => c,
    };

Color _contractColor(String c) => switch (c) {
      'permanent' => kNavy,
      'contractuel' => _kBlue,
      'vacataire' => _kOrange,
      'stagiaire' => _kPink,
      _ => kTextMuted,
    };

// ─── Couverture territoriale ────────────────────────────────────────────────
