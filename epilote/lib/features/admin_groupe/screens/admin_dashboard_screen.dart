import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_geo_provider.dart';
import '../../../core/widgets/admin_ui.dart';
import 'admin_regional_view.dart';

// ─── Accents locaux (complètent la palette admin_ui) ────────────────────────
const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kTeal   = Color(0xFF14B8A6);
const Color _kOrange = Color(0xFFF97316);
const Color _kPink   = Color(0xFFEC4899);

final _adminTabProv = StateProvider.autoDispose<int>((ref) => 0);

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppShell(title: 'Tableau de bord', child: _Body());
}

// ─── Corps : barre d'onglets + contenu paresseux ────────────────────────────
class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_adminTabProv);

    // Pré-charger les données géo dès l'ouverture du dashboard (onglet 0).
    // Les providers ont ref.keepAlive() → ils restent en mémoire ; quand
    // l'utilisateur clique "Vue régionale", les assets sont déjà prêts (~100 ms).
    ref.watch(congoBoundaryProvider);
    ref.watch(congoDepartmentsProvider);
    ref.watch(congoPlacesProvider);

    return Column(
      children: [
        _DashTabs(tab: tab),
        Expanded(
          child: tab == 0 ? const _OverviewTab() : const _RegionalTab(),
        ),
      ],
    );
  }
}

class _DashTabs extends ConsumerWidget {
  const _DashTabs({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabChip(
                label: "Vue d'ensemble",
                icon: Icons.dashboard_rounded,
                selected: tab == 0,
                onTap: () => ref.read(_adminTabProv.notifier).state = 0,
              ),
              const SizedBox(width: 4),
              _TabChip(
                label: 'Vue régionale',
                icon: Icons.map_rounded,
                selected: tab == 1,
                onTap: () => ref.read(_adminTabProv.notifier).state = 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [kNavyDark, kNavy])
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : kTextMuted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Onglet « Vue d'ensemble » ──────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: kNavy,
      onRefresh: () => ref.refresh(adminDashboardProvider.future),
      child: ref.watch(adminDashboardProvider).when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(adminDashboardProvider),
            ),
            data: (d) => _Overview(data: d),
          ),
    );
  }
}

class _RegionalTab extends StatelessWidget {
  const _RegionalTab();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: AdminRegionalView(),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final showBanner = data.expireBientot || data.tauxOccupationEleves >= 90;
    // Le contenu occupe toute la largeur disponible pour les grands écrans
    // (27" et plus) ; la grille KPI s'adapte jusqu'à 8 colonnes.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        _PageHeader(data: data),
        const SizedBox(height: 18),
        const _QuickActions(),
        if (showBanner) ...[
          const SizedBox(height: 18),
          _CriticalBanner(data: data),
        ],
        const SizedBox(height: 22),
        _KpiSection(data: data),
        const SizedBox(height: 24),
        _ChartsRow(data: data),
        const SizedBox(height: 24),
        _RhSection(data: data),
        const SizedBox(height: 24),
        _DeptSection(data: data),
        const SizedBox(height: 24),
        _Governance(data: data),
        const SizedBox(height: 24),
        _RiskCenter(data: data),
        const SizedBox(height: 24),
        _BottomRow(data: data),
      ],
    );
  }
}

// ─── En-tête de page (bandeau navy) ─────────────────────────────────────────
class _PageHeader extends ConsumerWidget {
  const _PageHeader({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kNavyDeep, kNavyDark, kNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final narrow = c.maxWidth < 660;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_greeting()} 👋',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 5),
              Text(data.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Text(_frDate(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 3),
              Text('Pilotage stratégique de votre groupe scolaire',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5)),
            ],
          );
          final right = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderChip(
                  label: statusLabel(data.subscriptionStatus),
                  color: statusColor(data.subscriptionStatus)),
              _HeaderChip(
                  label: 'Plan ${data.planName}',
                  color: planColor(data.planSlug)),
              Tooltip(
                message: 'Actualiser',
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ref.invalidate(adminDashboardProvider),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 16), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: left), const SizedBox(width: 16), right],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Actions rapides ────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData, String)>[
      ('Mes écoles', Icons.account_balance_rounded, Routes.adminEcoles),
      ('Utilisateurs', Icons.people_alt_rounded, Routes.adminUtilisateurs),
      ("Profils d'accès", Icons.admin_panel_settings_rounded, Routes.adminProfils),
      ('Rapports', Icons.assessment_rounded, Routes.adminRapports),
      ('Abonnement', Icons.workspace_premium_rounded, Routes.adminAbonnement),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          _QaChip(label: it.$1, icon: it.$2, onTap: () => context.go(it.$3)),
      ],
    );
  }
}

class _QaChip extends StatefulWidget {
  const _QaChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QaChip> createState() => _QaChipState();
}

class _QaChipState extends State<_QaChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? kNavy.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? kNavy : kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: kNavy),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bannière critique ──────────────────────────────────────────────────────
class _CriticalBanner extends StatelessWidget {
  const _CriticalBanner({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final msgs = <String>[];
    if (data.expireBientot) {
      msgs.add('Votre abonnement arrive à échéance');
    }
    if (data.tauxOccupationEleves >= 90) {
      msgs.add("le quota d'élèves de votre plan est presque atteint");
    }
    final message =
        '${msgs.map((m) => m).join(' · ')}. Anticipez pour éviter toute interruption de service.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kRed.withValues(alpha: 0.95), const Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Action requise',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => context.go(Routes.adminAbonnement),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kRed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            child: const Text("Gérer l'abonnement"),
          ),
        ],
      ),
    );
  }
}

// ─── Section KPI ────────────────────────────────────────────────────────────
enum _Spark { area, bars, progress }

class _Kpi {
  _Kpi({
    required this.icon,
    required this.color,
    required this.rawValue,
    required this.fmt,
    required this.label,
    required this.spark,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.areaPts = const [],
    this.bars = const [],
    this.progress = 0,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final num rawValue;
  final String Function(num) fmt;
  final String label;
  final _Spark spark;
  final String? sub;
  final String? trend;
  final bool trendUp;
  final List<MonthlyPoint> areaPts;
  final List<MapEntry<String, int>> bars;
  final double progress;
  final VoidCallback? onTap;
}

class _KpiSection extends ConsumerWidget {
  const _KpiSection({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = <_Kpi>[
      _Kpi(
        icon: Icons.account_balance_rounded,
        color: kNavy,
        rawValue: data.ecolesTotal,
        fmt: fmtInt,
        label: 'Écoles',
        sub: '${data.ecolesActives} active(s) · '
            '${data.publicCount} pub · ${data.priveCount} priv',
        spark: _Spark.progress,
        progress: data.ecolesTotal == 0 ? 0 : data.ecolesActives / data.ecolesTotal,
        onTap: () => context.go(Routes.adminEcoles),
      ),
      _Kpi(
        icon: Icons.groups_2_rounded,
        color: kGreen,
        rawValue: data.elevesTotal,
        fmt: fmtInt,
        label: 'Élèves',
        sub: '${data.studentsM} G · ${data.studentsF} F',
        trend: _pct(data.enrollmentGrowth),
        trendUp: data.enrollmentGrowth >= 0,
        spark: _Spark.area,
        areaPts: data.enrollmentTrend,
      ),
      _Kpi(
        icon: Icons.badge_rounded,
        color: _kBlue,
        rawValue: data.personnelTotal,
        fmt: fmtInt,
        label: 'Personnel',
        sub: '${data.enseignantsTotal} enseignant(s)',
        spark: _Spark.bars,
        bars: [for (final s in data.schools) MapEntry(s.name, s.staff)],
        onTap: () => context.go(Routes.adminUtilisateurs),
      ),
      _Kpi(
        icon: Icons.meeting_room_rounded,
        color: _kPurple,
        rawValue: data.classesTotal,
        fmt: fmtInt,
        label: 'Classes',
        sub: '${data.ecolesActives} école(s) active(s)',
        spark: _Spark.bars,
        bars: [for (final s in data.schools) MapEntry(s.name, s.classes)],
      ),
      _Kpi(
        icon: Icons.map_rounded,
        color: _kTeal,
        rawValue: data.coveredDepts,
        fmt: fmtInt,
        label: 'Départements couverts',
        sub: 'sur 15 au Congo',
        spark: _Spark.bars,
        bars: data.schoolsByDept.entries.toList(),
        onTap: () => ref.read(_adminTabProv.notifier).state = 1,
      ),
      _Kpi(
        icon: Icons.verified_rounded,
        color: kAccent,
        rawValue: data.tauxPaiement,
        fmt: (v) => '${v.round()} %',
        label: 'Taux de paiement',
        sub: '${data.elevesAJour}/${data.elevesTotal} à jour',
        spark: _Spark.progress,
        progress: (data.tauxPaiement / 100).clamp(0, 1),
        onTap: () => context.go(Routes.adminRapports),
      ),
      _Kpi(
        icon: Icons.payments_rounded,
        color: _kOrange,
        rawValue: data.revenusMois,
        fmt: fmtCompact,
        label: 'Revenus du mois',
        sub: '${data.paiementsMoisCount} paiement(s)',
        spark: _Spark.area,
        areaPts: data.revenueTrend,
        onTap: () => context.go(Routes.adminAbonnement),
      ),
      _Kpi(
        icon: Icons.donut_large_rounded,
        color: kRed,
        rawValue: data.tauxOccupationEleves,
        fmt: (v) => '${v.round()} %',
        label: 'Quota élèves',
        sub: '${fmtInt(data.elevesTotal)}/${fmtInt(data.maxStudents)}',
        spark: _Spark.progress,
        progress: (data.tauxOccupationEleves / 100).clamp(0, 1),
        onTap: () => context.go(Routes.adminAbonnement),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        final cols = w >= 1920 ? 8 : (w >= 1280 ? 4 : (w >= 920 ? 3 : (w >= 600 ? 2 : 1)));
        const gap = 16.0;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < kpis.length; i++)
              SizedBox(width: itemW, child: _KpiCard(kpi: kpis[i], index: i)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.kpi, required this.index});
  final _Kpi kpi;
  final int index;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kpi;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _hover ? k.color.withValues(alpha: 0.5) : kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04),
            blurRadius: _hover ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: k.color),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: k.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(k.icon, color: k.color, size: 22),
                      ),
                      if (k.trend != null)
                        _TrendPill(text: k.trend!, up: k.trendUp)
                      else if (k.onTap != null)
                        Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CountUp(
                    value: k.rawValue,
                    fmt: k.fmt,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(k.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600)),
                  if (k.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(k.sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 36, child: _spark(k)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final interactive = MouseRegion(
      cursor:
          k.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: k.onTap != null
          ? GestureDetector(onTap: k.onTap, child: card)
          : card,
    );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: interactive),
    );
  }

  Widget _spark(_Kpi k) => switch (k.spark) {
        _Spark.area => _SparkArea(pts: k.areaPts, color: k.color),
        _Spark.bars => _SparkBars(bars: k.bars, color: k.color),
        _Spark.progress => _SparkProgress(value: k.progress, color: k.color),
      };
}

class _CountUp extends StatefulWidget {
  const _CountUp({required this.value, required this.fmt, required this.style});
  final num value;
  final String Function(num) fmt;
  final TextStyle style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Text(
          widget.fmt(widget.value * t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.text, required this.up});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = up ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 12, color: c),
          const SizedBox(width: 3),
          Text(text,
              style:
                  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}

class _SparkArea extends StatelessWidget {
  const _SparkArea({required this.pts, required this.color});
  final List<MonthlyPoint> pts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = pts.fold<int>(0, (a, b) => a + b.value);
    if (pts.isEmpty || total == 0) return _FlatSpark(color: color);
    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      primaryXAxis: const CategoryAxis(isVisible: false),
      primaryYAxis: const NumericAxis(isVisible: false, minimum: 0),
      series: <CartesianSeries<MonthlyPoint, String>>[
        SplineAreaSeries<MonthlyPoint, String>(
          dataSource: pts,
          xValueMapper: (p, _) => p.month,
          yValueMapper: (p, _) => p.value,
          animationDuration: 1100,
          splineType: SplineType.natural,
          borderColor: color,
          borderWidth: 2,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ],
    );
  }
}

class _SparkBars extends StatelessWidget {
  const _SparkBars({required this.bars, required this.color});
  final List<MapEntry<String, int>> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxV = bars.isEmpty
        ? 0
        : bars.map((e) => e.value).reduce(math.max);
    if (bars.isEmpty || maxV == 0) return _FlatSpark(color: color);
    final show = bars.length > 12 ? bars.sublist(0, 12) : bars;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in show)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: ((e.value / maxV) * t).clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(
                            alpha: 0.45 + 0.55 * (e.value / maxV)),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparkProgress extends StatelessWidget {
  const _SparkProgress({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (ctx, t, _) => LinearProgressIndicator(
              value: t,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(v * 100).round()} %',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _FlatSpark extends StatelessWidget {
  const _FlatSpark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ─── Graphiques (inscriptions + répartition) ────────────────────────────────
class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final ench = _EnrollmentChart(data: data);
        final donut = _TypeDonut(data: data);
        if (c.maxWidth < 840) {
          return Column(children: [ench, const SizedBox(height: 18), donut]);
        }
        // IntrinsicHeight borne la hauteur (sinon « stretch » dans un ListView
        // vertical = contrainte infinie → le contenu disparaît sur grand écran).
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: ench),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: donut),
            ],
          ),
        );
      },
    );
  }
}

class _EnrollmentChart extends StatefulWidget {
  const _EnrollmentChart({required this.data});
  final AdminDashboardData data;

  @override
  State<_EnrollmentChart> createState() => _EnrollmentChartState();
}

class _EnrollmentChartState extends State<_EnrollmentChart> {
  late final TooltipBehavior _tt = TooltipBehavior(
    enable: true,
    color: kNavyDark,
    textStyle: const TextStyle(color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final pts = widget.data.enrollmentTrend;
    final total = pts.fold<int>(0, (a, b) => a + b.value);
    final growth = widget.data.enrollmentGrowth;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Évolution des inscriptions',
            icon: Icons.show_chart_rounded,
            subtitle: '6 derniers mois',
            trailing: total == 0
                ? null
                : _TrendPill(text: _pct(growth), up: growth >= 0),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: total == 0
                ? const _ChartEmpty(
                    message:
                        "Les inscriptions s'afficheront ici dès l'arrivée de vos premiers élèves.",
                  )
                : SfCartesianChart(
                    backgroundColor: Colors.transparent,
                    plotAreaBorderWidth: 0,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      labelStyle:
                          TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: 0,
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      majorGridLines: MajorGridLines(
                        width: 1,
                        color: kBorder.withValues(alpha: 0.7),
                        dashArray: const <double>[4, 4],
                      ),
                      labelStyle:
                          TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    series: <CartesianSeries<MonthlyPoint, String>>[
                      SplineAreaSeries<MonthlyPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.month,
                        yValueMapper: (p, _) => p.value,
                        name: 'Inscriptions',
                        animationDuration: 1400,
                        splineType: SplineType.natural,
                        borderColor: kGreen,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            kGreen.withValues(alpha: 0.28),
                            kGreen.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      SplineSeries<MonthlyPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.month,
                        yValueMapper: (p, _) => p.value,
                        name: 'Inscriptions',
                        animationDuration: 1400,
                        color: kGreen,
                        width: 2.5,
                        splineType: SplineType.natural,
                        markerSettings: MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 7,
                          width: 7,
                          borderWidth: 2,
                          borderColor: kGreen,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Pt {
  const _Pt(this.label, this.y, this.color);
  final String label;
  final int y;
  final Color color;
}

class _TypeDonut extends StatefulWidget {
  const _TypeDonut({required this.data});
  final AdminDashboardData data;

  @override
  State<_TypeDonut> createState() => _TypeDonutState();
}

class _TypeDonutState extends State<_TypeDonut> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, format: 'point.x : point.y');

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final all = <_Pt>[
      _Pt('Public', d.publicCount, _kBlue),
      _Pt('Privé', d.priveCount, kGreen),
      _Pt('Mixte', d.mixteCount, _kPurple),
    ];
    final pts = all.where((p) => p.y > 0).toList();
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle(
            'Répartition & parité',
            icon: Icons.pie_chart_rounded,
            subtitle: 'Écoles par type · élèves par sexe',
          ),
          const SizedBox(height: 14),
          if (d.ecolesTotal == 0)
            const SizedBox(
              height: 150,
              child: _ChartEmpty(
                  message: 'Ajoutez vos écoles pour visualiser leur répartition.'),
            )
          else ...[
            SizedBox(
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SfCircularChart(
                    backgroundColor: Colors.transparent,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    series: <CircularSeries<_Pt, String>>[
                      DoughnutSeries<_Pt, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.y,
                        pointColorMapper: (p, _) => p.color,
                        animationDuration: 1100,
                        innerRadius: '64%',
                        radius: '92%',
                        strokeColor: Colors.white,
                        strokeWidth: 2.5,
                        dataLabelSettings:
                            const DataLabelSettings(isVisible: false),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtInt(d.ecolesTotal),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text('écoles',
                          style: TextStyle(fontSize: 11, color: kTextMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final p in all)
                  _LegendDot(color: p.color, text: '${p.label} ${p.y}'),
              ],
            ),
            Divider(height: 26, color: kBorder),
            Text('Parité élèves',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 10),
            _GenderRow(
                label: 'Garçons',
                count: d.studentsM,
                total: d.elevesTotal,
                color: _kBlue),
            const SizedBox(height: 8),
            _GenderRow(
                label: 'Filles',
                count: d.studentsF,
                total: d.elevesTotal,
                color: _kPink),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }
}

class _GenderRow extends StatelessWidget {
  const _GenderRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
        ),
        Expanded(
          child: AdminProgressBar(
              value: count, max: total <= 0 ? 1 : total, height: 8, color: color),
        ),
        const SizedBox(width: 10),
        Text('$count',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        if (total > 0)
          Text('  ·  $pct%',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded,
              size: 34, color: kTextMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ─── Ressources humaines · statut d'emploi (fonctionnaires / non) ───────────
// Nomenclature métier (fonction publique congolaise) :
//   • « Fonctionnaires de l'État » = agents titulaires (contrat permanent).
//   • « Personnel non fonctionnaire » = contractuels, vacataires, stagiaires.
class _RhSection extends StatelessWidget {
  const _RhSection({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.personnelTotal;
    final fonc  = data.fonctionnaires;
    final non   = data.nonFonctionnaires;
    final tauxF = data.tauxFonctionnaires;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            "Ressources humaines · statut d'emploi",
            icon: Icons.badge_rounded,
            subtitle: "Fonctionnaires de l'État vs personnel non fonctionnaire",
            trailing: total == 0
                ? null
                : _PillChip(
                    label: '$total agents',
                    color: kNavy,
                    icon: Icons.groups_rounded,
                  ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const _ChartEmpty(
              message:
                  "Aucune donnée de personnel pour le moment.\nLes statuts d'emploi s'afficheront ici dès l'enregistrement du personnel.",
            )
          else
            LayoutBuilder(
              builder: (ctx, c) {
                final headline =
                    _RhHeadline(fonc: fonc, non: non, total: total, tauxF: tauxF);
                final breakdown = _RhBreakdown(data: data);
                if (c.maxWidth < 740) {
                  return Column(
                    children: [
                      headline,
                      const SizedBox(height: 20),
                      breakdown,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: headline),
                    const SizedBox(width: 26),
                    Expanded(flex: 4, child: breakdown),
                  ],
                );
              },
            ),
          if (total > 0) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: kBorder),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _MiniStat(emoji: '👨‍🏫', value: '${data.enseignantsTotal} enseignants'),
                _MiniStat(emoji: '🗂️', value: '${data.personnelAdministratif} administratifs'),
                _MiniStat(emoji: '🏢', value: '${data.coveredDepts} départements'),
                _MiniStat(emoji: '🏫', value: '${data.ecolesActives} écoles actives'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RhHeadline extends StatelessWidget {
  const _RhHeadline({
    required this.fonc,
    required this.non,
    required this.total,
    required this.tauxF,
  });
  final int fonc, non, total;
  final double tauxF;

  @override
  Widget build(BuildContext context) {
    final tauxN = 100 - tauxF;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RhTile(
                label: "Fonctionnaires de l'État",
                hint: 'Agents titulaires (permanents)',
                value: fonc,
                pct: tauxF,
                color: kNavy,
                icon: Icons.account_balance_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RhTile(
                label: 'Non fonctionnaires',
                hint: 'Contractuels · vacataires · stagiaires',
                value: non,
                pct: tauxN,
                color: _kTeal,
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: fonc <= 0 ? 0 : fonc,
                child: Container(height: 12, color: kNavy),
              ),
              Expanded(
                flex: non <= 0 ? 0 : non,
                child: Container(height: 12, color: _kTeal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _LegendDot(color: kNavy, text: 'Fonctionnaires ${tauxF.toStringAsFixed(0)} %'),
            const SizedBox(width: 16),
            _LegendDot(color: _kTeal, text: 'Non fonct. ${tauxN.toStringAsFixed(0)} %'),
          ],
        ),
      ],
    );
  }
}

class _RhTile extends StatelessWidget {
  const _RhTile({
    required this.label,
    required this.hint,
    required this.value,
    required this.pct,
    required this.color,
    required this.icon,
  });
  final String label, hint;
  final int value;
  final double pct;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text('${pct.toStringAsFixed(0)} %',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(fmtInt(value),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  height: 1)),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      ),
    );
  }
}

class _RhBreakdown extends StatelessWidget {
  const _RhBreakdown({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.personnelTotal;
    const order = ['permanent', 'contractuel', 'vacataire', 'stagiaire'];
    final rows = <(String, int)>[
      for (final k in order)
        if ((data.staffByContract[k] ?? 0) > 0) (k, data.staffByContract[k]!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Détail par type de contrat',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 14),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LegendDot(color: _contractColor(k), text: _contractLabel(k)),
                    const Spacer(),
                    Text('$v',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary)),
                    const SizedBox(width: 6),
                    Text('· ${total == 0 ? 0 : (v / total * 100).round()} %',
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
                const SizedBox(height: 7),
                AdminProgressBar(
                    value: v, max: total, color: _contractColor(k), height: 7),
              ],
            ),
          ),
      ],
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

String _contractLabel(String c) => switch (c) {
      'permanent' => 'Titulaires (permanents)',
      'contractuel' => 'Contractuels',
      'vacataire' => 'Vacataires',
      'stagiaire' => 'Stagiaires',
      _ => c,
    };

Color _contractColor(String c) => switch (c) {
      'permanent' => kNavy,
      'contractuel' => _kBlue,
      'vacataire' => _kOrange,
      'stagiaire' => _kPink,
      _ => kTextMuted,
    };

// ─── Couverture territoriale ────────────────────────────────────────────────
class _DeptSection extends StatefulWidget {
  const _DeptSection({required this.data});
  final AdminDashboardData data;

  @override
  State<_DeptSection> createState() => _DeptSectionState();
}

class _DeptSectionState extends State<_DeptSection> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final entries = d.schoolsByDept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxV =
        entries.isEmpty ? 0 : entries.map((e) => e.value).reduce(math.max);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Couverture territoriale',
            icon: Icons.location_city_rounded,
            subtitle: '${d.coveredDepts} département(s) · ${d.ecolesTotal} école(s)',
            trailing: AdminBadge(
              entries.isEmpty ? 'Aucune donnée' : 'Données réelles',
              color: entries.isEmpty ? kTextMuted : kGreen,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const _InlineEmpty(
                message:
                    'Renseignez le département de vos écoles pour suivre votre couverture.')
          else
            for (final e in entries)
              _DeptBar(
                name: e.key,
                schools: e.value,
                students: d.studentsByDept[e.key] ?? 0,
                maxV: maxV,
                selected: _sel == e.key,
                onTap: () =>
                    setState(() => _sel = _sel == e.key ? null : e.key),
              ),
          if (_sel != null) _DeptSchools(data: d, dept: _sel!),
        ],
      ),
    );
  }
}

class _DeptBar extends StatelessWidget {
  const _DeptBar({
    required this.name,
    required this.schools,
    required this.students,
    required this.maxV,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final int schools;
  final int students;
  final int maxV;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? kNavy.withValues(alpha: 0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      selected ? kNavy.withValues(alpha: 0.25) : Colors.transparent),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: selected ? 0.25 : 0,
                      child: Icon(Icons.chevron_right_rounded,
                          size: 16, color: kTextMuted),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary)),
                    ),
                    Text('$schools école${schools > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                    const SizedBox(width: 10),
                    Text('$students élève${students > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 11.5, color: kTextMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                AdminProgressBar(
                    value: schools, max: maxV <= 0 ? 1 : maxV, height: 7, color: kNavy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeptSchools extends StatelessWidget {
  const _DeptSchools({required this.data, required this.dept});
  final AdminDashboardData data;
  final String dept;

  @override
  Widget build(BuildContext context) {
    final list = data.schools.where((s) => _deptKeyOf(s) == dept).toList();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Écoles · $dept',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kTextMuted)),
          const SizedBox(height: 8),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('🏫', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: kTextPrimary)),
                  ),
                  _TypeChip(s.type),
                  const SizedBox(width: 8),
                  Text('${s.students} él.',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: kTextMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    final c = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(_typeLabel(type),
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ─── Centre de gouvernance ──────────────────────────────────────────────────
class _Alert {
  const _Alert(this.icon, this.color, this.text, [this.route]);
  final IconData icon;
  final Color color;
  final String text;
  final String? route;
}

class _Check {
  const _Check(this.label, this.ok);
  final String label;
  final bool ok;
}

class _Governance extends StatelessWidget {
  const _Governance({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts(data);
    final checks = _compliance(data);

    final alertsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHead(icon: Icons.notifications_active_rounded, text: 'Alertes & interventions'),
        const SizedBox(height: 10),
        for (final a in alerts)
          _AlertRow(
            alert: a,
            onTap: a.route == null ? null : () => context.go(a.route!),
          ),
      ],
    );

    final actionsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubHead(icon: Icons.task_alt_rounded, text: 'Actions recommandées'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QaChip(
                label: 'Gérer les écoles',
                icon: Icons.account_balance_rounded,
                onTap: () => context.go(Routes.adminEcoles)),
            _QaChip(
                label: 'Personnel',
                icon: Icons.people_alt_rounded,
                onTap: () => context.go(Routes.adminUtilisateurs)),
            _QaChip(
                label: 'Rapports',
                icon: Icons.assessment_rounded,
                onTap: () => context.go(Routes.adminRapports)),
          ],
        ),
        const SizedBox(height: 18),
        const _SubHead(icon: Icons.fact_check_rounded, text: 'Conformité'),
        const SizedBox(height: 10),
        for (final ch in checks) _CheckRow(check: ch),
      ],
    );

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle(
            'Centre de gouvernance',
            icon: Icons.shield_rounded,
            subtitle: 'Alertes, actions et indicateurs de conformité',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (ctx, c) {
              if (c.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    alertsBlock,
                    const SizedBox(height: 20),
                    actionsBlock,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: alertsBlock),
                  const SizedBox(width: 24),
                  Expanded(child: actionsBlock),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubHead extends StatelessWidget {
  const _SubHead({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kNavy),
        const SizedBox(width: 7),
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, this.onTap});
  final _Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: alert.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(alert.icon, size: 17, color: alert.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(alert.text,
                style: TextStyle(
                    fontSize: 12.5, color: kTextPrimary, height: 1.3)),
          ),
          if (onTap != null)
            Icon(Icons.arrow_forward_ios,
                size: 11, color: alert.color.withValues(alpha: 0.7)),
        ],
      ),
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final c = check.ok ? kGreen : kTextMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
              check.ok
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: c),
          const SizedBox(width: 9),
          Expanded(
            child: Text(check.label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: check.ok ? kTextPrimary : kTextMuted)),
          ),
        ],
      ),
    );
  }
}

List<_Alert> _buildAlerts(AdminDashboardData d) {
  final out = <_Alert>[];
  if (d.expireBientot) {
    out.add(_Alert(Icons.event_busy_rounded, kRed,
        'Votre abonnement arrive à échéance prochainement.', Routes.adminAbonnement));
  }
  final inactive = d.ecolesTotal - d.ecolesActives;
  if (inactive > 0) {
    out.add(_Alert(Icons.domain_disabled_rounded, kAccent,
        '$inactive école(s) inactive(s) à réactiver ou archiver.', Routes.adminEcoles));
  }
  final emptySchools = d.schools.where((s) => s.students == 0).length;
  if (emptySchools > 0 && d.ecolesTotal > 0) {
    out.add(_Alert(Icons.person_off_rounded, kAccent,
        '$emptySchools école(s) sans élève inscrit.', Routes.adminEcoles));
  }
  if (d.ecolesTotal > 0 && d.classesTotal == 0) {
    out.add(const _Alert(Icons.meeting_room_outlined, _kBlue,
        'Aucune classe configurée dans le groupe.', Routes.adminEcoles));
  }
  if (d.elevesImpayes > 0) {
    out.add(_Alert(Icons.receipt_long_rounded, kAccent,
        '${d.elevesImpayes} élève(s) en situation d\'impayé.', Routes.adminRapports));
  }
  if (d.tauxOccupationEleves >= 90) {
    out.add(_Alert(Icons.warning_amber_rounded, kRed,
        "Quota d'élèves de votre plan presque atteint.", Routes.adminAbonnement));
  }
  if (out.isEmpty) {
    out.add(_Alert(Icons.verified_rounded, kGreen,
        'Aucune alerte — votre groupe est conforme.'));
  }
  return out;
}

List<_Check> _compliance(AdminDashboardData d) => [
      _Check('Écoles toutes actives',
          d.ecolesTotal > 0 && d.ecolesActives == d.ecolesTotal),
      _Check('Classes configurées', d.classesTotal > 0),
      _Check('Corps enseignant renseigné',
          d.enseignantsTotal > 0 || d.personnelTotal > 0),
      _Check('Suivi des paiements actif', d.paiementsMoisCount > 0),
      _Check('Départements couverts', d.coveredDepts > 0),
    ];

// ─── Centre de décision · établissements à risque ───────────────────────────
enum _RiskLevel { critique, eleve, modere }

class _SchoolRisk {
  _SchoolRisk(this.school, this.reasons, this.score);
  final SchoolSummary school;
  final List<String> reasons;
  final int score;
  _RiskLevel get level => score >= 6
      ? _RiskLevel.critique
      : (score >= 3 ? _RiskLevel.eleve : _RiskLevel.modere);
}

({Color color, String label}) _riskStyle(_RiskLevel l) => switch (l) {
      _RiskLevel.critique => (color: kRed, label: 'Critique'),
      _RiskLevel.eleve => (color: kAccent, label: 'Élevé'),
      _RiskLevel.modere => (color: _kBlue, label: 'Modéré'),
    };

/// Évalue le niveau de risque de chaque établissement à partir de données
/// réelles (activité, effectifs, personnel, classes, taux d'encadrement).
/// Sert la prise de décision : où intervenir en priorité.
List<_SchoolRisk> _assessRisks(AdminDashboardData d) {
  final out = <_SchoolRisk>[];
  for (final s in d.schools) {
    final reasons = <String>[];
    var score = 0;

    if (!s.isActive) {
      reasons.add('Établissement inactif — à réactiver ou archiver');
      out.add(_SchoolRisk(s, reasons, 5));
      continue;
    }
    if (s.students == 0) {
      reasons.add('Aucun élève inscrit');
      score += 4;
    } else {
      if (s.staff == 0) {
        reasons.add('Aucun personnel affecté');
        score += 4;
      }
      if (s.classes == 0) {
        reasons.add('Aucune classe configurée');
        score += 3;
      } else {
        final perClass = s.students / s.classes;
        if (perClass > 50) {
          reasons.add('Surcharge : ${perClass.round()} élèves/classe');
          score += 2;
        }
      }
      if (s.staff > 0) {
        final perStaff = s.students / s.staff;
        if (perStaff > 35) {
          reasons.add('Encadrement faible : ${perStaff.round()} élèves/agent');
          score += 2;
        }
      }
    }
    if (reasons.isNotEmpty) out.add(_SchoolRisk(s, reasons, score));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

class _RiskCenter extends StatelessWidget {
  const _RiskCenter({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final risks = _assessRisks(data);
    final crit = risks.where((r) => r.level == _RiskLevel.critique).length;
    final elev = risks.where((r) => r.level == _RiskLevel.eleve).length;
    final mod = risks.where((r) => r.level == _RiskLevel.modere).length;
    final sains = data.schools.length - risks.length;
    final shown = risks.take(6).toList();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Établissements à surveiller',
            icon: Icons.health_and_safety_rounded,
            subtitle: 'Indicateurs de risque · interventions prioritaires',
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminEcoles),
              child: Text('Gérer',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RiskStat(
                  label: 'Critiques',
                  count: crit,
                  color: kRed,
                  icon: Icons.error_rounded),
              _RiskStat(
                  label: 'Risque élevé',
                  count: elev,
                  color: kAccent,
                  icon: Icons.warning_amber_rounded),
              _RiskStat(
                  label: 'À surveiller',
                  count: mod,
                  color: _kBlue,
                  icon: Icons.visibility_rounded),
              _RiskStat(
                  label: 'Conformes',
                  count: sains < 0 ? 0 : sains,
                  color: kGreen,
                  icon: Icons.verified_rounded),
            ],
          ),
          const SizedBox(height: 16),
          if (data.schools.isEmpty)
            const _InlineEmpty(
                message:
                    'Aucun établissement enregistré — ajoutez vos écoles pour activer la surveillance du réseau.')
          else if (risks.isEmpty)
            const _AllClearRow()
          else ...[
            for (final r in shown)
              _RiskRow(risk: r, onTap: () => context.go(Routes.adminEcoles)),
            if (risks.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 2),
                child: Text(
                    '+ ${risks.length - shown.length} autre(s) établissement(s) à examiner',
                    style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ],
      ),
    );
  }
}

class _RiskStat extends StatelessWidget {
  const _RiskStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final c = active ? color : kTextMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: active ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: active ? 0.20 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: c)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.risk, required this.onTap});
  final _SchoolRisk risk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = _riskStyle(risk.level);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                    color: st.color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(risk.school.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                        ),
                        const SizedBox(width: 8),
                        _RiskBadge(color: st.color, label: st.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final reason in risk.reasons)
                          _ReasonChip(text: reason, color: st.color),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.arrow_forward_ios,
                    size: 11, color: kTextMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2)),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.30))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AllClearRow extends StatelessWidget {
  const _AllClearRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, color: kGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réseau sain — aucun établissement à risque',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(
                    'Tous vos établissements actifs disposent d\'élèves, de personnel et de classes configurées.',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Établissements en tête + activité ──────────────────────────────────────
class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final top = _TopSchools(data: data);
        final act = _ActivityCard(data: data);
        if (c.maxWidth < 840) {
          return Column(children: [top, const SizedBox(height: 18), act]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: top),
            const SizedBox(width: 18),
            Expanded(flex: 2, child: act),
          ],
        );
      },
    );
  }
}

class _TopSchools extends StatelessWidget {
  const _TopSchools({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final ranked = [...data.schools]
      ..sort((a, b) => b.students.compareTo(a.students));
    final top = ranked.take(5).toList();
    final maxStu =
        top.isEmpty ? 0 : top.map((s) => s.students).reduce(math.max);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Établissements en tête',
            icon: Icons.emoji_events_rounded,
            subtitle: 'Classés par effectif élèves',
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminEcoles),
              child: Text('Tout voir',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 6),
          if (top.isEmpty)
            const _InlineEmpty(message: 'Aucune école enregistrée pour le moment.')
          else
            for (int i = 0; i < top.length; i++)
              _SchoolRankRow(
                rank: i + 1,
                s: top[i],
                maxStu: maxStu,
                onTap: () => context.go(Routes.adminEcoles),
              ),
        ],
      ),
    );
  }
}

class _SchoolRankRow extends StatelessWidget {
  const _SchoolRankRow({
    required this.rank,
    required this.s,
    required this.maxStu,
    required this.onTap,
  });
  final int rank;
  final SchoolSummary s;
  final int maxStu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(s.type),
                      ],
                    ),
                    const SizedBox(height: 7),
                    AdminProgressBar(
                        value: s.students,
                        max: maxStu <= 0 ? 1 : maxStu,
                        height: 6,
                        color: kNavy),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _MiniStat(emoji: '🎓', value: '${s.students}'),
                        _MiniStat(emoji: '👨‍🏫', value: '${s.staff}'),
                        _MiniStat(emoji: '📚', value: '${s.classes}'),
                        if (s.city != null && s.city!.isNotEmpty)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.place_rounded,
                                    size: 12, color: kTextMuted.withValues(alpha: 0.7)),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(s.city!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11, color: kTextMuted)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (kAccent, const Color(0xFF7A5C00)),
      2 => (const Color(0xFFCBD5E1), const Color(0xFF334155)),
      3 => (const Color(0xFFFAD9B8), const Color(0xFF8A4B14)),
      _ => (kNavy.withValues(alpha: 0.1), kNavy),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text('$rank',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.emoji, required this.value});
  final String emoji;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.data});
  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final acts = data.recentActivity;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(
            'Activité récente',
            icon: Icons.history_rounded,
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminAudit),
              child: Text('Journal',
                  style: TextStyle(
                      color: kNavy, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 6),
          if (acts.isEmpty)
            const _InlineEmpty(message: 'Aucune activité récente à afficher.')
          else
            for (final a in acts.take(7))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(9)),
                      child: Text(a.icon, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary)),
                          Text(a.time,
                              style: TextStyle(
                                  fontSize: 11, color: kTextMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.inbox_rounded, size: 18, color: kTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ─── États chargement / erreur ──────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
        );
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDF3),
      highlightColor: const Color(0xFFF7FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        children: [
          block(112),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: block(168)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(flex: 3, child: block(300)),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: block(300)),
            ],
          ),
          const SizedBox(height: 24),
          block(220),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 64),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle),
                  child: Icon(Icons.cloud_off_rounded,
                      size: 40, color: kRed),
                ),
                const SizedBox(height: 18),
                Text('Impossible de charger le tableau de bord',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────
String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

const List<String> _kJours = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];
const List<String> _kMois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _frDate() {
  final n = DateTime.now();
  return '${_kJours[n.weekday - 1]} ${n.day} ${_kMois[n.month - 1]} ${n.year}';
}

String _pct(double v) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)} %';

String _deptKeyOf(SchoolSummary s) {
  final d = s.department?.trim();
  return (d == null || d.isEmpty) ? 'Non précisé' : d;
}

String _typeLabel(String t) => switch (t) {
      'public' => 'Public',
      'prive' => 'Privé',
      'mixte' => 'Mixte',
      _ => t,
    };

Color _typeColor(String t) => switch (t) {
      'public' => _kBlue,
      'prive' => kGreen,
      'mixte' => _kPurple,
      _ => kTextMuted,
    };
