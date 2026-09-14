part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RAIL DES CYCLES — le maître de la page
//
//  Préscolaire, primaire, collège, lycée, formation pro. Tout ce que l'écran
//  montre ensuite découle du cycle sélectionné ici.
// ════════════════════════════════════════════════════════════════════════════

class _CycleRail extends StatelessWidget {
  const _CycleRail({
    required this.cycles,
    required this.selected,
    required this.onSelect,
  });
  final List<StructCycle> cycles;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('CYCLES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: kTextMuted)),
        ),
        for (final c in cycles) ...[
          _CycleTile(
            cycle: c,
            selected: c.code == selected,
            onTap: () => onSelect(c.code),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CycleTile extends StatelessWidget {
  const _CycleTile(
      {required this.cycle, required this.selected, required this.onTap});
  final StructCycle cycle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color : kBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_cycleIcon(cycle.code), size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cycle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? color : kTextPrimary)),
                ),
                if (cycle.emptyLevels > 0)
                  Tooltip(
                    message: '${cycle.emptyLevels} niveau(x) sans classe',
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFF59E0B)),
                  ),
              ]),
              const SizedBox(height: 9),
              Text(
                  '${_pl(cycle.levels.length, 'niveau', 'niveaux')} · ${_pl(cycle.classCount, 'classe', 'classes')} · ${_pl(cycle.enrolled, 'élève', 'élèves')}',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
              const SizedBox(height: 8),
              _FillBar(ratio: cycle.fillRatio, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// Variante étroite : chips horizontaux.

class _CycleChips extends StatelessWidget {
  const _CycleChips(
      {required this.cycles, required this.selected, required this.onSelect});
  final List<StructCycle> cycles;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final c in cycles) ...[
          _CycleChip(
            cycle: c,
            selected: c.code == selected,
            onTap: () => onSelect(c.code),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip(
      {required this.cycle, required this.selected, required this.onTap});
  final StructCycle cycle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_cycleIcon(cycle.code),
                size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 7),
            Text(cycle.name,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kTextPrimary)),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PANNEAU DÉTAIL (un cycle) — en-tête + barre d'outils + niveaux.
// ════════════════════════════════════════════════════════════════════════════
