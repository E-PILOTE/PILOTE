import 'package:flutter/material.dart';

import '../admin_ui.dart' show kNavyDark, kGreen;

/// Poignée verticale permettant de redimensionner la sidebar à la souris.
class SidebarResizeHandle extends StatefulWidget {
  const SidebarResizeHandle({super.key, required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: _hovered
              ? kGreen.withValues(alpha: 0.55)
              : kNavyDark.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}
