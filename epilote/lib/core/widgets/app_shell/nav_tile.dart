import 'package:flutter/material.dart';

import '../admin_ui.dart' show kNavy, kGreen;
import 'nav_models.dart';

/// Tuile de navigation cliquable (item de la sidebar).
///
/// États : repos / survol / actif / verrouillé. L'item actif porte un fond plein
/// + un liseré vert à gauche. En mode réduit, un tooltip affiche le libellé.
///
/// [locked] : module gelé par le hard-lock d'abonnement impayé (ADR-0009). La
/// tuile est grisée, porte un cadenas, le curseur devient « interdit » et le clic
/// est MORT (aucune navigation) — seuls Dashboard et pages hors abonnement
/// restent vivants. Le mur de renouvellement reste atteignable via le routeur
/// (deep-link) et la bannière de licence.
class NavTile extends StatefulWidget {
  const NavTile({
    super.key,
    required this.entry,
    required this.isActive,
    required this.expanded,
    required this.badge,
    required this.onTap,
    this.locked = false,
  });

  final NavEntry entry;
  final bool isActive;
  final bool expanded;
  final int badge;
  final VoidCallback onTap;
  final bool locked;

  @override
  State<NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final locked = widget.locked;
    // Un item verrouillé ne peut jamais paraître actif ni réagir au survol.
    final isActive = widget.isActive && !locked;
    final expanded = widget.expanded;
    const white = Colors.white;

    // Opacité du contenu : normal, ou atténué si verrouillé.
    final double contentAlpha = locked ? 0.34 : 0.80;

    return Tooltip(
      message: locked
          ? '${entry.label} — abonnement à renouveler'
          : (expanded ? '' : entry.label),
      preferBelow: false,
      child: MouseRegion(
        cursor: locked
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = !locked),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          // Clic MORT quand verrouillé : on absorbe le tap sans naviguer.
          onTap: locked ? () {} : widget.onTap,
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
                  badge: locked ? 0 : widget.badge,
                  dimmed: locked,
                ),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: TextStyle(
                        color: isActive
                            ? white
                            : white.withValues(alpha: contentAlpha),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (locked)
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: white.withValues(alpha: 0.34),
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
    this.dimmed = false,
  });
  final IconData icon;
  final bool isActive;
  final int badge;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: 19,
          color: isActive
              ? white
              : white.withValues(alpha: dimmed ? 0.30 : 0.62),
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
