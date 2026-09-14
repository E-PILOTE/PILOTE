part of 'programmes_screen.dart';

// ─── Vue table ─────────────────────────────────────────────────────────────

class _ProgTable extends ConsumerWidget {
  const _ProgTable({
    required this.rows,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final List<ProgrammeRow> rows;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(yearReadOnlyProvider);
    final canEdit =
        ref.watch(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    final canDelete =
        ref.watch(canProvider((slug: _kSlug, action: 'delete'))) && !readOnly;
    final canBulk = canEdit || canDelete;
    final allSel =
        rows.isNotEmpty && rows.every((p) => selected.contains(p.id));
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
            const _Th('PROGRAMME', flex: 6),
            const _Th('MATIÈRE', flex: 3),
            const _Th('NIVEAU', flex: 2),
            const _Th('TRIMESTRE', flex: 2),
            const _Th('TYPE', flex: 2),
            const SizedBox(width: 120),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _ProgRow(
            p: rows[i],
            last: i == rows.length - 1,
            canEdit: canEdit,
            canDelete: canDelete,
            canBulk: canBulk,
            selected: selected.contains(rows[i].id),
            onSelect: (v) => onSelect(rows[i].id, v),
            onEdit: () => onEdit(rows[i]),
            onDelete: () => onDelete(rows[i]),
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
  const _Th(this.label, {required this.flex});
  final String label;
  final int flex;
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _ProgRow extends StatelessWidget {
  const _ProgRow({
    required this.p,
    required this.last,
    required this.canEdit,
    required this.canDelete,
    required this.canBulk,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final ProgrammeRow p;
  final bool last, canEdit, canDelete, canBulk, selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(p.cycleCode);
    final canMutate = !p.isShared; // les programmes partagés (groupe) sont en lecture seule
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
            _Check(value: selected, onChanged: canMutate ? onSelect : (_) {}),
            const SizedBox(width: 6),
          ],
          Expanded(
            flex: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  if (p.hasContent) ...[
                    const SizedBox(height: 2),
                    Text(p.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ]),
          ),
          Expanded(
            flex: 3,
            child: Text(p.subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(p.levelLabel, color: col)),
          ),
          Expanded(
            flex: 2,
            child: Text(p.trimesterLabelOrAll,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: p.isOfficial
                  ? AdminBadge('Officiel', color: kGreen)
                  : AdminBadge(p.isShared ? 'Partagé' : 'Perso',
                      color: p.isShared ? kNavy : const Color(0xFFF59E0B)),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canEdit && canMutate)
                IconButton(
                  tooltip: 'Modifier',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined, size: 18, color: kNavy),
                  onPressed: onEdit,
                ),
              if (canDelete && canMutate)
                IconButton(
                  tooltip: 'Supprimer',
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                  onPressed: onDelete,
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
