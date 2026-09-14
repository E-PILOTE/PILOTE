part of '../admin_access_screen.dart';

// Fiche detaillee d’un profil.

class _ProfileDetailModal extends ConsumerStatefulWidget {
  const _ProfileDetailModal({
    required this.profile,
    required this.categories,
    required this.onEdit,
    required this.onPermissions,
    required this.onToggle,
    required this.onDelete,
  });
  final AccessProfile profile;
  final List<ModuleCategory> categories;
  final VoidCallback onEdit, onPermissions, onToggle, onDelete;

  @override
  ConsumerState<_ProfileDetailModal> createState() => _ProfileDetailModalState();
}

class _ProfileDetailModalState extends ConsumerState<_ProfileDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

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
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.shield_rounded,
                    color: p.isActive ? _kPurple : kTextMuted, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    AdminBadge(p.isActive ? 'Actif' : 'Inactif',
                        color: p.isActive ? kGreen : kRed,
                        icon: p.isActive ? Icons.check_circle : Icons.block_rounded),
                    AdminBadge('${p.memberCount} membre${p.memberCount > 1 ? 's' : ''}',
                        color: kNavy, icon: Icons.people_outline_rounded),
                    AdminBadge('${p.moduleCount} module${p.moduleCount > 1 ? 's' : ''}',
                        color: kGreen, icon: Icons.widgets_outlined),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                    style: TextStyle(color: kTextMuted, fontSize: 11.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.tune_rounded, color: _kPurple,
                    tooltip: 'Permissions', onTap: widget.onPermissions),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.edit_rounded, color: kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
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
                Tab(text: 'Permissions'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProfileInfoTab(profile: p),
                _ProfilePermsTab(
                  profile: p,
                  categories: widget.categories,
                  onConfigure: widget.onPermissions,
                ),
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
              Tooltip(
                message: 'Supprimer ce profil',
                child: OutlinedButton(
                  onPressed: widget.onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: BorderSide(color: kRed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(p.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(p.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: p.isActive ? _kOrange : kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onPermissions,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Permissions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
                ),
              ),
              const SizedBox(width: 10),
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
