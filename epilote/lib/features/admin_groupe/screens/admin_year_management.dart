part of 'admin_academic_years_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GESTION DES ANNÉES — section filtrable (Toutes/Actives/Archivées) + cartes.
// ════════════════════════════════════════════════════════════════════════════

/// Filtre actif de la section gestion : `all` | `active` | `archived`.
final _yearFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

class _ManagementSection extends ConsumerWidget {
  const _ManagementSection({required this.years});
  final List<AdminYear> years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_yearFilterProvider);
    final activeCount = years.where((y) => !y.isLocked).length;
    final archivedCount = years.where((y) => y.isLocked).length;

    final shown = switch (filter) {
      'active' => years.where((y) => !y.isLocked).toList(),
      'archived' => years.where((y) => y.isLocked).toList(),
      _ => years,
    }
      // courante d'abord, puis par date décroissante.
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.startDate.compareTo(a.startDate);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: AdminSectionTitle('Gestion & archivage des années',
                  icon: Icons.settings_suggest_rounded,
                  subtitle:
                      'Créer, basculer la rentrée, archiver — toutes les écoles '
                      'héritent par synchro.'),
            ),
            _SegFilter(
              current: filter,
              segments: [
                (key: 'all', label: 'Toutes', count: years.length),
                (key: 'active', label: 'Actives', count: activeCount),
                (key: 'archived', label: 'Archivées', count: archivedCount),
              ],
              onSelect: (k) =>
                  ref.read(_yearFilterProvider.notifier).state = k,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          AdminCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  filter == 'archived'
                      ? 'Aucune année archivée.'
                      : 'Aucune année dans ce filtre.',
                  style: const TextStyle(fontSize: 13, color: kTextMuted),
                ),
              ),
            ),
          )
        else
          ...shown.map((y) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _YearCard(year: y),
              )),
      ],
    );
  }
}

// ─── Segmented control (filtre) ────────────────────────────────────────────────
typedef _Seg = ({String key, String label, int count});

class _SegFilter extends StatelessWidget {
  const _SegFilter({
    required this.current,
    required this.segments,
    required this.onSelect,
  });
  final String current;
  final List<_Seg> segments;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((s) {
          final on = s.key == current;
          return GestureDetector(
            onTap: () => onSelect(s.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: on ? kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${s.label} (${s.count})',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : kTextMuted)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _YearCard extends ConsumerWidget {
  const _YearCard({required this.year});
  final AdminYear year;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() op,
    String success,
  ) async {
    try {
      await op();
      ref.invalidate(adminAcademicYearsProvider);
      ref.invalidate(adminYearAnalyticsProvider(year.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kGreen, content: Text(success)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = _status(year);
    final svc = ref.read(adminCalendarServiceProvider);
    final pct = year.schoolsTotal == 0
        ? 0.0
        : year.schoolsAdopted / year.schoolsTotal;

    return AdminCard(
      accent: year.isCurrent ? kGreen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(st.icon, size: 18, color: st.color),
              const SizedBox(width: 8),
              Text(year.label,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(width: 10),
              AdminBadge(st.label, color: st.color),
              const Spacer(),
              Text('${_fmtShort.format(year.startDate)} → '
                  '${_fmtShort.format(year.endDate)}',
                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(
                  icon: Icons.class_rounded,
                  value: '${year.classes}',
                  label: 'classes'),
              const SizedBox(width: 22),
              _Metric(
                  icon: Icons.people_rounded,
                  value: '${year.eleves}',
                  label: 'élèves'),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            size: 14, color: kTextMuted),
                        const SizedBox(width: 6),
                        Text(
                          '${year.schoolsAdopted}/${year.schoolsTotal} '
                          'écoles préparées',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kTextMuted),
                        ),
                        const Spacer(),
                        Text('${(pct * 100).round()} %',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: pct >= 1 ? kGreen : kNavy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AdminProgressBar(
                        value: year.schoolsAdopted,
                        max: year.schoolsTotal == 0 ? 1 : year.schoolsTotal,
                        color: pct >= 1 ? kGreen : kNavy),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdminYearCalendarDialog(
                      yearId: year.id, yearLabel: year.label),
                ),
                icon: const Icon(Icons.event_note_rounded, size: 17),
                label: const Text('Calendrier'),
                style: TextButton.styleFrom(foregroundColor: kNavy),
              ),
              const SizedBox(width: 4),
              if (!year.isCurrent && !year.isLocked)
                TextButton.icon(
                  onPressed: () => _run(context, ref,
                      () => svc.setCurrentYear(year.id),
                      'Année courante mise à jour'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                  label: const Text('Définir courante'),
                  style: TextButton.styleFrom(foregroundColor: kGreen),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _run(
                    context,
                    ref,
                    () => svc.setLocked(year.id, !year.isLocked),
                    year.isLocked ? 'Année déverrouillée' : 'Année archivée'),
                icon: Icon(
                    year.isLocked
                        ? Icons.lock_open_rounded
                        : Icons.archive_outlined,
                    size: 17),
                label: Text(year.isLocked ? 'Déverrouiller' : 'Archiver'),
                style: TextButton.styleFrom(
                    foregroundColor: year.isLocked ? kAccent : kTextMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kNavy),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      );
}
