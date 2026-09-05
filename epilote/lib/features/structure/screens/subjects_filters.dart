part of 'subjects_screen.dart';

// ─── Barre de filtres, en-tête de résultats, badges de niveaux ─────────────

class _SubjectFilterBar extends StatelessWidget {
  const _SubjectFilterBar({
    required this.searchCtrl,
    required this.isTable,
    required this.sort,
    required this.sortAsc,
    required this.onSearch,
    required this.onSort,
    required this.onToggleView,
    required this.onAdd,
  });
  final TextEditingController searchCtrl;
  final bool isTable, sortAsc;
  final String sort;
  final ValueChanged<String> onSearch, onSort;
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
                width: 240,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: adminFilledInput('Rechercher une matière',
                      icon: Icons.search_rounded),
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
              _SortChip(
                  label: 'Classes',
                  active: sort == 'classes',
                  asc: sortAsc,
                  onTap: () => onSort('classes')),
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
                    style: TextStyle(
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

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(
      {required this.total, required this.filtered, this.onExportPdf});
  final int total, filtered;
  final VoidCallback? onExportPdf;
  @override
  Widget build(BuildContext context) {
    final txt = filtered == total
        ? _pl(total, 'matière', 'matières')
        : '$filtered / ${_pl(total, 'matière', 'matières')}';
    return Row(children: [
      Icon(Icons.menu_book_outlined, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Text(txt,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const Spacer(),
      if (onExportPdf != null) AdminPdfButton(onTap: onExportPdf!),
    ]);
  }
}

class _NiveauxCell extends StatelessWidget {
  const _NiveauxCell({required this.niveaux, required this.assigned});
  final List<String> niveaux;
  final bool assigned;
  @override
  Widget build(BuildContext context) {
    if (niveaux.isEmpty) {
      return Text(assigned ? '—' : 'Non affectée',
          style: TextStyle(fontSize: 12, color: kTextMuted));
    }
    const cap = 4;
    final shown = niveaux.length > cap ? niveaux.sublist(0, cap) : niveaux;
    final extra = niveaux.length - shown.length;
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (final n in shown) AdminBadge(n, color: kNavy),
      if (extra > 0)
        Text('+$extra',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
    ]);
  }
}
