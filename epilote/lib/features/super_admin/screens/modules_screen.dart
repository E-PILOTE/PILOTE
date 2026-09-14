import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/modules_provider.dart';
import '../services/module_pdf_service.dart';
import '../../../core/utils/message_erreur.dart';

part 'modules/module_category_form.dart';
part 'modules/module_delete_dialog.dart';
part 'modules/module_detail_modal.dart';
part 'modules/module_detail_tabs.dart';
part 'modules/module_form_bits.dart';
part 'modules/module_form_modal.dart';
part 'modules/module_print_preview.dart';
part 'modules/modules_cards.dart';
part 'modules/modules_categories.dart';
part 'modules/modules_filter_bar.dart';
part 'modules/modules_form_fields.dart';
part 'modules/modules_kpis.dart';
part 'modules/modules_table.dart';

// ─── Design tokens (identiques à administrators_screen) ──────────────────────
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

// ─── Palette catégories (cyclée par ordre) ───────────────────────────────────
List<Color> get _catPalette => [
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
      if (mounted) _showError(messageErreur(e));
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
      if (mounted) _showError(messageErreur(e));
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
      if (mounted) _showError(messageErreur(e));
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
          Icon(Icons.cloud_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(messageErreur(e), style: TextStyle(color: _kMuted)),
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
