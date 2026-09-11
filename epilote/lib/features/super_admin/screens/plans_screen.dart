import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/utils/billing_period.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/plans_provider.dart';
import '../services/plan_pdf_service.dart';
import '../widgets/plan_period_fields.dart';
import '../../../core/utils/message_erreur.dart';
import '../../../core/utils/tarif_ecoles.dart';

part 'plans/plan_delete_dialog.dart';
part 'plans/plan_detail_modal.dart';
part 'plans/plan_detail_tabs.dart';
part 'plans/plan_form_extras.dart';
part 'plans/plan_form_modal.dart';
part 'plans/plan_print_preview.dart';
part 'plans/plans_cards.dart';
part 'plans/plans_filter_bar.dart';
part 'plans/plans_form_bits.dart';
part 'plans/plans_kpis.dart';
part 'plans/plans_table.dart';

part 'plans/plan_tranches_fields.dart';

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

// ─── Helpers slug ────────────────────────────────────────────────────────────
const _slugLabels = {
  'gratuit':       'Gratuit',
  'premium':       'Premium',
  'pro':           'Pro',
  'institutionnel':'Institutionnel',
};

Color _slugColor(String slug) => switch (slug) {
  'gratuit'        => _kMuted,
  'premium'        => _kBlue,
  'pro'            => _kPurple,
  'institutionnel' => _kNavy,
  _                => _kMuted,
};

IconData _slugIcon(String slug) => switch (slug) {
  'gratuit'        => Icons.card_giftcard_rounded,
  'premium'        => Icons.workspace_premium_rounded,
  'pro'            => Icons.rocket_launch_rounded,
  'institutionnel' => Icons.account_balance_rounded,
  _                => Icons.inventory_2_rounded,
};

String _slugLabel(String slug) => _slugLabels[slug] ?? slug;

// ─── Écran principal ──────────────────────────────────────────────────────────

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: "Plans d'abonnement",
      child: _PlansBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _PlansBody extends ConsumerStatefulWidget {
  const _PlansBody();
  @override
  ConsumerState<_PlansBody> createState() => _PlansBodyState();
}

class _PlansBodyState extends ConsumerState<_PlansBody> {
  final _searchCtrl   = TextEditingController();
  String _filterSlug   = 'tous';
  String _filterStatus = 'tous';
  String _sort         = 'prix';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PlanDetail> _applyFilters(List<PlanDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((p) {
      if (q.isNotEmpty) {
        final match = p.name.toLowerCase().contains(q)
            || p.slug.toLowerCase().contains(q)
            || (p.description?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterSlug   != 'tous' && p.slug != _filterSlug) return false;
      if (_filterStatus == 'actif'   && !p.isActive) return false;
      if (_filterStatus == 'inactif' &&  p.isActive) return false;
      if (_filterStatus == 'public'  && !p.isPublicPlan) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'      => a.name.compareTo(b.name),
      'za'      => b.name.compareTo(a.name),
      'abonnes' => b.subscribersTotal.compareTo(a.subscribersTotal),
      'revenu'  => b.monthlyRevenue.compareTo(a.monthlyRevenue),
      _         => a.priceXaf.compareTo(b.priceXaf),
    });
  }

  void _openForm({PlanDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _PlanFormModal(editing: editing),
    ).then((_) => ref.invalidate(plansProvider));
  }

  void _openDetail(PlanDetail p) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _PlanDetailModal(
        plan: p,
        onEdit:   () { Navigator.pop(context); _openForm(editing: p); },
        onToggle: () { Navigator.pop(context); _toggleActive(p); },
        onDelete: () { Navigator.pop(context); _confirmDelete(p); },
        onPrint:  () => _printPlan(p),
      ),
    );
  }

  void _printPlan(PlanDetail p) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _PlanPrintPreviewModal(plan: p),
    );
  }

  Future<void> _toggleActive(PlanDetail p) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('subscription_plans')
          .update({'is_active': !p.isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', p.id);
      ref.invalidate(plansProvider);
    } catch (e) {
      if (mounted) _showError(messageErreur(e));
    }
  }

  Future<void> _confirmDelete(PlanDetail p) async {
    if (p.subscribersTotal > 0) {
      _showError('Impossible : ${p.subscribersTotal} groupe(s) utilisent ce plan.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeletePlanDialog(plan: p),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('plan_modules').delete().eq('plan_id', p.id);
      await client.from('subscription_plans').delete().eq('id', p.id);
      ref.invalidate(plansProvider);
      if (mounted) _showSuccess('Plan "${p.name}" supprimé.');
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
    final async = ref.watch(plansProvider);

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
            onPressed: () => ref.invalidate(plansProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(PlansData data) {
    final filtered = _applyFilters(data.plans);

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
                filterSlug:     _filterSlug,
                filterStatus:   _filterStatus,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onSlug:         (v) => setState(() => _filterSlug   = v),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterSlug = _filterStatus = 'tous';
                  _sort = 'prix';
                }),
                onAdd: () => _openForm(),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                _TableView(
                  plans:    filtered,
                  onView:   _openDetail,
                  onEdit:   (p) => _openForm(editing: p),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                )
              else
                _CardGrid(
                  plans:    filtered,
                  onView:   _openDetail,
                  onEdit:   (p) => _openForm(editing: p),
                  onDelete: _confirmDelete,
                  onToggle: _toggleActive,
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── KPI Grid — 6 cartes 3×2 ─────────────────────────────────────────────────
