part of '../administrators_screen.dart';

// Vue cartes, pastille, badge de rôle, état vide.

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.admins,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<AdminDetail> admins;
  final ValueChanged<AdminDetail> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (admins.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.65,
      ),
      itemCount: admins.length,
      itemBuilder: (_, i) => _AdminCard(
        admin:    admins[i],
        onView:   () => onView(admins[i]),
        onEdit:   () => onEdit(admins[i]),
        onDelete: () => onDelete(admins[i]),
        onToggle: () => onToggle(admins[i]),
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  const _AdminCard({
    required this.admin,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final AdminDetail  admin;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? _kNavy.withValues(alpha: 0.4) : _kBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: _kNavy.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─ Header ───────────────────────────────────────────────────────
          Row(children: [
            _AdminAvatar(admin: a, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.fullName, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(a.email, style: TextStyle(
                    color: _kMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            // Statut dot
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: a.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ─ Badges ────────────────────────────────────────────────────────
          Wrap(spacing: 6, children: [
            _RoleBadge(role: a.role),
            if (a.groupName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(a.groupName!, style: TextStyle(
                    color: _kGold, fontSize: 11, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
          ]),
          const SizedBox(height: 10),

          // ─ Infos ─────────────────────────────────────────────────────────
          Row(children: [
            Icon(Icons.access_time_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 4),
            Text(a.lastLoginLabel, style: TextStyle(
                color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ]),

          const Spacer(),

          // ─ Actions ───────────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: widget.onView,
              icon: const Icon(Icons.visibility_rounded, size: 13),
              label: const Text('Voir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kBlue),
            ),
            TextButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Modifier', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kNavy),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: _kRed,
              tooltip: 'Supprimer',
            ),
          ]),
        ]),
      ),
      ),
    );
  }
}

// ─── Badges & avatars ─────────────────────────────────────────────────────────

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.admin, this.size = 36});
  final AdminDetail admin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(admin.role);
    if (admin.avatarUrl != null && admin.avatarUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: admin.avatarUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, _, _) => _Initials(
              initials: admin.initials, color: color, size: size),
        ),
      );
    }
    return _Initials(initials: admin.initials, color: color, size: size);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.color, required this.size});
  final String initials;
  final Color  color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
    ),
    child: Center(child: Text(initials, style: TextStyle(
        color: color, fontSize: size * 0.38, fontWeight: FontWeight.w800))),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_roleIcon(role), size: 11, color: color),
        const SizedBox(width: 4),
        Text(role == 'super_admin' ? 'Super Admin' : 'Admin Groupe',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.admin_panel_settings_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun administrateur trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouvel administrateur.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Widget upload avatar ─────────────────────────────────────────────────────
