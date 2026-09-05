part of '../school_groups_screen.dart';

// Bouton d’enregistrement de la fiche.

class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  }) : loading = false;
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool loading;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:   (_) => _ctrl.forward(),
        onTapUp:     (_) { _ctrl.reverse(); widget.onPressed?.call(); },
        onTapCancel: ()  => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.onPressed == null
                    ? [Colors.grey.shade300, Colors.grey.shade300]
                    : [const Color(0xFF1A2F5A), _kNavy],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered && widget.onPressed != null ? [
                BoxShadow(color: _kNavy.withValues(alpha: 0.4),
                    blurRadius: 16, offset: const Offset(0, 6)),
              ] : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.loading)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                Icon(widget.icon, color: Colors.white, size: 17),
              const SizedBox(width: 10),
              Text(widget.label, style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              if (!widget.loading) ...[
                const SizedBox(width: 8),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _hovered ? const Offset(0.2, 0) : Offset.zero,
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white60, size: 15),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}


// ─── Aide latérale formulaire ─────────────────────────────────────────────────

// ─── Dialog suppression premium ───────────────────────────────────────────────
