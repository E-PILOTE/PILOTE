part of 'announcements_screen.dart';

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterAudience,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onAudience,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });
  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterAudience, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onAudience, onSort;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: contentWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par titre, contenu, groupe…',
                  hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true, fillColor: _kSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Réinitialiser',
                child: InkWell(
                  onTap: onReset, borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: _kSurface,
                        borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                    child: const Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvelle annonce', style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded, label: 'Statut',
              items: const {
                'tous':      'Tous les statuts',
                'publiee':   'Publiées',
                'brouillon': 'Brouillons',
                'epinglee':  'Épinglées',
                'expiree':   'Expirées',
              },
              value: filterStatus, onChanged: onStatus, active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.people_rounded, label: 'Audience',
              items: const {
                'tous':     'Toutes les audiences',
                'all':      'Tout le monde',
                'staff':    'Personnel',
                'teachers': 'Enseignants',
                'parents':  'Parents',
                'students': 'Élèves',
              },
              value: filterAudience, onChanged: onAudience, active: filterAudience != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded, label: 'Trier',
              items: const {
                'recent': 'Plus récentes',
                'az':     'A → Z',
                'za':     'Z → A',
                'groupe': 'Par groupe',
              },
              value: sort, onChanged: onSort, active: sort != 'recent',
            ),
            const Spacer(),
            if (filterStatus != 'tous' || filterAudience != 'tous' || sort != 'recent')
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: _kRed),
                      SizedBox(width: 4),
                      Text('Réinitialiser', style: TextStyle(
                          color: _kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.icon, required this.label, required this.items,
      required this.value, required this.onChanged, required this.active});
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    height: 38, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, size: 18, color: active ? Colors.white : _kMuted),
        style: TextStyle(color: active ? Colors.white : _kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w600),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
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
        onTap: onToggle, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
              size: 18, color: _kNavy),
        ),
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered annonce${filtered > 1 ? "s" : ""}',
        style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: const TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}
