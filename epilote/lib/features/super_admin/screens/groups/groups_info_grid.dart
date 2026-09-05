part of '../school_groups_screen.dart';

// Titre de section et grille d’informations.

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800,
      letterSpacing: 0.2));
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid(this.items);
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: items.map((i) => SizedBox(
      width: (MediaQuery.of(context).size.width - 240) / 2 - 36,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Icon(i.icon, size: 16, color: _kNavy),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.label, style: TextStyle(color: _kMuted, fontSize: 10.5,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(i.value, style: TextStyle(color: _kText, fontSize: 13,
                fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    )).toList(),
  );
}

class _InfoItem {
  const _InfoItem(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
}

InputDecoration _inputDeco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: _kMuted, fontSize: 13),
  filled: true,
  fillColor: _kSurface,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kNavy, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kRed),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
);

// ─── Formatters ───────────────────────────────────────────────────────────────

String _fmtXaf(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} M FCFA';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} k FCFA';
  return '${v.toStringAsFixed(0)} FCFA';
}
