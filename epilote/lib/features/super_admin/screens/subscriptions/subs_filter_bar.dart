import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';
import 'subs_style.dart';

// ─── Recherche, filtres, bascule tableau/cartes ──────────────────────────
//  ⚠️ Le bouton « Nouvel abonnement » NE CRÉE PAS de groupe : il renvoie vers
//  l'écran des groupes, seul endroit qui demande la tutelle. La décision est
//  commentée au point d'appel, dans la coquille.

class SubFilterBar extends StatelessWidget {
  const SubFilterBar({
    super.key,
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterType,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onType,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterType, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onType, onSort;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: contentWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSubBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kSubBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par groupe, e-mail, plan, département…',
                  hintStyle: TextStyle(color: kSubMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: kSubMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: kSubMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true,
                  fillColor: kSubSurface,
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
                      color: kSubSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kSubBorder),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 20, color: kSubMuted),
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
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvel abonnement', style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    )),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded,
              label: 'Statut',
              items: const {
                'tous':      'Tous les statuts',
                'trial':     'Essai',
                'active':    'Actif',
                'suspended': 'Suspendu',
                'expired':   'Expiré',
                'cancelled': 'Annulé',
              },
              value: filterStatus,
              onChanged: onStatus,
              active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.category_rounded,
              label: 'Type',
              items: const {
                'tous':   'Tous les types',
                'public': 'Public',
                'prive':  'Privé',
              },
              value: filterType,
              onChanged: onType,
              active: filterType != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded,
              label: 'Trier',
              items: const {
                'recent':   'Plus récents',
                'az':       'A → Z',
                'za':       'Z → A',
                'echeance': 'Échéance proche',
                'revenu':   'Meilleur revenu',
              },
              value: sort,
              onChanged: onSort,
              active: sort != 'recent',
            ),
            const Spacer(),
            if (filterStatus != 'tous' || filterType != 'tous' || sort != 'recent')
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: kSubRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kSubRed.withValues(alpha: 0.25)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: kSubRed),
                      SizedBox(width: 4),
                      Text('Réinitialiser', style: TextStyle(
                          color: kSubRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
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
      color: active ? kSubNavy : kSubSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? kSubNavy : kSubBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: kCardBg,
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : kSubMuted),
        style: TextStyle(
          color: active ? Colors.white : kSubMuted,
          fontSize: 12.5, fontWeight: FontWeight.w600,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value),
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
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kSubSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kSubBorder),
          ),
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: kSubNavy,
          ),
        ),
      ),
    ),
  );
}

class SubResultHeader extends StatelessWidget {
  const SubResultHeader({super.key, required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? "s" : ""}',
        style: TextStyle(color: kSubText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: kSubMuted, fontSize: 13)),
    ],
  ]);
}
