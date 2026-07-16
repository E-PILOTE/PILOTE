import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/admin_reports_provider.dart';
import '../services/reports_pdf_service.dart';
import '../../../core/widgets/admin_ui.dart';

// ─── Accents locaux (complètent la palette admin_ui) ────────────────────────
const Color _kPurple = Color(0xFF7C3AED);
const Color _kBlue   = Color(0xFF0EA5E9);
const Color _kPink   = Color(0xFFEC4899);
const Color _kOrange = Color(0xFFF97316);
const Color _kTeal   = Color(0xFF14B8A6);

List<Color> get _kPalette => [
  kNavy, kGreen, _kPurple, _kOrange, _kBlue, _kTeal, _kPink, kAccent,
];

// ─── Section courante (état UI local) ───────────────────────────────────────
enum _Section { synthese, effectifs, finance, rh, etablissements }

final _sectionProvider =
    StateProvider.autoDispose<_Section>((_) => _Section.synthese);

const List<(_Section, String, IconData)> _kSections = [
  (_Section.synthese, 'Synthèse', Icons.dashboard_rounded),
  (_Section.effectifs, 'Effectifs', Icons.groups_rounded),
  (_Section.finance, 'Finance', Icons.payments_rounded),
  (_Section.rh, 'Personnel', Icons.badge_rounded),
  (_Section.etablissements, 'Établissements', Icons.account_balance_rounded),
];

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════════════
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final async = ref.watch(reportDataProvider(filter));
    return AppShell(
      title: 'Rapports',
      child: RefreshIndicator(
        color: kNavy,
        onRefresh: () => ref.refresh(reportsSnapshotProvider.future),
        child: async.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _ShimmerSkeleton(),
          error: (e, _) => _ErrorView(
            error: e,
            onRetry: () => ref.invalidate(reportsSnapshotProvider),
          ),
          data: (d) => _Body(data: d),
        ),
      ),
    );
  }
}

// ─── Vue d'erreur (scrollable → pull-to-refresh actif) ───────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Impossible de charger les rapports.\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  BODY
// ════════════════════════════════════════════════════════════════════════════
class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(_sectionProvider);

    return LayoutBuilder(builder: (ctx, constraints) {
      final double w = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(ctx).size.width - 80;

      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ControlBar(data: data),
                const SizedBox(height: 16),
                _SectionTabs(
                  current: section,
                  onChanged: (s) =>
                      ref.read(_sectionProvider.notifier).state = s,
                ),
                const SizedBox(height: 20),
                switch (section) {
                  _Section.synthese => _SyntheseSection(data: data),
                  _Section.effectifs => _EffectifsSection(data: data),
                  _Section.finance => _FinanceSection(data: data),
                  _Section.rh => _RhSection(data: data),
                  _Section.etablissements => _EtablissementsSection(data: data),
                },
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BARRE DE CONTRÔLE : groupe · période · école · export
// ════════════════════════════════════════════════════════════════════════════
class _ControlBar extends ConsumerStatefulWidget {
  const _ControlBar({required this.data});
  final ReportData data;

  @override
  ConsumerState<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends ConsumerState<_ControlBar> {
  bool _busy = false;

  ReportFilter get _filter => ref.read(reportFilterProvider);
  void _set(ReportFilter f) =>
      ref.read(reportFilterProvider.notifier).state = f;

  void _setPeriodKind(ReportPeriodKind kind) {
    if (kind == ReportPeriodKind.custom) {
      _pickCustomRange();
      return;
    }
    _set(_filter.copyWith(period: ReportPeriod(kind: kind)));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final cur = _filter.period;
    final initStart = cur.customStart ?? DateTime(now.year, now.month, 1);
    final initEnd = cur.customEnd ?? now;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initStart, end: initEnd),
      helpText: 'Période personnalisée',
      saveText: 'Valider',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: kNavy),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      _set(_filter.copyWith(
        period: ReportPeriod(
          kind: ReportPeriodKind.custom,
          customStart: range.start,
          customEnd: range.end,
        ),
      ));
    }
  }

  void _setSchool(String? id) => _set(_filter.copyWith(schoolId: id));

  Future<void> _export({required bool download}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (download) {
        final path = await ReportsPdfService.downloadReport(data: widget.data);
        messenger.showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text(path == null
              ? 'PDF généré.'
              : 'PDF enregistré : $path'),
        ));
      } else {
        await ReportsPdfService.printReport(data: widget.data);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Export impossible : $e'), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(reportFilterProvider);
    final d = widget.data;
    final scoped = filter.schoolId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : identité groupe + export ──────────────────────────
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [const Color(0xFF1A2F5A), kNavy]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.groupName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    AdminBadge('Plan ${d.planName}',
                        color: planColor(d.planName.toLowerCase()),
                        icon: Icons.workspace_premium_rounded),
                    AdminBadge(
                        '${d.periodLabel} · ${_fmtD(d.periodStart)} – ${_fmtD(d.periodEnd)}',
                        color: kNavy,
                        icon: Icons.event_rounded),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ExportControls(busy: _busy, onExport: _export),
          ]),
          const SizedBox(height: 14),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          // ── Filtres : période + école ───────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PeriodSelector(
                period: filter.period,
                onChanged: _setPeriodKind,
              ),
              _SchoolSelector(
                schools: d.allSchools,
                selectedId: filter.schoolId,
                onChanged: _setSchool,
              ),
              if (scoped)
                _ScopeChip(
                  label: d.scopeLabel,
                  onClear: () => _setSchool(null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Boutons d'export (imprimer + télécharger) ──────────────────────────────
class _ExportControls extends StatelessWidget {
  const _ExportControls({required this.busy, required this.onExport});
  final bool busy;
  final Future<void> Function({required bool download}) onExport;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MouseRegion(
        cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: busy ? null : () => onExport(download: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), kNavy]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded,
                      size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(busy ? 'Génération…' : 'Imprimer / PDF',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: 'Télécharger le PDF',
        child: MouseRegion(
          cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: busy ? null : () => onExport(download: true),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Icon(Icons.download_rounded, size: 18, color: kNavy),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Sélecteur de période (segmenté + perso) ────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final ReportPeriod period;
  final ValueChanged<ReportPeriodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <(ReportPeriodKind, String)>[
      (ReportPeriodKind.year, 'Année'),
      (ReportPeriodKind.trimester1, 'T1'),
      (ReportPeriodKind.trimester2, 'T2'),
      (ReportPeriodKind.trimester3, 'T3'),
      (ReportPeriodKind.custom, 'Perso.'),
    ];

    Widget seg((ReportPeriodKind, String) e) {
      final sel = period.kind == e.$1;
      return GestureDetector(
        onTap: () => onChanged(e.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (e.$1 == ReportPeriodKind.custom)
              Icon(Icons.tune_rounded,
                  size: 13, color: sel ? Colors.white : kTextMuted),
            if (e.$1 == ReportPeriodKind.custom) const SizedBox(width: 4),
            Text(e.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextMuted,
                )),
          ]),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.date_range_rounded, size: 16, color: kTextMuted),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min, children: entries.map(seg).toList()),
      ),
    ]);
  }
}

// ─── Sélecteur d'établissement ──────────────────────────────────────────────
class _SchoolSelector extends StatelessWidget {
  const _SchoolSelector({
    required this.schools,
    required this.selectedId,
    required this.onChanged,
  });
  final List<ReportSchoolRow> schools;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedId == null ? null : schools.where((s) => s.id == selectedId);
    final label = (selected == null || selected.isEmpty)
        ? 'Toutes les écoles'
        : selected.first.name;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrer par établissement',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) => onChanged(v == '__all__' ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: '__all__',
          child: _menuRow(
              Icons.public_rounded, 'Toutes les écoles', selectedId == null),
        ),
        const PopupMenuDivider(),
        ...schools.map((s) => PopupMenuItem<String?>(
              value: s.id,
              child: _menuRow(Icons.account_balance_rounded, s.name,
                  s.id == selectedId,
                  sub: '${s.students} élèves'),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_rounded, size: 16, color: kNavy),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 18, color: kTextMuted),
        ]),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, bool selected, {String? sub}) =>
      Row(children: [
        Icon(icon, size: 16, color: selected ? kNavy : kTextMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? kNavy : kTextPrimary)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ),
        if (selected)
          Icon(Icons.check_rounded, size: 16, color: kNavy),
      ]);
}

// ─── Chip de scope actif (école sélectionnée) ───────────────────────────────
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kNavy.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_alt_rounded, size: 14, color: kNavy),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 15, color: kNavy),
            ),
          ),
        ]),
      );
}

// ─── Onglets de section ─────────────────────────────────────────────────────
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current, required this.onChanged});
  final _Section current;
  final ValueChanged<_Section> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kSections.map((e) {
          final sel = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kNavy : kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? kNavy : kBorder),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: kNavy.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.$3,
                      size: 16, color: sel ? Colors.white : kTextMuted),
                  const SizedBox(width: 7),
                  Text(e.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : kTextMuted,
                      )),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  KPI (cartes animées génériques)
// ════════════════════════════════════════════════════════════════════════════
class _KD {
  const _KD({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.trend,
    this.trendUp = true,
    this.progress,
  });
  final String label, value;
  final String? sub, trend;
  final bool trendUp;
  final double? progress;
  final IconData icon;
  final Color color;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<_KD> items;

  @override
  Widget build(BuildContext context) {
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

class _KpiCardState extends State<_KpiCard>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 50 * widget.idx), () {
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
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hov ? 0.08 : 0.04),
                  blurRadius: _hov ? 12 : 4,
                  offset: Offset(0, _hov ? 4 : 2),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      d.color,
                      d.color.withValues(alpha: _hov ? 0.9 : 0.4),
                    ])),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: d.color,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(d.label,
                                        style: TextStyle(
                                          color: kTextMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                    if (d.sub != null)
                                      Text(d.sub!,
                                          style: TextStyle(
                                            color:
                                                d.color.withValues(alpha: 0.70),
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child:
                                    Icon(d.icon, color: d.color, size: 18),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(children: [
                            if (d.progress != null)
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: d.progress!.clamp(0.0, 1.0),
                                    backgroundColor:
                                        d.color.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation(
                                        d.color.withValues(
                                            alpha: _hov ? 1.0 : 0.75)),
                                    minHeight: 4,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            if (d.trend != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(d.trend!,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          d.trendUp ? d.color : _kOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ],
                          ]),
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

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · SYNTHÈSE
// ════════════════════════════════════════════════════════════════════════════
class _SyntheseSection extends StatelessWidget {
  const _SyntheseSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.insights_rounded,
        title: 'Aucune donnée à analyser',
        message:
            'Dès que vos écoles enregistreront élèves, personnel et paiements, '
            'les rapports se rempliront automatiquement.',
      );
    }

    final kpis = [
      _KD(
        label: 'Établissements',
        value: '${d.schoolsTotal}',
        sub: '${d.schoolsActives} actif(s) · ${d.coveredDepts} dépt.',
        icon: Icons.account_balance_rounded,
        color: kNavy,
        progress: d.schoolsTotal > 0 ? d.schoolsActives / d.schoolsTotal : 0,
        trend: '${d.schoolsActives}/${d.schoolsTotal}',
      ),
      _KD(
        label: 'Élèves',
        value: fmtInt(d.elevesTotal),
        sub: '${d.studentsF} F · ${d.studentsM} G',
        icon: Icons.groups_rounded,
        color: kGreen,
        trend: d.elevesNouveaux > 0 ? '+${d.elevesNouveaux} période' : 'Effectif',
        trendUp: true,
      ),
      _KD(
        label: 'Personnel',
        value: fmtInt(d.personnelTotal),
        sub: '${d.fonctionnaires} fonct. · ${d.nonFonctionnaires} contr.',
        icon: Icons.badge_rounded,
        color: kAccent,
        trend: d.personnelNouveau > 0
            ? '+${d.personnelNouveau} période'
            : 'Effectif actif',
      ),
      _KD(
        label: 'Classes',
        value: fmtInt(d.classesTotal),
        sub: 'salles actives',
        icon: Icons.class_rounded,
        color: _kPurple,
        trend: d.elevesTotal > 0 && d.classesTotal > 0
            ? '${(d.elevesTotal / d.classesTotal).round()} élèves/classe'
            : '—',
      ),
      _KD(
        label: 'Revenus (période)',
        value: _compactXaf(d.revenusTotal),
        sub: '${d.paiementsCount} paiement(s)',
        icon: Icons.trending_up_rounded,
        color: kGreen,
        trend: 'FCFA',
      ),
      _KD(
        label: 'Recouvrement',
        value: '${d.tauxPaiement.toStringAsFixed(0)}%',
        sub: '${d.elevesAJour}/${d.elevesTotal} à jour',
        icon: Icons.verified_rounded,
        color: _rateColor(d.tauxPaiement),
        progress: d.tauxPaiement / 100,
        trend: d.elevesImpayes > 0 ? '${d.elevesImpayes} impayés' : 'Complet',
        trendUp: d.elevesImpayes == 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final trend = _TrendChart(
            title: 'Évolution des inscriptions',
            subtitle: d.periodLabel,
            points: d.enrollmentTrend,
            color: kGreen,
            icon: Icons.show_chart_rounded,
          );
          final donut = _CategoryDonut(
            title: 'Types d\'établissement',
            subtitle: 'Public · Privé · Mixte',
            icon: Icons.pie_chart_rounded,
            slices: [
              _Slice('Public', d.publicCount, _kBlue),
              _Slice('Privé', d.priveCount, kGreen),
              _Slice('Mixte', d.mixteCount, _kPurple),
            ],
            centerValue: fmtInt(d.schoolsTotal),
            centerLabel: 'écoles',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              trend,
              const SizedBox(height: 18),
              donut,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: trend),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: donut),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _HighlightsStrip(data: d),
      ],
    );
  }
}

// ─── Bandeau « faits marquants » ─────────────────────────────────────────────
class _HighlightsStrip extends StatelessWidget {
  const _HighlightsStrip({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Faits marquants de la période',
              icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 14),
          Wrap(spacing: 24, runSpacing: 14, children: [
            _Highlight(
                icon: Icons.person_add_alt_1_rounded,
                color: kGreen,
                value: '+${fmtInt(d.elevesNouveaux)}',
                label: 'nouveaux élèves'),
            _Highlight(
                icon: Icons.badge_rounded,
                color: kNavy,
                value: '+${fmtInt(d.personnelNouveau)}',
                label: 'recrutements'),
            _Highlight(
                icon: Icons.female_rounded,
                color: _kPink,
                value: '${d.pctFilles.toStringAsFixed(0)}%',
                label: 'de filles'),
            _Highlight(
                icon: Icons.supervisor_account_rounded,
                color: _kPurple,
                value: '1 : ${d.ratioEncadrement.toStringAsFixed(0)}',
                label: 'encadrement (agent/élèves)'),
            _Highlight(
                icon: Icons.account_balance_wallet_rounded,
                color: _kOrange,
                value: _compactXaf(d.revenuMoyenParEleve),
                label: 'revenu moyen / élève'),
            _Highlight(
                icon: Icons.workspace_premium_rounded,
                color: kAccent,
                value: '${d.tauxFonctionnaires.toStringAsFixed(0)}%',
                label: 'de fonctionnaires'),
          ]),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ],
        ),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · EFFECTIFS
// ════════════════════════════════════════════════════════════════════════════
class _EffectifsSection extends StatelessWidget {
  const _EffectifsSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.elevesTotal == 0) {
      return const AdminEmptyState(
        icon: Icons.groups_outlined,
        title: 'Aucun élève',
        message: 'Les effectifs apparaîtront ici dès la première inscription.',
      );
    }

    final kpis = [
      _KD(
          label: 'Élèves',
          value: fmtInt(d.elevesTotal),
          sub: 'effectif total',
          icon: Icons.groups_rounded,
          color: kGreen),
      _KD(
          label: 'Nouveaux (période)',
          value: '+${fmtInt(d.elevesNouveaux)}',
          sub: d.periodLabel,
          icon: Icons.person_add_alt_1_rounded,
          color: kNavy),
      _KD(
          label: 'Filles',
          value: fmtInt(d.studentsF),
          sub: '${d.pctFilles.toStringAsFixed(1)} %',
          icon: Icons.female_rounded,
          color: _kPink,
          progress: d.pctFilles / 100),
      _KD(
          label: 'Garçons',
          value: fmtInt(d.studentsM),
          sub: '${d.pctGarcons.toStringAsFixed(1)} %',
          icon: Icons.male_rounded,
          color: _kBlue,
          progress: d.pctGarcons / 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Inscriptions par mois',
          subtitle: '${d.periodLabel} · nouveaux élèves',
          points: d.enrollmentTrend,
          color: kGreen,
          icon: Icons.show_chart_rounded,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final parity = _ParityCard(data: d);
          final byDept = _DistributionBars(
            title: 'Élèves par département',
            subtitle: 'Répartition géographique',
            icon: Icons.map_rounded,
            data: d.studentsByDept,
            emptyMessage: 'Aucune donnée géographique.',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              parity,
              const SizedBox(height: 18),
              byDept,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: parity),
                const SizedBox(width: 18),
                Expanded(child: byDept),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Carte parité (filles / garçons) ────────────────────────────────────────
class _ParityCard extends StatelessWidget {
  const _ParityCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionTitle('Parité',
              icon: Icons.wc_rounded, subtitle: 'Filles / garçons'),
          const SizedBox(height: 18),
          _ParityRow(
              label: 'Filles',
              count: d.studentsF,
              total: d.elevesTotal,
              color: _kPink),
          const SizedBox(height: 14),
          _ParityRow(
              label: 'Garçons',
              count: d.studentsM,
              total: d.elevesTotal,
              color: _kBlue),
          const SizedBox(height: 18),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.balance_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _parityComment(d.pctFilles),
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  String _parityComment(double pctF) {
    if (pctF == 0) return 'Aucune donnée de genre renseignée.';
    final gap = (pctF - 50).abs();
    if (gap <= 5) return 'Équilibre filles/garçons quasi parfait.';
    if (pctF > 50) return 'Majorité de filles (+${gap.toStringAsFixed(0)} pts).';
    return 'Majorité de garçons (+${gap.toStringAsFixed(0)} pts).';
  }
}

class _ParityRow extends StatelessWidget {
  const _ParityRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
          const Spacer(),
          Text('${fmtInt(count)}  ·  ${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        AdminProgressBar(
            value: count, max: total <= 0 ? 1 : total, height: 9, color: color),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · FINANCE
// ════════════════════════════════════════════════════════════════════════════
class _FinanceSection extends StatelessWidget {
  const _FinanceSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final kpis = [
      _KD(
          label: 'Revenus (période)',
          value: fmtXaf(d.revenusTotal),
          icon: Icons.trending_up_rounded,
          color: kGreen,
          trend: d.periodLabel),
      _KD(
          label: 'Paiements',
          value: fmtInt(d.paiementsCount),
          sub: 'transactions confirmées',
          icon: Icons.receipt_long_rounded,
          color: kNavy),
      _KD(
          label: 'Élèves à jour',
          value: fmtInt(d.elevesAJour),
          sub: 'sur ${fmtInt(d.elevesTotal)}',
          icon: Icons.verified_rounded,
          color: kGreen,
          progress: d.elevesTotal > 0 ? d.elevesAJour / d.elevesTotal : 0,
          trend: '${d.tauxPaiement.toStringAsFixed(0)}%'),
      _KD(
          label: 'Élèves impayés',
          value: fmtInt(d.elevesImpayes),
          icon: Icons.warning_amber_rounded,
          color: kRed,
          trend: d.elevesImpayes > 0 ? 'À relancer' : 'Aucun',
          trendUp: d.elevesImpayes == 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Revenus encaissés par mois',
          subtitle: '${d.periodLabel} · paiements confirmés',
          points: d.revenueTrend,
          color: kGreen,
          icon: Icons.bar_chart_rounded,
          money: true,
        ),
        const SizedBox(height: 20),
        _RecoveryCard(data: d),
      ],
    );
  }
}

// ─── Carte taux de recouvrement ─────────────────────────────────────────────
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final taux = data.tauxPaiement;
    final color = _rateColor(taux);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: AdminSectionTitle('Taux de recouvrement',
                  icon: Icons.savings_rounded,
                  subtitle: 'Élèves ayant réglé au moins un paiement'),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text('${taux.toStringAsFixed(1)} %',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: (taux / 100).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _rateLegend('< 40%', kRed),
            const SizedBox(width: 14),
            _rateLegend('40 – 70%', kAccent),
            const SizedBox(width: 14),
            _rateLegend('≥ 70%', kGreen),
            const Spacer(),
            Text(
                '${fmtInt(data.elevesAJour)} à jour · ${fmtInt(data.elevesImpayes)} en attente',
                style: TextStyle(fontSize: 11.5, color: kTextMuted)),
          ]),
        ],
      ),
    );
  }

  Widget _rateLegend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · RESSOURCES HUMAINES
// ════════════════════════════════════════════════════════════════════════════
class _RhSection extends StatelessWidget {
  const _RhSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d.personnelTotal == 0) {
      return const AdminEmptyState(
        icon: Icons.badge_outlined,
        title: 'Aucun personnel',
        message:
            'Les statuts d\'emploi s\'afficheront ici dès l\'enregistrement du personnel.',
      );
    }

    final kpis = [
      _KD(
          label: 'Personnel',
          value: fmtInt(d.personnelTotal),
          sub: 'agents actifs',
          icon: Icons.badge_rounded,
          color: kNavy),
      _KD(
          label: 'Recrutés (période)',
          value: '+${fmtInt(d.personnelNouveau)}',
          sub: d.periodLabel,
          icon: Icons.person_add_alt_1_rounded,
          color: kGreen),
      _KD(
          label: 'Fonctionnaires',
          value: fmtInt(d.fonctionnaires),
          sub: '${d.tauxFonctionnaires.toStringAsFixed(0)} % du personnel',
          icon: Icons.workspace_premium_rounded,
          color: kAccent,
          progress: d.tauxFonctionnaires / 100),
      _KD(
          label: 'Non fonctionnaires',
          value: fmtInt(d.nonFonctionnaires),
          sub: 'contractuels & vacataires',
          icon: Icons.handshake_rounded,
          color: _kPurple),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(items: kpis),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (_, c) {
          final donut = _CategoryDonut(
            title: 'Par type de contrat',
            subtitle: 'Statut d\'emploi',
            icon: Icons.pie_chart_rounded,
            slices: _contractSlices(d.staffByContract),
            centerValue: fmtInt(d.personnelTotal),
            centerLabel: 'agents',
          );
          final ratio = _DistributionBars(
            title: 'Personnel par établissement',
            subtitle: 'Effectif par école',
            icon: Icons.account_balance_rounded,
            data: {for (final s in d.schoolRows) s.name: s.staff},
            emptyMessage: 'Aucun personnel rattaché.',
          );
          if (c.maxWidth < 840) {
            return Column(children: [
              donut,
              const SizedBox(height: 18),
              ratio,
            ]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: donut),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: ratio),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        _TrendChart(
          title: 'Recrutements par mois',
          subtitle: '${d.periodLabel} · nouvelles embauches',
          points: d.hireTrend,
          color: kNavy,
          icon: Icons.show_chart_rounded,
        ),
      ],
    );
  }

  List<_Slice> _contractSlices(Map<String, int> raw) {
    const labels = {
      'permanent': 'Permanents',
      'contractuel': 'Contractuels',
      'vacataire': 'Vacataires',
      'stagiaire': 'Stagiaires',
    };
    final out = <_Slice>[];
    var i = 0;
    raw.forEach((k, v) {
      if (v <= 0) return;
      out.add(_Slice(labels[k] ?? k, v, _kPalette[i % _kPalette.length]));
      i++;
    });
    return out;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION · ÉTABLISSEMENTS (tableau + drill-down)
// ════════════════════════════════════════════════════════════════════════════
class _EtablissementsSection extends ConsumerWidget {
  const _EtablissementsSection({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = data;
    if (d.schoolRows.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.school_outlined,
        title: 'Aucun établissement',
        message: 'Ajoutez des écoles depuis la page Mes Écoles.',
      );
    }

    void drill(String id) {
      final f = ref.read(reportFilterProvider);
      ref.read(reportFilterProvider.notifier).state = f.copyWith(schoolId: id);
      ref.read(_sectionProvider.notifier).state = _Section.synthese;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
            child: AdminSectionTitle('Détail par établissement',
                icon: Icons.account_tree_rounded,
                subtitle: 'Cliquez une ligne pour analyser une école'),
          ),
          Text('${d.schoolRows.length} école(s)',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
        const SizedBox(height: 12),
        _SchoolsTable(rows: d.schoolRows, onTap: drill),
        const SizedBox(height: 20),
        _DistributionBars(
          title: 'Établissements par département',
          subtitle: 'Couverture géographique',
          icon: Icons.map_rounded,
          data: d.schoolsByDept,
          emptyMessage: 'Aucune donnée géographique.',
        ),
      ],
    );
  }
}

class _SchoolsTable extends StatelessWidget {
  const _SchoolsTable({required this.rows, required this.onTap});
  final List<ReportSchoolRow> rows;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final table = Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: kSurface,
            child: Row(children: [
              Expanded(flex: 5, child: Text('ÉTABLISSEMENT', style: _kHeaderSt)),
              Expanded(flex: 2, child: Text('TYPE', style: _kHeaderSt)),
              Expanded(
                  flex: 3,
                  child: Text('ÉLÈVES (F/G)',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('PERSONNEL',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('CLASSES',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 3,
                  child: Text('REVENUS',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('STATUT',
                      style: _kHeaderSt, textAlign: TextAlign.right)),
            ]),
          ),
          Divider(height: 1, color: kBorder),
          ...rows.asMap().entries.map((e) =>
              _SchoolRow(s: e.value, isOdd: e.key.isOdd, onTap: onTap)),
        ]),
      ),
    );

    // Sur petit écran : défilement horizontal pour préserver les colonnes.
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth >= 760) return table;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: 760, child: table),
      );
    });
  }
}

TextStyle get _kHeaderSt =>
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted);

class _SchoolRow extends StatefulWidget {
  const _SchoolRow({required this.s, required this.isOdd, required this.onTap});
  final ReportSchoolRow s;
  final bool isOdd;
  final ValueChanged<String> onTap;

  @override
  State<_SchoolRow> createState() => _SchoolRowState();
}

class _SchoolRowState extends State<_SchoolRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => widget.onTap(s.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hov
                ? kNavy.withValues(alpha: 0.05)
                : widget.isOdd
                    ? kSurface.withValues(alpha: 0.5)
                    : kCardBg,
            border: Border(
                bottom: BorderSide(color: kBorder, width: 0.6)),
          ),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _typeColor(s.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.account_balance_rounded,
                      size: 15, color: _typeColor(s.type)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(s.city ?? s.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: kTextMuted)),
                    ],
                  ),
                ),
              ]),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(_typeLabel(s.type), color: _typeColor(s.type)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtInt(s.students),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  Text('${s.studentsF} F · ${s.studentsM} G',
                      style: TextStyle(fontSize: 11, color: kTextMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(fmtInt(s.staff),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              flex: 2,
              child: Text(fmtInt(s.classes),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              flex: 3,
              child: Text(_compactXaf(s.revenue),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kGreen)),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: AdminBadge(s.isActive ? 'Active' : 'Inactive',
                    color: s.isActive ? kGreen : kTextMuted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GRAPHE TENDANCE (lignes/aires Syncfusion)
// ════════════════════════════════════════════════════════════════════════════
class _TrendChart extends StatefulWidget {
  const _TrendChart({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
    this.icon = Icons.show_chart_rounded,
    this.money = false,
  });
  final String title, subtitle;
  final List<ReportTrendPoint> points;
  final Color color;
  final IconData icon;
  final bool money;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  late final TooltipBehavior _tt = TooltipBehavior(
    enable: true,
    color: kNavyDark,
    textStyle: const TextStyle(color: Colors.white),
    builder: (data, point, series, pointIndex, seriesIndex) {
      final p = data as ReportTrendPoint;
      final txt = widget.money ? fmtXaf(p.amount) : '${p.value}';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kNavyDark,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('${p.label} · $txt',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final total = widget.money
        ? pts.fold<double>(0, (a, b) => a + b.amount)
        : pts.fold<int>(0, (a, b) => a + b.value).toDouble();

    num yOf(ReportTrendPoint p) => widget.money ? p.amount : p.value;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(widget.title,
              icon: widget.icon, subtitle: widget.subtitle),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: total == 0
                ? const _ChartEmpty(
                    message: 'Aucune donnée sur la période sélectionnée.')
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
                      labelRotation: -35,
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
                      axisLabelFormatter: widget.money
                          ? (details) => ChartAxisLabel(
                              _compactXaf(details.value), details.textStyle)
                          : null,
                    ),
                    series: <CartesianSeries<ReportTrendPoint, String>>[
                      SplineAreaSeries<ReportTrendPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => yOf(p),
                        name: widget.title,
                        animationDuration: 1200,
                        splineType: SplineType.natural,
                        borderColor: widget.color,
                        borderWidth: 2.5,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.color.withValues(alpha: 0.28),
                            widget.color.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      SplineSeries<ReportTrendPoint, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => yOf(p),
                        name: widget.title,
                        animationDuration: 1200,
                        color: widget.color,
                        width: 2.5,
                        splineType: SplineType.natural,
                        markerSettings: MarkerSettings(
                          isVisible: true,
                          shape: DataMarkerType.circle,
                          height: 7,
                          width: 7,
                          borderWidth: 2,
                          borderColor: widget.color,
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

// ════════════════════════════════════════════════════════════════════════════
//  DONUT CATÉGORIES (Syncfusion)
// ════════════════════════════════════════════════════════════════════════════
class _Slice {
  const _Slice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _CategoryDonut extends StatefulWidget {
  const _CategoryDonut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
  });
  final String title, subtitle, centerValue, centerLabel;
  final IconData icon;
  final List<_Slice> slices;

  @override
  State<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<_CategoryDonut> {
  late final TooltipBehavior _tt =
      TooltipBehavior(enable: true, format: 'point.x : point.y');

  @override
  Widget build(BuildContext context) {
    final pts = widget.slices.where((s) => s.value > 0).toList();
    final hasData = pts.isNotEmpty;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(widget.title,
              icon: widget.icon, subtitle: widget.subtitle),
          const SizedBox(height: 14),
          if (!hasData)
            const SizedBox(
              height: 168,
              child: _ChartEmpty(message: 'Aucune donnée à répartir.'),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SfCircularChart(
                    backgroundColor: Colors.transparent,
                    margin: EdgeInsets.zero,
                    tooltipBehavior: _tt,
                    series: <CircularSeries<_Slice, String>>[
                      DoughnutSeries<_Slice, String>(
                        dataSource: pts,
                        xValueMapper: (p, _) => p.label,
                        yValueMapper: (p, _) => p.value,
                        pointColorMapper: (p, _) => p.color,
                        animationDuration: 1000,
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
                      Text(widget.centerValue,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      Text(widget.centerLabel,
                          style: TextStyle(
                              fontSize: 11, color: kTextMuted)),
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
                for (final p in widget.slices)
                  _LegendDot(color: p.color, text: '${p.label} ${p.value}'),
              ],
            ),
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  BARRES DE DISTRIBUTION (catégories triées)
// ════════════════════════════════════════════════════════════════════════════
class _DistributionBars extends StatelessWidget {
  const _DistributionBars({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.data,
    required this.emptyMessage,
  });
  final String title, subtitle, emptyMessage;
  final IconData icon;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    const maxItems = 8;
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, int>> shown = entries;
    int autres = 0;
    if (entries.length > maxItems) {
      shown = entries.take(maxItems).toList();
      autres = entries.skip(maxItems).fold(0, (a, b) => a + b.value);
    }
    final maxV =
        shown.isEmpty ? 1 : shown.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionTitle(title, icon: icon, subtitle: subtitle),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            SizedBox(height: 120, child: _ChartEmpty(message: emptyMessage))
          else ...[
            ...shown.asMap().entries.map((e) {
              final color = _kPalette[e.key % _kPalette.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BarRow(
                    label: e.value.key,
                    value: e.value.value,
                    max: maxV,
                    color: color),
              );
            }),
            if (autres > 0)
              _BarRow(
                  label: 'Autres',
                  value: autres,
                  max: maxV,
                  color: kTextMuted),
          ],
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });
  final String label;
  final int value, max;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5, color: kTextPrimary)),
            ),
            const SizedBox(width: 8),
            Text(fmtInt(value),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 6),
          AdminProgressBar(
              value: value, max: max <= 0 ? 1 : max, height: 8, color: color),
        ],
      );
}

// ─── État vide graphique ────────────────────────────────────────────────────
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
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

// ════════════════════════════════════════════════════════════════════════════
//  SHIMMER (chargement)
// ════════════════════════════════════════════════════════════════════════════
class _ShimmerSkeleton extends StatelessWidget {
  const _ShimmerSkeleton();

  Widget _box(double w, double h, {double r = 10}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
            color: kCardBg, borderRadius: BorderRadius.circular(r)),
      );

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFFE8ECF0),
        highlightColor: const Color(0xFFF5F7FA),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(double.infinity, 120, r: 12),
              const SizedBox(height: 16),
              _box(360, 42, r: 8),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.6,
                ),
                itemCount: 6,
                itemBuilder: (_, _) =>
                    _box(double.infinity, double.infinity, r: 14),
              ),
              const SizedBox(height: 20),
              _box(double.infinity, 280, r: 14),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════════════
Color _rateColor(double v) => v >= 70 ? kGreen : v >= 40 ? kAccent : kRed;

Color _typeColor(String type) => switch (type) {
      'public' => _kBlue,
      'prive' => kGreen,
      'mixte' => _kPurple,
      _ => kNavy,
    };

String _typeLabel(String type) => switch (type) {
      'public' => 'Public',
      'prive' => 'Privé',
      'mixte' => 'Mixte',
      _ => type,
    };

String _fmtD(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Format monétaire compact : 1 250 000 → "1,3 M", 45 000 → "45 k".
String _compactXaf(num v) {
  final a = v.abs();
  String s;
  if (a >= 1e9) {
    s = '${(v / 1e9).toStringAsFixed(a >= 1e10 ? 0 : 1)} Md';
  } else if (a >= 1e6) {
    s = '${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)} M';
  } else if (a >= 1e3) {
    s = '${(v / 1e3).toStringAsFixed(0)} k';
  } else {
    s = v.toStringAsFixed(0);
  }
  return s.replaceAll('.', ',');
}
