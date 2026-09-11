part of '../admin_modules_screen.dart';

// Legende, barre de filtres, bascule de vue.

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
    ]);
  }
}


// ── Filter bar ────────────────────────────────────────────────────────────────

class _ModuleFilterBar extends StatelessWidget {
  const _ModuleFilterBar({
    required this.catalog,
    required this.catColors,
    required this.searchCtrl,
    required this.filterCat,
    required this.filterStatus,
    required this.filterModuleId,
    required this.filterSchoolId,
    required this.schoolNames,
    required this.sortBy,
    required this.sortAsc,
    required this.isCardView,
    required this.onSearchChange,
    required this.onFilterCat,
    required this.onFilterStatus,
    required this.onFilterModule,
    required this.onFilterSchool,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.resultCount,
    required this.totalCount,
  });
  final AdminModulesCatalog catalog;
  final Map<String, Color> catColors;
  final TextEditingController searchCtrl;
  final String filterCat;
  final String filterStatus;
  final String? filterModuleId;
  final String? filterSchoolId;
  final Map<String, String> schoolNames;
  final String sortBy;
  final bool sortAsc;
  final bool isCardView;
  final void Function(String) onSearchChange;
  final void Function(String) onFilterCat;
  final void Function(String) onFilterStatus;
  final void Function(String?) onFilterModule;
  final void Function(String?) onFilterSchool;
  final void Function(String) onSort;
  final VoidCallback onToggleView;
  final VoidCallback onReset;
  final int resultCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final catOptions = <(String, String)>[
      ('tous', 'Toutes catégories'),
      for (final c in catalog.categories) (c.slug, c.name),
    ];
    // Options écoles pour le dropdown
    final schoolOptions = <(String?, String)>[
      (null, 'Toutes les écoles'),
      for (final e in schoolNames.entries) (e.key, e.value),
    ];
    // Options modules : restreintes à la catégorie sélectionnée si nécessaire
    final moduleOptions = <(String?, String)>[
      (null, 'Tous les modules'),
      for (final cat in catalog.categories)
        if (filterCat == 'tous' || cat.slug == filterCat)
          for (final m in cat.modules)
            if (m.id != null) (m.id, m.name),
    ];

    final hasFilter = searchCtrl.text.isNotEmpty ||
        filterCat != 'tous' ||
        filterStatus != 'tous' ||
        filterModuleId != null ||
        filterSchoolId != null;

    // Ligne 1 : filtres (Wrap pour éviter tout overflow)
    final filterRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Recherche
        SizedBox(
          width: 200,
          height: 36,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChange,
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 17, color: kTextMuted),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () => onSearchChange(''),
                      child: Icon(Icons.clear_rounded,
                          size: 15, color: kTextMuted),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 0),
              filled: true,
              fillColor: kCardBg,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: kNavy, width: 1.5)),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // Catégorie (avec point coloré par catégorie)
        _DropFilter<String>(
          value: filterCat,
          items: catOptions.map((t) {
            final dotColor = t.$1 == 'tous' ? null : catColors[t.$1];
            return DropdownMenuItem<String>(
              value: t.$1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(t.$2),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => onFilterCat(v ?? 'tous'),
        ),
        // Statut
        _DropFilter<String>(
          value: filterStatus,
          items: const [
            DropdownMenuItem(value: 'tous', child: Text('Tous statuts')),
            DropdownMenuItem(value: 'active', child: Text('Activés')),
            DropdownMenuItem(
                value: 'inactive', child: Text('Non activés')),
          ],
          onChanged: (v) => onFilterStatus(v ?? 'tous'),
        ),
        // École (filtrage transversal)
        if (schoolOptions.length > 1)
          _DropFilter<String?>(
            value: filterSchoolId,
            items: schoolOptions
                .map((t) => DropdownMenuItem<String?>(
                    value: t.$1,
                    child: Text(
                      t.$2.length > 20
                          ? '${t.$2.substring(0, 18)}…'
                          : t.$2,
                    )))
                .toList(),
            onChanged: (v) => onFilterSchool(v),
          ),
        // Module spécifique (filtrage transversal)
        if (moduleOptions.length > 1)
          _DropFilter<String?>(
            value: filterModuleId,
            items: moduleOptions
                .map((t) => DropdownMenuItem<String?>(
                    value: t.$1,
                    child: Text(
                      t.$2.length > 22
                          ? '${t.$2.substring(0, 20)}…'
                          : t.$2,
                    )))
                .toList(),
            onChanged: (v) => onFilterModule(v),
          ),
        // Tri
        _DropFilter<String>(
          value: sortBy,
          items: const [
            DropdownMenuItem(value: 'nom', child: Text('Trier : Nom')),
            DropdownMenuItem(
                value: 'couverture',
                child: Text('Trier : Couverture')),
            DropdownMenuItem(
                value: 'categorie',
                child: Text('Trier : Catégorie')),
          ],
          onChanged: (v) => onSort(v ?? 'nom'),
        ),
        // ASC/DESC
        Tooltip(
          message: sortAsc ? 'Croissant' : 'Décroissant',
          child: InkWell(
            onTap: () => onSort(sortBy),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(
                sortAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: kNavy,
              ),
            ),
          ),
        ),
        // Reset (si filtre actif)
        if (hasFilter)
          Tooltip(
            message: 'Réinitialiser tous les filtres',
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: Icon(Icons.filter_alt_off_rounded,
                    size: 16, color: kRed),
              ),
            ),
          ),
      ],
    );

    // Ligne 2 : compteur + toggle vue
    final summaryRow = Row(children: [
      Text(
        '$resultCount / $totalCount module${totalCount > 1 ? "s" : ""}',
        style: TextStyle(fontSize: 12.5, color: kTextMuted),
      ),
      const Spacer(),
      Container(
        height: 36,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ViewBtn(
            icon: Icons.grid_view_rounded,
            active: isCardView,
            onTap: isCardView ? null : onToggleView,
            isLeft: true,
          ),
          Container(width: 1, color: kBorder),
          _ViewBtn(
            icon: Icons.table_rows_rounded,
            active: !isCardView,
            onTap: isCardView ? onToggleView : null,
            isLeft: false,
          ),
        ]),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterRow,
        const SizedBox(height: 8),
        summaryRow,
      ],
    );
  }
}

class _DropFilter<T> extends StatelessWidget {
  const _DropFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(fontSize: 13, color: kTextPrimary),
          icon: Icon(Icons.expand_more_rounded,
              size: 16, color: kTextMuted),
        ),
      ),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  const _ViewBtn({
    required this.icon,
    required this.active,
    required this.isLeft,
    this.onTap,
  });
  final IconData icon;
  final bool active;
  final bool isLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLeft
          ? const BorderRadius.horizontal(left: Radius.circular(7))
          : const BorderRadius.horizontal(right: Radius.circular(7)),
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        color: active
            ? kNavy.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Icon(icon, size: 18, color: active ? kNavy : kTextMuted),
      ),
    );
  }
}

// ── Card grid ─────────────────────────────────────────────────────────────────
