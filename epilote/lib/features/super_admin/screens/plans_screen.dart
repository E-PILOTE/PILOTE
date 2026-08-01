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
      if (mounted) _showError('Erreur : $e');
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
    final async = ref.watch(plansProvider);

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
  final PlansData data;

  @override
  Widget build(BuildContext context) {
    final n        = data.total;
    final inactifs = n - data.actifs;
    final items = [
      _KD(
        label: 'Total Plans', value: '$n',
        sub:   '${data.actifs} actifs · $inactifs inactifs',
        icon:  Icons.inventory_2_rounded, color: _kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Plans actifs', value: '${data.actifs}',
        sub:   'Disponibles à la vente',
        icon:  Icons.check_circle_rounded, color: _kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ En ligne' : '—',
      ),
      _KD(
        label: 'Plans publics', value: '${data.publics}',
        sub:   'Visibles à l\'inscription',
        icon:  Icons.public_rounded, color: _kBlue,
        progressValue: n > 0 ? data.publics / n : 0,
        trend: data.publics > 0 ? '${data.publics} visibles' : '—',
      ),
      _KD(
        label: 'Abonnés totaux', value: '${data.subscribers}',
        sub:   'Groupes scolaires',
        icon:  Icons.groups_rounded, color: _kGold,
        progressValue: data.subscribers > 0 ? 1 : 0,
        trend: data.subscribers > 0 ? 'Souscrits' : 'Aucun',
        trendUp: data.subscribers > 0,
      ),
      _KD(
        label: 'Revenu mensuel', value: '${moneyXaf(data.mrr)} F',
        sub:   'MRR estimé',
        icon:  Icons.payments_rounded, color: _kPurple,
        progressValue: data.mrr > 0 ? 1 : 0,
        trend: data.mrr > 0 ? '📈 Récurrent' : '—',
        trendUp: data.mrr > 0,
      ),
      _KD(
        label: 'Prix moyen', value: '${moneyXaf(data.avgPrice)} F',
        sub:   'Plans payants',
        icon:  Icons.sell_rounded, color: _kOrange,
        progressValue: data.avgPrice > 0 ? 1 : 0,
        trend: data.avgPrice > 0 ? 'par mois' : '—',
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
                        ), overflow: TextOverflow.ellipsis),
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

// ─── Barre de filtres ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.contentWidth,
    required this.searchCtrl,
    required this.filterSlug,
    required this.filterStatus,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onSlug,
    required this.onStatus,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterSlug, filterStatus, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onSlug, onStatus, onSort;
  final VoidCallback onToggleView, onReset, onAdd;

  @override
  Widget build(BuildContext context) {
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
                  hintText: 'Rechercher par nom, type, description…',
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
                    child: Icon(Icons.refresh_rounded, size: 20, color: _kMuted),
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
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Nouveau plan', style: TextStyle(
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
            _FilterDropdown(
              icon: Icons.category_rounded,
              label: 'Type',
              items: const {
                'tous':           'Tous les types',
                'gratuit':        'Gratuit',
                'premium':        'Premium',
                'pro':            'Pro',
                'institutionnel': 'Institutionnel',
              },
              value: filterSlug,
              onChanged: onSlug,
              active: filterSlug != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.radio_button_checked_rounded,
              label: 'Statut',
              items: const {
                'tous':    'Tous les statuts',
                'actif':   'Actifs',
                'inactif': 'Inactifs',
                'public':  'Publics',
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
                'prix':    'Prix croissant',
                'az':      'A → Z',
                'za':      'Z → A',
                'abonnes': 'Plus d\'abonnés',
                'revenu':  'Meilleur revenu',
              },
              value: sort,
              onChanged: onSort,
              active: sort != 'prix',
            ),
            const Spacer(),
            if (filterSlug != 'tous' || filterStatus != 'tous' || sort != 'prix')
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
        dropdownColor: kCardBg,
        icon: Icon(Icons.arrow_drop_down, size: 18,
            color: active ? Colors.white : _kMuted),
        style: TextStyle(
          color: active ? Colors.white : _kMuted,
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
    Text('$filtered résultat${filtered > 1 ? "s" : ""}',
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
    required this.plans,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<PlanDetail> plans;
  final ValueChanged<PlanDetail> onView, onEdit, onDelete, onToggle;

  static const _iconW    = 44.0;
  static const _statusW  = 88.0;
  static const _actionsW = 104.0;

  static Widget _hdr(String label, int flex, {bool center = false}) => Expanded(
    flex: flex,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label, style: TextStyle(
          color: _kMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _EmptyState();

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
              _hdr('Plan',          3),
              // Le tarif porte désormais sa période (« / an », « / mois ») :
              // un en-tête qui l'impose serait faux dès le premier plan
              // mensuel. Cf. `billing_period.dart`.
              _hdr('Tarif',         2),
              _hdr('Périodicité',   2),
              _hdr('Écoles max',    2),
              _hdr('Modules',       2),
              _hdr('Abonnés',       2),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: _kMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...plans.asMap().entries.map((e) => _TableRow(
            plan:     e.value,
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
    required this.plan,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final PlanDetail   plan;
  final bool         isOdd;
  final double       iconW, statusW, actionsW;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
              child: _PlanGlyph(slug: p.slug, size: 36),
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
                  Text(p.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (p.isPublicPlan)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.public_rounded, size: 11,
                            color: _kBlue.withValues(alpha: 0.8)),
                      ),
                    Text(_slugLabel(p.slug),
                        style: TextStyle(fontSize: 10.5,
                            color: color, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          )),
          // Montant nu : la période a sa propre colonne juste à droite.
          Expanded(flex: 2, child: Text(p.priceAmountLabel,
              style: TextStyle(fontSize: 12.5,
                  color: p.isFree ? _kMuted : _kText,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p.periodLabel,
              style: TextStyle(fontSize: 12, color: _kMuted),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p.maxSchoolsLabel,
              style: TextStyle(fontSize: 12, color: _kText),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Row(children: [
            const Icon(Icons.widgets_rounded, size: 13, color: _kPurple),
            const SizedBox(width: 4),
            Text('${p.linkedModules}',
                style: TextStyle(fontSize: 12.5, color: _kText,
                    fontWeight: FontWeight.w600)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(Icons.groups_rounded, size: 13, color: _kGold),
            const SizedBox(width: 4),
            Text('${p.subscribersTotal}',
                style: TextStyle(fontSize: 12.5, color: _kText,
                    fontWeight: FontWeight.w600)),
            if (p.subscribersActive != p.subscribersTotal)
              Text(' (${p.subscribersActive})',
                  style: TextStyle(fontSize: 10.5, color: _kGreen)),
          ])),
          SizedBox(
            width: widget.statusW,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.isActive
                        ? _kGreen.withValues(alpha: 0.10)
                        : _kMuted.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.isActive
                          ? _kGreen.withValues(alpha: 0.35)
                          : _kMuted.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: p.isActive ? _kGreen : _kMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(p.isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: p.isActive ? _kGreen : _kMuted)),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue, tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.delete_rounded, color: _kRed, tooltip: 'Supprimer', onTap: widget.onDelete),
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
    required this.plans,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final List<PlanDetail> plans;
  final ValueChanged<PlanDetail> onView, onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemCount: plans.length,
      itemBuilder: (_, i) => _PlanCard(
        plan:     plans[i],
        onView:   () => onView(plans[i]),
        onEdit:   () => onEdit(plans[i]),
        onDelete: () => onDelete(plans[i]),
        onToggle: () => onToggle(plans[i]),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  final PlanDetail   plan;
  final VoidCallback onView, onEdit, onDelete, onToggle;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
            color: _hovered ? color.withValues(alpha: 0.4) : _kBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: color.withValues(alpha: 0.08),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _PlanGlyph(slug: p.slug, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(p.priceLabel, style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
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
                    color: p.isActive ? _kGreen : _kMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _SlugBadge(slug: p.slug),
            if (p.isPublicPlan)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Public', style: TextStyle(
                    color: _kBlue, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const Spacer(),
          Row(children: [
            _miniStat(Icons.school_rounded, p.maxSchoolsLabel, _kNavy),
            const SizedBox(width: 12),
            _miniStat(Icons.widgets_rounded, '${p.linkedModules} mod.', _kPurple),
            const SizedBox(width: 12),
            _miniStat(Icons.groups_rounded, '${p.subscribersTotal}', _kGold),
          ]),
          const SizedBox(height: 6),
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

  Widget _miniStat(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: _kMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
    ],
  );
}

// ─── Glyphe & badges ──────────────────────────────────────────────────────────

class _PlanGlyph extends StatelessWidget {
  const _PlanGlyph({required this.slug, this.size = 36});
  final String slug;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _slugColor(slug);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Icon(_slugIcon(slug), color: color, size: size * 0.5),
    );
  }
}

class _SlugBadge extends StatelessWidget {
  const _SlugBadge({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final color = _slugColor(slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_slugIcon(slug), size: 11, color: color),
        const SizedBox(width: 4),
        Text(_slugLabel(slug),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
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
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun plan trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouveau plan.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Helpers dates / sections ─────────────────────────────────────────────────

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5));
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final String?               hint;
  final TextInputType?        keyboardType;
  final int                   maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    keyboardType: keyboardType,
    maxLines:     maxLines,
    onChanged:    onChanged,
    style: TextStyle(fontSize: 13, color: _kText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 16, color: _kMuted),
      filled: true,
      fillColor: _kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _kNavy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(12),
    ),
    validator: validator,
  );
}

// ─── Modal création / édition ─────────────────────────────────────────────────

class _PlanFormModal extends ConsumerStatefulWidget {
  const _PlanFormModal({this.editing});
  final PlanDetail? editing;
  @override
  ConsumerState<_PlanFormModal> createState() => _PlanFormModalState();
}

class _PlanFormModalState extends ConsumerState<_PlanFormModal> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _priceCtrl     = TextEditingController();
  final _maxSchoolsCtrl= TextEditingController();
  final _maxStudentsCtrl=TextEditingController();
  final _maxStaffCtrl  = TextEditingController();
  final _descCtrl      = TextEditingController();

  String  _slug      = 'premium';
  String  _period    = kDefaultBillingPeriod;
  bool    _isPublic  = false;
  bool    _isActive  = true;
  bool    _saving    = false;
  Set<String> _selectedModules = {};
  bool    _loadingModules = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    if (p != null) {
      _nameCtrl.text        = p.name;
      _priceCtrl.text       = p.priceXaf.toString();
      _maxSchoolsCtrl.text  = p.maxSchools.toString();
      _maxStudentsCtrl.text = p.maxStudents.toString();
      _maxStaffCtrl.text    = p.maxStaff.toString();
      _descCtrl.text        = p.description ?? '';
      _slug                 = p.slug;
      _period               = p.billingPeriod;
      _isPublic             = p.isPublicPlan;
      _isActive             = p.isActive;
      _loadingModules       = true;
      fetchPlanModuleIds(ref, p.id).then((ids) {
        if (mounted) setState(() { _selectedModules = ids; _loadingModules = false; });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _maxSchoolsCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _maxStaffCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseInt(String s, {int fallback = 0}) =>
      int.tryParse(s.trim().replaceAll(' ', '')) ?? fallback;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':           _nameCtrl.text.trim(),
        'slug':           _slug,
        'price_xaf':      _parseInt(_priceCtrl.text),
        'max_schools':    _parseInt(_maxSchoolsCtrl.text),
        'max_students':   _parseInt(_maxStudentsCtrl.text),
        'max_staff':      _parseInt(_maxStaffCtrl.text),
        'billing_period': _period,
        // `module_count` n'est PAS envoyé : depuis la migration 0076 il est
        // recalculé par trigger à partir de `plan_modules`. Deux écrivains pour
        // un même fait, c'était la dérive garantie — le plan « pro » annonçait
        // 26 modules et en donnait 28.
        'description':    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'is_public_plan': _isPublic,
        'is_active':      _isActive,
        'updated_at':     DateTime.now().toIso8601String(),
      };

      String planId;
      if (_isEditing) {
        await client.from('subscription_plans')
            .update(payload).eq('id', widget.editing!.id);
        planId = widget.editing!.id;
        await client.from('plan_modules').delete().eq('plan_id', planId);
      } else {
        final inserted = await client.from('subscription_plans')
            .insert(payload).select('id').single();
        planId = inserted['id'] as String;
      }

      if (_selectedModules.isNotEmpty) {
        await client.from('plan_modules').insert(
          _selectedModules.map((mid) => {
            'plan_id':   planId,
            'module_id': mid,
          }).toList(),
        );
      }

      ref.invalidate(plansProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(plansProvider).valueOrNull?.modules ?? const [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 580,
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
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), _kNavy]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(
                  _isEditing ? Icons.edit_rounded : Icons.add_rounded,
                  color: Colors.white, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEditing ? 'Modifier le plan' : 'Nouveau plan',
                  style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  _isEditing ? 'Mise à jour de la tarification' : 'Définissez tarifs et quotas',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ]),
              const Spacer(),
              InkWell(
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
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
                ),
              ),
            ]),
          ),
          // Formulaire
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom du plan *',
                    icon: Icons.inventory_2_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Type & Visibilité'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _slug,
                        isExpanded: true,
                        icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
                        style: TextStyle(color: _kText, fontSize: 13),
                        items: _slugLabels.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(children: [
                            Icon(_slugIcon(e.key), size: 14, color: _slugColor(e.key)),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _slug = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Le tarif et sa durée vont ensemble : un montant sans période
                  // ne veut rien dire, et c'est exactement l'ambiguïté qui
                  // faisait facturer un « prix mensuel » pour douze mois.
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 3,
                      child: _FormField(
                        controller: _priceCtrl,
                        label: 'Tarif (FCFA) *',
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        hint: '0 = gratuit',
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            int.tryParse(v!.trim().replaceAll(' ', '')) == null
                                ? 'Nombre requis'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: PlanPeriodPicker(
                      value: _period,
                      onChanged: (v) => setState(() => _period = v),
                    )),
                  ]),
                  const SizedBox(height: 6),
                  PlanPriceEquivalence(
                      priceXaf: _parseInt(_priceCtrl.text), period: _period),
                  const SizedBox(height: 14),
                  const _SectionTitle('Quotas & Limites'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _FormField(
                      controller: _maxSchoolsCtrl,
                      label: 'Écoles max *',
                      icon: Icons.school_rounded,
                      keyboardType: TextInputType.number,
                      hint: '-1 = illimité',
                      validator: validatePlanQuota,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _FormField(
                      controller: _maxStudentsCtrl,
                      label: 'Élèves max *',
                      icon: Icons.groups_rounded,
                      keyboardType: TextInputType.number,
                      hint: '-1 = illimité',
                      validator: validatePlanQuota,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _maxStaffCtrl,
                    label: 'Personnel max *',
                    icon: Icons.badge_rounded,
                    keyboardType: TextInputType.number,
                    hint: '-1 = illimité',
                    validator: validatePlanQuota,
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Modules inclus (${_selectedModules.length})'),
                  const SizedBox(height: 10),
                  _ModulePickerBox(
                    modules: modules,
                    selected: _selectedModules,
                    loading: _loadingModules,
                    onToggle: (id) => setState(() {
                      if (_selectedModules.contains(id)) {
                        _selectedModules.remove(id);
                      } else {
                        _selectedModules.add(id);
                      }
                    }),
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _descCtrl,
                    label: 'Description (optionnel)',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Disponibilité'),
                  const SizedBox(height: 8),
                  _SwitchRow(
                    icon: Icons.public_rounded,
                    label: 'Plan public',
                    sub: 'Visible lors de l\'inscription',
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  _SwitchRow(
                    icon: Icons.check_circle_rounded,
                    label: 'Plan actif',
                    sub: 'Disponible à la souscription',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                    child: Text('Annuler', style: TextStyle(
                        color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: _saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _saving ? [] : [BoxShadow(
                        color: _kNavy.withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      )],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_saving)
                        const SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        _saving ? 'Enregistrement…'
                            : (_isEditing ? 'Enregistrer' : 'Créer le plan'),
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(
        value: value,
        activeThumbColor: _kGreen,
        onChanged: onChanged,
      ),
    ]),
  );
}

class _ModulePickerBox extends StatelessWidget {
  const _ModulePickerBox({
    required this.modules,
    required this.selected,
    required this.loading,
    required this.onToggle,
  });
  final List<ModulePick> modules;
  final Set<String> selected;
  final bool loading;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))),
      );
    }
    if (modules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Text('Aucun module disponible.',
            style: TextStyle(color: _kMuted, fontSize: 12)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: SingleChildScrollView(
        child: Wrap(spacing: 8, runSpacing: 8, children: modules.map((m) {
          final on = selected.contains(m.id);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onToggle(m.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: on ? _kNavy : _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: on ? _kNavy : _kBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(on ? Icons.check_rounded : Icons.add_rounded,
                      size: 13, color: on ? Colors.white : _kMuted),
                  const SizedBox(width: 5),
                  Text(m.name, style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600,
                      color: on ? Colors.white : _kText)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }
}

// ─── Modal détails ────────────────────────────────────────────────────────────

class _PlanDetailModal extends ConsumerStatefulWidget {
  const _PlanDetailModal({
    required this.plan,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onPrint,
  });
  final PlanDetail plan;
  final VoidCallback onEdit, onToggle, onDelete, onPrint;

  @override
  ConsumerState<_PlanDetailModal> createState() => _PlanDetailModalState();
}

class _PlanDetailModalState extends ConsumerState<_PlanDetailModal>
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
    final p = widget.plan;
    final color = _slugColor(p.slug);

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
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              _PlanGlyph(slug: p.slug, size: 66),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(
                    color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _SlugBadge(slug: p.slug),
                  _PlanStatusBadge(isActive: p.isActive),
                  if (p.isPublicPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBlue.withValues(alpha: 0.30)),
                      ),
                      child: const Text('Public', style: TextStyle(
                          color: _kBlue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.payments_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(p.priceLabel, style: TextStyle(
                      color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _ModalIconBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.print_rounded, color: _kMuted, tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                _ModalIconBtn(icon: Icons.close_rounded, color: _kMuted, tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
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
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Modules & Adoption'),
                Tab(text: 'Système'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PlanInfoTab(plan: p),
                _PlanModulesTab(plan: p),
                _PlanSystemTab(plan: p),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              OutlinedButton.icon(
                onPressed: widget.onToggle,
                icon: Icon(p.isActive ? Icons.block_rounded : Icons.check_rounded, size: 16),
                label: Text(p.isActive ? 'Désactiver' : 'Activer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.isActive ? _kOrange : _kGreen,
                  side: BorderSide(color: p.isActive ? _kOrange : _kGreen),
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

// ─── Onglet Informations ────────────────────────────────────────────────────

class _PlanInfoTab extends StatelessWidget {
  const _PlanInfoTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PlanSectionTitle('Tarification'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.payments_outlined, 'Tarif', p.priceLabel),
          _PlanDetailRow(Icons.event_repeat_rounded, 'Périodicité',
              p.periodLabel),
          _PlanDetailRow(Icons.category_outlined, 'Type', _slugLabel(p.slug)),
          _PlanDetailRow(Icons.trending_up_rounded, 'Revenu mensuel généré',
              '${moneyXaf(p.monthlyRevenue)} FCFA', last: true),
        ]),
        const SizedBox(height: 14),
        const _PlanSectionTitle('Quotas & Limites'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.school_rounded, 'Écoles max', p.maxSchoolsLabel),
          _PlanDetailRow(Icons.groups_rounded, 'Élèves max', p.maxStudentsLabel),
          _PlanDetailRow(Icons.badge_rounded, 'Personnel max', p.maxStaffLabel,
              last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _PlanMetaChip(
            icon: _slugIcon(p.slug), label: _slugLabel(p.slug), color: _slugColor(p.slug))),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: p.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            label: p.isActive ? 'Actif' : 'Inactif',
            color: p.isActive ? _kGreen : _kRed)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: p.isPublicPlan ? Icons.public_rounded : Icons.lock_rounded,
            label: p.isPublicPlan ? 'Public' : 'Privé',
            color: p.isPublicPlan ? _kBlue : _kMuted)),
        ]),
        if (p.description != null && p.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const _PlanSectionTitle('Description'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Text(p.description!, style: TextStyle(
                color: _kText, fontSize: 12.5, height: 1.5)),
          ),
        ],
      ]),
    );
  }
}

// ─── Onglet Modules & Adoption ──────────────────────────────────────────────

class _PlanModulesTab extends ConsumerWidget {
  const _PlanModulesTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plan;
    final allModules = ref.watch(plansProvider).valueOrNull?.modules ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _PlanMetaChip(
            icon: Icons.widgets_rounded, label: '${p.linkedModules} modules', color: _kPurple)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: Icons.groups_rounded, label: '${p.subscribersTotal} abonnés', color: _kGold)),
          const SizedBox(width: 8),
          Expanded(child: _PlanMetaChip(
            icon: Icons.check_circle_rounded, label: '${p.subscribersActive} actifs', color: _kGreen)),
        ]),
        const SizedBox(height: 16),
        const _PlanSectionTitle('Modules inclus dans ce plan'),
        const SizedBox(height: 8),
        FutureBuilder<Set<String>>(
          future: fetchPlanModuleIds(ref, p.id),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))),
              );
            }
            final ids = snap.data!;
            final mods = allModules.where((m) => ids.contains(m.id)).toList();
            if (mods.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text('Aucun module rattaché à ce plan.',
                    style: TextStyle(color: _kMuted, fontSize: 12.5)),
              );
            }
            return Wrap(spacing: 8, runSpacing: 8, children: mods.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.widgets_rounded, size: 13, color: _kPurple),
                const SizedBox(width: 6),
                Text(m.name, style: TextStyle(
                    color: _kText, fontSize: 11.5, fontWeight: FontWeight.w600)),
                if (m.categoryName.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('· ${m.categoryName}', style: TextStyle(
                      color: _kMuted, fontSize: 10)),
                ],
              ]),
            )).toList());
          },
        ),
      ]),
    );
  }
}

// ─── Onglet Système ───────────────────────────────────────────────────────────

class _PlanSystemTab extends StatelessWidget {
  const _PlanSystemTab({required this.plan});
  final PlanDetail plan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PlanSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _PlanDetailCard([
          _PlanDetailRow(Icons.tag_rounded, 'UUID', p.id, copyable: true, mono: true),
          _PlanDetailRow(Icons.confirmation_number_outlined, 'Slug', p.slug),
          _PlanDetailRow(Icons.calendar_today_outlined, 'Créé le', _fmtDate(p.createdAt)),
          _PlanDetailRow(Icons.update_outlined, 'Mis à jour', _fmtDate(p.updatedAt), last: true),
        ]),
      ]),
    );
  }
}

// ─── Helpers modal détail ─────────────────────────────────────────────────────

class _PlanStatusBadge extends StatelessWidget {
  const _PlanStatusBadge({required this.isActive});
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

class _PlanDetailCard extends StatelessWidget {
  const _PlanDetailCard(this.rows);
  final List<_PlanDetailRow> rows;

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

class _PlanDetailRow extends StatelessWidget {
  const _PlanDetailRow(this.icon, this.label, this.value,
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
      Text(label, style: TextStyle(
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
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: _kNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

class _PlanMetaChip extends StatelessWidget {
  const _PlanMetaChip({required this.icon, required this.label, required this.color});
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

class _PlanSectionTitle extends StatelessWidget {
  const _PlanSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────

class _PlanPrintPreviewModal extends StatefulWidget {
  const _PlanPrintPreviewModal({required this.plan});
  final PlanDetail plan;

  @override
  State<_PlanPrintPreviewModal> createState() => _PlanPrintPreviewModalState();
}

class _PlanPrintPreviewModalState extends State<_PlanPrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  PlanDetail get p => widget.plan;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await PlanPdfService.printPlan(p);
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
      final path = await PlanPdfService.downloadPlan(p);
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
    final ref_ = p.id.substring(0, 8).toUpperCase();

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
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fiche du plan d\'abonnement',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $ref_  •  ${p.name}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10.5)),
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
              build: (format) => PlanPdfService.buildPdf(p),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Plan_${p.name.replaceAll(' ', '_')}.pdf',
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
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
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close_rounded, size: 13, color: _kMuted),
                      const SizedBox(width: 5),
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
                        SizedBox(width: 13, height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy))
                      else
                        Icon(Icons.print_rounded, size: 14, color: _kNavy),
                      const SizedBox(width: 6),
                      Text(_printing ? 'Impression…' : 'Imprimer',
                          style: TextStyle(color: _kNavy, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
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

// ─── Dialog de suppression ────────────────────────────────────────────────────

class _DeletePlanDialog extends StatefulWidget {
  const _DeletePlanDialog({required this.plan});
  final PlanDetail plan;
  @override
  State<_DeletePlanDialog> createState() => _DeletePlanDialogState();
}

class _DeletePlanDialogState extends State<_DeletePlanDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
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
                  const Text('Suppression du plan',
                      style: TextStyle(color: _kRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Cette action est irréversible',
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
                  _PlanGlyph(slug: p.slug, size: 42),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _kText)),
                    Text(p.priceLabel, style: TextStyle(fontSize: 12, color: _kMuted)),
                    const SizedBox(height: 4),
                    _SlugBadge(slug: p.slug),
                  ]),
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
                child: const Text(
                  'Le plan et ses liaisons de modules seront supprimés '
                  'définitivement de la plateforme.',
                  style: TextStyle(color: _kRed, fontSize: 12.5),
                ),
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
                    Expanded(child: Text(
                      'Je confirme vouloir supprimer définitivement ce plan',
                      style: TextStyle(fontSize: 12.5, color: _kText),
                    )),
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
                      child: Text('Annuler', style: TextStyle(
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
