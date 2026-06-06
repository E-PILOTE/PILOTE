import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/modules_provider.dart';
import '../services/module_pdf_service.dart';

// ─── Design tokens (identiques à administrators_screen) ──────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kGreen   = Color(0xFF009A44);
const _kGold    = Color(0xFFFBBC04);
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kBlue    = Color(0xFF0EA5E9);
const _kRed     = Color(0xFFEF4444);
const _kSurface = Color(0xFFF0F4F8);
const _kBg      = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFE2E8F0);
const _kText    = Color(0xFF0F172A);
const _kMuted   = Color(0xFF64748B);

// ─── Palette catégories (cyclée par ordre) ───────────────────────────────────
const _catPalette = [
  _kNavy, _kGreen, _kGold, _kBlue, _kPurple, _kOrange, _kRed,
];
Color _catColor(int order) => _catPalette[order.abs() % _catPalette.length];

// ─── Helpers dates ────────────────────────────────────────────────────────────
const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
String _fmtDateTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year} à ${hh}h$mm';
}

// ─── Écran principal ──────────────────────────────────────────────────────────

class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Catégories & Modules',
      child: _ModulesBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _ModulesBody extends ConsumerStatefulWidget {
  const _ModulesBody();
  @override
  ConsumerState<_ModulesBody> createState() => _ModulesBodyState();
}

class _ModulesBodyState extends ConsumerState<_ModulesBody> {
  final _searchCtrl    = TextEditingController();
  String _filterCat    = 'tous';
  String _filterStatus = 'tous';
  String _sort         = 'ordre';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ModuleItem> _applyFilters(List<ModuleItem> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((m) {
      if (q.isNotEmpty) {
        final match = m.name.toLowerCase().contains(q)
            || m.slug.toLowerCase().contains(q)
            || m.categoryName.toLowerCase().contains(q)
            || (m.description?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterCat != 'tous' && m.categoryId != _filterCat) return false;
      if (_filterStatus == 'actif'   && !m.isActive) return false;
      if (_filterStatus == 'inactif' &&  m.isActive) return false;
      return true;
    }).toList()
      ..sort((a, b) => switch (_sort) {
        'az'      => a.name.compareTo(b.name),
        'za'      => b.name.compareTo(a.name),
        'plans'   => b.planCount.compareTo(a.planCount),
        'recent'  => b.createdAt.compareTo(a.createdAt),
        _         => a.categoryName.compareTo(b.categoryName) != 0
            ? a.categoryName.compareTo(b.categoryName)
            : a.displayOrder.compareTo(b.displayOrder),
      });
  }

  // ── Formulaires ────────────────────────────────────────────────────────────
  void _openModuleForm({ModuleItem? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _ModuleFormModal(editing: editing),
    ).then((_) => ref.invalidate(modulesProvider));
  }

  void _openCategoryForm({ModuleCategory? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _CategoryFormModal(editing: editing),
    ).then((_) => ref.invalidate(modulesProvider));
  }

  void _openModuleDetail(ModuleItem m) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ModuleDetailModal(
        module: m,
        onEdit:   () { Navigator.pop(context); _openModuleForm(editing: m); },
        onToggle: () { Navigator.pop(context); _toggleModuleActive(m); },
        onDelete: () { Navigator.pop(context); _confirmDeleteModule(m); },
        onPrint:  () => _printModule(m),
      ),
    );
  }

  void _printModule(ModuleItem m) {
    final plans = ref.read(modulesProvider).valueOrNull?.plans ?? const [];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ModulePrintPreviewModal(module: m, plans: plans),
    );
  }

  Future<void> _toggleModuleActive(ModuleItem m) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('modules')
          .update({'is_active': !m.isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', m.id);
      ref.invalidate(modulesProvider);
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  Future<void> _confirmDeleteModule(ModuleItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(
        emoji: m.emoji,
        color: _kBlue,
        title: 'Supprimer le module',
        name: m.name,
        subtitle: m.categoryName,
        warning: 'Le module sera retiré du catalogue ainsi que de tous les plans '
            'd\'abonnement (${m.planCount}). Les écoles n\'y auront plus accès.',
        confirmLabel: 'Je confirme vouloir supprimer définitivement ce module',
      ),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('plan_modules').delete().eq('module_id', m.id);
      await client.from('modules').delete().eq('id', m.id);
      ref.invalidate(modulesProvider);
      if (mounted) _showSuccess('Module "${m.name}" supprimé définitivement.');
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  Future<void> _confirmDeleteCategory(ModuleCategory c) async {
    if (c.moduleCount > 0) {
      _showError('Impossible : la catégorie "${c.name}" contient encore '
          '${c.moduleCount} module(s). Déplacez ou supprimez-les d\'abord.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeleteConfirmDialog(
        emoji: c.emoji,
        color: _kNavy,
        title: 'Supprimer la catégorie',
        name: c.name,
        subtitle: 'Catégorie de navigation',
        warning: 'La catégorie sera retirée de la navigation de la plateforme. '
            'Cette action est irréversible.',
        confirmLabel: 'Je confirme vouloir supprimer définitivement cette catégorie',
      ),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('module_categories').delete().eq('id', c.id);
      ref.invalidate(modulesProvider);
      if (mounted) _showSuccess('Catégorie "${c.name}" supprimée.');
    } catch (e) {
      if (mounted) _showError('Erreur : $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(modulesProvider);

    return async.when(
      skipLoadingOnReload:  true,
      skipLoadingOnRefresh: true,
      loading: () => const _ShimmerSkeleton(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text('Erreur : $e', style: const TextStyle(color: _kMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(modulesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(ModulesData data) {
    final filtered = _applyFilters(data.modules);

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

              // ── Panneau Catégories ──────────────────────────────────────
              _CategoriesPanel(
                categories: data.categories,
                selectedId: _filterCat,
                onSelect:   (id) => setState(() =>
                    _filterCat = (_filterCat == id) ? 'tous' : id),
                onAdd:      () => _openCategoryForm(),
                onEdit:     (c) => _openCategoryForm(editing: c),
                onDelete:   _confirmDeleteCategory,
              ),
              const SizedBox(height: 20),

              _FilterBar(
                contentWidth:   w - 48,
                searchCtrl:     _searchCtrl,
                categories:     data.categories,
                filterCat:      _filterCat,
                filterStatus:   _filterStatus,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onCat:          (v) => setState(() => _filterCat    = v),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterCat = _filterStatus = 'tous';
                  _sort = 'ordre';
                }),
                onAddModule:   () => _openModuleForm(),
                onAddCategory: () => _openCategoryForm(),
              ),
              const SizedBox(height: 16),

              _ResultHeader(total: data.totalModules, filtered: filtered.length),
              const SizedBox(height: 12),

              if (_isTableView)
                _TableView(
                  modules:  filtered,
                  onView:   _openModuleDetail,
                  onEdit:   (m) => _openModuleForm(editing: m),
                  onDelete: _confirmDeleteModule,
                  onToggle: _toggleModuleActive,
                )
              else
                _CardGrid(
                  modules:  filtered,
                  onView:   _openModuleDetail,
                  onEdit:   (m) => _openModuleForm(editing: m),
                  onDelete: _confirmDeleteModule,
                  onToggle: _toggleModuleActive,
                ),
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
  final ModulesData data;

  @override
  Widget build(BuildContext context) {
    final nM = data.totalModules;
    final nP = data.plans.length;
    final avgCov = nP > 0 && nM > 0
        ? (data.totalPlanLinks / nP).round()
        : 0;
    final items = [
      _KD(
        label: 'Catégories', value: '${data.totalCategories}',
        sub: '$nM module${nM > 1 ? "s" : ""} au total',
        icon: Icons.category_rounded, color: _kNavy,
        progressValue: data.totalCategories > 0 ? 1 : 0,
        trend: data.totalCategories > 0 ? '🗂 Navigation' : '—',
      ),
      _KD(
        label: 'Modules', value: '$nM',
        sub: '${data.activeModules} actifs · ${data.inactiveModules} inactifs',
        icon: Icons.extension_rounded, color: _kBlue,
        progressValue: nM > 0 ? data.activeModules / nM : 0,
        trend: nM > 0 ? '${(data.activeModules * 100 / nM).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Modules actifs', value: '${data.activeModules}',
        sub: nM > 0 ? '${(data.activeModules * 100 / nM).round()}% du total' : '—',
        icon: Icons.check_circle_rounded, color: _kGreen,
        progressValue: nM > 0 ? data.activeModules / nM : 0,
        trend: data.activeModules > 0 ? '✅ Disponibles' : '—',
      ),
      _KD(
        label: 'Modules inactifs', value: '${data.inactiveModules}',
        sub: data.inactiveModules > 0 ? 'Masqués des plans' : '✅ Tous actifs',
        icon: Icons.block_rounded, color: _kRed,
        progressValue: nM > 0 ? data.inactiveModules / nM : 0,
        trend: data.inactiveModules > 0 ? '⚠ À vérifier' : '✅ OK',
        trendUp: data.inactiveModules == 0,
      ),
      _KD(
        label: 'Plans d\'abonnement', value: '$nP',
        sub: 'Offres configurées',
        icon: Icons.workspace_premium_rounded, color: _kGold,
        progressValue: nP > 0 ? 1 : 0,
        trend: nP > 0 ? '💎 Actifs' : '—',
      ),
      _KD(
        label: 'Liens plan·module', value: '${data.totalPlanLinks}',
        sub: 'Moy. $avgCov module(s)/plan',
        icon: Icons.account_tree_rounded, color: _kPurple,
        progressValue: (nM * nP) > 0 ? data.totalPlanLinks / (nM * nP) : 0,
        trend: data.totalPlanLinks > 0 ? '🔗 Couverture' : '—',
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
              border: Border.all(color: _kBorder),
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
                          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600,
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
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorder),
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
    decoration: BoxDecoration(
      color: Colors.white,
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
          _box(double.infinity, 96, r: 14),
          const SizedBox(height: 20),
          _box(double.infinity, 120, r: 14),
          const SizedBox(height: 16),
          _box(180, 18, r: 8),
          const SizedBox(height: 16),
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

// ─── Panneau Catégories ───────────────────────────────────────────────────────

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ModuleCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ModuleCategory> onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.category_rounded, size: 16, color: _kNavy),
          const SizedBox(width: 8),
          const Text('Catégories', style: TextStyle(
              color: _kText, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kSurface, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Text('${categories.length}', style: const TextStyle(
                color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 14, color: _kNavy),
                  SizedBox(width: 4),
                  Text('Catégorie', style: TextStyle(
                      color: _kNavy, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune catégorie. Créez-en une pour organiser les modules.',
                style: TextStyle(color: _kMuted, fontSize: 12.5)),
          )
        else
          Wrap(spacing: 10, runSpacing: 10,
            children: categories.map((c) => _CategoryChip(
              category: c,
              selected: selectedId == c.id,
              onTap:    () => onSelect(c.id),
              onEdit:   () => onEdit(c),
              onDelete: () => onDelete(c),
            )).toList(),
          ),
      ]),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final ModuleCategory category;
  final bool selected;
  final VoidCallback onTap, onEdit, onDelete;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final color = _catColor(c.displayOrder);
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.12) : _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? color : (_hov ? color.withValues(alpha: 0.4) : _kBorder),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(c.name, style: TextStyle(
                  color: sel ? color : _kText, fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
              Text('${c.moduleCount} module${c.moduleCount > 1 ? "s" : ""} · '
                  '${c.activeModuleCount} actif${c.activeModuleCount > 1 ? "s" : ""}',
                  style: const TextStyle(color: _kMuted, fontSize: 10)),
            ]),
            if (_hov || sel) ...[
              const SizedBox(width: 8),
              _MiniBtn(icon: Icons.edit_rounded, color: _kNavy,
                  tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 3),
              _MiniBtn(icon: Icons.delete_rounded, color: _kRed,
                  tooltip: 'Supprimer', onTap: widget.onDelete),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.color,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    ),
  );
}

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.categories,
    required this.filterCat,
    required this.filterStatus,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onCat,
    required this.onStatus,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAddModule,
    required this.onAddCategory,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final List<ModuleCategory> categories;
  final String filterCat, filterStatus, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onCat, onStatus, onSort;
  final VoidCallback onToggleView, onReset, onAddModule, onAddCategory;

  @override
  Widget build(BuildContext context) {
    final catItems = <String, String>{'tous': 'Toutes les catégories'};
    for (final c in categories) {
      catItems[c.id] = '${c.emoji}  ${c.name}';
    }
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
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChange,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, slug, catégorie…',
                  hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
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
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _AddBtn(icon: Icons.create_new_folder_rounded,
                label: 'Catégorie', outlined: true, onTap: onAddCategory),
            const SizedBox(width: 8),
            _AddBtn(icon: Icons.add_rounded,
                label: 'Nouveau module', outlined: false, onTap: onAddModule),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Flexible(child: _FilterDropdown(
              icon: Icons.category_rounded,
              label: 'Catégorie',
              items: catItems,
              value: catItems.containsKey(filterCat) ? filterCat : 'tous',
              onChanged: onCat,
              active: filterCat != 'tous',
            )),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded,
              label: 'Statut',
              items: const {
                'tous':    'Tous les statuts',
                'actif':   'Actifs',
                'inactif': 'Inactifs',
              },
              value: filterStatus,
              onChanged: onStatus,
              active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded,
              label: 'Trier',
              items: const {
                'ordre':  'Par catégorie / ordre',
                'az':     'A → Z',
                'za':     'Z → A',
                'plans':  'Plus de plans',
                'recent': 'Plus récents',
              },
              value: sort,
              onChanged: onSort,
              active: sort != 'ordre',
            ),
            const Spacer(),
            if (filterCat != 'tous' || filterStatus != 'tous' || sort != 'ordre')
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

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.icon, required this.label,
      required this.outlined, required this.onTap});
  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: outlined ? _kNavy.withValues(alpha: 0.06) : null,
          gradient: outlined ? null : const LinearGradient(
            colors: [Color(0xFF1A2F5A), Color(0xFF1E3A5F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: outlined ? Border.all(color: _kNavy.withValues(alpha: 0.25)) : null,
          boxShadow: outlined ? null : [BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: outlined ? _kNavy : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: outlined ? _kNavy : Colors.white, fontSize: 13,
            fontWeight: FontWeight.w700, letterSpacing: 0.2,
          )),
        ]),
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.active,
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
        dropdownColor: Colors.white,
        isDense: true,
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : _kMuted),
        style: TextStyle(
          color: active ? Colors.white : _kMuted,
          fontSize: 12.5, fontWeight: FontWeight.w600,
        ),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
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
    Text('$filtered module${filtered > 1 ? "s" : ""}',
        style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
    if (filtered < total) ...[
      const SizedBox(width: 8),
      Text('sur $total', style: const TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ]);
}

// ─── Vue Tableau ──────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({
    required this.modules,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<ModuleItem> modules;
  final ValueChanged<ModuleItem> onView, onEdit, onDelete, onToggle;

  static const _iconW    = 44.0;
  static const _statusW  = 88.0;
  static const _actionsW = 132.0;

  static Widget _hdr(String label, int flex, {bool center = false}) => Expanded(
    flex: flex,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label, style: const TextStyle(
          color: _kMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const _EmptyState();

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
          Container(
            height: 38,
            color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _iconW),
              _hdr('Module',        3),
              _hdr('Catégorie',     3),
              _hdr('Slug',          3),
              _hdr('Plans',         2, center: true),
              const SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              _hdr('Ordre',         2, center: true),
              const SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
          ...modules.asMap().entries.map((e) => _TableRow(
            module:   e.value,
            isOdd:    e.key.isOdd,
            iconW:    _iconW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
            onDelete: () => onDelete(e.value),
            onToggle: () => onToggle(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.module,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final ModuleItem  module;
  final bool        isOdd;
  final double      iconW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          SizedBox(width: widget.iconW, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              child: _ModuleEmoji(emoji: m.emoji, size: 36),
            ),
          )),
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  if ((m.description ?? '').trim().isNotEmpty)
                    Text(m.description!.trim(),
                        style: const TextStyle(fontSize: 10.5, color: _kMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )),
          Expanded(flex: 3, child: _CategoryBadge(
              name: m.categoryName, color: _kGold)),
          Expanded(flex: 3, child: Text(m.slug,
              style: const TextStyle(fontSize: 11.5, color: _kNavy,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPurple.withValues(alpha: 0.20)),
            ),
            child: Text('${m.planCount}', style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: _kPurple)),
          ))),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: m.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: m.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(m.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: m.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: Center(child: Text('#${m.displayOrder}',
              style: const TextStyle(fontSize: 11.5, color: _kMuted,
                  fontWeight: FontWeight.w600)))),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue,   tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded,       color: _kNavy,   tooltip: 'Modifier',      onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: m.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: _kOrange, tooltip: m.isActive ? 'Désactiver' : 'Activer', onTap: widget.onToggle),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded,     color: _kRed,    tooltip: 'Supprimer',     onTap: widget.onDelete),
            ]),
          ),
        ]),
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
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
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
  const _CardGrid({
    required this.modules,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<ModuleItem> modules;
  final ValueChanged<ModuleItem> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.65,
      ),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleCard(
        module:   modules[i],
        onView:   () => onView(modules[i]),
        onEdit:   () => onEdit(modules[i]),
        onDelete: () => onDelete(modules[i]),
        onToggle: () => onToggle(modules[i]),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.module,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final ModuleItem  module;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onView,
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
          Row(children: [
            _ModuleEmoji(emoji: m.emoji, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(m.slug, style: const TextStyle(
                    color: _kMuted, fontSize: 11, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: m.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _CategoryBadge(name: m.categoryName, color: _kGold, compact: true),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${m.planCount} plan${m.planCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                      color: _kPurple, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.tag_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 4),
            Text('Ordre #${m.displayOrder}', style: const TextStyle(
                color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: widget.onView,
              icon: const Icon(Icons.visibility_rounded, size: 13),
              label: const Text('Voir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kBlue),
            ),
            TextButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Modifier', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kNavy),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: _kRed,
              tooltip: 'Supprimer',
            ),
          ]),
        ]),
      ),
      ),
    );
  }
}

// ─── Badges & icônes ──────────────────────────────────────────────────────────

class _ModuleEmoji extends StatelessWidget {
  const _ModuleEmoji({required this.emoji, this.size = 36});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: _kBorder),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.name, required this.color, this.compact = false});
  final String name;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(compact ? 6 : 12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_rounded, size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(name, style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
    return compact ? badge : Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: badge,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(isActive ? 'Actif' : 'Inactif', style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.extension_off_rounded, size: 56, color: _kBorder),
      SizedBox(height: 16),
      Text('Aucun module trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau module.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Emojis suggérés ──────────────────────────────────────────────────────────
const _emojiSuggestions = [
  '📦','🧩','🎓','📚','🏫','👨‍🎓','📋','🏛️','📖','📝','📊','💰','💳','🧾',
  '📅','⏰','✅','📈','🩺','🍽️','📕','🚌','🏆','🔔','📢','✉️','📁','🗂️',
  '🛠️','⚙️','👥','🧑‍🏫','📌','🎯','💼','🗓️','📎','🔐','🌐','🏥',
];

String _slugify(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ûü]'), 'u')
    .replaceAll(RegExp(r'[ç]'), 'c')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

// ─── Modal Module (création / édition) ────────────────────────────────────────

class _ModuleFormModal extends ConsumerStatefulWidget {
  const _ModuleFormModal({this.editing});
  final ModuleItem? editing;
  @override
  ConsumerState<_ModuleFormModal> createState() => _ModuleFormModalState();
}

class _ModuleFormModalState extends ConsumerState<_ModuleFormModal> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _slugCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  String  _emoji    = '🧩';
  String? _categoryId;
  bool    _isActive = true;
  bool    _saving   = false;
  bool    _slugTouched = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.editing;
    if (m != null) {
      _nameCtrl.text  = m.name;
      _slugCtrl.text  = m.slug;
      _descCtrl.text  = m.description ?? '';
      _orderCtrl.text = '${m.displayOrder}';
      _emoji          = m.emoji;
      _categoryId     = m.categoryId;
      _isActive       = m.isActive;
      _slugTouched    = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner une catégorie'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'category_id':   _categoryId,
        'name':          _nameCtrl.text.trim(),
        'slug':          _slugCtrl.text.trim().isEmpty
            ? _slugify(_nameCtrl.text) : _slugCtrl.text.trim(),
        'description':   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'icon':          _emoji,
        'display_order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
        'is_active':     _isActive,
        'updated_at':    DateTime.now().toIso8601String(),
      };
      if (_isEditing) {
        await client.from('modules').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('modules').insert(payload);
      }
      ref.invalidate(modulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(modulesProvider).valueOrNull;
    final cats = data?.categories ?? const <ModuleCategory>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          _FormHeader(
            icon: _isEditing ? Icons.edit_rounded : Icons.add_rounded,
            title: _isEditing ? 'Modifier le module' : 'Nouveau module',
            subtitle: _isEditing
                ? 'Mise à jour des informations'
                : 'Ajoutez un module au catalogue',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EmojiPickerRow(
                    selected: _emoji,
                    onSelect: (e) => setState(() => _emoji = e),
                  ),
                  const SizedBox(height: 18),
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom du module *',
                    icon: Icons.extension_rounded,
                    onChanged: (v) => setState(() {
                      if (!_slugTouched) _slugCtrl.text = _slugify(v);
                    }),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _slugCtrl,
                    label: 'Slug (identifiant technique) *',
                    icon: Icons.link_rounded,
                    hint: 'auto-généré depuis le nom',
                    onChanged: (_) => _slugTouched = true,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Catégorie & Ordre'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(
                          color: _categoryId == null
                              ? _kRed.withValues(alpha: 0.5) : _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categoryId,
                        isExpanded: true,
                        hint: const Text('Sélectionner une catégorie *',
                            style: TextStyle(color: _kMuted, fontSize: 13)),
                        icon: const Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: const TextStyle(color: _kText, fontSize: 13),
                        items: cats.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _orderCtrl,
                    label: 'Ordre d\'affichage',
                    icon: Icons.sort_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Description (optionnelle)'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Décrivez la fonction de ce module…',
                      hintStyle: const TextStyle(color: _kMuted, fontSize: 12.5),
                      filled: true, fillColor: _kSurface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActiveToggleTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          _FormFooter(
            saving: _saving,
            saveLabel: _isEditing ? 'Enregistrer' : 'Créer le module',
            onSave: _save,
          ),
        ]),
      ),
    );
  }
}

// ─── Modal Catégorie (création / édition) ─────────────────────────────────────

class _CategoryFormModal extends ConsumerStatefulWidget {
  const _CategoryFormModal({this.editing});
  final ModuleCategory? editing;
  @override
  ConsumerState<_CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends ConsumerState<_CategoryFormModal> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _slugCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');

  String _emoji = '🗂️';
  bool   _saving = false;
  bool   _slugTouched = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    if (c != null) {
      _nameCtrl.text  = c.name;
      _slugCtrl.text  = c.slug;
      _orderCtrl.text = '${c.displayOrder}';
      _emoji          = c.emoji;
      _slugTouched    = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':          _nameCtrl.text.trim(),
        'slug':          _slugCtrl.text.trim().isEmpty
            ? _slugify(_nameCtrl.text) : _slugCtrl.text.trim(),
        'icon':          _emoji,
        'display_order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
        'updated_at':    DateTime.now().toIso8601String(),
      };
      if (_isEditing) {
        await client.from('module_categories').update(payload).eq('id', widget.editing!.id);
      } else {
        await client.from('module_categories').insert(payload);
      }
      ref.invalidate(modulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          _FormHeader(
            icon: _isEditing ? Icons.edit_rounded : Icons.create_new_folder_rounded,
            title: _isEditing ? 'Modifier la catégorie' : 'Nouvelle catégorie',
            subtitle: _isEditing
                ? 'Mise à jour des informations'
                : 'Organisez les modules par thème',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EmojiPickerRow(
                    selected: _emoji,
                    onSelect: (e) => setState(() => _emoji = e),
                  ),
                  const SizedBox(height: 18),
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom de la catégorie *',
                    icon: Icons.folder_rounded,
                    onChanged: (v) => setState(() {
                      if (!_slugTouched) _slugCtrl.text = _slugify(v);
                    }),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _slugCtrl,
                    label: 'Slug (identifiant technique) *',
                    icon: Icons.link_rounded,
                    hint: 'auto-généré depuis le nom',
                    onChanged: (_) => _slugTouched = true,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _orderCtrl,
                    label: 'Ordre d\'affichage',
                    icon: Icons.sort_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ]),
              ),
            ),
          ),
          _FormFooter(
            saving: _saving,
            saveLabel: _isEditing ? 'Enregistrer' : 'Créer la catégorie',
            onSave: _save,
          ),
        ]),
      ),
    );
  }
}

// ─── Sélecteur d'emoji ────────────────────────────────────────────────────────

class _EmojiPickerRow extends StatelessWidget {
  const _EmojiPickerRow({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(
        width: 72, height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kNavy.withValues(alpha: 0.3), width: 2),
        ),
        child: Text(selected, style: const TextStyle(fontSize: 36)),
      )),
      const SizedBox(height: 12),
      const Text('Icône', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Wrap(spacing: 6, runSpacing: 6,
          children: _emojiSuggestions.map((e) {
            final sel = e == selected;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelect(e),
                child: Container(
                  width: 34, height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? _kNavy.withValues(alpha: 0.12) : _kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? _kNavy : _kBorder,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 18)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─── En-tête / pied de formulaire partagés ────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      border: Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A2F5A), _kNavy]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
            color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
        Text(subtitle, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ]),
      const Spacer(),
      Builder(builder: (context) => InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.close_rounded, size: 15, color: _kMuted),
        ),
      )),
    ]),
  );
}

class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.saving, required this.saveLabel, required this.onSave});
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
    decoration: const BoxDecoration(
      color: _kSurface,
      border: Border(top: BorderSide(color: _kBorder)),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
    child: Row(children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Annuler', style: TextStyle(
                color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      const Spacer(),
      MouseRegion(
        cursor: saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: InkWell(
          onTap: saving ? null : onSave,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
              borderRadius: BorderRadius.circular(8),
              boxShadow: saving ? [] : [BoxShadow(
                color: _kNavy.withValues(alpha: 0.30),
                blurRadius: 8, offset: const Offset(0, 3),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (saving)
                const SizedBox(width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.save_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(saving ? 'Enregistrement…' : saveLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    ]),
  );
}

class _ActiveToggleTile extends StatelessWidget {
  const _ActiveToggleTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Icon(value ? Icons.check_circle_rounded : Icons.block_rounded,
          size: 18, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value ? 'Module actif' : 'Module inactif', style: const TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(value
            ? 'Visible et assignable aux plans d\'abonnement'
            : 'Masqué de la navigation et des plans',
            style: const TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: _kGreen,
      ),
    ]),
  );
}

// ─── Modal détails — Fiche module ─────────────────────────────────────────────

class _ModuleDetailModal extends StatefulWidget {
  const _ModuleDetailModal({
    required this.module,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onPrint,
  });
  final ModuleItem module;
  final VoidCallback onEdit, onToggle, onDelete, onPrint;

  @override
  State<_ModuleDetailModal> createState() => _ModuleDetailModalState();
}

class _ModuleDetailModalState extends State<_ModuleDetailModal>
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
    final m = widget.module;

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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              _ModuleEmoji(emoji: m.emoji, size: 66),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: const TextStyle(
                      color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _CategoryBadge(name: m.categoryName, color: _kGold, compact: true),
                    _StatusBadge(isActive: m.isActive),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kPurple.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kPurple.withValues(alpha: 0.30)),
                      ),
                      child: Text('${m.planCount} plan${m.planCount > 1 ? "s" : ""}',
                          style: const TextStyle(color: _kPurple, fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.link_rounded, size: 12, color: _kMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(m.slug,
                        style: const TextStyle(color: _kMuted, fontSize: 11.5,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Row(children: [
                _ModalIconBtn(icon: Icons.edit_rounded, color: _kNavy,
                    tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.print_rounded, color: _kMuted,
                    tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted,
                    tooltip: 'Fermer', onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
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
                Tab(text: 'Catégorie & Plans'),
                Tab(text: 'Activité'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ModInfoTab(module: m),
                _ModAccessTab(module: m),
                _ModActivityTab(module: m),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(m.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(m.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: m.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: m.isActive ? _kOrange : _kGreen),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onPrint,
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Imprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPurple,
                  side: const BorderSide(color: _kPurple),
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

class _ModInfoTab extends StatelessWidget {
  const _ModInfoTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _DSectionTitle('Identité'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.extension_rounded, 'Nom', m.name),
          _DRow(Icons.link_rounded, 'Slug', m.slug, copyable: true, mono: true),
          _DRow(Icons.folder_rounded, 'Catégorie', m.categoryName),
          _DRow(Icons.sort_rounded, 'Ordre d\'affichage', '#${m.displayOrder}', last: true),
        ]),
        const SizedBox(height: 14),
        if ((m.description ?? '').trim().isNotEmpty) ...[
          const _DSectionTitle('Description'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(m.description!.trim(), style: const TextStyle(
                color: _kText, fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
        const _DSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.tag_rounded, 'UUID', m.id, copyable: true, mono: true),
          _DRow(Icons.confirmation_number_outlined, 'Référence',
              m.id.substring(0, 8).toUpperCase()),
          _DRow(Icons.folder_special_rounded, 'ID catégorie', m.categoryId,
              copyable: true, mono: true, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MetaChip(
            icon: Icons.folder_rounded, label: m.categoryName, color: _kGold)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: m.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: m.isActive ? 'Actif' : 'Inactif',
            color: m.isActive ? _kGreen : _kRed)),
          const SizedBox(width: 8),
          Expanded(child: _MetaChip(
            icon: Icons.account_tree_rounded,
            label: '${m.planCount} plan(s)', color: _kPurple)),
        ]),
      ]),
    );
  }
}

class _ModAccessTab extends StatelessWidget {
  const _ModAccessTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kGold.withValues(alpha: 0.05), _kGold.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(m.categoryName, style: const TextStyle(
                  color: _kGold, fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('Catégorie de navigation',
                  style: TextStyle(color: _kMuted, fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ])),
            _StatusBadge(isActive: m.isActive),
          ]),
        ),
        const SizedBox(height: 20),
        const _DSectionTitle('Disponibilité par plan'),
        const SizedBox(height: 8),
        _DCard([
          _DRow(Icons.workspace_premium_rounded, 'Plans concernés',
              '${m.planCount} plan(s)'),
          _DRow(Icons.toggle_on_rounded, 'État',
              m.isActive ? 'Disponible' : 'Désactivé', last: true),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: 0.20)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _kBlue),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Ce module détermine la navigation hors-ligne disponible pour les '
              'écoles selon leur plan d\'abonnement.',
              style: TextStyle(color: _kBlue, fontSize: 12, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _ModActivityTab extends StatelessWidget {
  const _ModActivityTab({required this.module});
  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    final m = module;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TimelineItem(icon: Icons.add_circle_rounded, color: _kGreen,
            title: 'Module créé', date: m.createdAt),
        _TimelineItem(icon: Icons.update_rounded, color: _kNavy,
            title: 'Dernière mise à jour', date: m.updatedAt),
        if (!m.isActive)
          _TimelineItem(icon: Icons.block_rounded, color: _kRed,
              title: 'Module actuellement désactivé', date: m.updatedAt),
      ],
    );
  }
}

// ─── Helpers modal détail ─────────────────────────────────────────────────────

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
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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

class _DCard extends StatelessWidget {
  const _DCard(this.rows);
  final List<_DRow> rows;
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

class _DRow extends StatelessWidget {
  const _DRow(this.icon, this.label, this.value,
      {this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: _kNavy),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(
          color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: _kText, fontSize: mono ? 11.5 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copier',
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copié : $value'),
                    backgroundColor: _kNavy,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

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

class _DSectionTitle extends StatelessWidget {
  const _DSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.icon, required this.color,
      required this.title, required this.date});
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
        Text(title, style: const TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(_fmtDateTime(date), style: const TextStyle(color: _kMuted, fontSize: 11.5)),
      ])),
    ]),
  );
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────

class _ModulePrintPreviewModal extends StatefulWidget {
  const _ModulePrintPreviewModal({required this.module, required this.plans});
  final ModuleItem module;
  final List<PlanInfo> plans;

  @override
  State<_ModulePrintPreviewModal> createState() => _ModulePrintPreviewModalState();
}

class _ModulePrintPreviewModalState extends State<_ModulePrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  ModuleItem get m => widget.module;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await ModulePdfService.printModule(m, plans: widget.plans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur impression : $e'),
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
      final path = await ModulePdfService.downloadModule(m, plans: widget.plans);
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
        content: Text('Erreur téléchargement : $e'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now  = _fmtDateTime(DateTime.now());
    final ref_ = m.id.substring(0, 8).toUpperCase();

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
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            decoration: const BoxDecoration(
              color: _kNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche descriptive du module',
                    style: TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  $now',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65),
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
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => ModulePdfService.buildPdf(m, plans: widget.plans),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Module_${m.name.replaceAll(' ', '_')}.pdf',
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      SizedBox(width: 5),
                      Text('Fermer', style: TextStyle(
                          color: _kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _printing ? null : _handlePrint,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_printing)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))
                      else
                        const Icon(Icons.print_rounded, size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: const TextStyle(color: _kNavy, fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: _downloading ? null : _handleDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(_downloading ? 'Génération…' : 'Télécharger PDF',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5,
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

// ─── Dialog de suppression (générique) ────────────────────────────────────────

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({
    required this.emoji,
    required this.color,
    required this.title,
    required this.name,
    required this.subtitle,
    required this.warning,
    required this.confirmLabel,
  });
  final String emoji, title, name, subtitle, warning, confirmLabel;
  final Color color;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: const TextStyle(
                      color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  const Text('Cette action est irréversible',
                      style: TextStyle(color: _kMuted, fontSize: 11.5)),
                ]),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.color.withValues(alpha: 0.25)),
                    ),
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.name, style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _kText),
                        overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle, style: const TextStyle(
                        fontSize: 12, color: _kMuted)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kRed.withValues(alpha: 0.20)),
                ),
                child: Text(widget.warning,
                    style: const TextStyle(color: _kRed, fontSize: 12.5)),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : Colors.transparent,
                        border: Border.all(
                            color: _confirmed ? _kRed : _kMuted, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _confirmed
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.confirmLabel,
                        style: const TextStyle(fontSize: 12.5, color: _kText))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Annuler', style: TextStyle(
                          color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                  child: InkWell(
                    onTap: _confirmed ? () => Navigator.pop(context, true) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _confirmed ? _kRed : _kMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_forever_rounded,
                            color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                            size: 15),
                        const SizedBox(width: 6),
                        Text('Supprimer définitivement',
                            style: TextStyle(
                                color: _confirmed ? Colors.white : _kMuted.withValues(alpha: 0.5),
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5));
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.validator,
  }) : readOnly = false;
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final String?               hint;
  final TextInputType?        keyboardType;
  final bool                  readOnly;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    readOnly:     readOnly,
    keyboardType: keyboardType,
    onChanged:    onChanged,
    style: TextStyle(fontSize: 13, color: readOnly ? _kMuted : _kText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: _kMuted),
      filled: true,
      fillColor: readOnly ? _kSurface.withValues(alpha: 0.5) : _kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: readOnly
            ? const BorderSide(color: _kBorder)
            : const BorderSide(color: _kNavy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    ),
    validator: validator,
  );
}
