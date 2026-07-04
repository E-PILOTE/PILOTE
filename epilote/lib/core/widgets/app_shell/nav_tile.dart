import 'package:flutter/material.dart';

import '../admin_ui.dart' show kNavy, kGreen;
import 'nav_models.dart';

/// Tuile de navigation cliquable (item de la sidebar).
///
/// États : repos / survol / actif. L'item actif porte un fond plein + un liseré
/// vert à gauche. En mode réduit, un tooltip affiche le libellé.
class NavTile extends StatefulWidget {
  const NavTile({
    super.key,
    required this.entry,
    required this.isActive,
    required this.expanded,
    required this.badge,
    required this.onTap,
  });

  final NavEntry entry;
  final bool isActive;
  final bool expanded;
  final int badge;
  final VoidCallback onTap;

  @override
  State<NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isActive = widget.isActive;
    final expanded = widget.expanded;
    const white = Colors.white;

    return Tooltip(
      message: expanded ? '' : entry.label,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 44,
            margin: EdgeInsets.symmetric(
              horizontal: expanded ? 6 : 4,
              vertical: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? kNavy
                  : _hovered
                      ? white.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isActive ? kGreen : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                _IconWithBadge(
                  icon: entry.icon ?? Icons.circle_outlined,
                  isActive: isActive,
                  badge: widget.badge,
                ),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: TextStyle(
                        color: isActive ? white : white.withValues(alpha: 0.80),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.isActive,
    required this.badge,
  });
  final IconData icon;
  final bool isActive;
  final int badge;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: 19,
          color: isActive ? white : white.withValues(alpha: 0.62),
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
