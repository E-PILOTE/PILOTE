import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/subscriptions_provider.dart';
import '../services/subscription_pdf_service.dart';
import '../../../core/utils/message_erreur.dart';

/// Message lisible d'une erreur base : un garde-fou métier (ex. « Activation
/// refusée : aucun reçu payé… ») remonte via PostgrestException.message — on
/// l'affiche tel quel plutôt que le `toString()` verbeux (code, hint, détails).
String cleanDbError(Object e) =>
    e is PostgrestException ? e.message : e.toString();

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

// ─── Helpers statut ──────────────────────────────────────────────────────────
const _statusLabels = {
  'trial':     'Essai',
  'active':    'Actif',
  'suspended': 'Suspendu',
  'expired':   'Expiré',
  'cancelled': 'Annulé',
};

Color _statusColor(String s) => switch (s) {
  'trial'     => _kGold,
  'active'    => _kGreen,
  'suspended' => _kOrange,
  'expired'   => _kRed,
  'cancelled' => _kMuted,
  _           => _kMuted,
};

IconData _statusIcon(String s) => switch (s) {
  'trial'     => Icons.hourglass_top_rounded,
  'active'    => Icons.check_circle_rounded,
  'suspended' => Icons.pause_circle_rounded,
  'expired'   => Icons.event_busy_rounded,
  'cancelled' => Icons.cancel_rounded,
  _           => Icons.help_rounded,
};

String _statusLabel(String s) => _statusLabels[s] ?? s;

Color _typeColor(String t) => t == 'public' ? _kNavy : _kPurple;
IconData _typeIcon(String t) => t == 'public'
    ? Icons.account_balance_rounded : Icons.business_rounded;

// ─── Écran principal ──────────────────────────────────────────────────────────

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Abonnements',
      child: _SubsBody(),
    );
  }
}

// ─── Body avec state ──────────────────────────────────────────────────────────

class _SubsBody extends ConsumerStatefulWidget {
  const _SubsBody();
  @override
  ConsumerState<_SubsBody> createState() => _SubsBodyState();
}

class _SubsBodyState extends ConsumerState<_SubsBody> {
  final _searchCtrl   = TextEditingController();
  String _filterStatus = 'tous';
  String _filterType   = 'tous';
  String _sort         = 'recent';
  bool   _isTableView  = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SubscriptionDetail> _applyFilters(List<SubscriptionDetail> all) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return all.where((s) {
      if (q.isNotEmpty) {
        final match = s.groupName.toLowerCase().contains(q)
            || s.adminEmail.toLowerCase().contains(q)
            || (s.planName?.toLowerCase().contains(q) ?? false)
            || (s.department?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_filterStatus != 'tous' && s.status != _filterStatus) return false;
      if (_filterType   != 'tous' && s.groupType != _filterType) return false;
      return true;
    }).toList()..sort((a, b) => switch (_sort) {
      'az'       => a.groupName.compareTo(b.groupName),
      'za'       => b.groupName.compareTo(a.groupName),
      'echeance' => (a.end ?? DateTime(2999)).compareTo(b.end ?? DateTime(2999)),
      'revenu'   => b.priceXaf.compareTo(a.priceXaf),
      _          => b.createdAt.compareTo(a.createdAt),
    });
  }

  void _openForm({SubscriptionDetail? editing}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: false,
      builder: (_) => _SubFormModal(editing: editing),
    ).then((_) => ref.invalidate(subscriptionsProvider));
  }

  void _openDetail(SubscriptionDetail s) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _SubDetailModal(
        sub: s,
        onEdit:   () { Navigator.pop(context); _openForm(editing: s); },
        onStatus: (st) { Navigator.pop(context); _setStatus(s, st); },
        onPrint:  () => _printSub(s),
      ),
    );
  }

  void _printSub(SubscriptionDetail s) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _SubPrintPreviewModal(sub: s),
    );
  }

  Future<void> _setStatus(SubscriptionDetail s, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('school_groups').update({
        'subscription_status': status,
        'is_active': status == 'active' || status == 'trial',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', s.id);
      ref.invalidate(subscriptionsProvider);
      if (mounted) _showSuccess('Statut mis à jour : ${_statusLabel(status)}');
    } catch (e) {
      if (mounted) _showError(cleanDbError(e));
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
    final async = ref.watch(subscriptionsProvider);

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
            onPressed: () => ref.invalidate(subscriptionsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (data) => _buildContent(data),
    );
  }

  Widget _buildContent(SubscriptionsData data) {
    final filtered = _applyFilters(data.subscriptions);

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
                filterStatus:   _filterStatus,
                filterType:     _filterType,
                sort:           _sort,
                isTableView:    _isTableView,
                onSearchChange: (_) => setState(() {}),
                onStatus:       (v) => setState(() => _filterStatus = v),
                onType:         (v) => setState(() => _filterType   = v),
                onSort:         (v) => setState(() => _sort         = v),
                onToggleView:   ()  => setState(() => _isTableView  = !_isTableView),
                onReset: () => setState(() {
                  _searchCtrl.clear();
                  _filterStatus = _filterType = 'tous';
                  _sort = 'recent';
                }),
                // ⚠️ NE CRÉE PLUS DE GROUPE ICI. Ce dialogue en créait un sans
                // `tutelle` — donc invisible de son ministère, et ses écoles
                // en héritaient une tutelle nulle : exactement la brèche que
                // les migrations 0155 et 0158 ont fermée. Deux formulaires de
                // création avec des champs différents, c'est la garantie qu'un
                // groupe naît un jour à moitié configuré.
                // Un seul endroit crée un groupe : l'écran des groupes.
                onAdd: () => context.go(Routes.superGroupes),
              ),
              const SizedBox(height: 16),
              _ResultHeader(total: data.total, filtered: filtered.length),
              const SizedBox(height: 12),
              if (_isTableView)
                _TableView(
                  subs:     filtered,
                  onView:   _openDetail,
                  onEdit:   (s) => _openForm(editing: s),
                )
              else
                _CardGrid(
                  subs:     filtered,
                  onView:   _openDetail,
                  onEdit:   (s) => _openForm(editing: s),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

// ─── Helpers monnaie / dates ──────────────────────────────────────────────────

String _money(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$buf';
}

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_moisFr[l.month - 1]} ${l.year}';
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
  final SubscriptionsData data;

  @override
  Widget build(BuildContext context) {
    final n = data.total;
    final items = [
      _KD(
        label: 'Total Abonnements', value: '$n',
        sub:   '${data.actifs} actifs · ${data.trials} essais',
        icon:  Icons.workspace_premium_rounded, color: _kNavy,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: n > 0 ? '${(data.actifs * 100 / n).round()}% actifs' : '—',
      ),
      _KD(
        label: 'Abonnements actifs', value: '${data.actifs}',
        sub:   'Payants en cours',
        icon:  Icons.check_circle_rounded, color: _kGreen,
        progressValue: n > 0 ? data.actifs / n : 0,
        trend: data.actifs > 0 ? '✅ Payants' : '—',
      ),
      _KD(
        label: 'En essai', value: '${data.trials}',
        sub:   'Période d\'essai',
        icon:  Icons.hourglass_top_rounded, color: _kGold,
        progressValue: n > 0 ? data.trials / n : 0,
        trend: data.trials > 0 ? '${data.trials} en test' : 'Aucun',
        trendUp: data.trials > 0,
      ),
      _KD(
        label: 'Inactifs', value: '${data.inactifs}',
        sub:   'Suspendus / expirés / annulés',
        icon:  Icons.pause_circle_rounded, color: _kMuted,
        progressValue: n > 0 ? data.inactifs / n : 0,
        trend: data.inactifs > 0 ? '${data.inactifs} hors-service' : '—',
        trendUp: false,
      ),
      _KD(
        label: 'Expire bientôt', value: '${data.expiringSoon}',
        sub:   'Échéance ≤ 30 jours',
        icon:  Icons.event_busy_rounded, color: _kOrange,
        progressValue: data.actifs > 0 ? data.expiringSoon / data.actifs : 0,
        trend: data.expiringSoon > 0 ? '⚠️ À relancer' : 'OK',
        trendUp: data.expiringSoon == 0,
      ),
      _KD(
        label: 'Revenu mensuel', value: '${_money(data.mrr)} F',
        sub:   'MRR estimé',
        icon:  Icons.payments_rounded, color: _kPurple,
        progressValue: data.mrr > 0 ? 1 : 0,
        trend: data.mrr > 0 ? '📈 Récurrent' : '—',
        trendUp: data.mrr > 0,
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
    required this.filterStatus,
    required this.filterType,
    required this.sort,
    required this.isTableView,
    required this.onSearchChange,
    required this.onStatus,
    required this.onType,
    required this.onSort,
    required this.onToggleView,
    required this.onReset,
    required this.onAdd,
  });

  final double contentWidth;
  final TextEditingController searchCtrl;
  final String filterStatus, filterType, sort;
  final bool   isTableView;
  final ValueChanged<String> onSearchChange, onStatus, onType, onSort;
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
                  hintText: 'Rechercher par groupe, e-mail, plan, département…',
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
                    Text('Nouvel abonnement', style: TextStyle(
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
              icon: Icons.radio_button_checked_rounded,
              label: 'Statut',
              items: const {
                'tous':      'Tous les statuts',
                'trial':     'Essai',
                'active':    'Actif',
                'suspended': 'Suspendu',
                'expired':   'Expiré',
                'cancelled': 'Annulé',
              },
              value: filterStatus,
              onChanged: onStatus,
              active: filterStatus != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.category_rounded,
              label: 'Type',
              items: const {
                'tous':   'Tous les types',
                'public': 'Public',
                'prive':  'Privé',
              },
              value: filterType,
              onChanged: onType,
              active: filterType != 'tous',
            ),
            const SizedBox(width: 8),
            _FilterDropdown(
              icon: Icons.sort_rounded,
              label: 'Trier',
              items: const {
                'recent':   'Plus récents',
                'az':       'A → Z',
                'za':       'Z → A',
                'echeance': 'Échéance proche',
                'revenu':   'Meilleur revenu',
              },
              value: sort,
              onChanged: onSort,
              active: sort != 'recent',
            ),
            const Spacer(),
            if (filterStatus != 'tous' || filterType != 'tous' || sort != 'recent')
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
    required this.subs,
    required this.onView,
    required this.onEdit,
  });

  final List<SubscriptionDetail> subs;
  final ValueChanged<SubscriptionDetail> onView, onEdit;

  static const _iconW    = 48.0;
  static const _statusW  = 100.0;
  static const _actionsW = 76.0;

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
    if (subs.isEmpty) return const _EmptyState();

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
              _hdr('Groupe scolaire', 3),
              _hdr('Plan',            2),
              _hdr('Type',            2),
              _hdr('Échéance',        3),
              _hdr('Écoles',          1),
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
          ...subs.asMap().entries.map((e) => _TableRow(
            sub:      e.value,
            isOdd:    e.key.isOdd,
            iconW:    _iconW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:   () => onView(e.value),
            onEdit:   () => onEdit(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.sub,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
  });
  final SubscriptionDetail sub;
  final bool         isOdd;
  final double       iconW, statusW, actionsW;
  final VoidCallback onView, onEdit;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;

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
              child: _SubGroupGlyph(sub: s, size: 38),
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
                  Text(s.groupName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                      overflow: TextOverflow.ellipsis),
                  Text(s.adminEmail,
                      style: TextStyle(fontSize: 10.5, color: _kMuted),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )),
          Expanded(flex: 2, child: Text(s.planName ?? '—',
              style: TextStyle(fontSize: 12.5,
                  color: s.planName == null ? _kMuted : _kText,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _TypeBadge(type: s.groupType)),
          Expanded(flex: 3, child: Row(children: [
            Icon(Icons.schedule_rounded, size: 13,
                color: s.isOverdue ? _kRed : (s.isExpiringSoon ? _kOrange : _kMuted)),
            const SizedBox(width: 4),
            Flexible(child: Text(s.remainingLabel,
                style: TextStyle(fontSize: 11.5,
                    color: s.isOverdue ? _kRed : (s.isExpiringSoon ? _kOrange : _kText),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 1, child: Row(children: [
            Icon(Icons.school_rounded, size: 13, color: _kNavy),
            const SizedBox(width: 4),
            Text('${s.schoolsCount}',
                style: TextStyle(fontSize: 12.5, color: _kText,
                    fontWeight: FontWeight.w600)),
          ])),
          SizedBox(
            width: widget.statusW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(status: s.status),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: _kBlue, tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.edit_rounded, color: _kNavy, tooltip: 'Modifier', onTap: widget.onEdit),
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
    required this.subs,
    required this.onView,
    required this.onEdit,
  });

  final List<SubscriptionDetail> subs;
  final ValueChanged<SubscriptionDetail> onView, onEdit;

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing:  14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      itemCount: subs.length,
      itemBuilder: (_, i) => _SubCard(
        sub:    subs[i],
        onView: () => onView(subs[i]),
        onEdit: () => onEdit(subs[i]),
      ),
    );
  }
}

class _SubCard extends StatefulWidget {
  const _SubCard({
    required this.sub,
    required this.onView,
    required this.onEdit,
  });
  final SubscriptionDetail sub;
  final VoidCallback onView, onEdit;

  @override
  State<_SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<_SubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final color = _statusColor(s.status);

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
            _SubGroupGlyph(sub: s, size: 44),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.groupName, style: TextStyle(
                    color: _kText, fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(s.planName ?? 'Sans plan', style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _StatusBadge(status: s.status),
            _TypeBadge(type: s.groupType),
          ]),
          const Spacer(),
          Row(children: [
            _miniStat(Icons.school_rounded, '${s.schoolsCount} écoles', _kNavy),
            const SizedBox(width: 12),
            _miniStat(Icons.payments_rounded,
                '${_money(s.priceXaf)} F/${s.periodSuffix}', _kPurple),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 12,
                color: s.isOverdue ? _kRed : (s.isExpiringSoon ? _kOrange : _kMuted)),
            const SizedBox(width: 4),
            Expanded(child: Text(s.remainingLabel, style: TextStyle(
                color: s.isOverdue ? _kRed : (s.isExpiringSoon ? _kOrange : _kMuted),
                fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
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

// ─── Glyphe groupe & badges ───────────────────────────────────────────────────

class _SubGroupGlyph extends StatelessWidget {
  const _SubGroupGlyph({required this.sub, this.size = 38});
  final SubscriptionDetail sub;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(sub.groupType);
    final logo = sub.groupLogo;
    if (logo != null && logo.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: CachedNetworkImage(
          imageUrl: logo,
          width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(color),
          errorWidget: (_, _, _) => _fallback(color),
        ),
      );
    }
    return _fallback(color);
  }

  Widget _fallback(Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(sub.initials, style: TextStyle(
        color: color, fontSize: size * 0.36, fontWeight: FontWeight.w800)),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 11, color: color),
        const SizedBox(width: 4),
        Text(_statusLabel(status),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_typeIcon(type), size: 11, color: color),
        const SizedBox(width: 4),
        Text(type == 'public' ? 'Public' : 'Privé',
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
      Icon(Icons.workspace_premium_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucun abonnement trouvé', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres ou créez un nouvel abonnement.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Sections / champs de formulaire ──────────────────────────────────────────

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
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    keyboardType: keyboardType,
    style: TextStyle(fontSize: 13, color: _kText),
    decoration: InputDecoration(
      labelText: label,
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

class _SubFormModal extends ConsumerStatefulWidget {
  const _SubFormModal({this.editing});
  final SubscriptionDetail? editing;
  @override
  ConsumerState<_SubFormModal> createState() => _SubFormModalState();
}

class _SubFormModalState extends ConsumerState<_SubFormModal> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _deptCtrl   = TextEditingController();

  String    _groupType = 'prive';
  String    _status    = 'trial';
  String?   _planId;
  DateTime? _start;
  DateTime? _end;
  bool      _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.editing;
    if (s != null) {
      _nameCtrl.text  = s.groupName;
      _emailCtrl.text = s.adminEmail;
      _phoneCtrl.text = s.phone ?? '';
      _deptCtrl.text  = s.department ?? '';
      _groupType      = s.groupType;
      _status         = s.status;
      _planId         = s.planId;
      _start          = s.start;
      _end            = s.end;
    } else {
      _start = DateTime.now();
      _end   = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() { if (isStart) { _start = picked; } else { _end = picked; } });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':                _nameCtrl.text.trim(),
        'admin_email':         _emailCtrl.text.trim(),
        'phone':               _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'department':          _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
        'group_type':          _groupType,
        'plan_id':             _planId,
        'subscription_status': _status,
        'subscription_start':  _start?.toIso8601String(),
        'subscription_end':    _end?.toIso8601String(),
        'is_active':           _status == 'active' || _status == 'trial',
        'updated_at':          DateTime.now().toIso8601String(),
      };

      // Ce formulaire MODIFIE l'abonnement d'un groupe existant. Il ne le crée
      // pas : il ne demande ni la tutelle, ni l'agrément, ni le secteur, et un
      // groupe amputé de sa tutelle n'apparaît dans le réseau d'aucun ministère.
      if (!_isEditing) {
        throw StateError(
            'Ce formulaire ne crée pas de groupe : passer par « Groupes '
            'Scolaires », seul endroit qui demande la tutelle.');
      }
      await client.from('school_groups')
          .update(payload).eq('id', widget.editing!.id);

      ref.invalidate(subscriptionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cleanDbError(e)),
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
    final plans = ref.watch(subscriptionsProvider).valueOrNull?.plans ?? const [];

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
                  _isEditing ? 'Modifier l\'abonnement' : 'Nouvel abonnement',
                  style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Mise à jour du groupe scolaire',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FormField(
                    controller: _nameCtrl,
                    label: 'Nom du groupe *',
                    icon: Icons.business_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _emailCtrl,
                    label: 'E-mail administrateur *',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _FormField(
                      controller: _phoneCtrl,
                      label: 'Téléphone',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _FormField(
                      controller: _deptCtrl,
                      label: 'Département',
                      icon: Icons.location_on_rounded,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  const _SectionTitle('Type d\'établissement'),
                  const SizedBox(height: 10),
                  _FormDropdown<String>(
                    value: _groupType,
                    icon: _typeIcon(_groupType),
                    items: const {'public': 'Public', 'prive': 'Privé'},
                    onChanged: (v) => setState(() => _groupType = v),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Plan d\'abonnement'),
                  const SizedBox(height: 10),
                  _PlanDropdown(
                    plans: plans,
                    value: _planId,
                    onChanged: (v) => setState(() => _planId = v),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Statut'),
                  const SizedBox(height: 10),
                  _FormDropdown<String>(
                    value: _status,
                    icon: _statusIcon(_status),
                    iconColor: _statusColor(_status),
                    items: const {
                      'trial':     'Essai',
                      'active':    'Actif',
                      'suspended': 'Suspendu',
                      'expired':   'Expiré',
                      'cancelled': 'Annulé',
                    },
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Période d\'abonnement'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _DateField(
                      label: 'Début',
                      value: _start,
                      onTap: () => _pickDate(isStart: true),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _DateField(
                      label: 'Fin',
                      value: _end,
                      onTap: () => _pickDate(isStart: false),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
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
                            : (_isEditing ? 'Enregistrer' : 'Créer l\'abonnement'),
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

class _FormDropdown<T> extends StatelessWidget {
  const _FormDropdown({
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.iconColor,
  });
  final T value;
  final IconData icon;
  final Color? iconColor;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _kSurface,
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
        style: TextStyle(color: _kText, fontSize: 13),
        items: items.entries.map((e) => DropdownMenuItem<T>(
          value: e.key,
          child: Row(children: [
            Icon(icon, size: 14, color: iconColor ?? _kNavy),
            const SizedBox(width: 8),
            Text(e.value),
          ]),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

class _PlanDropdown extends StatelessWidget {
  const _PlanDropdown({
    required this.plans,
    required this.value,
    required this.onChanged,
  });
  final List<PlanOption> plans;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _kSurface,
      border: Border.all(color: _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, size: 18, color: _kMuted),
        style: TextStyle(color: _kText, fontSize: 13),
        hint: Text('Sélectionner un plan', style: TextStyle(color: _kMuted, fontSize: 13)),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Row(children: [
              Icon(Icons.block_rounded, size: 14, color: _kMuted),
              const SizedBox(width: 8),
              const Text('Aucun plan'),
            ]),
          ),
          ...plans.map((p) => DropdownMenuItem<String?>(
            value: p.id,
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, size: 14, color: _kPurple),
              const SizedBox(width: 8),
              Flexible(child: Text(
                '${p.name} · ${p.priceLabel}',
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          )),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 15, color: _kMuted),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: _kMuted, fontSize: 10)),
            Text(_fmtDate(value), style: TextStyle(
                color: _kText, fontSize: 12.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    ),
  );
}

// ─── Modal détails ────────────────────────────────────────────────────────────

class _SubDetailModal extends ConsumerStatefulWidget {
  const _SubDetailModal({
    required this.sub,
    required this.onEdit,
    required this.onStatus,
    required this.onPrint,
  });
  final SubscriptionDetail sub;
  final VoidCallback onEdit, onPrint;
  final ValueChanged<String> onStatus;

  @override
  ConsumerState<_SubDetailModal> createState() => _SubDetailModalState();
}

class _SubDetailModalState extends ConsumerState<_SubDetailModal>
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
    final s = widget.sub;
    final color = _statusColor(s.status);

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
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              _SubGroupGlyph(sub: s, size: 66),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.groupName, style: TextStyle(
                    color: _kText, fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _StatusBadge(status: s.status),
                  _TypeBadge(type: s.groupType),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.email_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                  Flexible(child: Text(s.adminEmail, style: TextStyle(
                      color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
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
          Container(
            color: _kSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Groupe'),
                Tab(text: 'Abonnement'),
                Tab(text: 'Système'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SubGroupTab(sub: s),
                _SubSubscriptionTab(sub: s),
                _SubSystemTab(sub: s),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              _StatusMenuButton(current: s.status, onSelect: widget.onStatus),
              const Spacer(),
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

class _StatusMenuButton extends StatelessWidget {
  const _StatusMenuButton({required this.current, required this.onSelect});
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onSelect,
    tooltip: 'Changer le statut',
    itemBuilder: (_) => _statusLabels.entries
        .where((e) => e.key != current)
        .map((e) => PopupMenuItem<String>(
              value: e.key,
              child: Row(children: [
                Icon(_statusIcon(e.key), size: 15, color: _statusColor(e.key)),
                const SizedBox(width: 8),
                Text(e.value),
              ]),
            ))
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: _statusColor(current)),
        borderRadius: BorderRadius.circular(8),
        color: _statusColor(current).withValues(alpha: 0.06),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: _statusColor(current)),
        const SizedBox(width: 6),
        Text('Changer le statut', style: TextStyle(
            color: _statusColor(current), fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// ─── Onglet Groupe ────────────────────────────────────────────────────────────

class _SubGroupTab extends StatelessWidget {
  const _SubGroupTab({required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SubSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        _SubDetailCard([
          _SubDetailRow(Icons.business_rounded, 'Nom du groupe', s.groupName),
          _SubDetailRow(Icons.email_outlined, 'E-mail admin', s.adminEmail, copyable: true),
          _SubDetailRow(Icons.phone_rounded, 'Téléphone', s.phone ?? '—'),
          _SubDetailRow(Icons.location_on_outlined, 'Département', s.department ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SubMetaChip(
            icon: _typeIcon(s.groupType), label: s.groupTypeLabel, color: _typeColor(s.groupType))),
          const SizedBox(width: 8),
          Expanded(child: _SubMetaChip(
            icon: Icons.school_rounded, label: '${s.schoolsCount} école(s)', color: _kNavy)),
          const SizedBox(width: 8),
          Expanded(child: _SubMetaChip(
            icon: _statusIcon(s.status), label: s.statusLabel, color: _statusColor(s.status))),
        ]),
      ]),
    );
  }
}

// ─── Onglet Abonnement ──────────────────────────────────────────────────────

class _SubSubscriptionTab extends StatelessWidget {
  const _SubSubscriptionTab({required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SubSectionTitle('Plan & Tarification'),
        const SizedBox(height: 8),
        _SubDetailCard([
          _SubDetailRow(Icons.workspace_premium_rounded, 'Plan', s.planName ?? '—'),
          _SubDetailRow(Icons.payments_outlined, 'Prix mensuel',
              s.priceLabel),
          _SubDetailRow(Icons.radio_button_checked_rounded, 'Statut', s.statusLabel, last: true),
        ]),
        const SizedBox(height: 14),
        const _SubSectionTitle('Période'),
        const SizedBox(height: 8),
        _SubDetailCard([
          _SubDetailRow(Icons.play_circle_outline_rounded, 'Début', _fmtDate(s.start)),
          _SubDetailRow(Icons.stop_circle_outlined, 'Fin', _fmtDate(s.end)),
          _SubDetailRow(Icons.timelapse_rounded, 'Échéance', s.remainingLabel, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SubMetaChip(
            icon: s.isOverdue ? Icons.error_rounded : Icons.check_circle_rounded,
            label: s.isOverdue ? 'En retard' : (s.isExpiringSoon ? 'Expire bientôt' : 'À jour'),
            color: s.isOverdue ? _kRed : (s.isExpiringSoon ? _kOrange : _kGreen))),
          const SizedBox(width: 8),
          Expanded(child: _SubMetaChip(
            icon: Icons.payments_rounded,
            // « / mois » était faux : le même montant est facturé pour un an.
            label: '${_money(s.priceXaf)} F / ${s.periodSuffix}',
            color: _kPurple)),
        ]),
      ]),
    );
  }
}

// ─── Onglet Système ───────────────────────────────────────────────────────────

class _SubSystemTab extends StatelessWidget {
  const _SubSystemTab({required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SubSectionTitle('Identité système'),
        const SizedBox(height: 8),
        _SubDetailCard([
          _SubDetailRow(Icons.tag_rounded, 'UUID', s.id, copyable: true, mono: true),
          if (s.planId != null)
            _SubDetailRow(Icons.confirmation_number_outlined, 'Plan ID', s.planId!, mono: true),
          if (s.planSlug != null)
            _SubDetailRow(Icons.label_outline_rounded, 'Plan slug', s.planSlug!),
          _SubDetailRow(Icons.calendar_today_outlined, 'Créé le', _fmtDate(s.createdAt)),
          _SubDetailRow(Icons.update_outlined, 'Mis à jour', _fmtDate(s.updatedAt), last: true),
        ]),
      ]),
    );
  }
}

// ─── Helpers modal détail ─────────────────────────────────────────────────────

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

class _SubDetailCard extends StatelessWidget {
  const _SubDetailCard(this.rows);
  final List<Widget> rows;

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

class _SubDetailRow extends StatelessWidget {
  const _SubDetailRow(this.icon, this.label, this.value,
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

class _SubMetaChip extends StatelessWidget {
  const _SubMetaChip({required this.icon, required this.label, required this.color});
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

class _SubSectionTitle extends StatelessWidget {
  const _SubSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: _kNavy, fontSize: 13, fontWeight: FontWeight.w800));
}

// ─── Modal aperçu / impression PDF ───────────────────────────────────────────

class _SubPrintPreviewModal extends StatefulWidget {
  const _SubPrintPreviewModal({required this.sub});
  final SubscriptionDetail sub;

  @override
  State<_SubPrintPreviewModal> createState() => _SubPrintPreviewModalState();
}

class _SubPrintPreviewModalState extends State<_SubPrintPreviewModal> {
  bool _printing    = false;
  bool _downloading = false;

  SubscriptionDetail get s => widget.sub;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await SubscriptionPdfService.printSubscription(s);
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
      final path = await SubscriptionPdfService.downloadSubscription(s);
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

  @override
  Widget build(BuildContext context) {
    final refLabel = s.id.substring(0, 8).toUpperCase();

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
                const Text('Fiche d\'abonnement',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Réf. $refLabel  •  ${s.groupName}',
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
              build: (format) => SubscriptionPdfService.buildPdf(s),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              maxPageWidth: 680,
              pdfFileName: 'Abonnement_${s.groupName.replaceAll(' ', '_')}.pdf',
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
