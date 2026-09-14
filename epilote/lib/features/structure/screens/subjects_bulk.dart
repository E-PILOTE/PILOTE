part of 'subjects_screen.dart';

// ─── Actions groupées sur la sélection ─────────────────────────────────────

class _SubjectBulkBar extends StatelessWidget {
  const _SubjectBulkBar({
    required this.count,
    required this.onArchive,
    required this.onExport,
    required this.onClear,
  });
  final int count;
  final VoidCallback onArchive, onExport, onClear;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text('$count sélectionnée${count > 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        _BulkBtn(
            icon: Icons.archive_outlined, label: 'Archiver', onTap: onArchive),
        _BulkBtn(
            icon: Icons.download_rounded, label: 'Exporter', onTap: onExport),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Désélectionner',
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          onPressed: onClear,
        ),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
