part of 'emploi_du_temps_screen.dart';

// ─── Conformité au programme (volume horaire requis vs placé) ────────────────
//  Cœur de cohérence d'un EDT : chaque matière du programme de la classe a un
//  volume hebdo requis (`class_subjects.weekly_hours`) ; on compare aux heures
//  réellement placées (durée des créneaux). Vert = au volume, ambre = partiel,
//  rouge = manquant.
class _ProgramCompliance extends ConsumerWidget {
  const _ProgramCompliance({required this.classId, required this.slots});
  final String classId;
  final List<TimetableSlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(classProgramProvider(classId)).valueOrNull ?? const [];
    if (program.isEmpty) {
      return const _InfoNote(
          'Aucune matière au programme de cette classe — la conformité ne peut '
          'être mesurée. Affectez des matières (page Matières) avec un volume horaire.');
    }
    // Heures placées par matière (durée réelle des créneaux).
    final placed = <String, double>{};
    for (final s in slots) {
      placed[s.subjectId] = (placed[s.subjectId] ?? 0) + s.durationMinutes / 60;
    }
    final withTarget = program.where((o) => (o.weeklyHours ?? 0) > 0).toList();
    final okCount = withTarget
        .where((o) => (placed[o.subjectId] ?? 0) >= (o.weeklyHours ?? 0) - 0.01)
        .length;

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.fact_check_outlined, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Conformité au programme',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          ),
          if (withTarget.isNotEmpty)
            Text('$okCount/${withTarget.length} au volume',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: okCount == withTarget.length ? kGreen : kAccent)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final o in program) _SubjectVolumeChip(
            name: o.subjectName,
            placed: placed[o.subjectId] ?? 0,
            required: o.weeklyHours,
          )],
        ),
      ]),
    );
  }
}

class _SubjectVolumeChip extends StatelessWidget {
  const _SubjectVolumeChip(
      {required this.name, required this.placed, required this.required});
  final String name;
  final double placed;
  final int? required;

  String _h(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}h' : '${v.toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    final req = required ?? 0;
    final Color color;
    final IconData icon;
    if (req <= 0) {
      color = kTextMuted; // pas de cible définie
      icon = Icons.remove_rounded;
    } else if (placed >= req - 0.01) {
      color = kGreen;
      icon = Icons.check_circle_rounded;
    } else if (placed > 0) {
      color = const Color(0xFFF59E0B);
      icon = Icons.timelapse_rounded;
    } else {
      color = kRed;
      icon = Icons.error_outline_rounded;
    }
    final label = req > 0 ? '${_h(placed)} / ${req}h' : _h(placed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ─── Menu d'actions d'une classe (dupliquer / vider) ─────────────────────────
class _ClassActionsMenu extends StatelessWidget {
  const _ClassActionsMenu({
    required this.className,
    required this.canEdit,
    required this.onDuplicate,
    required this.onClear,
  });
  final String className;
  final bool canEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: kTextMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'dup') onDuplicate();
        if (v == 'clear') onClear?.call();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dup',
          child: Row(children: [
            Icon(Icons.copy_all_rounded, size: 17, color: kNavy),
            const SizedBox(width: 10),
            const Text('Dupliquer vers une classe…'),
          ]),
        ),
        if (onClear != null)
          PopupMenuItem(
            value: 'clear',
            child: Row(children: [
              Icon(Icons.delete_sweep_outlined, size: 17, color: kRed),
              const SizedBox(width: 10),
              Text('Vider l\'emploi du temps', style: TextStyle(color: kRed)),
            ]),
          ),
      ],
    );
  }
}
