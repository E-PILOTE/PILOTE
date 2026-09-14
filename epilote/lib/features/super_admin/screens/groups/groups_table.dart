part of '../school_groups_screen.dart';

// Vue tableau : en-tête, lignes, bouton d’action.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.groups,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });

  final List<GroupDetail> groups;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;
  final ValueChanged<GroupDetail> onDetail, onEdit, onDelete, onPrint;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const _EmptyState();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          // En-tête
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort),
          // Lignes
          ...groups.asMap().entries.map((e) => _TableRow(
            group:    e.value,
            isOdd:    e.key.isOdd,
            onTap:    () => onDetail(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onPrint:  () => onPrint(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortField, required this.sortAsc, required this.onSort});
  final String sortField;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  Widget _col(String label, String field, {double? flex}) => Expanded(
    flex: (flex ?? 1).toInt(),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w700))),
          const SizedBox(width: 4),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 13,
            color: sortField == field ? _kNavy : _kMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: _kSurface,
    child: Row(children: [
      const SizedBox(width: 38),
      const SizedBox(width: 12),
      _col('NOM DU GROUPE',   'name',    flex: 3),
      _col('DÉPARTEMENT',     'dept'),
      _col('TYPE',            'type'),
      _col('PLAN',            'plan'),
      _col('STATUT',          'status'),
      _col('ÉCOLES',          'schools'),
      _col('FIN ABO.',        'endDate'),
      const SizedBox(width: 92),
    ]),
  );
}

class _TableRow extends ConsumerStatefulWidget {
  const _TableRow({
    required this.group,
    required this.isOdd,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });
  final GroupDetail group;
  final bool isOdd;
  final VoidCallback onTap, onEdit, onDelete, onPrint;

  @override
  ConsumerState<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends ConsumerState<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _hovered
                ? _kNavy.withValues(alpha: 0.04)
                : widget.isOdd
                    ? _kSurface.withValues(alpha: 0.5)
                    : _kBg,
            border: Border(
              bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(children: [
            // Avatar avec logo réel
            _GroupAvatar(name: g.name, size: 38, logoUrl: g.logoUrl),
            const SizedBox(width: 12),
            // Nom + email
            Expanded(flex: 3, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: TextStyle(
                    color: _kText, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                // Le COMPTE, pas le contact : c'est un identifiant qu'on
                // vient lire ici quand un client n'arrive pas à entrer.
                Text(
                    ref.watch(comptesAdminParGroupeProvider).maybeWhen(
                          data: (m) => compteDeConnexion(m, g.id),
                          orElse: () => null,
                        ) ??
                        g.adminEmail,
                    style: TextStyle(color: _kMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            // Département
            Expanded(child: Text(g.department ?? '—',
                style: TextStyle(color: _kText, fontSize: 12.5),
                overflow: TextOverflow.ellipsis)),
            // Type
            Expanded(child: _TypeBadge(type: g.groupType, label: g.groupTypeLabel)),
            // Plan
            Expanded(child: _PlanBadge(plan: g.planName, price: g.priceXaf)),
            // Statut
            Expanded(child: _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel)),
            // Écoles
            Expanded(child: Row(children: [
              Text('${g.schoolCount}', style: TextStyle(
                  color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
              if (g.maxSchools > 0) Text(' / ${g.maxSchools}',
                  style: TextStyle(color: _kMuted, fontSize: 11)),
            ])),
            // Fin abonnement
            Expanded(child: g.subscriptionEnd != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!),
                        style: TextStyle(
                          color: g.expiresBientot ? _kOrange : _kText,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                    if (g.expiresBientot)
                      const Text('Expire bientôt',
                          style: TextStyle(color: _kOrange, fontSize: 10)),
                  ])
                : Text('—', style: TextStyle(color: _kMuted))),
            // Actions
            SizedBox(
              width: 92,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _ActionBtn(icon: Icons.edit_rounded, color: _kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.print_rounded, color: _kMuted,
                    tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.delete_rounded, color: _kRed,
                    tooltip: 'Supprimer', onTap: widget.onDelete),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
