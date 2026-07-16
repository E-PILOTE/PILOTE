part of 'notes_screen.dart';

// ─── Liste des évaluations (cartes) ──────────────────────────────────────────
class _EvalList extends StatelessWidget {
  const _EvalList({
    required this.items,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });
  final List<Evaluation> items;
  final bool canEdit, canDelete;
  final ValueChanged<Evaluation> onOpen, onEdit, onDelete;
  final void Function(Evaluation, String) onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in items)
          _EvalCard(
            e: e,
            canEdit: canEdit,
            canDelete: canDelete,
            onOpen: () => onOpen(e),
            onEdit: () => onEdit(e),
            onDelete: () => onDelete(e),
            onStatus: (s) => onStatus(e, s),
          ),
      ],
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({
    required this.e,
    required this.canEdit,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });
  final Evaluation e;
  final bool canEdit, canDelete;
  final VoidCallback onOpen, onEdit, onDelete;
  final ValueChanged<String> onStatus;

  Color get _statusColor => switch (e.status) {
        'published' => kGreen,
        'validated' => const Color(0xFF0EA5E9),
        'submitted' => const Color(0xFFF59E0B),
        _ => kTextMuted,
      };

  @override
  Widget build(BuildContext context) {
    final progress = e.studentCount == 0 ? 0.0 : e.gradedCount / e.studentCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                    e.average != null ? e.average!.toStringAsFixed(1) : '—',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: e.average != null ? kNavy : kTextMuted)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary)),
                      ),
                      const SizedBox(width: 8),
                      _Badge(
                          label: evaluationTypeLabel(e.type),
                          color: kNavy.withValues(alpha: 0.7)),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        '${e.subjectName ?? '—'} · ${e.className ?? '—'} · '
                        '${e.dateLabel} · /${e.maxScore.toStringAsFixed(0)} · '
                        'coeff ${e.coefficient}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12, color: kTextMuted)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: kSurface,
                            valueColor: AlwaysStoppedAnimation(
                                e.isComplete ? kGreen : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.gradedCount}/${e.studentCount} notes',
                          style: TextStyle(
                              fontSize: 11, color: kTextMuted)),
                    ]),
                  ]),
            ),
            const SizedBox(width: 10),
            _Badge(label: evalStatusLabel(e.status), color: _statusColor),
            _CardMenu(
              e: e,
              canEdit: canEdit,
              canDelete: canDelete,
              onEdit: onEdit,
              onDelete: onDelete,
              onStatus: onStatus,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.e,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });
  final Evaluation e;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    // Transition de statut suivante possible.
    final next = switch (e.status) {
      'draft' => ('submitted', 'Soumettre'),
      'submitted' => ('validated', 'Valider'),
      'validated' => ('published', 'Publier'),
      _ => null,
    };
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
          case 'back':
            onStatus('draft');
          default:
            onStatus(v);
        }
      },
      itemBuilder: (ctx) => [
        if (next != null && canEdit)
          PopupMenuItem(
              value: next.$1,
              child: Row(children: [
                const Icon(Icons.arrow_forward_rounded, size: 16),
                const SizedBox(width: 8),
                Text(next.$2),
              ])),
        if (e.status != 'draft' && e.status != 'published' && canEdit)
          const PopupMenuItem(
              value: 'back',
              child: Row(children: [
                Icon(Icons.undo_rounded, size: 16),
                SizedBox(width: 8),
                Text('Repasser en brouillon'),
              ])),
        if (canEdit && !e.isPublished)
          const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 16),
                SizedBox(width: 8),
                Text('Modifier'),
              ])),
        if (canDelete)
          PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                const SizedBox(width: 8),
                Text('Supprimer', style: TextStyle(color: kRed)),
              ])),
      ],
    );
  }
}
