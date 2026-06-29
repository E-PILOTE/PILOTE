part of 'bulletins_screen.dart';

// ─── Espace de travail d'une classe : calcul + KPI + actions + liste ─────────
class _BulletinBody extends ConsumerWidget {
  const _BulletinBody({
    required this.args,
    required this.className,
    required this.busy,
    required this.canGenerate,
    required this.canPublish,
    required this.onGenerate,
    required this.onStatus,
    required this.onOpen,
  });
  final BulletinArgs args;
  final String? className;
  final bool busy, canGenerate, canPublish;
  final ValueChanged<BulletinComputation> onGenerate;
  final ValueChanged<String> onStatus;
  final void Function(StudentBulletin, double?) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bulletinComputationProvider(args));
    return Container(
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.class_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text(className ?? 'Classe',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
        ]),
        const SizedBox(height: 14),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 30, bottom: 30),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(child: Text('Erreur : $e'))),
          data: (comp) {
            if (comp.evaluationCount == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: AdminEmptyState(
                  icon: Icons.grade_outlined,
                  title: 'Aucune note pour ce trimestre',
                  message:
                      'Saisissez d\'abord des évaluations et leurs notes (page '
                      'Notes) pour cette classe et ce trimestre.',
                ),
              );
            }
            final pass =
                comp.students.where((s) => (s.overallAverage ?? 0) >= 10).length;
            final withAvg =
                comp.students.where((s) => s.overallAverage != null).length;
            final published =
                comp.students.where((s) => s.status == 'published').length;
            final generated = comp.students.where((s) => s.persisted).length;

            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Kpis(
                    classAverage: comp.classAverage,
                    students: comp.students.length,
                    pass: pass,
                    withAvg: withAvg,
                  ),
                  const SizedBox(height: 16),
                  _ActionBar(
                    comp: comp,
                    busy: busy,
                    generated: generated,
                    published: published,
                    canGenerate: canGenerate,
                    canPublish: canPublish,
                    onGenerate: () => onGenerate(comp),
                    onStatus: onStatus,
                  ),
                  const SizedBox(height: 18),
                  for (final s in comp.students)
                    _StudentRow(s: s, onOpen: () => onOpen(s, comp.classAverage)),
                ]);
          },
        ),
      ]),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({
    required this.classAverage,
    required this.students,
    required this.pass,
    required this.withAvg,
  });
  final double? classAverage;
  final int students, pass, withAvg;
  @override
  Widget build(BuildContext context) {
    final rate = withAvg == 0 ? 0.0 : pass / withAvg * 100;
    final cards = <(IconData, String, String, Color, String?)>[
      (
        Icons.functions_rounded,
        'Moyenne de classe',
        classAverage == null ? '—' : '${classAverage!.toStringAsFixed(2)}/20',
        kNavy,
        null
      ),
      (Icons.groups_2_rounded, 'Élèves', '$students', const Color(0xFF0EA5E9),
          null),
      (
        Icons.trending_up_rounded,
        'Taux de réussite',
        '${rate.toStringAsFixed(0)}%',
        rate >= 50 ? kGreen : const Color(0xFFF59E0B),
        '≥ 10/20'
      ),
      (
        Icons.checklist_rounded,
        'Moyennes calculées',
        '$withAvg/$students',
        const Color(0xFF8B5CF6),
        null
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
          final (ic, l, v, c, s) = cards[i];
          return AdminStatCard(label: l, value: v, icon: ic, color: c, subtitle: s);
        },
      );
    });
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.comp,
    required this.busy,
    required this.generated,
    required this.published,
    required this.canGenerate,
    required this.canPublish,
    required this.onGenerate,
    required this.onStatus,
  });
  final BulletinComputation comp;
  final bool busy, canGenerate, canPublish;
  final int generated, published;
  final VoidCallback onGenerate;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final total = comp.students.length;
    final allPublished = published > 0 && published == generated && generated > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Icon(
            generated == 0
                ? Icons.pending_outlined
                : allPublished
                    ? Icons.verified_rounded
                    : Icons.edit_note_rounded,
            size: 18,
            color: generated == 0
                ? kTextMuted
                : allPublished
                    ? kGreen
                    : kAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              generated == 0
                  ? 'Bulletins non générés — calcul en aperçu'
                  : allPublished
                      ? 'Bulletins publiés ($published/$total) — visibles familles'
                      : 'Bulletins générés ($generated/$total) — brouillon',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ),
        if (busy)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else ...[
          if (canGenerate)
            OutlinedButton.icon(
              onPressed: onGenerate,
              style: OutlinedButton.styleFrom(
                  foregroundColor: kNavy,
                  side: BorderSide(color: kNavy.withValues(alpha: 0.4))),
              icon: const Icon(Icons.calculate_rounded, size: 16),
              label: Text(generated == 0 ? 'Générer' : 'Recalculer'),
            ),
          if (canPublish && generated > 0 && !allPublished) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => onStatus('published'),
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              icon: const Icon(Icons.publish_rounded, size: 16),
              label: const Text('Publier'),
            ),
          ],
          if (canPublish && allPublished) ...[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => onStatus('draft'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent.withValues(alpha: 0.4))),
              icon: const Icon(Icons.unpublished_outlined, size: 16),
              label: const Text('Dépublier'),
            ),
          ],
        ],
      ]),
    );
  }
}

// ─── Ligne élève (classée) ───────────────────────────────────────────────────
class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.s, required this.onOpen});
  final StudentBulletin s;
  final VoidCallback onOpen;

  Color _avgColor(double? a) => a == null
      ? kTextMuted
      : a >= 14
          ? kGreen
          : a >= 10
              ? const Color(0xFF0EA5E9)
              : const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(s.rank == 0 ? '—' : '${s.rank}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(
                        '${s.mention}${s.persisted ? ' · ${s.status == 'published' ? 'publié' : 'généré'}' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _avgColor(s.overallAverage).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                  s.overallAverage == null
                      ? '—'
                      : '${s.overallAverage!.toStringAsFixed(2)}/20',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _avgColor(s.overallAverage))),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ]),
        ),
      ),
    );
  }
}
