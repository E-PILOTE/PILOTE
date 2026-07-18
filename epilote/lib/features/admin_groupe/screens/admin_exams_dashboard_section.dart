import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_exams_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SECTION EXAMENS & STAGES DU RÉSEAU — sur le tableau de bord du ministère.
//
//  Le cockpit complet vit sur /admin/examens ; ICI on ne montre que le pouls :
//  couverture réseau, dépôts à la DEC, écoles à risque, dossiers de bac bloqués.
//  Ce sont les chiffres qu'un ministre demande en premier, donc ils remontent
//  sur l'écran d'accueil. La section s'efface entièrement pour un groupe qui
//  n'utilise pas le module (aucun candidat, aucune session, aucun stage) : pas
//  de carte vide sur les dashboards des autres groupes scolaires.
// ════════════════════════════════════════════════════════════════════════════
class AdminExamsDashboardSection extends ConsumerWidget {
  const AdminExamsDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminExamsProvider);
    final d = async.valueOrNull;

    // Rien tant qu'on n'a pas de valeur (le reste du dashboard porte déjà le
    // chargement) ; rien non plus si le groupe n'exploite pas le module.
    if (d == null) return const SizedBox.shrink();
    final used = d.totalCandidates > 0 ||
        d.sessionCount > 0 ||
        d.internshipsTotal > 0;
    if (!used) return const SizedBox.shrink();

    final rate = d.totalCandidates == 0
        ? 0
        : (d.totalComplete / d.totalCandidates * 100).round();

    final cards = <Widget>[
      AdminStatCard(
        label: 'Candidats aux examens',
        value: '${d.totalCandidates}',
        subtitle: '${d.schoolsWithCandidates} école(s) · '
            '${d.sessionCount} session(s)',
        icon: Icons.workspace_premium_rounded,
        color: kNavy,
        onTap: () => context.go(Routes.adminExamens),
      ),
      AdminStatCard(
        label: 'Dossiers complets',
        value: '$rate%',
        subtitle: '${d.totalComplete}/${d.totalCandidates} candidats',
        icon: Icons.fact_check_rounded,
        color: kGreen,
        onTap: () => context.go(Routes.adminExamens),
      ),
      AdminStatCard(
        label: 'Transmissions DEC',
        value: '${d.transmissionCount}',
        subtitle: '${d.transmissionsAcknowledged} accusé(s) de réception',
        icon: Icons.outbox_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: () => context.go(Routes.adminExamens),
      ),
      AdminStatCard(
        label: 'Écoles à risque',
        value: '${d.schoolsAtRisk}',
        subtitle: 'candidats, rien de transmis',
        icon: Icons.warning_amber_rounded,
        color: d.schoolsAtRisk > 0 ? kRed : kTextMuted,
        onTap: () => context.go(Routes.adminExamens),
      ),
      AdminStatCard(
        label: 'Stages du réseau',
        value: '${d.internshipsTotal}',
        subtitle: '${d.attestationsTotal} attestation(s) délivrée(s)',
        icon: Icons.work_history_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => context.go(Routes.adminExamens),
      ),
      AdminStatCard(
        label: 'Bacs bloqués',
        value: '${d.bacBlocked}',
        subtitle: 'stage manquant · dossier irrecevable',
        icon: Icons.block_rounded,
        color: d.bacBlocked > 0 ? kRed : kTextMuted,
        onTap: () => context.go(Routes.adminExamens),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(
          'Examens nationaux & Stages',
          icon: Icons.workspace_premium_rounded,
          subtitle: d.yearLabel == null
              ? 'Pilotage du réseau'
              : 'Session ${d.yearLabel}',
          trailing: TextButton.icon(
            onPressed: () => context.go(Routes.adminExamens),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Cockpit'),
            style: TextButton.styleFrom(foregroundColor: kNavy),
          ),
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
  final List<MinistryExamBar> bars;

  @override
  Widget build(BuildContext context) {
    final maxV = bars.fold<int>(0, (m, b) => b.candidates > m ? b.candidates : m);
    if (maxV == 0) return const SizedBox.shrink();
    // MEPSA (général) vs METP (technique/pro) : la tutelle colore la barre.
    Color tutColor(String? t) =>
        (t ?? '').toUpperCase().contains('METP') ? const Color(0xFF7C3AED) : kNavy;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Candidats par examen',
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
                        color: tutColor(b.tutelle).withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: tutColor(b.tutelle),
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
                      color: tutColor(b.tutelle))),
            ),
          ]),
        ),
    ]);
  }
}
