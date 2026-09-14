part of '../modules_screen.dart';

// Confirmation de suppression.

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.emoji,
    required this.color,
    required this.title,
    required this.name,
    required this.subtitle,
    required this.warning,
    required this.confirmLabel,
  });
  final String emoji, title, name, subtitle, warning, confirmLabel;
  final Color color;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: const TextStyle(
                      color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Cette action est irréversible',
                      style: TextStyle(color: _kMuted, fontSize: 11.5)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.color.withValues(alpha: 0.25)),
                    ),
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.name, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _kText),
                        overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle, style: TextStyle(
                        fontSize: 12, color: _kMuted)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kRed.withValues(alpha: 0.20)),
                ),
                child: Text(widget.warning,
                    style: const TextStyle(color: _kRed, fontSize: 12.5)),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : Colors.transparent,
                        border: Border.all(
                            color: _confirmed ? _kRed : _kMuted, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmed
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.confirmLabel,
                        style: TextStyle(fontSize: 12.5, color: _kText))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Annuler', style: TextStyle(
                          color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                  child: InkWell(
                    onTap: _confirmed ? () => Navigator.pop(context, true) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : _kMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_forever_rounded,
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                            size: 15),
                        const SizedBox(width: 6),
                        Text('Supprimer définitivement',
                            style: TextStyle(
                                color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────
