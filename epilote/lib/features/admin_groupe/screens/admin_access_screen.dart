import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/admin_access_provider.dart';
import '../../../core/widgets/admin_ui.dart';

// ─── Couleurs locales ─────────────────────────────────────────────────────────
const _kPurple = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF0EA5E9);
const _kOrange = Color(0xFFFF6B35);

// ─── Normalisation des messages d'erreur ──────────────────────────────────────
/// Transforme une exception (souvent un PostgrestException ou Exception
/// applicative) en message lisible par l'utilisateur.
String _friendlyError(Object e) {
  var msg = e.toString();
  // « Exception: ... » → on enlève le préfixe technique.
  if (msg.startsWith('Exception: ')) msg = msg.substring(11);
  final lower = msg.toLowerCase();
  // Violation de clé étrangère (profil encore attribué à des membres).
  if (lower.contains('foreign key') ||
      lower.contains('violates') ||
      lower.contains('fk_profiles_access_profile')) {
    return 'Suppression impossible : ce profil est encore attribué à des '
        'membres. Réattribuez-les depuis la page Utilisateurs, puis réessayez.';
  }
  // Droits insuffisants côté RLS / RPC.
  if (lower.contains('accès refusé') ||
      lower.contains('row-level security') ||
      lower.contains('permission denied')) {
    return "Action refusée : vous n'avez pas les droits requis pour cette "
        'opération.';
  }
  return msg;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminAccessScreen extends ConsumerWidget {
  const AdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: "Profils d'accès",
      child: ref.watch(adminAccessProvider).when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _ShimmerSkeleton(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
            const SizedBox(height: 12),
            Text('Erreur : $e', style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(adminAccessProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (d) => _AccessBody(data: d),
      ),
    );
  }
}

// ─── Body (état filtres + tri + vue) ─────────────────────────────────────────

class _AccessBody extends ConsumerStatefulWidget {
  const _AccessBody({required this.data});
  final AdminAccessData data;

  @override
  ConsumerState<_AccessBody> createState() => _AccessBodyState();
}

class _AccessBodyState extends ConsumerState<_AccessBody> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all | active | inactive
  bool   _isTableView  = true;
  String _sortField    = 'name';
  bool   _sortAsc      = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AccessProfile> _applyFilters(List<AccessProfile> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((p) {
      if (_statusFilter == 'active'   && !p.isActive) return false;
      if (_statusFilter == 'inactive' &&  p.isActive) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q)
          || (p.description?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        int c;
        switch (_sortField) {
          case 'members': c = a.memberCount.compareTo(b.memberCount); break;
          case 'modules': c = a.moduleCount.compareTo(b.moduleCount); break;
          case 'status':  c = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1); break;
          default:        c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return _sortAsc ? c : -c;
      });
  }

  void _openCreate() => showDialog(
        context: context,
        builder: (_) => ProfileWizardDialog(categories: widget.data.categories),
      );

  void _openEdit(AccessProfile p) => showDialog(
        context: context,
        builder: (_) =>
            ProfileWizardDialog(profile: p, categories: widget.data.categories),
      );

  void _openPermissions(AccessProfile p) => showDialog(
        context: context,
        builder: (_) => ProfileWizardDialog(
            profile: p, categories: widget.data.categories, initialStep: 1),
      );

  void _openDetail(AccessProfile p) => showDialog(
        context: context,
        builder: (_) => _ProfileDetailModal(
          profile: p,
          categories: widget.data.categories,
          onEdit:        () { Navigator.of(context).pop(); _openEdit(p); },
          onPermissions: () { Navigator.of(context).pop(); _openPermissions(p); },
          onToggle:      () { Navigator.of(context).pop(); _toggleActive(p); },
          onDelete:      () { Navigator.of(context).pop(); _confirmDelete(p); },
        ),
      );

  Future<void> _toggleActive(AccessProfile p) async {
    try {
      await ref.read(adminAccessServiceProvider).setActive(p.id, !p.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(p.isActive ? 'Profil désactivé' : 'Profil activé'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _confirmDelete(AccessProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteProfileDialog(profile: p),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(adminAccessServiceProvider).deleteProfile(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('Profil « ${p.name} » supprimé'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text(_friendlyError(e)),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data     = widget.data;
    final filtered = _applyFilters(data.profiles);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminAccessProvider.future),
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
                _KpiGrid(data: data),
                const SizedBox(height: 20),
                _FilterBar(
                  contentWidth: w - 48,
                  searchCtrl:   _searchCtrl,
                  statusFilter: _statusFilter,
                  isTableView:  _isTableView,
                  onSearchChange: (_) => setState(() {}),
                  onStatus:     (v) => setState(() => _statusFilter = v),
                  onToggleView: ()  => setState(() => _isTableView = !_isTableView),
                  onReset: () => setState(() {
                    _searchCtrl.clear();
                    _statusFilter = 'all';
                  }),
                  onAdd: _openCreate,
                ),
                const SizedBox(height: 16),
                _ResultHeader(total: data.profiles.length, filtered: filtered.length),
                const SizedBox(height: 12),
                if (data.profiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: AdminEmptyState(
                      icon: Icons.shield_outlined,
                      title: "Aucun profil d'accès",
                      message:
                          'Créez des profils (ex. « Enseignant », « Comptable ») pour contrôler finement ce que chaque membre du personnel peut voir et modifier.',
                      actionLabel: 'Créer un profil',
                      onAction: _openCreate,
                    ),
                  )
                else if (_isTableView)
                  _TableView(
                    profiles:  filtered,
                    sortField: _sortField,
                    sortAsc:   _sortAsc,
                    onSort: (f) => setState(() {
                      if (_sortField == f) { _sortAsc = !_sortAsc; }
                      else { _sortField = f; _sortAsc = true; }
                    }),
                    onView:        _openDetail,
                    onEdit:        _openEdit,
                    onPermissions: _openPermissions,
                    onToggle:      _toggleActive,
                    onDelete:      _confirmDelete,
                  )
                else
                  _CardGrid(
                    profiles:      filtered,
                    onView:        _openDetail,
                    onEdit:        _openEdit,
                    onPermissions: _openPermissions,
                    onToggle:      _toggleActive,
                    onDelete:      _confirmDelete,
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
  final AdminAccessData data;

  @override
  Widget build(BuildContext context) {
    final n        = data.profiles.length;
    final actifs   = data.activeProfiles;
    final inactifs = data.inactiveProfiles;
    final covered  = data.totalCoveredMembers;
    final without  = data.withoutProfile;
    final accessible = data.accessibleModules;
    final totalMods  = data.totalModules;

    final items = [
      _KD(
        label: 'Profils',
        value: '$n',
        sub: '$actifs actifs · $inactifs inactifs',
        icon: Icons.shield_rounded, color: _kPurple,
        progressValue: n > 0 ? actifs / n : 0,
        trend: n > 0 ? '${(actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Actifs',
        value: '$actifs',
        sub: n > 0 ? '${(actifs * 100 / n).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: kGreen,
        progressValue: n > 0 ? actifs / n : 0,
        trend: actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Inactifs',
        value: '$inactifs',
        sub: inactifs > 0 ? '⚠ Profils bloqués' : '✅ Aucun',
        icon: Icons.block_rounded, color: kRed,
        progressValue: n > 0 ? inactifs / n : 0,
        trend: inactifs > 0 ? '⚠ À vérifier' : '✅ OK',
        trendUp: inactifs == 0,
      ),
      _KD(
        label: 'Modules du plan',
        value: '$accessible/$totalMods',
        sub: 'inclus dans votre abonnement',
        icon: Icons.widgets_rounded, color: kNavy,
        progressValue: totalMods > 0 ? accessible / totalMods : 0,
        trend: totalMods > 0 ? '${(accessible * 100 / totalMods).round()}% couverts' : '—',
      ),
      _KD(
        label: 'Membres couverts',
        value: '$covered',
        sub: 'comptes rattachés à un profil',
        icon: Icons.people_rounded, color: _kBlue,
        progressValue: null,
        trend: covered > 0 ? 'Personnel encadré' : 'Aucun rattachement',
        trendUp: covered > 0,
      ),
      _KD(
        label: 'Sans profil attribué',
        value: '$without',
        sub: without > 0 ? 'Membres à configurer' : '✅ Tous rattachés',
        icon: Icons.person_off_rounded, color: _kOrange,
        progressValue: null,
        trend: without > 0 ? '⚠ À traiter' : '✅ Complet',
        trendUp: without == 0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 800 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
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
              color: kCardBg,
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
                        Text(d.label, style: TextStyle(
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
                    Row(children: [
                      if (d.progressValue != null)
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.progressValue!.clamp(0.0, 1.0),
                            backgroundColor: d.color.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                                d.color.withValues(alpha: _hov ? 1.0 : 0.75)),
                            minHeight: 4,
                          ),
                        ))
                      else
                        const Spacer(),
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
        ...List.generate(6, (_) => Column(children: [
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
    required this.statusFilter,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String statusFilter;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String> onStatus;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChange,
            decoration: InputDecoration(
              hintText: 'Rechercher un profil (nom, description)…',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: kTextMuted, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: kTextMuted),
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
        _StatusSegment(value: statusFilter, onChanged: onStatus),
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
                child: Icon(Icons.refresh_rounded, size: 20, color: kTextMuted),
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
                gradient: const LinearGradient(colors: [Color(0xFF6D28D9), _kPurple]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Nouveau', style: TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
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
    Text('$filtered profil${filtered > 1 ? 's' : ''}',
        style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: kTextMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.profiles, required this.sortField, required this.sortAsc,
    required this.onSort, required this.onView, required this.onEdit,
    required this.onPermissions, required this.onToggle, required this.onDelete,
  });
  final List<AccessProfile> profiles;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String>        onSort;
  final ValueChanged<AccessProfile> onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun profil ne correspond à vos filtres.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
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
          ...profiles.asMap().entries.map((e) => _TableRow(
            profile:       e.value,
            isOdd:         e.key.isOdd,
            onView:        () => onView(e.value),
            onEdit:        () => onEdit(e.value),
            onPermissions: () => onPermissions(e.value),
            onToggle:      () => onToggle(e.value),
            onDelete:      () => onDelete(e.value),
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
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
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
      _col('PROFIL',   'name',    flex: 4),
      _col('MEMBRES',  'members', flex: 2),
      _col('MODULES',  'modules', flex: 2),
      _col('STATUT',   'status',  flex: 2),
      SizedBox(width: 118,
          child: Text('ACTIONS', textAlign: TextAlign.end,
              style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.profile, required this.isOdd,
    required this.onView, required this.onEdit, required this.onPermissions,
    required this.onToggle, required this.onDelete,
  });
  final AccessProfile profile;
  final bool isOdd;
  final VoidCallback onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
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
              : widget.isOdd ? kSurface.withValues(alpha: 0.5) : kCardBg,
          border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.shield_rounded, size: 20,
                color: p.isActive ? _kPurple : kTextMuted),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            Text(p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                style: TextStyle(fontSize: 11, color: kTextMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.people_outline_rounded, size: 14, color: kNavy),
            const SizedBox(width: 5),
            Text('${p.memberCount}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.widgets_outlined, size: 14, color: kGreen),
            const SizedBox(width: 5),
            Text('${p.moduleCount}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(p.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16, color: p.isActive ? kGreen : kRed),
            const SizedBox(width: 5),
            Flexible(child: Text(p.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: p.isActive ? kGreen : kRed),
                overflow: TextOverflow.ellipsis)),
          ])),
          SizedBox(width: 118, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.tune_rounded, color: _kPurple,
                tooltip: 'Permissions', onTap: widget.onPermissions),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.edit_rounded, color: kNavy,
                tooltip: 'Modifier', onTap: widget.onEdit),
            const SizedBox(width: 2),
            _RowMenu(
              isActive: p.isActive,
              onView:   widget.onView,
              onToggle: widget.onToggle,
              onDelete: widget.onDelete,
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

/// Menu « overflow » d'une ligne de tableau : actions secondaires
/// (détails, activation, suppression) regroupées pour ne pas surcharger.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.isActive,
    required this.onView,
    required this.onToggle,
    required this.onDelete,
  });
  final bool isActive;
  final VoidCallback onView, onToggle, onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: "Plus d'actions",
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: kTextMuted),
        padding: EdgeInsets.zero,
        splashRadius: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (v) {
          switch (v) {
            case 'view':   onView();   break;
            case 'toggle': onToggle(); break;
            case 'delete': onDelete(); break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Row(children: [
            Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
            SizedBox(width: 10), Text('Voir les détails'),
          ])),
          PopupMenuItem(value: 'toggle', child: Row(children: [
            Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                size: 18, color: isActive ? _kOrange : kGreen),
            const SizedBox(width: 10),
            Text(isActive ? 'Désactiver' : 'Activer'),
          ])),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
            const SizedBox(width: 10),
            Text('Supprimer', style: TextStyle(color: kRed)),
          ])),
        ],
      );
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.profiles, required this.onView,
    required this.onEdit, required this.onPermissions, required this.onToggle,
    required this.onDelete,
  });
  final List<AccessProfile> profiles;
  final ValueChanged<AccessProfile> onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun profil ne correspond à vos filtres.',
      );
    }
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 720 ? 2 : 1;
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap,
        children: profiles.map((p) => SizedBox(width: w,
          child: _ProfileCard(
            profile:       p,
            onView:        () => onView(p),
            onEdit:        () => onEdit(p),
            onPermissions: () => onPermissions(p),
            onToggle:      () => onToggle(p),
            onDelete:      () => onDelete(p),
          ))).toList(),
      );
    });
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile, required this.onView,
    required this.onEdit, required this.onPermissions, required this.onToggle,
    required this.onDelete,
  });
  final AccessProfile profile;
  final VoidCallback onView, onEdit, onPermissions, onToggle, onDelete;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hov ? _kPurple.withValues(alpha: 0.3) : kBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
              blurRadius: _hov ? 12 : 4, offset: Offset(0, _hov ? 4 : 2),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: p.isActive ? _kPurple : kTextMuted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.shield_rounded,
                          color: p.isActive ? _kPurple : kTextMuted, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary))),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: kTextMuted, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (v) {
                        if (v == 'view')        widget.onView();
                        if (v == 'permissions') widget.onPermissions();
                        if (v == 'edit')        widget.onEdit();
                        if (v == 'toggle')      widget.onToggle();
                        if (v == 'delete')      widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'view', child: Row(children: [
                          Icon(Icons.visibility_outlined, size: 18, color: _kBlue),
                          SizedBox(width: 10), Text('Voir les détails'),
                        ])),
                        const PopupMenuItem(value: 'permissions', child: Row(children: [
                          Icon(Icons.tune_rounded, size: 18, color: _kPurple),
                          SizedBox(width: 10), Text('Permissions'),
                        ])),
                        PopupMenuItem(value: 'edit', child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18, color: kNavy),
                          const SizedBox(width: 10), const Text('Modifier les infos'),
                        ])),
                        PopupMenuItem(value: 'toggle', child: Row(children: [
                          Icon(p.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                              size: 18, color: p.isActive ? _kOrange : kGreen),
                          const SizedBox(width: 10),
                          Text(p.isActive ? 'Désactiver' : 'Activer'),
                        ])),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'delete', child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                          const SizedBox(width: 10),
                          Text('Supprimer', style: TextStyle(color: kRed)),
                        ])),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    AdminBadge('${p.memberCount} membre${p.memberCount > 1 ? 's' : ''}',
                        color: kNavy, icon: Icons.people_outline_rounded),
                    AdminBadge('${p.moduleCount} module${p.moduleCount > 1 ? 's' : ''}',
                        color: kGreen, icon: Icons.widgets_outlined),
                    AdminBadge(p.isActive ? 'Actif' : 'Inactif',
                        color: p.isActive ? kGreen : kRed,
                        icon: p.isActive ? Icons.check_circle : Icons.cancel),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onPermissions,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Configurer les permissions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kPurple,
                        side: BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Confirmation de suppression ──────────────────────────────────────────────
class _DeleteProfileDialog extends ConsumerStatefulWidget {
  const _DeleteProfileDialog({required this.profile});
  final AccessProfile profile;

  @override
  ConsumerState<_DeleteProfileDialog> createState() => _DeleteProfileDialogState();
}

class _DeleteProfileDialogState extends ConsumerState<_DeleteProfileDialog> {
  late Future<int> _membersF;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // On revérifie en direct le nombre de membres rattachés : le compteur
    // affiché dans la liste peut être obsolète (filtre is_active) et la FK
    // refuse la suppression d'un profil encore attribué.
    _membersF = ref.read(adminAccessServiceProvider).countMembers(widget.profile.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.delete_outline_rounded, color: kRed, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Supprimer le profil ?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: FutureBuilder<int>(
              future: _membersF,
              builder: (context, snap) {
                final loading = snap.connectionState == ConnectionState.waiting;
                final attached = snap.data ?? 0;
                final blocked = attached > 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(text: TextSpan(
                      style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5),
                      children: [
                        const TextSpan(text: 'Le profil '),
                        TextSpan(text: '« ${p.name} »',
                            style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                        const TextSpan(text: ' et toutes ses permissions seront '
                            'définitivement supprimés. Cette action est irréversible.'),
                      ],
                    )),
                    const SizedBox(height: 14),
                    if (loading)
                      Row(children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
                        const SizedBox(width: 10),
                        Text('Vérification des membres rattachés…',
                            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                      ])
                    else if (snap.hasError)
                      AdminErrorBanner(message: _friendlyError(snap.error!))
                    else if (blocked)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '$attached membre${attached > 1 ? 's sont' : ' est'} encore '
                            'rattaché${attached > 1 ? 's' : ''} à ce profil. Réattribuez-'
                            '${attached > 1 ? 'les' : 'le'} depuis la page Utilisateurs '
                            'avant de pouvoir le supprimer.',
                            style: TextStyle(fontSize: 12, color: kTextPrimary, height: 1.4),
                          )),
                        ]),
                      ),
                  ],
                );
              },
            ),
          ),
          // Pied
          Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<int>(
              future: _membersF,
              builder: (context, snap) {
                final ready = snap.connectionState == ConnectionState.done && !snap.hasError;
                final blocked = (snap.data ?? 0) > 0;
                final canDelete = ready && !blocked && !_deleting;
                return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
                    child: Text('Annuler', style: TextStyle(color: kTextMuted)),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: canDelete
                        ? () {
                            setState(() => _deleting = true);
                            Navigator.of(context).pop(true);
                          }
                        : null,
                    icon: _deleting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kRed.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Confirmation : profil sans aucune permission ─────────────────────────────
class _ConfirmEmptyPermsDialog extends StatelessWidget {
  const _ConfirmEmptyPermsDialog({required this.isEdit});
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.lock_open_rounded, color: _kOrange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Aucune permission accordée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              "Ce profil n'autorisera l'accès à aucun module. Les membres qui en "
              'héritent ne pourront rien voir ni faire. Voulez-vous continuer '
              'malgré tout ?',
              style: TextStyle(fontSize: 13.5, color: kTextMuted, height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Revenir aux permissions',
                    style: TextStyle(color: kTextMuted)),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEdit ? 'Enregistrer quand même' : 'Créer quand même'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Modal détails profil (style super_admin) ─────────────────────────────────

class _ProfileDetailModal extends ConsumerStatefulWidget {
  const _ProfileDetailModal({
    required this.profile,
    required this.categories,
    required this.onEdit,
    required this.onPermissions,
    required this.onToggle,
    required this.onDelete,
  });
  final AccessProfile profile;
  final List<ModuleCategory> categories;
  final VoidCallback onEdit, onPermissions, onToggle, onDelete;

  @override
  ConsumerState<_ProfileDetailModal> createState() => _ProfileDetailModalState();
}

class _ProfileDetailModalState extends ConsumerState<_ProfileDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

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
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  color: (p.isActive ? _kPurple : kTextMuted).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.shield_rounded,
                    color: p.isActive ? _kPurple : kTextMuted, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(
                      color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    AdminBadge(p.isActive ? 'Actif' : 'Inactif',
                        color: p.isActive ? kGreen : kRed,
                        icon: p.isActive ? Icons.check_circle : Icons.block_rounded),
                    AdminBadge('${p.memberCount} membre${p.memberCount > 1 ? 's' : ''}',
                        color: kNavy, icon: Icons.people_outline_rounded),
                    AdminBadge('${p.moduleCount} module${p.moduleCount > 1 ? 's' : ''}',
                        color: kGreen, icon: Icons.widgets_outlined),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    p.description?.isNotEmpty == true ? p.description! : 'Aucune description',
                    style: TextStyle(color: kTextMuted, fontSize: 11.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                AdminModalIconBtn(icon: Icons.tune_rounded, color: _kPurple,
                    tooltip: 'Permissions', onTap: widget.onPermissions),
                const SizedBox(width: 4),
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
              labelColor: kNavy,
              unselectedLabelColor: kTextMuted,
              indicatorColor: kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Permissions'),
              ],
            ),
          ),
          // ─ Content ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProfileInfoTab(profile: p),
                _ProfilePermsTab(
                  profile: p,
                  categories: widget.categories,
                  onConfigure: widget.onPermissions,
                ),
              ],
            ),
          ),
          // ─ Footer ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              Tooltip(
                message: 'Supprimer ce profil',
                child: OutlinedButton(
                  onPressed: widget.onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: BorderSide(color: kRed.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(p.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(p.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.isActive ? _kOrange : kGreen,
                  side: BorderSide(color: p.isActive ? _kOrange : kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onPermissions,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Permissions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
                ),
              ),
              const SizedBox(width: 10),
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

class _ProfileInfoTab extends StatelessWidget {
  const _ProfileInfoTab({required this.profile});
  final AccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminModalSectionTitle('Profil'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.label_outline, 'Nom', p.name),
          AdminDetailRow(Icons.notes_rounded, 'Description',
              p.description?.isNotEmpty == true ? p.description! : '—'),
          AdminDetailRow(
              p.isActive ? Icons.check_circle_outline : Icons.block_outlined,
              'Statut', p.isActive ? 'Actif' : 'Inactif',
              valueColor: p.isActive ? kGreen : kRed, last: true),
        ]),
        const SizedBox(height: 14),
        const AdminModalSectionTitle('Couverture'),
        const SizedBox(height: 8),
        AdminDetailCard([
          AdminDetailRow(Icons.people_outline_rounded, 'Membres rattachés',
              '${p.memberCount}'),
          AdminDetailRow(Icons.widgets_outlined, 'Modules autorisés',
              '${p.moduleCount}'),
          AdminDetailRow(Icons.tag_rounded, 'Identifiant', p.id, mono: true, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AdminMetaChip(
              icon: Icons.people_rounded, label: '${p.memberCount} membres', color: kNavy)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: Icons.widgets_rounded, label: '${p.moduleCount} modules', color: kGreen)),
          const SizedBox(width: 8),
          Expanded(child: AdminMetaChip(
              icon: p.isActive ? Icons.verified_rounded : Icons.block_rounded,
              label: p.isActive ? 'Actif' : 'Inactif',
              color: p.isActive ? kGreen : kRed)),
        ]),
        if (p.memberCount == 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kOrange.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: _kOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Aucun membre n'utilise encore ce profil. "
                'Attribuez-le depuis la page Utilisateurs.',
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.4),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ProfilePermsTab extends ConsumerWidget {
  const _ProfilePermsTab({
    required this.profile,
    required this.categories,
    required this.onConfigure,
  });
  final AccessProfile profile;
  final List<ModuleCategory> categories;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(accessProfilePermsProvider(profile.id));
    return permsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: kNavy)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: kTextMuted),
            const SizedBox(height: 12),
            Text('Impossible de charger les permissions.\n${_friendlyError(e)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(accessProfilePermsProvider(profile.id)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
      ),
      data: (perms) {
        final granted = perms.entries.where((e) => !e.value.isEmpty).toList();
        if (granted.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: AdminEmptyState(
              icon: Icons.lock_open_rounded,
              title: 'Aucune permission définie',
              message: "Ce profil n'a encore aucun accès. "
                  'Configurez ses permissions pour autoriser des modules.',
              actionLabel: 'Configurer les permissions',
              onAction: onConfigure,
            ),
          );
        }
        // moduleId → (catégorie, module)
        final moduleNames = <String, ({String cat, ModuleInfo mod})>{};
        for (final c in categories) {
          for (final m in c.modules) {
            moduleNames[m.id] = (cat: c.name, mod: m);
          }
        }
        // Regrouper par catégorie
        final byCat = <String, List<MapEntry<String, PermRow>>>{};
        for (final e in granted) {
          final cat = moduleNames[e.key]?.cat ?? 'Autres';
          byCat.putIfAbsent(cat, () => []).add(e);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in byCat.entries) ...[
              AdminModalSectionTitle(entry.key),
              const SizedBox(height: 8),
              ...entry.value.map((e) {
                final info = moduleNames[e.key];
                return _PermSummaryRow(
                  icon: info?.mod.icon ?? '📦',
                  name: info?.mod.name ?? 'Module',
                  row: e.value,
                );
              }),
              const SizedBox(height: 14),
            ],
          ]),
        );
      },
    );
  }
}

class _PermSummaryRow extends StatelessWidget {
  const _PermSummaryRow({required this.icon, required this.name, required this.row});
  final String icon;
  final String name;
  final PermRow row;

  @override
  Widget build(BuildContext context) {
    // Affiche uniquement les actions ACCORDÉES, avec mise en évidence orange
    // pour les actions sensibles (suppression, export, import, validation…).
    Widget flag(String label, bool on, bool sensitive) {
      final accent = sensitive ? _kOrange : _kPurple;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(sensitive ? Icons.warning_amber_rounded : Icons.check_rounded,
              size: 12, color: accent),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: accent)),
        ]),
      );
    }

    // (label, accordé, sensible) — seules les actions actives sont rendues.
    final flags = <Widget>[
      if (row.canRead)     flag('Voir',       true, false),
      if (row.canCreate)   flag('Créer',      true, false),
      if (row.canUpdate)   flag('Modifier',   true, false),
      if (row.canDelete)   flag('Supprimer',  true, true),
      if (row.canExport)   flag('Exporter',   true, true),
      if (row.canImport)   flag('Importer',   true, true),
      if (row.canValidate) flag('Valider',    true, true),
      if (row.canApprove)  flag('Approuver',  true, true),
      if (row.canManage)   flag('Paramètres', true, true),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(name,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary))),
          AdminBadge(
            row.dataScope == 'own_classes' ? 'Ses classes' : "Toute l'école",
            color: kNavy, icon: Icons.visibility_outlined,
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: flags),
      ]),
    );
  }
}

// ─── Catalogue des 9 actions ─────────────────────────────────────────────────
class _ActionDef {
  const _ActionDef(this.key, this.label, this.icon, this.sensitive);
  final String key, label;
  final IconData icon;
  final bool sensitive; // action à risque → mise en évidence (orange + ⚠)
}

const _kActions = <_ActionDef>[
  _ActionDef('read',     'Voir',       Icons.visibility_outlined,     false),
  _ActionDef('create',   'Créer',      Icons.add_circle_outline,      false),
  _ActionDef('update',   'Modifier',   Icons.edit_outlined,           false),
  _ActionDef('delete',   'Supprimer',  Icons.delete_outline_rounded,  true),
  _ActionDef('export',   'Exporter',   Icons.download_rounded,        true),
  _ActionDef('import',   'Importer',   Icons.upload_rounded,          true),
  _ActionDef('validate', 'Valider',    Icons.fact_check_outlined,     true),
  _ActionDef('approve',  'Approuver',  Icons.verified_outlined,       true),
  _ActionDef('manage',   'Paramètres', Icons.settings_outlined,       true),
];

bool _permGet(PermRow r, String k) {
  switch (k) {
    case 'read':     return r.canRead;
    case 'create':   return r.canCreate;
    case 'update':   return r.canUpdate;
    case 'delete':   return r.canDelete;
    case 'export':   return r.canExport;
    case 'import':   return r.canImport;
    case 'validate': return r.canValidate;
    case 'approve':  return r.canApprove;
    default:         return r.canManage;
  }
}

PermRow _permSet(PermRow r, String k, bool v) {
  switch (k) {
    case 'read':     return r.copyWith(canRead: v);
    case 'create':   return r.copyWith(canCreate: v, canRead: v ? true : r.canRead);
    case 'update':   return r.copyWith(canUpdate: v, canRead: v ? true : r.canRead);
    case 'delete':   return r.copyWith(canDelete: v, canRead: v ? true : r.canRead);
    case 'export':   return r.copyWith(canExport: v, canRead: v ? true : r.canRead);
    case 'import':   return r.copyWith(canImport: v, canRead: v ? true : r.canRead);
    case 'validate': return r.copyWith(canValidate: v, canRead: v ? true : r.canRead);
    case 'approve':  return r.copyWith(canApprove: v, canRead: v ? true : r.canRead);
    default:         return r.copyWith(canManage: v, canRead: v ? true : r.canRead);
  }
}

// ─── Droits par défaut (modèle de profil standard) ───────────────────────────
class _Grant {
  const _Grant({
    this.read = false, this.create = false, this.update = false, this.delete = false,
    this.export = false, this.import = false, this.validate = false,
    this.approve = false, this.manage = false, this.scope = 'own_school',
  });
  final bool read, create, update, delete, export, import, validate, approve, manage;
  final String scope;

  PermRow toRow() => PermRow(
        canRead: read, canCreate: create, canUpdate: update, canDelete: delete,
        canExport: export, canImport: import, canValidate: validate,
        canApprove: approve, canManage: manage, dataScope: scope,
      );

  // Raccourcis sémantiques
  static _Grant full({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, delete: true, export: true,
      import: true, validate: true, approve: true, manage: true, scope: scope);
  static _Grant manageData({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, delete: true, export: true,
      import: true, scope: scope);
  static _Grant contribute({String scope = 'own_school'}) =>
      _Grant(read: true, create: true, update: true, scope: scope);
  static _Grant teach({String scope = 'own_classes'}) =>
      _Grant(read: true, create: true, update: true, export: true, scope: scope);
  static _Grant financial({String scope = 'own_school'}) => _Grant(
      read: true, create: true, update: true, export: true, import: true,
      validate: true, scope: scope);
  static _Grant readExport({String scope = 'own_school'}) =>
      _Grant(read: true, export: true, scope: scope);
  static _Grant readOnly({String scope = 'own_school'}) =>
      _Grant(read: true, scope: scope);
}

class _Preset {
  const _Preset({
    required this.roleType, required this.label, required this.name,
    required this.description, required this.icon, required this.color,
    this.categories = const {}, this.modules = const {},
  });
  final String roleType, label, name, description;
  final IconData icon;
  final Color color;
  final Map<String, _Grant> categories; // slug catégorie → droits
  final Map<String, _Grant> modules;     // slug module → droits (priorité)

  _Grant? grantFor(String catSlug, String modSlug) =>
      modules[modSlug] ?? categories[catSlug];
}

final _kPresets = <_Preset>[
  _Preset(
    roleType: 'proviseur', label: 'Proviseur',
    name: 'Proviseur', icon: Icons.account_balance_rounded,
    color: const Color(0xFF4F46E5),
    description: 'Chef d\'établissement (lycée). Autorité complète sur l\'ensemble des modules de l\'école.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','vie-scolaire','finance','rh'])
        c: _Grant.full(),
    },
  ),
  _Preset(
    roleType: 'directeur', label: 'Directeur',
    name: 'Directeur', icon: Icons.manage_accounts_rounded,
    color: const Color(0xFF1D4ED8),
    description: 'Chef d\'établissement (collège / école professionnelle). Gestion complète de l\'école.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','vie-scolaire','finance','rh'])
        c: _Grant.full(),
    },
  ),
  _Preset(
    roleType: 'directeur_etudes', label: 'Directeur des Études',
    name: 'Directeur des Études (D.E)', icon: Icons.menu_book_rounded,
    color: const Color(0xFF0D9488),
    description: 'Pilotage pédagogique : programmes, évaluations, bulletins, conseils de classe.',
    categories: {
      'scolarite': _Grant.manageData(),
      'enseignement': _Grant.full(),
      'evaluation': _Grant.full(),
      'vie-scolaire': _Grant.contribute(),
    },
  ),
  _Preset(
    roleType: 'chef_travaux', label: 'Chef des Travaux',
    name: 'Chef des Travaux (C.T)', icon: Icons.engineering_rounded,
    color: const Color(0xFFB45309),
    description: 'Coordination de l\'enseignement technique : matières, emplois du temps, programmes.',
    categories: {
      'scolarite': _Grant.readExport(),
      'enseignement': _Grant.teach(scope: 'own_school'),
      'evaluation': _Grant.teach(scope: 'own_school'),
      'rh': _Grant.readOnly(),
    },
    modules: {
      'matieres': _Grant.manageData(),
      'emploi-du-temps': _Grant.manageData(),
      'programmes': _Grant.manageData(),
    },
  ),
  _Preset(
    roleType: 'secretaire', label: 'Secrétaire',
    name: 'Secrétaire', icon: Icons.edit_document,
    color: const Color(0xFF7C3AED),
    description: 'Dossiers élèves, inscriptions, documents administratifs et messagerie.',
    categories: {
      'scolarite': _Grant.manageData(),
      'enseignement': _Grant.readExport(),
      'evaluation': _Grant.readExport(),
      'vie-scolaire': _Grant.readOnly(),
    },
  ),
  _Preset(
    roleType: 'comptable', label: 'Comptable',
    name: 'Comptable', icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xFFD97706),
    description: 'Paiements, facturation, budgets, dépenses et comptabilité. Validation financière.',
    categories: {
      'finance': _Grant.financial(),
      'scolarite': _Grant.readOnly(),
    },
  ),
  _Preset(
    roleType: 'enseignant', label: 'Enseignant',
    name: 'Enseignant', icon: Icons.school_rounded,
    color: const Color(0xFF059669),
    description: 'Notes, cahier de textes, évaluations et présences de ses classes uniquement.',
    categories: {
      'enseignement': _Grant.teach(),
      'evaluation': _Grant.teach(),
      'scolarite': _Grant.readOnly(scope: 'own_classes'),
      'vie-scolaire': _Grant.readOnly(scope: 'own_classes'),
    },
  ),
  _Preset(
    roleType: 'surveillant', label: 'Surveillant',
    name: 'Surveillant', icon: Icons.security_rounded,
    color: const Color(0xFFDC2626),
    description: 'Présences, discipline, infirmerie, cantine et vie scolaire au quotidien.',
    categories: {
      'vie-scolaire': _Grant.manageData(),
      'scolarite': _Grant.readOnly(),
    },
    modules: {
      'presences-eleves': _Grant.contribute(),
    },
  ),
  _Preset(
    roleType: 'consultant', label: 'Consultant',
    name: 'Consultant', icon: Icons.insights_rounded,
    color: const Color(0xFF475569),
    description: 'Observateur / analyste : lecture et export de tous les modules, sans modification.',
    categories: {
      for (final c in const ['scolarite','enseignement','evaluation','vie-scolaire','finance','rh'])
        c: _Grant.readExport(),
    },
  ),
  const _Preset(
    roleType: 'autre', label: 'Autre',
    name: '', icon: Icons.tune_rounded,
    color: Color(0xFF64748B),
    description: 'Profil personnalisé : partez d\'une page vierge et choisissez chaque droit manuellement.',
  ),
];

// ─── Assistant profil unifié (identité + permissions) ───────────────────────
class ProfileWizardDialog extends ConsumerStatefulWidget {
  const ProfileWizardDialog({
    super.key,
    this.profile,
    required this.categories,
    this.initialStep = 0,
  });
  final AccessProfile? profile;
  final List<ModuleCategory> categories;
  final int initialStep;

  @override
  ConsumerState<ProfileWizardDialog> createState() => _ProfileWizardDialogState();
}

class _ProfileWizardDialogState extends ConsumerState<ProfileWizardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  final _search = TextEditingController();

  late int _step; // 0 = identité, 1 = permissions
  String? _roleType;
  String? _selectedPreset;
  final Map<String, PermRow> _edits = {};
  final Set<String> _collapsed = {};
  bool _permsLoaded = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile?.name ?? '');
    _desc = TextEditingController(text: widget.profile?.description ?? '');
    _roleType = widget.profile?.roleType;
    _step = _isEdit ? widget.initialStep.clamp(0, 1) : 0;
    if (!_isEdit) _permsLoaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _search.dispose();
    super.dispose();
  }

  PermRow _rowFor(String moduleId) => _edits[moduleId] ?? const PermRow();
  void _update(String moduleId, PermRow row) {
    setState(() {
      if (row.isEmpty) {
        _edits.remove(moduleId);
      } else {
        _edits[moduleId] = row;
      }
    });
  }

  int get _grantedCount => _edits.values.where((r) => !r.isEmpty).length;
  int get _sensitiveCount =>
      _edits.values.fold<int>(0, (s, r) => s + r.sensitiveCount);

  void _applyPreset(_Preset p) {
    final next = <String, PermRow>{};
    for (final cat in widget.categories) {
      for (final m in cat.modules) {
        if (!m.accessible) continue; // hors plan : jamais accordé
        final g = p.grantFor(cat.slug, m.slug);
        if (g != null) next[m.id] = g.toRow();
      }
    }
    setState(() {
      _edits
        ..clear()
        ..addAll(next);
      _roleType = p.roleType;
      _selectedPreset = p.roleType;
    });
    if (p.name.isNotEmpty) _name.text = p.name;
    _desc.text = p.description;
  }

  void _bulkCategory(ModuleCategory cat, {required bool grant}) {
    setState(() {
      for (final m in cat.modules) {
        if (!m.accessible) continue;
        if (grant) {
          _edits[m.id] = _rowFor(m.id).copyWith(canRead: true);
        } else {
          _edits.remove(m.id);
        }
      }
    });
  }

  Future<void> _submit() async {
    // À l'étape Permissions, le Form de l'étape Identité est démonté :
    // _formKey.currentState est alors null. On valide donc directement le
    // contenu du champ Nom (seul champ requis) au lieu de l'état du Form,
    // sinon la soumission renverrait toujours en arrière sans rien enregistrer.
    if (_name.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Le nom du profil est requis.';
      });
      // Laisse le Form se reconstruire avant de déclencher sa validation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
      return;
    }

    // Garde-fou : un profil sans aucune permission n'a aucun accès.
    final perms = <Map<String, dynamic>>[];
    _edits.forEach((mid, row) {
      if (!row.isEmpty) perms.add(row.toJson(mid));
    });
    if (perms.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmEmptyPermsDialog(isEdit: _isEdit),
      );
      if (proceed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = ref.read(adminAccessServiceProvider);
      String id;
      if (_isEdit) {
        id = widget.profile!.id;
        await svc.updateProfile(
          id: id,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          roleType: _roleType,
        );
      } else {
        id = await svc.createProfile(
          name: _name.text.trim(),
          description: _desc.text.trim(),
          roleType: _roleType,
        );
      }
      await svc.savePermissions(id, perms);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(_isEdit ? 'Profil mis à jour' : 'Profil créé'),
        ));
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
        // En cas d'échec de validation du formulaire (nom manquant), on est
        // déjà à l'étape 0 ; sinon on garde l'étape courante pour réessayer.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;
    Widget? footer;

    if (_isEdit && !_permsLoaded) {
      final async = ref.watch(accessProfilePermsProvider(widget.profile!.id));
      if (async.hasError) {
        body = Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: kTextMuted),
              const SizedBox(height: 14),
              Text('Impossible de charger les permissions du profil.\n'
                  '${_friendlyError(async.error!)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextMuted,
                    side: BorderSide(color: kBorder),
                  ),
                  child: const Text('Fermer'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(accessProfilePermsProvider(widget.profile!.id)),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPurple, foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ]),
          ),
        );
      } else if (async.hasValue) {
        _edits.addAll(async.value ?? const {});
        _permsLoaded = true;
      }
    }

    if (_permsLoaded) {
      body = _step == 0 ? _buildIdentity() : _buildPermissions();
      footer = _buildFooter();
    }
    body ??= SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(color: kNavy)));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 860),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildHeader(),
          Flexible(child: body),
          ?footer,
        ]),
      ),
    );
  }

  // ── En-tête + indicateur d'étape ───────────────────────────────────────────
  Widget _buildHeader() {
    Widget stepDot(int i, String label, IconData icon) {
      final active = _step == i;
      final done = _step > i;
      final color = active || done ? _kPurple : kTextMuted;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active
                ? _kPurple
                : done
                    ? _kPurple.withValues(alpha: 0.12)
                    : kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: active ? _kPurple : kBorder),
          ),
          child: Icon(done ? Icons.check_rounded : icon,
              size: 14, color: active ? Colors.white : color),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? kTextPrimary : kTextMuted)),
      ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded, color: _kPurple, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isEdit ? 'Modifier le profil' : "Nouveau profil d'accès",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            stepDot(0, 'Identité', Icons.badge_outlined),
            Container(
                width: 22, height: 1.4, color: kBorder,
                margin: const EdgeInsets.symmetric(horizontal: 8)),
            stepDot(1, 'Permissions', Icons.tune_rounded),
          ]),
        ])),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, size: 20, color: kTextMuted),
          tooltip: 'Fermer',
        ),
      ]),
    );
  }

  // ── Étape 1 : Identité ─────────────────────────────────────────────────────
  Widget _buildIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Form(
        key: _formKey,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: _kPurple),
                const SizedBox(width: 6),
                Text('Modèles de profil',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('pré-remplit nom, type et droits',
                      style: TextStyle(
                          fontSize: 10, color: _kPurple, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _kPresets)
                  _PresetChip(
                    preset: p,
                    selected: _selectedPreset == p.roleType,
                    onTap: () => _applyPreset(p),
                  ),
              ]),
              const SizedBox(height: 18),
              Divider(color: kBorder, height: 1),
              const SizedBox(height: 18),
              Text('Nom du profil *',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                decoration: adminInputDecoration(
                    'Ex : Proviseur, Comptable, Enseignant…',
                    icon: Icons.label_outline),
              ),
              const SizedBox(height: 14),
              Text('Type de profil',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _roleType,
                isExpanded: true,
                decoration: adminInputDecoration('Choisir un type…',
                    icon: Icons.workspace_premium_outlined),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Non spécifié —')),
                  for (final p in _kPresets)
                    DropdownMenuItem(
                        value: p.roleType,
                        child: Row(children: [
                          Icon(p.icon, size: 16, color: p.color),
                          const SizedBox(width: 8),
                          Text(p.label),
                        ])),
                ],
                onChanged: (v) => setState(() => _roleType = v),
              ),
              const SizedBox(height: 14),
              Text('Description',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: adminInputDecoration(
                    'Décrivez les responsabilités et le périmètre de ce profil…',
                    icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kNavy.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: kNavy.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    'À l\'étape suivante, choisissez précisément les modules accessibles '
                    'et les actions autorisées (voir, créer, modifier, supprimer, exporter…).',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.5),
                  )),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AdminErrorBanner(message: _error!),
              ],
              const SizedBox(height: 6),
            ]),
      ),
    );
  }

  // ── Étape 2 : Permissions ──────────────────────────────────────────────────
  Widget _buildPermissions() {
    final q = _search.text.trim().toLowerCase();
    List<ModuleInfo> visibleMods(ModuleCategory c) => q.isEmpty
        ? c.modules
        : c.modules
            .where((m) => m.name.toLowerCase().contains(q))
            .toList();

    final cats = widget.categories
        .where((c) => visibleMods(c).isNotEmpty)
        .toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Barre outils : recherche + résumé
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un module…',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: kTextMuted, size: 19),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 17, color: kTextMuted),
                          onPressed: () => setState(() => _search.clear()))
                      : null,
                  filled: true,
                  fillColor: kCardBg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AdminBadge('$_grantedCount module${_grantedCount > 1 ? 's' : ''}',
              color: _kPurple, icon: Icons.widgets_rounded),
          const SizedBox(width: 8),
          AdminBadge('$_sensitiveCount sensible${_sensitiveCount > 1 ? 's' : ''}',
              color: _sensitiveCount > 0 ? _kOrange : kTextMuted,
              icon: Icons.warning_amber_rounded),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _MatrixLegend(),
            const SizedBox(height: 12),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text('Aucun module ne correspond à la recherche.',
                        style: TextStyle(color: kTextMuted))),
              )
            else
              for (final cat in cats)
                _MatrixCategory(
                  category: cat,
                  modules: visibleMods(cat),
                  collapsed: _collapsed.contains(cat.id),
                  rowFor: _rowFor,
                  onUpdate: _update,
                  onToggleCollapse: () => setState(() {
                    if (!_collapsed.add(cat.id)) _collapsed.remove(cat.id);
                  }),
                  onGrantAll: () => _bulkCategory(cat, grant: true),
                  onClearAll: () => _bulkCategory(cat, grant: false),
                ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AdminErrorBanner(message: _error!),
            ],
          ]),
        ),
      ),
    ]);
  }

  // ── Pied de page ────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        if (_step == 1)
          OutlinedButton.icon(
            onPressed: _saving ? null : () => setState(() => _step = 0),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Identité'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextMuted,
              side: BorderSide(color: kBorder),
            ),
          )
        else
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextMuted,
              side: BorderSide(color: kBorder),
            ),
            child: const Text('Annuler'),
          ),
        const Spacer(),
        if (_step == 0)
          ElevatedButton.icon(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() => _step = 1);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Suivant : Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_isEdit ? Icons.save_rounded : Icons.check_rounded, size: 16),
            label: Text(_isEdit ? 'Enregistrer' : 'Créer le profil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
          ),
      ]),
    );
  }
}

// ─── Chip modèle de profil ────────────────────────────────────────────────────
class _PresetChip extends StatefulWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t   = widget.preset;
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: t.description,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel
                  ? t.color.withValues(alpha: 0.12)
                  : _hov ? t.color.withValues(alpha: 0.06) : kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel
                    ? t.color.withValues(alpha: 0.55)
                    : _hov ? t.color.withValues(alpha: 0.3) : kBorder,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.icon, size: 14, color: sel ? t.color : kTextMuted),
              const SizedBox(width: 6),
              Text(t.label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: sel ? t.color : kTextMuted,
              )),
              if (sel) ...[
                const SizedBox(width: 5),
                Icon(Icons.check_rounded, size: 12, color: t.color),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Matrice de permissions (étape 2 de l'assistant) ────────────────────────
class _MatrixLegend extends StatelessWidget {
  const _MatrixLegend();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            'Activez les actions autorisées par module. Cocher une action active '
            'automatiquement « Voir ». La portée définit si le membre voit toute '
            'l\'école ou seulement ses classes. Les modules « Hors plan » ne font '
            'pas partie de votre abonnement et ne peuvent pas être accordés.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
          ),
        ),
        const SizedBox(width: 12),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: 13, color: _kOrange),
            SizedBox(width: 4),
            Text('action sensible',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kOrange)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 13, color: kTextMuted),
            const SizedBox(width: 4),
            Text('hors plan',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kTextMuted)),
          ]),
        ]),
      ]),
    );
  }
}

class _MatrixCategory extends StatelessWidget {
  const _MatrixCategory({
    required this.category,
    required this.modules,
    required this.collapsed,
    required this.rowFor,
    required this.onUpdate,
    required this.onToggleCollapse,
    required this.onGrantAll,
    required this.onClearAll,
  });
  final ModuleCategory category;
  final List<ModuleInfo> modules;
  final bool collapsed;
  final PermRow Function(String) rowFor;
  final void Function(String, PermRow) onUpdate;
  final VoidCallback onToggleCollapse, onGrantAll, onClearAll;

  @override
  Widget build(BuildContext context) {
    final accessibleCount = modules.where((m) => m.accessible).length;
    final grantedCount = modules.where((m) => !rowFor(m.id).isEmpty).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(children: [
              Icon(
                  collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: kTextMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(category.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: kNavy,
                        letterSpacing: 0.4)),
              ),
              const SizedBox(width: 8),
              if (grantedCount > 0)
                AdminBadge('$grantedCount/$accessibleCount',
                    color: _kPurple, icon: Icons.check_rounded),
              const Spacer(),
              _MiniBtn(
                  label: 'Tout voir',
                  icon: Icons.visibility_outlined,
                  onTap: onGrantAll),
              const SizedBox(width: 6),
              _MiniBtn(
                  label: 'Effacer', icon: Icons.clear_rounded, onTap: onClearAll),
            ]),
          ),
        ),
        if (!collapsed) ...[
          Divider(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              for (final m in modules)
                _MatrixModuleRow(
                    module: m,
                    row: rowFor(m.id),
                    onChanged: (r) => onUpdate(m.id, r)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: kTextMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted)),
            ]),
          ),
        ),
      );
}

class _MatrixModuleRow extends StatelessWidget {
  const _MatrixModuleRow(
      {required this.module, required this.row, required this.onChanged});
  final ModuleInfo module;
  final PermRow row;
  final ValueChanged<PermRow> onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = !module.accessible;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(module.icon ?? '📦', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(module.name,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            if (locked)
              AdminBadge('Hors plan',
                  color: kTextMuted, icon: Icons.lock_outline)
            else if (row.sensitiveCount > 0)
              AdminBadge(
                  '${row.sensitiveCount} sensible${row.sensitiveCount > 1 ? 's' : ''}',
                  color: _kOrange,
                  icon: Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final a in _kActions)
                _ActionToggle(
                  def: a,
                  active: _permGet(row, a.key),
                  enabled: !locked,
                  onTap: () =>
                      onChanged(_permSet(row, a.key, !_permGet(row, a.key))),
                ),
              const SizedBox(width: 4),
              _ScopeDropdown(
                value: row.dataScope,
                enabled: !locked && !row.isEmpty,
                onChanged: (v) => onChanged(row.copyWith(dataScope: v)),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _ActionToggle extends StatelessWidget {
  const _ActionToggle(
      {required this.def,
      required this.active,
      required this.enabled,
      required this.onTap});
  final _ActionDef def;
  final bool active, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = def.sensitive ? _kOrange : _kPurple;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.12) : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? accent.withValues(alpha: 0.55) : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(def.icon, size: 13, color: active ? accent : kTextMuted),
          const SizedBox(width: 5),
          Text(def.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : kTextMuted)),
          if (def.sensitive) ...[
            const SizedBox(width: 3),
            Icon(Icons.warning_amber_rounded,
                size: 11,
                color:
                    active ? accent : kTextMuted.withValues(alpha: 0.6)),
          ],
        ]),
      ),
    );
  }
}

class _ScopeDropdown extends StatelessWidget {
  const _ScopeDropdown({required this.value, required this.enabled, required this.onChanged});
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: kTextMuted),
          style: TextStyle(fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'own_school', child: Text('Toute l\'école')),
            DropdownMenuItem(value: 'own_classes', child: Text('Ses classes')),
          ],
          onChanged: enabled ? (v) => onChanged(v ?? 'own_school') : null,
        ),
      ),
    );
  }
}
