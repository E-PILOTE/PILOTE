part of '../admin_users_screen.dart';

// Vue cartes (écran étroit) + formats de date partagés.

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.users, required this.data, required this.onView,
    required this.onEdit, required this.onPassword, required this.onToggle,
    required this.onMuter, required this.onResetPin,
  });
  final List<AdminUser>  users;
  final AdminUsersData   data;
  final ValueChanged<AdminUser> onView, onEdit, onPassword, onToggle, onMuter,
      onResetPin;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun utilisateur ne correspond à vos filtres.',
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1200 ? 4 : c.maxWidth >= 800 ? 3 : c.maxWidth >= 560 ? 2 : 1;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap,
        children: users.map((u) => SizedBox(width: w,
          child: _UserCard(
            user:       u,
            onView:     () => onView(u),
            onEdit:     () => onEdit(u),
            onPassword: () => onPassword(u),
            onToggle:   () => onToggle(u),
            onMuter:    () => onMuter(u),
            onResetPin: () => onResetPin(u),
          ))).toList(),
      );
    });
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({required this.user, required this.onView, required this.onEdit,
      required this.onPassword, required this.onToggle, required this.onMuter,
      required this.onResetPin});
  final AdminUser user;
  final VoidCallback onView, onEdit, onPassword, onToggle, onMuter, onResetPin;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hov ? kNavy.withValues(alpha: 0.3) : kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
            blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PhotoAvatar(
              name: u.fullName,
              photoUrl: u.avatarUrl,
              size: 44,
              background: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.12),
              foreground: u.isActive ? kNavy : kTextMuted,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
              Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ])),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'view')     widget.onView();
                if (v == 'edit')     widget.onEdit();
                if (v == 'password') widget.onPassword();
                if (v == 'reset_pin') widget.onResetPin();
                if (v == 'muter')    widget.onMuter();
                if (v == 'toggle')   widget.onToggle();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Row(children: [
                  Icon(Icons.visibility_outlined, size: 18, color: _kBlue), SizedBox(width: 10), Text('Voir les détails'),
                ])),
                PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: kNavy), const SizedBox(width: 10), const Text('Modifier'),
                ])),
                PopupMenuItem(value: 'password', child: Row(children: [
                  Icon(Icons.key_rounded, size: 18, color: kAccent), const SizedBox(width: 10), const Text('Réinit. mot de passe'),
                ])),
                if (agentLockApplies(u.role))
                  PopupMenuItem(value: 'reset_pin', child: Row(children: [
                    Icon(Icons.pin_rounded, size: 18, color: kNavy), const SizedBox(width: 10), const Text('Réinit. code du poste'),
                  ])),
                const PopupMenuItem(value: 'muter', child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 18, color: _kPurple),
                  SizedBox(width: 10), Text('Muter'),
                ])),
                PopupMenuItem(value: 'toggle', child: Row(children: [
                  Icon(u.isActive ? Icons.logout_rounded : Icons.person_add_alt_1_rounded,
                      size: 18, color: u.isActive ? kRed : kGreen),
                  const SizedBox(width: 10),
                  Text(u.isActive ? 'Fin de service' : 'Réintégrer'),
                ])),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _RoleBadge(role: u.role),
            if (u.schoolName != null)
              AdminBadge(u.schoolName!, color: _kBlue, icon: Icons.account_balance_outlined),
            AdminBadge(
              u.isActive ? 'Actif' : 'Inactif',
              color: u.isActive ? kGreen : kRed,
              icon: u.isActive ? Icons.check_circle : Icons.cancel,
            ),
          ]),
          if (u.lastLogin != null) ...[
            const SizedBox(height: 8),
            Text(u.lastLoginLabel,
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        ]),
      ),
      ),
    );
  }
}

// ─── Modal détails utilisateur (style super_admin) ───────────────────────────

Color _userRoleColor(String role) => switch (role) {
  'directeur'  => kNavy,
  'proviseur'  => kNavy,
  'enseignant' => _kBlue,
  'cpe'        => _kPurple,
  'secretaire' => _kPurple,
  'comptable'  => kAccent,
  'surveillant'=> _kOrange,
  'infirmier'  => kGreen,
  'responsable_cantine' => kGreen,
  _            => kTextMuted,
};

IconData _userRoleIcon(String role) => switch (role) {
  'directeur'  => Icons.workspace_premium_rounded,
  'proviseur'  => Icons.workspace_premium_rounded,
  'enseignant' => Icons.menu_book_rounded,
  'cpe'        => Icons.gavel_rounded,
  'secretaire' => Icons.description_rounded,
  'comptable'  => Icons.payments_rounded,
  'surveillant'=> Icons.shield_outlined,
  'infirmier'  => Icons.medical_services_outlined,
  'responsable_cantine' => Icons.restaurant_rounded,
  _            => Icons.person_rounded,
};

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
                'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

String _fmtDateTime(DateTime? d) {
  if (d == null) return 'Jamais';
  return '${_fmtDate(d)} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
