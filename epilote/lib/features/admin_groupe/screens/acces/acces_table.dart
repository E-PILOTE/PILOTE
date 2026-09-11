part of '../admin_access_screen.dart';

// Vue tableau : lignes, boutons et menu contextuel.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.profiles, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit,
    required this.onPermissions, required this.onToggle, required this.onDelete,
  });
  final List<AccessProfile> profiles;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String>        onSort;
  final ValueChanged<AccessProfile> onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun profil ne correspond à vos filtres.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort),
          ...profiles.asMap().entries.map((e) => _TableRow(
            profile:       e.value,
            isOdd:         e.key.isOdd,
            onView:        () => onView(e.value),
            onEdit:        () => onEdit(e.value),
            onPermissions: () => onPermissions(e.value),
            onToggle:      () => onToggle(e.value),
            onDelete:      () => onDelete(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.sortField, required this.sortAsc, required this.onSort});
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;

  Widget _col(String label, String field, {int flex = 1}) => Expanded(
    flex: flex,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 3),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: sortField == field ? kNavy : kTextMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: kSurface,
    child: Row(children: [
      const SizedBox(width: 42),
      const SizedBox(width: 12),
      _col('PROFIL',   'name',    flex: 4),
      _col('MEMBRES',  'members', flex: 2),
      _col('MODULES',  'modules', flex: 2),
      _col('STATUT',   'status',  flex: 2),
      SizedBox(width: 118,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.profile, required this.isOdd,
    required this.onView, required this.onEdit, required this.onPermissions,
    required this.onToggle, required this.onDelete,
  });
  final AccessProfile profile;
  final bool isOdd;
  final VoidCallback onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hov
              ? kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? kSurface.withValues(alpha: 0.5) : kCardBg,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.shield_rounded, size: 20,
                color: p.isActive ? _kPurple : kTextMuted),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            Text(p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                style: TextStyle(fontSize: 11, color: kTextMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.people_outline_rounded, size: 14, color: kNavy),
            const SizedBox(width: 5),
            Text('${p.memberCount}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.widgets_outlined, size: 14, color: kGreen),
            const SizedBox(width: 5),
            Text('${p.moduleCount}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(p.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16, color: p.isActive ? kGreen : kRed),
            const SizedBox(width: 5),
            Flexible(child: Text(p.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: p.isActive ? kGreen : kRed),
                overflow: TextOverflow.ellipsis)),
          ])),
          SizedBox(width: 118, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.tune_rounded, color: _kPurple,
                tooltip: 'Permissions', onTap: widget.onPermissions),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.edit_rounded, color: kNavy,
                tooltip: 'Modifier', onTap: widget.onEdit),
            const SizedBox(width: 2),
            _RowMenu(
              isActive: p.isActive,
              onView:   widget.onView,
              onToggle: widget.onToggle,
              onDelete: widget.onDelete,
            ),
          ])),
        ]),
      ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
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

/// Menu « overflow » d'une ligne de tableau : actions secondaires
/// (détails, activation, suppression) regroupées pour ne pas surcharger.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.isActive,
    required this.onView,
    required this.onToggle,
    required this.onDelete,
  });
  final bool isActive;
  final VoidCallback onView, onToggle, onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: "Plus d'actions",
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: kTextMuted),
        padding: EdgeInsets.zero,
        splashRadius: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (v) {
          switch (v) {
            case 'view':   onView();   break;
            case 'toggle': onToggle(); break;
            case 'delete': onDelete(); break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Row(children: [
            Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
            SizedBox(width: 10), Text('Voir les détails'),
          ])),
          PopupMenuItem(value: 'toggle', child: Row(children: [
            Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                size: 18, color: isActive ? _kOrange : kGreen),
            const SizedBox(width: 10),
            Text(isActive ? 'Désactiver' : 'Activer'),
          ])),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
            const SizedBox(width: 10),
            Text('Supprimer', style: TextStyle(color: kRed)),
          ])),
        ],
      );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
