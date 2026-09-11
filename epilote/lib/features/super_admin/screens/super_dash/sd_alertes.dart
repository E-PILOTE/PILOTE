part of '../super_dashboard_screen.dart';

// Bandeau d’alertes.

class _AlertesSection extends StatelessWidget {
  const _AlertesSection({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    final expiring = stats.deptStats
        .expand((d) => d.groups)
        .where((g) => g.expiresBientot)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [BoxShadow(
            color: _kOrange.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats.expirantDans30j} abonnement'
              '${stats.expirantDans30j > 1 ? 's' : ''} '
              'expirant dans les 30 prochains jours',
              style: const TextStyle(color: Color(0xFF92400E),
                  fontSize: 13, fontWeight: FontWeight.w700)),
            if (expiring.isNotEmpty)
              Text(expiring.map((g) => g.name).join(' · '),
                  style: const TextStyle(color: Color(0xFFC2410C), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ],
        )),
        TextButton.icon(
          onPressed: () => context.go(Routes.superAbonnements),
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: const Text('Gérer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: _kOrange),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4 · KPI GRID — chaque carte a son propre type de graphique
// ═══════════════════════════════════════════════════════════════════════════════

// Type de sparkline — chaque KPI a le sien
enum _SparkType { spline, splineArea, column, barH, progress }

// ─── Tendances réelles ───────────────────────────────────────────────────────
//
// Les cartes portaient des slogans écrits en dur : « ↑ dynamique »,
// « ↑ croissance », « ↑ inscriptions », « ↑ +8 % », « ✅ Nominal ». Ils
// s'affichaient quelle que soit la donnée — « 0 groupe · ↑ dynamique » — et le
// « +8 % » avait la précision d'une mesure sans en être une.
//
// Les séries mensuelles existaient déjà et comptent les CRÉATIONS du mois. On
// les lit, tout simplement.

double _lastMonth(List<MonthlyPoint> pts) => pts.isEmpty ? 0 : pts.last.value;

String _newThisMonth(List<MonthlyPoint> pts, String noun) {
  final n = _lastMonth(pts).round();
  if (n == 0) return 'aucun ce mois-ci';
  return '+$n $noun${n > 1 ? 's' : ''} ce mois-ci';
}

// ─── Ce que la page n'a pas pu lire ──────────────────────────────────────────
//
//  ⚠️ Neuf lectures de cet écran étaient avalées en silence : une requête qui
//  échoue laissait la mesure à ZÉRO, et la page annonçait « 0 élève », « 0 FCFA
//  de revenus » avec le même aplomb que la vérité. Zéro n'est pas « je ne sais
//  pas » — surtout sur l'écran où le fondateur juge l'état de son affaire.
//
//  Les cartes concernées affichent « — » ; ce bandeau dit lesquelles, et
//  pourquoi elles ne montrent rien.
class _MesuresIndisponiblesBanner extends ConsumerWidget {
  const _MesuresIndisponiblesBanner({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manquantes = stats.mesuresIndisponibles;
    if (manquantes.isEmpty) return const SizedBox.shrink();

    final noms = (manquantes.map(MesuresDashboard.libelle).toList()..sort())
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: _kOrange),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Certaines mesures n'ont pas pu être lues",
                style: TextStyle(
                    color: _kOrange, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              '$noms. Les cases correspondantes affichent « — » : elles ne sont '
              'pas à zéro, elles sont inconnues.',
              style: TextStyle(
                  color: _kText.withValues(alpha: 0.80),
                  fontSize: 11.5,
                  height: 1.35),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => ref.invalidate(superDashboardProvider),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: _kOrange),
        ),
      ]),
    );
  }
}
