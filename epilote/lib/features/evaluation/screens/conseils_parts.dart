part of 'conseils_screen.dart';

// ─── Corps : session + KPI + distribution + actions + liste ──────────────────
class _CouncilBody extends ConsumerWidget {
  const _CouncilBody({
    required this.args,
    required this.busy,
    required this.canEdit,
    required this.className,
    required this.trimesterLabel,
    required this.onGenerate,
    required this.onAutofill,
    required this.onStatus,
    required this.onSynthesis,
    required this.onDeliberate,
  });
  final CouncilArgs args;
  final bool busy, canEdit;
  final String? className, trimesterLabel;
  final VoidCallback onGenerate;
  final ValueChanged<List<CouncilEntry>> onAutofill;
  final ValueChanged<String> onStatus;
  final ValueChanged<String?> onSynthesis;
  final ValueChanged<CouncilEntry> onDeliberate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(councilSessionProvider(args));
    final school = ref.watch(currentSchoolProvider).valueOrNull;
    final year = ref.watch(activeYearProvider);
    return Container(
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.groups_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text(className ?? 'Classe',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
        ]),
        const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(child: Text(messageErreur(e)))),
          data: (s) {
        if (s.evaluationCount == 0) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: AdminEmptyState(
              icon: Icons.how_to_vote_outlined,
              title: 'Aucune note pour ce trimestre',
              message:
                  'Le conseil délibère à partir des bulletins, eux-mêmes '
                  'calculés depuis les notes. Saisissez d\'abord des notes '
                  '(page Notes) pour cette classe et ce trimestre.',
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Kpis(session: s),
          const SizedBox(height: 16),
          _Distribution(session: s),
          const SizedBox(height: 16),
          _ActionBar(
            session: s,
            busy: busy,
            canEdit: canEdit,
            onGenerate: onGenerate,
            onAutofill: () => onAutofill(s.entries),
            onStatus: onStatus,
            onSynthesis: () => onSynthesis(s.directorComment),
            onPv: () => showPdfPreviewDialog(
              context,
              title: 'Procès-verbal — Conseil de classe',
              subtitle: '${className ?? ''} · ${year?.label ?? ''}',
              pdfFileName:
                  'pv_conseil_${(className ?? 'classe').replaceAll(' ', '_')}.pdf',
              build: (_) => ConseilPdfService.buildPv(
                session: s,
                schoolName: school?['name'] as String?,
                className: className,
                trimesterLabel: trimesterLabel,
                yearLabel: year?.label,
              ),
            ),
          ),
          if ((s.directorComment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _SynthesisCard(text: s.directorComment!),
          ],
          const SizedBox(height: 18),
          if (!s.bulletinsReady)
            const _GeneratePrompt()
          else
            for (final e in s.entries)
              _StudentRow(entry: e, onTap: () => onDeliberate(e)),
        ]);
          },
        ),
      ]),
    );
  }
}

// ─── KPI ─────────────────────────────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  const _Kpis({required this.session});
  final CouncilSession session;
  @override
  Widget build(BuildContext context) {
    final positives = session.entries
        .where((e) => awardFor(e.award)?.positive == true)
        .length;
    final sanctions = session.entries
        .where((e) => awardFor(e.award)?.positive == false)
        .length;
    final cards = <(IconData, String, String, Color, String?)>[
      (
        Icons.functions_rounded,
        'Moyenne de classe',
        session.classAverage == null
            ? '—'
            : '${session.classAverage!.toStringAsFixed(2)}/20',
        kNavy,
        null
      ),
      (
        Icons.how_to_vote_rounded,
        'Élèves délibérés',
        '${session.deliberatedCount}/${session.generatedCount}',
        const Color(0xFF0EA5E9),
        session.bulletinsReady ? null : 'bulletins à générer'
      ),
      (
        Icons.workspace_premium_rounded,
        'Distinctions',
        '$positives',
        kGreen,
        'félicitations, encouragements…'
      ),
      (
        Icons.warning_amber_rounded,
        'Avertissements',
        '$sanctions',
        sanctions == 0 ? kTextMuted : const Color(0xFFF59E0B),
        'travail / conduite'
      ),
    ];
    return LayoutBuilder(builder: (ctx, cns) {
      final cols = cns.maxWidth >= 920 ? 4 : (cns.maxWidth >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final (ic, l, v, c, sub) = cards[i];
          return AdminStatCard(
              label: l, value: v, icon: ic, color: c, subtitle: sub);
        },
      );
    });
  }
}

// ─── Répartition des distinctions (barre empilée) ────────────────────────────
class _Distribution extends StatelessWidget {
  const _Distribution({required this.session});
  final CouncilSession session;
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in councilAwards) {
      counts[a.code] = session.entries.where((e) => e.award == a.code).length;
    }
    final pending = session.entries
        .where((e) => awardFor(e.award) == null)
        .length;
    final total = session.entries.length;
    final segments = <(String, int, Color)>[
      for (final a in councilAwards)
        if (counts[a.code]! > 0) (a.label, counts[a.code]!, a.color),
      if (pending > 0) ('À délibérer', pending, kNoAwardColor),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.donut_small_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Text('Répartition des distinctions',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              if (total == 0)
                Expanded(child: Container(height: 12, color: kSurface))
              else
                for (final (_, n, c) in segments)
                  Expanded(flex: n, child: Container(height: 12, color: c)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (label, n, c) in segments)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 6),
                Text('$label · $n',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
              ]),
          ],
        ),
      ]),
    );
  }
}

// ─── Passerelle vers le conseil de FIN D'ANNÉE ───────────────────────────────
//
// Le conseil de classe se tient chaque trimestre ; celui de fin d'année ne se
// tient qu'une fois et engage la scolarité de l'élève. La carte le dit avant
// d'y mener — un intitulé seul (« Passage en classe supérieure ») ne distingue
// pas une consultation d'une décision irréversible.
class _PassageGateway extends StatelessWidget {
  const _PassageGateway();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNavy.withValues(alpha: 0.28)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.moving_rounded, size: 20, color: kNavy),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conseil de fin d\'année',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const SizedBox(height: 3),
              Text(
                'Passage, redoublement et réinscription pour l\'année '
                'suivante. Se tient après le 3ᵉ trimestre, sur la moyenne '
                'annuelle des trois bulletins.',
                style: TextStyle(
                    fontSize: 12, height: 1.35, color: kTextMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: () => context.go(Routes.passage),
          style: FilledButton.styleFrom(backgroundColor: kNavy),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Ouvrir la délibération'),
        ),
      ]),
    );
  }
}
