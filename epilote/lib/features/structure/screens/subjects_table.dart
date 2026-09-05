part of 'subjects_screen.dart';

// ─── Vue table ─────────────────────────────────────────────────────────────

class _SubjectTable extends ConsumerWidget {
  const _SubjectTable({
    required this.rows,
    required this.sort,
    required this.sortAsc,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onSort,
    required this.onEdit,
    required this.onArchive,
    required this.onOpen,
  });
  final List<SubjectModel> rows;
  final String sort;
  final bool sortAsc;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<String> onSort;
  final ValueChanged<SubjectModel> onEdit, onArchive, onOpen;

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
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
            _Th('COEF. PAR DÉFAUT',
                flex: 3,
                asc: sort == 'coef' ? sortAsc : null,
                onTap: () => onSort('coef')),
            const _Th('NIVEAUX', flex: 4),
            _Th('CLASSES',
                flex: 2,
                asc: sort == 'classes' ? sortAsc : null,
                onTap: () => onSort('classes')),
            const SizedBox(width: 128),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _SubjectRow(
            s: rows[i],
            last: i == rows.length - 1,
            canEdit: canEdit,
            canDelete: canDelete,
            canBulk: canBulk,
            selected: selected.contains(rows[i].id),
            onSelect: (v) => onSelect(rows[i].id, v),
            onEdit: () => onEdit(rows[i]),
            onArchive: () => onArchive(rows[i]),
            onOpen: () => onOpen(rows[i]),
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
          side: BorderSide(color: kTextMuted, width: 1.5),
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
            style: TextStyle(
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
    required this.last,
    required this.canEdit,
    required this.canDelete,
    required this.canBulk,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onArchive,
    required this.onOpen,
  });
  final SubjectModel s;
  final bool last, canEdit, canDelete, canBulk, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit, onArchive, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kNavy.withValues(alpha: 0.04) : null,
          border:
              last ? null : Border(bottom: BorderSide(color: kBorder)),
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
                    style: TextStyle(
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
              child: AdminBadge('Coef. ${s.coefficient}', color: kGreen),
            ),
          ),
          Expanded(
            flex: 4,
            child: _NiveauxCell(niveaux: s.niveaux, assigned: s.isAssigned),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: s.classCount == 0
                  ? Text('—',
                      style: TextStyle(fontSize: 12.5, color: kTextMuted))
                  : AdminBadge(_pl(s.classCount, 'classe', 'classes'),
                      color: kNavy),
            ),
          ),
          SizedBox(
            width: 128,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canEdit)
                IconButton(
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined, size: 18, color: kNavy),
                  onPressed: onEdit,
                ),
              if (canDelete)
                IconButton(
                  tooltip: 'Archiver',
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.archive_outlined, size: 18, color: kRed),
                  onPressed: onArchive,
                ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: kTextMuted),
            ]),
          ),
        ]),
      ),
    );
  }
}
