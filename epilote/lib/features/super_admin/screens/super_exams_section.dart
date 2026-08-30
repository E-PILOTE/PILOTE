import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/super_exams_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ADOPTION EXAMENS & STAGES — carte du tableau de bord super_admin.
//
//  Cadrage PLATEFORME : combien de groupes exploitent le module d'examens
//  d'État, combien de candidats et de dépôts DEC transitent par l'outil. C'est
//  un indicateur d'adoption d'une fonctionnalité stratégique (le seul système
//  national de gestion des examens d'État), pas un pilotage de réseau. La carte
//  s'efface si aucun groupe ne s'en sert.
// ════════════════════════════════════════════════════════════════════════════
class SuperExamsSection extends ConsumerWidget {
  const SuperExamsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(superExamsProvider).valueOrNull;
    if (d == null || !d.used) return const SizedBox.shrink();

    final rate = d.totalCandidates == 0
        ? 0
        : (d.totalComplete / d.totalCandidates * 100).round();

    final cards = <Widget>[
      AdminStatCard(
        label: 'Groupes utilisateurs',
        value: '${d.groupsUsing}',
        subtitle: 'exploitent le module Examens',
        icon: Icons.hub_rounded,
        color: kNavy,
      ),
      AdminStatCard(
        label: "Candidats d'État gérés",
        value: '${d.totalCandidates}',
        subtitle: '${d.schoolsWithCandidates} école(s) · '
            '${d.sessionCount} session(s)',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF3B82F6),
      ),
      AdminStatCard(
        label: 'Dossiers complets',
        value: '$rate%',
        subtitle: '${d.totalComplete}/${d.totalCandidates}',
        icon: Icons.fact_check_rounded,
        color: kGreen,
      ),
      AdminStatCard(
        label: 'Transmissions DEC',
        value: '${d.transmissionCount}',
        subtitle: 'dépôts opposables',
        icon: Icons.outbox_rounded,
        color: const Color(0xFF14B8A6),
      ),
      AdminStatCard(
        label: 'Stages gérés',
        value: '${d.internshipsTotal}',
        subtitle: '${d.attestationsTotal} attestation(s)',
        icon: Icons.work_history_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      AdminStatCard(
        label: 'Bacs bloqués',
        value: '${d.bacBlocked}',
        subtitle: 'stage manquant',
        icon: Icons.block_rounded,
        color: d.bacBlocked > 0 ? kRed : kTextMuted,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle(
            "Examens d'État & Stages — adoption",
            icon: Icons.workspace_premium_rounded,
            subtitle: 'Usage du module à l\'échelle de la plateforme',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (ctx, c) {
            final cross = c.maxWidth > 900 ? 6 : (c.maxWidth > 600 ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 176,
              ),
              itemCount: cards.length,
              itemBuilder: (_, i) => cards[i],
            );
          }),
          if (d.byExam.isNotEmpty) ...[
            const SizedBox(height: 20),
            _ExamBars(bars: d.byExam),
          ],
        ]),
      ),
    );
  }
}

// ─── Candidats par examen (barres horizontales) ───────────────────────────────
class _ExamBars extends StatelessWidget {
  const _ExamBars({required this.bars});
  final List<PlatformExamBar> bars;

  @override
  Widget build(BuildContext context) {
    final maxV = bars.fold<int>(0, (m, b) => b.candidates > m ? b.candidates : m);
    if (maxV == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Candidats par examen · toutes écoles',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(height: 12),
      for (final b in bars)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            SizedBox(
              width: 74,
              child: Text(b.examShortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: b.candidates / maxV),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, v, _) => Stack(children: [
                    Container(
                        height: 12,
                        color: couleurTutelle(b.tutelle).withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: couleurTutelle(b.tutelle),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text('${b.candidates}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: couleurTutelle(b.tutelle))),
            ),
          ]),
        ),
    ]);
  }
}
