part of '../audit_screen.dart';

// Barre de filtres, bascule de vue, en-tête.

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterAction,
    required this.filterRole,
    required this.filterTable,
    required this.tables,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onAction,
    required this.onRole,
    required this.onTable,
    required this.onSort,
    required this.onToggleView,
    required this.onRefresh,
    required this.onReset,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterAction, filterRole, filterTable, sort;
  final List<String> tables;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onAction, onRole, onTable, onSort;
  final VoidCallback onToggleView, onRefresh, onReset;

  @override
  Widget build(BuildContext context) {
    final tableItems = <String, String>{'tous': 'Toutes les tables'};
    for (final t in tables) {
      tableItems[t] = AuditLog(
        id: '', userId: '', action: '', tableName: t,
        createdAt: DateTime.now(),
      ).tableLabel;
    }

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
                  hintText: 'Rechercher par table, action, utilisateur…',
                  hintStyle: TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: _kMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true, fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                message: 'Rafraîchir le journal',
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _kSurface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 20, color: _kNavy),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FilterDropdown(
              icon: Icons.flash_on_rounded, label: 'Action',
              items: const {
                'tous':   'Toutes les actions',
                'INSERT': 'Créations',
                'UPDATE': 'Modifications',
                'DELETE': 'Suppressions',
              },
              value: filterAction, onChanged: onAction, active: filterAction != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.badge_rounded, label: 'Rôle',
              items: const {
                'tous':          'Tous les rôles',
                'super_admin':   'Super Admin',
                'admin_groupe':  'Admin Groupe',
                'directeur':     'Directeur',
                'enseignant':    'Enseignant',
                'comptable':     'Comptable',
              },
              value: filterRole, onChanged: onRole, active: filterRole != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.table_chart_rounded, label: 'Table',
              items: tableItems,
              value: tableItems.containsKey(filterTable) ? filterTable : 'tous',
              onChanged: onTable, active: filterTable != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded, label: 'Trier',
              items: const {
                'recent': 'Plus récents',
                'az':     'Table A → Z',
                'action': 'Par action',
              },
              value: sort, onChanged: onSort, active: sort != 'recent',
            ),
            const Spacer(),
            if (filterAction != 'tous' || filterRole != 'tous' || filterTable != 'tous' || sort != 'recent')
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
  const _FilterDropdown({
    required this.icon, required this.label, required this.items,
    required this.value, required this.onChanged, required this.active,
  });
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: kCardBg,
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
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: _kNavy,
          ),
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
    Text('$filtered événement${filtered > 1 ? "s" : ""}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────
