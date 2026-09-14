part of '../modules_screen.dart';

// Panneau des catégories et ses pastilles.

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ModuleCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ModuleCategory> onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.category_rounded, size: 16, color: _kNavy),
          const SizedBox(width: 8),
          Text('Catégories', style: TextStyle(
              color: _kText, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kSurface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Text('${categories.length}', style: TextStyle(
                color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 14, color: _kNavy),
                  const SizedBox(width: 4),
                  Text('Catégorie', style: TextStyle(
                      color: _kNavy, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune catégorie. Créez-en une pour organiser les modules.',
                style: TextStyle(color: _kMuted, fontSize: 12.5)),
          )
        else
          Wrap(spacing: 10, runSpacing: 10,
            children: categories.map((c) => _CategoryChip(
              category: c,
              selected: selectedId == c.id,
              onTap:    () => onSelect(c.id),
              onEdit:   () => onEdit(c),
              onDelete: () => onDelete(c),
            )).toList(),
          ),
      ]),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final ModuleCategory category;
  final bool selected;
  final VoidCallback onTap, onEdit, onDelete;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final color = _catColor(c.displayOrder);
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.12) : _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? color : (_hov ? color.withValues(alpha: 0.4) : _kBorder),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(c.name, style: TextStyle(
                  color: sel ? color : _kText, fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
              Text('${c.moduleCount} module${c.moduleCount > 1 ? "s" : ""} · '
                  '${c.activeModuleCount} actif${c.activeModuleCount > 1 ? "s" : ""}',
                  style: TextStyle(color: _kMuted, fontSize: 10)),
            ]),
            if (_hov || sel) ...[
              const SizedBox(width: 8),
              _MiniBtn(icon: Icons.edit_rounded, color: _kNavy,
                  tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 3),
              _MiniBtn(icon: Icons.delete_rounded, color: _kRed,
                  tooltip: 'Supprimer', onTap: widget.onDelete),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
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
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────
