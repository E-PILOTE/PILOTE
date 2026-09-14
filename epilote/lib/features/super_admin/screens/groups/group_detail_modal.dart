part of '../school_groups_screen.dart';

// Fiche détaillée : coquille et onglets.

class _GroupDetailModal extends StatefulWidget {
  const _GroupDetailModal({
    required this.group,
    required this.plans,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onPrint,
  });
  final GroupDetail      group;
  final List<PlanInfo>   plans;
  final VoidCallback     onEdit, onToggleActive, onDelete, onPrint;

  @override
  State<_GroupDetailModal> createState() => _GroupDetailModalState();
}

class _GroupDetailModalState extends State<_GroupDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header propre ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Logo carré arrondi
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                  color: _kSurface,
                ),
                clipBehavior: Clip.antiAlias,
                child: (g.logoUrl != null && g.logoUrl!.startsWith('http'))
                    ? CachedNetworkImage(
                        imageUrl: g.logoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _SquareInitials(name: g.name, size: 66),
                      )
                    : _SquareInitials(name: g.name, size: 66),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (g.administreReferentielNational)
                      BadgeMinistere(estMinistere: true, tutelle: g.tutelle),
                    _StatusBadge(status: g.subscriptionStatus,
                        label: g.statusLabel),
                    _TypeBadge(type: g.groupType, label: g.groupTypeLabel),
                    if (g.caractereLabel != null)
                      _CaractereBadge(caractere: g.caractere!,
                          label: g.caractereLabel!),
                    if (!g.administreReferentielNational)
                      _TutelleBadge(tutelle: g.tutelle),
                    _PlanBadge(plan: g.planName, price: g.priceXaf),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.email_outlined, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Consumer(builder: (context, ref, _) {
                      final compte = ref
                          .watch(comptesAdminParGroupeProvider)
                          .maybeWhen(
                            data: (m) => compteDeConnexion(m, g.id),
                            orElse: () => null,
                          );
                      return Text(compte ?? g.adminEmail,
                          style: TextStyle(color: _kMuted, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis);
                    })),
                    if (g.department != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined,
                          size: 12, color: _kMuted),
                      const SizedBox(width: 3),
                      Text(g.department!,
                          style: TextStyle(
                              color: _kMuted, fontSize: 11.5)),
                    ],
                    if (g.foundedYear != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.history_edu_outlined,
                          size: 12, color: _kMuted),
                      const SizedBox(width: 3),
                      Text('Fondé en ${g.foundedYear}',
                          style: TextStyle(
                              color: _kMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              // Boutons d'action
              Row(children: [
                _ModalIconBtn(
                    icon: Icons.edit_rounded,
                    color: _kNavy,
                    tooltip: 'Modifier',
                    onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.print_rounded,
                    color: _kMuted,
                    tooltip: 'Imprimer',
                    onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.close_rounded,
                    color: _kMuted,
                    tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),

          // ─ Tabs ──────────────────────────────────────────────────────────────
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Abonnement'),
                Tab(text: 'Activité'),
              ],
            ),
          ),

          // ─ Tab content ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _InfoTab(group: g),
                _SubscriptionTab(group: g),
                _ActivityTab(group: g),
              ],
            ),
          ),

          // ─ Footer actions ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggleActive,
                icon: Icon(
                  g.isActive ? Icons.block_rounded : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(g.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: g.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: g.isActive ? _kOrange : _kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
