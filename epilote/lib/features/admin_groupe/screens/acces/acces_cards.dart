part of '../admin_access_screen.dart';

// Vue cartes des profils d’acces.

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.profiles, required this.onView,
    required this.onEdit, required this.onPermissions, required this.onToggle,
    required this.onDelete,
  });
  final List<AccessProfile> profiles;
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
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 720 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap,
        children: profiles.map((p) => SizedBox(width: w,
          child: _ProfileCard(
            profile:       p,
            onView:        () => onView(p),
            onEdit:        () => onEdit(p),
            onPermissions: () => onPermissions(p),
            onToggle:      () => onToggle(p),
            onDelete:      () => onDelete(p),
          ))).toList(),
      );
    });
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile, required this.onView,
    required this.onEdit, required this.onPermissions, required this.onToggle,
    required this.onDelete,
  });
  final AccessProfile profile;
  final VoidCallback onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hov ? _kPurple.withValues(alpha: 0.3) : kBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
              blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: p.isActive ? _kPurple : kTextMuted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.shield_rounded,
                          color: p.isActive ? _kPurple : kTextMuted, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary))),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (v) {
                        if (v == 'view')        widget.onView();
                        if (v == 'permissions') widget.onPermissions();
                        if (v == 'edit')        widget.onEdit();
                        if (v == 'toggle')      widget.onToggle();
                        if (v == 'delete')      widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'view', child: Row(children: [
                          Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
                          SizedBox(width: 10), Text('Voir les détails'),
                        ])),
                        const PopupMenuItem(value: 'permissions', child: Row(children: [
                          Icon(Icons.tune_rounded, size: 18, color: _kPurple),
                          SizedBox(width: 10), Text('Permissions'),
                        ])),
                        PopupMenuItem(value: 'edit', child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18, color: kNavy),
                          const SizedBox(width: 10), const Text('Modifier les infos'),
                        ])),
                        PopupMenuItem(value: 'toggle', child: Row(children: [
                          Icon(p.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                              size: 18, color: p.isActive ? _kOrange : kGreen),
                          const SizedBox(width: 10),
                          Text(p.isActive ? 'Désactiver' : 'Activer'),
                        ])),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                          const SizedBox(width: 10),
                          Text('Supprimer', style: TextStyle(color: kRed)),
                        ])),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    AdminBadge('${p.memberCount} membre${p.memberCount > 1 ? 's' : ''}',
                        color: kNavy, icon: Icons.people_outline_rounded),
                    AdminBadge('${p.moduleCount} module${p.moduleCount > 1 ? 's' : ''}',
                        color: kGreen, icon: Icons.widgets_outlined),
                    AdminBadge(p.isActive ? 'Actif' : 'Inactif',
                        color: p.isActive ? kGreen : kRed,
                        icon: p.isActive ? Icons.check_circle : Icons.cancel),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onPermissions,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Configurer les permissions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kPurple,
                        side: BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Confirmation de suppression ──────────────────────────────────────────────
