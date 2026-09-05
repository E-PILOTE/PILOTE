part of '../admin_dashboard_screen.dart';

// Centre de risques des écoles.

enum _RiskLevel { critique, eleve, modere }

class _SchoolRisk {
  _SchoolRisk(this.school, this.reasons, this.score);
  final SchoolSummary school;
  final List<String> reasons;
  final int score;
  _RiskLevel get level => score >= 6
      ? _RiskLevel.critique
      : (score >= 3 ? _RiskLevel.eleve : _RiskLevel.modere);
}

({Color color, String label}) _riskStyle(_RiskLevel l) => switch (l) {
      _RiskLevel.critique => (color: kRed, label: 'Critique'),
      _RiskLevel.eleve => (color: kAccent, label: 'Élevé'),
      _RiskLevel.modere => (color: _kBlue, label: 'Modéré'),
    };

/// Évalue le niveau de risque de chaque établissement à partir de données
/// réelles (activité, effectifs, personnel, classes, taux d'encadrement).
/// Sert la prise de décision : où intervenir en priorité.
List<_SchoolRisk> _assessRisks(AdminDashboardData d) {
  final out = <_SchoolRisk>[];
  for (final s in d.schools) {
    final reasons = <String>[];
    var score = 0;

    if (!s.isActive) {
      reasons.add('Établissement inactif — à réactiver ou archiver');
      out.add(_SchoolRisk(s, reasons, 5));
      continue;
    }
    if (s.students == 0) {
      reasons.add('Aucun élève inscrit');
      score += 4;
    } else {
      if (s.staff == 0) {
        reasons.add('Aucun personnel affecté');
        score += 4;
      }
      if (s.classes == 0) {
        reasons.add('Aucune classe configurée');
        score += 3;
      } else {
        final perClass = s.students / s.classes;
        if (perClass > 50) {
          reasons.add('Surcharge : ${perClass.round()} élèves/classe');
          score += 2;
        }
      }
      if (s.staff > 0) {
        final perStaff = s.students / s.staff;
        if (perStaff > 35) {
          reasons.add('Encadrement faible : ${perStaff.round()} élèves/agent');
          score += 2;
        }
      }
    }
    if (reasons.isNotEmpty) out.add(_SchoolRisk(s, reasons, score));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

class _RiskCenter extends StatelessWidget {
  const _RiskCenter({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final risks = _assessRisks(data);
    final crit = risks.where((r) => r.level == _RiskLevel.critique).length;
    final elev = risks.where((r) => r.level == _RiskLevel.eleve).length;
    final mod = risks.where((r) => r.level == _RiskLevel.modere).length;
    final sains = data.schools.length - risks.length;
    final shown = risks.take(6).toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Établissements à surveiller',
            icon: Icons.health_and_safety_rounded,
            subtitle: 'Indicateurs de risque · interventions prioritaires',
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminEcoles),
              child: Text('Gérer',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RiskStat(
                  label: 'Critiques',
                  count: crit,
                  color: kRed,
                  icon: Icons.error_rounded),
              _RiskStat(
                  label: 'Risque élevé',
                  count: elev,
                  color: kAccent,
                  icon: Icons.warning_amber_rounded),
              _RiskStat(
                  label: 'À surveiller',
                  count: mod,
                  color: _kBlue,
                  icon: Icons.visibility_rounded),
              _RiskStat(
                  label: 'Conformes',
                  count: sains < 0 ? 0 : sains,
                  color: kGreen,
                  icon: Icons.verified_rounded),
            ],
          ),
          const SizedBox(height: 16),
          if (data.schools.isEmpty)
            const _InlineEmpty(
                message:
                    'Aucun établissement enregistré — ajoutez vos écoles pour activer la surveillance du réseau.')
          else if (risks.isEmpty)
            const _AllClearRow()
          else ...[
            for (final r in shown)
              _RiskRow(risk: r, onTap: () => context.go(Routes.adminEcoles)),
            if (risks.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 2),
                child: Text(
                    '+ ${risks.length - shown.length} autre(s) établissement(s) à examiner',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }
}

class _RiskStat extends StatelessWidget {
  const _RiskStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final c = active ? color : kTextMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: active ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: active ? 0.20 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.risk, required this.onTap});
  final _SchoolRisk risk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = _riskStyle(risk.level);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                    color: st.color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(risk.school.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                        ),
                        const SizedBox(width: 8),
                        _RiskBadge(color: st.color, label: st.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final reason in risk.reasons)
                          _ReasonChip(text: reason, color: st.color),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.arrow_forward_ios,
                    size: 11, color: kTextMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2)),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.30))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AllClearRow extends StatelessWidget {
  const _AllClearRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, color: kGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réseau sain — aucun établissement à risque',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(
                    'Tous vos établissements actifs disposent d\'élèves, de personnel et de classes configurées.',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Établissements en tête + activité ──────────────────────────────────────
