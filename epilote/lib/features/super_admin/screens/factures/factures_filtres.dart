part of '../invoices_screen.dart';

// Barre de filtres et en-tête de résultats.

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterMethod,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onMethod,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onRefresh,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterMethod, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onMethod, onSort;
  final VoidCallback onToggleView, onReset, onRefresh;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
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
                hintText: 'Rechercher par groupe, N° facture, plan…',
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
          _IconBtn(
            icon: isTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            tooltip: isTableView ? 'Vue cartes' : 'Vue tableau',
            onTap: onToggleView,
          ),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.refresh_rounded, tooltip: 'Actualiser', onTap: onRefresh),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.filter_alt_off_rounded, tooltip: 'Réinitialiser les filtres', onTap: onReset),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded,
            label: 'Statut',
            items: const {
              'tous':      'Tous les statuts',
              'pending':   'En attente',
              'paid':      'Payée',
              'overdue':   'En retard',
              'cancelled': 'Annulée',
            },
            value: filterStatus,
            onChanged: onStatus,
            active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.payment_rounded,
            label: 'Paiement',
            items: const {
              'tous':         'Tous les modes',
              'mtn_money':    'MTN Money',
              'airtel_money': 'Airtel Money',
              'visa':         'Visa/Carte',
              'especes':      'Espèces',
            },
            value: filterMethod,
            onChanged: onMethod,
            active: filterMethod != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.sort_rounded,
            label: 'Trier',
            items: const {
              'recent':   'Plus récentes',
              'az':       'A → Z',
              'za':       'Z → A',
              'montant':  'Montant élevé',
              'echeance': 'Échéance proche',
            },
            value: sort,
            onChanged: onSort,
            active: sort != 'recent',
          ),
          const Spacer(),
          if (filterStatus != 'tous' || filterMethod != 'tous' || sort != 'recent')
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 18, color: _kNavy),
        ),
      ),
    ),
  );
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
  final IconData              icon;
  final String                label;
  final Map<String, String>   items;
  final String                value;
  final ValueChanged<String>  onChanged;
  final bool                  active;

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
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : _kMuted),
        style: TextStyle(
          color: active ? Colors.white : _kMuted,
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

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? "s" : ""}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────
