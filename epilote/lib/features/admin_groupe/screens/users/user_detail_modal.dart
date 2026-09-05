part of '../admin_users_screen.dart';

// Fiche détaillée : coquille et onglets.

class _UserDetailModal extends StatefulWidget {
  const _UserDetailModal({
    required this.user,
    required this.onEdit,
    required this.onPassword,
    required this.onToggle,
  });
  final AdminUser user;
  final VoidCallback onEdit, onPassword, onToggle;

  @override
  State<_UserDetailModal> createState() => _UserDetailModalState();
}

class _UserDetailModalState extends State<_UserDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              PhotoAvatar(
                name: u.fullName,
                photoUrl: u.avatarUrl,
                size: 66,
                background: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.12),
                foreground: u.isActive ? kNavy : kTextMuted,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName, style: TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _RoleBadge(role: u.role),
                    // « Inactif » ne disait rien : on affiche le MOTIF du
                    // départ, seule information exploitable (migration 0083).
                    AdminBadge(
                        u.isActive
                            ? 'En service'
                            : mouvementLabel(u.departureMotif),
                        color: u.isActive ? kGreen : kRed,
                        icon: u.isActive ? Icons.check_circle : Icons.logout_rounded),
                    if (u.schoolName != null)
                      AdminBadge(u.schoolName!, color: _kBlue,
                          icon: Icons.account_balance_outlined),
                    if (u.accessProfileName != null)
                      AdminBadge(u.accessProfileName!, color: _kPurple,
                          icon: Icons.shield_outlined),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.email_outlined, size: 12, color: kTextMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(u.email,
                        style: TextStyle(color: kTextMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (u.phone != null && u.phone!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.phone_outlined, size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text(u.phone!, style: TextStyle(color: kTextMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.edit_rounded, color: kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.key_rounded, color: kAccent,
                    tooltip: 'Réinitialiser le mot de passe', onTap: widget.onPassword),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.close_rounded, color: kTextMuted,
                    tooltip: 'Fermer', onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // ─ Tabs ────────────────────────────────────────────────────────────
          Container(
            color: kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: kNavy,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Carrière'),
                Tab(text: 'Rôle & Accès'),
                Tab(text: 'Activité'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _UserInfoTab(user: u),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: AgentCarrierePanel(profileId: u.id),
                ),
                _UserAccessTab(user: u),
                _UserActivityTab(user: u),
              ],
            ),
          ),
          // ─ Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(u.isActive ? Icons.logout_rounded : Icons.person_add_alt_1_rounded, size: 16),
                label: Text(u.isActive ? 'Fin de service' : 'Réintégrer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: u.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: u.isActive ? _kOrange : kGreen),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onPassword,
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('Mot de passe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy, foregroundColor: Colors.white, elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
