part of 'programmes_screen.dart';

// ─── Répartition par niveau — barres cliquables qui filtrent la liste ───────

class _LevelBreakdown extends StatelessWidget {
  const _LevelBreakdown(
      {required this.byLevel, required this.active, required this.onPick});
  final List<ProgLevelCount> byLevel;
  final String? active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final maxN = byLevel.fold<int>(0, (m, e) => e.total > m ? e.total : m);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.stairs_outlined, size: 16, color: kNavy),
          const SizedBox(width: 8),
          Text('Programmes par niveau',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
          Text('cliquez pour filtrer',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        for (final e in byLevel)
          _LevelBar(
            label: e.code,
            count: e.total,
            ratio: maxN == 0 ? 0 : e.total / maxN,
            color: _cyc(e.cycleCode),
            active: active == e.code,
            onTap: () => onPick(e.code),
          ),
      ]),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final double ratio;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.02, 1.0),
                minHeight: 16,
                backgroundColor: kSurface,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.85)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(_pl(count, 'programme', 'programmes'),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ),
        ]),
      ),
    );
  }
}
