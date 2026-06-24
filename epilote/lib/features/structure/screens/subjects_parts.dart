part of 'subjects_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Briques de la page Matières : répartition par coefficient, barre de filtres,
//  table, cartes, formulaire création/édition.
// ════════════════════════════════════════════════════════════════════════════

// Accents par cycle (cohérents avec les autres pages).
const _cycleColors = <String, Color>{
  'prescolaire': Color(0xFFEC4899),
  'primaire': Color(0xFF0EA5E9),
  'college': kGreen,
  'lycee': kNavy,
  'formation_pro': Color(0xFFF59E0B),
  'fp': Color(0xFFF59E0B),
};
Color _cycColor(String? c) => _cycleColors[c ?? ''] ?? kNavy;

// ─── Matières par niveau (barres cliquables → filtre) ────────────────────────
// Une matière est portée par un niveau (coefficient propre) ; « Tronc commun »
// = toutes les classes. Cliquer un niveau filtre la liste. La granularité série
// (Tle A vs C) suivra si l'admin groupe modélise des niveaux par filière.
class _NiveauBreakdown extends StatelessWidget {
  const _NiveauBreakdown({
    required this.subjects,
    required this.active,
    required this.onPick,
  });
  final List<SubjectModel> subjects;
  final String? active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final groups =
        <String, ({String label, int order, String cycle, int count, int coef})>{};
    for (final s in subjects) {
      final key = s.isTronc ? '__tronc__' : (s.levelCode ?? '');
      final cur = groups[key];
      groups[key] = (
        label: s.isTronc ? 'Tronc commun' : (s.levelCode ?? '—'),
        order: s.isTronc ? -1 : s.levelOrder,
        cycle: s.isTronc ? '' : (s.cycleCode ?? ''),
        count: (cur?.count ?? 0) + 1,
        coef: (cur?.coef ?? 0) + s.coefficient,
      );
    }
    final list = groups.entries.toList()
      ..sort((a, b) => a.value.order.compareTo(b.value.order));
    final maxN = list.fold<int>(0, (m, e) => e.value.count > m ? e.value.count : m);

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.stairs_outlined, size: 16, color: kNavy),
          SizedBox(width: 8),
          Text('Matières par niveau',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          Spacer(),
          Text('cliquez pour filtrer',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        for (final e in list)
          _NivBar(
            label: e.value.label,
            count: e.value.count,
            coef: e.value.coef,
            ratio: maxN == 0 ? 0 : e.value.count / maxN,
            color: e.key == '__tronc__' ? kTextMuted : _cycColor(e.value.cycle),
            active: active == e.key,
            onTap: () => onPick(e.key),
          ),
      ]),
    );
  }
}

class _NivBar extends StatelessWidget {
  const _NivBar({
    required this.label,
    required this.count,
    required this.coef,
    required this.ratio,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count, coef;
  final double ratio;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: 96,
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
                value: ratio.clamp(0.02, 1.0),
                minHeight: 16,
                backgroundColor: kSurface,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text('${_pl(count, 'matière', 'matières')} · Σ$coef',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
class _SubjectFilterBar extends StatelessWidget {
  const _SubjectFilterBar({
    required this.searchCtrl,
    required this.isTable,
    required this.sort,
    required this.sortAsc,
    required this.levelFilter,
    required this.levelsPresent,
    required this.onSearch,
    required this.onSort,
    required this.onLevel,
    required this.onToggleView,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final bool isTable, sortAsc;
  final String sort;
  final String? levelFilter;
  final Map<String, String> levelsPresent; // key (code|__tronc__) → label
  final ValueChanged<String> onSearch, onSort;
  final ValueChanged<String?> onLevel;
  final VoidCallback onToggleView, onAdd;

  @override
  Widget build(BuildContext context) {
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
                width: 230,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher une matière',
                      icon: Icons.search_rounded),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: levelsPresent.containsKey(levelFilter)
                      ? levelFilter
                      : null,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  icon: const Icon(Icons.expand_more_rounded,
                      size: 18, color: kTextMuted),
                  decoration: adminFilledInput('Tous les niveaux'),
                  hint: const Text('Tous les niveaux',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: kTextMuted)),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tous les niveaux')),
                    for (final e in levelsPresent.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: onLevel,
                ),
              ),
              _SortChip(
                  label: 'Nom',
                  active: sort == 'name',
                  asc: sortAsc,
                  onTap: () => onSort('name')),
              _SortChip(
                  label: 'Coefficient',
                  active: sort == 'coef',
                  asc: sortAsc,
                  onTap: () => onSort('coef')),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onToggleView,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    isTable
                        ? Icons.grid_view_rounded
                        : Icons.table_rows_rounded,
                    size: 16,
                    color: kNavy),
                const SizedBox(width: 7),
                Text(isTable ? 'Cartes' : 'Table',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kNavy)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PermissionGate(
          slug: _kSlug,
          action: 'create',
          child: AdminPrimaryButton(
            label: 'Nouvelle matière',
            icon: Icons.add_rounded,
            color: kNavy,
            onTap: onAdd,
          ),
        ),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label,
      required this.active,
      required this.asc,
      required this.onTap});
  final String label;
  final bool active, asc;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? kNavy.withValues(alpha: 0.08) : kSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? kNavy : kBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? kNavy : kTextMuted)),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 13, color: kNavy),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── En-tête résultats ────────────────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'matière', 'matières')
        : '$filtered / ${_pl(total, 'matière', 'matières')}';
    return Row(children: [
      const Icon(Icons.menu_book_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ]);
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────
class _SubjectTable extends ConsumerWidget {
  const _SubjectTable({
    required this.rows,
    required this.coefByLevel,
    required this.sort,
    required this.sortAsc,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onSort,
    required this.onEdit,
    required this.onArchive,
  });
  final List<SubjectModel> rows;
  final Map<String, int> coefByLevel;
  final String sort;
  final bool sortAsc;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<String> onSort;
  final ValueChanged<SubjectModel> onEdit, onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final canBulk = canEdit || canDelete;
    final allSel =
        rows.isNotEmpty && rows.every((s) => selected.contains(s.id));
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
            if (canBulk) ...[
              _Check(value: allSel, onChanged: onSelectAll),
              const SizedBox(width: 6),
            ],
            _Th('MATIÈRE',
                flex: 5,
                asc: sort == 'name' ? sortAsc : null,
                onTap: () => onSort('name')),
            const _Th('NIVEAU', flex: 3),
            _Th('COEFFICIENT',
                flex: 3,
                asc: sort == 'coef' ? sortAsc : null,
                onTap: () => onSort('coef')),
            const _Th('POIDS', flex: 2),
            const SizedBox(width: 96),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _SubjectRow(
            s: rows[i],
            levelCoefTotal: coefByLevel[
                    rows[i].isTronc ? '__tronc__' : (rows[i].levelCode ?? '')] ??
                0,
            last: i == rows.length - 1,
            canEdit: canEdit,
            canDelete: canDelete,
            canBulk: canBulk,
            selected: selected.contains(rows[i].id),
            onSelect: (v) => onSelect(rows[i].id, v),
            onEdit: () => onEdit(rows[i]),
            onArchive: () => onArchive(rows[i]),
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
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.s,
    required this.levelCoefTotal,
    required this.last,
    required this.canEdit,
    required this.canDelete,
    required this.canBulk,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onArchive,
  });
  final SubjectModel s;
  final int levelCoefTotal;
  final bool last, canEdit, canDelete, canBulk, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit, onArchive;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    final pct = levelCoefTotal == 0
        ? null
        : (s.coefficient * 100 / levelCoefTotal).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? kNavy.withValues(alpha: 0.04) : null,
        border:
            last ? null : const Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        if (canBulk) ...[
          _Check(value: selected, onChanged: onSelect),
          const SizedBox(width: 6),
        ],
        Expanded(
          flex: 5,
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.menu_book_rounded, size: 17, color: col),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(s.name,
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBadge(s.levelLabel,
                color: s.isTronc ? kTextMuted : _cycColor(s.cycleCode)),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBadge('Coef. ${s.coefficient}', color: kGreen),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(pct == null ? '—' : '$pct %',
              style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
        ),
        SizedBox(
          width: 96,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (canEdit)
              IconButton(
                tooltip: 'Modifier',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18, color: kNavy),
                onPressed: onEdit,
              ),
            if (canDelete)
              IconButton(
                tooltip: 'Archiver',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.archive_outlined, size: 18, color: kRed),
                onPressed: onArchive,
              ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Cartes ──────────────────────────────────────────────────────────────────
class _SubjectCards extends ConsumerWidget {
  const _SubjectCards(
      {required this.rows,
      required this.coefByLevel,
      required this.onEdit,
      required this.onArchive});
  final List<SubjectModel> rows;
  final Map<String, int> coefByLevel;
  final ValueChanged<SubjectModel> onEdit, onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 4 : (w >= 880 ? 3 : (w >= 560 ? 2 : 1));
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in rows)
            SizedBox(
              width: cardW,
              child: _SubjectGridCard(
                s: s,
                levelCoefTotal:
                    coefByLevel[s.isTronc ? '__tronc__' : (s.levelCode ?? '')] ?? 0,
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () => onEdit(s),
                onArchive: () => onArchive(s),
              ),
            ),
        ],
      );
    });
  }
}

class _SubjectGridCard extends StatelessWidget {
  const _SubjectGridCard({
    required this.s,
    required this.levelCoefTotal,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onArchive,
  });
  final SubjectModel s;
  final int levelCoefTotal;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onArchive;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    final pct = levelCoefTotal == 0
        ? null
        : (s.coefficient * 100 / levelCoefTotal).round();
    return AdminCard(
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
            child: Icon(Icons.menu_book_rounded, size: 20, color: col),
          ),
          const Spacer(),
          if (canEdit)
            IconButton(
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Archiver',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.archive_outlined, size: 17, color: kRed),
              onPressed: onArchive,
            ),
        ]),
        const SizedBox(height: 12),
        Text(s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        AdminBadge(s.levelLabel,
            color: s.isTronc ? kTextMuted : _cycColor(s.cycleCode)),
        const SizedBox(height: 10),
        Row(children: [
          AdminBadge('Coef. ${s.coefficient}', color: kGreen),
          const Spacer(),
          if (pct != null)
            Text('$pct % du niveau',
                style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE — création / édition (nom + coefficient via stepper).
// ════════════════════════════════════════════════════════════════════════════
class _SubjectForm extends ConsumerStatefulWidget {
  const _SubjectForm({this.existing});
  final SubjectModel? existing;
  @override
  ConsumerState<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<_SubjectForm> {
  late final _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late int _coef = widget.existing?.coefficient ?? 1;
  late String? _levelId = widget.existing?.levelId; // null = tronc commun
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Le nom de la matière est obligatoire.', kRed);
      return;
    }
    final profile = ref.read(authNotifierProvider).valueOrNull;
    final groupId = profile?.groupId;
    final schoolId = profile?.schoolId;
    if (groupId == null || schoolId == null || schoolId.isEmpty) {
      _snack('École introuvable.', kRed);
      return;
    }
    setState(() => _saving = true);
    final ok = await runModuleWrite(
      context,
      () async {
        if (_isEdit) {
          await updateSubject(
              id: widget.existing!.id,
              name: name,
              coefficient: _coef,
              levelId: _levelId,
              clearLevel: _levelId == null);
        } else {
          await createSubject(
              groupId: groupId,
              schoolId: schoolId,
              name: name,
              coefficient: _coef,
              levelId: _levelId);
        }
      },
      success: _isEdit ? 'Matière mise à jour' : 'Matière créée',
    );
    if (ok && mounted) Navigator.pop(context);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final structure =
        ref.watch(academicStructureProvider).valueOrNull ?? AcademicStructure.empty;
    // Items niveau : Tronc commun + niveaux de l'école (groupés par cycle).
    final levelItems = <(String?, String)>[
      (null, 'Tronc commun (toutes les classes)'),
      for (final c in structure.cycles)
        for (final l in c.levels) (l.id, '${c.name} · ${l.name}'),
    ];
    final hasLevel = _levelId == null ||
        levelItems.any((e) => e.$1 == _levelId);

    return AdminFormDialog(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Modifier la matière' : 'Nouvelle matière',
      subtitle: 'Portée par un niveau · le coefficient pèse dans la moyenne',
      width: 480,
      saving: _saving,
      submitLabel: _isEdit ? 'Enregistrer' : 'Créer',
      submitIcon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
      onSubmit: _saving ? null : _save,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Nom de la matière *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5),
          decoration:
              adminFilledInput('Ex. Mathématiques', icon: Icons.menu_book_outlined),
        ),
        const SizedBox(height: 16),
        const Text('Niveau',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: hasLevel ? _levelId : null,
          isExpanded: true,
          style: const TextStyle(fontSize: 13.5, color: kTextPrimary),
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: kTextMuted),
          decoration: adminFilledInput('Tronc commun'),
          items: [
            for (final e in levelItems)
              DropdownMenuItem(value: e.$1, child: Text(e.$2)),
          ],
          onChanged: (v) => setState(() => _levelId = v),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
              'Le coefficient peut différer d\'un niveau à l\'autre : créez une '
              'entrée par niveau (ex. Maths en 6e ≠ Maths en Tle).',
              style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.35)),
        ),
        const SizedBox(height: 16),
        const Text('Coefficient',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          _StepBtn(
              icon: Icons.remove_rounded,
              onTap: () => setState(() => _coef = (_coef - 1).clamp(1, 20))),
          Expanded(
            child: Center(
              child: Text('$_coef',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kNavy)),
            ),
          ),
          _StepBtn(
              icon: Icons.add_rounded,
              onTap: () => setState(() => _coef = (_coef + 1).clamp(1, 20))),
        ]),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Icon(icon, size: 20, color: kNavy),
          ),
        ),
      );
}

// ─── Barre d'actions groupées ────────────────────────────────────────────────
class _SubjectBulkBar extends StatelessWidget {
  const _SubjectBulkBar({
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
