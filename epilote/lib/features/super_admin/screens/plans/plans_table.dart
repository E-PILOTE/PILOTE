part of '../plans_screen.dart';

// Vue tableau : lignes et boutons d’action.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.plans,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<PlanDetail> plans;
  final ValueChanged<PlanDetail> onView, onEdit, onDelete, onToggle;

  static const _iconW    = 44.0;
  static const _statusW  = 88.0;
  static const _actionsW = 104.0;

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
    if (plans.isEmpty) return const _EmptyState();

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
          Container(
            height: 38,
            color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _iconW),
              _hdr('Plan',          3),
              // Le tarif porte désormais sa période (« / an », « / mois ») :
              // un en-tête qui l'impose serait faux dès le premier plan
              // mensuel. Cf. `billing_period.dart`.
              _hdr('Tarif',         2),
              _hdr('Périodicité',   2),
              _hdr('Écoles max',    2),
              _hdr('Modules',       2),
              _hdr('Abonnés',       2),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...plans.asMap().entries.map((e) => _TableRow(
            plan:     e.value,
            isOdd:    e.key.isOdd,
            iconW:    _iconW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onToggle: () => onToggle(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.plan,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final PlanDetail   plan;
  final bool         isOdd;
  final double       iconW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
          SizedBox(width: widget.iconW, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              child: _PlanGlyph(slug: p.slug, size: 36),
            ),
          )),
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (p.isPublicPlan)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.public_rounded, size: 11,
                            color: _kBlue.withValues(alpha: 0.8)),
                      ),
                    Text(_slugLabel(p.slug),
                        style: TextStyle(fontSize: 10.5,
                            color: color, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          )),
          // Montant nu : la période a sa propre colonne juste à droite.
          Expanded(flex: 2, child: Text(p.priceAmountLabel,
              style: TextStyle(fontSize: 12.5,
                  color: p.isFree ? _kMuted : _kText,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p.periodLabel,
              style: TextStyle(fontSize: 12, color: _kMuted),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p.maxSchoolsLabel,
              style: TextStyle(fontSize: 12, color: _kText),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Row(children: [
            const Icon(Icons.widgets_rounded, size: 13, color: _kPurple),
            const SizedBox(width: 4),
            Text('${p.linkedModules}',
                style: TextStyle(fontSize: 12.5, color: _kText,
                    fontWeight: FontWeight.w600)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.groups_rounded, size: 13, color: _kGold),
            const SizedBox(width: 4),
            Text('${p.subscribersTotal}',
                style: TextStyle(fontSize: 12.5, color: _kText,
                    fontWeight: FontWeight.w600)),
            if (p.subscribersActive != p.subscribersTotal)
              Text(' (${p.subscribersActive})',
                  style: TextStyle(fontSize: 10.5, color: _kGreen)),
          ])),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: p.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(p.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: p.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue, tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded, color: _kRed, tooltip: 'Supprimer', onTap: widget.onDelete),
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
