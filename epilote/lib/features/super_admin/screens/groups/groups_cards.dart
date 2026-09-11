part of '../school_groups_screen.dart';

// Vue cartes (écran étroit).

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.groups,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GroupDetail> groups;
  final ValueChanged<GroupDetail> onDetail, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemCount: groups.length,
      itemBuilder: (_, i) => _GroupCard(
        group:    groups[i],
        onDetail: () => onDetail(groups[i]),
        onEdit:   () => onEdit(groups[i]),
        onDelete: () => onDelete(groups[i]),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });
  final GroupDetail group;
  final VoidCallback onDetail, onEdit, onDelete;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onDetail,
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
            // ─ Header ─────────────────────────────────────────────────────────
            Row(children: [
              _GroupAvatar(name: g.name, size: 40),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: TextStyle(
                      color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  Text(g.department ?? '—',
                      style: TextStyle(color: _kMuted, fontSize: 11)),
                ],
              )),
              _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel),
            ]),
            const SizedBox(height: 12),

            // ─ Badges ─────────────────────────────────────────────────────────
            Wrap(spacing: 6, runSpacing: 4, children: [
              // ⚠️ Un ministère porte SA pastille et pas celle de la tutelle :
              // « MINISTÈRE · MEPSA » dit déjà le sigle, et deux pastilles
              // côte à côte laisseraient croire à deux informations.
              if (g.administreReferentielNational)
                BadgeMinistere(estMinistere: true, tutelle: g.tutelle)
              else
                _TutelleBadge(tutelle: g.tutelle),
              _TypeBadge(type: g.groupType, label: g.groupTypeLabel),
              if (g.caractereLabel != null)
                _CaractereBadge(caractere: g.caractere!,
                    label: g.caractereLabel!),
              _PlanBadge(plan: g.planName, price: g.priceXaf),
            ]),
            const SizedBox(height: 10),

            // ─ Stats ──────────────────────────────────────────────────────────
            Row(children: [
              _CardStat(icon: Icons.business_rounded, label: '${g.schoolCount} école${g.schoolCount > 1 ? 's' : ''}'),
              const SizedBox(width: 14),
              if (g.subscriptionEnd != null)
                _CardStat(
                  icon: Icons.event_rounded,
                  label: DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!),
                  color: g.expiresBientot ? _kOrange : _kMuted,
                ),
            ]),

            const Spacer(),

            // ─ Actions ────────────────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kNavy),
              ),
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kRed),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  _CardStat({required this.icon, required this.label, Color? color}) : color = color ?? _kMuted;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: color, fontSize: 11.5,
        fontWeight: FontWeight.w600)),
  ]);
}

// ─── Badges ───────────────────────────────────────────────────────────────────
