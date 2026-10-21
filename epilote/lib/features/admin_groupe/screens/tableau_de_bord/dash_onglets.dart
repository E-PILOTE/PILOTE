part of '../admin_dashboard_screen.dart';

// Vue d'ensemble du tableau de bord — son seul contenu depuis le retrait de
// la « Vue régionale » (2026-10-21).

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
