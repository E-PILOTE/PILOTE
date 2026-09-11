part of '../admin_modules_screen.dart';

// Briques du panneau : statistiques, lignes, poignee.

// ─── Widgets helpers panneau ─────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: kTextMuted)),
      ]),
    );
  }
}

class _SchoolAdoptRow extends StatelessWidget {
  const _SchoolAdoptRow({required this.name, required this.uses});
  final String name;
  final bool   uses;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
          color: uses ? kGreen : Colors.transparent,
          border: Border.all(
              color: uses ? kGreen : kBorder, width: 1.5),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                color: uses ? kTextPrimary : kTextMuted,
                fontWeight:
                    uses ? FontWeight.w600 : FontWeight.normal)),
      ),
      if (uses)
        Icon(Icons.check_rounded, size: 13, color: kGreen),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
              border:
                  Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIGNE DE PROFIL DANS LE PANNEAU — éditeur de niveau inline
// ═══════════════════════════════════════════════════════════════════════════════

class _PanelProfileRow extends ConsumerStatefulWidget {
  const _PanelProfileRow({
    required this.slug,
    required this.moduleId,
    required this.profile,
    required this.enabled,
  });
  final String slug;
  final String moduleId;
  final ModuleProfileAccess profile;
  final bool enabled;

  @override
  ConsumerState<_PanelProfileRow> createState() => _PanelProfileRowState();
}

class _PanelProfileRowState extends ConsumerState<_PanelProfileRow> {
  bool _saving = false;

  Future<void> _setLevel(String level) async {
    if (_saving) return;
    final p = widget.profile;
    final current = _levelOf(p.perm);
    if (level == current && !_isCustom(p.perm)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = ref.read(adminAccessServiceProvider);
      final map = {...await ref.read(accessProfilePermsProvider(p.id).future)};
      final scope = map[widget.moduleId]?.dataScope ?? 'own_school';
      if (level == _levelNone) {
        map.remove(widget.moduleId);
      } else {
        map[widget.moduleId] = _presetFor(level, scope);
      }
      final perms = [
        for (final e in map.entries)
          if (!e.value.isEmpty) e.value.toJson(e.key),
      ];
      await svc.savePermissions(p.id, perms);
      ref.invalidate(adminModuleProvider(widget.slug));
      ref.invalidate(adminModulesCatalogProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(level == _levelNone
            ? '${p.name} : accès retiré'
            : '${p.name} : ${level.toLowerCase()}'),
        backgroundColor: kNavy,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Échec de la mise à jour : $e'),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final level = _levelOf(p.perm);
    final color = _levelColor(level);
    final custom = _isCustom(p.perm);
    final on = level != _levelNone;
    final sub = <String>[
      if (p.roleType != null && p.roleType!.isNotEmpty) p.roleType!,
      '${p.memberCount} membre${p.memberCount > 1 ? "s" : ""}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (on ? color : kTextMuted).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_levelIcon(level),
              color: on ? color : kTextMuted, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: kTextMuted)),
              ),
              if (custom) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: "Permissions personnalisées définies dans Profils d'accès — "
                      'changer le niveau ici les remplacera.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('réglage fin',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _kPurple)),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        _selector(level, color),
      ]),
    );
  }

  Widget _selector(String level, Color color) {
    final isEnabled = widget.enabled && !_saving;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_saving)
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kNavy))
        else
          Icon(_levelIcon(level),
              size: 15, color: widget.enabled ? color : kTextMuted),
        const SizedBox(width: 6),
        Text(level,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: widget.enabled ? kTextPrimary : kTextMuted)),
        if (widget.enabled) ...[
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 16, color: kTextMuted),
        ],
      ]),
    );

    if (!isEnabled) return Opacity(opacity: widget.enabled ? 1 : 0.7, child: chip);

    return PopupMenuButton<String>(
      tooltip: "Modifier le niveau d'accès",
      onSelected: _setLevel,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        for (final l in _allLevels)
          PopupMenuItem<String>(
            value: l,
            child: Row(children: [
              Icon(_levelIcon(l), size: 16, color: _levelColor(l)),
              const SizedBox(width: 10),
              Text(l,
                  style: TextStyle(
                      fontSize: 13, color: kTextPrimary)),
              if (l == level) ...[
                const Spacer(),
                Icon(Icons.check_rounded,
                    size: 16, color: kGreen),
              ],
            ]),
          ),
      ],
      child: chip,
    );
  }
}

// ─── Drag handle panneau (bord gauche) ───────────────────────────────────────

class _PanelResizeHandle extends StatefulWidget {
  const _PanelResizeHandle({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<_PanelResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: _hovered
              ? kGreen.withValues(alpha: 0.55)
              : kBorder.withValues(alpha: 0.60),
        ),
      ),
    );
  }
}
