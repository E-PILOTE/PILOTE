import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/audit_data.dart';
import 'widgets/audit_activity_tab.dart';
import 'widgets/audit_alerts_tab.dart';
import 'widgets/audit_charts_tab.dart';
import 'widgets/audit_kpi.dart';

/// Journal d'audit — **module partagé scope-aware** (cf. [auditScopeProvider]).
/// Monté à l'identique par l'espace admin_groupe (`/admin/audit`, périmètre
/// groupe) et par la direction d'école (`/user/journal-audit`, périmètre école,
/// dimension « École » masquée). Lecture ONLINE (donnée de gouvernance).
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh(AuditFilters filters) async {
    ref.invalidate(auditFacetsProvider);
    ref.invalidate(auditPageProvider);
    ref.invalidate(auditTimelineProvider);
    await ref.read(auditFacetsProvider(filters.facetKey).future);
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(auditScopeProvider);
    if (scope == null) {
      return const AppShell(
        title: "Journal d'audit",
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: AdminEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Consultation indisponible',
              message:
                  "Le journal d'audit est une donnée de gouvernance consultée "
                  'en ligne. Vérifiez votre connexion et votre session.',
            ),
          ),
        ),
      );
    }

    final filters = ref.watch(auditFiltersProvider);
    final facetsAsync = ref.watch(auditFacetsProvider(filters.facetKey));
    final timelineAsync = ref.watch(auditTimelineProvider);

    // Alertes calculées dès que les deux sources sont disponibles.
    final alerts =
        facetsAsync.valueOrNull != null && timelineAsync.valueOrNull != null
            ? computeAuditAlerts(timelineAsync.value!, facetsAsync.value!)
            : <AuditAlert>[];
    final alertCount = alerts.length;
    final hasCritical = alerts.any((a) => a.level == AuditAlertLevel.critical);

    return AppShell(
      title: "Journal d'audit",
      child: RefreshIndicator(
        color: kNavy,
        onRefresh: () => _refresh(filters),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── KPI row ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: facetsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const AuditKpiSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
                data: (f) => AuditKpiGrid(facets: f),
              ),
            ),

            // ── Bandeau alertes critiques ────────────────────────────────────
            if (hasCritical)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: AuditCriticalAlertBanner(
                    alerts: alerts
                        .where((a) => a.level == AuditAlertLevel.critical)
                        .toList()),
              ),

            // ── Tab bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: kNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: kTextMuted,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Activité'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Graphiques'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active_rounded,
                              size: 16),
                          const SizedBox(width: 6),
                          const Text('Alertes'),
                          if (alertCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: hasCritical ? kRed : kAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$alertCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: hasCritical ? Colors.white : kNavy,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 2),
            Divider(height: 1, color: kBorder),

            // ── Contenu des onglets ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  AuditActivityTab(facetsAsync: facetsAsync, scope: scope),
                  AuditChartsTab(
                      timelineAsync: timelineAsync,
                      showSchools: scope.showSchoolDimension),
                  AuditAlertsTab(
                    alerts: alerts,
                    isLoading:
                        facetsAsync.isLoading || timelineAsync.isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
