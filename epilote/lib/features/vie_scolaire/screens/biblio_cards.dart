part of 'bibliotheque_screen.dart';

// ─── Carte ouvrage ───────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final LibraryItem item;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final it = item;
    final availColor = it.available == 0
        ? kRed
        : (it.available < it.quantity ? const Color(0xFFF59E0B) : kGreen);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.menu_book_rounded, size: 19, color: kNavy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                if ((it.author ?? '').isNotEmpty)
                  Text(it.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTextMuted)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: availColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${it.available}/${it.quantity} dispo',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: availColor)),
                  ),
                  if ((it.category ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(it.category!,
                        style: const TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ]),
              ]),
        ),
        if (canEdit || canDelete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: kTextMuted),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (ctx) => [
              if (canEdit)
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ])),
              if (canDelete)
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                      SizedBox(width: 8),
                      Text('Retirer', style: TextStyle(color: kRed)),
                    ])),
            ],
          ),
      ]),
    );
  }
}

// ─── Carte prêt ──────────────────────────────────────────────────────────────
class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.canEdit,
    required this.onReturn,
  });
  final LibraryLoan loan;
  final bool canEdit;
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) {
    final l = loan;
    final color = l.returned
        ? kGreen
        : (l.overdue ? kRed : const Color(0xFF0EA5E9));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
              l.returned
                  ? Icons.assignment_turned_in_rounded
                  : Icons.book_rounded,
              size: 19,
              color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.itemTitle ?? 'Ouvrage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${(l.borrowerName ?? '').isEmpty ? 'Emprunteur' : l.borrowerName} · '
                    'à rendre le ${l.dueDate ?? '—'}'
                    '${l.returned ? ' · rendu le ${l.returnDate}' : ''}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
        ),
        if (l.overdue && !l.returned)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('En retard',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: kRed)),
          ),
        if (!l.returned && canEdit)
          OutlinedButton.icon(
            onPressed: onReturn,
            style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                side: BorderSide(color: kGreen.withValues(alpha: 0.4))),
            icon: const Icon(Icons.assignment_return_rounded, size: 16),
            label: const Text('Retour'),
          )
        else if (l.returned)
          const Icon(Icons.check_circle_rounded, color: kGreen, size: 22),
      ]),
    );
  }
}
