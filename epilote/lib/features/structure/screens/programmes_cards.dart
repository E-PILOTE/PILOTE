part of 'programmes_screen.dart';

// ─── Vue cartes ────────────────────────────────────────────────────────────

class _ProgCards extends ConsumerWidget {
  const _ProgCards(
      {required this.rows,
      required this.onEdit,
      required this.onDelete,
      required this.onOpen});
  final List<ProgrammeRow> rows;
  final ValueChanged<ProgrammeRow> onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(yearReadOnlyProvider);
    final canEdit =
        ref.watch(canProvider((slug: _kSlug, action: 'update'))) && !readOnly;
    final canDelete =
        ref.watch(canProvider((slug: _kSlug, action: 'delete'))) && !readOnly;
    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 1180 ? 3 : (w >= 760 ? 2 : 1);
      const gap = 14.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in rows)
            SizedBox(
              width: cardW,
              child: _ProgCard(
                p: p,
                canEdit: canEdit && !p.isShared,
                canDelete: canDelete && !p.isShared,
                onEdit: () => onEdit(p),
                onDelete: () => onDelete(p),
                onOpen: () => onOpen(p),
              ),
            ),
        ],
      );
    });
  }
}

class _ProgCard extends StatelessWidget {
  const _ProgCard({
    required this.p,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });
  final ProgrammeRow p;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _cyc(p.cycleCode);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: col,
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Supprimer',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 17, color: kRed),
              onPressed: onDelete,
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          AdminBadge(p.subjectName, color: col),
          AdminBadge(p.levelLabel, color: kNavy),
          AdminBadge(p.trimesterLabelOrAll, color: kTextMuted),
          if (p.isOfficial)
            AdminBadge('Officiel', color: kGreen)
          else if (p.isShared)
            AdminBadge('Partagé', color: kNavy),
        ]),
        if (p.hasContent) ...[
          const SizedBox(height: 10),
          Text(p.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: kTextMuted, height: 1.4)),
        ],
      ]),
    );
  }
}

// (Vue « Par cycle » premium → programmes_cycle_view.dart)
