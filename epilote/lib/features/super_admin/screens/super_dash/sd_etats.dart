part of '../super_dashboard_screen.dart';

// Briques communes, chargement et erreur.

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.sub});
  final IconData icon; final String title; final String? sub;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 17, color: _kNavy),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
            color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub!, style: TextStyle(color: _kMuted, fontSize: 12)),
      ],
    ],
  );
}

// ─── Loading / Error ──────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Shimmer.fromColors(
          baseColor: kBorder,
          highlightColor: const Color(0xFFF8FAFC),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Barre du haut ─────────────────────────────────────────────
              Row(children: [
                _ShimmerBox(width: 220, height: 28, radius: 8),
                Spacer(),
                _ShimmerBox(width: 100, height: 32, radius: 8),
                SizedBox(width: 10),
                _ShimmerBox(width: 100, height: 32, radius: 8),
              ]),
              SizedBox(height: 24),
              // ── KPI row 1 (4 cartes) ───────────────────────────────────────
              _ShimmerKpiRow(),
              SizedBox(height: 12),
              // ── KPI row 2 (4 cartes) ───────────────────────────────────────
              _ShimmerKpiRow(),
              SizedBox(height: 24),
              // ── Graphiques (2 colonnes) ────────────────────────────────────
              Row(children: [
                Expanded(child: _ShimmerBox(height: 260, radius: 16)),
                SizedBox(width: 16),
                Expanded(child: _ShimmerBox(height: 260, radius: 16)),
              ]),
              SizedBox(height: 16),
              Row(children: [
                Expanded(flex: 2, child: _ShimmerBox(height: 220, radius: 16)),
                SizedBox(width: 16),
                Expanded(child: _ShimmerBox(height: 220, radius: 16)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });
  final double width, height, radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _ShimmerKpiRow extends StatelessWidget {
  const _ShimmerKpiRow();

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(4, (i) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Spacer(),
                Container(width: 46, height: 7,
                    decoration: BoxDecoration(color: kCardBg,
                        borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 8),
              Container(width: 80, height: 20,
                  decoration: BoxDecoration(color: kCardBg,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(width: 120, height: 10,
                  decoration: BoxDecoration(color: kCardBg,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    )),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.warning_amber_rounded, size: 42, color: _kRed)),
      const SizedBox(height: 18),
      Text('Impossible de charger le tableau de bord',
          style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(error, style: TextStyle(color: _kMuted, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 22),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ],
  ));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 7 · Panneau Insights IA
// ═══════════════════════════════════════════════════════════════════════════════
