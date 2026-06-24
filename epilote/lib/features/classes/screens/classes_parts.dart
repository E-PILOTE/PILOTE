part of 'classes_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Classes : barre de filtres, en-tête de résultats,
//  table, cartes, et le formulaire création/édition (cascade Cycle ▸ Niveau).
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres (recherche + cycle + niveau + filière + vue + ajout) ───
class _ClassFilterBar extends StatelessWidget {
  const _ClassFilterBar({
    required this.searchCtrl,
    required this.cycle,
    required this.level,
    required this.filiere,
    required this.isTable,
    required this.readOnly,
    required this.cyclesPresent,
    required this.levelCodes,
    required this.filieresPresent,
    required this.onSearch,
    required this.onCycle,
    required this.onLevel,
    required this.onFiliere,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final String? cycle, level, filiere;
  final bool isTable, readOnly;
  final Map<String, String> cyclesPresent;
  final List<String> levelCodes;
  final List<String> filieresPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCycle, onLevel, onFiliere;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFilter = searchCtrl.text.isNotEmpty ||
        cycle != null ||
        level != null ||
        filiere != null;
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher (nom, salle, prof.)',
                      icon: Icons.search_rounded),
                ),
              ),
              _FilterDropdown(
                hint: 'Tous les cycles',
                value: cycle,
                items: {
                  for (final e in (cyclesPresent.entries.toList()
                        ..sort((a, b) =>
                            _cycOrder(a.key).compareTo(_cycOrder(b.key)))))
                    if (e.key.isNotEmpty) e.key: e.value,
                },
                onChanged: onCycle,
              ),
              _FilterDropdown(
                hint: 'Tous les niveaux',
                value: level,
                items: {for (final c in levelCodes) c: c},
                onChanged: onLevel,
              ),
              if (filieresPresent.isNotEmpty)
                _FilterDropdown(
                  hint: 'Toutes les filières',
                  value: filiere,
                  items: {for (final f in filieresPresent) f: f},
                  onChanged: onFiliere,
                ),
              if (hasFilter)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(foregroundColor: kTextMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ViewToggle(isTable: isTable, onToggle: onToggleView),
        if (!readOnly) ...[
          const SizedBox(width: 10),
          PermissionGate(
            slug: 'classes',
            action: 'create',
            child: AdminPrimaryButton(
              label: 'Nouvelle classe',
              icon: Icons.add_rounded,
              color: kNavy,
              onTap: onAdd,
            ),
          ),
        ],
      ]),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: kTextPrimary),
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        decoration: adminFilledInput(hint),
        hint: Text(hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: kTextMuted)),
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final e in items.entries)
            DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                size: 16, color: kNavy),
            const SizedBox(width: 7),
            Text(isTable ? 'Cartes' : 'Table',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
          ]),
        ),
      ),
    );
  }
}

// ─── En-tête de résultats ────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'classe', 'classes')
        : '$filtered / ${_pl(total, 'classe', 'classes')}';
    return Row(children: [
      const Icon(Icons.class_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _ClassTable extends StatelessWidget {
  const _ClassTable({
    required this.rows,
    required this.teachers,
    required this.sortAsc,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onSort,
    required this.onView,
    required this.onEdit,
  });
  final List<ClassModel> rows;
  final Map<String, String> teachers;
  final bool sortAsc, readOnly;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onSort;
  final ValueChanged<ClassModel> onView, onEdit;

  @override
  Widget build(BuildContext context) {
    final allSel =
        rows.isNotEmpty && rows.every((c) => selected.contains(c.id));
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            if (!readOnly) ...[
              _Check(value: allSel, onChanged: onSelectAll),
              const SizedBox(width: 6),
            ],
            const _Th('CLASSE', flex: 3),
            _Th('CYCLE · NIVEAU', flex: 3, onTap: onSort, asc: sortAsc),
            const _Th('FILIÈRE', flex: 2),
            const _Th('EFFECTIF', flex: 2),
            const _Th('PROF. PRINCIPAL', flex: 3),
            const _Th('SALLE', flex: 1),
            const SizedBox(width: 84),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _ClassRow(
            c: rows[i],
            teacher: teachers[rows[i].mainTeacherId],
            last: i == rows.length - 1,
            readOnly: readOnly,
            selected: selected.contains(rows[i].id),
            onSelect: (v) => onSelect(rows[i].id, v),
            onView: () => onView(rows[i]),
            onEdit: () => onEdit(rows[i]),
          ),
      ]),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: kNavy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: kTextMuted, width: 1.5),
        ),
      );
}

class _Th extends StatelessWidget {
  const _Th(this.label, {required this.flex, this.onTap, this.asc});
  final String label;
  final int flex;
  final VoidCallback? onTap;
  final bool? asc;
  @override
  Widget build(BuildContext context) {
    final child = Row(children: [
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      ),
      if (asc != null)
        Icon(asc! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: kTextMuted),
    ]);
    return Expanded(
      flex: flex,
      child: onTap == null
          ? child
          : InkWell(onTap: onTap, child: child),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.c,
    required this.teacher,
    required this.last,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
    required this.onView,
    required this.onEdit,
  });
  final ClassModel c;
  final String? teacher;
  final bool last, readOnly, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onView, onEdit;

  @override
  Widget build(BuildContext context) {
    final col = _cycColor(c.cycleCode);
    return InkWell(
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.04) : null,
          border: last
              ? null
              : const Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          if (!readOnly) ...[
            _Check(value: selected, onChanged: onSelect),
            const SizedBox(width: 6),
          ],
          Expanded(
            flex: 3,
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.class_rounded, size: 17, color: col),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
              ),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Row(children: [
              AdminBadge(_cycName(c.cycleCode), color: col),
              const SizedBox(width: 6),
              Flexible(
                child: Text(c.levelCode ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: kTextPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Text(c.filiereLabel ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(flex: 2, child: _Effectif(c: c)),
          Expanded(
            flex: 3,
            child: Text(teacher ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: teacher == null ? kTextMuted : kTextPrimary)),
          ),
          Expanded(
            flex: 1,
            child: Text(c.room ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          SizedBox(
            width: 84,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Ouvrir',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.visibility_outlined,
                    size: 18, color: kTextMuted),
                onPressed: onView,
              ),
              if (!readOnly)
                IconButton(
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                  icon:
                      const Icon(Icons.edit_outlined, size: 18, color: kNavy),
                  onPressed: onEdit,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Effectif extends StatelessWidget {
  const _Effectif({required this.c});
  final ClassModel c;
  @override
  Widget build(BuildContext context) {
    final n = c.studentCount ?? 0;
    final cap = c.capacity;
    final ratio = (cap == null || cap == 0) ? null : n / cap;
    final over = cap != null && n > cap;
    final near = ratio != null && ratio >= 0.9 && !over;
    final col = over ? kRed : (near ? kAccent : kGreen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(cap == null ? '$n' : '$n / $cap',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: col)),
        const SizedBox(height: 4),
        _FillBar(ratio: ratio?.clamp(0.0, 1.0), color: col),
      ],
    );
  }
}

class _FillBar extends StatelessWidget {
  const _FillBar({required this.ratio, required this.color});
  final double? ratio;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: ratio ?? 0,
          minHeight: 5,
          backgroundColor: kBorder,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _ClassCards extends StatelessWidget {
  const _ClassCards({
    required this.rows,
    required this.teachers,
    required this.readOnly,
    required this.onView,
    required this.onEdit,
  });
  final List<ClassModel> rows;
  final Map<String, String> teachers;
  final bool readOnly;
  final ValueChanged<ClassModel> onView, onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 4 : (w >= 880 ? 3 : (w >= 560 ? 2 : 1));
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final c in rows)
            SizedBox(
              width: cardW,
              child: _ClassGridCard(
                c: c,
                teacher: teachers[c.mainTeacherId],
                readOnly: readOnly,
                onView: () => onView(c),
                onEdit: () => onEdit(c),
              ),
            ),
        ],
      );
    });
  }
}

class _ClassGridCard extends StatelessWidget {
  const _ClassGridCard({
    required this.c,
    required this.teacher,
    required this.readOnly,
    required this.onView,
    required this.onEdit,
  });
  final ClassModel c;
  final String? teacher;
  final bool readOnly;
  final VoidCallback onView, onEdit;

  @override
  Widget build(BuildContext context) {
    final col = _cycColor(c.cycleCode);
    final n = c.studentCount ?? 0;
    final cap = c.capacity;
    final ratio = (cap == null || cap == 0) ? null : n / cap;
    final over = cap != null && n > cap;
    final near = ratio != null && ratio >= 0.9 && !over;
    final fillCol = over ? kRed : (near ? kAccent : kGreen);
    return AdminCard(
      onTap: onView,
      padding: const EdgeInsets.all(16),
      accent: col,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.class_rounded, size: 20, color: col),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              Text(
                  [_cycName(c.cycleCode), if ((c.levelCode ?? '').isNotEmpty) c.levelCode!]
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          if (!readOnly)
            IconButton(
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.groups_outlined, size: 15, color: fillCol),
          const SizedBox(width: 5),
          Text(cap == null ? '$n élève${n > 1 ? 's' : ''}' : '$n / $cap',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: fillCol)),
          const Spacer(),
          if (c.filiereLabel != null)
            Flexible(
              child: Text(c.filiereLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
            ),
        ]),
        const SizedBox(height: 8),
        _FillBar(ratio: ratio?.clamp(0.0, 1.0), color: fillCol),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.person_outline_rounded, size: 14, color: kTextMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(teacher ?? 'Pas de prof. principal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: teacher == null ? kTextMuted : kTextPrimary)),
          ),
          if ((c.room ?? '').isNotEmpty) ...[
            const Icon(Icons.meeting_room_outlined,
                size: 14, color: kTextMuted),
            const SizedBox(width: 4),
            Text(c.room!,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE — création (cascade Cycle ▸ Niveau) / édition. Pose level_id +
//  dénormalisés via createStructuredClass → KPI cohérents (fin de l'heuristique
//  par nom). Prof. principal + filière (séries lycée / métiers FP) intégrés.
// ════════════════════════════════════════════════════════════════════════════
class _ClassFormSheet extends ConsumerStatefulWidget {
  const _ClassFormSheet({this.existing});
  final ClassModel? existing;
  @override
  ConsumerState<_ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends ConsumerState<_ClassFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _capacity =
      TextEditingController(text: widget.existing?.capacity?.toString() ?? '');
  late final _room = TextEditingController(text: widget.existing?.room ?? '');

  String? _cycleCode;
  String? _levelId;
  String? _levelCode;
  int _levelOrder = 999;
  String? _filiereCode;
  String? _filiereLabel;
  String? _teacherId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _cycleCode = widget.existing!.cycleCode;
      _levelId = widget.existing!.levelId;
      _levelCode = widget.existing!.levelCode;
      _levelOrder = widget.existing!.levelOrder ?? 999;
      _filiereLabel = widget.existing!.filiereLabel;
      _teacherId = widget.existing!.mainTeacherId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _room.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  String? _codeForLabel(List<StructFiliere> fils, String? label) {
    if (label == null) return null;
    final m = fils.where((f) => f.name == label);
    return m.isEmpty ? null : m.first.code;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la classe est obligatoire.', kRed);
      return;
    }
    if (!_isEdit && _levelId == null) {
      _snack('Choisissez le cycle et le niveau.', kRed);
      return;
    }
    setState(() => _saving = true);
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    final ok = await runModuleWrite(
      context,
      () async {
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
            levelId: _levelId!,
            cycleCode: _cycleCode ?? '',
            levelCode: _levelCode ?? '',
            levelOrder: _levelOrder,
            capacity: int.tryParse(_capacity.text.trim()),
            room: _room.text.trim().isEmpty ? null : _room.text.trim(),
            mainTeacherId: _teacherId,
            filiereCode: _filiereCode,
            filiereLabel: _filiereLabel,
          );
        }
      },
      success: _isEdit ? 'Classe modifiée' : 'Classe créée',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Archiver la classe ?'),
        content: Text('La classe « ${widget.existing!.name} » sera masquée. '
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
    if (ok != true || !mounted) return;
    final done = await runModuleWrite(context,
        () => archiveClass(widget.existing!.id),
        success: 'Classe archivée');
    if (done && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final structure =
        ref.watch(academicStructureProvider).valueOrNull ?? AcademicStructure.empty;
    final teachers =
        ref.watch(schoolTeachersProvider).valueOrNull ?? const <SchoolTeacher>[];
    final filieres = (_cycleCode == null || _cycleCode!.isEmpty)
        ? const <StructFiliere>[]
        : (ref.watch(cycleFilieresProvider(_cycleCode!)).valueOrNull ??
            const <StructFiliere>[]);

    // Niveaux du cycle sélectionné (création).
    final levels = _cycleCode == null
        ? const <StructLevel>[]
        : (structure.cycles
                .where((c) => c.code == _cycleCode)
                .map((c) => c.levels)
                .expand((e) => e)
                .toList());

    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Modifier la classe' : 'Nouvelle classe',
      subtitle: _isEdit
          ? '${_cycName(_cycleCode)} · ${_levelCode ?? '—'}'
          : 'Cycle ▸ niveau ▸ détails',
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
      onSubmit: _saving ? null : _save,
      footer: null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_isEdit) ...[
          if (structure.cycles.isEmpty)
            const _InfoNote(
                'Aucun cycle n\'est encore attribué à l\'école. '
                'L\'administration du groupe doit configurer les cycles '
                'd\'enseignement avant de créer des classes.')
          else ...[
            const _Label('Cycle *'),
            _Dropdown<String>(
              hint: 'Sélectionner le cycle',
              value: _cycleCode,
              items: {
                for (final c in (structure.cycles.toList()
                      ..sort((a, b) => a.order.compareTo(b.order))))
                  c.code: c.name,
              },
              onChanged: (v) => setState(() {
                _cycleCode = v;
                _levelId = null;
                _levelCode = null;
                _filiereCode = null;
                _filiereLabel = null;
              }),
            ),
            const SizedBox(height: 14),
            const _Label('Niveau *'),
            _Dropdown<String>(
              key: ValueKey('lvl_$_cycleCode'),
              hint: levels.isEmpty
                  ? 'Aucun niveau pour ce cycle'
                  : 'Sélectionner le niveau',
              value: _levelId,
              items: {for (final l in levels) l.id: l.name},
              onChanged: (v) => setState(() {
                _levelId = v;
                final m = levels.where((l) => l.id == v);
                if (m.isNotEmpty) {
                  _levelCode = m.first.code;
                  _levelOrder = m.first.order;
                  if (_name.text.trim().isEmpty) {
                    _name.text = '${m.first.code} A';
                  }
                }
              }),
            ),
            const SizedBox(height: 14),
          ],
        ],
        const _Label('Nom de la classe *'),
        _TextField(controller: _name, hint: 'Ex. 6e A, Terminale D'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Capacité'),
                  _TextField(
                      controller: _capacity,
                      hint: 'Ex. 45',
                      number: true),
                ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Salle'),
                  _TextField(controller: _room, hint: 'Ex. B12'),
                ]),
          ),
        ]),
        if (filieres.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _Label('Filière / Série'),
          _Dropdown<String>(
            hint: 'Aucune (tronc commun)',
            value: _filiereCode ?? _codeForLabel(filieres, _filiereLabel),
            nullable: true,
            items: {for (final f in filieres) f.code: f.name},
            onChanged: (v) => setState(() {
              _filiereCode = v;
              final m = filieres.where((f) => f.code == v);
              _filiereLabel = m.isEmpty ? null : m.first.name;
            }),
          ),
        ],
        const SizedBox(height: 14),
        const _Label('Professeur principal'),
        _Dropdown<String>(
          hint: teachers.isEmpty ? 'Aucun enseignant' : 'Aucun (à affecter)',
          value: _teacherId,
          nullable: true,
          items: {for (final t in teachers) t.id: t.fullName},
          onChanged: (v) => setState(() => _teacherId = v),
        ),
        if (_isEdit) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _archive,
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: const Text('Archiver cette classe'),
              style: TextButton.styleFrom(foregroundColor: kRed),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Champs de formulaire locaux (style plateforme) ──────────────────────────
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      );
}

class _TextField extends StatelessWidget {
  const _TextField(
      {required this.controller, required this.hint, this.number = false});
  final TextEditingController controller;
  final String hint;
  final bool number;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        style: const TextStyle(fontSize: 13.5),
        decoration: adminFilledInput(hint),
      );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.nullable = false,
  });
  final String hint;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final bool nullable;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.containsKey(value) ? value : null,
      isExpanded: true,
      style: const TextStyle(fontSize: 13.5, color: kTextPrimary),
      icon: const Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
      decoration: adminFilledInput(hint),
      hint: Text(hint,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: kTextMuted)),
      items: [
        if (nullable)
          DropdownMenuItem(value: null, child: Text(hint)),
        for (final e in items.entries)
          DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E))),
          ),
        ]),
      );
}

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _ClassBulkBar extends StatelessWidget {
  const _ClassBulkBar({
    required this.count,
    required this.onArchive,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onArchive, onExport, onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('$count sélectionnée${count > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        const Spacer(),
        _BulkBtn(
            icon: Icons.archive_outlined, label: 'Archiver', onTap: onArchive),
        _BulkBtn(
            icon: Icons.download_rounded, label: 'Exporter', onTap: onExport),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Désélectionner',
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

// ─── Graphes : classes par cycle (donut) + occupation par niveau (barres) ────
class _ClassCharts extends StatelessWidget {
  const _ClassCharts({required this.classes});
  final List<ClassModel> classes;

  @override
  Widget build(BuildContext context) {
    final byCycle = <String, int>{};
    for (final c in classes) {
      byCycle[c.cycleCode ?? ''] = (byCycle[c.cycleCode ?? ''] ?? 0) + 1;
    }
    final slices = (byCycle.entries.toList()
          ..sort((a, b) => _cycOrder(a.key).compareTo(_cycOrder(b.key))))
        .map((e) => _CycleSlice(_cycName(e.key), e.value, _cycColor(e.key)))
        .toList();

    // Occupation par niveau (effectif / capacité).
    final lvl = <String, ({int n, int cap, int order, String cycle})>{};
    for (final c in classes) {
      final lc = c.levelCode ?? '';
      if (lc.isEmpty) continue;
      final cur = lvl[lc];
      lvl[lc] = (
        n: (cur?.n ?? 0) + (c.studentCount ?? 0),
        cap: (cur?.cap ?? 0) + (c.capacity ?? 0),
        order: c.levelOrder ?? 999,
        cycle: c.cycleCode ?? '',
      );
    }
    final levels = lvl.entries.toList()
      ..sort((a, b) {
        final cy = _cycOrder(a.value.cycle).compareTo(_cycOrder(b.value.cycle));
        return cy != 0 ? cy : a.value.order.compareTo(b.value.order);
      });

    return LayoutBuilder(builder: (ctx, cns) {
      final wide = cns.maxWidth >= 760;
      final donut = _MiniChartCard(
        title: 'Classes par cycle',
        icon: Icons.donut_large_rounded,
        child: SizedBox(
          height: 200,
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            legend: const Legend(
                isVisible: true,
                overflowMode: LegendItemOverflowMode.wrap,
                position: LegendPosition.bottom),
            series: <CircularSeries>[
              DoughnutSeries<_CycleSlice, String>(
                dataSource: slices,
                xValueMapper: (s, _) => s.label,
                yValueMapper: (s, _) => s.value,
                pointColorMapper: (s, _) => s.color,
                innerRadius: '62%',
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
      );
      final bars = _MiniChartCard(
        title: 'Occupation par niveau',
        icon: Icons.bar_chart_rounded,
        child: levels.isEmpty
            ? const SizedBox(
                height: 60,
                child: Center(child: Text('—', style: TextStyle(color: kTextMuted))))
            : Column(
                children: [
                  for (final e in levels)
                    _OccBar(
                      label: e.key,
                      n: e.value.n,
                      cap: e.value.cap,
                      cycle: e.value.cycle,
                    ),
                ],
              ),
      );
      if (wide) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: donut),
            const SizedBox(width: 14),
            Expanded(child: bars),
          ]),
        );
      }
      return Column(children: [donut, const SizedBox(height: 14), bars]);
    });
  }
}

class _CycleSlice {
  const _CycleSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _MiniChartCard extends StatelessWidget {
  const _MiniChartCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _OccBar extends StatelessWidget {
  const _OccBar(
      {required this.label,
      required this.n,
      required this.cap,
      required this.cycle});
  final String label;
  final int n, cap;
  final String cycle;
  @override
  Widget build(BuildContext context) {
    final ratio = cap == 0 ? null : n / cap;
    final over = cap > 0 && n > cap;
    final col = over ? kRed : _cycColor(cycle);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 56,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ratio ?? 0).clamp(0.02, 1.0),
              minHeight: 16,
              backgroundColor: kSurface,
              valueColor: AlwaysStoppedAnimation(col.withValues(alpha: 0.85)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(cap == 0 ? '$n' : '$n / $cap',
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: over ? kRed : kTextPrimary)),
        ),
      ]),
    );
  }
}
