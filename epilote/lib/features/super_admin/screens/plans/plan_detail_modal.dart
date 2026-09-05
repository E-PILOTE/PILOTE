part of '../plans_screen.dart';

// Fiche détaillée : coquille et onglets.

class _PlanDetailModal extends ConsumerStatefulWidget {
  const _PlanDetailModal({
    required this.plan,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onPrint,
  });
  final PlanDetail plan;
  final VoidCallback onEdit, onToggle, onDelete, onPrint;

  @override
  ConsumerState<_PlanDetailModal> createState() => _PlanDetailModalState();
}

class _PlanDetailModalState extends ConsumerState<_PlanDetailModal>
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
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              _PlanGlyph(slug: p.slug, size: 66),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(
                    color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _SlugBadge(slug: p.slug),
                  _PlanStatusBadge(isActive: p.isActive),
                  if (p.isPublicPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBlue.withValues(alpha: 0.30)),
                      ),
                      child: const Text('Public', style: TextStyle(
                          color: _kBlue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.payments_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(p.priceLabel, style: TextStyle(
                      color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _ModalIconBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.print_rounded, color: _kMuted, tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // Tabs
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
                Tab(text: 'Modules & Adoption'),
                Tab(text: 'Système'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PlanInfoTab(plan: p),
                _PlanModulesTab(plan: p),
                _PlanSystemTab(plan: p),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(p.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(p.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: p.isActive ? _kOrange : _kGreen),
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

// ─── Onglet Informations ────────────────────────────────────────────────────
