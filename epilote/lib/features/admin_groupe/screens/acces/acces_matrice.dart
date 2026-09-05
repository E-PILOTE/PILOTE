part of '../admin_access_screen.dart';

// Matrice des permissions : legende, categories, bascules.

// ─── Chip modèle de profil ────────────────────────────────────────────────────
class _PresetChip extends StatefulWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t   = widget.preset;
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: t.description,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? t.color.withValues(alpha: 0.12)
                  : _hov ? t.color.withValues(alpha: 0.06) : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel
                    ? t.color.withValues(alpha: 0.55)
                    : _hov ? t.color.withValues(alpha: 0.3) : kBorder,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.icon, size: 14, color: sel ? t.color : kTextMuted),
              const SizedBox(width: 6),
              Text(t.label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: sel ? t.color : kTextMuted,
              )),
              if (sel) ...[
                const SizedBox(width: 5),
                Icon(Icons.check_rounded, size: 12, color: t.color),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Matrice de permissions (étape 2 de l'assistant) ────────────────────────
class _MatrixLegend extends StatelessWidget {
  const _MatrixLegend();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            'Activez les actions autorisées par module. Cocher une action active '
            'automatiquement « Voir ». La portée définit si le membre voit toute '
            'l\'école ou seulement ses classes. Les modules « Hors plan » ne font '
            'pas partie de votre abonnement et ne peuvent pas être accordés.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: 13, color: _kOrange),
            SizedBox(width: 4),
            Text('action sensible',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kOrange)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 13, color: kTextMuted),
            const SizedBox(width: 4),
            Text('hors plan',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kTextMuted)),
          ]),
        ]),
      ]),
    );
  }
}

class _MatrixCategory extends StatelessWidget {
  const _MatrixCategory({
    required this.category,
    required this.modules,
    required this.collapsed,
    required this.rowFor,
    required this.onUpdate,
    required this.onToggleCollapse,
    required this.onGrantAll,
    required this.onClearAll,
  });
  final ModuleCategory category;
  final List<ModuleInfo> modules;
  final bool collapsed;
  final PermRow Function(String) rowFor;
  final void Function(String, PermRow) onUpdate;
  final VoidCallback onToggleCollapse, onGrantAll, onClearAll;

  @override
  Widget build(BuildContext context) {
    final accessibleCount = modules.where((m) => m.accessible).length;
    final grantedCount = modules.where((m) => !rowFor(m.id).isEmpty).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(children: [
              Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: kTextMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(category.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kNavy,
                        letterSpacing: 0.4)),
              ),
              const SizedBox(width: 8),
              if (grantedCount > 0)
                AdminBadge('$grantedCount/$accessibleCount',
                    color: _kPurple, icon: Icons.check_rounded),
              const Spacer(),
              _MiniBtn(
                  label: 'Tout voir',
                  icon: Icons.visibility_outlined,
                  onTap: onGrantAll),
              const SizedBox(width: 6),
              _MiniBtn(
                  label: 'Effacer', icon: Icons.clear_rounded, onTap: onClearAll),
            ]),
          ),
        ),
        if (!collapsed) ...[
          Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              for (final m in modules)
                _MatrixModuleRow(
                    module: m,
                    row: rowFor(m.id),
                    onChanged: (r) => onUpdate(m.id, r)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted)),
            ]),
          ),
        ),
      );
}

class _MatrixModuleRow extends StatelessWidget {
  const _MatrixModuleRow(
      {required this.module, required this.row, required this.onChanged});
  final ModuleInfo module;
  final PermRow row;
  final ValueChanged<PermRow> onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = !module.accessible;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(module.icon ?? '📦', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(module.name,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            if (locked)
              AdminBadge('Hors plan',
                  color: kTextMuted, icon: Icons.lock_outline)
            else if (row.sensitiveCount > 0)
              AdminBadge(
                  '${row.sensitiveCount} sensible${row.sensitiveCount > 1 ? 's' : ''}',
                  color: _kOrange,
                  icon: Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final a in _kActions)
                _ActionToggle(
                  def: a,
                  active: _permGet(row, a.key),
                  enabled: !locked,
                  onTap: () =>
                      onChanged(_permSet(row, a.key, !_permGet(row, a.key))),
                ),
              const SizedBox(width: 4),
              _ScopeDropdown(
                value: row.dataScope,
                enabled: !locked && !row.isEmpty,
                onChanged: (v) => onChanged(row.copyWith(dataScope: v)),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _ActionToggle extends StatelessWidget {
  const _ActionToggle(
      {required this.def,
      required this.active,
      required this.enabled,
      required this.onTap});
  final _ActionDef def;
  final bool active, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = def.sensitive ? _kOrange : _kPurple;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.12) : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? accent.withValues(alpha: 0.55) : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(def.icon, size: 13, color: active ? accent : kTextMuted),
          const SizedBox(width: 5),
          Text(def.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : kTextMuted)),
          if (def.sensitive) ...[
            const SizedBox(width: 3),
            Icon(Icons.warning_amber_rounded,
                size: 11,
                color:
                    active ? accent : kTextMuted.withValues(alpha: 0.6)),
          ],
        ]),
      ),
    );
  }
}

class _ScopeDropdown extends StatelessWidget {
  const _ScopeDropdown({required this.value, required this.enabled, required this.onChanged});
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: kTextMuted),
          style: TextStyle(fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'own_school', child: Text('Toute l\'école')),
            DropdownMenuItem(value: 'own_classes', child: Text('Ses classes')),
          ],
          onChanged: enabled ? (v) => onChanged(v ?? 'own_school') : null,
        ),
      ),
    );
  }
}
