part of '../admin_schools_screen.dart';

// Barre de filtres + actions groupées

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterType,
    required this.filterStatus,
    required this.filterDept,
    required this.isTableView,
    required this.quotaReached,
    required this.onSearchChange,
    required this.onType,
    required this.onStatus,
    required this.onDept,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterType, filterStatus, filterDept;
  final bool   isTableView;
  final bool   quotaReached;
  final ValueChanged<String> onSearchChange, onType, onStatus, onDept;
  final VoidCallback onToggleView, onReset, onAdd;

  bool get _hasFilters =>
      filterType != 'tous' || filterStatus != 'tous' || filterDept != 'tous';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: 'Rechercher une école, code, ville, département…',
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
            child: Tooltip(
              message: quotaReached ? 'Quota atteint pour ce plan' : '',
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: quotaReached
                          ? [kTextMuted, kTextMuted]
                          : const [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: quotaReached
                        ? []
                        : [BoxShadow(
                            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvelle école', style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    )),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _FilterDropdown(
            icon: Icons.category_outlined, label: 'Type',
            items: const {
              'tous': 'Tous les types',
              'public': 'Public',
              'prive': 'Privé',
              'mixte': 'Mixte',
            },
            value: filterType, onChanged: onType, active: filterType != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded, label: 'Statut',
            items: const {
              'tous': 'Tous les statuts',
              'active': 'Active',
              'inactive': 'Inactive',
            },
            value: filterStatus, onChanged: onStatus, active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.location_on_rounded, label: 'Département',
            items: {
              'tous': 'Tous',
              for (final d in _kDepartements) d: d,
            },
            value: filterDept, onChanged: onDept, active: filterDept != 'tous',
          ),
          const Spacer(),
          if (_hasFilters)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                    const SizedBox(width: 4),
                    Text('Réinitialiser', style: TextStyle(
                      color: kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
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
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: kNavy,
          ),
        ),
      ),
    ),
  );
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
    constraints: const BoxConstraints(minWidth: 140),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: Icon(Icons.expand_more_rounded, size: 14,
            color: active ? kNavy : kTextMuted),
        style: TextStyle(
          color: active ? kNavy : kTextPrimary,
          fontSize: 12.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: kTextMuted),
            const SizedBox(width: 6),
            Text(e.value),
          ]),
        )).toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? 's' : ''}',
        style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: kTextMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Case à cocher compacte ─────────────────────────────────────────────────
class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: checked ? kNavy : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: checked ? kNavy : kBorder, width: 1.5),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ),
      );
}

// ─── Barre d'actions groupées ───────────────────────────────────────────────
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.activeCount,
    required this.onActivate,
    required this.onDeactivate,
    required this.onClear,
  });
  final int count;
  final int activeCount;
  final VoidCallback onActivate, onDeactivate, onClear;

  @override
  Widget build(BuildContext context) {
    final inactiveCount = count - activeCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: kNavy.withValues(alpha: 0.25),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        const Flexible(child: Text('école(s) sélectionnée(s)',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
        const Spacer(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (inactiveCount > 0)
            _BulkBtn(
              icon: Icons.check_circle_outline_rounded,
              label: 'Activer',
              onTap: onActivate,
            ),
          if (activeCount > 0)
            _BulkBtn(
              icon: Icons.block_rounded,
              label: 'Désactiver',
              onTap: onDeactivate,
            ),
          _BulkBtn(
            icon: Icons.close_rounded,
            label: 'Effacer',
            subtle: true,
            onTap: onClear,
          ),
        ]),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.icon, required this.label, required this.onTap,
    this.subtle = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: subtle ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: subtle ? Colors.white.withValues(alpha: 0.4) : Colors.white,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: subtle ? Colors.white : kNavy),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                  color: subtle ? Colors.white : kNavy,
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

