part of 'academic_structure_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RAIL DES CYCLES (maître) — sélection focalisée d'un cycle.
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
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
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
            color: selected ? color : Colors.white,
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

// ─── Bloc d'un niveau (en-tête + table de classes) ───────────────────────────
class _NiveauBlock extends StatelessWidget {
  const _NiveauBlock({
    required this.level,
    required this.classes,
    required this.color,
    required this.readOnly,
    required this.narrow,
    required this.onAdd,
    required this.onEdit,
  });
  final StructLevel level;
  final List<StructClass> classes;
  final Color color;
  final bool readOnly, narrow;
  final VoidCallback onAdd;
  final void Function(StructClass) onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // En-tête niveau
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(level.name,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  classes.isEmpty
                      ? 'Aucune classe'
                      : '${_pl(classes.length, 'classe', 'classes')} · ${level.enrolled}'
                          '${level.capacity > 0 ? '/${level.capacity}' : ''} ${level.enrolled <= 1 ? 'élève' : 'élèves'}',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted)),
            ),
            if (!readOnly)
              _MiniAddBtn(color: color, onTap: onAdd),
          ]),
        ),
        if (classes.isNotEmpty)
          narrow
              ? Column(children: [
                  for (final c in classes)
                    _ClassCard(
                        cls: c,
                        color: color,
                        onTap: readOnly ? null : () => onEdit(c)),
                ])
              : _ClassTable(
                  classes: classes,
                  color: color,
                  onEdit: readOnly ? null : onEdit,
                )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
                readOnly
                    ? '—'
                    : 'Ce niveau n\'a pas encore de classe. Cliquez « + » pour en créer une.',
                style: TextStyle(
                    fontSize: 12,
                    color: kTextMuted,
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

class _MiniAddBtn extends StatelessWidget {
  const _MiniAddBtn({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 15, color: color),
              const SizedBox(width: 4),
              Text('Classe',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
}

// ─── Table de classes (large) ────────────────────────────────────────────────
class _ClassTable extends StatelessWidget {
  const _ClassTable(
      {required this.classes, required this.color, required this.onEdit});
  final List<StructClass> classes;
  final Color color;
  final void Function(StructClass)? onEdit;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // En-tête colonnes
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: kCardBg,
        child: const Row(children: [
          Expanded(flex: 3, child: _Th('CLASSE')),
          Expanded(flex: 2, child: _Th('FILIÈRE')),
          Expanded(flex: 3, child: _Th('EFFECTIF')),
          Expanded(flex: 3, child: _Th('PROF. PRINCIPAL')),
          Expanded(flex: 2, child: _Th('SALLE')),
          SizedBox(width: 36),
        ]),
      ),
      for (final c in classes)
        _ClassRow(cls: c, color: color, onTap: onEdit == null ? null : () => onEdit!(c)),
    ]);
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: kTextMuted));
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.color, required this.onTap});
  final StructClass cls;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder))),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(cls.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ),
              ]),
            ),
            Expanded(
                flex: 2,
                child: Text(cls.filiereLabel ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))),
            Expanded(flex: 3, child: _EffectifCell(cls: cls, color: color)),
            Expanded(
              flex: 3,
              child: cls.teacherName != null
                  ? Text(cls.teacherName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: kTextPrimary))
                  : Text('Non assigné',
                      style: TextStyle(
                          fontSize: 12,
                          color: kTextMuted,
                          fontStyle: FontStyle.italic)),
            ),
            Expanded(
                flex: 2,
                child: Text(cls.room ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted))),
            SizedBox(
              width: 36,
              child: onTap == null
                  ? const SizedBox.shrink()
                  : Icon(Icons.edit_outlined, size: 16, color: kTextMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EffectifCell extends StatelessWidget {
  const _EffectifCell({required this.cls, required this.color});
  final StructClass cls;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final txtColor = cls.isOver
        ? kRed
        : (cls.isNearFull ? const Color(0xFFF59E0B) : kTextPrimary);
    return Row(children: [
      Expanded(
          child: _FillBar(
              ratio: cls.fillRatio,
              color: cls.isOver
                  ? kRed
                  : (cls.isNearFull ? const Color(0xFFF59E0B) : color))),
      const SizedBox(width: 8),
      Text(
          cls.capacity != null
              ? '${cls.enrolled}/${cls.capacity}'
              : '${cls.enrolled}',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: txtColor)),
    ]);
  }
}

// Carte classe (étroit)
class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls, required this.color, required this.onTap});
  final StructClass cls;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder))),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(cls.name,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              if (cls.filiereLabel != null) ...[
                const SizedBox(width: 8),
                Text(cls.filiereLabel!,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
              const Spacer(),
              if (onTap != null)
                Icon(Icons.edit_outlined, size: 15, color: kTextMuted),
            ]),
            const SizedBox(height: 8),
            _EffectifCell(cls: cls, color: color),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: kTextMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(cls.teacherName ?? 'Prof. non assigné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: cls.teacherName != null
                            ? kTextPrimary
                            : kTextMuted)),
              ),
              if (cls.room != null) ...[
                Icon(Icons.meeting_room_outlined,
                    size: 14, color: kTextMuted),
                const SizedBox(width: 4),
                Text(cls.room!,
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Barre d'occupation ──────────────────────────────────────────────────────
class _FillBar extends StatelessWidget {
  const _FillBar({required this.ratio, required this.color, this.showPct = false});
  final double? ratio;
  final Color color;
  final bool showPct;
  @override
  Widget build(BuildContext context) {
    final r = ratio == null ? 0.0 : ratio!.clamp(0.0, 1.0);
    final over = ratio != null && ratio! > 1.0;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 6, color: kBorder),
            FractionallySizedBox(
              widthFactor: ratio == null ? 0 : (over ? 1.0 : r),
              child: Container(height: 6, color: over ? kRed : color),
            ),
          ]),
        ),
      ),
      if (showPct) ...[
        const SizedBox(width: 8),
        Text(ratio == null ? '—' : '${(ratio! * 100).round()}%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: over ? kRed : kTextMuted)),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MODAL — créer / modifier une classe (filière, prof principal, salle).
// ════════════════════════════════════════════════════════════════════════════
class _ClassFormModal extends ConsumerStatefulWidget {
  const _ClassFormModal(
      {required this.cycle, required this.level, this.existing});
  final StructCycle cycle;
  final StructLevel level;
  final StructClass? existing;
  @override
  ConsumerState<_ClassFormModal> createState() => _ClassFormModalState();
}

class _ClassFormModalState extends ConsumerState<_ClassFormModal> {
  late final _name = TextEditingController(
      text: widget.existing?.name ?? '${widget.level.code} A');
  late final _capacity = TextEditingController(
      text: widget.existing?.capacity != null
          ? '${widget.existing!.capacity}'
          : '');
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  String? _filiereCode;
  String? _filiereLabel;
  String? _teacherId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _filiereLabel = widget.existing?.filiereLabel;
    _teacherId = widget.existing?.teacherId;
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la classe est obligatoire.', kRed);
      return;
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    try {
      if (_isEdit) {
        await updateClassInfo(
          classId: widget.existing!.id,
          name: name,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim(),
          mainTeacherId: _teacherId,
          clearTeacher: _teacherId == null,
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      } else {
        await createStructuredClass(
          schoolId: profile?.schoolId ?? '',
          groupId: profile?.groupId ?? '',
          academicYearId: yearId ?? '',
          name: name,
          levelId: widget.level.id,
          cycleCode: widget.cycle.code,
          levelCode: widget.level.code,
          levelOrder: widget.level.order,
          capacity: int.tryParse(_capacity.text.trim()),
          room: _room.text.trim().isEmpty ? null : _room.text.trim(),
          mainTeacherId: _teacherId,
          filiereCode: _filiereCode,
          filiereLabel: _filiereLabel,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        _snack(_isEdit ? 'Classe modifiée.' : 'Classe créée.', kGreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Erreur : $e', kRed);
      }
    }
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver la classe ?'),
        content: Text(
            'La classe « ${widget.existing!.name} » sera archivée (masquée). '
            'Les inscriptions existantes sont conservées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await archiveClass(widget.existing!.id);
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Classe archivée.', kTextMuted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Erreur : $e', kRed);
      }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final filieresAsync = widget.cycle.hasPrograms
        ? ref.watch(cycleFilieresProvider(widget.cycle.code))
        : null;
    final teachers =
        ref.watch(schoolTeachersProvider).valueOrNull ?? const <SchoolTeacher>[];
    return InscriptionModalFrame(
      width: 560,
      maxHeight: 680,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InscriptionHeader(
          icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
          title: _isEdit ? 'Modifier la classe' : 'Nouvelle classe',
          subtitle: '${widget.cycle.name} · Niveau ${widget.level.name}',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filieresAsync != null)
                  filieresAsync.maybeWhen(
                    data: (fils) => fils.isEmpty
                        ? const SizedBox.shrink()
                        : FormDropdown<String>(
                            label: 'Filière / série',
                            value:
                                _filiereCode ?? _codeForLabel(fils, _filiereLabel),
                            items: {for (final f in fils) f.code: f.name},
                            onChanged: (v) => setState(() {
                              _filiereCode = v;
                              _filiereLabel =
                                  v == null ? null : fils.firstWhere((f) => f.code == v).name;
                            }),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                FormTextField(
                    controller: _name,
                    label: 'Nom de la classe *',
                    icon: Icons.class_outlined),
                Row(children: [
                  Expanded(
                    child: FormTextField(
                        controller: _capacity,
                        label: 'Capacité',
                        keyboardType: TextInputType.number,
                        icon: Icons.event_seat_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormTextField(
                        controller: _room,
                        label: 'Salle',
                        icon: Icons.meeting_room_outlined),
                  ),
                ]),
                FormDropdown<String>(
                  label: 'Professeur principal',
                  value: _teacherId ?? '',
                  items: {
                    '': 'Non assigné',
                    for (final t in teachers) t.id: t.fullName,
                  },
                  onChanged: (v) =>
                      setState(() => _teacherId = (v == null || v.isEmpty) ? null : v),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _archive,
                      icon: const Icon(Icons.archive_outlined, size: 17),
                      label: const Text('Archiver la classe'),
                      style: TextButton.styleFrom(foregroundColor: kRed),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AdminDialogFooter(
          saving: _saving,
          submitLabel: _isEdit ? 'Enregistrer' : 'Créer la classe',
          submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
          submitColor: _isEdit ? kNavy : kGreen,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: _save,
        ),
      ]),
    );
  }

  String? _codeForLabel(List<StructFiliere> fils, String? label) {
    if (label == null) return null;
    for (final f in fils) {
      if (f.name == label) return f.code;
    }
    return null;
  }
}
