part of '../super_dashboard_screen.dart';

// Onglets du tableau de bord plateforme.

class _DashboardTabs extends ConsumerWidget {
  const _DashboardTabs({required this.active});
  final int active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(children: [
        _TabChip(
          icon: Icons.dashboard_rounded,
          label: "Vue d'ensemble",
          selected: active == 0,
          onTap: () => ref.read(_dashTabProvider.notifier).state = 0,
        ),
        const SizedBox(width: 10),
        _TabChip(
          icon: Icons.public_rounded,
          label: 'Vue Nationale',
          selected: active == 1,
          onTap: () => ref.read(_dashTabProvider.notifier).state = 1,
        ),
      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
  });
  final IconData icon; final String label;
  final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kNavy : _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _kNavy : kBorder),
          boxShadow: selected ? [BoxShadow(
              color: _kNavy.withValues(alpha: 0.25),
              blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : _kMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kMuted)),
        ]),
      ),
    ),
  );
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(superDashboardProvider);
    final profile    = ref.watch(authNotifierProvider).valueOrNull;
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing  = syncStatus.valueOrNull?.connected ?? false;

    return statsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const _LoadingState(),
      error:   (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(superDashboardProvider)),
      data: (stats) => Container(
        color: _kBg,
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(profile: profile),
                const SizedBox(height: 20),
                _QuickActions(),
                const SizedBox(height: 20),
                // Avant les chiffres : ce que la page n'a pas pu lire. Le
                // lecteur doit le savoir AVANT de regarder les cartes, pas
                // après s'être fait une opinion.
                if (stats.mesuresIndisponibles.isNotEmpty) ...[
                  _MesuresIndisponiblesBanner(stats: stats),
                  const SizedBox(height: 20),
                ],
                if (stats.expirantDans30j > 0) ...[
                  _AlertesSection(stats: stats),
                  const SizedBox(height: 20),
                ],
                _KpiGrid(stats: stats, isSyncing: isSyncing),
                const SizedBox(height: 22),
                _AiInsightsPanel(stats: stats),
                const SizedBox(height: 22),
                _RevenueSection(stats: stats),
                const SizedBox(height: 22),
                _ChartsRow(stats: stats),
                // Adoption du module Examens d'État à l'échelle plateforme
                // (s'efface si aucun groupe ne l'utilise).
                const SuperExamsSection(),
                const SizedBox(height: 22),
                _BottomRow(stats: stats),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 1 · En-tête ─────────────────────────────────────────────────────────────
