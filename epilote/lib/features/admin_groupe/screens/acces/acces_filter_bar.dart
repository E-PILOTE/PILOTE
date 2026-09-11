part of '../admin_access_screen.dart';

// Barre de filtres, segments de statut, en-tete de resultats.

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.statusFilter,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String statusFilter;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChange,
            decoration: InputDecoration(
              hintText: 'Rechercher un profil (nom, description)…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: kTextMuted),
                      onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                  : null,
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StatusSegment(value: statusFilter, onChanged: onStatus),
        const SizedBox(width: 12),
        _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Réinitialiser les filtres',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: Icon(Icons.refresh_rounded, size: 20, color: kTextMuted),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6D28D9), _kPurple]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Nouveau', style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    ),
  );
}

class _ToggleViewBtn extends StatelessWidget {
  const _ToggleViewBtn({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Tooltip(
      message: isTable ? 'Vue en cartes' : 'Vue en tableau',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
              size: 18, color: kNavy),
        ),
      ),
    ),
  );
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : kTextMuted,
          )),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('active', 'Actifs'),
        seg('inactive', 'Inactifs'),
      ]),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered profil${filtered > 1 ? 's' : ''}',
        style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: kTextMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────
