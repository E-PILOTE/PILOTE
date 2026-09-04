part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PANNEAU DE DÉTAIL — en-tête du cycle, filières, barre d'outils
// ════════════════════════════════════════════════════════════════════════════

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.cycle,
    required this.readOnly,
    required this.search,
    required this.filiere,
    required this.onSearch,
    required this.onFiliere,
    required this.onAdd,
    required this.onEdit,
    this.narrow = false,
  });
  final StructCycle cycle;
  final bool readOnly, narrow;
  final TextEditingController search;
  final String? filiere;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onFiliere;
  final void Function(StructLevel) onAdd;
  final void Function(StructLevel, StructClass) onEdit;

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final filtering = q.isNotEmpty || filiere != null;
    // Filières présentes (pour le filtre).
    final present = <String>{
      for (final l in cycle.levels)
        for (final c in l.classes)
          if (c.filiereLabel != null) c.filiereLabel!,
    }.toList()
      ..sort();

    final blocks = <Widget>[];
    for (final lvl in cycle.levels) {
      final classes = lvl.classes.where((c) {
        if (q.isNotEmpty && !c.name.toLowerCase().contains(q)) return false;
        if (filiere != null && c.filiereLabel != filiere) return false;
        return true;
      }).toList();
      if (filtering && classes.isEmpty) continue; // masque niveaux vides en filtrage
      blocks.add(_NiveauBlock(
        level: lvl,
        classes: classes,
        color: _cycleColor(cycle.code),
        readOnly: readOnly,
        narrow: narrow,
        onAdd: () => onAdd(lvl),
        onEdit: (c) => onEdit(lvl, c),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _DetailHeader(cycle: cycle),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _Toolbar(
            search: search,
            onSearch: onSearch,
            filiere: filiere,
            filieres: present,
            onFiliere: onFiliere,
          ),
        ),
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Center(
              child: Text(
                  filtering
                      ? 'Aucune classe ne correspond.'
                      : 'Aucun niveau dans ce cycle.',
                  style: TextStyle(color: kTextMuted, fontSize: 13)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(children: blocks),
          ),
      ]),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.cycle});
  final StructCycle cycle;
  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(_cycleIcon(cycle.code), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cycle.name,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                    '${_pl(cycle.levels.length, 'niveau', 'niveaux')} · ${_pl(cycle.classCount, 'classe', 'classes')} · ${_pl(cycle.enrolled, 'élève', 'élèves')}'
                    '${cycle.capacity > 0 ? ' · ${cycle.enrolled}/${cycle.capacity} places' : ''}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          SizedBox(
              width: 120,
              child: _FillBar(ratio: cycle.fillRatio, color: color, showPct: true)),
        ]),
        if (cycle.hasPrograms) ...[
          const SizedBox(height: 12),
          _CycleFilieres(cycleCode: cycle.code),
        ],
      ]),
    );
  }
}

// Référentiel des filières du cycle (chips lecture).

class _CycleFilieres extends ConsumerWidget {
  const _CycleFilieres({required this.cycleCode});
  final String cycleCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cycleFilieresProvider(cycleCode));
    return async.maybeWhen(
      data: (fils) => fils.isEmpty
          ? const SizedBox.shrink()
          : Wrap(spacing: 6, runSpacing: 6, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 2),
                child: Icon(Icons.workspaces_outline,
                    size: 14, color: kTextMuted),
              ),
              for (final f in fils)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(f.name,
                      style:
                          TextStyle(fontSize: 11, color: kTextMuted)),
                ),
            ]),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearch,
    required this.filiere,
    required this.filieres,
    required this.onFiliere,
  });
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final String? filiere;
  final List<String> filieres;
  final ValueChanged<String?> onFiliere;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: search,
            onChanged: onSearch,
            style: const TextStyle(fontSize: 13.5),
            decoration: adminFilledInput('Rechercher une classe…',
                icon: Icons.search_rounded),
          ),
        ),
        if (filieres.isNotEmpty)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: filiere,
              isExpanded: true,
              style: TextStyle(fontSize: 13.5, color: kTextPrimary),
              decoration: adminFilledInput('Toutes les filières',
                  icon: Icons.workspaces_outline),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toutes les filières')),
                for (final f in filieres)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: onFiliere,
            ),
          ),
      ],
    );
  }
}
