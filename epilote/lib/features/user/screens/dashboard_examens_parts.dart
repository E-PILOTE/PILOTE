part of 'user_dashboard_screen.dart';

// ─── Bloc EXAMENS & STAGES (direction / secrétariat) ──────────────────────────
// Deux modules CRUCIAUX pour l'espace école : les examens d'État engagent l'année
// de l'élève (un candidat non déposé perd une année), et les stages conditionnent
// la recevabilité du dossier de bac technique/pro. Ils méritent donc leur place
// sur le tableau de bord — la gouvernance vit sur les pages Examens/Stages, mais
// l'USAGE se lit ici (cf design-gouvernance-anti-redondance : usage = Dashboard).
//
// Gaté par la permission `examens` OU `stages` (accès = permissions) et rangé par
// la charge (poids des modules accordés). Les KPI sont ADDITIFS par capacité :
//   • base (lecture) — les compteurs + les ALERTES critiques (dossiers bloqués,
//     anomalies) qui ne sont JAMAIS masquées, même en lecture seule ;
//   • écriture (create/validate) — les tâches à faire (restent à inscrire,
//     attestations dues) qui n'ont de sens que pour qui peut agir.
class _ExamensBlock extends ConsumerWidget {
  const _ExamensBlock({required this.showExamens, required this.showStages});
  final bool showExamens, showStages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = showExamens
        ? ref.watch(examOverviewProvider).valueOrNull
        : null;
    final stages = showStages
        ? ref.watch(stagesOverviewProvider).valueOrNull
        : null;

    final perms = ref.watch(myPermissionsProvider).valueOrNull ?? const {};
    final examP = perms['examens'];
    final stageP = perms['stages'];
    // « Agir » = inscrire un candidat, déposer un dossier, délivrer une
    // attestation. On additionne les capacités d'écriture des deux modules.
    final canActExam =
        (examP?.canCreate ?? false) || (examP?.canValidate ?? false);
    final canActStage =
        (stageP?.canCreate ?? false) || (stageP?.canUpdate ?? false);

    final examClasses = exam?.examClasses.length ?? 0;
    final candidates = exam?.candidatesTotal ?? 0;
    final missing = exam?.missingTotal ?? 0;
    final anomalies = exam?.anomalies.length ?? 0;
    final internships = stages?.internships.length ?? 0;
    final attestations = stages?.attestations ?? 0;
    final overdue = stages?.overdue ?? 0;
    final blocked = stages?.blocked.length ?? 0;

    // ── KPI de base (visibles dès la lecture) ────────────────────────────────
    final cards = <Widget>[
      if (showExamens)
        AdminStatCard(
          label: 'Candidats aux examens',
          value: '$candidates',
          icon: Icons.workspace_premium_rounded,
          color: kNavy,
          onTap: () => context.push(Routes.examens),
        ),
      if (showExamens)
        AdminStatCard(
          label: "Classes d'examen",
          value: '$examClasses',
          icon: Icons.school_rounded,
          color: const Color(0xFF7C3AED),
          onTap: () => context.push(Routes.examens),
        ),
      if (showStages)
        AdminStatCard(
          label: 'Stages',
          value: '$internships',
          icon: Icons.work_history_rounded,
          color: const Color(0xFF0EA5E9),
          onTap: () => context.push(Routes.stages),
        ),
      if (showStages)
        AdminStatCard(
          label: 'Attestations délivrées',
          value: '$attestations',
          icon: Icons.verified_rounded,
          color: kGreen,
          onTap: () => context.push(Routes.stages),
        ),
    ];

    // ── ALERTES critiques : jamais masquées, même en lecture seule ───────────
    // Un dossier de bac bloqué faute d'attestation = une année perdue. C'est
    // l'information la plus coûteuse du réseau : elle s'affiche pour TOUS.
    if (showStages && blocked > 0) {
      cards.add(AdminStatCard(
        label: 'Dossiers bloqués',
        value: '$blocked',
        icon: Icons.block_rounded,
        color: kRed,
        onTap: () => context.push(Routes.stages),
      ));
    }
    if (showExamens && anomalies > 0) {
      cards.add(AdminStatCard(
        label: 'Classes à qualifier',
        value: '$anomalies',
        icon: Icons.help_center_rounded,
        color: kAccent,
        onTap: () => context.push(Routes.examens),
      ));
    }

    // ── Tâches à faire : réservées à qui peut AGIR ───────────────────────────
    if (showExamens && canActExam && missing > 0) {
      cards.add(AdminStatCard(
        label: 'Restent à inscrire',
        value: '$missing',
        icon: Icons.person_add_alt_1_rounded,
        color: kAccent,
        onTap: () => context.push(Routes.examens),
      ));
    }
    if (showStages && canActStage && overdue > 0) {
      cards.add(AdminStatCard(
        label: 'Attestations dues',
        value: '$overdue',
        icon: Icons.assignment_late_rounded,
        color: kAccent,
        onTap: () => context.push(Routes.stages),
      ));
    }

    // Route « Voir » : le module dominant (examens si présent, sinon stages).
    final seeRoute = showExamens ? Routes.examens : Routes.stages;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AdminSectionTitle('Examens & Stages',
          icon: Icons.workspace_premium_rounded,
          trailing: _dashSeeAll(context, seeRoute)),
      const SizedBox(height: 14),
      _StatGrid(cards),
      // Barre de couverture des inscriptions : combien de candidats déjà
      // inscrits sur l'effectif des classes d'examen. Le geste manquant saute
      // aux yeux avant la clôture.
      if (showExamens && exam != null && exam.studentsTotal > 0) ...[
        const SizedBox(height: 14),
        _ExamCoverageBar(
          inscrits: candidates,
          effectif: exam.studentsTotal,
        ),
      ],
      const SizedBox(height: 24),
    ]);
  }
}

// ─── Barre de couverture des inscriptions aux examens ─────────────────────────
// Relation partie/tout (candidats inscrits / élèves des classes d'examen), avec
// cible implicite 100 %. Même grammaire visuelle que la barre de recouvrement
// finance : un segment plein + le % en grand se lisent instantanément.
class _ExamCoverageBar extends StatelessWidget {
  const _ExamCoverageBar({required this.inscrits, required this.effectif});
  final int inscrits, effectif;

  @override
  Widget build(BuildContext context) {
    final pct = effectif > 0 ? (inscrits / effectif).clamp(0.0, 1.0) : 0.0;
    final pctLabel = (pct * 100).round();
    final reste = (effectif - inscrits).clamp(0, effectif);
    final done = pct >= 1.0;

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: _ChartTitle(
                'Couverture des inscriptions', Icons.how_to_reg_rounded),
          ),
          Text('$pctLabel%',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: done ? kGreen : kNavy)),
        ]),
        const SizedBox(height: 4),
        Text(
            done
                ? '$inscrits candidat(s) inscrit(s) — couverture complète'
                : '$inscrits inscrit(s) sur $effectif · $reste à inscrire',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final flexIn = (v * 1000).round();
              final flexReste = 1000 - flexIn;
              return SizedBox(
                height: 16,
                child: Row(children: [
                  if (flexIn > 0)
                    Expanded(
                        flex: flexIn,
                        child: ColoredBox(color: done ? kGreen : kNavy)),
                  if (flexReste > 0)
                    Expanded(
                        flex: flexReste,
                        child: ColoredBox(
                            color: kAccent.withValues(alpha: 0.45))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
