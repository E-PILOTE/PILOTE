part of '../school_groups_screen.dart';

// Barre de filtres, bascule de vue, en-tête de résultats.

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterType,
    required this.filterPlan,
    required this.filterDept,
    required this.departments,
    required this.planNames,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onType,
    required this.onPlan,
    required this.onDept,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String  filterStatus, filterType, filterPlan, filterDept;
  final List<String> departments, planNames;
  final bool    isTableView;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String> onStatus, onType, onPlan, onDept;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    // SizedBox avec largeur explicite pour garantir des contraintes bornées
    // même si le parent transmet une largeur infinie (transition Riverpod).
    return SizedBox(
      width: contentWidth,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ─ Ligne 1 : Search + Toggle vue + Bouton créer ───────────────────────
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: 'Rechercher un groupe, email, département…',
                hintStyle: TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: _kMuted),
                        onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                    : null,
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Toggle table/cards
          _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
          const SizedBox(width: 8),
          // Reset filtres
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
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Créer groupe
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Nouveau groupe', style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // ─ Filtres dropdowns ─────────────────────────────────────────────────
        Row(children: [
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded,
            label: 'Statut',
            items: const {
              'tous': 'Tous les statuts',
              'active': 'Actif',
              'trial': 'Essai',
              'suspended': 'Suspendu',
              'cancelled': 'Résilié',
            },
            value: filterStatus,
            onChanged: onStatus,
            active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.business_rounded,
            label: 'Type',
            // ⚠️ Trois de ces entrées ne pouvaient RIEN rendre : l'enum
            // `group_type` n'accepte que `public` et `prive`, aucune ligne
            // n'a donc jamais porté « catholique ». Le filtre proposait de
            // chercher ce qui ne pouvait pas exister.
            items: {
              'tous': 'Tous les secteurs',
              for (final code in kSecteursGroupe) code: libelleSecteur(code),
            },
            value: filterType,
            onChanged: onType,
            active: filterType != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.inventory_2_rounded,
            label: 'Plan',
            items: {
              'tous': 'Tous les plans',
              for (final p in planNames) p: p,
            },
            value: filterPlan,
            onChanged: onPlan,
            active: filterPlan != 'tous',
          ),
          if (departments.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.location_on_rounded,
              label: 'Département',
              items: {
                'tous': 'Tous',
                for (final d in departments) d: d,
              },
              value: filterDept,
              onChanged: onDept,
              active: filterDept != 'tous',
            ),
          ],
          const Spacer(),
          if (filterStatus != 'tous' || filterType != 'tous' ||
              filterPlan != 'tous' || filterDept != 'tous')
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
      ),  // Container
    );    // SizedBox
  }
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
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
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
    Text('$filtered résultat${filtered > 1 ? 's' : ''}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────
