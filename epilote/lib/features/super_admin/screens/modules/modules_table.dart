part of '../modules_screen.dart';

// Vue tableau : lignes et boutons d’action.

class _TableView extends StatelessWidget {
  const _TableView({
    required this.modules,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<ModuleItem> modules;
  final ValueChanged<ModuleItem> onView, onEdit, onDelete, onToggle;

  static const _iconW    = 44.0;
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
    if (modules.isEmpty) return const _EmptyState();

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
              _hdr('Module',        3),
              _hdr('Catégorie',     3),
              _hdr('Slug',          3),
              _hdr('Plans',         2, center: true),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Ordre',         2, center: true),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...modules.asMap().entries.map((e) => _TableRow(
            module:   e.value,
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
    required this.module,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final ModuleItem  module;
  final bool        isOdd;
  final double      iconW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

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
              child: _ModuleEmoji(emoji: m.emoji, size: 36),
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
                  Text(m.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  if ((m.description ?? '').trim().isNotEmpty)
                    Text(m.description!.trim(),
                        style: TextStyle(fontSize: 10.5, color: _kMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )),
          Expanded(flex: 3, child: _CategoryBadge(
              name: m.categoryName, color: _kGold)),
          Expanded(flex: 3, child: Text(m.slug,
              style: TextStyle(fontSize: 11.5, color: _kNavy,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPurple.withValues(alpha: 0.20)),
            ),
            child: Text('${m.planCount}', style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: _kPurple)),
          ))),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: m.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: m.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(m.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: m.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: Center(child: Text('#${m.displayOrder}',
              style: TextStyle(fontSize: 11.5, color: _kMuted,
                  fontWeight: FontWeight.w600)))),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue,   tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded,       color: _kNavy,   tooltip: 'Modifier',      onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: m.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: _kOrange, tooltip: m.isActive ? 'Désactiver' : 'Activer', onTap: widget.onToggle),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded,     color: _kRed,    tooltip: 'Supprimer',     onTap: widget.onDelete),
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
