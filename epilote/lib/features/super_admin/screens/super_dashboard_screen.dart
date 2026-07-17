import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import '../providers/super_dashboard_provider.dart';
import 'national_map_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
Color get _kRed => kRed;
Color get _kCard => kCardBg;
Color get _kBg => kSurface;
Color get _kText => kTextPrimary;
Color get _kMuted => kTextMuted;
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);
const _kOrange = Color(0xFFF97316);

// ─── Couleurs département & plan ─────────────────────────────────────────────
Map<String, Color> get _kDeptColors => {
  'Brazzaville': _kNavy,   'Pointe-Noire': _kBlue,
  'Dolisie':     _kTeal,   'Pool':         _kGreen,
  'Plateaux':    _kPurple, 'Kouilou':      const Color(0xFF0EA5E9),
  'Sangha':      _kOrange, 'Niari':        const Color(0xFFEC4899),
  'Bouenza':     const Color(0xFF84CC16), 'Autres': _kGold,
};
Color _deptColor(String d) => _kDeptColors[d] ?? _kMuted;

Map<String, Color> get _kPlanColors => {
  'Institutionnel': _kNavy, 'Premium': _kBlue,
  'Pro':            _kTeal, 'Gratuit': _kGold,
};
Color _planColor(String p) {
  for (final e in _kPlanColors.entries) {
    if (p.toLowerCase().contains(e.key.toLowerCase())) return e.value;
  }
  return _kMuted;
}

// ─── Écran principal ──────────────────────────────────────────────────────────
class SuperDashboardScreen extends ConsumerWidget {
  const SuperDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: 'Tableau de bord', child: _DashboardBody());
}

// Onglet actif du tableau de bord : 0 = vue d'ensemble, 1 = vue nationale
final _dashTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_dashTabProvider);
    return Container(
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardTabs(active: tab),
          Expanded(
            child: tab == 0 ? const _OverviewTab() : const NationalMapView(),
          ),
        ],
      ),
    );
  }
}

// ─── Sélecteur d'onglets (Vue d'ensemble / Vue Nationale) ────────────────────
class _DashboardTabs extends ConsumerWidget {
  const _DashboardTabs({required this.active});
  final int active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(children: [
        _TabChip(
          icon: Icons.dashboard_rounded,
          label: "Vue d'ensemble",
          selected: active == 0,
          onTap: () => ref.read(_dashTabProvider.notifier).state = 0,
        ),
        const SizedBox(width: 10),
        _TabChip(
          icon: Icons.public_rounded,
          label: 'Vue Nationale',
          selected: active == 1,
          onTap: () => ref.read(_dashTabProvider.notifier).state = 1,
        ),
      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
  });
  final IconData icon; final String label;
  final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kNavy : _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _kNavy : kBorder),
          boxShadow: selected ? [BoxShadow(
              color: _kNavy.withValues(alpha: 0.25),
              blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : _kMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kMuted)),
        ]),
      ),
    ),
  );
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(superDashboardProvider);
    final profile    = ref.watch(authNotifierProvider).valueOrNull;
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing  = syncStatus.valueOrNull?.connected ?? false;

    return statsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const _LoadingState(),
      error:   (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(superDashboardProvider)),
      data: (stats) => Container(
        color: _kBg,
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(profile: profile),
                const SizedBox(height: 20),
                _QuickActions(),
                const SizedBox(height: 20),
                if (stats.expirantDans30j > 0) ...[
                  _AlertesSection(stats: stats),
                  const SizedBox(height: 20),
                ],
                _KpiGrid(stats: stats, isSyncing: isSyncing),
                const SizedBox(height: 22),
                _AiInsightsPanel(stats: stats),
                const SizedBox(height: 22),
                _RevenueSection(stats: stats),
                const SizedBox(height: 22),
                _ChartsRow(stats: stats),
                const SizedBox(height: 22),
                _BottomRow(stats: stats),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 1 · En-tête ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final day       = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now);
    final firstName = _first(profile?.fullName as String?);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kNavy, const Color(0xFF2D5A8E)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: _kNavy.withValues(alpha: 0.28),
            blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greet(now.hour)}${firstName.isNotEmpty ? ', $firstName' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: Color(0xFF93C5FD)),
              const SizedBox(width: 5),
              Text(day, style: const TextStyle(
                  color: Color(0xFF93C5FD), fontSize: 12)),
            ]),
          ],
        )),
        Row(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ...[_kGreen, _kGold, _kRed].map((c) => Container(
              width: 28, height: 4,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2)),
            )),
          ]),
          const SizedBox(width: 14),
          Consumer(builder: (_, ref, _) => Tooltip(
            message: 'Actualiser',
            child: InkWell(
              onTap: () => ref.invalidate(superDashboardProvider),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
          )),
        ]),
      ]),
    );
  }

  String _first(String? n) =>
      n == null || n.isEmpty ? '' : n.trim().split(RegExp(r'\s+')).first;
  String _greet(int h) => h >= 5 && h < 12 ? 'Bonjour'
      : h >= 12 && h < 18 ? 'Bon après-midi'
      : h >= 18 && h < 22 ? 'Bonsoir' : 'Bonne nuit';
}

// ─── 2 · Actions rapides ──────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  _QuickActions();

  final _actions = [
    _QA('Nouveau groupe', Icons.add_business_rounded,  _kNavy,   Routes.superGroupes),
    const _QA('Nouvel admin',   Icons.person_add_rounded,    _kBlue,   Routes.superAdministrateurs),
    const _QA('Créer un plan',  Icons.inventory_2_rounded,   _kTeal,   Routes.superPlans),
    _QA('Abonnements',    Icons.verified_rounded,      _kGreen,  Routes.superAbonnements),
    const _QA('Factures',       Icons.receipt_long_rounded,  _kPurple, Routes.superFactures),
    const _QA('Rapports',       Icons.bar_chart_rounded,     _kOrange, Routes.superRapports),
  ];

  @override
  Widget build(BuildContext context) => _Card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(Icons.flash_on_rounded, size: 15, color: _kGold),
        const SizedBox(width: 7),
        Text('Actions rapides', style: TextStyle(
            color: _kText, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 8,
          children: _actions.map((a) => _QaChip(action: a)).toList()),
    ],
  ));
}

class _QA {
  const _QA(this.label, this.icon, this.color, this.route);
  final String label; final IconData icon;
  final Color color;  final String route;
}

class _QaChip extends StatefulWidget {
  const _QaChip({required this.action});
  final _QA action;
  @override
  State<_QaChip> createState() => _QaChipState();
}
class _QaChipState extends State<_QaChip> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => context.go(a.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hov ? a.color : a.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hov ? a.color : a.color.withValues(alpha: 0.28)),
            boxShadow: _hov ? [BoxShadow(
                color: a.color.withValues(alpha: 0.30),
                blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(a.icon, size: 15, color: _hov ? Colors.white : a.color),
            const SizedBox(width: 7),
            Text(a.label, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: _hov ? Colors.white : a.color)),
          ]),
        ),
      ),
    );
  }
}

// ─── 3 · Alertes ─────────────────────────────────────────────────────────────
class _AlertesSection extends StatelessWidget {
  const _AlertesSection({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    final expiring = stats.deptStats
        .expand((d) => d.groups)
        .where((g) => g.expiresBientot)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [BoxShadow(
            color: _kOrange.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats.expirantDans30j} abonnement'
              '${stats.expirantDans30j > 1 ? 's' : ''} '
              'expirant dans les 30 prochains jours',
              style: const TextStyle(color: Color(0xFF92400E),
                  fontSize: 13, fontWeight: FontWeight.w700)),
            if (expiring.isNotEmpty)
              Text(expiring.map((g) => g.name).join(' · '),
                  style: const TextStyle(color: Color(0xFFC2410C), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ],
        )),
        TextButton.icon(
          onPressed: () => context.go(Routes.superAbonnements),
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: const Text('Gérer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: _kOrange),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4 · KPI GRID — chaque carte a son propre type de graphique
// ═══════════════════════════════════════════════════════════════════════════════

// Type de sparkline — chaque KPI a le sien
enum _SparkType { spline, splineArea, column, barH, progress }

class _KD {
  _KD({
    required this.icon,
    required this.color,
    required this.rawValue,
    required this.format,
    required this.label,
    required this.trend,
    required this.trendUp,
    this.sub,
    this.sparkType = _SparkType.splineArea,
    this.pts        = const [],
    this.barsData   = const [],
    this.progressMax = 100.0,
  });
  final IconData                    icon;
  final Color                       color;
  final double                      rawValue;
  final String Function(double)     format;
  final String                      label;
  final String                      trend;
  final bool                        trendUp;
  final String?                     sub;
  final _SparkType                  sparkType;
  final List<MonthlyPoint>          pts;
  final List<MapEntry<String, int>> barsData;
  final double                      progressMax;
}

bool _hasSpark(_KD d) {
  switch (d.sparkType) {
    case _SparkType.spline:
    case _SparkType.splineArea:
    case _SparkType.column:
      return d.pts.length >= 2;
    case _SparkType.barH:
      return d.barsData.isNotEmpty;
    case _SparkType.progress:
      return true;
  }
}

Widget _buildSparkline(_KD d, int idx) {
  final delay = 420 + 70 * idx;
  switch (d.sparkType) {
    case _SparkType.spline:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.splineArea:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.column:
      return _SparkChart(pts: d.pts, color: d.color, type: d.sparkType);
    case _SparkType.barH:
      return _SparkBarH(data: d.barsData, color: d.color, delayMs: delay);
    case _SparkType.progress:
      return _SparkProgress(
          value: d.rawValue, max: d.progressMax,
          color: d.color, delayMs: delay);
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.isSyncing});
  final SuperDashboardData stats;
  final bool               isSyncing;

  @override
  Widget build(BuildContext context) {
    final items = [
      // 1 · Groupes actifs — SplineSeries (ligne fine, tendance mensuelle)
      _KD(
        icon: Icons.school_rounded, color: _kNavy,
        rawValue: stats.groupesActifs.toDouble(),
        format: (v) => _fmt(v.round()),
        label: 'Groupes actifs',
        sub: '${stats.groupesTotal} au total',
        trend: '↑ dynamique', trendUp: true,
        sparkType: _SparkType.spline,
        pts: stats.trendGroupes,
      ),
      // 2 · Écoles actives — ColumnSeries (colonnes verticales par mois)
      _KD(
        icon: Icons.domain_rounded, color: _kTeal,
        rawValue: stats.ecolesTotal.toDouble(),
        format: (v) => _fmt(v.round()),
        label: 'Écoles actives',
        trend: '↑ croissance', trendUp: true,
        sparkType: _SparkType.column,
        pts: stats.trendEcoles,
      ),
      // 3 · Élèves total — SplineAreaSeries (zone remplie, volume)
      _KD(
        icon: Icons.people_alt_rounded, color: _kBlue,
        rawValue: stats.elevesTotal.toDouble(),
        format: (v) => _fmtLg(v.round()),
        label: 'Élèves total',
        trend: '↑ inscriptions', trendUp: true,
        sparkType: _SparkType.splineArea,
        pts: stats.trendEleves,
      ),
      // 4 · Personnel — BarH (barres horizontales par rôle)
      _KD(
        icon: Icons.badge_rounded, color: _kPurple,
        rawValue: stats.personnelTotal.toDouble(),
        format: (v) => _fmt(v.round()),
        label: 'Personnel actif',
        trend: '↑ +8%', trendUp: true,
        sparkType: _SparkType.barH,
        barsData: stats.personnelByRole,
      ),
      // 5 · Revenus — SplineAreaSeries dégradé gold (masse financière)
      _KD(
        icon: Icons.account_balance_rounded, color: _kGold,
        rawValue: stats.revenusXafMois,
        format: (v) => _fmtRevenu(v),
        label: 'Revenus XAF/mois',
        sub: 'FCFA · abonnements actifs',
        trend: '↑ revenus', trendUp: true,
        sparkType: _SparkType.splineArea,
        pts: stats.trendRevenus,
      ),
      // 6 · Abonnements — BarH (barres horizontales par statut)
      _KD(
        icon: Icons.verified_rounded, color: _kGreen,
        rawValue: stats.abonnementsActifs.toDouble(),
        format: (v) => _fmt(v.round()),
        label: 'Abonnements actifs',
        trend: stats.expirantDans30j > 0
            ? '⚠ ${stats.expirantDans30j} expirent' : '✅ À jour',
        trendUp: stats.expirantDans30j == 0,
        sparkType: _SparkType.barH,
        barsData: stats.abonnementsByStatus,
      ),
      // 7 · Sync — barre de progression animée avec glow
      _KD(
        icon: Icons.sync_rounded, color: _kBlue,
        rawValue: stats.syncRate,
        format: (v) => '${v.toStringAsFixed(1)}%',
        label: 'Sync réussie',
        trend: isSyncing ? '✅ En ligne' : '⚡ Hors ligne',
        trendUp: isSyncing,
        sparkType: _SparkType.progress,
        progressMax: 100.0,
      ),
      // 8 · SLA — barre de progression animée avec glow
      _KD(
        icon: Icons.shield_rounded, color: _kTeal,
        rawValue: stats.slaRate,
        format: (v) => '${v.toStringAsFixed(1)}%',
        label: 'Disponibilité SLA',
        trend: '✅ Nominal', trendUp: true,
        sparkType: _SparkType.progress,
        progressMax: 100.0,
      ),
    ];

    return LayoutBuilder(builder: (_, c) {
      final w    = c.maxWidth;
      final cols = w > 900 ? 4 : w > 600 ? 3 : 2;
      final gaps = (cols - 1) * 14.0;
      final ratio = ((w - gaps) / cols / 150.0).clamp(1.0, 4.0);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: ratio,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _KpiCard(d: items[i], idx: i),
      );
    });
  }
}

// ─── Carte KPI premium ────────────────────────────────────────────────────────
class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.d, required this.idx});
  final _KD d;
  final int idx;
  @override
  State<_KpiCard> createState() => _KpiCardState();
}
class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 70 * widget.idx), () {
      if (mounted) _entry.forward();
    });
  }
  @override
  void dispose() { _entry.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d     = widget.d;
    final spark = _hasSpark(d);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hov = true),
          onExit:  (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hov
                    ? d.color.withValues(alpha: 0.42)
                    : d.color.withValues(alpha: 0.14),
                width: 1.3,
              ),
              boxShadow: [BoxShadow(
                color: _hov
                    ? d.color.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.07),
                blurRadius: _hov ? 24 : 14,
                offset: Offset(0, _hov ? 8 : 4),
                spreadRadius: _hov ? 0 : -1,
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bande accent colorée
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        d.color,
                        d.color.withValues(alpha: _hov ? 0.95 : 0.45),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icône + libellé + badge tendance
                          Row(children: [
                            Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: d.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(d.icon, size: 14, color: d.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d.label,
                                style: TextStyle(color: _kMuted,
                                    fontSize: 10.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (d.trendUp ? _kGreen : _kOrange)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(d.trend, style: TextStyle(
                                  color: d.trendUp ? _kGreen : _kOrange,
                                  fontSize: 8.5, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 7),
                          // Nombre animé
                          _CountUp(
                            target: d.rawValue,
                            format: d.format,
                            delayMs: 300 + 70 * widget.idx,
                            style: TextStyle(
                              color: _kText, fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6, height: 1.0,
                              shadows: [Shadow(
                                  color: d.color.withValues(alpha: 0.15),
                                  blurRadius: 8)],
                            ),
                          ),
                          if (d.sub != null) ...[
                            const SizedBox(height: 2),
                            Text(d.sub!, style: TextStyle(
                                color: d.color.withValues(alpha: 0.75),
                                fontSize: 9.5, fontWeight: FontWeight.w500)),
                          ],
                          const Spacer(),
                          if (spark) _buildSparkline(d, widget.idx),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CountUp animé ────────────────────────────────────────────────────────────
class _CountUp extends StatefulWidget {
  const _CountUp({
    required this.target, required this.format,
    required this.style, this.delayMs = 300,
  });
  final double target; final String Function(double) format;
  final TextStyle style; final int delayMs;
  @override
  State<_CountUp> createState() => _CountUpState();
}
class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Text(
        widget.format(widget.target * _anim.value), style: widget.style),
  );
}

// ─── Sparkline A : Syncfusion (spline / splineArea / column) ─────────────────
class _SparkChart extends StatelessWidget {
  const _SparkChart({required this.pts, required this.color, required this.type});
  final List<MonthlyPoint> pts;
  final Color              color;
  final _SparkType         type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBorderWidth: 0,
        margin: EdgeInsets.zero,
        primaryXAxis: const CategoryAxis(
            isVisible: false, borderColor: Colors.transparent),
        primaryYAxis: const NumericAxis(
            isVisible: false, borderColor: Colors.transparent, minimum: 0),
        series: _series(),
      ),
    );
  }

  List<CartesianSeries> _series() {
    switch (type) {

      // ── Ligne fine seule (Groupes actifs) ─────────────────────────────────
      case _SparkType.spline:
        return [
          SplineSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.85),
            width: 2.0, animationDuration: 1500,
            splineType: SplineType.natural,
            markerSettings: MarkerSettings(
              isVisible: true, shape: DataMarkerType.circle,
              width: 5, height: 5, color: color,
              borderColor: Colors.white, borderWidth: 1.4,
            ),
          ),
        ];

      // ── Zone remplie + ligne (Élèves, Revenus) ────────────────────────────
      case _SparkType.splineArea:
        return [
          SplineAreaSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            animationDuration: 1500, splineType: SplineType.natural,
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.40), color.withValues(alpha: 0.03)],
            ),
            borderColor: Colors.transparent, borderWidth: 0,
          ),
          SplineSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            color: color.withValues(alpha: 0.85),
            width: 1.8, animationDuration: 1500,
            splineType: SplineType.natural,
            markerSettings: MarkerSettings(
              isVisible: true, shape: DataMarkerType.circle,
              width: 4, height: 4, color: color,
              borderColor: Colors.white, borderWidth: 1.2,
            ),
          ),
        ];

      // ── Colonnes verticales (Écoles actives) ──────────────────────────────
      case _SparkType.column:
        final shades = [0.40, 0.52, 0.65, 0.78, 0.90, 1.0];
        return [
          ColumnSeries<MonthlyPoint, String>(
            dataSource: pts,
            xValueMapper: (p, _) => p.month,
            yValueMapper: (p, _) => p.value,
            borderRadius: BorderRadius.circular(3),
            spacing: 0.18, animationDuration: 1400,
            pointColorMapper: (_, i) =>
                color.withValues(alpha: shades[i < shades.length ? i : shades.length - 1]),
          ),
        ];

      default:
        return [];
    }
  }
}

// ─── Sparkline B : barres horizontales custom (Personnel, Abonnements) ───────
class _SparkBarH extends StatefulWidget {
  const _SparkBarH({required this.data, required this.color, this.delayMs = 420});
  final List<MapEntry<String, int>> data;
  final Color color; final int delayMs;
  @override
  State<_SparkBarH> createState() => _SparkBarHState();
}
class _SparkBarHState extends State<_SparkBarH>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.data.fold(0, (m, e) => e.value > m ? e.value : m);
    if (maxVal == 0) return const SizedBox.shrink();
    const shades = [1.0, 0.72, 0.50, 0.34];
    final rows = widget.data.take(4).toList();

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => SizedBox(
        height: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rows.asMap().entries.map((e) {
            final i    = e.key;
            final frac = (e.value.value / maxVal).clamp(0.0, 1.0) * _anim.value;
            final alpha = shades[i < shades.length ? i : shades.length - 1];
            return SizedBox(
              height: 6,
              child: Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(color: widget.color.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: alpha),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ]),
                )),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Sparkline C : barre de progression animée avec glow (Sync, SLA) ─────────
class _SparkProgress extends StatefulWidget {
  const _SparkProgress({required this.value, required this.max,
      required this.color, this.delayMs = 420});
  final double value, max;
  final Color  color;
  final int    delayMs;
  @override
  State<_SparkProgress> createState() => _SparkProgressState();
}
class _SparkProgressState extends State<_SparkProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.value / widget.max).clamp(0.0, 1.0);
    return SizedBox(
      height: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(children: [
            Text('0', style: TextStyle(
                color: widget.color.withValues(alpha: 0.35), fontSize: 7.5)),
            const Spacer(),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, _) => Text(
                '${(widget.value * _anim.value).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: widget.color.withValues(alpha: 0.75),
                    fontSize: 8, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(children: [
                Container(
                  height: 10,
                  color: widget.color.withValues(alpha: 0.10)),
                FractionallySizedBox(
                  widthFactor: pct * _anim.value,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.color.withValues(alpha: 0.60),
                        widget.color,
                      ]),
                      boxShadow: [BoxShadow(
                          color: widget.color.withValues(alpha: 0.55),
                          blurRadius: 8, spreadRadius: 1)],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5 · Graphiques ───────────────────────────────────────────────────────────
class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth > 760) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: _PlanDonut(stats: stats)),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _DeptChart(stats: stats)),
      ]);
    }
    return Column(children: [
      _PlanDonut(stats: stats),
      const SizedBox(height: 16),
      _DeptChart(stats: stats),
    ]);
  });
}

// ─── DonutChart plans ─────────────────────────────────────────────────────────
class _CPt {
  const _CPt(this.label, this.y, this.color);
  final String label; final int y; final Color color;
}

class _PlanDonut extends StatelessWidget {
  const _PlanDonut({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    if (stats.groupesByPlan.isEmpty) {
      return _Card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.donut_large_rounded,
              title: "Plans d'abonnement", sub: 'Répartition des groupes'),
          const SizedBox(height: 24),
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Aucun groupe enregistré',
                style: TextStyle(color: _kMuted, fontSize: 13)),
          )),
        ],
      ));
    }

    final data  = stats.groupesByPlan
        .map((e) => _CPt(e.key, e.value, _planColor(e.key))).toList();
    final total = data.fold(0, (s, d) => s + d.y);

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.donut_large_rounded,
            title: "Plans d'abonnement",
            sub: '$total groupes · ${stats.abonnementsActifs} actifs'),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            SfCircularChart(
              backgroundColor: Colors.transparent,
              margin: EdgeInsets.zero,
              series: <CircularSeries>[
                DoughnutSeries<_CPt, String>(
                  dataSource: data,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.y,
                  pointColorMapper: (d, _) => d.color,
                  animationDuration: 1200,
                  innerRadius: '62%', radius: '92%',
                  strokeColor: kCardBg, strokeWidth: 2.5,
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                ),
              ],
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_fmt(total), style: TextStyle(
                  color: _kText, fontSize: 26,
                  fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              Text('groupes', style: TextStyle(
                  color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 8,
            children: data.map((pt) => Row(mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: pt.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(pt.label, style: TextStyle(
                    color: _kText, fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: pt.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${pt.y}', style: TextStyle(
                      color: pt.color, fontSize: 10,
                      fontWeight: FontWeight.w700)),
                ),
              ])).toList()),
      ],
    ));
  }
}

// ─── Graphique Département interactif ─────────────────────────────────────────
class _DeptChart extends StatefulWidget {
  const _DeptChart({required this.stats});
  final SuperDashboardData stats;
  @override
  State<_DeptChart> createState() => _DeptChartState();
}
class _DeptChartState extends State<_DeptChart>
    with SingleTickerProviderStateMixin {
  String? _sel;
  late final AnimationController _anim;
  late final Animation<double>   _fade;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 260));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _tap(String dept) {
    if (_sel == dept) { setState(() => _sel = null); _anim.reverse(); }
    else              { setState(() => _sel = dept);  _anim.forward(from: 0); }
  }

  @override
  Widget build(BuildContext context) {
    final data   = widget.stats.deptStats;
    final maxVal = data.isEmpty ? 1
        : data.fold(0, (m, d) => d.groupCount > m ? d.groupCount : m);
    final totalG = data.fold(0, (s, d) => s + d.groupCount);
    final totalE = data.fold(0, (s, d) => s + d.schoolCount);
    final selGroups = _sel != null
        ? data.firstWhere((d) => d.dept == _sel,
              orElse: () => const DeptStat(dept: '', groups: [])).groups
        : <DeptGroupInfo>[];

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.map_rounded, size: 17, color: _kNavy),
          const SizedBox(width: 8),
          Expanded(child: Text('Par Département', style: TextStyle(
              color: _kText, fontSize: 15, fontWeight: FontWeight.w700))),
          widget.stats.deptStats.isNotEmpty
              ? _Chip('Données réelles', _kGreen)
              : _Chip('Démo', _kGold),
        ]),
        const SizedBox(height: 2),
        Text('$totalG groupe${totalG != 1 ? 's' : ''} · '
            '$totalE école${totalE != 1 ? 's' : ''}',
            style: TextStyle(color: _kMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text('Cliquez sur un département pour les détails',
            style: TextStyle(color: _kMuted.withValues(alpha: 0.55),
                fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        ...data.map((d) => _DBar(d: d, maxVal: maxVal,
            selected: _sel == d.dept, onTap: () => _tap(d.dept))),
        AnimatedSize(
          duration: const Duration(milliseconds: 290),
          curve: Curves.easeInOut,
          child: _sel != null && selGroups.isNotEmpty
              ? FadeTransition(opacity: _fade,
                  child: _DeptDetail(dept: _sel!, groups: selGroups,
                      onClose: () { setState(() => _sel = null); _anim.reverse(); }))
              : const SizedBox.shrink(),
        ),
      ],
    ));
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w600)));
}

class _DBar extends StatefulWidget {
  const _DBar({required this.d, required this.maxVal,
      required this.selected, required this.onTap});
  final DeptStat d; final int maxVal;
  final bool selected; final VoidCallback onTap;
  @override
  State<_DBar> createState() => _DBarState();
}
class _DBarState extends State<_DBar> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final d   = widget.d;
    final frc = widget.maxVal > 0 ? d.groupCount / widget.maxVal : 0.0;
    final col = _deptColor(d.dept);
    final sel = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = true),
        onExit:  (_) => setState(() => _hov = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? col.withValues(alpha: 0.07)
                  : _hov ? Colors.grey.withValues(alpha: 0.04) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? col.withValues(alpha: 0.28) : Colors.transparent),
            ),
            child: Column(children: [
              Row(children: [
                SizedBox(width: 96, child: Text(d.dept, style: TextStyle(
                    color: sel ? col : _kText, fontSize: 12,
                    fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis)),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 11, color: col.withValues(alpha: 0.10)),
                    FractionallySizedBox(widthFactor: frc,
                        child: Container(height: 11,
                            decoration: BoxDecoration(color: col,
                                borderRadius: BorderRadius.circular(4)))),
                  ]),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 22, child: Text('${d.groupCount}',
                    textAlign: TextAlign.right, style: TextStyle(
                        color: col, fontSize: 12, fontWeight: FontWeight.w700))),
                const SizedBox(width: 4),
                Icon(sel ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 15, color: _kMuted),
              ]),
              Row(children: [
                const SizedBox(width: 96),
                Text('${d.schoolCount} école${d.schoolCount != 1 ? 's' : ''}',
                    style: TextStyle(
                        color: _kMuted.withValues(alpha: 0.65), fontSize: 10)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DeptDetail extends StatelessWidget {
  const _DeptDetail({required this.dept, required this.groups,
      required this.onClose});
  final String dept; final List<DeptGroupInfo> groups;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _deptColor(dept).withValues(alpha: 0.25))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: Row(children: [
            Container(width: 4, height: 18,
                decoration: BoxDecoration(color: _deptColor(dept),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Groupes · $dept', style: TextStyle(
                color: _deptColor(dept), fontSize: 12.5,
                fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${groups.length} groupe${groups.length > 1 ? 's' : ''}',
                style: TextStyle(color: _kMuted, fontSize: 11)),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onClose,
                  child: Icon(Icons.close_rounded, size: 15, color: _kMuted))),
          ]),
        ),
        Divider(height: 1, color: kBorder),
        ...groups.map((g) => _GRow(g: g)),
      ]),
    );
  }
}

class _GRow extends StatefulWidget {
  const _GRow({required this.g});
  final DeptGroupInfo g;
  @override
  State<_GRow> createState() => _GRowState();
}
class _GRowState extends State<_GRow> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final g  = widget.g;
    final pc = _planColor(g.planName);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => context.go(Routes.superGroupes),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          color: _hov ? _kNavy.withValues(alpha: 0.03) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    color: pc.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(Icons.school_rounded, size: 15, color: pc)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: TextStyle(
                    color: _kText, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  _PBadge(g.planName), const SizedBox(width: 6),
                  Text('${g.schoolsCount} école${g.schoolsCount != 1 ? 's' : ''}',
                      style: TextStyle(color: _kMuted, fontSize: 10)),
                ]),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _SBadge(g.status),
              if (g.subscriptionEnd != null) ...[
                const SizedBox(height: 2),
                Text('exp. ${DateFormat('dd/MM/yy').format(g.subscriptionEnd!)}',
                    style: TextStyle(
                        color: g.expiresBientot ? _kOrange : _kMuted,
                        fontSize: 9.5, fontWeight: FontWeight.w500)),
              ],
            ]),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kMuted),
          ]),
        ),
      ),
    );
  }
}

class _PBadge extends StatelessWidget {
  const _PBadge(this.p);
  final String p;
  @override
  Widget build(BuildContext context) {
    final c = _planColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(p, style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w700)));
  }
}

class _SBadge extends StatelessWidget {
  const _SBadge(this.s);
  final String s;
  static Map<String, (String, Color)> get _map => {
    'active':    ('Actif',    _kGreen),
    'trial':     ('Essai',    _kBlue),
    'expired':   ('Expiré',   _kRed),
    'suspended': ('Suspendu', _kOrange),
  };
  @override
  Widget build(BuildContext context) {
    final (label, color) = _map[s] ?? ('—', _kMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ]));
  }
}

// ─── 6 · Bas de page ──────────────────────────────────────────────────────────
class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth > 760) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 4, child: _TopGroupes(stats: stats)),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _ActivityFeed(stats: stats)),
      ]);
    }
    return Column(children: [
      _TopGroupes(stats: stats),
      const SizedBox(height: 16),
      _ActivityFeed(stats: stats),
    ]);
  });
}

class _TopGroupes extends StatelessWidget {
  const _TopGroupes({required this.stats});
  final SuperDashboardData stats;

  @override
  Widget build(BuildContext context) {
    final all = stats.deptStats.expand((d) => d.groups).toList()
      ..sort((a, b) => b.schoolsCount.compareTo(a.schoolsCount));
    final top = all.take(5).toList();

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _SectionTitle(icon: Icons.emoji_events_rounded,
              title: 'Top Groupes', sub: "Par nombre d'écoles"),
          const Spacer(),
          TextButton(
            onPressed: () => context.go(Routes.superGroupes),
            style: TextButton.styleFrom(foregroundColor: _kNavy,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Voir tout →', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        if (top.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Aucune donnée disponible',
                style: TextStyle(color: _kMuted, fontSize: 13))))
        else
          ...top.asMap().entries.map((e) =>
              _TopGroupRow(rank: e.key + 1, g: e.value)),
      ],
    ));
  }
}

class _TopGroupRow extends StatelessWidget {
  const _TopGroupRow({required this.rank, required this.g});
  final int rank; final DeptGroupInfo g;
  static List<Color> get _medals => [
    const Color(0xFFFFD700), const Color(0xFFB0B8C5), const Color(0xFFCD7F32), _kMuted, _kMuted,
  ];
  @override
  Widget build(BuildContext context) {
    final rc = _medals[rank <= 5 ? rank - 1 : 4];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
              color: rc.withValues(alpha: rank <= 3 ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(7),
              border: rank <= 3
                  ? Border.all(color: rc.withValues(alpha: 0.40)) : null),
          child: Center(child: Text('$rank', style: TextStyle(
              color: rc, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.name, style: TextStyle(color: _kText, fontSize: 12.5,
                fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            _PBadge(g.planName),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Icon(Icons.domain_rounded, size: 12, color: _kMuted),
            const SizedBox(width: 3),
            Text('${g.schoolsCount}', style: TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          Text('école${g.schoolsCount != 1 ? 's' : ''}',
              style: TextStyle(color: _kMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.stats});
  final SuperDashboardData stats;

  static const _demo = [
    ActivityItem(time: 'il y a 17h', icon: '🏫',
        title: 'Groupe mis à jour', detail: 'Réseau EDEC Congo'),
    ActivityItem(time: 'il y a 2 j', icon: '👤',
        title: 'Profil mis à jour', detail: 'Grace'),
    ActivityItem(time: 'il y a 3 j', icon: '🏫',
        title: 'Nouvelle école ajoutée', detail: 'École Primaire Saint-Pierre'),
    ActivityItem(time: 'il y a 5 j', icon: '📋',
        title: "Plan d'abonnement mis à jour", detail: 'Premium'),
    ActivityItem(time: 'il y a 6 j', icon: '🏫',
        title: 'Nouvelle école ajoutée', detail: 'École Savorgnan de Brazza'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = stats.recentActivity.isEmpty ? _demo : stats.recentActivity;
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _SectionTitle(icon: Icons.history_rounded,
              title: 'Activité récente',
              sub: 'Dernières modifications plateforme'),
          const Spacer(),
          if (stats.recentActivity.isEmpty)
            _Chip('Démo', _kGold)
          else
            TextButton(
              onPressed: () => context.go(Routes.superAudit),
              style: TextButton.styleFrom(foregroundColor: _kNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Journal complet →',
                  style: TextStyle(fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 14),
        ...items.map((i) => _ATile(item: i)),
      ],
    ));
  }
}

class _ATile extends StatelessWidget {
  const _ATile({required this.item});
  final ActivityItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(9)),
        child: Center(child: Text(item.icon,
            style: const TextStyle(fontSize: 16))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: '${item.time} · ', style: TextStyle(
                color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
            TextSpan(text: item.title, style: TextStyle(
                color: _kText, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('"${item.detail}"', style: TextStyle(
              color: _kMuted, fontSize: 11.5, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

// ─── Widgets communs ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -2)],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.sub});
  final IconData icon; final String title; final String? sub;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 17, color: _kNavy),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(
            color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub!, style: TextStyle(color: _kMuted, fontSize: 12)),
      ],
    ],
  );
}

// ─── Loading / Error ──────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Shimmer.fromColors(
          baseColor: kBorder,
          highlightColor: const Color(0xFFF8FAFC),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Barre du haut ─────────────────────────────────────────────
              Row(children: [
                _ShimmerBox(width: 220, height: 28, radius: 8),
                Spacer(),
                _ShimmerBox(width: 100, height: 32, radius: 8),
                SizedBox(width: 10),
                _ShimmerBox(width: 100, height: 32, radius: 8),
              ]),
              SizedBox(height: 24),
              // ── KPI row 1 (4 cartes) ───────────────────────────────────────
              _ShimmerKpiRow(),
              SizedBox(height: 12),
              // ── KPI row 2 (4 cartes) ───────────────────────────────────────
              _ShimmerKpiRow(),
              SizedBox(height: 24),
              // ── Graphiques (2 colonnes) ────────────────────────────────────
              Row(children: [
                Expanded(child: _ShimmerBox(height: 260, radius: 16)),
                SizedBox(width: 16),
                Expanded(child: _ShimmerBox(height: 260, radius: 16)),
              ]),
              SizedBox(height: 16),
              Row(children: [
                Expanded(flex: 2, child: _ShimmerBox(height: 220, radius: 16)),
                SizedBox(width: 16),
                Expanded(child: _ShimmerBox(height: 220, radius: 16)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });
  final double width, height, radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _ShimmerKpiRow extends StatelessWidget {
  const _ShimmerKpiRow();

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(4, (i) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Spacer(),
                Container(width: 46, height: 7,
                    decoration: BoxDecoration(color: kCardBg,
                        borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 8),
              Container(width: 80, height: 20,
                  decoration: BoxDecoration(color: kCardBg,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(width: 120, height: 10,
                  decoration: BoxDecoration(color: kCardBg,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    )),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.warning_amber_rounded, size: 42, color: _kRed)),
      const SizedBox(height: 18),
      Text('Impossible de charger le tableau de bord',
          style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(error, style: TextStyle(color: _kMuted, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 22),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ],
  ));
}

// ═══════════════════════════════════════════════════════════════════════════════
// 7 · Panneau Insights IA
// ═══════════════════════════════════════════════════════════════════════════════

enum _InsightType { positive, warning, critical, info, forecast }

class _Insight {
  const _Insight({required this.icon, required this.title,
      required this.detail, required this.type});
  final String      icon;
  final String      title;
  final String      detail;
  final _InsightType type;
}

Color _insightColor(_InsightType t) => switch (t) {
  _InsightType.positive => const Color(0xFF34D399),
  _InsightType.warning  => const Color(0xFFFBBF24),
  _InsightType.critical => const Color(0xFFF87171),
  _InsightType.forecast => const Color(0xFFA5B4FC),
  _InsightType.info     => Colors.white,
};

List<_Insight> _buildInsights(SuperDashboardData stats) {
  final list = <_Insight>[];

  // 1. Tendance revenus 3M vs 3M précédents
  if (stats.revenueMonthly.length >= 6) {
    final all   = stats.revenueMonthly;
    final last3 = all.sublist(all.length - 3).fold(0.0, (s, r) => s + r.amount);
    final prev3 = all.sublist(all.length - 6, all.length - 3)
        .fold(0.0, (s, r) => s + r.amount);
    if (prev3 > 0) {
      final pct = (last3 - prev3) / prev3 * 100;
      list.add(_Insight(
        icon: pct >= 0 ? '📈' : '📉',
        title: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}% de revenus ce trimestre',
        detail: '${_fmtRevenuFull(last3)} vs ${_fmtRevenuFull(prev3)} le trimestre précédent',
        type: pct >= 5 ? _InsightType.positive
            : pct >= 0 ? _InsightType.info : _InsightType.warning,
      ));
    }
  }

  // 2. Risque churn — abonnements expirants
  if (stats.expirantDans30j > 0) {
    final avgRev = stats.abonnementsActifs > 0
        ? stats.revenusXafMois / stats.abonnementsActifs : 0.0;
    final atRisk = avgRev * stats.expirantDans30j;
    list.add(_Insight(
      icon: '⚠️',
      title: '${stats.expirantDans30j} abonnement'
          '${stats.expirantDans30j > 1 ? 's' : ''} en danger',
      detail: '~${_fmtRevenuFull(atRisk)} de revenus à risque — contacter maintenant',
      type: stats.expirantDans30j >= 3 ? _InsightType.critical : _InsightType.warning,
    ));
  }

  // 3. Prévision revenus mois suivant
  if (stats.revenueMonthly.length >= 4) {
    final forecast = _forecastRevenue(stats.revenueMonthly);
    if (forecast > 0) {
      final delta = forecast - stats.revenusXafMois;
      list.add(_Insight(
        icon: '🔮',
        title: 'Prévision mois prochain : ${_fmtRevenuFull(forecast)}',
        detail: '${delta >= 0 ? '+' : ''}${_fmtRevenu(delta)} vs MRR actuel'
            ' (régression linéaire 6M)',
        type: _InsightType.forecast,
      ));
    }
  }

  // 4. Rythme de croissance groupes
  if (stats.trendGroupes.length >= 3) {
    final n = stats.trendGroupes.sublist(stats.trendGroupes.length - 3)
        .fold(0.0, (s, p) => s + p.value);
    if (n > 0) {
      list.add(_Insight(
        icon: '🚀',
        title: '${n.toInt()} nouveau${n > 1 ? 'x' : ''} groupe${n > 1 ? 's' : ''} ce trimestre',
        detail: 'rythme : ${(n / 3).toStringAsFixed(1)} groupe/mois — '
            '${stats.groupesActifs} actifs au total',
        type: _InsightType.positive,
      ));
    }
  }

  // 5. Concentration plan
  if (stats.groupesByPlan.isNotEmpty) {
    final top   = stats.groupesByPlan.first;
    final total = stats.groupesByPlan.fold(0, (s, e) => s + e.value);
    if (total > 0) {
      final pct = (top.value / total * 100).round();
      if (pct > 50) {
        list.add(_Insight(
          icon: '💡',
          title: 'Plan "${top.key}" : $pct% des groupes',
          detail: 'opportunité d\'upsell vers Premium ou Institutionnel',
          type: _InsightType.info,
        ));
      }
    }
  }

  // 6. Département dominant
  if (stats.deptStats.isNotEmpty && stats.groupesTotal > 0) {
    final top = stats.deptStats.first;
    final pct = (top.groupCount / stats.groupesTotal * 100).round();
    if (pct > 45) {
      list.add(_Insight(
        icon: '🗺️',
        title: '${top.dept} concentre $pct% des groupes',
        detail: 'fort potentiel d\'expansion dans les autres départements',
        type: _InsightType.info,
      ));
    }
  }

  // État vide — aucune donnée encore
  if (stats.groupesTotal == 0) {
    list.add(const _Insight(
      icon: '🏫',
      title: 'Aucun groupe enregistré',
      detail: 'Créez votre premier groupe scolaire pour démarrer l\'analyse',
      type: _InsightType.info,
    ));
  }
  if (stats.ecolesTotal == 0 && stats.groupesTotal > 0) {
    list.add(const _Insight(
      icon: '🏗️',
      title: 'Aucune école associée',
      detail: 'Ajoutez des écoles aux groupes pour enrichir les statistiques',
      type: _InsightType.info,
    ));
  }
  if (stats.revenusXafMois == 0 && stats.groupesTotal > 0) {
    list.add(const _Insight(
      icon: '💰',
      title: 'MRR à zéro',
      detail: 'Configurez des plans d\'abonnement avec un prix pour suivre les revenus',
      type: _InsightType.warning,
    ));
  }

  if (list.isEmpty) {
    list.add(const _Insight(
      icon: '✅',
      title: 'Plateforme en bonne santé',
      detail: 'Aucune anomalie détectée — continuez sur cette lancée',
      type: _InsightType.positive,
    ));
  }

  return list.take(5).toList();
}

double _forecastRevenue(List<MonthlyRevenue> months) {
  final n = months.length;
  if (n < 3) return 0;
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < n; i++) {
    sumX += i; sumY += months[i].amount;
    sumXY += i * months[i].amount; sumX2 += i * i;
  }
  final denom = n * sumX2 - sumX * sumX;
  if (denom == 0) return months.last.amount;
  final slope     = (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;
  return (intercept + slope * n).clamp(0, double.infinity);
}

class _AiInsightsPanel extends ConsumerStatefulWidget {
  const _AiInsightsPanel({required this.stats});
  final SuperDashboardData stats;
  @override
  ConsumerState<_AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends ConsumerState<_AiInsightsPanel>
    with SingleTickerProviderStateMixin {
  late DateTime          _analysedAt;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _analysedAt = DateTime.now();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AiInsightsPanel old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) _analysedAt = DateTime.now();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _refresh() {
    ref.invalidate(superDashboardProvider);
    setState(() => _analysedAt = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final stats    = widget.stats;
    final insights = _buildInsights(stats);
    final timeStr  = DateFormat('HH:mm:ss').format(_analysedAt);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
          blurRadius: 24, offset: const Offset(0, 8),
        )],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─ En-tête ─────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 19, color: Color(0xFFA5B4FC)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Insights IA', style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            Text('Analysé à $timeStr · Supabase live',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5)),
          ])),
          // Badge pulsant "Live"
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08 + _pulse.value * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF34D399)
                        .withValues(alpha: 0.35 + _pulse.value * 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399)
                          .withValues(alpha: 0.70 + _pulse.value * 0.30),
                      shape: BoxShape.circle,
                    )),
                const SizedBox(width: 5),
                const Text('Live', style: TextStyle(
                    color: Color(0xFF34D399), fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton refresh
          Tooltip(
            message: 'Relancer l\'analyse',
            child: InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 14),

        // ─ Mini-KPIs réels depuis Supabase ────────────────────────────────
        Wrap(spacing: 8, runSpacing: 6, children: [
          _LiveChip(Icons.school_rounded,
              '${stats.groupesActifs}/${stats.groupesTotal} groupes',
              const Color(0xFF818CF8)),
          _LiveChip(Icons.domain_rounded,
              '${stats.ecolesTotal} écoles',
              const Color(0xFF34D399)),
          _LiveChip(Icons.people_alt_rounded,
              '${_fmtLg(stats.elevesTotal)} élèves',
              const Color(0xFF60A5FA)),
          _LiveChip(Icons.account_balance_wallet_rounded,
              'MRR ${_fmtRevenu(stats.revenusXafMois)} FCFA',
              _kGold),
          _LiveChip(Icons.verified_rounded,
              '${stats.abonnementsActifs} abonnements',
              const Color(0xFF4ADE80)),
          if (stats.expirantDans30j > 0)
            _LiveChip(Icons.warning_amber_rounded,
                '${stats.expirantDans30j} expirent bientôt',
                const Color(0xFFFB923C)),
        ]),

        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
        const SizedBox(height: 14),

        // ─ Insights générés ────────────────────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          if (c.maxWidth > 700) {
            final left  = [for (int i = 0; i < insights.length; i += 2) insights[i]];
            final right = [for (int i = 1; i < insights.length; i += 2) insights[i]];
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: left.asMap().entries.map((e) =>
                  _InsightTile(insight: e.value, delay: e.key * 120)).toList())),
              const SizedBox(width: 20),
              Expanded(child: Column(children: right.asMap().entries.map((e) =>
                  _InsightTile(insight: e.value, delay: e.key * 120 + 60)).toList())),
            ]);
          }
          return Column(children: insights.asMap().entries.map((e) =>
              _InsightTile(insight: e.value, delay: e.key * 90)).toList());
        }),

        const SizedBox(height: 10),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 10),

        // ─ Footer ──────────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.psychology_rounded, size: 12,
              color: Color(0xFF6366F1)),
          const SizedBox(width: 6),
          Text('Analyse basée sur les données réelles de ta plateforme',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 10.5)),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _refresh,
              child: Text('Actualiser →',
                  style: TextStyle(
                      color: const Color(0xFFA5B4FC).withValues(alpha: 0.70),
                      fontSize: 10.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Chip données live ────────────────────────────────────────────────────────
class _LiveChip extends StatelessWidget {
  const _LiveChip(this.icon, this.label, this.color);
  final IconData icon; final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _InsightTile extends StatefulWidget {
  const _InsightTile({required this.insight, this.delay = 0});
  final _Insight insight;
  final int      delay;
  @override
  State<_InsightTile> createState() => _InsightTileState();
}
class _InsightTileState extends State<_InsightTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 420));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = _insightColor(widget.insight.type);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.22)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.insight.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.insight.title, style: TextStyle(
                    color: c, fontSize: 12.5, fontWeight: FontWeight.w700,
                    height: 1.2)),
                const SizedBox(height: 2),
                Text(widget.insight.detail, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 11, height: 1.3)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 8 · Graphique Revenus interactif — sélecteur de période + date personnalisée
// ═══════════════════════════════════════════════════════════════════════════════

class _RevenueSection extends StatefulWidget {
  const _RevenueSection({required this.stats});
  final SuperDashboardData stats;
  @override
  State<_RevenueSection> createState() => _RevenueSectionState();
}

class _RevenueSectionState extends State<_RevenueSection> {
  int _preset = 6;

  List<MonthlyRevenue> get _shown {
    final all = widget.stats.revenueMonthly;
    return all.length >= _preset ? all.sublist(all.length - _preset) : all;
  }

  String get _periodLabel => _preset == 12 ? '12 mois' : '$_preset mois';

  @override
  Widget build(BuildContext context) {
    final shown      = _shown;
    final total      = shown.fold(0.0, (s, r) => s + r.amount);
    final hasData    = shown.any((r) => r.amount > 0);
    final isEstimate = widget.stats.revenueMonthly.every((r) => r.subscriptions == 0);

    // Variation vs période précédente (uniquement pour les presets fixes)
    double? variation;
    if (_preset > 0) {
      final all = widget.stats.revenueMonthly;
      if (all.length >= _preset * 2) {
        final prev      = all.sublist(all.length - _preset * 2, all.length - _preset);
        final prevTotal = prev.fold(0.0, (s, r) => s + r.amount);
        if (prevTotal > 0) variation = (total - prevTotal) / prevTotal * 100;
      }
    }

    final tooltipBehavior = TooltipBehavior(
      enable: true,
      color: _kNavy,
      header: '',
      format: 'point.x',
      builder: (data, point, series, pointIndex, seriesIndex) {
        final r = data as MonthlyRevenue;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kNavy, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.35),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.label} ${r.year}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10)),
              const SizedBox(height: 3),
              Text(_fmtRevenu(r.amount),
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800)),
              if (r.subscriptions > 0) ...[
                const SizedBox(height: 2),
                Text('${r.subscriptions} abonnement${r.subscriptions > 1 ? 's' : ''}',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10)),
              ],
            ],
          ),
        );
      },
    );

    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ En-tête ────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_kGold, const Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Revenus & Abonnements', style: TextStyle(
                color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(isEstimate ? 'Projection estimée' : 'Données réelles Supabase',
                style: TextStyle(
                    color: isEstimate ? _kGold : _kGreen, fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ])),
          // Sélecteur de période
          _RevPeriodSelector(
            preset: _preset,
            onSelect: (m) => setState(() => _preset = m),
          ),
        ]),
        const SizedBox(height: 14),
        // ─ Total + variation ──────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmtRevenuFull(total), style: TextStyle(
                color: _kText, fontSize: 26, fontWeight: FontWeight.w900,
                letterSpacing: -0.8)),
            Text('Total · $_periodLabel · FCFA',
                style: TextStyle(color: _kMuted, fontSize: 11)),
          ]),
          const SizedBox(width: 12),
          if (variation != null) _VariationBadge(variation),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtRevenuFull(widget.stats.revenusXafMois),
                style: TextStyle(color: _kGold, fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text('MRR actuel', style: TextStyle(color: _kMuted, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 16),
        // ─ Graphique ──────────────────────────────────────────────────────
        SizedBox(
          height: 200,
          child: !hasData && shown.isNotEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text('Aucun revenu sur cette période',
                      style: TextStyle(color: _kMuted, fontSize: 13))))
              : shown.isEmpty
                  ? Center(child: CircularProgressIndicator(color: _kGold))
                  : SfCartesianChart(
                      backgroundColor: Colors.transparent,
                      plotAreaBorderWidth: 0,
                      margin: EdgeInsets.zero,
                      tooltipBehavior: tooltipBehavior,
                      primaryXAxis: CategoryAxis(
                        labelStyle: TextStyle(color: _kMuted, fontSize: 9.5,
                            fontWeight: FontWeight.w500),
                        majorGridLines: const MajorGridLines(width: 0),
                        axisLine: AxisLine(
                            color: _kMuted.withValues(alpha: 0.15), width: 1),
                        majorTickLines: const MajorTickLines(size: 0),
                      ),
                      primaryYAxis: const NumericAxis(
                        isVisible: false, minimum: 0,
                        borderColor: Colors.transparent,
                      ),
                      series: [
                        ColumnSeries<MonthlyRevenue, String>(
                          dataSource: shown,
                          xValueMapper: (r, _) => r.label,
                          yValueMapper: (r, _) => r.amount,
                          animationDuration: 1200,
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [_kGold, _kGold.withValues(alpha: 0.50)],
                          ),
                          spacing: 0.25, enableTooltip: true,
                        ),
                        SplineSeries<MonthlyRevenue, String>(
                          dataSource: shown,
                          xValueMapper: (r, _) => r.label,
                          yValueMapper: (r, _) => r.amount,
                          color: _kNavy.withValues(alpha: 0.70),
                          width: 2.0, animationDuration: 1500,
                          splineType: SplineType.natural,
                          enableTooltip: false,
                          markerSettings: MarkerSettings(
                            isVisible: true, shape: DataMarkerType.circle,
                            width: 7, height: 7, color: _kNavy,
                            borderColor: Colors.white, borderWidth: 2.0,
                          ),
                        ),
                      ],
                    ),
        ),
        const SizedBox(height: 10),
        // ─ Légende ────────────────────────────────────────────────────────
        Row(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_kGold, const Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('Revenus mensuels (FCFA)',
                style: TextStyle(color: _kMuted, fontSize: 10.5)),
          ]),
          const SizedBox(width: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 16, height: 2.5,
                color: _kNavy.withValues(alpha: 0.65)),
            const SizedBox(width: 2),
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: _kNavy, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Tendance', style: TextStyle(color: _kMuted, fontSize: 10.5)),
          ]),
        ]),
      ],
    ));
  }
}

// ─── Sélecteur de période (presets + date personnalisée) ─────────────────────
class _RevPeriodSelector extends StatelessWidget {
  const _RevPeriodSelector({required this.preset, required this.onSelect});
  final int preset;
  final ValueChanged<int> onSelect;

  static const _options = [1, 2, 3, 4, 5, 6, 12];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kMuted.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in _options)
        _RevPeriodChip(
          label: m == 12 ? '1A' : '${m}M',
          active: preset == m,
          onTap: () => onSelect(m),
        ),
    ]),
  );
}

class _RevPeriodChip extends StatelessWidget {
  const _RevPeriodChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool   active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : _kMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        )),
      ),
    ),
  );
}

// ─── Badge variation ──────────────────────────────────────────────────────────
class _VariationBadge extends StatelessWidget {
  const _VariationBadge(this.pct);
  final double pct;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (up ? _kGreen : _kRed).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (up ? _kGreen : _kRed).withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14, color: up ? _kGreen : _kRed),
        const SizedBox(width: 4),
        Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                color: up ? _kGreen : _kRed,
                fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Formatage ────────────────────────────────────────────────────────────────
String _fmt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtLg(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)} K';
  return _fmt(n);
}

String _fmtRevenu(double x) {
  if (x >= 1000000) return '${(x / 1000000).toStringAsFixed(1)} M';
  if (x >= 1000)    return '${(x / 1000).toStringAsFixed(0)} K';
  if (x == 0)       return '—';
  return _fmt(x.round());
}

String _fmtRevenuFull(double x) {
  if (x == 0)       return '0 FCFA';
  if (x >= 1000000) return '${(x / 1000000).toStringAsFixed(x >= 10000000 ? 1 : 2)} M FCFA';
  if (x >= 1000)    return '${(x / 1000).toStringAsFixed(0)} K FCFA';
  return '${x.round()} FCFA';
}
