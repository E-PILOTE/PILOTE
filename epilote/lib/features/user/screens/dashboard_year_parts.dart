part of 'user_dashboard_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Sous-widgets du tableau de bord (part of user_dashboard_screen.dart).
// ════════════════════════════════════════════════════════════════════════════

// ─── Carte année académique ───────────────────────────────────────────────────
class _AcademicYearCard extends StatelessWidget {
  const _AcademicYearCard({required this.year, required this.syncState});
  final dynamic year;
  final SyncUiState syncState;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'fr_FR');
    final start = fmt.format(year.startDate as DateTime);
    final end = fmt.format(year.endDate as DateTime);

    // État de synchro offline-first : rattaché à la fraîcheur des données de
    // l'année (déplacé ici depuis la card d'en-tête pour éviter le doublon).
    final (dotColor, label) = switch (syncState) {
      SyncUiState.synced => (kGreen, 'À jour'),
      SyncUiState.syncing => (const Color(0xFF0EA5E9), 'Synchronisation…'),
      SyncUiState.offline => (kAccent, 'Hors ligne'),
    };

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
        if (year.isLocked as bool) ...[
          const Tooltip(
            message: 'Année archivée',
            child: Icon(Icons.lock_rounded, size: 16, color: kTextMuted),
          ),
          const SizedBox(width: 10),
        ],
        _SyncPill(dotColor: dotColor, label: label),
      ]),
    );
  }
}

// Puce d'état de synchro — variante claire (posée sur fond clair, ≠ bannière).
class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.dotColor, required this.label});
  final Color dotColor;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dotColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color: Color.lerp(dotColor, Colors.black, 0.35),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );
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
