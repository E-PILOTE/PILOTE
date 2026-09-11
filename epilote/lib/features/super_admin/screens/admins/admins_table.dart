part of '../administrators_screen.dart';

// Vue tableau : lignes et boutons d’action.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.admins,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReset,
  });

  final List<AdminDetail> admins;
  final ValueChanged<AdminDetail> onView, onEdit, onDelete, onToggle, onReset;

  static const _avatarW  = 44.0;
  static const _statusW  = 88.0;
  static const _actionsW = 132.0;

  static Widget _hdr(String label, int flex, {bool center = false}) => Expanded(
    flex: flex,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label, style: TextStyle(
          color: _kMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (admins.isEmpty) return const _EmptyState();

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
          Container(
            height: 38,
            color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _avatarW),
              _hdr('Administrateur',      3),
              _hdr('Rôle',               2),
              _hdr('Groupe scolaire',    2),
              _hdr('Email',              3),
              _hdr('Téléphone',          2),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Dernière connexion', 2),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          // Lignes
          ...admins.asMap().entries.map((e) => _TableRow(
            admin:    e.value,
            isOdd:    e.key.isOdd,
            avatarW:  _avatarW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onToggle: () => onToggle(e.value),
            onReset:  () => onReset(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.admin,
    required this.isOdd,
    required this.avatarW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReset,
  });
  final AdminDetail  admin;
  final bool         isOdd;
  final double       avatarW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle, onReset;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Avatar (cliquable → détails)
          SizedBox(width: widget.avatarW, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              child: _AdminAvatar(admin: a, size: 36),
            ),
          )),

          // Nom + sous-titre (cliquable → détails)
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(a.fullName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  if (a.firstName.isEmpty && a.lastName.isEmpty)
                    Text('Profil incomplet',
                        style: TextStyle(fontSize: 10.5,
                            color: _kOrange.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )),

          // Rôle
          Expanded(flex: 2, child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _RoleBadge(role: a.role),
            ),
          )),

          // Groupe
          Expanded(flex: 2, child: a.groupName != null
              ? Row(children: [
                  if (a.groupLogo != null && a.groupLogo!.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: a.groupLogo!,
                        width: 20, height: 20, fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox(),
                      ),
                    )
                  else
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.business_rounded, size: 12, color: _kGold),
                    ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.groupName!,
                      style: TextStyle(fontSize: 12, color: _kText),
                      overflow: TextOverflow.ellipsis)),
                ])
              : Text(a.role == 'super_admin' ? 'Plateforme' : '—',
                  style: TextStyle(
                      fontSize: 12,
                      color: a.role == 'super_admin' ? _kNavy : _kMuted,
                      fontWeight: a.role == 'super_admin'
                          ? FontWeight.w600 : FontWeight.normal))),

          // Email
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: a.email,
              child: Text(a.email,
                  style: TextStyle(fontSize: 12, color: _kNavy),
                  overflow: TextOverflow.ellipsis),
            ),
          )),

          // Téléphone
          Expanded(flex: 2, child: Text(a.phone ?? '—',
              style: TextStyle(fontSize: 12, color: _kMuted),
              overflow: TextOverflow.ellipsis)),

          // Statut (cliquable pour toggle)
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: a.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: a.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: a.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(a.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: a.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),

          // Dernière connexion
          Expanded(flex: 2, child: Text(a.lastLoginLabel,
              style: TextStyle(fontSize: 11.5,
                  color: a.lastLogin == null
                      ? _kMuted.withValues(alpha: 0.6) : _kText),
              overflow: TextOverflow.ellipsis)),

          // Actions
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue,   tooltip: 'Voir la fiche',                  onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded,       color: _kNavy,   tooltip: 'Modifier',                       onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.lock_reset_rounded, color: _kOrange, tooltip: 'Réinitialiser le mot de passe',  onTap: widget.onReset),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded,     color: _kRed,    tooltip: 'Supprimer',                      onTap: widget.onDelete),
            ]),
          ),
        ]),
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
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
