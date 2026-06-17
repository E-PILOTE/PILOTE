part of 'user_dashboard_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Sous-widgets du tableau de bord (part of user_dashboard_screen.dart).
// ════════════════════════════════════════════════════════════════════════════

// ─── Carte année académique ───────────────────────────────────────────────────
class _AcademicYearCard extends StatelessWidget {
  const _AcademicYearCard({required this.year});
  final dynamic year;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'fr_FR');
    final start = fmt.format(year.startDate as DateTime);
    final end = fmt.format(year.endDate as DateTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.08),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.school_rounded, size: 20, color: kGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Année scolaire active · ${year.label}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669))),
            Text('$start — $end',
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        if (year.isLocked as bool)
          const Tooltip(
            message: 'Année archivée',
            child: Icon(Icons.lock_rounded, size: 16, color: kTextMuted),
          ),
      ]),
    );
  }
}

// ─── Bandeau calendrier (trimestres) ──────────────────────────────────────────
class _CalendarStrip extends ConsumerWidget {
  const _CalendarStrip({required this.yearId});
  final String yearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trims = ref.watch(trimestersProvider(yearId)).valueOrNull ?? const [];
    if (trims.isEmpty) return const SizedBox.shrink();

    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.event_note_rounded, size: 18, color: kNavy),
        const SizedBox(width: 10),
        const Text('Calendrier',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in trims)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.isCurrent ? kGreen.withValues(alpha: 0.12) : kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: t.isCurrent
                          ? kGreen.withValues(alpha: 0.4)
                          : kBorder),
                ),
                child: Text(t.label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: t.isCurrent ? kGreen : kTextMuted)),
              ),
          ]),
        ),
      ]),
    );
  }
}
