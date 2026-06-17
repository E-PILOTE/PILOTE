import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_schools_provider.dart';
import '../providers/admin_users_provider.dart' show roleLabel;
import '../providers/education_provider.dart';
import '../../../core/widgets/admin_ui.dart';

// ─── Couleurs locales (complètent admin_ui.dart) ─────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF0EA5E9);
const _kOrange = Color(0xFFFF6B35);
const _kGold   = Color(0xFFFBBC04);

// 15 départements — réforme territoriale du 8 octobre 2024
const _kDepartements = [
  'Bouenza', 'Brazzaville', 'Congo-Oubangui', 'Cuvette', 'Cuvette-Ouest',
  'Djoué-Léfini', 'Kouilou', 'Lékoumou', 'Likouala', 'Niari',
  'Nkéni-Alima', 'Plateaux', 'Pointe-Noire', 'Pool', 'Sangha',
];

// ─── Avatar école (logo si présent, sinon icône) ─────────────────────────────
class _SchoolAvatar extends StatelessWidget {
  const _SchoolAvatar({
    required this.logoUrl,
    this.size = 46,
    this.radius = 11,
    this.iconColor = kNavy,
    this.iconSize,
  });
  final String? logoUrl;
  final double  size;
  final double  radius;
  final Color   iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    final icon = Icon(Icons.account_balance_rounded,
        color: iconColor, size: iconSize ?? size * 0.43);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Center(child: icon),
              errorWidget: (_, _, _) => Center(child: icon),
            )
          : Center(child: icon),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminSchoolsScreen extends ConsumerWidget {
  const AdminSchoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Mes Écoles',
      child: ref.watch(adminSchoolsProvider).when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _ShimmerSkeleton(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
            const SizedBox(height: 12),
            Text('Erreur : $e', style: const TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(adminSchoolsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _SchoolsBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _SchoolsBody extends ConsumerStatefulWidget {
  const _SchoolsBody({required this.data});
  final AdminSchoolsData data;

  @override
  ConsumerState<_SchoolsBody> createState() => _SchoolsBodyState();
}

class _SchoolsBodyState extends ConsumerState<_SchoolsBody> {
  final _searchCtrl  = TextEditingController();
  String _filterType   = 'tous';
  String _filterStatus = 'tous';
  String _filterDept   = 'tous';
  bool   _isTableView  = true;
  String _sortField    = 'name';
  bool   _sortAsc      = true;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SchoolDetail> _applyFilters(List<SchoolDetail> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((s) {
      if (q.isNotEmpty) {
        final ok = s.name.toLowerCase().contains(q)
            || (s.code?.toLowerCase().contains(q) ?? false)
            || (s.city?.toLowerCase().contains(q) ?? false)
            || (s.department?.toLowerCase().contains(q) ?? false);
        if (!ok) return false;
      }
      if (_filterType   != 'tous' && s.type != _filterType) return false;
      if (_filterStatus == 'active'   && !s.isActive) return false;
      if (_filterStatus == 'inactive' &&  s.isActive) return false;
      if (_filterDept   != 'tous' && (s.department ?? '') != _filterDept) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'students': c = a.students.compareTo(b.students); break;
          case 'staff':    c = a.staff.compareTo(b.staff);       break;
          case 'classes':  c = a.classes.compareTo(b.classes);   break;
          case 'dept':     c = (a.department ?? '').compareTo(b.department ?? ''); break;
          default:         c = a.name.compareTo(b.name);
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() {
    final d = widget.data;
    if (d.quotaReached) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: Text('Quota atteint : plan ${d.planName} limité à ${d.maxSchools} école(s).'),
      ));
      return;
    }
    showDialog(context: context, builder: (_) => const SchoolFormDialog());
  }

  void _openEdit(SchoolDetail s) =>
      showDialog(context: context, builder: (_) => SchoolFormDialog(school: s));

  void _openDetail(SchoolDetail s) => showDialog(
        context: context,
        builder: (_) => _SchoolDetailModal(
          school: s,
          onEdit: () { Navigator.of(context).pop(); _openEdit(s); },
          onToggle: () { Navigator.of(context).pop(); _toggleActive(s); },
        ),
      );

  Future<void> _toggleActive(SchoolDetail s) async {
    try {
      await ref.read(adminSchoolsServiceProvider).setActive(s.id, !s.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(s.isActive ? 'École désactivée' : 'École activée'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _bulkSetActive(List<SchoolDetail> selected, bool active) async {
    final ids = selected.where((s) => s.isActive != active).map((s) => s.id).toList();
    if (ids.isEmpty) {
      setState(_selectedIds.clear);
      return;
    }
    try {
      await ref.read(adminSchoolsServiceProvider).setActiveBulk(ids, active);
      if (mounted) {
        setState(_selectedIds.clear);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(
              '${ids.length} école(s) ${active ? 'activée(s)' : 'désactivée(s)'}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data        = widget.data;
    final filtered    = _applyFilters(data.schools);
    final selected    = filtered.where((s) => _selectedIds.contains(s.id)).toList();
    final allSelected = filtered.isNotEmpty && selected.length == filtered.length;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminSchoolsProvider.future),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(ctx).size.width - 80;

        return SingleChildScrollView(
          child: SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── KPIs ─────────────────────────────────────────────────────
                _KpiGrid(data: data),
                const SizedBox(height: 20),
                // ── Filtres ──────────────────────────────────────────────────
                _FilterBar(
                  contentWidth:   w - 48,
                  searchCtrl:     _searchCtrl,
                  filterType:     _filterType,
                  filterStatus:   _filterStatus,
                  filterDept:     _filterDept,
                  isTableView:    _isTableView,
                  quotaReached:   data.quotaReached,
                  onSearchChange: (_) => setState(() {}),
                  onType:         (v) => setState(() => _filterType   = v),
                  onStatus:       (v) => setState(() => _filterStatus = v),
                  onDept:         (v) => setState(() => _filterDept   = v),
                  onToggleView:   ()  => setState(() {
                    _isTableView = !_isTableView;
                    _selectedIds.clear();
                  }),
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _filterType = _filterStatus = _filterDept = 'tous';
                  }),
                  onAdd: _openCreate,
                ),
                const SizedBox(height: 16),
                // ── Résultat ─────────────────────────────────────────────────
                _ResultHeader(total: data.schools.length, filtered: filtered.length),
                const SizedBox(height: 12),
                // ── Vue principale ───────────────────────────────────────────
                if (data.schools.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.school_rounded,
                      title: 'Aucune école',
                      message: 'Ajoutez votre première école pour commencer à gérer les élèves, le personnel et les classes.',
                      actionLabel: 'Ajouter une école',
                      onAction: _openCreate,
                    ),
                  )
                else if (_isTableView)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (selected.isNotEmpty) ...[
                      _BulkActionBar(
                        count: selected.length,
                        activeCount: selected.where((s) => s.isActive).length,
                        onActivate: () => _bulkSetActive(selected, true),
                        onDeactivate: () => _bulkSetActive(selected, false),
                        onClear: () => setState(_selectedIds.clear),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _TableView(
                      schools:     filtered,
                      sortField:   _sortField,
                      sortAsc:     _sortAsc,
                      selectedIds: _selectedIds,
                      allSelected: allSelected,
                      onToggleAll: () => setState(() {
                        if (allSelected) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(filtered.map((s) => s.id));
                        }
                      }),
                      onToggleSelect: (id) => setState(() {
                        if (!_selectedIds.remove(id)) _selectedIds.add(id);
                      }),
                      onSort: (f) => setState(() {
                        if (_sortField == f) { _sortAsc = !_sortAsc; }
                        else { _sortField = f; _sortAsc = true; }
                      }),
                      onView:   _openDetail,
                      onEdit:   _openEdit,
                      onToggle: _toggleActive,
                    ),
                  ])
                else
                  _CardGrid(
                    schools:  filtered,
                    onView:   _openDetail,
                    onEdit:   _openEdit,
                    onToggle: _toggleActive,
                  ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────

class _KD {
  const _KD({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.progressValue,
  });
  final String label, value;
  final String? sub, trend;
  final bool trendUp;
  final double? progressValue;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AdminSchoolsData data;

  @override
  Widget build(BuildContext context) {
    final n        = data.schools.length;
    final actives  = data.schools.where((s) => s.isActive).length;
    final inactive = n - actives;
    final publics  = data.schools.where((s) => s.type == 'public').length;
    final privees  = data.schools.where((s) => s.type == 'prive').length;
    final maxS     = data.maxSchools;
    final maxStu   = data.maxStudents;

    final items = [
      _KD(
        label: 'Total Écoles',
        value: '$n',
        sub: maxS > 0 ? '$actives actives · quota $maxS' : '$actives actives',
        icon: Icons.school_rounded, color: kNavy,
        progressValue: maxS > 0 ? n / maxS : (n > 0 ? 1.0 : 0.0),
        trend: maxS > 0 ? '$n/$maxS utilisés' : 'Illimité',
      ),
      _KD(
        label: 'Actives',
        value: '$actives',
        sub: n > 0 ? '${(actives * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: kGreen,
        progressValue: n > 0 ? actives / n : 0,
        trend: actives > 0 ? '✅ Opérationnelles' : '—',
      ),
      _KD(
        label: 'Inactives',
        value: '$inactive',
        sub: inactive > 0 ? '⚠ À réactiver ou archiver' : '✅ Aucune',
        icon: Icons.block_rounded, color: kRed,
        progressValue: n > 0 ? inactive / n : 0,
        trend: inactive > 0 ? '⚠ Action requise' : '✅ OK',
        trendUp: inactive == 0,
      ),
      _KD(
        label: 'Total Élèves',
        value: '${data.totalStudents}',
        sub: maxStu > 0 ? 'quota $maxStu élèves' : 'Élèves actifs inscrits',
        icon: Icons.groups_rounded, color: _kPurple,
        progressValue: maxStu > 0 ? data.totalStudents / maxStu : 0,
        trend: maxStu > 0 ? '${data.totalStudents}/$maxStu' : '${data.totalStudents} inscrits',
      ),
      _KD(
        label: 'Établ. Publics',
        value: '$publics',
        sub: n > 0 ? '${(publics * 100 / n).round()}% du groupe' : '—',
        icon: Icons.account_balance_rounded, color: _kBlue,
        progressValue: n > 0 ? publics / n : 0,
        trend: publics > 0 ? '$publics public${publics > 1 ? 's' : ''}' : 'Aucun',
      ),
      _KD(
        label: 'Établ. Privés',
        value: '$privees',
        sub: n > 0 ? '${(privees * 100 / n).round()}% du groupe' : '—',
        icon: Icons.business_rounded, color: _kGold,
        progressValue: n > 0 ? privees / n : 0,
        trend: privees > 0 ? '$privees privé${privees > 1 ? 's' : ''}' : 'Aucun',
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 14,
          mainAxisSpacing: 14, childAspectRatio: 2.6,
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
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.value, style: TextStyle(
                          color: d.color, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5,
                        )),
                        const SizedBox(height: 2),
                        Text(d.label, style: const TextStyle(
                          color: kTextMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)),
  );

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8ECF0),
    highlightColor: const Color(0xFFF5F7FA),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // KPI skeleton — grille 3×2
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14,
            mainAxisSpacing: 14, childAspectRatio: 2.6,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 16),
        ),
        const SizedBox(height: 20),
        // FilterBar skeleton
        _box(double.infinity, 120, r: 14),
        const SizedBox(height: 16),
        // Result header skeleton
        _box(180, 18, r: 8),
        const SizedBox(height: 16),
        // Table rows skeleton
        _box(double.infinity, 48, r: 6),
        const SizedBox(height: 1),
        ...List.generate(6, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 56, r: 0),
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
    required this.filterType,
    required this.filterStatus,
    required this.filterDept,
    required this.isTableView,
    required this.quotaReached,
    required this.onSearchChange,
    required this.onType,
    required this.onStatus,
    required this.onDept,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterType, filterStatus, filterDept;
  final bool   isTableView;
  final bool   quotaReached;
  final ValueChanged<String> onSearchChange, onType, onStatus, onDept;
  final VoidCallback onToggleView, onReset, onAdd;

  bool get _hasFilters =>
      filterType != 'tous' || filterStatus != 'tous' || filterDept != 'tous';

  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: 'Rechercher une école, code, ville, département…',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: kTextMuted),
                        onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                    : null,
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
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
              message: 'Réinitialiser les filtres',
              child: InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: kTextMuted),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: quotaReached ? 'Quota atteint pour ce plan' : '',
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: quotaReached
                          ? const [kTextMuted, kTextMuted]
                          : const [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: quotaReached
                        ? []
                        : [BoxShadow(
                            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouvelle école', style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    )),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _FilterDropdown(
            icon: Icons.category_outlined, label: 'Type',
            items: const {
              'tous': 'Tous les types',
              'public': 'Public',
              'prive': 'Privé',
              'mixte': 'Mixte',
            },
            value: filterType, onChanged: onType, active: filterType != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded, label: 'Statut',
            items: const {
              'tous': 'Tous les statuts',
              'active': 'Active',
              'inactive': 'Inactive',
            },
            value: filterStatus, onChanged: onStatus, active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.location_on_rounded, label: 'Département',
            items: {
              'tous': 'Tous',
              for (final d in _kDepartements) d: d,
            },
            value: filterDept, onChanged: onDept, active: filterDept != 'tous',
          ),
          const Spacer(),
          if (_hasFilters)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_alt_off_rounded, size: 13, color: kRed),
                    SizedBox(width: 4),
                    Text('Réinitialiser', style: TextStyle(
                      color: kRed, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
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
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Icon(
            isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
            size: 18, color: kNavy,
          ),
        ),
      ),
    ),
  );
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
    constraints: const BoxConstraints(minWidth: 140),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: Icon(Icons.expand_more_rounded, size: 14,
            color: active ? kNavy : kTextMuted),
        style: TextStyle(
          color: active ? kNavy : kTextPrimary,
          fontSize: 12.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: kTextMuted),
            const SizedBox(width: 6),
            Text(e.value),
          ]),
        )).toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.total, required this.filtered});
  final int total, filtered;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$filtered résultat${filtered > 1 ? 's' : ''}',
        style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: const TextStyle(color: kTextMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Case à cocher compacte ─────────────────────────────────────────────────
class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: checked ? kNavy : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: checked ? kNavy : kBorder, width: 1.5),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
        ),
      );
}

// ─── Barre d'actions groupées ───────────────────────────────────────────────
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.activeCount,
    required this.onActivate,
    required this.onDeactivate,
    required this.onClear,
  });
  final int count;
  final int activeCount;
  final VoidCallback onActivate, onDeactivate, onClear;

  @override
  Widget build(BuildContext context) {
    final inactiveCount = count - activeCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: kNavy.withValues(alpha: 0.25),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        const Flexible(child: Text('école(s) sélectionnée(s)',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
        const Spacer(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (inactiveCount > 0)
            _BulkBtn(
              icon: Icons.check_circle_outline_rounded,
              label: 'Activer',
              onTap: onActivate,
            ),
          if (activeCount > 0)
            _BulkBtn(
              icon: Icons.block_rounded,
              label: 'Désactiver',
              onTap: onDeactivate,
            ),
          _BulkBtn(
            icon: Icons.close_rounded,
            label: 'Effacer',
            subtle: true,
            onTap: onClear,
          ),
        ]),
      ]),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.icon, required this.label, required this.onTap,
    this.subtle = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: subtle ? Colors.transparent : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: subtle ? Colors.white.withValues(alpha: 0.4) : Colors.white,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: subtle ? Colors.white : kNavy),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                  color: subtle ? Colors.white : kNavy,
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.schools, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit, required this.onToggle,
    required this.selectedIds, required this.allSelected,
    required this.onToggleAll, required this.onToggleSelect,
  });
  final List<SchoolDetail> schools;
  final String sortField;
  final bool   sortAsc;
  final Set<String> selectedIds;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String>      onSort;
  final ValueChanged<SchoolDetail> onView;
  final ValueChanged<SchoolDetail> onEdit;
  final ValueChanged<SchoolDetail> onToggle;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucune école ne correspond à vos filtres.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort,
              allSelected: allSelected, onToggleAll: onToggleAll),
          ...schools.asMap().entries.map((e) => _TableRow(
            school:   e.value,
            isOdd:    e.key.isOdd,
            selected: selectedIds.contains(e.value.id),
            onToggleSelect: () => onToggleSelect(e.value.id),
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onToggle: () => onToggle(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortField, required this.sortAsc, required this.onSort,
    required this.allSelected, required this.onToggleAll,
  });
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;
  final bool allSelected;
  final VoidCallback onToggleAll;

  Widget _col(String label, String field, {int flex = 1}) => Expanded(
    flex: flex,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 3),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 12,
            color: sortField == field ? kNavy : kTextMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: kSurface,
    child: Row(children: [
      SizedBox(width: 36, child: Align(
        alignment: Alignment.centerLeft,
        child: _CheckSquare(checked: allSelected, onTap: onToggleAll),
      )),
      const SizedBox(width: 8),
      const SizedBox(width: 46),
      const SizedBox(width: 12),
      _col('NOM DE L\'ÉCOLE', 'name', flex: 3),
      _col('TYPE',            'type'),
      _col('DÉPARTEMENT',     'dept'),
      _col('ÉLÈVES',          'students'),
      _col('PERSONNEL',       'staff'),
      _col('CLASSES',         'classes'),
      const SizedBox(width: 32,
          child: Text('ÉTAT',
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
      const SizedBox(width: 110,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.school, required this.isOdd,
    required this.selected, required this.onToggleSelect,
    required this.onView, required this.onEdit, required this.onToggle,
  });
  final SchoolDetail school;
  final bool isOdd;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onView, onEdit, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: widget.selected
              ? kNavy.withValues(alpha: 0.07)
              : _hov
                  ? kNavy.withValues(alpha: 0.04)
                  : widget.isOdd
                      ? kSurface.withValues(alpha: 0.5)
                      : Colors.white,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(width: 36, child: Align(
            alignment: Alignment.centerLeft,
            child: _CheckSquare(checked: widget.selected, onTap: widget.onToggleSelect),
          )),
          const SizedBox(width: 8),
          _SchoolAvatar(
            logoUrl: s.logoUrl,
            size: 46, radius: 11, iconSize: 20,
            iconColor: s.isActive ? kNavy : kTextMuted,
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name,
                style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            if (s.code != null)
              Text('Code : ${s.code}',
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ])),
          Expanded(child: _TypeBadge(type: s.type)),
          Expanded(child: Text(s.department ?? '—',
              style: const TextStyle(color: kTextPrimary, fontSize: 12.5),
              overflow: TextOverflow.ellipsis)),
          Expanded(child: Text('${s.students}',
              style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(child: Text('${s.staff}',
              style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(child: Text('${s.classes}',
              style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
          SizedBox(
            width: 32,
            child: Icon(
              s.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18, color: s.isActive ? kGreen : kRed,
            ),
          ),
          SizedBox(
            width: 110,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(icon: Icons.visibility_outlined, color: _kBlue,
                  tooltip: 'Voir les détails', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: kNavy,
                  tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: s.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                color: s.isActive ? kRed : kGreen,
                tooltip: s.isActive ? 'Désactiver' : 'Activer',
                onTap: widget.onToggle,
              ),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon, required this.color,
    required this.tooltip, required this.onTap,
  });
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'public' => ('Public', _kBlue),
      'mixte'  => ('Mixte',  _kOrange),
      _        => ('Privé',  _kGold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.schools, required this.onView, required this.onEdit, required this.onToggle});
  final List<SchoolDetail> schools;
  final ValueChanged<SchoolDetail> onView;
  final ValueChanged<SchoolDetail> onEdit;
  final ValueChanged<SchoolDetail> onToggle;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucune école ne correspond à vos filtres.',
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: schools.map((s) => SizedBox(width: w,
          child: _SchoolCard(s: s, onView: () => onView(s), onEdit: () => onEdit(s), onToggle: () => onToggle(s)))).toList(),
      );
    });
  }
}

class _SchoolCard extends StatefulWidget {
  const _SchoolCard({required this.s, required this.onView, required this.onEdit, required this.onToggle});
  final SchoolDetail s;
  final VoidCallback onView, onEdit, onToggle;

  @override
  State<_SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<_SchoolCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hov ? kNavy.withValues(alpha: 0.3) : kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
            blurRadius: _hov ? 12 : 4,
            offset: Offset(0, _hov ? 4 : 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                s.isActive ? kNavy : kTextMuted,
                (s.isActive ? kNavy : kTextMuted).withValues(alpha: 0.4),
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _SchoolAvatar(
                  logoUrl: s.logoUrl,
                  size: 46, radius: 11, iconSize: 22,
                  iconColor: s.isActive ? kNavy : kTextMuted,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  if (s.code != null)
                    Text('Code : ${s.code}', style: const TextStyle(fontSize: 11, color: kTextMuted)),
                ])),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'view') { widget.onView(); }
                    else if (v == 'edit') { widget.onEdit(); }
                    else if (v == 'toggle') { widget.onToggle(); }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Row(children: [
                      Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
                      SizedBox(width: 10), Text('Voir les détails'),
                    ])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: kNavy),
                      SizedBox(width: 10), Text('Modifier'),
                    ])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [
                      Icon(s.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          size: 18, color: s.isActive ? kRed : kGreen),
                      const SizedBox(width: 10),
                      Text(s.isActive ? 'Désactiver' : 'Activer'),
                    ])),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _TypeBadge(type: s.type),
                if (s.city != null) AdminBadge(s.city!, color: kTextMuted, icon: Icons.location_on_outlined),
                if (!s.isActive) const AdminBadge('Inactive', color: kRed, icon: Icons.block_rounded),
              ]),
              const Divider(height: 26, color: kBorder),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat(icon: Icons.groups_rounded,  label: 'Élèves',    value: s.students, color: _kPurple),
                _Stat(icon: Icons.badge_rounded,   label: 'Personnel', value: s.staff,    color: _kBlue),
                _Stat(icon: Icons.class_rounded,   label: 'Classes',   value: s.classes,  color: kGreen),
              ]),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 4),
    Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
    Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
  ]);
}

// ─── Modal détails école (style super_admin) ─────────────────────────────────

String _schoolTypeLabel(String t) => switch (t) {
  'public' => 'Public',
  'mixte'  => 'Mixte',
  _        => 'Privé',
};

Color _schoolTypeColor(String t) => switch (t) {
  'public' => _kBlue,
  'mixte'  => _kOrange,
  _        => _kGold,
};

class _SchoolDetailModal extends StatefulWidget {
  const _SchoolDetailModal({
    required this.school,
    required this.onEdit,
    required this.onToggle,
  });
  final SchoolDetail school;
  final VoidCallback onEdit, onToggle;

  @override
  State<_SchoolDetailModal> createState() => _SchoolDetailModalState();
}

class _SchoolDetailModalState extends State<_SchoolDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    final typeColor = _schoolTypeColor(s.type);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              _SchoolAvatar(
                logoUrl: s.logoUrl,
                size: 66, radius: 14, iconSize: 30,
                iconColor: s.isActive ? kNavy : kTextMuted,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _TypeBadge(type: s.type),
                    AdminBadge(s.isActive ? 'Active' : 'Inactive',
                        color: s.isActive ? kGreen : kRed,
                        icon: s.isActive ? Icons.check_circle : Icons.block_rounded),
                    if (s.code != null)
                      AdminBadge('Code ${s.code}', color: kTextMuted, icon: Icons.tag_rounded),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: kTextMuted),
                    const SizedBox(width: 3),
                    Flexible(child: Text(
                        [s.city, s.department].where((e) => e != null && e.isNotEmpty).join(', '),
                        style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (s.foundedYear != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.history_edu_outlined, size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text('Fondée en ${s.foundedYear}',
                          style: const TextStyle(color: kTextMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.edit_rounded, color: kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.close_rounded, color: kTextMuted,
                    tooltip: 'Fermer', onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          // ─ Tabs ────────────────────────────────────────────────────────────
          Container(
            color: kSurface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: kNavy,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: 'Informations'),
                Tab(icon: Icon(Icons.school_outlined, size: 16),      text: 'Cycles'),
                Tab(icon: Icon(Icons.people_outline_rounded, size: 16), text: 'Utilisateurs'),
                Tab(icon: Icon(Icons.bar_chart_rounded, size: 16),    text: 'Statistiques'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SchoolInfoTab(school: s),
                _SchoolCyclesTab(schoolId: s.id),
                _SchoolUsersTab(schoolId: s.id),
                _SchoolStatsTab(school: s, typeColor: typeColor),
              ],
            ),
          ),
          // ─ Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(s.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(s.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: s.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: s.isActive ? _kOrange : kGreen),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy, foregroundColor: Colors.white, elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Onglet Cycles d'enseignement ─────────────────────────────────────────────

class _SchoolCyclesTab extends ConsumerWidget {
  const _SchoolCyclesTab({required this.schoolId});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catAsync = ref.watch(educationCatalogProvider);
    final selAsync = ref.watch(schoolEducationProvider(schoolId));

    if (catAsync.isLoading || selAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: kNavy));
    }
    if (catAsync.hasError || selAsync.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AdminErrorBanner(message: 'Impossible de charger les cycles.'),
        ),
      );
    }

    final cat = catAsync.valueOrNull ?? EducationCatalog.empty;
    final sel = selAsync.valueOrNull ?? SchoolEducationSelection.empty;

    if (sel.cycleIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AdminEmptyState(
          icon: Icons.school_outlined,
          title: 'Aucun cycle assigné',
          message: "Modifiez l'école pour lui attribuer des cycles d'enseignement.",
        ),
      );
    }

    final assignedCycles = cat.cycles
        .where((c) => sel.cycleIds.contains(c.id))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cycle in assignedCycles) ...[
            _CycleSection(cycle: cycle, cat: cat, sel: sel),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CycleSection extends StatelessWidget {
  const _CycleSection({required this.cycle, required this.cat, required this.sel});
  final EducationCycle cycle;
  final EducationCatalog cat;
  final SchoolEducationSelection sel;

  static Color _cycleColor(String code) => switch (code.toLowerCase()) {
        'prescolaire' || 'pres' => const Color(0xFFFF6B35),
        'primaire'    || 'prim' => const Color(0xFF0EA5E9),
        'college'     || 'coll' => const Color(0xFF7C3AED),
        'lycee'       || 'lyc'  => kNavy,
        'fp'                    => kGreen,
        _                       => kNavy,
      };

  static IconData _cycleIcon(String code) => switch (code.toLowerCase()) {
        'prescolaire' || 'pres' => Icons.child_care_rounded,
        'primaire'    || 'prim' => Icons.menu_book_rounded,
        'college'     || 'coll' => Icons.library_books_rounded,
        'lycee'       || 'lyc'  => Icons.account_balance_rounded,
        'fp'                    => Icons.build_rounded,
        _                       => Icons.school_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _cycleColor(cycle.code);
    final List<Widget> contentRows = [];

    if (cycle.hasPrograms) {
      final programs = cat.programs
          .where((p) => sel.programIds.contains(p.id) && p.cycleId == cycle.id)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (programs.isEmpty) {
        contentRows.add(_emptyRow('Aucune filière sélectionnée'));
      } else {
        for (final prog in programs) {
          final levels = cat.levels
              .where((l) => sel.levelIds.contains(l.id) && l.programId == prog.id)
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          contentRows.add(_ProgramRow(program: prog, levels: levels, color: color));
        }
      }
    } else {
      final levels = cat.levels
          .where((l) => sel.levelIds.contains(l.id) && l.cycleId == cycle.id && l.programId == null)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (levels.isEmpty) {
        contentRows.add(_emptyRow('Aucun niveau sélectionné'));
      } else {
        contentRows.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: levels
                .map((l) => _LevelChip(name: l.name, color: color))
                .toList(),
          ),
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête du cycle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            Icon(_cycleIcon(cycle.code), size: 17, color: color),
            const SizedBox(width: 8),
            Text(cycle.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
        ...contentRows,
      ]),
    );
  }

  static Widget _emptyRow(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(msg, style: const TextStyle(fontSize: 12, color: kTextMuted)),
      );
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.program, required this.levels, required this.color});
  final EducationProgram program;
  final List<EducationLevel> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.folder_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(program.name,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        if (levels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: levels.map((l) => _LevelChip(name: l.name, color: color)).toList(),
          ),
        ],
      ]),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(name,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

// ─── Onglet Utilisateurs ───────────────────────────────────────────────────────

class _SchoolUsersTab extends ConsumerWidget {
  const _SchoolUsersTab({required this.schoolId});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(schoolUsersProvider(schoolId));

    return usersAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator(color: kNavy)),
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AdminErrorBanner(message: 'Impossible de charger les utilisateurs.'),
        ),
      ),
      data: (users) => users.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: AdminEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Aucun utilisateur',
                message: "Cette école n'a pas encore d'utilisateurs enregistrés.",
              ),
            )
          : _SchoolUsersList(users: users),
    );
  }
}

class _SchoolUsersList extends StatelessWidget {
  const _SchoolUsersList({required this.users});
  final List<SchoolUser> users;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < users.length; i++) ...[
              _SchoolUserRow(user: users[i]),
              if (i < users.length - 1) const Divider(height: 1, color: kBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolUserRow extends StatelessWidget {
  const _SchoolUserRow({required this.user});
  final SchoolUser user;

  static Color _roleColor(String role) => switch (role) {
        'directeur' || 'proviseur' => kNavy,
        'enseignant'               => const Color(0xFF0EA5E9),
        'cpe' || 'surveillant'     => const Color(0xFF7C3AED),
        'comptable'                => kGreen,
        'secretaire'               => const Color(0xFFFF6B35),
        _                          => kTextMuted,
      };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.person_rounded, color: roleColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName.isEmpty ? '—' : user.fullName,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              AdminBadge(roleLabel(user.role), color: roleColor),
              if (user.accessProfileName != null)
                AdminBadge(user.accessProfileName!, color: kNavy,
                    icon: Icons.shield_outlined),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        AdminBadge(
          user.isActive ? 'Actif' : 'Inactif',
          color: user.isActive ? kGreen : kRed,
        ),
      ]),
    );
  }
}

// ─── Onglet Informations ───────────────────────────────────────────────────────

class _SchoolInfoTab extends StatelessWidget {
  const _SchoolInfoTab({required this.school});
  final SchoolDetail school;

  @override
  Widget build(BuildContext context) {
    final s = school;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.email_outlined, 'Email', s.email ?? '—'),
          AdminDetailRow(Icons.phone_outlined, 'Téléphone', s.phone ?? '—'),
          AdminDetailRow(Icons.home_outlined, 'Adresse', s.address ?? '—'),
          AdminDetailRow(Icons.location_city_outlined, 'Ville', s.city ?? '—'),
          AdminDetailRow(Icons.map_outlined, 'Département', s.department ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Identité'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.business_outlined, 'Type', _schoolTypeLabel(s.type)),
          AdminDetailRow(Icons.tag_rounded, 'Code établissement', s.code ?? '—'),
          AdminDetailRow(Icons.history_edu_outlined, 'Année de fondation',
              s.foundedYear?.toString() ?? '—'),
          AdminDetailRow(
              s.isActive ? Icons.check_circle_outline : Icons.block_outlined,
              'Statut', s.isActive ? 'Active' : 'Inactive',
              valueColor: s.isActive ? kGreen : kRed, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
              icon: Icons.groups_rounded, label: '${s.students} élèves', color: _kPurple)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.badge_rounded, label: '${s.staff} personnel', color: _kBlue)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.class_rounded, label: '${s.classes} classes', color: kGreen)),
        ]),
      ]),
    );
  }
}

class _SchoolStatsTab extends StatelessWidget {
  const _SchoolStatsTab({required this.school, required this.typeColor});
  final SchoolDetail school;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final s = school;
    final perClass = s.classes > 0 ? (s.students / s.classes) : 0.0;
    final perStaff = s.staff > 0 ? (s.students / s.staff) : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _BigStat(
              icon: Icons.groups_rounded, value: '${s.students}',
              label: 'Élèves inscrits', color: _kPurple)),
          const SizedBox(width: 12),
          Expanded(child: _BigStat(
              icon: Icons.badge_rounded, value: '${s.staff}',
              label: 'Membres du personnel', color: _kBlue)),
          const SizedBox(width: 12),
          Expanded(child: _BigStat(
              icon: Icons.class_rounded, value: '${s.classes}',
              label: 'Classes ouvertes', color: kGreen)),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Ratios d\'encadrement'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.school_outlined, 'Élèves par classe',
              s.classes > 0 ? perClass.toStringAsFixed(1) : '—',
              valueColor: perClass > 50 ? kRed : kTextPrimary),
          AdminDetailRow(Icons.supervisor_account_outlined, 'Élèves par agent',
              s.staff > 0 ? perStaff.toStringAsFixed(1) : '—',
              valueColor: perStaff > 35 ? kRed : kTextPrimary, last: true),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: kTextMuted),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Les ratios élevés (rouge) signalent une surcharge potentielle : '
              '> 50 élèves/classe ou > 35 élèves/agent.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Form dialog école (style Groupe Scolaire) ────────────────────────────────

class SchoolFormDialog extends ConsumerStatefulWidget {
  const SchoolFormDialog({super.key, this.school});
  final SchoolDetail? school;

  @override
  ConsumerState<SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends ConsumerState<SchoolFormDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _arrondissement;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _founded;
  late final TextEditingController _motto;
  String  _type       = 'prive';
  String? _department;
  bool    _saving     = false;
  String? _error;

  // ── Logo de l'école ──
  String?    _logoUrl;
  Uint8List? _logoPreviewBytes;
  bool       _uploadingLogo = false;

  // ── Offre éducative : cycles / filières / niveaux ──
  Set<String> _cycleIds   = {};
  Set<String> _programIds = {};
  Set<String> _levelIds   = {};
  bool _eduLoaded = false;

  late final AnimationController _btnCtrl;
  late final Animation<double>   _btnScale;
  bool _btnHov = false;

  bool get _isEdit => widget.school != null;

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _name           = TextEditingController(text: s?.name ?? '');
    _code           = TextEditingController(text: s?.code ?? '');
    _city           = TextEditingController(text: s?.city ?? '');
    _province       = TextEditingController(text: s?.province ?? '');
    _arrondissement = TextEditingController(text: s?.arrondissement ?? '');
    _address        = TextEditingController(text: s?.address ?? '');
    _phone          = TextEditingController(text: s?.phone ?? '');
    _email          = TextEditingController(text: s?.email ?? '');
    _website        = TextEditingController(text: s?.website ?? '');
    _founded        = TextEditingController(text: s?.foundedYear?.toString() ?? '');
    _motto          = TextEditingController(text: s?.motto ?? '');
    _logoUrl        = s?.logoUrl;
    _type = s?.type ?? 'prive';
    _department = (s?.department != null && _kDepartements.contains(s!.department))
        ? s.department
        : null;
    _btnCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(_btnCtrl);

    // En édition : charger l'offre éducative déjà enregistrée.
    if (_isEdit) {
      Future.microtask(() async {
        try {
          final sel =
              await ref.read(schoolEducationProvider(widget.school!.id).future);
          if (!mounted) return;
          setState(() {
            _cycleIds   = {...sel.cycleIds};
            _programIds = {...sel.programIds};
            _levelIds   = {...sel.levelIds};
            _eduLoaded  = true;
          });
        } catch (_) {
          if (mounted) setState(() => _eduLoaded = true);
        }
      });
    } else {
      _eduLoaded = true;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _city, _province, _arrondissement,
                     _address, _phone, _email, _website, _founded, _motto]) {
      c.dispose();
    }
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _logoPreviewBytes = file.bytes;
      _uploadingLogo = true;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final fileName = 'school_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'schools/$fileName';
      await client.storage.from('group-logos').uploadBinary(
        path,
        file.bytes!,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );
      final url = client.storage.from('group-logos').getPublicUrl(path);
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        setState(() => _logoPreviewBytes = null);
        _eduSnack('Erreur upload logo : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final svc    = ref.read(adminSchoolsServiceProvider);
      final eduSvc = ref.read(educationServiceProvider);
      final year   = int.tryParse(_founded.text.trim());
      final String schoolId;
      if (_isEdit) {
        await svc.update(
          id: widget.school!.id,
          name: _name.text.trim(), type: _type, code: _code.text.trim(),
          address: _address.text.trim(), city: _city.text.trim(),
          province: _province.text.trim(), arrondissement: _arrondissement.text.trim(),
          department: _department, phone: _phone.text.trim(),
          email: _email.text.trim(), website: _website.text.trim(),
          motto: _motto.text.trim(), foundedYear: year, logoUrl: _logoUrl,
        );
        schoolId = widget.school!.id;
      } else {
        schoolId = await svc.create(
          name: _name.text.trim(), type: _type, code: _code.text.trim(),
          address: _address.text.trim(), city: _city.text.trim(),
          province: _province.text.trim(), arrondissement: _arrondissement.text.trim(),
          department: _department, phone: _phone.text.trim(),
          email: _email.text.trim(), website: _website.text.trim(),
          motto: _motto.text.trim(), foundedYear: year, logoUrl: _logoUrl,
        );
      }
      // Enregistrer l'offre éducative (cycles / filières / niveaux).
      await eduSvc.saveSchoolEducation(
        schoolId: schoolId,
        cycleIds: _cycleIds,
        programIds: _programIds,
        levelIds: _levelIds,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'École mise à jour' : 'École créée avec succès'),
        ));
      }
    } catch (e) {
      setState(() { _error = '$e'; _saving = false; });
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
    filled: true,
    fillColor: kSurface,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kNavy, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kRed)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  // ════════════════════════════════════════════════════════════════════════
  //  Section « Cycles d'enseignement » — 100 % piloté par le référentiel
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildEducationSection() {
    final catAsync = ref.watch(educationCatalogProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SchFormLabel('CYCLES D\'ENSEIGNEMENT'),
      const SizedBox(height: 4),
      const Text(
        'Sélectionnez les cycles proposés par l\'établissement, puis les niveaux '
        'exacts. Une école peut combiner plusieurs cycles simultanément.',
        style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 14),
      catAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: _eduSpinner,
        error: (e, _) => _eduError('Référentiel indisponible : $e'),
        data: (cat) => _eduLoaded ? _eduSelector(cat) : _eduSpinner(),
      ),
    ]);
  }

  Widget _eduSpinner() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
          ),
        ),
      );

  Widget _eduSelector(EducationCatalog cat) {
    final cycles = cat.activeCycles;
    if (cycles.isEmpty) {
      return _eduError('Aucun cycle dans le référentiel.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in cycles)
          _eduChip(
            label: c.name,
            selected: _cycleIds.contains(c.id),
            color: kNavy,
            onTap: () => _toggleCycle(c, cat),
          ),
      ]),
      for (final c in cycles.where((c) => _cycleIds.contains(c.id))) ...[
        const SizedBox(height: 12),
        _cycleCard(c, cat),
      ],
      if (_cycleIds.isEmpty) ...[
        const SizedBox(height: 6),
        const Text('Aucun cycle sélectionné pour l\'instant.',
            style: TextStyle(fontSize: 11, color: kTextMuted, fontStyle: FontStyle.italic)),
      ],
    ]);
  }

  Widget _cycleCard(EducationCycle c, EducationCatalog cat) {
    final children = <Widget>[
      Row(children: [
        Icon(_cycleIcon(c.code), size: 16, color: kNavy),
        const SizedBox(width: 8),
        Expanded(child: Text(c.name, style: const TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w800, color: kTextPrimary))),
      ]),
      const SizedBox(height: 10),
    ];

    if (c.hasPrograms) {
      // Cycle à filières (ex. Formation Professionnelle)
      final progs = cat
          .programsOf(c.id)
          .where((p) => p.isActive || _programIds.contains(p.id))
          .toList();
      children
        ..add(_eduSubHeader('Filières', onAdd: () => _addProgram(c)))
        ..add(const SizedBox(height: 8))
        ..add(progs.isEmpty
            ? const Text('Aucune filière. Ajoutez-en une.',
                style: TextStyle(fontSize: 11, color: kTextMuted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in progs)
                  _eduChip(
                    label: p.name,
                    selected: _programIds.contains(p.id),
                    color: _kBlue,
                    custom: p.isCustom,
                    onTap: () => _toggleProgram(p, cat),
                    onMenu: p.isCustom ? (a) => _programMenu(a, p) : null,
                  ),
              ]));
      for (final p in progs.where((p) => _programIds.contains(p.id))) {
        final lvls = cat
            .levelsOfProgram(p.id)
            .where((l) => l.isActive || _levelIds.contains(l.id))
            .toList();
        children
          ..add(const SizedBox(height: 10))
          ..add(Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _eduSubHeader('Niveaux · ${p.name}',
                  onAdd: () => _addLevel(c, program: p)),
              const SizedBox(height: 8),
              if (lvls.isEmpty)
                const Text('Aucun niveau. Ajoutez-en un.',
                    style: TextStyle(fontSize: 11, color: kTextMuted))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in lvls)
                    _eduChip(
                      label: l.name,
                      selected: _levelIds.contains(l.id),
                      color: kGreen,
                      custom: l.isCustom,
                      onTap: () => _toggleLevel(l),
                    ),
                ]),
            ]),
          ));
      }
    } else {
      // Cycle à niveaux directs (préscolaire, primaire, collège, lycée)
      final lvls = cat
          .generalLevelsOf(c.id)
          .where((l) => l.isActive || _levelIds.contains(l.id))
          .toList();
      children
        ..add(_eduSubHeader('Niveaux', onAdd: () => _addLevel(c)))
        ..add(const SizedBox(height: 8))
        ..add(lvls.isEmpty
            ? const Text('Aucun niveau. Ajoutez-en un.',
                style: TextStyle(fontSize: 11, color: kTextMuted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in lvls)
                  _eduChip(
                    label: l.name,
                    selected: _levelIds.contains(l.id),
                    color: kGreen,
                    custom: l.isCustom,
                    onTap: () => _toggleLevel(l),
                  ),
              ]));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _eduSubHeader(String title, {required VoidCallback onAdd}) => Row(children: [
        Text(title.toUpperCase(), style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: kTextMuted, letterSpacing: 0.8)),
        const Spacer(),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 14, color: kNavy),
              SizedBox(width: 3),
              Text('Ajouter', style: TextStyle(
                  fontSize: 11, color: kNavy, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]);

  Widget _eduChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    bool custom = false,
    void Function(String action)? onMenu,
  }) {
    final body = Padding(
      padding: EdgeInsets.fromLTRB(12, 8, onMenu != null ? 2 : 12, 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (selected) ...[
          const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
        ],
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kTextPrimary)),
        if (custom) ...[
          const SizedBox(width: 5),
          Container(width: 5, height: 5, decoration: BoxDecoration(
              color: selected ? Colors.white : _kPurple, shape: BoxShape.circle)),
        ],
      ]),
    );
    return Container(
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? color : kBorder, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: body,
          ),
        ),
        if (onMenu != null)
          SizedBox(
            width: 28, height: 30,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'Gérer',
              icon: Icon(Icons.more_vert_rounded, size: 15,
                  color: selected ? Colors.white : kTextMuted),
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Renommer')),
                PopupMenuItem(value: 'disable', child: Text('Désactiver')),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _eduError(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kRed.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: kRed),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontSize: 12, color: kRed))),
        ]),
      );

  IconData _cycleIcon(String code) {
    switch (code) {
      case 'prescolaire':   return Icons.child_care_rounded;
      case 'primaire':      return Icons.menu_book_rounded;
      case 'college':       return Icons.school_rounded;
      case 'lycee':         return Icons.account_balance_rounded;
      case 'formation_pro': return Icons.engineering_rounded;
      default:              return Icons.category_rounded;
    }
  }

  // ── Sélection (toggles avec cascade pour éviter les orphelins) ──────────
  void _toggleCycle(EducationCycle c, EducationCatalog cat) {
    setState(() {
      if (_cycleIds.contains(c.id)) {
        _cycleIds.remove(c.id);
        final progIds = cat.programsOf(c.id).map((p) => p.id).toSet();
        final lvlIds  = cat.levels
            .where((l) => l.cycleId == c.id).map((l) => l.id).toSet();
        _programIds.removeWhere(progIds.contains);
        _levelIds.removeWhere(lvlIds.contains);
      } else {
        _cycleIds.add(c.id);
      }
    });
  }

  void _toggleProgram(EducationProgram p, EducationCatalog cat) {
    setState(() {
      if (_programIds.contains(p.id)) {
        _programIds.remove(p.id);
        final lvlIds = cat.levelsOfProgram(p.id).map((l) => l.id).toSet();
        _levelIds.removeWhere(lvlIds.contains);
      } else {
        _programIds.add(p.id);
        _cycleIds.add(p.cycleId);
      }
    });
  }

  void _toggleLevel(EducationLevel l) {
    setState(() {
      if (_levelIds.contains(l.id)) {
        _levelIds.remove(l.id);
      } else {
        _levelIds.add(l.id);
        _cycleIds.add(l.cycleId);
        if (l.programId != null) _programIds.add(l.programId!);
      }
    });
  }

  // ── Gestion dynamique du référentiel (filières / niveaux du groupe) ─────
  Future<void> _addProgram(EducationCycle c) async {
    final name = await _promptName('Nouvelle filière', hint: 'Nom de la filière');
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref.read(educationServiceProvider)
          .createProgram(cycleId: c.id, name: name.trim());
      if (!mounted) return;
      setState(() { _programIds.add(id); _cycleIds.add(c.id); });
    } catch (e) {
      if (mounted) _eduSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _addLevel(EducationCycle c, {EducationProgram? program}) async {
    final name = await _promptName(
      program == null ? 'Nouveau niveau' : 'Nouveau niveau · ${program.name}',
      hint: 'Ex. 4ème année',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref.read(educationServiceProvider).createLevel(
          cycleId: c.id, programId: program?.id, name: name.trim());
      if (!mounted) return;
      setState(() {
        _levelIds.add(id);
        _cycleIds.add(c.id);
        if (program != null) _programIds.add(program.id);
      });
    } catch (e) {
      if (mounted) _eduSnack('Erreur : $e', error: true);
    }
  }

  Future<void> _programMenu(String action, EducationProgram p) async {
    if (action == 'rename') {
      final name = await _promptName('Renommer la filière', initial: p.name);
      if (name == null || name.trim().isEmpty) return;
      try {
        await ref.read(educationServiceProvider).updateProgram(
            id: p.id, name: name.trim(), description: p.description);
        if (mounted) _eduSnack('Filière renommée');
      } catch (e) {
        if (mounted) _eduSnack('Erreur : $e', error: true);
      }
    } else if (action == 'disable') {
      try {
        await ref.read(educationServiceProvider).setProgramActive(p.id, false);
        if (!mounted) return;
        setState(() => _programIds.remove(p.id));
        _eduSnack('Filière désactivée');
      } catch (e) {
        if (mounted) _eduSnack('Erreur : $e', error: true);
      }
    }
  }

  Future<String?> _promptName(String title, {String? hint, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: _inputDec(hint ?? 'Nom'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
            child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Valider')),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  void _eduSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? kRed : kGreen,
      content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 36),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40, offset: const Offset(0, 10),
          )],
        ),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2F5A), kNavy],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                    color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEdit ? 'Modifier l\'école' : 'Nouvelle école',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? 'Modifiez les informations de l\'établissement'
                      : 'Renseignez les informations du nouvel établissement',
                  style: const TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ])),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: kTextMuted),
                ),
              ),
            ]),
          ),
          // ── Body ────────────────────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SchFormLabel('IDENTITÉ DE L\'ÉCOLE'),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SchoolLogoUploadBox(
                    name: _name.text.isNotEmpty ? _name.text : 'É',
                    logoUrl: _logoUrl,
                    previewBytes: _logoPreviewBytes,
                    uploading: _uploadingLogo,
                    onPick: _pickAndUploadLogo,
                    onRemove: () => setState(() {
                      _logoUrl = null;
                      _logoPreviewBytes = null;
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                        decoration: _inputDec('Nom de l\'établissement *'),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: _inputDec('Type'),
                          items: const [
                            DropdownMenuItem(value: 'prive',  child: Text('Privé')),
                            DropdownMenuItem(value: 'public', child: Text('Public')),
                            DropdownMenuItem(value: 'mixte',  child: Text('Mixte')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'prive'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(
                          controller: _code,
                          decoration: _inputDec('Code établissement'),
                        )),
                      ]),
                    ],
                  )),
                ]),
                const _SchFormDivider(),
                const _SchFormLabel('LOCALISATION'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _city,
                    decoration: _inputDec('Ville / Commune'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _province,
                    decoration: _inputDec('Province'),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _arrondissement,
                    decoration: _inputDec('Arrondissement / Quartier'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    initialValue: _department,
                    isExpanded: true,
                    decoration: _inputDec('Département'),
                    items: _kDepartements.map((d) => DropdownMenuItem(
                      value: d, child: Text(d, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _department = v),
                  )),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: _inputDec('Adresse complète'),
                ),
                const _SchFormDivider(),
                const _SchFormLabel('CONTACTS'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDec('Téléphone'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return v.contains('@') ? null : 'Email invalide';
                    },
                    decoration: _inputDec('Email'),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _founded,
                    keyboardType: TextInputType.number,
                    decoration: _inputDec('Année de fondation'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: _inputDec('Site web'),
                  )),
                ]),
                const _SchFormDivider(),
                const _SchFormLabel('IDENTITÉ OFFICIELLE'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motto,
                  maxLines: 3,
                  decoration: _inputDec('Devise / Motto de l\'établissement'),
                ),
                const _SchFormDivider(),
                _buildEducationSection(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AdminErrorBanner(message: _error!),
                ],
              ]),
            ),
          )),
          // ── Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Annuler'),
                style: TextButton.styleFrom(foregroundColor: kTextMuted),
              ),
              const Spacer(),
              if (_saving)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1A2F5A), kNavy],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text('Enregistrement…',
                        style: TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                )
              else
                _SchSaveBtn(
                  isEdit: _isEdit,
                  btnCtrl: _btnCtrl,
                  btnScale: _btnScale,
                  btnHov: _btnHov,
                  onHover: (h) => setState(() => _btnHov = h),
                  onTap: _submit,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets locaux du formulaire école ────────────────────────────────────────

class _SchoolLogoUploadBox extends StatelessWidget {
  const _SchoolLogoUploadBox({
    required this.name,
    required this.onPick,
    required this.onRemove,
    this.logoUrl,
    this.previewBytes,
    this.uploading = false,
  });
  final String       name;
  final String?      logoUrl;
  final Uint8List?   previewBytes;
  final bool         uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static const _colors = [kNavy, kGreen, _kPurple, _kOrange, _kBlue];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'É';
  }

  Color get _color =>
      name.isNotEmpty ? _colors[name.codeUnitAt(0) % _colors.length] : kNavy;

  bool get _hasImage =>
      previewBytes != null || (logoUrl != null && logoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.topRight, clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasImage ? kNavy.withValues(alpha: 0.35) : kBorder,
                  width: _hasImage ? 2 : 1.5,
                ),
                color: kSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildContent(),
            ),
          ),
        ),
        if (_hasImage && !uploading)
          Positioned(
            top: -4, right: -4,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kNavy.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(uploading ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                  size: 12, color: kNavy),
              const SizedBox(width: 4),
              Text(
                uploading ? 'Upload…' : (_hasImage ? 'Changer' : 'Logo'),
                style: const TextStyle(
                    color: kNavy, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    if (uploading) {
      return const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
        ),
      );
    }
    if (previewBytes != null) {
      return Image.memory(previewBytes!, fit: BoxFit.cover);
    }
    if (logoUrl != null && logoUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
          ),
        ),
        errorWidget: (_, _, _) => _initialsWidget(),
      );
    }
    return _initialsWidget();
  }

  Widget _initialsWidget() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_photo_alternate_rounded,
              size: 22, color: kTextMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 3),
          Text(_initials, style: TextStyle(
              color: _color, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _SchFormLabel extends StatelessWidget {
  const _SchFormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(
        color: kNavy, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1,
      )),
    ]),
  );
}

class _SchFormDivider extends StatelessWidget {
  const _SchFormDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Divider(color: kBorder, height: 1),
  );
}

class _SchSaveBtn extends StatelessWidget {
  const _SchSaveBtn({
    required this.isEdit,
    required this.btnCtrl,
    required this.btnScale,
    required this.btnHov,
    required this.onHover,
    required this.onTap,
  });
  final bool isEdit;
  final AnimationController btnCtrl;
  final Animation<double>   btnScale;
  final bool btnHov;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => onHover(true),
    onExit:  (_) => onHover(false),
    child: GestureDetector(
      onTapDown:  (_) => btnCtrl.forward(),
      onTapUp:    (_) { btnCtrl.reverse(); onTap(); },
      onTapCancel: () => btnCtrl.reverse(),
      child: ScaleTransition(
        scale: btnScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A2F5A), kNavy],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: btnHov
                ? [BoxShadow(color: kNavy.withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              isEdit ? 'Enregistrer' : 'Créer l\'école',
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            AnimatedSlide(
              offset: btnHov ? const Offset(0.15, 0) : Offset.zero,
              duration: const Duration(milliseconds: 180),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
