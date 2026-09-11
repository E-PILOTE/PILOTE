part of '../admin_dashboard_screen.dart';

// Gouvernance : alertes et contrôles.

class _Governance extends StatelessWidget {
  const _Governance({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts(data);
    final checks = _compliance(data);

    final alertsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHead(icon: Icons.notifications_active_rounded, text: 'Alertes & interventions'),
        const SizedBox(height: 10),
        for (final a in alerts)
          _AlertRow(
            alert: a,
            onTap: a.route == null ? null : () => context.go(a.route!),
          ),
      ],
    );

    final actionsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHead(icon: Icons.task_alt_rounded, text: 'Actions recommandées'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QaChip(
                label: 'Gérer les écoles',
                icon: Icons.account_balance_rounded,
                onTap: () => context.go(Routes.adminEcoles)),
            _QaChip(
                label: 'Personnel',
                icon: Icons.people_alt_rounded,
                onTap: () => context.go(Routes.adminUtilisateurs)),
            _QaChip(
                label: 'Rapports',
                icon: Icons.assessment_rounded,
                onTap: () => context.go(Routes.adminRapports)),
          ],
        ),
        const SizedBox(height: 18),
        const _SubHead(icon: Icons.fact_check_rounded, text: 'Conformité'),
        const SizedBox(height: 10),
        for (final ch in checks) _CheckRow(check: ch),
      ],
    );

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle(
            'Centre de gouvernance',
            icon: Icons.shield_rounded,
            subtitle: 'Alertes, actions et indicateurs de conformité',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (ctx, c) {
              if (c.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    alertsBlock,
                    const SizedBox(height: 20),
                    actionsBlock,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: alertsBlock),
                  const SizedBox(width: 24),
                  Expanded(child: actionsBlock),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubHead extends StatelessWidget {
  const _SubHead({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kNavy),
        const SizedBox(width: 7),
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, this.onTap});
  final _Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: alert.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(alert.icon, size: 17, color: alert.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(alert.text,
                style: TextStyle(
                    fontSize: 12.5, color: kTextPrimary, height: 1.3)),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios,
                size: 11, color: alert.color.withValues(alpha: 0.7)),
        ],
      ),
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final c = check.ok ? kGreen : kTextMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
              check.ok
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: c),
          const SizedBox(width: 9),
          Expanded(
            child: Text(check.label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: check.ok ? kTextPrimary : kTextMuted)),
          ),
        ],
      ),
    );
  }
}

List<_Alert> _buildAlerts(AdminDashboardData d) {
  final out = <_Alert>[];
  if (d.expireBientot) {
    out.add(_Alert(Icons.event_busy_rounded, kRed,
        'Votre abonnement arrive à échéance prochainement.', Routes.adminAbonnement));
  }
  final inactive = d.ecolesTotal - d.ecolesActives;
  if (inactive > 0) {
    out.add(_Alert(Icons.domain_disabled_rounded, kAccent,
        '$inactive école(s) inactive(s) à réactiver ou archiver.', Routes.adminEcoles));
  }
  final emptySchools = d.schools.where((s) => s.students == 0).length;
  if (emptySchools > 0 && d.ecolesTotal > 0) {
    out.add(_Alert(Icons.person_off_rounded, kAccent,
        '$emptySchools école(s) sans élève inscrit.', Routes.adminEcoles));
  }
  if (d.ecolesTotal > 0 && d.classesTotal == 0) {
    out.add(const _Alert(Icons.meeting_room_outlined, _kBlue,
        'Aucune classe configurée dans le groupe.', Routes.adminEcoles));
  }
  if (d.elevesImpayes > 0) {
    out.add(_Alert(Icons.receipt_long_rounded, kAccent,
        '${d.elevesImpayes} élève(s) en situation d\'impayé.', Routes.adminRapports));
  }
  if (d.tauxOccupationEleves >= 90) {
    out.add(_Alert(Icons.warning_amber_rounded, kRed,
        "Quota d'élèves de votre plan presque atteint.", Routes.adminAbonnement));
  }
  if (out.isEmpty) {
    out.add(_Alert(Icons.verified_rounded, kGreen,
        'Aucune alerte — votre groupe est conforme.'));
  }
  return out;
}

List<_Check> _compliance(AdminDashboardData d) => [
      _Check('Écoles toutes actives',
          d.ecolesTotal > 0 && d.ecolesActives == d.ecolesTotal),
      _Check('Classes configurées', d.classesTotal > 0),
      _Check('Corps enseignant renseigné',
          d.enseignantsTotal > 0 || d.personnelTotal > 0),
      _Check('Suivi des paiements actif', d.paiementsMoisCount > 0),
      _Check('Départements couverts', d.coveredDepts > 0),
    ];

// ─── Centre de décision · établissements à risque ───────────────────────────
