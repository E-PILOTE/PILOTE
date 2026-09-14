part of '../modules_screen.dart';

// Vue cartes, emoji, badges, état vide.

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.modules,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<ModuleItem> modules;
  final ValueChanged<ModuleItem> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.65,
      ),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleCard(
        module:   modules[i],
        onView:   () => onView(modules[i]),
        onEdit:   () => onEdit(modules[i]),
        onDelete: () => onDelete(modules[i]),
        onToggle: () => onToggle(modules[i]),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.module,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final ModuleItem  module;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

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
            color: _hovered ? _kNavy.withValues(alpha: 0.4) : _kBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: _kNavy.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _ModuleEmoji(emoji: m.emoji, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(m.slug, style: TextStyle(
                    color: _kMuted, fontSize: 11, fontFamily: 'monospace'),
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
                    color: m.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _CategoryBadge(name: m.categoryName, color: _kGold, compact: true),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${m.planCount} plan${m.planCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                      color: _kPurple, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.tag_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 4),
            Text('Ordre #${m.displayOrder}', style: TextStyle(
                color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
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
}

// ─── Badges & icônes ──────────────────────────────────────────────────────────

class _ModuleEmoji extends StatelessWidget {
  const _ModuleEmoji({required this.emoji, this.size = 36});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: _kBorder),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.name, required this.color, this.compact = false});
  final String name;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(compact ? 6 : 12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_rounded, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(name, style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
    return compact ? badge : Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: badge,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
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
      Icon(Icons.extension_off_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun module trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau module.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Emojis suggérés ──────────────────────────────────────────────────────────
const _emojiSuggestions = [
  '📦','🧩','🎓','📚','🏫','👨‍🎓','📋','🏛️','📖','📝','📊','💰','💳','🧾',
  '📅','⏰','✅','📈','🩺','🍽️','📕','🚌','🏆','🔔','📢','✉️','📁','🗂️',
  '🛠️','⚙️','👥','🧑‍🏫','📌','🎯','💼','🗓️','📎','🔐','🌐','🏥',
];

String _slugify(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ûü]'), 'u')
    .replaceAll(RegExp(r'[ç]'), 'c')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

// ─── Modal Module (création / édition) ────────────────────────────────────────
