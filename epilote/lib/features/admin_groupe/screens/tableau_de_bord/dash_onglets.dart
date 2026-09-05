part of '../admin_dashboard_screen.dart';

// Onglets du tableau de bord.

class _DashTabs extends ConsumerWidget {
  const _DashTabs({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      // Les deux pastilles ont une largeur incompressible : sur une fenêtre
      // réduite, elles débordaient de la colonne (bande jaune sur « Vue
      // régionale »). D'où le défilement horizontal.
      //
      // ⚠️ L'`Align` est INDISPENSABLE et avait été retiré à tort : un
      // `SingleChildScrollView` ne remplit PAS l'axe de défilement, il se
      // dimensionne sur son enfant (`constraints.constrain(child.size)`). Dans
      // une `Column` en `crossAxisAlignment.center`, le bloc d'onglets se
      // retrouvait donc CENTRÉ. L'`Align` lui rend la largeur disponible et le
      // colle à gauche, sans rien coûter au défilement.
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TabChip(
                  label: "Vue d'ensemble",
                  icon: Icons.dashboard_rounded,
                  selected: tab == 0,
                  onTap: () => ref.read(_adminTabProv.notifier).state = 0,
                ),
                const SizedBox(width: 4),
                _TabChip(
                  label: 'Vue régionale',
                  icon: Icons.map_rounded,
                  selected: tab == 1,
                  onTap: () => ref.read(_adminTabProv.notifier).state = 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [kNavyDark, kNavy])
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : kTextMuted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Onglet « Vue d'ensemble » ──────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: kNavy,
      onRefresh: () => ref.refresh(adminDashboardProvider.future),
      child: ref.watch(adminDashboardProvider).when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(adminDashboardProvider),
            ),
            data: (d) => _Overview(data: d),
          ),
    );
  }
}

class _RegionalTab extends StatelessWidget {
  const _RegionalTab();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: AdminRegionalView(),
      );
}
