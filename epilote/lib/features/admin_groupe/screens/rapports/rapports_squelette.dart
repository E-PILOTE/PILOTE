part of '../admin_reports_screen.dart';

// Squelette de chargement.

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFFE8ECF0),
        highlightColor: const Color(0xFFF5F7FA),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(double.infinity, 120, r: 12),
              const SizedBox(height: 16),
              _box(360, 42, r: 8),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.6,
                ),
                itemCount: 6,
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 14),
              ),
              const SizedBox(height: 20),
              _box(double.infinity, 280, r: 14),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════════════
Color _rateColor(double v) => v >= 70 ? kGreen : v >= 40 ? kAccent : kRed;

Color _typeColor(String type) => switch (type) {
      'public' => _kBlue,
      'prive' => kGreen,
      _ => kNavy,
    };

String _typeLabel(String type) => switch (type) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => type,
    };

String _fmtD(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Format monétaire compact : 1 250 000 → "1,3 M", 45 000 → "45 k".
String _compactXaf(num v) {
  final a = v.abs();
  String s;
  if (a >= 1e9) {
    s = '${(v / 1e9).toStringAsFixed(a >= 1e10 ? 0 : 1)} Md';
  } else if (a >= 1e6) {
    s = '${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)} M';
  } else if (a >= 1e3) {
    s = '${(v / 1e3).toStringAsFixed(0)} k';
  } else {
    s = v.toStringAsFixed(0);
  }
  return s.replaceAll('.', ',');
}

// ─── Ce que le rapport n'a pas pu lire ───────────────────────────────────────
//
//  ⚠️ SEPT LECTURES ÉTAIENT MUETTES (`catch (_) {}`) : établissements, élèves,
//  personnel, classes, paiements, identité du groupe, année scolaire. Une
//  requête qui échouait laissait « 0 école », « 0 élève », « 0 FCFA encaissé »
//  — et ce rapport s'exporte en PDF pour un ministère. Un zéro rond est
//  d'autant plus crédible qu'il est net.
