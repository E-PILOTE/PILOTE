import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/admin_users_provider.dart';
import '../../../core/widgets/admin_ui.dart';

// ─── Couleurs locales ─────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF6B35);
const _kBlue   = Color(0xFF0EA5E9);
const _kPurple = Color(0xFF7C3AED);

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Utilisateurs',
      child: ref.watch(adminUsersProvider).when(
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
              onPressed: () => ref.invalidate(adminUsersProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _UsersBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _UsersBody extends ConsumerStatefulWidget {
  const _UsersBody({required this.data});
  final AdminUsersData data;

  @override
  ConsumerState<_UsersBody> createState() => _UsersBodyState();
}

class _UsersBodyState extends ConsumerState<_UsersBody> {
  final _searchCtrl  = TextEditingController();
  String? _roleFilter;
  String? _schoolFilter;
  String  _statusFilter = 'all'; // all | active | inactive
  bool    _isTableView  = true;
  String  _sortField    = 'name';
  bool    _sortAsc      = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUser> _applyFilters(List<AdminUser> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((u) {
      if (_roleFilter   != null && u.role     != _roleFilter)   return false;
      if (_schoolFilter != null && u.schoolId != _schoolFilter) return false;
      if (_statusFilter == 'active'   && !u.isActive) return false;
      if (_statusFilter == 'inactive' &&  u.isActive) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q)
          || u.email.toLowerCase().contains(q)
          || (u.employeeNumber?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'role':   c = a.role.compareTo(b.role);         break;
          case 'school': c = (a.schoolName ?? '').compareTo(b.schoolName ?? ''); break;
          case 'status': c = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1); break;
          default:       c = a.fullName.compareTo(b.fullName);
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() {
    final data = widget.data;
    if (data.schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kRed,
        content: Text("Vous devez d'abord créer au moins une école."),
      ));
      return;
    }
    showDialog(context: context, builder: (_) => UserFormDialog(data: data));
  }

  void _openEdit(AdminUser u) =>
      showDialog(context: context, builder: (_) => UserFormDialog(data: widget.data, user: u));

  void _openResetPwd(AdminUser u) =>
      showDialog(context: context, builder: (_) => ResetPasswordDialog(user: u));

  void _openDetail(AdminUser u) => showDialog(
        context: context,
        builder: (_) => _UserDetailModal(
          user: u,
          onEdit:     () { Navigator.of(context).pop(); _openEdit(u); },
          onPassword: () { Navigator.of(context).pop(); _openResetPwd(u); },
          onToggle:   () { Navigator.of(context).pop(); _toggleActive(u); },
        ),
      );

  Future<void> _toggleActive(AdminUser u) async {
    try {
      await ref.read(adminUsersServiceProvider).setActive(u.id, !u.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(u.isActive ? 'Compte désactivé' : 'Compte activé'),
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
    final data     = widget.data;
    final filtered = _applyFilters(data.users);
    final roles    = {for (final u in data.users) u.role}.toList()..sort();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminUsersProvider.future),
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
                  roleFilter:     _roleFilter,
                  schoolFilter:   _schoolFilter,
                  statusFilter:   _statusFilter,
                  isTableView:    _isTableView,
                  rolesPresent:   roles,
                  schools:        data.schools,
                  onSearchChange: (_) => setState(() {}),
                  onRole:         (v) => setState(() => _roleFilter   = v),
                  onSchool:       (v) => setState(() => _schoolFilter = v),
                  onStatus:       (v) => setState(() => _statusFilter = v),
                  onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _roleFilter = _schoolFilter = null;
                    _statusFilter = 'all';
                  }),
                  onAdd: _openCreate,
                ),
                const SizedBox(height: 16),
                // ── Résultat ──────────────────────────────────────────────────
                _ResultHeader(total: data.users.length, filtered: filtered.length),
                const SizedBox(height: 12),
                // ── Vue principale ───────────────────────────────────────────
                if (data.users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Aucun utilisateur',
                      message: data.schools.isEmpty
                          ? "Créez d'abord une école, puis ajoutez les comptes du personnel."
                          : 'Ajoutez les comptes du personnel de vos établissements pour leur donner accès à la plateforme.',
                      actionLabel: data.schools.isEmpty ? null : 'Ajouter un utilisateur',
                      onAction: data.schools.isEmpty ? null : _openCreate,
                    ),
                  )
                else if (_isTableView)
                  _TableView(
                    users:     filtered,
                    sortField: _sortField,
                    sortAsc:   _sortAsc,
                    onSort: (f) => setState(() {
                      if (_sortField == f) { _sortAsc = !_sortAsc; }
                      else { _sortField = f; _sortAsc = true; }
                    }),
                    onView:     _openDetail,
                    onEdit:     _openEdit,
                    onPassword: _openResetPwd,
                    onToggle:   _toggleActive,
                    data:       data,
                  )
                else
                  _CardGrid(
                    users:      filtered,
                    data:       data,
                    onView:     _openDetail,
                    onEdit:     _openEdit,
                    onPassword: _openResetPwd,
                    onToggle:   _toggleActive,
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
    required this.label, required this.value, required this.icon,
    required this.color, this.sub, this.trend, this.trendUp = true, this.progressValue,
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
  final AdminUsersData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total',
        value: '$n',
        sub: '${data.actifs} actifs · ${data.inactifs} inactifs',
        icon: Icons.groups_rounded, color: kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Enseignants',
        value: '${data.enseignants}',
        sub: 'Personnel pédagogique',
        icon: Icons.school_rounded, color: _kBlue,
        progressValue: n > 0 ? data.enseignants / n : 0,
        trend: n > 0 ? '${(data.enseignants * 100 / n).round()}% du total' : '—',
      ),
      _KD(
        label: 'Administration',
        value: '${data.administration}',
        sub: 'Personnel non-enseignant',
        icon: Icons.badge_rounded, color: _kPurple,
        progressValue: n > 0 ? data.administration / n : 0,
        trend: n > 0 ? '${(data.administration * 100 / n).round()}% du total' : '—',
      ),
      _KD(
        label: 'Actifs',
        value: '${data.actifs}',
        sub: n > 0 ? '${(data.actifs * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Connectés (7j)',
        value: '${data.connectes7j}',
        sub: n > 0 ? '${(data.connectes7j * 100 / n).round()}% du personnel' : '—',
        icon: Icons.bolt_rounded, color: kAccent,
        progressValue: n > 0 ? data.connectes7j / n : 0,
        trend: data.connectes7j > 0 ? 'Actifs récemment' : 'Aucune activité',
        trendUp: data.connectes7j > 0,
      ),
      _KD(
        label: 'Inactifs',
        value: '${data.inactifs}',
        sub: data.inactifs > 0 ? '⚠ Accès bloqués' : '✅ Aucun',
        icon: Icons.block_rounded, color: kRed,
        progressValue: n > 0 ? data.inactifs / n : 0,
        trend: data.inactifs > 0 ? '⚠ À vérifier' : '✅ OK',
        trendUp: data.inactifs == 0,
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
        _box(double.infinity, 60, r: 8),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 14,
            mainAxisSpacing: 14, childAspectRatio: 2.6,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => _box(double.infinity, double.infinity, r: 14),
        ),
        const SizedBox(height: 20),
        _box(double.infinity, 120, r: 8),
        const SizedBox(height: 16),
        _box(200, 18, r: 8),
        const SizedBox(height: 16),
        _box(double.infinity, 48, r: 6),
        ...List.generate(7, (_) => Column(children: [
          const SizedBox(height: 1),
          _box(double.infinity, 60, r: 0),
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
    required this.roleFilter,
    required this.schoolFilter,
    required this.statusFilter,
    required this.isTableView,
    required this.rolesPresent,
    required this.schools,
    required this.onSearchChange,
    required this.onRole,
    required this.onSchool,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String?  roleFilter, schoolFilter;
  final String   statusFilter;
  final bool     isTableView;
  final List<String>      rolesPresent;
  final List<SchoolOption> schools;
  final ValueChanged<String>  onSearchChange;
  final ValueChanged<String?> onRole, onSchool;
  final ValueChanged<String>  onStatus;
  final VoidCallback onToggleView, onReset, onAdd;

  bool get _hasFilters =>
      roleFilter != null || schoolFilter != null || statusFilter != 'all';

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
                hintText: 'Rechercher (nom, email, matricule)…',
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
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_add_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Nouvel utilisateur', style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _FilterDropdown<String?>(
            icon: Icons.badge_outlined, label: 'Rôle',
            value: roleFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les rôles')),
              ...rolesPresent.map((r) => DropdownMenuItem(
                  value: r, child: Text(roleLabel(r), overflow: TextOverflow.ellipsis))),
            ],
            onChanged: onRole,
            active: roleFilter != null,
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            icon: Icons.account_balance_outlined, label: 'École',
            value: schoolFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('Toutes les écoles')),
              ...schools.map((s) => DropdownMenuItem(
                  value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: onSchool,
            active: schoolFilter != null,
          ),
          const SizedBox(width: 8),
          _StatusSegment(value: statusFilter, onChanged: onStatus),
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
            color: kSurface, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Icon(isTable ? Icons.grid_view_rounded : Icons.table_rows_rounded,
              size: 18, color: kNavy),
        ),
      ),
    ),
  );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon, required this.label, required this.items,
    required this.value, required this.onChanged, required this.active,
  });
  final IconData icon;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final T value;
  final ValueChanged<T?> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? kNavy.withValues(alpha: 0.06) : kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? kNavy.withValues(alpha: 0.35) : kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        icon: Icon(Icons.expand_more_rounded, size: 14,
            color: active ? kNavy : kTextMuted),
        isExpanded: true,
        style: TextStyle(
          color: active ? kNavy : kTextPrimary,
          fontSize: 12.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String v, String label) {
      final sel = value == v;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : kTextMuted,
          )),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('all', 'Tous'),
        seg('active', 'Actifs'),
        seg('inactive', 'Inactifs'),
      ]),
    );
  }
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

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.users, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit, required this.onPassword,
    required this.onToggle, required this.data,
  });
  final List<AdminUser>  users;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String>    onSort;
  final ValueChanged<AdminUser> onView, onEdit, onPassword, onToggle;
  final AdminUsersData data;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun utilisateur ne correspond à vos filtres.',
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
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort),
          ...users.asMap().entries.map((e) => _TableRow(
            user:       e.value,
            isOdd:      e.key.isOdd,
            data:       data,
            onView:     () => onView(e.value),
            onEdit:     () => onEdit(e.value),
            onPassword: () => onPassword(e.value),
            onToggle:   () => onToggle(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.sortField, required this.sortAsc, required this.onSort});
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;

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
      const SizedBox(width: 42),
      const SizedBox(width: 12),
      _col('NOM / EMAIL',       'name',   flex: 3),
      _col('RÔLE',              'role',   flex: 2),
      _col('ÉCOLE',             'school', flex: 2),
      _col('STATUT',            'status'),
      _col('DERNIÈRE CONNEXION','login',  flex: 2),
      const SizedBox(width: 118,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.user, required this.isOdd, required this.data,
    required this.onView, required this.onEdit, required this.onPassword, required this.onToggle,
  });
  final AdminUser user;
  final bool isOdd;
  final AdminUsersData data;
  final VoidCallback onView, onEdit, onPassword, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hov
              ? kNavy.withValues(alpha: 0.04)
              : widget.isOdd ? kSurface.withValues(alpha: 0.5) : Colors.white,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(u.initials, style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13,
              color: u.isActive ? kNavy : kTextMuted,
            )),
          ),
          const SizedBox(width: 12),
          // Nom + email
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.fullName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            Text(u.email,
                style: const TextStyle(fontSize: 11, color: kTextMuted),
                overflow: TextOverflow.ellipsis),
          ])),
          // Rôle + profil
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _RoleBadge(role: u.role),
            if (u.accessProfileName != null) ...[
              const SizedBox(height: 4),
              _SmallBadge(label: u.accessProfileName!, color: _kPurple, icon: Icons.shield_outlined),
            ],
          ])),
          // École
          Expanded(flex: 2, child: u.schoolName != null
              ? _SmallBadge(label: u.schoolName!, color: _kBlue, icon: Icons.account_balance_outlined)
              : const Text('—', style: TextStyle(color: kTextMuted, fontSize: 12))),
          // Statut
          Expanded(child: Row(children: [
            Icon(
              u.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16, color: u.isActive ? kGreen : kRed,
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(u.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: u.isActive ? kGreen : kRed,
                ), overflow: TextOverflow.ellipsis)),
          ])),
          // Dernière connexion
          Expanded(flex: 2, child: Text(u.lastLoginLabel,
              style: const TextStyle(fontSize: 11.5, color: kTextMuted),
              overflow: TextOverflow.ellipsis)),
          // Actions
          SizedBox(width: 118, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _kBlue, tooltip: 'Voir les détails', onTap: widget.onView),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.edit_rounded, color: kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.key_rounded, color: kAccent, tooltip: 'Réinitialiser le mot de passe', onTap: widget.onPassword),
            const SizedBox(width: 4),
            _ActionBtn(
              icon: u.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
              color: u.isActive ? kRed : kGreen,
              tooltip: u.isActive ? 'Désactiver' : 'Activer',
              onTap: widget.onToggle,
            ),
          ])),
        ]),
      ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'directeur'       => kNavy,
      'enseignant'      => _kBlue,
      'secretaire'      => _kPurple,
      'comptable'       => kAccent,
      'surveillant'     => _kOrange,
      _                 => kTextMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(roleLabel(role), style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w700,
      ), overflow: TextOverflow.ellipsis),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color),
    const SizedBox(width: 4),
    Flexible(child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.users, required this.data, required this.onView,
    required this.onEdit, required this.onPassword, required this.onToggle,
  });
  final List<AdminUser>  users;
  final AdminUsersData   data;
  final ValueChanged<AdminUser> onView, onEdit, onPassword, onToggle;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun utilisateur ne correspond à vos filtres.',
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1200 ? 4 : c.maxWidth >= 800 ? 3 : c.maxWidth >= 560 ? 2 : 1;
      const gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap,
        children: users.map((u) => SizedBox(width: w,
          child: _UserCard(
            user:       u,
            onView:     () => onView(u),
            onEdit:     () => onEdit(u),
            onPassword: () => onPassword(u),
            onToggle:   () => onToggle(u),
          ))).toList(),
      );
    });
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({required this.user, required this.onView, required this.onEdit,
      required this.onPassword, required this.onToggle});
  final AdminUser user;
  final VoidCallback onView, onEdit, onPassword, onToggle;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hov ? kNavy.withValues(alpha: 0.3) : kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
            blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(u.initials, style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14,
                color: u.isActive ? kNavy : kTextMuted,
              )),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
              Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'view')     widget.onView();
                if (v == 'edit')     widget.onEdit();
                if (v == 'password') widget.onPassword();
                if (v == 'toggle')   widget.onToggle();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Row(children: [
                  Icon(Icons.visibility_outlined, size: 18, color: _kBlue), SizedBox(width: 10), Text('Voir les détails'),
                ])),
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: kNavy), SizedBox(width: 10), Text('Modifier'),
                ])),
                const PopupMenuItem(value: 'password', child: Row(children: [
                  Icon(Icons.key_rounded, size: 18, color: kAccent), SizedBox(width: 10), Text('Réinit. mot de passe'),
                ])),
                PopupMenuItem(value: 'toggle', child: Row(children: [
                  Icon(u.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                      size: 18, color: u.isActive ? kRed : kGreen),
                  const SizedBox(width: 10),
                  Text(u.isActive ? 'Désactiver' : 'Activer'),
                ])),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _RoleBadge(role: u.role),
            if (u.schoolName != null)
              AdminBadge(u.schoolName!, color: _kBlue, icon: Icons.account_balance_outlined),
            AdminBadge(
              u.isActive ? 'Actif' : 'Inactif',
              color: u.isActive ? kGreen : kRed,
              icon: u.isActive ? Icons.check_circle : Icons.cancel,
            ),
          ]),
          if (u.lastLogin != null) ...[
            const SizedBox(height: 8),
            Text(u.lastLoginLabel,
                style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        ]),
      ),
      ),
    );
  }
}

// ─── Modal détails utilisateur (style super_admin) ───────────────────────────

Color _userRoleColor(String role) => switch (role) {
  'directeur'  => kNavy,
  'proviseur'  => kNavy,
  'enseignant' => _kBlue,
  'cpe'        => _kPurple,
  'secretaire' => _kPurple,
  'comptable'  => kAccent,
  'surveillant'=> _kOrange,
  'infirmier'  => kGreen,
  'responsable_cantine' => kGreen,
  _            => kTextMuted,
};

IconData _userRoleIcon(String role) => switch (role) {
  'directeur'  => Icons.workspace_premium_rounded,
  'proviseur'  => Icons.workspace_premium_rounded,
  'enseignant' => Icons.menu_book_rounded,
  'cpe'        => Icons.gavel_rounded,
  'secretaire' => Icons.description_rounded,
  'comptable'  => Icons.payments_rounded,
  'surveillant'=> Icons.shield_outlined,
  'infirmier'  => Icons.medical_services_outlined,
  'responsable_cantine' => Icons.restaurant_rounded,
  _            => Icons.person_rounded,
};

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
                'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

String _fmtDateTime(DateTime? d) {
  if (d == null) return 'Jamais';
  return '${_fmtDate(d)} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _UserDetailModal extends StatefulWidget {
  const _UserDetailModal({
    required this.user,
    required this.onEdit,
    required this.onPassword,
    required this.onToggle,
  });
  final AdminUser user;
  final VoidCallback onEdit, onPassword, onToggle;

  @override
  State<_UserDetailModal> createState() => _UserDetailModalState();
}

class _UserDetailModalState extends State<_UserDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
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
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  color: (u.isActive ? kNavy : kTextMuted).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(u.initials, style: TextStyle(
                    color: u.isActive ? kNavy : kTextMuted,
                    fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName, style: const TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _RoleBadge(role: u.role),
                    AdminBadge(u.isActive ? 'Actif' : 'Inactif',
                        color: u.isActive ? kGreen : kRed,
                        icon: u.isActive ? Icons.check_circle : Icons.block_rounded),
                    if (u.schoolName != null)
                      AdminBadge(u.schoolName!, color: _kBlue,
                          icon: Icons.account_balance_outlined),
                    if (u.accessProfileName != null)
                      AdminBadge(u.accessProfileName!, color: _kPurple,
                          icon: Icons.shield_outlined),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.email_outlined, size: 12, color: kTextMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(u.email,
                        style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (u.phone != null && u.phone!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.phone_outlined, size: 12, color: kTextMuted),
                      const SizedBox(width: 3),
                      Text(u.phone!, style: const TextStyle(color: kTextMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.edit_rounded, color: kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                AdminModalIconBtn(icon: Icons.key_rounded, color: kAccent,
                    tooltip: 'Réinitialiser le mot de passe', onTap: widget.onPassword),
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
              labelColor: kNavy,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Rôle & Accès'),
                Tab(text: 'Activité'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _UserInfoTab(user: u),
                _UserAccessTab(user: u),
                _UserActivityTab(user: u),
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
                icon: Icon(u.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(u.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: u.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: u.isActive ? _kOrange : kGreen),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onPassword,
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('Mot de passe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
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

class _UserInfoTab extends StatelessWidget {
  const _UserInfoTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Identité civile'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.badge_outlined, 'Nom complet', u.fullName),
          AdminDetailRow(Icons.wc_rounded, 'Genre', u.genderLabel),
          AdminDetailRow(Icons.cake_outlined, 'Date de naissance',
              u.dateOfBirth != null ? _fmtDate(u.dateOfBirth) : '—'),
          AdminDetailRow(Icons.location_city_outlined, 'Lieu de naissance',
              (u.birthPlace != null && u.birthPlace!.isNotEmpty) ? u.birthPlace! : '—',
              last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.email_outlined, 'Email', u.email),
          AdminDetailRow(Icons.phone_outlined, 'Téléphone',
              (u.phone != null && u.phone!.isNotEmpty) ? u.phone! : '—'),
          AdminDetailRow(Icons.home_outlined, 'Adresse',
              (u.address != null && u.address!.isNotEmpty) ? u.address! : '—',
              last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Identité système'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.tag_rounded, 'Identifiant', u.id, mono: true),
          AdminDetailRow(Icons.confirmation_number_outlined, 'Matricule',
              (u.employeeNumber != null && u.employeeNumber!.isNotEmpty)
                  ? u.employeeNumber! : '—'),
          AdminDetailRow(Icons.calendar_today_outlined, 'Créé le',
              _fmtDate(u.createdAt), last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
            icon: _userRoleIcon(u.role),
            label: u.roleLbl,
            color: _userRoleColor(u.role),
          )),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
            icon: u.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: u.isActive ? 'Actif' : 'Inactif',
            color: u.isActive ? kGreen : kRed,
          )),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
            icon: Icons.account_balance_rounded,
            label: u.schoolName ?? 'Non assigné',
            color: _kBlue,
          )),
        ]),
      ]),
    );
  }
}

class _UserAccessTab extends StatelessWidget {
  const _UserAccessTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final color = _userRoleColor(u.role);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_userRoleIcon(u.role), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.roleLbl, style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('Accès limité à son établissement',
                  style: TextStyle(color: kTextMuted, fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Périmètre d\'accès'),
        const SizedBox(height: 8),
        AdminDetailCard([
          const AdminDetailRow(Icons.shield_rounded, 'Niveau', 'École'),
          AdminDetailRow(Icons.account_balance_outlined, 'Établissement',
              u.schoolName ?? 'Non assigné'),
          AdminDetailRow(Icons.verified_user_outlined, "Profil d'accès",
              u.accessProfileName ?? 'Aucun (rôle par défaut)', last: true),
        ]),
        const SizedBox(height: 18),
        const AdminModalSectionTitle('Statut du compte'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(
              u.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              'État', u.isActive ? 'Compte actif' : 'Compte désactivé',
              valueColor: u.isActive ? kGreen : kRed),
          AdminDetailRow(Icons.login_rounded, 'Dernière connexion',
              _fmtDateTime(u.lastLogin), last: true),
        ]),
      ]),
    );
  }
}

class _UserActivityTab extends StatelessWidget {
  const _UserActivityTab({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _UserTimelineItem(
          icon: Icons.person_add_rounded,
          color: kGreen,
          title: 'Compte créé',
          subtitle: _fmtDate(u.createdAt),
        ),
        if (u.lastLogin != null)
          _UserTimelineItem(
            icon: Icons.login_rounded,
            color: kNavy,
            title: 'Dernière connexion',
            subtitle: _fmtDateTime(u.lastLogin),
          )
        else
          const _UserTimelineItem(
            icon: Icons.login_rounded,
            color: kTextMuted,
            title: 'Aucune connexion enregistrée',
            subtitle: "L'utilisateur ne s'est jamais connecté",
          ),
        if (!u.isActive)
          const _UserTimelineItem(
            icon: Icons.block_rounded,
            color: kRed,
            title: 'Compte actuellement désactivé',
            subtitle: "Accès bloqué — l'utilisateur ne peut pas se connecter",
            last: true,
          )
        else
          const _UserTimelineItem(
            icon: Icons.verified_rounded,
            color: kGreen,
            title: 'Compte opérationnel',
            subtitle: 'Accès autorisé à la plateforme',
            last: true,
          ),
      ],
    );
  }
}

class _UserTimelineItem extends StatelessWidget {
  const _UserTimelineItem({
    required this.icon, required this.color,
    required this.title, required this.subtitle, this.last = false,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        if (!last)
          Expanded(child: Container(width: 2, color: kBorder)),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 18, top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      )),
    ]),
  );
}

// ─── Formulaire création / édition — redesign complet ────────────────────────

String _fmtDob(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

DateTime? _parseDob(String s) {
  final p = s.trim().replaceAll('-', '/').split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  if (y < 1900 || y > DateTime.now().year) return null;
  if (m < 1 || m > 12) return null;
  if (d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, required this.data, this.user});
  final AdminUsersData data;
  final AdminUser? user;

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late final TextEditingController _matricule;
  late final TextEditingController _dob;
  late final TextEditingController _address;
  late final TextEditingController _birthPlace;
  // Volet carrière RH (migration 0023)
  late final TextEditingController _grade;
  late final TextEditingController _echelon;
  late final TextEditingController _category;
  late final TextEditingController _speciality;
  late final TextEditingController _hireDate;
  String? _schoolId;
  String  _role = 'enseignant';
  String? _accessProfileId;
  String? _gender;
  String? _employmentStatus;
  DateTime? _dobDate;
  DateTime? _hireDateD;
  bool    _obscure = true;
  bool    _saving  = false;
  String? _error;

  static const _kEmploymentStatuses = <(String, String)>[
    ('fonctionnaire', 'Fonctionnaire'),
    ('contractuel', 'Contractuel'),
    ('volontaire', 'Volontaire'),
    ('prestataire', 'Prestataire'),
    ('stagiaire', 'Stagiaire'),
    ('benevole', 'Bénévole'),
  ];

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _email      = TextEditingController(text: u?.email ?? '');
    _password   = TextEditingController();
    _first      = TextEditingController(text: u?.firstName ?? '');
    _last       = TextEditingController(text: u?.lastName ?? '');
    _phone      = TextEditingController(text: u?.phone ?? '');
    _matricule  = TextEditingController(text: u?.employeeNumber ?? '');
    _dobDate    = u?.dateOfBirth;
    _dob        = TextEditingController(text: _fmtDob(u?.dateOfBirth));
    _address    = TextEditingController(text: u?.address ?? '');
    _birthPlace = TextEditingController(text: u?.birthPlace ?? '');
    _grade      = TextEditingController(text: u?.grade ?? '');
    _echelon    = TextEditingController(text: u?.echelon ?? '');
    _category   = TextEditingController(text: u?.category ?? '');
    _speciality = TextEditingController(text: u?.speciality ?? '');
    _hireDateD  = u?.hireDate;
    _hireDate   = TextEditingController(text: _fmtDob(u?.hireDate));
    _employmentStatus = u?.employmentStatus;
    _gender     = u?.gender;
    _schoolId   = u?.schoolId ??
        (widget.data.schools.isNotEmpty ? widget.data.schools.first.id : null);
    _role = u?.role ?? 'enseignant';
    _accessProfileId = u?.accessProfileId;
  }

  @override
  void dispose() {
    for (final c in [_email, _password, _first, _last, _phone,
                     _matricule, _dob, _address, _birthPlace,
                     _grade, _echelon, _category, _speciality, _hireDate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dob.text = _fmtDob(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_schoolId == null) {
      setState(() => _error = 'Veuillez sélectionner une école');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final svc = ref.read(adminUsersServiceProvider);
      final dob = _dob.text.trim().isNotEmpty
          ? (_dobDate ?? _parseDob(_dob.text.trim()))
          : null;
      final hire = _hireDate.text.trim().isNotEmpty
          ? (_hireDateD ?? _parseDob(_hireDate.text.trim()))
          : null;
      if (_isEdit) {
        await svc.updateUser(
          id:              widget.user!.id,
          firstName:       _first.text.trim(),
          lastName:        _last.text.trim(),
          schoolId:        _schoolId!,
          role:            _role,
          accessProfileId: _accessProfileId,
          phone:           _phone.text.trim(),
          employeeNumber:  _matricule.text.trim(),
          gender:          _gender,
          dateOfBirth:     dob,
          address:         _address.text.trim(),
          birthPlace:      _birthPlace.text.trim(),
          employmentStatus: _employmentStatus,
          grade:           _grade.text.trim(),
          echelon:         _echelon.text.trim(),
          category:        _category.text.trim(),
          speciality:      _speciality.text.trim(),
          hireDate:        hire,
        );
      } else {
        await svc.createUser(
          email:           _email.text.trim(),
          password:        _password.text,
          firstName:       _first.text.trim(),
          lastName:        _last.text.trim(),
          schoolId:        _schoolId!,
          role:            _role,
          accessProfileId: _accessProfileId,
          phone:           _phone.text.trim(),
          employeeNumber:  _matricule.text.trim(),
          gender:          _gender,
          dateOfBirth:     dob,
          address:         _address.text.trim(),
          birthPlace:      _birthPlace.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'Utilisateur mis à jour' : 'Utilisateur créé avec succès'),
        ));
      }
    } catch (e) {
      setState(() { _error = _clean('$e'); _saving = false; });
    }
  }

  String _clean(String raw) {
    final m = RegExp(r'message: ([^,}]+)').firstMatch(raw);
    return m != null ? m.group(1)!.trim() : raw;
  }

  List<({String value, String label})> get _roleItems {
    final items = [...kStaffRoles];
    if (!items.any((r) => r.value == _role)) {
      items.add((value: _role, label: roleLabel(_role)));
    }
    return items;
  }

  // ── Helpers visuels ──────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(title, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: kTextMuted, letterSpacing: 0.5,
    )),
  );

  InputDecoration _inputDec(String label, IconData icon, {bool readOnly = false}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: kTextMuted),
        filled: true,
        fillColor: readOnly ? kSurface.withValues(alpha: 0.5) : kSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: readOnly
              ? const BorderSide(color: kBorder)
              : const BorderSide(color: kNavy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(12),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
    Widget? suffix,
    VoidCallback? onTap,
    bool readOnly = false,
  }) =>
      TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(fontSize: 13, color: readOnly ? kTextMuted : kTextPrimary),
        decoration: _inputDec(label, icon, readOnly: readOnly).copyWith(suffixIcon: suffix),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Requis' : null;

  Widget _passwordField() => TextFormField(
    controller: _password,
    obscureText: _obscure,
    style: const TextStyle(fontSize: 13, color: kTextPrimary),
    validator: (v) {
      if (v == null || v.isEmpty) return 'Mot de passe requis';
      if (v.length < 6) return 'Au moins 6 caractères';
      return null;
    },
    decoration: _inputDec('Mot de passe *', Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20, color: kTextMuted),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );

  Widget _genderDropdown() => DropdownButtonFormField<String?>(
    initialValue: _gender,
    isExpanded: true,
    decoration: _inputDec('Genre', Icons.wc_rounded),
    items: const [
      DropdownMenuItem(value: null,    child: Text('— Non renseigné')),
      DropdownMenuItem(value: 'M',     child: Text('Masculin')),
      DropdownMenuItem(value: 'F',     child: Text('Féminin')),
      DropdownMenuItem(value: 'autre', child: Text('Autre')),
    ],
    onChanged: (v) => setState(() => _gender = v),
  );

  Widget _dobField() => _field(
    _dob, 'Date de naissance (JJ/MM/AAAA)', Icons.cake_outlined,
    keyboard: TextInputType.datetime,
    suffix: IconButton(
      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: kTextMuted),
      onPressed: _pickDate,
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      if (_parseDob(v) == null) return 'Format JJ/MM/AAAA';
      return null;
    },
  );

  Widget _employmentStatusDropdown() => DropdownButtonFormField<String?>(
    initialValue: _employmentStatus,
    isExpanded: true,
    decoration: _inputDec('Statut', Icons.badge_outlined),
    items: [
      const DropdownMenuItem(value: null, child: Text('— Non renseigné')),
      for (final (v, l) in _kEmploymentStatuses)
        DropdownMenuItem(value: v, child: Text(l)),
    ],
    onChanged: (v) => setState(() => _employmentStatus = v),
  );

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDateD ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
      helpText: 'Date de prise de service',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
    );
    if (picked != null) {
      setState(() {
        _hireDateD = picked;
        _hireDate.text = _fmtDob(picked);
      });
    }
  }

  Widget _hireDateField() => _field(
    _hireDate, 'Prise de service', Icons.event_available_outlined,
    keyboard: TextInputType.datetime,
    suffix: IconButton(
      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: kTextMuted),
      onPressed: _pickHireDate,
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      if (_parseDob(v) == null) return 'Format JJ/MM/AAAA';
      return null;
    },
  );

  Widget _schoolDropdown() => DropdownButtonFormField<String>(
    initialValue: _schoolId,
    isExpanded: true,
    decoration: _inputDec('École *', Icons.account_balance_outlined),
    items: widget.data.schools
        .map((s) => DropdownMenuItem(value: s.id,
            child: Text(s.name, overflow: TextOverflow.ellipsis)))
        .toList(),
    validator: (v) => v == null ? 'École requise' : null,
    onChanged: (v) => setState(() => _schoolId = v),
  );

  Widget _roleDropdown() => DropdownButtonFormField<String>(
    initialValue: _role,
    isExpanded: true,
    decoration: _inputDec('Rôle *', Icons.badge_outlined),
    items: _roleItems
        .map((r) => DropdownMenuItem(value: r.value,
            child: Text(r.label, overflow: TextOverflow.ellipsis)))
        .toList(),
    onChanged: (v) => setState(() => _role = v ?? 'enseignant'),
  );

  Widget _accessProfileDropdown() => DropdownButtonFormField<String?>(
    initialValue: _accessProfileId,
    isExpanded: true,
    decoration: _inputDec("Profil d'accès", Icons.shield_outlined),
    items: [
      const DropdownMenuItem(value: null, child: Text('Aucun (rôle par défaut)')),
      ...widget.data.accessProfiles.map((a) =>
          DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
    ],
    onChanged: (v) => setState(() => _accessProfileId = v),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8),
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── En-tête blanc avec boîte icône navy ──────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2F5A), kNavy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? "Modifier l'utilisateur" : 'Nouvel utilisateur',
                        style: const TextStyle(
                          color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isEdit ? widget.user!.email : 'Compte du personnel scolaire',
                        style: const TextStyle(color: kTextMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: const Icon(Icons.close_rounded, size: 15, color: kTextMuted),
                      ),
                    ),
                  ),
                ]),
              ),
              // ── Corps scrollable ────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Identité civile ──────────────────────────────────
                      _sectionTitle('IDENTITÉ CIVILE'),
                      Row(children: [
                        Expanded(child: _field(_first, 'Prénom *', Icons.person_outline,
                            validator: _req)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_last, 'Nom *', Icons.person_outline,
                            validator: _req)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _genderDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _dobField()),
                      ]),
                      const SizedBox(height: 12),
                      _field(_birthPlace, 'Lieu de naissance', Icons.location_city_outlined),

                      // ── Coordonnées ──────────────────────────────────────
                      _sectionTitle('COORDONNÉES'),
                      _field(_phone, 'Téléphone', Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 12),
                      _field(_address, 'Adresse', Icons.home_outlined,
                          maxLines: 2, keyboard: TextInputType.multiline),

                      // ── Affectation scolaire ─────────────────────────────
                      _sectionTitle('AFFECTATION SCOLAIRE'),
                      _schoolDropdown(),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _roleDropdown()),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_matricule, 'Matricule', Icons.tag_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      _accessProfileDropdown(),

                      // ── Carrière RH (édition : volet migration 0023) ─────
                      if (_isEdit) ...[
                        _sectionTitle('CARRIÈRE'),
                        Row(children: [
                          Expanded(child: _employmentStatusDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _hireDateField()),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(_grade, 'Grade', Icons.workspace_premium_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_echelon, 'Échelon', Icons.stairs_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_category, 'Catégorie', Icons.label_outline)),
                        ]),
                        const SizedBox(height: 12),
                        _field(_speciality, 'Spécialité / discipline', Icons.menu_book_outlined),
                      ],

                      // ── Accès au compte (création uniquement) ────────────
                      if (!_isEdit) ...[
                        _sectionTitle('ACCÈS AU COMPTE'),
                        _field(_email, 'Email *', Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email requis';
                              return v.contains('@') ? null : 'Email invalide';
                            }),
                        const SizedBox(height: 12),
                        _passwordField(),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AdminErrorBanner(message: _error!),
                      ],
                    ]),
                  ),
                ),
              ),
              // ── Pied de page ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Annuler', style: TextStyle(
                          color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: _saving ? null : _submit,
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _saving
                              ? kNavy.withValues(alpha: 0.70)
                              : kNavy,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(
                            color: kNavy.withValues(alpha: 0.30),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_saving)
                            const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          else
                            Icon(
                              _isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _saving
                                ? 'Enregistrement…'
                                : (_isEdit ? 'Enregistrer' : 'Créer le compte'),
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Réinitialisation mot de passe (inchangé) ────────────────────────────────

class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({super.key, required this.user});
  final AdminUser user;

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pwd     = TextEditingController();
  final _confirm = TextEditingController();
  bool    _obscure = true;
  bool    _saving  = false;
  String? _error;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminUsersServiceProvider).resetPassword(widget.user.id, _pwd.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: kGreen,
          content: Text('Mot de passe réinitialisé'),
        ));
      }
    } catch (e) {
      setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: 'Réinitialiser le mot de passe',
              subtitle: widget.user.fullName,
              icon: Icons.key_rounded,
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _pwd,
                    obscureText: _obscure,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 6) return 'Au moins 6 caractères';
                      return null;
                    },
                    decoration: adminInputDecoration('Nouveau mot de passe', icon: Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: kTextMuted),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    validator: (v) => v != _pwd.text ? 'Les mots de passe ne correspondent pas' : null,
                    decoration: adminInputDecoration('Confirmer', icon: Icons.lock_outline),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AdminErrorBanner(message: _error!),
                  ],
                ]),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              submitLabel: 'Réinitialiser',
              submitColor: kAccent,
              submitIcon: Icons.key_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
