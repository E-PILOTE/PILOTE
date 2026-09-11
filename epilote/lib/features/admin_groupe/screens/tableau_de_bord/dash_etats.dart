part of '../admin_dashboard_screen.dart';

// États de chargement et d’erreur.

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          decoration: BoxDecoration(
              color: kCardBg, borderRadius: BorderRadius.circular(14)),
        );
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDF3),
      highlightColor: const Color(0xFFF7FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        children: [
          block(112),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: block(168)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(flex: 3, child: block(300)),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: block(300)),
            ],
          ),
          const SizedBox(height: 24),
          block(220),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 64),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle),
                  child: Icon(Icons.cloud_off_rounded,
                      size: 40, color: kRed),
                ),
                const SizedBox(height: 18),
                Text('Impossible de charger le tableau de bord',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────
String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

const List<String> _kJours = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];
const List<String> _kMois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _frDate() {
  final n = DateTime.now();
  return '${_kJours[n.weekday - 1]} ${n.day} ${_kMois[n.month - 1]} ${n.year}';
}

String _pct(double v) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)} %';

String _deptKeyOf(SchoolSummary s) {
  final d = s.department?.trim();
  return (d == null || d.isEmpty) ? 'Non précisé' : d;
}

String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => t,
    };

Color _typeColor(String t) => switch (t) {
      'public' => _kBlue,
      'prive' => kGreen,
      _ => kTextMuted,
    };
