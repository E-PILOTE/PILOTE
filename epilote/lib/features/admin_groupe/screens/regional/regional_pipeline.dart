part of '../admin_regional_view.dart';

// ─── Pipeline d'expansion (projets de création d'école) ──────────────────────
// Métier UNIQUE à la carte (ni la page Écoles ni le Dashboard ne le couvrent) :
// suivre les projets de création — étude → validation → budgétisation →
// construction → achevé. C'est le cœur du « pilote » territorial.
const List<String> _kPipelineOrder = [
  'etude', 'validation', 'budgetisation', 'construction', 'acheve',
];

class _PipelinePanel extends ConsumerWidget {
  const _PipelinePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminProjectsProvider);
    final selectedId = ref.watch(_selectionProv).projectOrNull?.id;

    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kNavy))),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (projects) {
        final active =
            projects.where((p) => p.status != 'acheve').length;
        final done = projects.where((p) => p.status == 'acheve').length;
        final budget = projects.fold<int>(0, (s, p) => s + (p.budgetXaf ?? 0));
        final fmt = NumberFormat.decimalPattern('fr');

        final items = <Widget>[
          // En-tête section
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(children: [
              const Icon(Icons.rocket_launch_rounded, size: 12, color: _kOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text("PIPELINE D'EXPANSION",
                    style: TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: kTextMuted, letterSpacing: 0.8)),
              ),
              if (active > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$active actifs',
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _kOrange)),
                ),
            ]),
          ),
        ];

        if (projects.isEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            child: Row(children: [
              Icon(Icons.add_location_alt_outlined,
                  size: 15, color: kTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Aucun projet. Bouton + sur la carte pour en placer un.',
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              ),
            ]),
          ));
          return Column(mainAxisSize: MainAxisSize.min, children: items);
        }

        // Bandeau récap budget / achevés
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(children: [
            Expanded(
              child: _PipelineStat(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Budget cumulé',
                  value: budget > 0 ? '${fmt.format(budget)} F' : '—',
                  color: _kOrange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PipelineStat(
                  icon: Icons.check_circle_rounded,
                  label: 'Achevés',
                  value: '$done',
                  color: kGreen),
            ),
          ]),
        ));

        // Groupes par statut (ordre du pipeline)
        for (final status in _kPipelineOrder) {
          final inStatus =
              projects.where((p) => p.status == status).toList();
          if (inStatus.isEmpty) continue;
          final color = _projectStatusColor(status);
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
            child: Row(children: [
              Icon(_projectStatusIcon(status), size: 12, color: color),
              const SizedBox(width: 6),
              Text(_projectStatusLabel(status).toUpperCase(),
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: color, letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Text('${inStatus.length}',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: kTextMuted)),
            ]),
          ));
          for (final p in inStatus) {
            final isSel = selectedId == p.id;
            items.add(InkWell(
              onTap: () => ref.read(_selectionProv.notifier).state =
                  isSel ? const SelectionNone() : SelectionProject(p),
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 6, 14, 6),
                color: isSel
                    ? color.withValues(alpha: 0.07)
                    : Colors.transparent,
                child: Row(children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                              [if (p.city != null) p.city!,
                                if (p.department != null) p.department!]
                                  .join(' · '),
                              style: TextStyle(
                                  fontSize: 9, color: kTextMuted),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                  if (p.priority == 'haute')
                    Icon(Icons.priority_high_rounded,
                        size: 13, color: kRed),
                ]),
              ),
            ));
          }
        }

        return Column(mainAxisSize: MainAxisSize.min, children: items);
      },
    );
  }
}

class _PipelineStat extends StatelessWidget {
  const _PipelineStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.18))),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 8.5, color: kTextMuted)),
                ]),
          ),
        ]),
      );
}

