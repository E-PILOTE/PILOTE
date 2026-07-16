part of 'school_calendar_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Détail d'une année (CÔTÉ ÉCOLE) — lecture seule.
//  Le calendrier (trimestres / séquences) est défini par le GROUPE
//  (admin_groupe) puis hérité. La direction le consulte ici.
// ════════════════════════════════════════════════════════════════════════════

/// Palette des trimestres (T1/T2/T3/…).
List<Color> get _kTrimColors => [kNavy, kGreen, const Color(0xFF0EA5E9), const Color(0xFF7C3AED)];

class _YearDetail extends ConsumerWidget {
  const _YearDetail({required this.year});
  final AcademicYearModel year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimAsync = ref.watch(trimestersProvider(year.id));
    final counts = ref.watch(yearContentCountProvider(year.id)).valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: kCardBg,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(year.label,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(width: 10),
            if (year.isCurrent) _Tag(text: 'Courante', color: kGreen),
            if (year.isLocked) ...[
              const SizedBox(width: 6),
              _Tag(text: 'Archivée', color: kAccent),
            ],
            const Spacer(),
            _CountChip(icon: Icons.class_rounded, value: counts?.classes, label: 'classes'),
            const SizedBox(width: 8),
            _CountChip(icon: Icons.people_rounded, value: counts?.eleves, label: 'élèves'),
          ]),
          const SizedBox(height: 4),
          Text('${_fmtDate.format(year.startDate)} → ${_fmtDate.format(year.endDate)}',
              style: TextStyle(fontSize: 13, color: kTextMuted)),
          const SizedBox(height: 12),
          _YearProgress(year: year),
        ]),
      ),
      Divider(height: 1, color: kBorder),
      Expanded(
        child: trimAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: kNavy)),
          error: (e, _) =>
              Center(child: Text('Erreur : $e', style: TextStyle(color: kRed))),
          data: (trims) {
            if (trims.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: AdminEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'Calendrier non défini',
                    message:
                        'Les trimestres et séquences de cette année seront '
                        'définis par le groupe puis hérités par votre école.',
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _YearTimeline(year: year, trims: trims),
                const SizedBox(height: 18),
                const AdminSectionTitle('Trimestres & séquences',
                    icon: Icons.view_timeline_rounded),
                const SizedBox(height: 12),
                ...trims.map((t) => _TrimesterCard(trimester: t)),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

// ─── Barre de progression de l'année ──────────────────────────────────────────
class _YearProgress extends StatelessWidget {
  const _YearProgress({required this.year});
  final AcademicYearModel year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = year.endDate.difference(year.startDate).inDays;
    final elapsed = now.difference(year.startDate).inDays;
    final pct = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;

    final (label, color) = year.isLocked || now.isAfter(year.endDate)
        ? ('Année terminée', kTextMuted)
        : now.isBefore(year.startDate)
            ? ('Débute dans ${year.startDate.difference(now).inDays} jours', kAccent)
            : ('${(pct * 100).round()}% écoulé · ${year.endDate.difference(now).inDays} jours restants',
                kGreen);
    final shown = year.isLocked || now.isAfter(year.endDate) ? 1.0 : pct;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: shown,
          minHeight: 8,
          backgroundColor: kBorder,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.schedule_rounded, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    ]);
  }
}

// ─── Timeline visuelle proportionnelle des trimestres ─────────────────────────
class _YearTimeline extends StatelessWidget {
  const _YearTimeline({required this.year, required this.trims});
  final AcademicYearModel year;
  final List<TrimesterModel> trims;

  @override
  Widget build(BuildContext context) {
    final total = year.endDate.difference(year.startDate).inDays.toDouble();
    if (total <= 0) return const SizedBox.shrink();
    final now = DateTime.now();
    final todayFrac =
        (now.difference(year.startDate).inDays / total).clamp(0.0, 1.0);
    final showToday = now.isAfter(year.startDate) && now.isBefore(year.endDate);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timeline_rounded, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Text("Déroulé de l'année",
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 58,
            child: Stack(clipBehavior: Clip.none, children: [
              // Piste de fond
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                height: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              // Segments trimestres
              for (var i = 0; i < trims.length; i++)
                ..._segment(trims[i], i, w, total),
              // Marqueur aujourd'hui
              if (showToday) ...[
                Positioned(
                  left: (todayFrac * w - 1).clamp(0.0, w - 2),
                  top: 8,
                  height: 46,
                  child: Container(width: 2, color: kRed),
                ),
                Positioned(
                  left: (todayFrac * w - 16).clamp(0.0, w - 34),
                  top: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: kRed, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Auj.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
          );
        }),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (var i = 0; i < trims.length; i++)
            _LegendDot(
                color: _kTrimColors[i % _kTrimColors.length],
                label: trims[i].label,
                current: trims[i].isCurrent),
        ]),
      ]),
    );
  }

  List<Widget> _segment(
      TrimesterModel t, int i, double w, double total) {
    final leftFrac =
        (t.startDate.difference(year.startDate).inDays / total).clamp(0.0, 1.0);
    final widthFrac =
        (t.endDate.difference(t.startDate).inDays / total).clamp(0.0, 1.0);
    final left = leftFrac * w;
    final width = (widthFrac * w).clamp(6.0, w);
    final color = _kTrimColors[i % _kTrimColors.length];
    return [
      Positioned(
        left: left,
        top: 16,
        width: width,
        height: 30,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: t.isCurrent ? 0.95 : 0.78),
            borderRadius: BorderRadius.circular(8),
            border: t.isCurrent
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: t.isCurrent
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]
                : null,
          ),
          child: width > 36
              ? Text('T${t.trimesterNumber}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800))
              : null,
        ),
      ),
    ];
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(
      {required this.color, required this.label, required this.current});
  final Color color;
  final String label;
  final bool current;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                color: current ? color : kTextMuted)),
        if (current) ...[
          const SizedBox(width: 4),
          Icon(Icons.circle, size: 5, color: kGreen),
        ],
      ]);
}

class _TrimesterCard extends ConsumerWidget {
  const _TrimesterCard({required this.trimester});
  final TrimesterModel trimester;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seqAsync = ref.watch(sequencesProvider(trimester.id));
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('T${trimester.trimesterNumber}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(trimester.label,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kNavy)),
                  const SizedBox(width: 8),
                  if (trimester.isCurrent) _Tag(text: 'Courant', color: kGreen),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${_fmtDate.format(trimester.startDate)} → ${_fmtDate.format(trimester.endDate)}',
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
              ]),
            ),
          ]),
        ),
        seqAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (seqs) {
            if (seqs.isEmpty) return const SizedBox.shrink();
            return Column(children: [
              Divider(height: 1, color: kBorder),
              ...seqs.map((s) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                    child: Row(children: [
                      Icon(Icons.fiber_manual_record, size: 8, color: kTextMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Séq. ${s.sequenceNumber} · ${s.label}',
                            style: TextStyle(fontSize: 12.5, color: kNavy)),
                      ),
                      Text(
                          '${_fmtDate.format(s.startDate)} → ${_fmtDate.format(s.endDate)}',
                          style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                      if (s.isCurrent) ...[
                        const SizedBox(width: 8),
                        _Tag(text: 'Courante', color: kGreen),
                      ],
                    ]),
                  )),
              const SizedBox(height: 6),
            ]);
          },
        ),
      ]),
    );
  }
}

// Toast partagé (utilisé par _PrepClassesDialog).
void _calToast(BuildContext c, String m, {bool ok = false}) =>
    ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: ok ? kGreen : kRed));
