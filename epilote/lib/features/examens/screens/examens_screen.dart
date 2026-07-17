import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/examens_provider.dart';
import '../widgets/examens_widgets.dart';

const _kSlug = 'examens';

// ════════════════════════════════════════════════════════════════════════════
//  EXAMENS D'ÉTAT — espace école, offline-first.
//
//  Lecture de haut en bas : sessions ouvertes (ce qui presse) → KPI → classes
//  d'examen groupées par diplôme → anomalies à qualifier.
//
//  Les classes de PASSAGE ne sont pas affichées : ce sont 32 classes sur 44 dans
//  le parc réel, sans aucun enjeu d'examen. Les lister noierait le signal.
// ════════════════════════════════════════════════════════════════════════════
class ExamensScreen extends ConsumerWidget {
  const ExamensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Examens',
        child: _Body(),
      );
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examOverviewProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ExamErrorCard(message: '$e'),
      data: (o) {
        if (o.examClasses.isEmpty && o.anomalies.isEmpty) {
          return const ExamEmptyState();
        }

        final byExam = <String, List<ExamClassRow>>{};
        for (final c in o.examClasses) {
          byExam.putIfAbsent(c.examCode ?? '—', () => []).add(c);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Sessions : l'information périssable d'abord ────────────────
            for (final s in o.relevantSessions) ...[
              ExamSessionBanner(
                session: s,
                // Le bandeau mène à la page qui PRODUIT : candidats, couverture
                // par cycle/niveau/classe, liste officielle en PDF, export CSV.
                onTap: () => context.go(
                    Routes.examenSession.replaceFirst(':id', s.id)),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 4),
            _Kpis(overview: o),
            const SizedBox(height: 24),

            // ── Anomalies : avant les classes, car elles appellent une action ─
            if (o.anomalies.isNotEmpty) ...[
              ExamAnomalyCard(rows: o.anomalies),
              const SizedBox(height: 24),
            ],

            if (o.examClasses.isNotEmpty) ...[
              ExamSectionLabel(
                'Classes d\'examen',
                trailing: '${o.examClasses.length} classe(s)',
              ),
              const SizedBox(height: 12),
              for (final entry in byExam.entries) ...[
                ExamGroupCard(
                  examCode: entry.key,
                  examName: entry.value.first.examName ?? entry.key,
                  rows: entry.value,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.overview});
  final ExamOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final cards = <(IconData, String, String, Color, String?)>[
      (
        Icons.workspace_premium_rounded,
        'Classes d\'examen',
        '${o.examClasses.length}',
        kNavy,
        o.anomalies.isEmpty ? null : '${o.anomalies.length} à qualifier',
      ),
      (
        Icons.groups_rounded,
        'Élèves concernés',
        '${o.studentsTotal}',
        kGreen,
        'en classe terminale',
      ),
      (
        Icons.how_to_reg_rounded,
        'Candidats inscrits',
        '${o.candidatesTotal}',
        o.candidatesTotal == 0 ? kTextMuted : kAccent,
        'sur ${o.studentsTotal} élève(s)',
      ),
      (
        Icons.pending_actions_rounded,
        'Restent à inscrire',
        '${o.missingTotal}',
        o.missingTotal == 0 ? kGreen : kRed,
        o.missingTotal == 0 ? 'tout le monde est inscrit' : 'élève(s) sans candidature',
      ),
    ];

    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176, // jamais childAspectRatio (convention projet)
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final (icon, label, value, color, sub) = cards[i];
          return AdminStatCard(
            label: label,
            value: value,
            icon: icon,
            color: color,
            subtitle: sub,
          );
        },
      );
    });
  }
}
