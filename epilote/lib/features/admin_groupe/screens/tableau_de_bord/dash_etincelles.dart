part of '../admin_dashboard_screen.dart';

// Étincelles de progression et plate.

class _SparkProgress extends StatelessWidget {
  const _SparkProgress({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (ctx, t, _) => LinearProgressIndicator(
              value: t,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(v * 100).round()} %',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _FlatSpark extends StatelessWidget {
  const _FlatSpark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ─── Graphiques (inscriptions + répartition) ────────────────────────────────
