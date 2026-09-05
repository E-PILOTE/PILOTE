part of '../admin_dashboard_screen.dart';

// Bandeau critique et types de base des cartouches.

class _CriticalBanner extends StatelessWidget {
  const _CriticalBanner({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final msgs = <String>[];
    if (data.expireBientot) {
      msgs.add('Votre abonnement arrive à échéance');
    }
    if (data.tauxOccupationEleves >= 90) {
      msgs.add("le quota d'élèves de votre plan est presque atteint");
    }
    final message =
        '${msgs.map((m) => m).join(' · ')}. Anticipez pour éviter toute interruption de service.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kRed.withValues(alpha: 0.95), const Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Action requise',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => context.go(Routes.adminAbonnement),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kRed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            child: const Text("Gérer l'abonnement"),
          ),
        ],
      ),
    );
  }
}

// ─── Section KPI ────────────────────────────────────────────────────────────
enum _Spark { area, bars, progress }

class _Kpi {
  _Kpi({
    required this.icon,
    required this.color,
    required this.rawValue,
    required this.fmt,
    required this.label,
    required this.spark,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.areaPts = const [],
    this.bars = const [],
    this.progress = 0,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final num rawValue;
  final String Function(num) fmt;
  final String label;
  final _Spark spark;
  final String? sub;
  final String? trend;
  final bool trendUp;
  final List<MonthlyPoint> areaPts;
  final List<MapEntry<String, int>> bars;
  final double progress;
  final VoidCallback? onTap;
}

// ─── Ce que le tableau de bord n'a pas pu lire ───────────────────────────────
//
//  ⚠️ HUIT LECTURES ÉTAIENT MUETTES (`catch (_) {}`) : identité du groupe,
//  établissements, élèves, personnel, classes, corps enseignant, finances,
//  activité. Une requête qui échoue laissait la mesure à ZÉRO — et c'est le
//  premier écran qu'ouvre un administrateur de réseau, ministère compris.
class _MesuresManquantesGroupe extends ConsumerWidget {
  const _MesuresManquantesGroupe({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noms = (data.mesuresManquantes
            .map(MesuresTableauGroupe.libelle)
            .toList()
          ..sort())
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: kAccent),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Certaines mesures manquent',
                style: TextStyle(
                    color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              'Non lues : $noms. Les cases correspondantes ne sont pas à zéro, '
              'elles sont inconnues.',
              style: TextStyle(
                  color: kTextPrimary.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.35),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => ref.invalidate(adminDashboardProvider),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: kAccent),
        ),
      ]),
    );
  }
}
