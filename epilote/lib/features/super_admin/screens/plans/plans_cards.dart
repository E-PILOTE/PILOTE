part of '../plans_screen.dart';

// Vue cartes, glyphe, badge de slug, état vide.

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.plans,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<PlanDetail> plans;
  final ValueChanged<PlanDetail> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemCount: plans.length,
      itemBuilder: (_, i) => _PlanCard(
        plan:     plans[i],
        onView:   () => onView(plans[i]),
        onEdit:   () => onEdit(plans[i]),
        onDelete: () => onDelete(plans[i]),
        onToggle: () => onToggle(plans[i]),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final PlanDetail   plan;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
            color: _hovered ? color.withValues(alpha: 0.4) : _kBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: color.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _PlanGlyph(slug: p.slug, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(p.priceLabel, style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: p.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _SlugBadge(slug: p.slug),
            if (p.isPublicPlan)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Public', style: TextStyle(
                    color: _kBlue, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const Spacer(),
          Row(children: [
            _miniStat(Icons.school_rounded, p.maxSchoolsLabel, _kNavy),
            const SizedBox(width: 12),
            _miniStat(Icons.widgets_rounded, '${p.linkedModules} mod.', _kPurple),
            const SizedBox(width: 12),
            _miniStat(Icons.groups_rounded, '${p.subscribersTotal}', _kGold),
          ]),
          const SizedBox(height: 6),
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

  Widget _miniStat(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
    ],
  );
}

// ─── Glyphe & badges ──────────────────────────────────────────────────────────

class _PlanGlyph extends StatelessWidget {
  const _PlanGlyph({required this.slug, this.size = 36});
  final String slug;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _slugColor(slug);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Icon(_slugIcon(slug), color: color, size: size * 0.5),
    );
  }
}

class _SlugBadge extends StatelessWidget {
  const _SlugBadge({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final color = _slugColor(slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_slugIcon(slug), size: 11, color: color),
        const SizedBox(width: 4),
        Text(_slugLabel(slug),
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
      Icon(Icons.inventory_2_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun plan trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau plan.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Helpers dates / sections ─────────────────────────────────────────────────

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}
