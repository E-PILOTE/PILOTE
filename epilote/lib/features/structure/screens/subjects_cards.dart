part of 'subjects_screen.dart';

// ─── Vue cartes ────────────────────────────────────────────────────────────

class _SubjectCards extends ConsumerWidget {
  const _SubjectCards(
      {required this.rows, required this.onEdit, required this.onArchive,
      required this.onOpen});
  final List<SubjectModel> rows;
  final ValueChanged<SubjectModel> onEdit, onArchive, onOpen;

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
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () => onEdit(s),
                onArchive: () => onArchive(s),
                onOpen: () => onOpen(s),
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
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onArchive,
    required this.onOpen,
  });
  final SubjectModel s;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onArchive, onOpen;

  @override
  Widget build(BuildContext context) {
    final col = _subjectColor(s.slug);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      accent: col,
      onTap: onOpen,
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
              icon: Icon(Icons.edit_outlined, size: 17, color: kNavy),
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Archiver',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.archive_outlined, size: 17, color: kRed),
              onPressed: onArchive,
            ),
        ]),
        const SizedBox(height: 12),
        Text(s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          AdminBadge('Coef. ${s.coefficient}', color: kGreen),
          const Spacer(),
          Text(
              s.classCount == 0
                  ? 'Non affectée'
                  : _pl(s.classCount, 'classe', 'classes'),
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: s.classCount == 0 ? kTextMuted : kNavy)),
        ]),
        if (s.niveaux.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NiveauxCell(niveaux: s.niveaux, assigned: true),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Spacer(),
          Text('Détails', style: TextStyle(fontSize: 11, color: kTextMuted)),
          Icon(Icons.chevron_right_rounded, size: 15, color: kTextMuted),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE — création / édition (nom + coefficient PAR DÉFAUT via stepper).
//  Le coefficient réel se règle ensuite par classe dans le détail.
// ════════════════════════════════════════════════════════════════════════════
