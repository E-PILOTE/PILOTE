import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/audit_provider.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kBlue    = Color(0xFF0EA5E9);
const _kRed     = Color(0xFFEF4444);
Color get _kSurface => kSurface;
Color get _kBg => kCardBg;
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

// ─── Helpers action ───────────────────────────────────────────────────────────
Color _actionColor(String a) => switch (a) {
  'INSERT' => _kGreen,
  'UPDATE' => _kBlue,
  'DELETE' => _kRed,
  _        => _kMuted,
};

IconData _actionIcon(String a) => switch (a) {
  'INSERT' => Icons.add_circle_rounded,
  'UPDATE' => Icons.edit_rounded,
  'DELETE' => Icons.delete_rounded,
  _        => Icons.help_rounded,
};

Color _roleColor(String? r) => switch (r) {
  'super_admin'   => _kNavy,
  'admin_groupe'  => _kPurple,
  'directeur'     => _kBlue,
  'enseignant'    => _kGreen,
  _               => _kMuted,
};

// ─── Écran principal ──────────────────────────────────────────────────────────

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: "Journal d'Audit",
      child: _AuditBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _AuditBody extends ConsumerStatefulWidget {
  const _AuditBody();
  @override
  ConsumerState<_AuditBody> createState() => _AuditBodyState();
}

class _AuditBodyState extends ConsumerState<_AuditBody> {
  final _searchCtrl    = TextEditingController();
  String _filterAction = 'tous';
  String _filterRole   = 'tous';
  String _filterTable  = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AuditLog> _applyFilters(List<AuditLog> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((l) {
      if (q.isNotEmpty) {
        final match = l.tableName.toLowerCase().contains(q)
            || l.action.toLowerCase().contains(q)
            || (l.userEmail?.toLowerCase().contains(q) ?? false)
            || (l.userRole?.toLowerCase().contains(q) ?? false)
            || (l.recordId?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterAction != 'tous' && l.action != _filterAction) return false;
      if (_filterRole   != 'tous' && l.userRole != _filterRole) return false;
      if (_filterTable  != 'tous' && l.tableName != _filterTable) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'    => a.tableName.compareTo(b.tableName),
      'action'=> a.action.compareTo(b.action),
      _       => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openDetail(AuditLog l) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _AuditDetailModal(log: l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogsProvider);
    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text('Erreur : $e', style: TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(auditLogsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(AuditData data) {
    final filtered = _applyFilters(data.logs);
    final tables   = data.logs.map((l) => l.tableName).toSet().toList()..sort();

    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _KpiGrid(data: data),
              const SizedBox(height: 20),
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterAction:   _filterAction,
                filterRole:     _filterRole,
                filterTable:    _filterTable,
                tables:         tables,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onAction:       (v) => setState(() => _filterAction = v),
                onRole:         (v) => setState(() => _filterRole   = v),
                onTable:        (v) => setState(() => _filterTable  = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onRefresh:      ()  => ref.invalidate(auditLogsProvider),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterAction = _filterRole = _filterTable = 'tous';
                  _sort = 'recent';
                }),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                _TableView(logs: filtered, onView: _openDetail)
              else
                _CardGrid(logs: filtered, onView: _openDetail),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid — 6 cartes 3×2 ─────────────────────────────────────────────────

class _KD {
  const _KD({
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true,
    this.progressValue,
  });
  final String  label, value;
  final String? sub, trend;
  final bool    trendUp;
  final double? progressValue;
  final IconData icon;
  final Color   color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AuditData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Événements', value: '$n',
        sub:   '${data.todayCount} aujourd\'hui',
        icon:  Icons.history_rounded, color: _kNavy,
        progressValue: 1,
        trend: n > 0 ? '📋 $n enregistrés' : '—',
      ),
      _KD(
        label: 'Aujourd\'hui', value: '${data.todayCount}',
        sub:   'Activité du jour',
        icon:  Icons.today_rounded, color: _kBlue,
        progressValue: n > 0 ? data.todayCount / n : 0,
        trend: data.todayCount > 0 ? 'Actif' : 'Calme',
        trendUp: data.todayCount > 0,
      ),
      _KD(
        label: 'Créations', value: '${data.inserts}',
        sub:   'Insertions en base',
        icon:  Icons.add_circle_rounded, color: _kGreen,
        progressValue: n > 0 ? data.inserts / n : 0,
        trend: n > 0 ? '${(data.inserts * 100 / n).round()}%' : '—',
      ),
      _KD(
        label: 'Modifications', value: '${data.updates}',
        sub:   'Mises à jour',
        icon:  Icons.edit_rounded, color: _kGold,
        progressValue: n > 0 ? data.updates / n : 0,
        trend: n > 0 ? '${(data.updates * 100 / n).round()}%' : '—',
      ),
      _KD(
        label: 'Suppressions', value: '${data.deletes}',
        sub:   'Enregistrements supprimés',
        icon:  Icons.delete_rounded, color: _kRed,
        progressValue: n > 0 ? data.deletes / n : 0,
        trend: data.deletes > 0 ? '⚠️ À surveiller' : 'Aucune',
        trendUp: data.deletes == 0,
      ),
      _KD(
        label: 'Tables impactées', value: '${data.distinctTables}',
        sub:   'Tables distinctes',
        icon:  Icons.table_chart_rounded, color: _kPurple,
        progressValue: data.distinctTables > 0 ? 1 : 0,
        trend: data.distinctTables > 0 ? '${data.distinctTables} tables' : '—',
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 60 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }

  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _kBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200), height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(color: d.color, fontSize: 22,
                            fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(d.label, style: TextStyle(color: _kMuted, fontSize: 11.5,
                            fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(color: d.color.withValues(alpha: 0.70),
                              fontSize: 10), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _kSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorder)),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    if (d.progressValue != null)
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                                d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        )),
                        if (d.trend != null) ...[
                          const SizedBox(width: 8),
                          Text(d.trend!, style: TextStyle(
                            color: d.trendUp ? d.color : _kOrange,
                            fontSize: 10, fontWeight: FontWeight.w600,
                          )),
                        ],
                      ]),
                  ]),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Skeleton ─────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();
  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(r)),
  );
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8ECF0),
    highlightColor: const Color(0xFFF5F7FA),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
        ),
        const SizedBox(height: 20),
        _box(double.infinity, 100, r: 14),
        const SizedBox(height: 16),
        _box(180, 18, r: 8),
        const SizedBox(height: 16),
        _box(double.infinity, 48, r: 6),
        const SizedBox(height: 1),
        ...List.generate(8, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 52, r: 0),
        ])),
      ]),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterAction,
    required this.filterRole,
    required this.filterTable,
    required this.tables,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onAction,
    required this.onRole,
    required this.onTable,
    required this.onSort,
    required this.onToggleView,
    required this.onRefresh,
    required this.onReset,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterAction, filterRole, filterTable, sort;
  final List<String> tables;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onAction, onRole, onTable, onSort;
  final VoidCallback onToggleView, onRefresh, onReset;

  @override
  Widget build(BuildContext context) {
    final tableItems = <String, String>{'tous': 'Toutes les tables'};
    for (final t in tables) {
      tableItems[t] = AuditLog(
        id: '', userId: '', action: '', tableName: t,
        createdAt: DateTime.now(),
      ).tableLabel;
    }

    return SizedBox(
      width: contentWidth,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par table, action, utilisateur…',
                  hintStyle: TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: _kMuted),
                          onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                      : null,
                  filled: true, fillColor: _kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Rafraîchir le journal',
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _kSurface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 20, color: _kNavy),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FilterDropdown(
              icon: Icons.flash_on_rounded, label: 'Action',
              items: const {
                'tous':   'Toutes les actions',
                'INSERT': 'Créations',
                'UPDATE': 'Modifications',
                'DELETE': 'Suppressions',
              },
              value: filterAction, onChanged: onAction, active: filterAction != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.badge_rounded, label: 'Rôle',
              items: const {
                'tous':          'Tous les rôles',
                'super_admin':   'Super Admin',
                'admin_groupe':  'Admin Groupe',
                'directeur':     'Directeur',
                'enseignant':    'Enseignant',
                'comptable':     'Comptable',
              },
              value: filterRole, onChanged: onRole, active: filterRole != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.table_chart_rounded, label: 'Table',
              items: tableItems,
              value: tableItems.containsKey(filterTable) ? filterTable : 'tous',
              onChanged: onTable, active: filterTable != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded, label: 'Trier',
              items: const {
                'recent': 'Plus récents',
                'az':     'Table A → Z',
                'action': 'Par action',
              },
              value: sort, onChanged: onSort, active: sort != 'recent',
            ),
            const Spacer(),
            if (filterAction != 'tous' || filterRole != 'tous' || filterTable != 'tous' || sort != 'recent')
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 13, color: _kRed),
                      SizedBox(width: 4),
                      Text('Réinitialiser', style: TextStyle(
                          color: _kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon, required this.label, required this.items,
    required this.value, required this.onChanged, required this.active,
  });
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? _kNavy : _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? _kNavy : _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: kCardBg,
        icon: Icon(Icons.arrow_drop_down, size: 18, color: active ? Colors.white : _kMuted),
        style: TextStyle(color: active ? Colors.white : _kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w600),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class _ToggleViewBtn extends StatelessWidget {
  const _ToggleViewBtn({required this.isTable, required this.onToggle});
  final bool isTable;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Tooltip(
      message: isTable ? 'Vue en cartes' : 'Vue en tableau',
      child: InkWell(
        onTap: onToggle, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: _kNavy,
          ),
        ),
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered événement${filtered > 1 ? "s" : ""}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({required this.logs, required this.onView});
  final List<AuditLog> logs;
  final ValueChanged<AuditLog> onView;

  static const _actionW  = 96.0;
  static const _timeW    = 140.0;
  static const _actionsW = 52.0;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: TextStyle(color: _kMuted, fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.4), overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const _EmptyState();
    return Container(
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SizedBox(width: _actionW,
                child: Text('Action', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Table', 2),
              _hdr('Utilisateur', 2),
              _hdr('Rôle', 2),
              _hdr('ID enregistrement', 3),
              SizedBox(width: _timeW,
                child: Text('Date & Heure', style: TextStyle(color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              SizedBox(width: _actionsW,
                child: Center(child: Text('', style: TextStyle(color: _kMuted, fontSize: 11)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...logs.asMap().entries.map((e) => _TableRow(
            log: e.value, isOdd: e.key.isOdd,
            actionW: _actionW, timeW: _timeW, actionsW: _actionsW,
            onView: () => onView(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.log, required this.isOdd, required this.actionW,
    required this.timeW, required this.actionsW, required this.onView,
  });
  final AuditLog log;
  final bool isOdd;
  final double actionW, timeW, actionsW;
  final VoidCallback onView;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? _kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
          border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(
            width: widget.actionW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_actionIcon(l.action), size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(l.actionLabel, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.tableLabel, style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w700, color: _kText), overflow: TextOverflow.ellipsis),
                Text(l.tableName, style: TextStyle(fontSize: 10, color: _kMuted,
                    fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
              ]),
            ),
          )),
          Expanded(flex: 2, child: Text(l.userEmail ?? '—',
              style: TextStyle(fontSize: 12, color: _kText), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _RoleBadge(role: l.userRole)),
          Expanded(flex: 3, child: Text(l.recordId ?? '—',
              style: TextStyle(fontSize: 10.5, color: _kMuted, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: widget.timeW,
            child: Text(timeStr, style: TextStyle(fontSize: 11.5, color: _kMuted,
                fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Center(child: _ActionBtn(
              icon: Icons.visibility_rounded, color: _kBlue,
              tooltip: 'Voir le détail', onTap: widget.onView,
            )),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.logs, required this.onView});
  final List<AuditLog> logs;
  final ValueChanged<AuditLog> onView;
  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.7,
      ),
      itemCount: logs.length,
      itemBuilder: (_, i) => _LogCard(log: logs[i], onView: () => onView(logs[i])),
    );
  }
}

class _LogCard extends StatefulWidget {
  const _LogCard({required this.log, required this.onView});
  final AuditLog log;
  final VoidCallback onView;
  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? color.withValues(alpha: 0.4) : _kBorder),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_actionIcon(l.action), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.tableLabel, style: TextStyle(color: _kText, fontSize: 13,
                    fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                Text(l.actionLabel, style: TextStyle(color: color, fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _RoleBadge(role: l.userRole),
            ]),
            const Spacer(),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 12, color: _kMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(l.userEmail ?? '—',
                  style: TextStyle(fontSize: 11, color: _kMuted), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 12, color: _kMuted),
              const SizedBox(width: 4),
              Text(timeStr, style: TextStyle(fontSize: 11, color: _kMuted,
                  fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Badges & helpers ─────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String? role;
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    final log = AuditLog(id:'',userId:'',action:'',tableName:'',createdAt:DateTime.now(),userRole:role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(log.userRoleLabel, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64), alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.history_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun événement trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres pour afficher les logs.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Helpers dates & sections ─────────────────────────────────────────────────

const _moisFr = [
  'janvier','février','mars','avril','mai','juin',
  'juillet','août','septembre','octobre','novembre','décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year} à '
      '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
}

class _SubSectionTitle extends StatelessWidget {
  const _SubSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(this.rows);
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11 : 13, fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(message: 'Copier', child: InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copié : $value'), backgroundColor: _kNavy,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy)),
          )),
        ),
      ],
    ]),
  );
}

class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({required this.icon, required this.color,
      required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _kSurface,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

// ─── Modal détail du log ──────────────────────────────────────────────────────

class _AuditDetailModal extends StatefulWidget {
  const _AuditDetailModal({required this.log});
  final AuditLog log;
  @override
  State<_AuditDetailModal> createState() => _AuditDetailModalState();
}

class _AuditDetailModalState extends State<_AuditDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = widget.log;
    final color = _actionColor(l.action);
    final dt = l.createdAt.toLocal();
    final timeStr = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(_actionIcon(l.action), color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l.actionLabel} · ${l.tableLabel}', style: TextStyle(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  _ActionBadge(action: l.action),
                  _RoleBadge(role: l.userRole),
                ]),
                const SizedBox(height: 4),
                Text(timeStr, style: TextStyle(color: _kMuted, fontSize: 11.5)),
              ])),
              _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
          // Tabs
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: 'Détail'), Tab(text: 'Valeurs JSON')],
            ),
          ),
          Expanded(child: TabBarView(controller: _tabs, children: [
            _AuditDetailTab(log: l),
            _AuditJsonTab(log: l),
          ])),
          // Footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Fermer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});
  final String action;
  @override
  Widget build(BuildContext context) {
    final color = _actionColor(action);
    final log = AuditLog(id:'',userId:'',action:action,tableName:'',createdAt:DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_actionIcon(action), size: 11, color: color),
        const SizedBox(width: 4),
        Text(log.actionLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── Onglet Détail ────────────────────────────────────────────────────────────

class _AuditDetailTab extends StatelessWidget {
  const _AuditDetailTab({required this.log});
  final AuditLog log;
  @override
  Widget build(BuildContext context) {
    final l = log;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SubSectionTitle('Événement'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.flash_on_rounded, 'Action', l.actionLabel),
          _DetailRow(Icons.table_chart_rounded, 'Table', '${l.tableLabel} (${l.tableName})'),
          _DetailRow(Icons.calendar_today_rounded, 'Horodatage', _fmtDate(l.createdAt), last: true),
        ]),
        const SizedBox(height: 14),
        const _SubSectionTitle('Utilisateur'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.tag_rounded, 'User ID', l.userId, copyable: true, mono: true),
          _DetailRow(Icons.email_outlined, 'E-mail', l.userEmail ?? '—'),
          _DetailRow(Icons.badge_rounded, 'Rôle', l.userRoleLabel,
              last: l.ipAddress == null && l.recordId == null),
          if (l.ipAddress != null)
            _DetailRow(Icons.router_rounded, 'Adresse IP', l.ipAddress!,
                last: l.recordId == null),
          if (l.recordId != null)
            _DetailRow(Icons.fingerprint_rounded, 'ID enregistrement',
                l.recordId!, copyable: true, mono: true, last: true),
        ]),
        if (l.userAgent != null) ...[
          const SizedBox(height: 14),
          const _SubSectionTitle('Contexte technique'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder)),
            child: Text(l.userAgent!, style: TextStyle(
                fontSize: 11, color: _kMuted, fontFamily: 'monospace', height: 1.5)),
          ),
        ],
      ]),
    );
  }
}

// ─── Onglet Valeurs JSON ──────────────────────────────────────────────────────

class _AuditJsonTab extends StatelessWidget {
  const _AuditJsonTab({required this.log});
  final AuditLog log;

  String _prettyJson(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return '(aucune donnée)';
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  @override
  Widget build(BuildContext context) {
    final l = log;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (l.oldValues != null) ...[
          Row(children: [
            const _SubSectionTitle('Anciennes valeurs'),
            const Spacer(),
            _CopyBtn(text: _prettyJson(l.oldValues)),
          ]),
          const SizedBox(height: 8),
          _JsonBox(content: _prettyJson(l.oldValues), color: _kRed),
          const SizedBox(height: 16),
        ],
        if (l.newValues != null) ...[
          Row(children: [
            const _SubSectionTitle('Nouvelles valeurs'),
            const Spacer(),
            _CopyBtn(text: _prettyJson(l.newValues)),
          ]),
          const SizedBox(height: 8),
          _JsonBox(content: _prettyJson(l.newValues), color: _kGreen),
        ],
        if (l.oldValues == null && l.newValues == null)
          Container(
            padding: const EdgeInsets.all(24), alignment: Alignment.center,
            child: Text('Aucune donnée JSON disponible pour cet événement.',
                style: TextStyle(color: _kMuted, fontSize: 13)),
          ),
      ]),
    );
  }
}

class _JsonBox extends StatelessWidget {
  const _JsonBox({required this.content, required this.color});
  final String content;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: SelectableText(content, style: TextStyle(
        fontSize: 11.5, color: _kText, fontFamily: 'monospace',
        height: 1.6)),
  );
}

class _CopyBtn extends StatelessWidget {
  const _CopyBtn({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Tooltip(
      message: 'Copier JSON',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('JSON copié'), backgroundColor: _kNavy,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _kSurface, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.copy_rounded, size: 12, color: _kNavy),
            const SizedBox(width: 4),
            Text('Copier', style: TextStyle(fontSize: 11, color: _kNavy, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ),
  );
}
