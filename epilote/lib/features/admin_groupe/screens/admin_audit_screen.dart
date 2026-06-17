import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/admin_audit_provider.dart';
import '../providers/admin_users_provider.dart' show roleLabel;
import '../../../core/widgets/admin_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen>
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
    ref.invalidate(adminAuditFacetsProvider);
    ref.invalidate(adminAuditPageProvider);
    ref.invalidate(adminAuditTimelineProvider);
    await ref.read(adminAuditFacetsProvider(filters.facetKey).future);
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(adminAuditFiltersProvider);
    final facetsAsync = ref.watch(adminAuditFacetsProvider(filters.facetKey));
    final timelineAsync = ref.watch(adminAuditTimelineProvider);

    // Alertes calculées dès que les deux sources sont disponibles
    final alerts = facetsAsync.valueOrNull != null && timelineAsync.valueOrNull != null
        ? computeAuditAlerts(timelineAsync.value!, facetsAsync.value!)
        : <AuditAlert>[];
    final alertCount = alerts.length;

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
                loading: () => const _KpiSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
                data: (f) => _KpiGrid(facets: f),
              ),
            ),

            // ── Bandeau alertes critiques ────────────────────────────────────
            if (alerts.any((a) => a.level == AuditAlertLevel.critical))
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: _CriticalAlertBanner(
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
                          const Icon(Icons.notifications_active_rounded, size: 16),
                          const SizedBox(width: 6),
                          const Text('Alertes'),
                          if (alertCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: alertCount > 0 &&
                                        alerts.any((a) =>
                                            a.level == AuditAlertLevel.critical)
                                    ? kRed
                                    : kAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$alertCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: alertCount > 0 &&
                                          alerts.any((a) =>
                                              a.level == AuditAlertLevel.critical)
                                      ? Colors.white
                                      : kNavy,
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
            const Divider(height: 1, color: kBorder),

            // ── Contenu des onglets ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Onglet 0 — Activité (liste filtrée + paginée)
                  _ActivityTab(facetsAsync: facetsAsync),

                  // Onglet 1 — Graphiques
                  _ChartsTab(timelineAsync: timelineAsync),

                  // Onglet 2 — Alertes
                  _AlertsTab(
                    alerts: alerts,
                    isLoading: facetsAsync.isLoading || timelineAsync.isLoading,
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

// ─────────────────────────────────────────────────────────────────────────────
// KPI
// ─────────────────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.facets});
  final AuditFacets facets;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      AdminStatCard(
        label: 'Événements',
        value: '${facets.total}',
        icon: Icons.list_alt_rounded,
        color: kNavy,
        subtitle: _breakdown(facets),
      ),
      AdminStatCard(
        label: 'Créations',
        value: '${facets.creations}',
        icon: Icons.add_circle_rounded,
        color: kGreen,
      ),
      AdminStatCard(
        label: 'Modifications',
        value: '${facets.modifications}',
        icon: Icons.edit_rounded,
        color: kAccent,
      ),
      AdminStatCard(
        label: 'Suppressions',
        value: '${facets.suppressions}',
        icon: Icons.delete_rounded,
        color: kRed,
      ),
      AdminStatCard(
        label: 'Utilisateurs actifs',
        value: '${facets.activeUsers}',
        icon: Icons.group_rounded,
        color: kNavy,
      ),
      AdminStatCard(
        label: 'Dernier événement',
        value: _lastValue(facets.lastEventAt),
        icon: Icons.schedule_rounded,
        color: kNavy,
        subtitle: facets.lastEventAt != null ? _fullDate(facets.lastEventAt!) : null,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
      );
    });
  }

  static String _breakdown(AuditFacets f) {
    if (f.total == 0) return 'Aucune activité';
    return '${f.creations} créa · ${f.modifications} modif · ${f.suppressions} suppr';
  }

  static String _lastValue(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  static String _fullDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      'à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(
            6,
            (_) => SizedBox(
                  width: w,
                  height: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                  ),
                )),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANDEAU ALERTE CRITIQUE (hors onglet)
// ─────────────────────────────────────────────────────────────────────────────
class _CriticalAlertBanner extends StatelessWidget {
  const _CriticalAlertBanner({required this.alerts});
  final List<AuditAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alerts.first.title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kRed),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Voir les alertes →',
            style: TextStyle(
                fontSize: 12,
                color: kRed.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 0 — ACTIVITÉ
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.facetsAsync});
  final AsyncValue<AuditFacets> facetsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(adminAuditFiltersProvider);
    final pageAsync = ref.watch(adminAuditPageProvider(filters));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _FilterBar(
          filters: filters,
          tables: facetsAsync.valueOrNull?.tables ?? const [],
          roles: facetsAsync.valueOrNull?.roles ?? const [],
          schools: facetsAsync.valueOrNull?.schools ?? const [],
        ),
        const SizedBox(height: 16),
        pageAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: kNavy)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: AdminErrorBanner(message: 'Erreur de chargement : $e'),
          ),
          data: (page) => _AuditList(filters: filters, page: page),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRE DE FILTRES
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({
    required this.filters,
    required this.tables,
    required this.roles,
    required this.schools,
  });
  final AuditFilters filters;
  final List<String> tables;
  final List<String> roles;
  final List<({String id, String name})> schools;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.filters.query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(AuditFilters next) {
    ref.read(adminAuditFiltersProvider.notifier).state =
        next.copyWith(page: 0);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _update(widget.filters.copyWith(query: value));
    });
  }

  Future<void> _pickRange() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DateRangePickerDialog(
        initialFrom: widget.filters.dateFrom,
        initialTo: widget.filters.dateTo,
      ),
    );
    if (result != null && mounted) {
      _update(widget.filters.copyWith(
          dateFrom: result.start, dateTo: result.end));
    }
  }

  void _applyPreset(int days) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    _update(widget.filters.copyWith(dateFrom: from, dateTo: now));
  }

  void _clearDate() {
    _update(widget.filters.copyWith(dateFrom: null, dateTo: null));
  }

  void _openExportDialog(AuditPage? page) {
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExportDialog(
        filters: widget.filters,
        currentPageEntries: page?.entries ?? const [],
        totalCount: page?.totalCount ?? 0,
        groupId: auth.groupId ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final pageAsync = ref.watch(adminAuditPageProvider(f));

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Presets rapides
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                label: 'Auj.',
                active: _isPreset(f, 1),
                onTap: () => _applyPreset(1),
              ),
              _PresetChip(
                label: '7 j',
                active: _isPreset(f, 7),
                onTap: () => _applyPreset(7),
              ),
              _PresetChip(
                label: '30 j',
                active: _isPreset(f, 30),
                onTap: () => _applyPreset(30),
              ),
              _PresetChip(
                label: '3 mois',
                active: _isPreset(f, 90),
                onTap: () => _applyPreset(90),
              ),
              const SizedBox(width: 0), // force new row if needed
            ],
          ),
          const SizedBox(height: 10),

          // Filtres principaux
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: adminInputDecoration(
                    'Rechercher',
                    icon: Icons.search_rounded,
                    hint: 'Entité, utilisateur…',
                  ),
                ),
              ),
              SizedBox(
                width: 175,
                child: DropdownButtonFormField<String>(
                  initialValue: f.action,
                  isExpanded: true,
                  decoration: adminInputDecoration('Action',
                      icon: Icons.bolt_rounded),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Toutes les')),
                    DropdownMenuItem(
                        value: 'INSERT', child: Text('Créations')),
                    DropdownMenuItem(
                        value: 'UPDATE', child: Text('Modifications')),
                    DropdownMenuItem(
                        value: 'DELETE', child: Text('Suppressions')),
                  ],
                  onChanged: (v) =>
                      _update(f.copyWith(action: v ?? 'all')),
                ),
              ),
              SizedBox(
                width: 195,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.tables.contains(f.table) ? f.table : 'all',
                  isExpanded: true,
                  decoration: adminInputDecoration('Entité',
                      icon: Icons.table_rows_rounded),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Toutes les entités')),
                    ...widget.tables.map((t) => DropdownMenuItem(
                        value: t, child: Text(auditEntityLabel(t)))),
                  ],
                  onChanged: (v) =>
                      _update(f.copyWith(table: v ?? 'all')),
                ),
              ),
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.roles.contains(f.role) ? f.role : 'all',
                  isExpanded: true,
                  decoration: adminInputDecoration('Rôle',
                      icon: Icons.badge_outlined),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Tous les rôles')),
                    ...widget.roles.map((r) => DropdownMenuItem(
                        value: r, child: Text(roleLabel(r)))),
                  ],
                  onChanged: (v) =>
                      _update(f.copyWith(role: v ?? 'all')),
                ),
              ),
              if (widget.schools.isNotEmpty)
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.schools.any((s) => s.id == f.schoolId)
                        ? f.schoolId
                        : 'all',
                    isExpanded: true,
                    decoration: adminInputDecoration('École',
                        icon: Icons.school_outlined),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('Toutes les écoles')),
                      ...widget.schools.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) =>
                        _update(f.copyWith(schoolId: v ?? 'all')),
                  ),
                ),
              _DateRangeSelector(
                dateFrom: f.dateFrom,
                dateTo: f.dateTo,
                onPick: _pickRange,
                onClear: _clearDate,
              ),
              _ExportButton(
                onPressed: () => _openExportDialog(pageAsync.valueOrNull),
                totalCount: pageAsync.valueOrNull?.totalCount ?? 0,
              ),
            ],
          ),
          if (f.hasActiveFilters) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _debounce?.cancel();
                  _searchCtrl.clear();
                  ref.read(adminAuditFiltersProvider.notifier).state =
                      const AuditFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Réinitialiser'),
                style: TextButton.styleFrom(foregroundColor: kTextMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isPreset(AuditFilters f, int days) {
    if (f.dateFrom == null || f.dateTo == null) return false;
    final now = DateTime.now();
    final expected = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    return f.dateFrom!.year == expected.year &&
        f.dateFrom!.month == expected.month &&
        f.dateFrom!.day == expected.day;
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? kNavy : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kNavy : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : kTextMuted,
          ),
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTE + PAGINATION
// ─────────────────────────────────────────────────────────────────────────────
class _AuditList extends ConsumerWidget {
  const _AuditList({required this.filters, required this.page});
  final AuditFilters filters;
  final AuditPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: AdminEmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: filters.hasActiveFilters ? 'Aucun résultat' : 'Journal vide',
          message: filters.hasActiveFilters
              ? 'Aucun événement ne correspond à vos filtres.'
              : 'Le journal retrace chaque action sensible des utilisateurs. Il se remplira automatiquement dès la première opération.',
        ),
      );
    }

    final totalPages = (page.totalCount / kAuditPageSize).ceil();
    final from = filters.page * kAuditPageSize + 1;
    final to = filters.page * kAuditPageSize + page.entries.length;

    return Column(
      children: [
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < page.entries.length; i++) ...[
                _AuditRow(
                  e: page.entries[i],
                  onTap: () =>
                      _showDetail(context, ref, page.entries[i]),
                ),
                if (i != page.entries.length - 1)
                  const Divider(height: 1, color: kBorder),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Pager(
          from: from,
          to: to,
          total: page.totalCount,
          pageIndex: filters.page,
          totalPages: totalPages,
          onPrev: filters.page > 0
              ? () => ref.read(adminAuditFiltersProvider.notifier).state =
                  filters.copyWith(page: filters.page - 1)
              : null,
          onNext: filters.page < totalPages - 1
              ? () => ref.read(adminAuditFiltersProvider.notifier).state =
                  filters.copyWith(page: filters.page + 1)
              : null,
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, AuditEntry e) {
    showDialog(
      context: context,
      builder: (_) => _AuditDetailDialog(
        entry: e,
        onFilterSchool: e.schoolId != null
            ? () {
                ref.read(adminAuditFiltersProvider.notifier).state =
                    const AuditFilters().copyWith(schoolId: e.schoolId);
                Navigator.of(context).pop();
              }
            : null,
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.from,
    required this.to,
    required this.total,
    required this.pageIndex,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });
  final int from, to, total, pageIndex, totalPages;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$from–$to sur $total événements',
            style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
        Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
              color: kNavy,
              disabledColor: kBorder,
              tooltip: 'Précédent',
            ),
            Text(
                '${pageIndex + 1} / ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              color: kNavy,
              disabledColor: kBorder,
              tooltip: 'Suivant',
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIGNE D'AUDIT
// ─────────────────────────────────────────────────────────────────────────────
(Color, IconData) _actionStyle(String action) => switch (action.toUpperCase()) {
      'INSERT' => (kGreen, Icons.add_rounded),
      'UPDATE' => (kAccent, Icons.edit_rounded),
      'DELETE' => (kRed, Icons.delete_outline_rounded),
      _ => (kTextMuted, Icons.bolt_rounded),
    };

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.e, required this.onTap});
  final AuditEntry e;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _actionStyle(e.action);
    final severity = e.severity;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur de sévérité (barre colorée à gauche)
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: switch (severity) {
                  AuditSeverity.high => kRed,
                  AuditSeverity.medium => kAccent,
                  AuditSeverity.low => Colors.transparent,
                },
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(e.actionLabel,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('· ${e.entityLabel}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ),
                    if (severity == AuditSeverity.high) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: kRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('SENSIBLE',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: kRed,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 13, color: kTextMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${e.userName} · ${e.roleLbl}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: kTextMuted)),
                    ),
                    if (e.schoolName != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.school_outlined,
                          size: 13, color: kTextMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(e.schoolName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: kTextMuted)),
                      ),
                    ],
                    if (e.ipAddress != null &&
                        e.ipAddress!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.lan_outlined,
                          size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text(e.ipAddress!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontFamily: 'monospace')),
                    ],
                  ]),
                  if (e.action.toUpperCase() == 'UPDATE' &&
                      e.newFields.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: e.newFields.take(5).map((field) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: kBorder),
                            ),
                            child: Text(field,
                                style: const TextStyle(
                                    fontSize: 10.5, color: kTextMuted)),
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeLabel(e.createdAt),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: kTextMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 1 — GRAPHIQUES
// ─────────────────────────────────────────────────────────────────────────────
class _ChartsTab extends ConsumerWidget {
  const _ChartsTab({required this.timelineAsync});
  final AsyncValue<AuditTimeline> timelineAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return timelineAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(color: kNavy),
        ),
      ),
      error: (e, _) => Center(
          child: AdminErrorBanner(message: 'Erreur graphiques : $e')),
      data: (timeline) {
        if (timeline.buckets.every((b) => b.total == 0)) {
          return const Padding(
            padding: EdgeInsets.only(top: 60),
            child: AdminEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Aucune donnée (30 derniers jours)',
              message:
                  'Les graphiques se rempliront dès que des événements auront été enregistrés.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Timeline ──────────────────────────────────────────────────
            _ChartCard(
              title: 'Activité des 30 derniers jours',
              subtitle: 'Créations · Modifications · Suppressions par jour',
              child: SizedBox(
                height: 220,
                child: _TimelineChart(buckets: timeline.buckets),
              ),
            ),
            const SizedBox(height: 16),

            // ── Distribution + Top entités ──────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 700;
              final row = <Widget>[
                _ChartCard(
                  title: 'Répartition par action',
                  subtitle: '% Créations / Modifs / Suppressions',
                  child: SizedBox(
                    height: 200,
                    child: _DonutActionChart(buckets: timeline.buckets),
                  ),
                ),
                const SizedBox(width: 16, height: 16),
                _ChartCard(
                  title: 'Top entités',
                  subtitle: '5 entités les plus fréquentes',
                  child: SizedBox(
                    height: 200,
                    child: _TopEntitiesChart(
                        entities: timeline.topEntities),
                  ),
                ),
              ];
              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: row[0]),
                      row[1],
                      Expanded(child: row[2]),
                    ],
                  ),
                );
              }
              return Column(children: row);
            }),
            const SizedBox(height: 16),

            // ── Top Écoles + Top Acteurs ────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 700;
              final row = <Widget>[
                _RankingCard(
                  title: 'Top écoles (activité 30 j)',
                  icon: Icons.school_rounded,
                  items: timeline.topSchools
                      .map((s) => (label: s.name, count: s.count))
                      .toList(),
                  maxCount: timeline.topSchools.isEmpty
                      ? 1
                      : timeline.topSchools.first.count,
                  barColor: kNavy,
                  emptyMessage: 'Aucune école dans les logs',
                ),
                const SizedBox(width: 16, height: 16),
                _RankingCard(
                  title: 'Top acteurs (activité 30 j)',
                  icon: Icons.person_rounded,
                  items: timeline.topActors
                      .map((a) => (
                            label: a.name,
                            count: a.count,
                          ))
                      .toList(),
                  maxCount: timeline.topActors.isEmpty
                      ? 1
                      : timeline.topActors.first.count,
                  barColor: const Color(0xFF6366F1),
                  emptyMessage: 'Aucun acteur identifié',
                ),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: row[0]),
                    row[1],
                    Expanded(child: row[2]),
                  ],
                );
              }
              return Column(children: row);
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// — Conteneur de graphique avec titre —
class _ChartCard extends StatelessWidget {
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// — Graphique timeline (30 jours, colonnes empilées) —
class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.buckets});
  final List<AuditDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    // On n'affiche qu'un label toutes les 7 buckets pour éviter la surcharge
    final labeledIndices = <int>{0, 6, 13, 20, 27, buckets.length - 1};

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(fontSize: 10, color: kTextMuted),
        labelPlacement: LabelPlacement.onTicks,
        axisLabelFormatter: (details) {
          final idx = details.value.toInt();
          if (!labeledIndices.contains(idx) ||
              idx < 0 ||
              idx >= buckets.length) {
            return ChartAxisLabel('', null);
          }
          return ChartAxisLabel(buckets[idx].dayLabel, null);
        },
      ),
      primaryYAxis: const NumericAxis(
        majorGridLines: MajorGridLines(
            width: 0.5, color: kBorder, dashArray: [4, 4]),
        axisLine: AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        minimum: 0,
      ),
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(fontSize: 11, color: kTextMuted),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Créations',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.inserts.toDouble(),
          color: kGreen.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: BorderRadius.zero,
        ),
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Modifications',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.updates.toDouble(),
          color: kAccent.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: BorderRadius.zero,
        ),
        StackedColumnSeries<AuditDayBucket, String>(
          name: 'Suppressions',
          dataSource: buckets,
          xValueMapper: (b, _) => b.dayLabel,
          yValueMapper: (b, _) => b.deletes.toDouble(),
          color: kRed.withValues(alpha: 0.85),
          width: 0.6,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),
      ],
    );
  }
}

// — Donut distribution des actions —
class _DonutActionChart extends StatelessWidget {
  const _DonutActionChart({required this.buckets});
  final List<AuditDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold(0, (s, b) => s + b.total);
    final inserts = buckets.fold(0, (s, b) => s + b.inserts);
    final updates = buckets.fold(0, (s, b) => s + b.updates);
    final deletes = buckets.fold(0, (s, b) => s + b.deletes);

    if (total == 0) {
      return const Center(
          child: Text('Aucune donnée', style: TextStyle(color: kTextMuted)));
    }

    final data = [
      _ActionPct('Créations', inserts.toDouble(), kGreen),
      _ActionPct('Modifs', updates.toDouble(), kAccent),
      _ActionPct('Suppr.', deletes.toDouble(), kRed),
    ].where((d) => d.value > 0).toList();

    return SfCircularChart(
      margin: EdgeInsets.zero,
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: TextStyle(fontSize: 11, color: kTextMuted),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        DoughnutSeries<_ActionPct, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.label,
          yValueMapper: (d, _) => d.value,
          pointColorMapper: (d, _) => d.color,
          innerRadius: '55%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ActionPct {
  const _ActionPct(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

// — Bar chart top entités —
class _TopEntitiesChart extends StatelessWidget {
  const _TopEntitiesChart({required this.entities});
  final List<AuditEntityStat> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return const Center(
          child: Text('Aucune donnée', style: TextStyle(color: kTextMuted)));
    }
    return SfCartesianChart(
      margin: const EdgeInsets.all(0),
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
      ),
      primaryYAxis: const NumericAxis(
        majorGridLines: MajorGridLines(
            width: 0.5, color: kBorder, dashArray: [4, 4]),
        axisLine: AxisLine(width: 0),
        labelStyle: TextStyle(fontSize: 10, color: kTextMuted),
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        BarSeries<AuditEntityStat, String>(
          dataSource: entities,
          xValueMapper: (e, _) => e.label,
          yValueMapper: (e, _) => e.count.toDouble(),
          color: kNavy.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(fontSize: 10),
          ),
          width: 0.5,
        ),
      ],
    );
  }
}

// — Carte classement (écoles / acteurs) —
class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.maxCount,
    required this.barColor,
    required this.emptyMessage,
  });
  final String title;
  final IconData icon;
  final List<({String label, int count})> items;
  final int maxCount;
  final Color barColor;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: kNavy),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyMessage,
                style:
                    const TextStyle(fontSize: 12.5, color: kTextMuted))
          else
            for (int i = 0; i < items.length; i++) ...[
              _RankingRow(
                rank: i + 1,
                label: items[i].label,
                count: items[i].count,
                maxCount: maxCount,
                barColor: barColor,
              ),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.label,
    required this.count,
    required this.maxCount,
    required this.barColor,
  });
  final int rank;
  final String label;
  final int count;
  final int maxCount;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final pct = maxCount > 0 ? count / maxCount : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(
            width: 20,
            child: Text('$rank.',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextMuted)),
          ),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, color: kTextPrimary)),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: kSurface,
          valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: 0.7)),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLET 2 — ALERTES
// ─────────────────────────────────────────────────────────────────────────────
class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.alerts, required this.isLoading});
  final List<AuditAlert> alerts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kNavy));
    }
    if (alerts.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.check_circle_rounded,
        title: 'Aucune anomalie détectée',
        message:
            "Le journal ne présente aucun comportement suspect sur les 30 derniers jours. Les alertes s'affichent automatiquement en cas d'anomalie.",
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: alerts.length,
      separatorBuilder: (_, si) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final AuditAlert alert;

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor, labelBg, label) = switch (alert.level) {
      AuditAlertLevel.critical => (
          kRed.withValues(alpha: 0.06),
          kRed.withValues(alpha: 0.3),
          kRed,
          kRed,
          'CRITIQUE',
        ),
      AuditAlertLevel.warning => (
          kAccent.withValues(alpha: 0.08),
          kAccent.withValues(alpha: 0.35),
          kAccent,
          kAccent,
          'ATTENTION',
        ),
      AuditAlertLevel.info => (
          kNavy.withValues(alpha: 0.05),
          kNavy.withValues(alpha: 0.2),
          kNavy,
          kNavy,
          'INFO',
        ),
    };

    final icon = switch (alert.level) {
      AuditAlertLevel.critical => Icons.warning_rounded,
      AuditAlertLevel.warning => Icons.trending_up_rounded,
      AuditAlertLevel.info => Icons.info_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(alert.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: iconColor)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: labelBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(alert.description,
                    style: const TextStyle(
                        fontSize: 13, color: kTextPrimary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DÉTAIL ENRICHI
// ─────────────────────────────────────────────────────────────────────────────
class _AuditDetailDialog extends StatelessWidget {
  const _AuditDetailDialog({required this.entry, this.onFilterSchool});
  final AuditEntry entry;
  final VoidCallback? onFilterSchool;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (color, _) = _actionStyle(e.action);
    final diff = e.buildDiff();
    final isInsert = e.action.toUpperCase() == 'INSERT';
    final isDelete = e.action.toUpperCase() == 'DELETE';
    final severity = e.severity;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            AdminDialogHeader(
              title: '${e.actionLabel} · ${e.entityLabel}',
              subtitle: _fullDate(e.createdAt),
              icon: Icons.history_rounded,
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sévérité + contexte ──────────────────────────────
                    Row(
                      children: [
                        _SeverityBadge(severity: severity),
                        const SizedBox(width: 8),
                        AdminBadge(e.actionLabel, color: color),
                        if (e.recordId != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: e.recordId!));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('ID copié dans le presse-papier'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded,
                                      size: 12, color: kTextMuted),
                                  const SizedBox(width: 5),
                                  Text(
                                    _truncateId(e.recordId!),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kTextMuted,
                                        fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Métadonnées ──────────────────────────────────────
                    AdminDetailCard([
                      AdminDetailRow(Icons.person_outline_rounded, 'Auteur',
                          '${e.userName} (${e.roleLbl})'),
                      AdminDetailRow(Icons.table_rows_rounded, 'Entité',
                          '${e.entityLabel} · ${e.tableName}'),
                      if (e.schoolName != null)
                        AdminDetailRow(Icons.school_outlined, 'École',
                            e.schoolName!),
                      AdminDetailRow(Icons.schedule_rounded, 'Horodatage',
                          _fullDate(e.createdAt)),
                      if (e.ipAddress != null && e.ipAddress!.isNotEmpty)
                        AdminDetailRow(Icons.lan_outlined, 'Adresse IP',
                            e.ipAddress!,
                            mono: true),
                      if (e.userAgent != null && e.userAgent!.isNotEmpty)
                        AdminDetailRow(Icons.devices_rounded, 'Appareil',
                            _simplifyUserAgent(e.userAgent!),
                            last: e.recordId == null),
                      if (e.recordId != null)
                        AdminDetailRow(Icons.tag_rounded, 'ID enregistrement',
                            e.recordId!,
                            mono: true,
                            last: true),
                    ]),
                    const SizedBox(height: 18),

                    // ── Diff ─────────────────────────────────────────────
                    Row(children: [
                      const AdminModalSectionTitle('Détail des changements'),
                      const SizedBox(width: 8),
                      if (isInsert)
                        const AdminBadge('Création',
                            color: kGreen, icon: Icons.add_rounded)
                      else if (isDelete)
                        const AdminBadge('Suppression',
                            color: kRed,
                            icon: Icons.delete_outline_rounded)
                      else
                        AdminBadge(
                          '${diff.where((d) => d.kind == AuditDiffKind.changed).length} champ(s)',
                          color: kAccent,
                          icon: Icons.edit_rounded,
                        ),
                    ]),
                    const SizedBox(height: 10),
                    if (diff.isEmpty)
                      _noDataBox()
                    else
                      _DiffTable(
                          diff: diff,
                          showBefore: !isInsert,
                          showAfter: !isDelete),
                  ],
                ),
              ),
            ),

            // Pied du modal
            Container(
              padding: const EdgeInsets.all(14),
              decoration:
                  const BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
              child: Row(
                children: [
                  if (onFilterSchool != null)
                    OutlinedButton.icon(
                      onPressed: onFilterSchool,
                      icon: const Icon(Icons.filter_alt_rounded, size: 15),
                      label: const Text('Filtrer cette école'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: const BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _noDataBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: const Text(
          'Aucune donnée détaillée enregistrée pour cet événement.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
      );

  static String _fullDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        'à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static String _simplifyUserAgent(String ua) {
    if (ua.contains('Flutter')) return 'App Flutter (Mobile/Desktop)';
    if (ua.contains('Chrome')) return 'Navigateur Chrome';
    if (ua.contains('Firefox')) return 'Navigateur Firefox';
    if (ua.contains('Safari') && !ua.contains('Chrome')) return 'Safari';
    if (ua.length > 60) return '${ua.substring(0, 60)}…';
    return ua;
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});
  final AuditSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      AuditSeverity.high => (kRed, 'RISQUE ÉLEVÉ'),
      AuditSeverity.medium => (kAccent, 'RISQUE MOYEN'),
      AuditSeverity.low => (kGreen, 'RISQUE FAIBLE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE DIFF (inchangée)
// ─────────────────────────────────────────────────────────────────────────────
class _DiffTable extends StatelessWidget {
  const _DiffTable(
      {required this.diff, required this.showBefore, required this.showAfter});
  final List<AuditFieldDiff> diff;
  final bool showBefore;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final sorted = [...diff]..sort((a, b) {
        int rank(AuditDiffKind k) => switch (k) {
              AuditDiffKind.changed => 0,
              AuditDiffKind.added => 1,
              AuditDiffKind.removed => 1,
              AuditDiffKind.unchanged => 2,
            };
        final r = rank(a.kind).compareTo(rank(b.kind));
        return r != 0 ? r : a.field.compareTo(b.field);
      });

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            _DiffRow(
                d: sorted[i], showBefore: showBefore, showAfter: showAfter),
            if (i != sorted.length - 1) const Divider(height: 1, color: kBorder),
          ],
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow(
      {required this.d, required this.showBefore, required this.showAfter});
  final AuditFieldDiff d;
  final bool showBefore;
  final bool showAfter;

  @override
  Widget build(BuildContext context) {
    final highlight = d.kind == AuditDiffKind.changed;
    final rowBg = highlight ? kAccent.withValues(alpha: 0.06) : null;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (highlight)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 6,
                height: 6,
                decoration:
                    const BoxDecoration(color: kAccent, shape: BoxShape.circle),
              ),
            Expanded(
              child: Text(
                _fieldLabel(d.field),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary),
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBefore) ...[
                Expanded(
                  child: _ValueChip(
                    label: 'Avant',
                    value: d.hasOld ? _fmt(d.before) : null,
                    kind: highlight || d.kind == AuditDiffKind.removed
                        ? _ChipKind.before
                        : _ChipKind.neutral,
                  ),
                ),
                if (showAfter)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 14, color: kTextMuted),
                  ),
              ],
              if (showAfter)
                Expanded(
                  child: _ValueChip(
                    label: showBefore ? 'Après' : 'Valeur',
                    value: d.hasNew ? _fmt(d.after) : null,
                    kind: highlight || d.kind == AuditDiffKind.added
                        ? _ChipKind.after
                        : _ChipKind.neutral,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fieldLabel(String f) => f
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _fmt(dynamic v) {
    if (v == null) return '∅';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is Map || v is List) return v.toString();
    final s = v.toString();
    return s.isEmpty ? '∅' : s;
  }
}

enum _ChipKind { before, after, neutral }

class _ValueChip extends StatelessWidget {
  const _ValueChip(
      {required this.label, required this.value, required this.kind});
  final String label;
  final String? value;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, border, txt) = switch (kind) {
      _ChipKind.before => (
          kRed.withValues(alpha: 0.06),
          kRed.withValues(alpha: 0.25),
          kRed
        ),
      _ChipKind.after => (
          kGreen.withValues(alpha: 0.07),
          kGreen.withValues(alpha: 0.28),
          kGreen
        ),
      _ChipKind.neutral => (kSurface, kBorder, kTextPrimary),
    };
    final isMissing = value == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMissing ? kSurface : bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMissing ? kBorder : border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: kTextMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            value ?? '—',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isMissing ? kTextMuted : txt,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SÉLECTEUR DE PÉRIODE — version professionnelle
// ─────────────────────────────────────────────────────────────────────────────
class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.dateFrom,
    required this.dateTo,
    required this.onPick,
    required this.onClear,
  });
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasRange = dateFrom != null && dateTo != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasRange ? kNavy.withValues(alpha: 0.05) : kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasRange ? kNavy : kBorder,
            width: hasRange ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 15, color: hasRange ? kNavy : kTextMuted),
            const SizedBox(width: 8),
            if (!hasRange)
              const Text('Période personnalisée',
                  style: TextStyle(fontSize: 13, color: kTextMuted))
            else ...[
              _DateChip(label: 'DU', date: dateFrom!),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 13, color: kNavy.withValues(alpha: 0.45)),
              ),
              _DateChip(label: 'AU', date: dateTo!),
              const SizedBox(width: 10),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: kNavy.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.date});
  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: kNavy.withValues(alpha: 0.55),
                letterSpacing: 0.6)),
        Text(
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}',
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: kNavy),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON EXPORT
// ─────────────────────────────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed, required this.totalCount});
  final VoidCallback onPressed;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file_rounded, size: 15, color: kNavy),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exporter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kNavy)),
                if (totalCount > 0)
                  Text('$totalCount événements',
                      style: const TextStyle(
                          fontSize: 10, color: kTextMuted)),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG D'EXPORT PROFESSIONNEL
// ─────────────────────────────────────────────────────────────────────────────
enum _ExportScope { currentPage, allFiltered }

class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog({
    required this.filters,
    required this.currentPageEntries,
    required this.totalCount,
    required this.groupId,
  });
  final AuditFilters filters;
  final List<AuditEntry> currentPageEntries;
  final int totalCount;
  final String groupId;

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  _ExportScope _scope = _ExportScope.allFiltered;
  bool _loading = false;
  bool _done = false;
  String? _filePath;
  int _exportedCount = 0;
  String? _errorMsg;

  // Colonnes
  final _cols = {
    'Date': true,
    'Action': true,
    'Entité': true,
    'Table DB': false,
    'Auteur': true,
    'Rôle': true,
    'École': true,
    'ID Enregistrement': false,
    'Adresse IP': true,
    'User Agent': false,
  };

  Future<void> _doExport() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    List<AuditEntry> entries;
    if (_scope == _ExportScope.currentPage) {
      entries = widget.currentPageEntries;
    } else {
      try {
        final client = ref.read(supabaseClientProvider);
        entries = await fetchAllAuditForExport(
          client: client,
          groupId: widget.groupId,
          filters: widget.filters,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMsg = 'Erreur de récupération : $e';
          });
        }
        return;
      }
    }

    // Construction du CSV
    final activeCols = _cols.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final buf = StringBuffer();
    buf.writeln(activeCols.map((c) => '"$c"').join(','));

    for (final e in entries) {
      final row = activeCols.map((col) {
        return switch (col) {
          'Date' => _fmtDate(e.createdAt),
          'Action' => e.actionLabel,
          'Entité' => e.entityLabel,
          'Table DB' => e.tableName,
          'Auteur' => e.userName,
          'Rôle' => e.roleLbl,
          'École' => e.schoolName ?? '',
          'ID Enregistrement' => e.recordId ?? '',
          'Adresse IP' => e.ipAddress ?? '',
          'User Agent' => e.userAgent ?? '',
          _ => '',
        };
      }).map((v) => '"${v.replaceAll('"', '""')}"').join(',');
      buf.writeln(row);
    }

    // Écriture
    try {
      final now = DateTime.now();
      final ts = '${now.year}${_p(now.month)}${_p(now.day)}_'
          '${_p(now.hour)}${_p(now.minute)}${_p(now.second)}';
      final path = '/tmp/audit_export_$ts.csv';
      await File(path).writeAsString(buf.toString());
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
          _filePath = path;
          _exportedCount = entries.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Erreur écriture fichier : $e';
        });
      }
    }
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${_p(dt.day)}/${_p(dt.month)}/${dt.year} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  // Conteneur dialog style SchoolFormDialog
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: _done ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final pageCount = widget.currentPageEntries.length;
    final allCount = widget.totalCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── En-tête style SchoolFormDialog ──────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A2F5A), kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 19),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exporter le journal d\'audit',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  SizedBox(height: 2),
                  Text('Format CSV · encodage UTF-8',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: kTextMuted),
                ),
              ),
            ),
          ]),
        ),

        // ── Corps ────────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Périmètre
                const Text('Périmètre d\'export',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 10),
                _ScopeCard(
                  selected: _scope == _ExportScope.allFiltered,
                  icon: Icons.filter_alt_rounded,
                  title: 'Tous les résultats filtrés',
                  subtitle:
                      '$allCount événements correspondant aux filtres actifs',
                  badge:
                      allCount > 1000 ? 'Peut prendre quelques secondes' : null,
                  badgeColor: kAccent,
                  onTap: () =>
                      setState(() => _scope = _ExportScope.allFiltered),
                ),
                const SizedBox(height: 8),
                _ScopeCard(
                  selected: _scope == _ExportScope.currentPage,
                  icon: Icons.list_alt_rounded,
                  title: 'Page courante uniquement',
                  subtitle: '$pageCount événements affichés à l\'écran',
                  onTap: () =>
                      setState(() => _scope = _ExportScope.currentPage),
                ),
                const SizedBox(height: 18),

                // Colonnes
                const Text('Colonnes à inclure',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cols.keys.map((col) {
                    final active = _cols[col]!;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _cols[col] = !active),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? kNavy.withValues(alpha: 0.08)
                                : kSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active ? kNavy : kBorder,
                              width: active ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 14,
                                color: active ? kNavy : kTextMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(col,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active ? kNavy : kTextMuted)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  AdminErrorBanner(message: _errorMsg!),
                ],
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),

        // ── Pied ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      _loading || _cols.values.every((v) => !v)
                          ? null
                          : _doExport,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 16),
                  label:
                      Text(_loading ? 'Génération en cours…' : 'Exporter en CSV'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: kGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Export réussi',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text('$_exportedCount événement(s) exporté(s)',
                      style: const TextStyle(
                          fontSize: 11.5, color: kTextMuted)),
                ],
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              // Chemin du fichier
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.insert_drive_file_rounded,
                          size: 14, color: kTextMuted),
                      SizedBox(width: 6),
                      Text('Fichier généré',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTextMuted,
                              letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 8),
                    SelectableText(
                      _filePath ?? '',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          color: kTextPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _filePath ?? ''));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Chemin copié dans le presse-papier'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copier le chemin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: const BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: kNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? kNavy.withValues(alpha: 0.05) : kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? kNavy : kBorder,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (selected ? kNavy : kTextMuted).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 18, color: selected ? kNavy : kTextMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? kNavy : kTextPrimary)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? kAccent)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? kAccent)),
                        ),
                      ],
                    ]),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? kNavy : Colors.transparent,
                  border: Border.all(
                    color: selected ? kNavy : kBorder,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 11, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALENDRIER DE PÉRIODE COMPACT (remplace showDateRangePicker plein écran)
// ─────────────────────────────────────────────────────────────────────────────
class _DateRangePickerDialog extends StatefulWidget {
  const _DateRangePickerDialog({this.initialFrom, this.initialTo});
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_DateRangePickerDialog> createState() =>
      _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime? _from;
  late DateTime? _to;

  static final _first = DateTime(DateTime.now().year - 5);

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  void _applyQuick(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _from = today.subtract(Duration(days: days - 1));
      _to = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canApply = _from != null && _to != null;
    final conflict = canApply && _from!.isAfter(_to!);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 740),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2F5A), kNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: kNavy.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(Icons.date_range_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sélectionner une période',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      SizedBox(height: 2),
                      Text(
                          'Cliquez sur une date de début, puis une date de fin',
                          style:
                              TextStyle(fontSize: 11.5, color: kTextMuted)),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: kTextMuted),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Raccourcis ─────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: const BoxDecoration(
                color: kSurface,
                border: Border(
                    top: BorderSide(color: kBorder),
                    bottom: BorderSide(color: kBorder)),
              ),
              child: Row(children: [
                const Text('Raccourcis :',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ...[
                  (1, "Aujourd'hui"),
                  (7, '7 jours'),
                  (30, '30 jours'),
                  (90, '3 mois'),
                  (365, '1 an'),
                ].map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _applyQuick(p.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kBorder),
                          ),
                          child: Text(p.$2,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kNavy)),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Deux calendriers côte à côte ────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CalendarPanel(
                      label: 'Date de début',
                      labelColor: kGreen,
                      selected: _from,
                      firstDate: _first,
                      lastDate: _to ?? today,
                      onChanged: (d) => setState(() => _from = d),
                    ),
                  ),
                  Container(width: 1, color: kBorder),
                  Expanded(
                    child: _CalendarPanel(
                      label: 'Date de fin',
                      labelColor: kRed,
                      selected: _to,
                      firstDate: _from ?? _first,
                      lastDate: today,
                      onChanged: (d) => setState(() => _to = d),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(children: [
                // Aperçu
                Expanded(
                  child: canApply
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: conflict
                                ? kRed.withValues(alpha: 0.07)
                                : kNavy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: conflict
                                  ? kRed.withValues(alpha: 0.3)
                                  : kNavy.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              conflict
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 14,
                              color: conflict ? kRed : kGreen,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                conflict
                                    ? 'La fin doit être après le début'
                                    : '${_fmt(_from!)}  →  ${_fmt(_to!)}'
                                        '  ·  ${_to!.difference(_from!).inDays + 1} j',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: conflict ? kRed : kNavy,
                                ),
                              ),
                            ),
                          ]),
                        )
                      : const Text('Sélectionnez les deux dates',
                          style:
                              TextStyle(fontSize: 12, color: kTextMuted)),
                ),
                const SizedBox(width: 12),
                if (_from != null || _to != null)
                  TextButton(
                    onPressed: () =>
                        setState(() { _from = null; _to = null; }),
                    child: const Text('Effacer',
                        style: TextStyle(color: kTextMuted)),
                  ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(color: kTextMuted)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canApply && !conflict
                      ? () => Navigator.of(context)
                          .pop(DateTimeRange(start: _from!, end: _to!))
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Appliquer'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.label,
    required this.labelColor,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });
  final String label;
  final Color labelColor;
  final DateTime? selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final safeLast =
        lastDate.isBefore(firstDate) ? firstDate : lastDate;
    final safeInit = selected != null &&
            !selected!.isBefore(firstDate) &&
            !selected!.isAfter(safeLast)
        ? selected!
        : (today.isBefore(firstDate)
            ? firstDate
            : (today.isAfter(safeLast) ? safeLast : today));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: labelColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: labelColor)),
            if (selected != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_p(selected!.day)}/${_p(selected!.month)}/${selected!.year}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor),
                ),
              ),
            ],
          ]),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
                primary: labelColor, onPrimary: Colors.white),
          ),
          child: CalendarDatePicker(
            key: ValueKey('${firstDate}_$safeLast'),
            initialDate: safeInit,
            firstDate: firstDate,
            lastDate: safeLast,
            onDateChanged: onChanged,
          ),
        ),
      ],
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
InputDecoration adminInputDecoration(String label,
    {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 18, color: kTextMuted) : null,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kNavy, width: 1.5)),
    filled: true,
    fillColor: kCardBg,
    labelStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
    hintStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
  );
}
