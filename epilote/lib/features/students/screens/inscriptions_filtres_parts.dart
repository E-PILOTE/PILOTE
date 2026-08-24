part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA BARRE DE FILTRES — recherche, filière, type, portée, statut, tri, et la
//  bascule liste/tableau, plus le bouton d'ajout d'un dossier.
//
//  Le plus large des trois bandeaux : chaque contrôle porte son propre widget
//  (_ScopeChip, _IconBtn, _FilterDropdown, _StatusSegment) parce qu'ils
//  se répètent d'un filtre à l'autre.
// ════════════════════════════════════════════════════════════════════════════

// ─── Barre de filtres (style plateforme) ─────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.width,
    required this.searchCtrl,
    required this.filiere,
    required this.type,
    required this.status,
    required this.isTable,
    required this.readOnly,
    required this.filieresPresent,
    required this.onSearch,
    required this.onFiliere,
    required this.onType,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
    required this.onExport,
  });
  final double width;
  final TextEditingController searchCtrl;
  final String? filiere, type;
  final String status;
  final bool isTable, readOnly;
  final List<String> filieresPresent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onFiliere, onType;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd, onExport;

  bool get _hasFilters =>
      filiere != null || type != null || status != 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
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
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, matricule)…',
                hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: kTextMuted),
                        onPressed: () { searchCtrl.clear(); onSearch(''); })
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
          _IconBtn(
            icon: isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            tooltip: isTable ? 'Vue en cartes' : 'Vue en tableau',
            color: kNavy,
            onTap: onToggleView,
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.download_rounded,
            tooltip: 'Exporter en CSV',
            color: kGreen,
            onTap: onExport,
          ),
          const SizedBox(width: 12),
          _AddButton(readOnly: readOnly, onAdd: onAdd),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (filieresPresent.isNotEmpty)
              _FilterDropdown<String?>(
                icon: Icons.workspaces_outlined,
                value: filiere,
                active: filiere != null,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Toutes les filières')),
                  for (final f in filieresPresent)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: onFiliere,
              ),
            _FilterDropdown<String?>(
              icon: Icons.category_outlined,
              value: type,
              active: type != null,
              items: const [
                DropdownMenuItem(value: null, child: Text('Tous les types')),
                DropdownMenuItem(value: 'new', child: Text('Nouvelles')),
                DropdownMenuItem(
                    value: 'reinscription', child: Text('Réinscriptions')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferts')),
              ],
              onChanged: onType,
            ),
            _StatusSegment(value: status, onChanged: onStatus),
            if (_hasFilters)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                      const SizedBox(width: 4),
                      Text('Réinitialiser',
                          style: TextStyle(
                              color: kRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

// Bandeau de filtre actif (scope choisi dans le panneau de répartition).
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kNavy.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(width: 2),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15, color: kNavy),
              ),
            ),
          ]),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.readOnly, required this.onAdd});
  final bool readOnly;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: kAccent),
          const SizedBox(width: 6),
          Text('Année verrouillée',
              style: TextStyle(
                  color: kAccent, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return PermissionGate(
      slug: 'inscriptions',
      action: 'create',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavyDark, kNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('Inscrire',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.active,
  });
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? kNavy : kTextMuted),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                icon: Icon(Icons.expand_more_rounded,
                    size: 14, color: active ? kNavy : kTextMuted),
                isExpanded: true,
                style: TextStyle(
                  color: active ? kNavy : kTextPrimary,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ]),
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
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('pending_validation', 'En attente'),
        seg('rejected', 'Rejetées'),
        seg('withdrawn', 'Sorties'),
      ]),
    );
  }
}
