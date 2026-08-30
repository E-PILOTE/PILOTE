import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/widgets/app_shell.dart';
import '../../../core/utils/media_compression.dart';
import '../providers/school_groups_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animated_button/flutter_animated_button.dart';
import '../services/group_pdf_service.dart';
import '../widgets/plan_change_notice.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/constants/tutelle.dart';

// Le formulaire de groupe vit dans ses propres fichiers : cet écran dépassait
// 3 600 lignes et le modal en pesait 511 à lui seul. `part` plutôt que des
// fichiers autonomes parce qu'ils s'appuient sur les jetons et les petits
// widgets privés (`_FormLabel`, `_LogoUploadBox`, `_inputDeco`) déclarés ici.
part 'groups/group_form_modal.dart';
part 'groups/group_tutelle_selector.dart';
part 'groups/group_form_footer.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kRed     = Color(0xFFEF4444);
Color get _kSurface => kSurface;
Color get _kBg => kCardBg;
Color get _kBorder => kBorder;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;

// ─── Écran principal ──────────────────────────────────────────────────────────

class SchoolGroupsScreen extends ConsumerWidget {
  const SchoolGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Groupes Scolaires',
      child: _GroupsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _GroupsBody extends ConsumerStatefulWidget {
  const _GroupsBody();
  @override
  ConsumerState<_GroupsBody> createState() => _GroupsBodyState();
}

class _GroupsBodyState extends ConsumerState<_GroupsBody> {
  // Filtres
  final _searchCtrl  = TextEditingController();
  String  _filterStatus = 'tous';
  String  _filterType   = 'tous';
  String  _filterPlan   = 'tous';
  String  _filterDept   = 'tous';
  // Vue
  bool    _isTableView  = true;
  // Tri (table)
  String  _sortField    = 'createdAt';
  bool    _sortAsc      = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GroupDetail> _applyFilters(List<GroupDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((g) {
      if (q.isNotEmpty) {
        final match = g.name.toLowerCase().contains(q)
            || g.adminEmail.toLowerCase().contains(q)
            || (g.department?.toLowerCase().contains(q) ?? false)
            || g.planName.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_filterStatus != 'tous' && g.subscriptionStatus != _filterStatus) return false;
      if (_filterType   != 'tous' && g.groupType          != _filterType  ) return false;
      if (_filterPlan   != 'tous' && g.planName           != _filterPlan  ) return false;
      if (_filterDept   != 'tous' && (g.department ?? '') != _filterDept  ) return false;
      return true;
    }).toList()..sort((a, b) {
      int c;
      switch (_sortField) {
        case 'name':       c = a.name.compareTo(b.name);                 break;
        case 'status':     c = a.subscriptionStatus.compareTo(b.subscriptionStatus); break;
        case 'plan':       c = a.planName.compareTo(b.planName);         break;
        case 'schools':    c = a.schoolCount.compareTo(b.schoolCount);   break;
        case 'endDate':
          final ae = a.subscriptionEnd, be = b.subscriptionEnd;
          if (ae == null && be == null) {
            c = 0;
          } else if (ae == null) {
            c = 1;
          } else if (be == null) {
            c = -1;
          } else {
            c = ae.compareTo(be);
          }
          break;
        default:           c = a.createdAt.compareTo(b.createdAt);
      }
      return _sortAsc ? c : -c;
    });
  }

  void _openCreate(SchoolGroupsData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupFormModal(plans: data.plans, onSaved: () {
        ref.invalidate(schoolGroupsProvider);
      }),
    );
  }

  void _openDetail(GroupDetail g, SchoolGroupsData data) {
    showDialog(
      context: context,
      builder: (_) => _GroupDetailModal(
        group: g,
        plans: data.plans,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(g, data);
        },
        onToggleActive: () async {
          await _toggleActive(g);
          if (mounted) Navigator.pop(context);
        },
        onDelete: () async {
          Navigator.pop(context);
          await _confirmDelete(g);
        },
        onPrint: () => _printGroup(g),
      ),
    );
  }

  void _openEdit(GroupDetail g, SchoolGroupsData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupFormModal(
        plans:    data.plans,
        existing: g,
        onSaved:  () => ref.invalidate(schoolGroupsProvider),
      ),
    );
  }

  Future<void> _toggleActive(GroupDetail g) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('school_groups')
          .update({'is_active': !g.isActive}).eq('id', g.id);
      ref.invalidate(schoolGroupsProvider);
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  Future<void> _confirmDelete(GroupDetail g) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(group: g),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_school_group', params: {'p_group_id': g.id});
      ref.invalidate(schoolGroupsProvider);
      if (mounted) _showSuccess('Groupe "${g.name}" supprimé définitivement.');
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  void _printGroup(GroupDetail g) {
    showDialog(
      context: context,
      builder: (_) => _PrintPreviewModal(group: g),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolGroupsProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error:   (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(schoolGroupsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(SchoolGroupsData data) {
    final filtered = _applyFilters(data.groups);

    return LayoutBuilder(builder: (context, constraints) {
      // Garantir une largeur finie même si le parent donne des contraintes
      // non bornées lors d'une transition d'état Riverpod.
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 300;

      return SingleChildScrollView(
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── KPI premium grid ───────────────────────────────────────────
              _KpiGrid(data: data),
              const SizedBox(height: 20),

              // ── Barre de filtres ────────────────────────────────────────────
              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                filterStatus:   _filterStatus,
                filterType:     _filterType,
                filterPlan:     _filterPlan,
                filterDept:     _filterDept,
                departments:    data.departments,
                planNames:      data.plans.map((p) => p.name).toList(),
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onType:         (v) => setState(() => _filterType   = v),
                onPlan:         (v) => setState(() => _filterPlan   = v),
                onDept:         (v) => setState(() => _filterDept   = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterStatus = _filterType = _filterPlan = _filterDept = 'tous';
                }),
                onAdd: () => _openCreate(data),
              ),
              const SizedBox(height: 16),

              // ── Résultat ────────────────────────────────────────────────────
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),

              // ── Vue principale ──────────────────────────────────────────────
              if (_isTableView)
                _TableView(
                  groups:    filtered,
                  sortField: _sortField,
                  sortAsc:   _sortAsc,
                  onSort: (f) => setState(() {
                    if (_sortField == f) {
                      _sortAsc = !_sortAsc;
                    } else {
                      _sortField = f;
                      _sortAsc = true;
                    }
                  }),
                  onDetail: (g) => _openDetail(g, data),
                  onEdit:   (g) => _openEdit(g, data),
                  onDelete: (g) => _confirmDelete(g),
                  onPrint:  (g) => _printGroup(g),
                )
              else
                _CardGrid(
                  groups:   filtered,
                  onDetail: (g) => _openDetail(g, data),
                  onEdit:   (g) => _openEdit(g, data),
                  onDelete: (g) => _confirmDelete(g),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid premium — 6 cartes en grille 3×2 ───────────────────────────────

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
  final SchoolGroupsData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Groupes',  value: '${data.total}',
        sub:   '${data.actifs} actifs · ${data.enEssai} essai',
        icon:  Icons.school_rounded,          color: _kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Actifs',         value: '${data.actifs}',
        sub:   n > 0 ? '${(data.actifs * 100 / n).round()}% du total' : '—',
        icon:  Icons.check_circle_rounded,    color: _kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Opérationnels' : '—',
      ),
      _KD(
        label: 'Revenus/mois',   value: _fmtXaf(data.revenusTotal),
        sub:   'FCFA · abonnements actifs',
        icon:  Icons.payments_rounded,        color: _kGold,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0
            ? '${data.actifs} payant${data.actifs > 1 ? "s" : ""}' : '0 payant',
      ),
      _KD(
        label: 'Expirant 30j',   value: '${data.expirantBientot}',
        sub:   data.expirantBientot > 0 ? '⚠ Action requise' : '✅ À jour',
        icon:  Icons.timer_rounded,           color: _kOrange,
        progressValue: n > 0 ? data.expirantBientot / n : 0,
        trend: data.expirantBientot > 0 ? '⚠ Urgent' : '✅ Aucun',
        trendUp: data.expirantBientot == 0,
      ),
      _KD(
        label: 'En essai',       value: '${data.enEssai}',
        sub:   'Période gratuite',
        icon:  Icons.hourglass_top_rounded,   color: _kPurple,
        progressValue: n > 0 ? data.enEssai / n : 0,
        trend: data.enEssai > 0 ? 'À convertir' : 'Aucun',
        trendUp: false,
      ),
      _KD(
        label: 'Suspendus',      value: '${data.suspendus}',
        sub:   data.suspendus > 0 ? 'Impayés / bloqués' : '✅ Aucun',
        icon:  Icons.pause_circle_rounded,    color: _kRed,
        progressValue: n > 0 ? data.suspendus / n : 0,
        trend: data.suspendus > 0 ? '⚠ Débloquer' : '✅ OK',
        trendUp: data.suspendus == 0,
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
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
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
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hov ? _kBorder : _kBorder,
                width: 1,
              ),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                blurRadius: _hov ? 12 : 4,
                offset: Offset(0, _hov ? 4 : 2),
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Bande accent colorée en haut ──────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [d.color, d.color.withValues(alpha: _hov ? 0.9 : 0.4)],
                  )),
                ),
                // ── Corps de la carte ─────────────────────────────────────
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
                          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
                        ), overflow: TextOverflow.ellipsis),
                        if (d.sub != null)
                          Text(d.sub!, style: TextStyle(
                            color: d.color.withValues(alpha: 0.70), fontSize: 10,
                          ), overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 10),
                      // Icône en haut à droite
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Icon(d.icon, color: d.color, size: 18),
                      ),
                    ]),
                    const Spacer(),
                    // ── Barre de progression + tendance ──────────────────
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

// ─── Shimmer Skeleton (chargement initial) ────────────────────────────────────

class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
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
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterStatus,
    required this.filterType,
    required this.filterPlan,
    required this.filterDept,
    required this.departments,
    required this.planNames,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onType,
    required this.onPlan,
    required this.onDept,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String  filterStatus, filterType, filterPlan, filterDept;
  final List<String> departments, planNames;
  final bool    isTableView;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String> onStatus, onType, onPlan, onDept;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
    // SizedBox avec largeur explicite pour garantir des contraintes bornées
    // même si le parent transmet une largeur infinie (transition Riverpod).
    return SizedBox(
      width: contentWidth,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ─ Ligne 1 : Search + Toggle vue + Bouton créer ───────────────────────
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChange,
              decoration: InputDecoration(
                hintText: 'Rechercher un groupe, email, département…',
                hintStyle: TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: _kMuted),
                        onPressed: () { searchCtrl.clear(); onSearchChange(''); })
                    : null,
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Toggle table/cards
          _ToggleViewBtn(isTable: isTableView, onToggle: onToggleView),
          const SizedBox(width: 8),
          // Reset filtres
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
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Créer groupe
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Nouveau groupe', style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // ─ Filtres dropdowns ─────────────────────────────────────────────────
        Row(children: [
          _FilterDropdown(
            icon: Icons.radio_button_checked_rounded,
            label: 'Statut',
            items: const {
              'tous': 'Tous les statuts',
              'active': 'Actif',
              'trial': 'Essai',
              'suspended': 'Suspendu',
              'cancelled': 'Résilié',
            },
            value: filterStatus,
            onChanged: onStatus,
            active: filterStatus != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.business_rounded,
            label: 'Type',
            items: const {
              'tous': 'Tous les types',
              'public': 'Public',
              'prive': 'Privé',
              'catholique': 'Catholique',
              'islamique': 'Islamique',
              'protestant': 'Protestant',
            },
            value: filterType,
            onChanged: onType,
            active: filterType != 'tous',
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            icon: Icons.inventory_2_rounded,
            label: 'Plan',
            items: {
              'tous': 'Tous les plans',
              for (final p in planNames) p: p,
            },
            value: filterPlan,
            onChanged: onPlan,
            active: filterPlan != 'tous',
          ),
          if (departments.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.location_on_rounded,
              label: 'Département',
              items: {
                'tous': 'Tous',
                for (final d in departments) d: d,
              },
              value: filterDept,
              onChanged: onDept,
              active: filterDept != 'tous',
            ),
          ],
          const Spacer(),
          if (filterStatus != 'tous' || filterType != 'tous' ||
              filterPlan != 'tous' || filterDept != 'tous')
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
      ),  // Container
    );    // SizedBox
  }
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
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
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
    Text('$filtered résultat${filtered > 1 ? 's' : ''}',
        style: TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.groups,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });

  final List<GroupDetail> groups;
  final String sortField;
  final bool   sortAsc;
  final ValueChanged<String> onSort;
  final ValueChanged<GroupDetail> onDetail, onEdit, onDelete, onPrint;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const _EmptyState();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          // En-tête
          _TableHeader(sortField: sortField, sortAsc: sortAsc, onSort: onSort),
          // Lignes
          ...groups.asMap().entries.map((e) => _TableRow(
            group:    e.value,
            isOdd:    e.key.isOdd,
            onTap:    () => onDetail(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onPrint:  () => onPrint(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortField, required this.sortAsc, required this.onSort});
  final String sortField;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  Widget _col(String label, String field, {double? flex}) => Expanded(
    flex: (flex ?? 1).toInt(),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSort(field),
        child: Row(children: [
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w700))),
          const SizedBox(width: 4),
          Icon(
            sortField == field
                ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 13,
            color: sortField == field ? _kNavy : _kMuted,
          ),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: _kSurface,
    child: Row(children: [
      const SizedBox(width: 38),
      const SizedBox(width: 12),
      _col('NOM DU GROUPE',   'name',    flex: 3),
      _col('DÉPARTEMENT',     'dept'),
      _col('TYPE',            'type'),
      _col('PLAN',            'plan'),
      _col('STATUT',          'status'),
      _col('ÉCOLES',          'schools'),
      _col('FIN ABO.',        'endDate'),
      const SizedBox(width: 92),
    ]),
  );
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.group,
    required this.isOdd,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
  });
  final GroupDetail group;
  final bool isOdd;
  final VoidCallback onTap, onEdit, onDelete, onPrint;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _hovered
                ? _kNavy.withValues(alpha: 0.04)
                : widget.isOdd
                    ? _kSurface.withValues(alpha: 0.5)
                    : _kBg,
            border: Border(
              bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(children: [
            // Avatar avec logo réel
            _GroupAvatar(name: g.name, size: 38, logoUrl: g.logoUrl),
            const SizedBox(width: 12),
            // Nom + email
            Expanded(flex: 3, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: TextStyle(
                    color: _kText, fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(g.adminEmail, style: TextStyle(
                    color: _kMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            // Département
            Expanded(child: Text(g.department ?? '—',
                style: TextStyle(color: _kText, fontSize: 12.5),
                overflow: TextOverflow.ellipsis)),
            // Type
            Expanded(child: _TypeBadge(type: g.groupType, label: g.groupTypeLabel)),
            // Plan
            Expanded(child: _PlanBadge(plan: g.planName, price: g.priceXaf)),
            // Statut
            Expanded(child: _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel)),
            // Écoles
            Expanded(child: Row(children: [
              Text('${g.schoolCount}', style: TextStyle(
                  color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
              if (g.maxSchools > 0) Text(' / ${g.maxSchools}',
                  style: TextStyle(color: _kMuted, fontSize: 11)),
            ])),
            // Fin abonnement
            Expanded(child: g.subscriptionEnd != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!),
                        style: TextStyle(
                          color: g.expiresBientot ? _kOrange : _kText,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                    if (g.expiresBientot)
                      const Text('Expire bientôt',
                          style: TextStyle(color: _kOrange, fontSize: 10)),
                  ])
                : Text('—', style: TextStyle(color: _kMuted))),
            // Actions
            SizedBox(
              width: 92,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _ActionBtn(icon: Icons.edit_rounded, color: _kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.print_rounded, color: _kMuted,
                    tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.delete_rounded, color: _kRed,
                    tooltip: 'Supprimer', onTap: widget.onDelete),
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
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
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

// ─── Vue Cartes ───────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.groups,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GroupDetail> groups;
  final ValueChanged<GroupDetail> onDetail, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemCount: groups.length,
      itemBuilder: (_, i) => _GroupCard(
        group:    groups[i],
        onDetail: () => onDetail(groups[i]),
        onEdit:   () => onEdit(groups[i]),
        onDelete: () => onDelete(groups[i]),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });
  final GroupDetail group;
  final VoidCallback onDetail, onEdit, onDelete;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? _kNavy.withValues(alpha: 0.4) : _kBorder,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: _kNavy.withValues(alpha: 0.08),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─ Header ─────────────────────────────────────────────────────────
            Row(children: [
              _GroupAvatar(name: g.name, size: 40),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: TextStyle(
                      color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  Text(g.department ?? '—',
                      style: TextStyle(color: _kMuted, fontSize: 11)),
                ],
              )),
              _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel),
            ]),
            const SizedBox(height: 12),

            // ─ Badges ─────────────────────────────────────────────────────────
            Wrap(spacing: 6, runSpacing: 4, children: [
              _TypeBadge(type: g.groupType, label: g.groupTypeLabel),
              _TutelleBadge(tutelle: g.tutelle),
              _PlanBadge(plan: g.planName, price: g.priceXaf),
            ]),
            const SizedBox(height: 10),

            // ─ Stats ──────────────────────────────────────────────────────────
            Row(children: [
              _CardStat(icon: Icons.business_rounded, label: '${g.schoolCount} école${g.schoolCount > 1 ? 's' : ''}'),
              const SizedBox(width: 14),
              if (g.subscriptionEnd != null)
                _CardStat(
                  icon: Icons.event_rounded,
                  label: DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!),
                  color: g.expiresBientot ? _kOrange : _kMuted,
                ),
            ]),

            const Spacer(),

            // ─ Actions ────────────────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kNavy),
              ),
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _kRed),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  _CardStat({required this.icon, required this.label, Color? color}) : color = color ?? _kMuted;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: color, fontSize: 11.5,
        fontWeight: FontWeight.w600)),
  ]);
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name, this.size = 38, this.logoUrl});
  final String  name;
  final double  size;
  final String? logoUrl;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange, const Color(0xFF0EA5E9)];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get _color => _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.startsWith('http');
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasLogo ? _kBorder : _color.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Center(child: Text(_initials,
                style: TextStyle(color: _color,
                    fontSize: size * 0.37, fontWeight: FontWeight.w800))),
              errorWidget: (_, _, _) => Center(child: Text(_initials,
                style: TextStyle(color: _color,
                    fontSize: size * 0.37, fontWeight: FontWeight.w800))),
            )
          : Center(child: Text(_initials, style: TextStyle(
              color: _color, fontSize: size * 0.37, fontWeight: FontWeight.w800,
            ))),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});
  final String status, label;

  Color get _color => switch (status) {
    'active'    => _kGreen,
    'trial'     => _kPurple,
    'suspended' => _kOrange,
    'cancelled' => _kRed,
    _           => _kMuted,
  };

  IconData get _icon => switch (status) {
    'active'    => Icons.check_circle_rounded,
    'trial'     => Icons.hourglass_top_rounded,
    'suspended' => Icons.pause_circle_rounded,
    'cancelled' => Icons.cancel_rounded,
    _           => Icons.help_rounded,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 11, color: _color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.label});
  final String type, label;

  Color get _color => switch (type) {
    'public'     => _kNavy,
    'prive'      => _kGold,
    'catholique' => _kOrange,
    'islamique'  => _kGreen,
    _            => _kMuted,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
        color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

/// Pastille du ministère de tutelle.
///
/// ⚠️ Elle NE DISPARAÎT PAS quand la tutelle manque : elle affiche « Sans
/// ministère » en rouge. Une pastille absente se confond avec un écran qui n'en
/// affiche pas ; une pastille qui dit le manque se voit dans une liste de
/// mille groupes, et c'est le seul endroit où la lacune peut encore être
/// corrigée avant qu'elle ne bloque une inscription à un examen d'État.
class _TutelleBadge extends StatelessWidget {
  const _TutelleBadge({required this.tutelle});
  final String? tutelle;

  @override
  Widget build(BuildContext context) {
    final connue = tutelleConnue(tutelle);
    final couleur = connue ? couleurTutelle(tutelle) : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: connue ? null : Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!connue) ...[
          Icon(Icons.error_outline_rounded, size: 11, color: couleur),
          const SizedBox(width: 4),
        ],
        Text(
          connue ? sigleTutelle(tutelle)! : 'Sans ministère',
          style: TextStyle(
              color: couleur, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan, required this.price});
  final String plan;
  final int price;

  Color get _color => switch (plan) {
    'Gratuit'       => _kMuted,
    'Premium'       => _kGold,
    'Pro'           => _kNavy,
    'Institutionnel' => _kPurple,
    _               => _kMuted,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _color.withValues(alpha: 0.2)),
    ),
    child: Text(plan, style: TextStyle(
        color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.school_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun groupe trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau groupe.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Modal Détails ────────────────────────────────────────────────────────────

class _GroupDetailModal extends StatefulWidget {
  const _GroupDetailModal({
    required this.group,
    required this.plans,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onPrint,
  });
  final GroupDetail      group;
  final List<PlanInfo>   plans;
  final VoidCallback     onEdit, onToggleActive, onDelete, onPrint;

  @override
  State<_GroupDetailModal> createState() => _GroupDetailModalState();
}

class _GroupDetailModalState extends State<_GroupDetailModal>
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
    final g = widget.group;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ─ Header propre ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Logo carré arrondi
              Container(
                width: 66, height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                  color: _kSurface,
                ),
                clipBehavior: Clip.antiAlias,
                child: (g.logoUrl != null && g.logoUrl!.startsWith('http'))
                    ? CachedNetworkImage(
                        imageUrl: g.logoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _SquareInitials(name: g.name, size: 66),
                      )
                    : _SquareInitials(name: g.name, size: 66),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _StatusBadge(status: g.subscriptionStatus,
                        label: g.statusLabel),
                    _TypeBadge(type: g.groupType, label: g.groupTypeLabel),
                    _TutelleBadge(tutelle: g.tutelle),
                    _PlanBadge(plan: g.planName, price: g.priceXaf),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.email_outlined, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(g.adminEmail,
                        style: TextStyle(color: _kMuted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)),
                    if (g.department != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined,
                          size: 12, color: _kMuted),
                      const SizedBox(width: 3),
                      Text(g.department!,
                          style: TextStyle(
                              color: _kMuted, fontSize: 11.5)),
                    ],
                    if (g.foundedYear != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.history_edu_outlined,
                          size: 12, color: _kMuted),
                      const SizedBox(width: 3),
                      Text('Fondé en ${g.foundedYear}',
                          style: TextStyle(
                              color: _kMuted, fontSize: 11.5)),
                    ],
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              // Boutons d'action
              Row(children: [
                _ModalIconBtn(
                    icon: Icons.edit_rounded,
                    color: _kNavy,
                    tooltip: 'Modifier',
                    onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.print_rounded,
                    color: _kMuted,
                    tooltip: 'Imprimer',
                    onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(
                    icon: Icons.close_rounded,
                    color: _kMuted,
                    tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),

          // ─ Tabs ──────────────────────────────────────────────────────────────
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Abonnement'),
                Tab(text: 'Activité'),
              ],
            ),
          ),

          // ─ Tab content ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _InfoTab(group: g),
                _SubscriptionTab(group: g),
                _ActivityTab(group: g),
              ],
            ),
          ),

          // ─ Footer actions ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggleActive,
                icon: Icon(
                  g.isActive ? Icons.block_rounded : Icons.check_rounded,
                  size: 16,
                ),
                label: Text(g.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: g.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: g.isActive ? _kOrange : _kGreen),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_rounded, size: 16),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.email_outlined, 'Email', g.adminEmail),
          _DetailRow(Icons.phone_outlined, 'Téléphone', g.phone ?? '—'),
          _DetailRow(Icons.location_on_outlined, 'Département', g.department ?? '—'),
          _DetailRow(Icons.home_outlined, 'Adresse', g.address ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        const _SectionTitle('Paramètres'),
        const SizedBox(height: 8),
        _DetailCard([
          _DetailRow(Icons.business_outlined, 'Type', g.groupTypeLabel),
          // « Non renseignée » plutôt qu'un tiret : l'absence de tutelle est
          // une lacune à combler, pas une case vide sans conséquence — un
          // groupe sans ministère ne remonte dans aucun état ministériel.
          _DetailRow(Icons.account_balance_outlined, 'Tutelle',
              g.tutelleLabel ?? 'Non renseignée'),
          if (g.foundedYear != null)
            _DetailRow(Icons.history_edu_outlined, 'Fondé en',
                g.foundedYear.toString()),
          _DetailRow(Icons.link_outlined, 'Slug', g.slug ?? '—'),
          _DetailRow(Icons.calendar_today_outlined, 'Créé le',
              DateFormat('dd/MM/yyyy').format(g.createdAt)),
          _DetailRow(Icons.update_outlined, 'Mis à jour',
              DateFormat('dd/MM/yyyy').format(g.updatedAt), last: true),
        ]),
        if (g.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          const _SectionTitle('Notes'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Text(g.notes!, style: TextStyle(
                color: _kMuted, fontSize: 13, height: 1.5)),
          ),
        ],
        const SizedBox(height: 14),
        // Méta rapide
        Row(children: [
          Expanded(child: _MetaChip(
            icon: Icons.school_rounded,
            label: '${g.schoolCount} école${g.schoolCount > 1 ? 's' : ''}',
            color: _kNavy,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.people_rounded,
            label: '${g.maxStudents == -1 ? "∞" : g.maxStudents} élèves max',
            color: _kGreen,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.account_balance_wallet_rounded,
            label: '${_fmtXaf(g.priceXaf.toDouble())}/${g.periodSuffix}',
            color: _kGold,
          )),
        ]),
      ]),
    );
  }
}

class _SubscriptionTab extends ConsumerWidget {
  const _SubscriptionTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = group;
    final daysLeft = g.subscriptionEnd?.difference(DateTime.now()).inDays;
    final modulesAsync = ref.watch(groupModuleAccessProvider(g.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Plan actuel
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavy.withValues(alpha: 0.05), _kNavy.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kNavy.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_rounded, color: _kNavy, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Plan ${g.planName}', style: TextStyle(
                  color: _kNavy, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('${_fmtXaf(g.priceXaf.toDouble())} / ${g.periodSuffix}',
                  style: TextStyle(color: _kGold, fontSize: 14, fontWeight: FontWeight.w700)),
            ])),
            _StatusBadge(status: g.subscriptionStatus, label: g.statusLabel),
          ]),
        ),
        const SizedBox(height: 20),

        const _SectionTitle('Quotas'),
        const SizedBox(height: 12),

        _QuotaBar(
          label: 'Écoles utilisées',
          used: g.schoolCount,
          max:  g.maxSchools == -1 ? null : g.maxSchools,
          color: _kNavy,
        ),
        const SizedBox(height: 12),
        _QuotaBar(
          label: 'Capacité élèves',
          used: 0,
          max:  g.maxStudents == -1 ? null : g.maxStudents,
          color: _kGreen,
          showUsed: false,
        ),
        const SizedBox(height: 20),

        const _SectionTitle('Période'),
        const SizedBox(height: 12),
        _InfoGrid([
          _InfoItem('Début', g.subscriptionStart != null
              ? DateFormat('dd/MM/yyyy').format(g.subscriptionStart!)
              : '—', Icons.play_circle_rounded),
          _InfoItem('Fin', g.subscriptionEnd != null
              ? DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!)
              : '—', Icons.stop_circle_rounded),
          if (daysLeft != null)
            _InfoItem(
              daysLeft > 0 ? 'Jours restants' : 'Expiré depuis',
              daysLeft > 0 ? '$daysLeft jours' : '${(-daysLeft)} jours',
              Icons.timer_rounded,
            ),
        ]),
        const SizedBox(height: 20),

        // ─ Modules accessibles ────────────────────────────────────────────────
        const _SectionTitle('Modules du plan'),
        const SizedBox(height: 12),
        modulesAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          error: (e, _) => Text(messageErreur(e),
              style: const TextStyle(color: _kRed, fontSize: 12)),
          data: (modules) {
            if (modules.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text('Aucun module configuré dans ce plan.',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              );
            }
            final byCategory = <String, List<GroupModuleAccess>>{};
            for (final m in modules) {
              (byCategory[m.categoryName] ??= []).add(m);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: byCategory.entries.map((entry) {
                final accessCount = entry.value.where((m) => m.isAccessible).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(entry.key, style: TextStyle(
                          color: _kNavy, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accessCount > 0 ? _kGreen.withValues(alpha: 0.1) : _kMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$accessCount/${entry.value.length}',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: accessCount > 0 ? _kGreen : _kMuted)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Column(
                          children: entry.value.asMap().entries.map((me) {
                            final mod = me.value;
                            final isLast = me.key == entry.value.length - 1;
                            return Container(
                              decoration: BoxDecoration(
                                border: isLast ? null : Border(
                                  bottom: BorderSide(color: _kBorder),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                leading: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: mod.isAccessible
                                        ? _kGreen.withValues(alpha: 0.1)
                                        : _kMuted.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    mod.isAccessible
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_rounded,
                                    size: 14,
                                    color: mod.isAccessible ? _kGreen : _kMuted,
                                  ),
                                ),
                                title: Text(mod.moduleName, style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: mod.isAccessible ? _kText : _kMuted,
                                )),
                                trailing: mod.isAccessible
                                    ? Text('Actif',
                                        style: TextStyle(
                                          color: _kGreen, fontSize: 11,
                                          fontWeight: FontWeight.w600))
                                    : Text('Verrouillé',
                                        style: TextStyle(
                                          color: _kMuted, fontSize: 11)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TimelineItem(
          icon: Icons.add_circle_rounded,
          color: _kGreen,
          title: 'Groupe créé',
          date: g.createdAt,
        ),
        if (g.subscriptionStart != null)
          _TimelineItem(
            icon: Icons.play_arrow_rounded,
            color: _kNavy,
            title: 'Abonnement démarré — Plan ${g.planName}',
            date: g.subscriptionStart!,
          ),
        if (g.subscriptionEnd != null && g.subscriptionEnd!.isBefore(DateTime.now()))
          _TimelineItem(
            icon: Icons.event_busy_rounded,
            color: _kRed,
            title: 'Abonnement expiré',
            date: g.subscriptionEnd!,
          ),
        _TimelineItem(
          icon: Icons.update_rounded,
          color: _kMuted,
          title: 'Dernière mise à jour',
          date: g.updatedAt,
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.date,
  });
  final IconData icon;
  final Color color;
  final String title;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(DateFormat('dd MMMM yyyy', 'fr').format(date),
            style: TextStyle(color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.used,
    required this.max,
    required this.color,
    this.showUsed = true,
  });
  final String label;
  final int used;
  final int? max;
  final Color color;
  final bool showUsed;

  @override
  Widget build(BuildContext context) {
    final pct = max != null && max! > 0 ? (used / max!).clamp(0.0, 1.0) : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: _kMuted, fontSize: 12)),
        const Spacer(),
        Text(max == null || max == -1
            ? (showUsed ? '$used / ∞' : 'Illimité')
            : '$used / $max',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: max == null || max == -1 ? 0.1 : pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ─── Bouton Sauvegarder Premium ───────────────────────────────────────────────

class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  }) : loading = false;
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool loading;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:   (_) => _ctrl.forward(),
        onTapUp:     (_) { _ctrl.reverse(); widget.onPressed?.call(); },
        onTapCancel: ()  => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.onPressed == null
                    ? [Colors.grey.shade300, Colors.grey.shade300]
                    : [const Color(0xFF1A2F5A), _kNavy],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered && widget.onPressed != null ? [
                BoxShadow(color: _kNavy.withValues(alpha: 0.4),
                    blurRadius: 16, offset: const Offset(0, 6)),
              ] : [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.loading)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                Icon(widget.icon, color: Colors.white, size: 17),
              const SizedBox(width: 10),
              Text(widget.label, style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              if (!widget.loading) ...[
                const SizedBox(width: 8),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _hovered ? const Offset(0.2, 0) : Offset.zero,
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white60, size: 15),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}


// ─── Aide latérale formulaire ─────────────────────────────────────────────────

// ─── Dialog suppression premium ───────────────────────────────────────────────

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.group});
  final GroupDetail group;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: _kRed.withValues(alpha: 0.12),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Zone danger ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: _kRed.withValues(alpha: 0.12))),
            ),
            child: Column(children: [
              // Icône d'alerte
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kRed.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: _kRed, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('Supprimer définitivement',
                  style: TextStyle(
                      color: _kRed, fontSize: 17,
                      fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              const SizedBox(height: 6),
              Text('Cette action est irréversible',
                  style: TextStyle(
                      color: _kRed.withValues(alpha: 0.7),
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),

          // ── Corps ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Groupe ciblé
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  _GroupAvatar(name: g.name, size: 40, logoUrl: g.logoUrl),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: TextStyle(
                          color: _kText, fontSize: 14,
                          fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${g.groupTypeLabel}  •  ${g.adminEmail}',
                          style: TextStyle(
                              color: _kMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // Avertissement données
              Text('Seront également supprimées :',
                  style: TextStyle(
                      color: _kText, fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const _DeleteWarningItem(
                  icon: Icons.school_rounded,
                  text: 'Toutes les écoles rattachées au groupe'),
              const _DeleteWarningItem(
                  icon: Icons.people_rounded,
                  text: 'Tous les élèves et le personnel'),
              const _DeleteWarningItem(
                  icon: Icons.payments_rounded,
                  text: 'L\'historique des paiements'),
              const _DeleteWarningItem(
                  icon: Icons.description_rounded,
                  text: 'Les documents et archives scolaires'),
              const SizedBox(height: 18),

              // Case à cocher confirmation
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : kCardBg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _confirmed
                              ? _kRed
                              : _kBorder,
                          width: 2,
                        ),
                      ),
                      child: _confirmed
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Je comprends que cette action est irréversible',
                      style: TextStyle(
                          color: _confirmed ? _kRed : _kMuted,
                          fontSize: 12.5,
                          fontWeight: _confirmed
                              ? FontWeight.w700
                              : FontWeight.w400),
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
            ]),
          ),

          // ── Footer ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Annuler
              Expanded(child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context, false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Annuler',
                        style: TextStyle(
                            color: _kMuted, fontSize: 13,
                            fontWeight: FontWeight.w700))),
                  ),
                ),
              )),
              const SizedBox(width: 12),
              // Supprimer
              Expanded(child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _confirmed ? 1.0 : 0.4,
                child: MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.forbidden,
                  child: GestureDetector(
                    onTap: _confirmed
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _confirmed ? [BoxShadow(
                          color: _kRed.withValues(alpha: 0.30),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )] : [],
                      ),
                      child: const Center(child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_forever_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Supprimer',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ],
                      )),
                    ),
                  ),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DeleteWarningItem extends StatelessWidget {
  const _DeleteWarningItem({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Container(
        width: 22, height: 22,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 12, color: _kRed.withValues(alpha: 0.7)),
      ),
      Expanded(child: Text(text, style: TextStyle(
          color: _kMuted, fontSize: 11.5))),
    ]),
  );
}

// ─── Fiche officielle d'identité du groupe ────────────────────────────────────

class _PrintPreviewModal extends StatefulWidget {
  const _PrintPreviewModal({required this.group});
  final GroupDetail group;

  @override
  State<_PrintPreviewModal> createState() => _PrintPreviewModalState();
}

class _PrintPreviewModalState extends State<_PrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  GroupDetail get g => widget.group;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await GroupPdfService.printGroup(g);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Impression')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    try {
      final path = await GroupPdfService.downloadGroup(g);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            path != null ? 'PDF sauvegardé : $path' : 'PDF généré',
            overflow: TextOverflow.ellipsis,
          )),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Téléchargement')),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _copyToClipboard(BuildContext context) {
    final g = widget.group;
    final now = DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now());
    final lines = [
      '════════════════════════════════════════',
      '  E-PILOTE CONGO — FICHE OFFICIELLE',
      '  Groupe Scolaire • Générée le $now',
      '════════════════════════════════════════',
      '',
      '  ${g.name.toUpperCase()}',
      '  Statut : ${g.statusLabel}  |  Type : ${g.groupTypeLabel}  |  Plan : ${g.planName}',
      if (g.foundedYear != null) '  Fondé en : ${g.foundedYear}',
      '',
      '── COORDONNÉES ──────────────────────────',
      '  Email       : ${g.adminEmail}',
      '  Téléphone   : ${g.phone ?? '—'}',
      '  Département : ${g.department ?? '—'}',
      '  Adresse     : ${g.address ?? '—'}',
      '',
      '── ABONNEMENT ───────────────────────────',
      '  Plan        : ${g.planName}',
      '  Tarif       : ${_fmtXaf(g.priceXaf.toDouble())} / ${g.periodSuffix}',
      if (g.subscriptionStart != null)
        '  Début       : ${DateFormat('dd/MM/yyyy').format(g.subscriptionStart!)}',
      if (g.subscriptionEnd != null)
        '  Expiration  : ${DateFormat('dd/MM/yyyy').format(g.subscriptionEnd!)}',
      '',
      '── CAPACITÉ ─────────────────────────────',
      '  Écoles      : ${g.schoolCount} / ${g.maxSchools == -1 ? "Illimité" : "${g.maxSchools}"}',
      '  Élèves max  : ${g.maxStudents == -1 ? "Illimité" : "${g.maxStudents}"}',
      '',
      '── HISTORIQUE ───────────────────────────',
      '  Création    : ${DateFormat('dd MMMM yyyy', 'fr').format(g.createdAt)}',
      '  Mis à jour  : ${DateFormat('dd MMMM yyyy', 'fr').format(g.updatedAt)}',
      '',
      '════════════════════════════════════════',
      '  Document généré via E-PILOTE CONGO',
      '  Réf. : ${g.id.substring(0, 8).toUpperCase()}',
      '════════════════════════════════════════',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Fiche copiée dans le presse-papiers'),
      ]),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now  = DateFormat('dd/MM/yyyy • HH:mm', 'fr').format(DateTime.now());
    final ref_ = g.id.substring(0, 8).toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 820),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          // ── Barre modale ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche officielle du groupe',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  $now',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5)),
              ]),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ]),
          ),

          // ── Aperçu PDF réel ────────────────────────────────────────────────
          Expanded(
            child: PdfPreview(
              build: (format) => GroupPdfService.buildPdf(g),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Fiche_${g.name.replaceAll(' ', '_')}.pdf',
            ),
          ),

          // ── Footer actions ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Fermer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Fermer', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              // Copier texte
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => _copyToClipboard(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
                      Text('Copier', style: TextStyle(
                          color: _kMuted, fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Imprimer
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _printing ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_printing)
                        SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kNavy))
                      else
                        Icon(Icons.print_rounded,
                            size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: TextStyle(
                              color: _kNavy, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Télécharger PDF
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _downloading ? null : _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_downloading)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded,
                            size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_downloading ? 'Génération…' : 'Télécharger PDF',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

// Couleur du point plan dans le dropdown
Color _planDotColor(String plan) => switch (plan.toLowerCase()) {
  String p when p.contains('premium')       => _kGold,
  String p when p.contains('pro')           => _kNavy,
  String p when p.contains('institution')   => _kPurple,
  String p when p.contains('gratuit')       => _kMuted,
  _                                          => _kGreen,
};

IconData _typeIcon(String type) => switch (type) {
  'public'     => Icons.account_balance_rounded,
  'catholique' => Icons.church_rounded,
  'islamique'  => Icons.mosque_rounded,
  'protestant' => Icons.volunteer_activism_rounded,
  _            => Icons.business_rounded,
};

// Label de section minimaliste
class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(
          color: _kNavy,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          color: _kNavy, fontSize: 10.5, fontWeight: FontWeight.w800,
          letterSpacing: 1.1)),
    ]),
  );
}

// Séparateur de section dans le formulaire
class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(color: _kBorder, height: 1),
  );
}

// Widget dropdown filtre compact
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? _kNavy.withValues(alpha: 0.06) : _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? _kNavy.withValues(alpha: 0.4) : _kBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16,
              color: active ? _kNavy : _kMuted),
          style: TextStyle(
            color: active ? _kNavy : _kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w600,
          ),
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// Initiales carrées pour le header du modal
class _SquareInitials extends StatelessWidget {
  const _SquareInitials({required this.name, required this.size});
  final String name;
  final double size;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange,
      const Color(0xFF0EA5E9)];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }

  Color get _color =>
      name.isNotEmpty ? _colors[name.codeUnitAt(0) % _colors.length] : _kNavy;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    color: _color.withValues(alpha: 0.12),
    child: Center(child: Text(_initials, style: TextStyle(
      color: _color, fontSize: size * 0.3, fontWeight: FontWeight.w900,
    ))),
  );
}

// Bouton icône compact pour le header modal
class _ModalIconBtn extends StatelessWidget {
  const _ModalIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
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
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

// Carte de détail (rows groupées dans une border)
class _DetailCard extends StatelessWidget {
  const _DetailCard(this.rows);
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

// Row d'un détail dans le modal
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value, {this.last = false});
  final IconData icon;
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// Meta chip dans InfoTab
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(
          color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Logo Upload Box (formulaire) ────────────────────────────────────────────

class _LogoUploadBox extends StatelessWidget {
  const _LogoUploadBox({
    required this.name,
    required this.onPick,
    required this.onRemove,
    this.logoUrl,
    this.previewBytes,
    this.uploading = false,
  });
  final String      name;
  final String?     logoUrl;
  final Uint8List?  previewBytes;
  final bool        uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static List<Color> get _colors => [_kNavy, _kGreen, _kPurple, _kOrange, const Color(0xFF0EA5E9)];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }

  Color get _color => name.isNotEmpty
      ? _colors[name.codeUnitAt(0) % _colors.length]
      : _kNavy;

  bool get _hasImage =>
      previewBytes != null ||
      (logoUrl != null && logoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Aperçu ──────────────────────────────────────────────────────────
      Stack(alignment: Alignment.topRight, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasImage
                      ? _kNavy.withValues(alpha: 0.35)
                      : _kBorder,
                  width: _hasImage ? 2 : 1.5,
                ),
                color: _kSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildContent(),
            ),
          ),
        ),
        // Bouton supprimer si image présente
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
                    color: _kRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      // ── Bouton sélectionner ──────────────────────────────────────────────
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kNavy.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                uploading ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                size: 12, color: _kNavy,
              ),
              const SizedBox(width: 4),
              Text(
                uploading ? 'Upload…' : (_hasImage ? 'Changer' : 'Logo'),
                style: TextStyle(
                  color: _kNavy, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    if (uploading) {
      return Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy),
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
        placeholder: (_, _) => Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy),
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
          size: 22, color: _kMuted.withValues(alpha: 0.5)),
      const SizedBox(height: 3),
      Text(_initials, style: TextStyle(
          color: _color, fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800,
      letterSpacing: 0.2));
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid(this.items);
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: items.map((i) => SizedBox(
      width: (MediaQuery.of(context).size.width - 240) / 2 - 36,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Icon(i.icon, size: 16, color: _kNavy),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.label, style: TextStyle(color: _kMuted, fontSize: 10.5,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(i.value, style: TextStyle(color: _kText, fontSize: 13,
                fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    )).toList(),
  );
}

class _InfoItem {
  const _InfoItem(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
}

InputDecoration _inputDeco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: _kMuted, fontSize: 13),
  filled: true,
  fillColor: _kSurface,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: _kNavy, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kRed),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
);

// ─── Formatters ───────────────────────────────────────────────────────────────

String _fmtXaf(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} M FCFA';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} k FCFA';
  return '${v.toStringAsFixed(0)} FCFA';
}
