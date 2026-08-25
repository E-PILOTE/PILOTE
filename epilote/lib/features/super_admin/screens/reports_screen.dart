import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../providers/reports_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange = Color(0xFFFF6B35);
const _kPurple = Color(0xFF7C3AED);
Color get _kCard => kCardBg;
Color get _kText => kTextPrimary;
Color get _kSub => kTextMuted;

final _fmtXaf = NumberFormat.currency(locale: 'fr_FR', symbol: 'XAF', decimalDigits: 0);
final _fmtNum = NumberFormat.decimalPattern('fr_FR');

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportsPeriodProvider);
    final async  = ref.watch(reportsProvider);

    return AppShell(
      title: 'Rapports & Statistiques',
      child: Column(
        children: [
          _ActionBar(
            period: period,
            onPeriodChanged: (v) => ref.read(reportsPeriodProvider.notifier).state = v,
            onExport: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export PDF en cours de génération…')),
            ),
            onRefresh: () => ref.invalidate(reportsProvider),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnReload:  true,
              skipLoadingOnRefresh: true,
              loading: () => const _LoadingSkeleton(),
              error:   (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(reportsProvider)),
              data:    (data) => _ReportsBody(data: data, period: period),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.period, required this.onPeriodChanged,
      required this.onExport, required this.onRefresh});
  final int period;
  final ValueChanged<int> onPeriodChanged;
  final VoidCallback onExport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCardBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _PeriodSelector(period: period, onChanged: onPeriodChanged),
          const Spacer(),
          FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Exporter PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: _kGreen, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            color: _kNavy,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ─── Period selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final int period;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in [3, 6, 12])
            _PeriodBtn(label: '${v}M', value: v, selected: period == v, onTap: () => onChanged(v)),
        ],
      ),
    );
  }
}

class _PeriodBtn extends StatelessWidget {
  const _PeriodBtn({required this.label, required this.value, required this.selected, required this.onTap});
  final String label; final int value; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _kNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _kSub,
        )),
    ),
  );
}

// ─── Main body ────────────────────────────────────────────────────────────────

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.data, required this.period});
  final ReportsData data;
  final int period;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KpiGrid(data: data),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _RevenueChart(data: data, period: period)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _PlanDonut(data: data)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _InvoiceStatusChart(data: data)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _GroupTypeSection(data: data)),
            ],
          ),
          const SizedBox(height: 16),
          _TopGroupsTable(data: data),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _StaffContractChart(data: data)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _DeptBreakdown(data: data)),
            ],
          ),
          const SizedBox(height: 16),
          _FinancialSummaryTable(data: data),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── KPI Grid (8 cards) ───────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final rate = (data.paymentRate * 100).toStringAsFixed(1);
    final cards = [
      _KpiDef(
        icon: Icons.corporate_fare_rounded, label: 'Groupes Scolaires',
        value: _fmtNum.format(data.totalGroupes),
        sub: '${data.totalPublic} publics · ${data.totalPrivate} privés',
        color: _kNavy,
      ),
      _KpiDef(
        icon: Icons.school_rounded, label: 'Établissements',
        value: _fmtNum.format(data.totalEcoles),
        sub: data.totalGroupes > 0
            ? '${(data.totalEcoles / data.totalGroupes).toStringAsFixed(1)} moy/groupe'
            : '0 moy/groupe',
        color: _kGreen,
      ),
      _KpiDef(
        icon: Icons.people_alt_rounded, label: 'Élèves Inscrits',
        value: _fmtNum.format(data.totalEleves),
        sub: 'Toutes écoles confondues',
        color: _kGold,
      ),
      _KpiDef(
        icon: Icons.badge_rounded, label: 'Personnel',
        value: _fmtNum.format(data.totalPersonnel),
        sub: 'Enseignants + administration',
        color: _kOrange,
      ),
      _KpiDef(
        icon: Icons.account_balance_wallet_rounded, label: 'Revenus encaissés',
        value: _fmtXaf.format(data.totalRevenusXaf),
        sub: 'Toutes périodes',
        color: _kGreen,
      ),
      _KpiDef(
        icon: Icons.trending_up_rounded, label: 'MRR',
        value: _fmtXaf.format(data.mrr),
        sub: 'ARR: ${_fmtXaf.format(data.arr)}',
        color: _kNavy,
      ),
      _KpiDef(
        icon: Icons.receipt_long_rounded, label: 'Taux de paiement',
        value: '$rate%',
        sub: '${data.totalFacturesPending} en attente · ${data.totalFacturesOverdue} en retard',
        color: double.parse(rate) >= 80 ? _kGreen : _kOrange,
      ),
      _KpiDef(
        icon: Icons.warning_amber_rounded, label: 'Factures en retard',
        value: _fmtNum.format(data.totalFacturesOverdue),
        sub: '${data.totalFacturesCancelled} annulées',
        color: data.totalFacturesOverdue > 0 ? const Color(0xFFEF4444) : _kGreen,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          crossAxisSpacing: 12,
          mainAxisSpacing:  12,
          childAspectRatio: 2.6,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _KpiCard(def: cards[i]),
      );
    });
  }
}

class _KpiDef {
  const _KpiDef({required this.icon, required this.label, required this.value, required this.sub, required this.color});
  final IconData icon; final String label; final String value; final String sub; final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.def});
  final _KpiDef def;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: def.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(def.icon, color: def.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.label, style: TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(def.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kText),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(def.sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Revenue Chart ────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.data, required this.period});
  final ReportsData data;
  final int period;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Évolution des revenus',
      subtitle: 'Derniers $period mois',
      height: 270,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          labelStyle: TextStyle(fontSize: 10, color: _kSub),
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: TextStyle(fontSize: 10, color: _kSub),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          numberFormat: NumberFormat.compact(locale: 'fr_FR'),
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom,
          textStyle: TextStyle(fontSize: 10), iconHeight: 8, iconWidth: 8),
        series: <CartesianSeries>[
          SplineAreaSeries<ReportMonthly, String>(
            name: 'Encaissé (XAF)',
            dataSource: data.monthly,
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.revenueXaf,
            color: _kGreen.withValues(alpha: 0.25),
            borderColor: _kGreen,
            borderWidth: 2.5,
            splineType: SplineType.natural,
            markerSettings: MarkerSettings(
              isVisible: true, height: 6, width: 6,
              color: _kGreen, borderColor: Colors.white, borderWidth: 2,
            ),
          ),
          ColumnSeries<ReportMonthly, String>(
            name: 'Nb factures',
            dataSource: data.monthly,
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.invoiceCount,
            color: _kNavy.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            width: 0.3,
            yAxisName: 'y2',
          ),
        ],
        axes: [
          NumericAxis(
            name: 'y2',
            opposedPosition: true,
            labelStyle: TextStyle(fontSize: 9, color: _kNavy),
            axisLine: const AxisLine(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }
}

// ─── Plan Donut ───────────────────────────────────────────────────────────────

class _PlanDonut extends StatelessWidget {
  const _PlanDonut({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    if (data.groupsByPlan.isEmpty) {
      return _ChartCard(
        title: 'Répartition par plan',
        subtitle: 'Aucune donnée',
        height: 270,
        child: Center(child: Text('Aucun groupe', style: TextStyle(color: _kSub))),
      );
    }
    return _ChartCard(
      title: 'Répartition par plan',
      subtitle: '${data.groupsByPlan.length} plans · ${data.totalGroupes} groupes',
      height: 270,
      child: SfCircularChart(
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          textStyle: TextStyle(fontSize: 10),
          iconHeight: 8,
          iconWidth: 8,
        ),
        series: [
          DoughnutSeries<ReportsByPlan, String>(
            dataSource:       data.groupsByPlan,
            xValueMapper:     (p, _) => p.planName,
            yValueMapper:     (p, _) => p.groupCount,
            pointColorMapper: (p, _) => Color(p.color),
            innerRadius:      '60%',
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
              textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }
}

// ─── Invoice status bar chart ─────────────────────────────────────────────────

class _InvoiceStatusChart extends StatelessWidget {
  const _InvoiceStatusChart({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Factures par mois',
      subtitle: 'Payées vs en attente',
      height: 250,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          labelStyle: TextStyle(fontSize: 9, color: _kSub),
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: TextStyle(fontSize: 9, color: _kSub),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom,
          textStyle: TextStyle(fontSize: 9), iconHeight: 7, iconWidth: 7),
        series: <CartesianSeries>[
          ColumnSeries<ReportMonthly, String>(
            name: 'Payées',
            dataSource: data.monthly,
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.paidCount,
            color: _kGreen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            spacing: 0.15,
          ),
          ColumnSeries<ReportMonthly, String>(
            name: 'En attente',
            dataSource: data.monthly,
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.pendingCount,
            color: _kGold,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            spacing: 0.15,
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }
}

// ─── Group type public/privé ──────────────────────────────────────────────────

class _GroupTypeSection extends StatelessWidget {
  const _GroupTypeSection({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final total   = data.totalPublic + data.totalPrivate;
    final pctPub  = total > 0 ? data.totalPublic  / total : 0.0;
    final pctPriv = total > 0 ? data.totalPrivate / total : 0.0;

    return _ChartCard(
      title: 'Public vs Privé',
      subtitle: 'Répartition des ${data.totalGroupes} groupes',
      height: 250,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigStat(label: 'Public',  value: data.totalPublic,  color: _kNavy),
              Container(width: 1, height: 60, color: Colors.grey.shade200),
              _BigStat(label: 'Privé',   value: data.totalPrivate, color: _kPurple),
              Container(width: 1, height: 60, color: Colors.grey.shade200),
              _BigStat(label: 'Total',   value: total,             color: _kSub),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  if (pctPub > 0)
                    Flexible(
                      flex: (pctPub * 100).round(),
                      child: Container(
                        height: 24, color: _kNavy,
                        child: Center(child: Text('${(pctPub * 100).round()}%',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  if (pctPriv > 0)
                    Flexible(
                      flex: (pctPriv * 100).round(),
                      child: Container(
                        height: 24, color: _kPurple,
                        child: Center(child: Text('${(pctPriv * 100).round()}%',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _kNavy,   label: 'Établissements publics'),
              const SizedBox(width: 24),
              const _LegendDot(color: _kPurple, label: 'Établissements privés'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value, required this.color});
  final String label; final int value; final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(_fmtNum.format(value),
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w500)),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color; final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: _kSub)),
    ],
  );
}

// ─── Top 5 Groups ─────────────────────────────────────────────────────────────

class _TopGroupsTable extends StatelessWidget {
  const _TopGroupsTable({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Top 5 Groupes Scolaires',
      subtitle: 'Classés par nombre d\'établissements',
      child: data.topGroups.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Aucune donnée', style: TextStyle(color: _kSub))),
            )
          : Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(2.5),
                5: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  children: const [
                    _Th('Groupe'), _Th('Département'), _Th('Écoles'),
                    _Th('Type'), _Th('Revenus'), _Th('Statut'),
                  ],
                ),
                ...data.topGroups.asMap().entries.map((e) {
                  final idx = e.key; final g = e.value;
                  final bg  = idx.isEven ? Colors.transparent : const Color(0xFFF8FAFC);
                  return TableRow(
                    decoration: BoxDecoration(color: bg),
                    children: [
                      _Td(child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: _kNavy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text('${idx + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(g.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ])),
                      _Td(child: Text(g.department,
                          style: TextStyle(fontSize: 11, color: _kSub))),
                      _Td(child: Text('${g.schoolCount}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy))),
                      _Td(child: _TypeBadge(type: g.groupType)),
                      _Td(child: Text(_fmtXaf.format(g.revenueXaf),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen))),
                      _Td(child: _StatusChip(status: g.status)),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub)),
  );
}

class _Td extends StatelessWidget {
  const _Td({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: child,
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;
  @override
  Widget build(BuildContext context) {
    final isPublic = type == 'public';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isPublic ? _kNavy : _kPurple).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(isPublic ? 'Public' : 'Privé',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: isPublic ? _kNavy : _kPurple)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active'    => ('Actif',    _kGreen),
      'trial'     => ('Essai',    _kGold),
      'expired'   => ('Expiré',   const Color(0xFFEF4444)),
      'suspended' => ('Suspendu', _kOrange),
      _            => ('Inconnu', _kSub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Staff Contract Chart ─────────────────────────────────────────────────────

class _StaffContractChart extends StatelessWidget {
  const _StaffContractChart({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final labels = <String, (String, Color)>{
      'permanent':   ('Permanent',   _kNavy),
      'contractuel': ('Contractuel', _kGreen),
      'vacataire':   ('Vacataire',   _kGold),
      'stagiaire':   ('Stagiaire',   _kOrange),
    };
    final total = data.staffByContract.values.fold(0, (a, b) => a + b);

    return _ChartCard(
      title: 'Personnel par type de contrat',
      subtitle: '${_fmtNum.format(total)} personnes au total',
      child: Column(
        children: labels.entries.map((e) {
          final count = data.staffByContract[e.key] ?? 0;
          final pct   = total > 0 ? count / total : 0.0;
          final color = e.value.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value.$1,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kText)),
                    Text('$count  (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 9,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Dept Breakdown ───────────────────────────────────────────────────────────

class _DeptBreakdown extends StatelessWidget {
  const _DeptBreakdown({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final sorted = data.groupsByDept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total  = data.totalGroupes;
    final colors = [_kNavy, _kGreen, _kGold, _kOrange, _kPurple, const Color(0xFF0EA5E9)];

    return _ChartCard(
      title: 'Répartition géographique',
      subtitle: '${sorted.length} départements couverts',
      child: Column(
        children: sorted.asMap().entries.map((e) {
          final color = colors[e.key % colors.length];
          final pct   = total > 0 ? e.value.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.value.key,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _kText),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value.value} groupe${e.value.value > 1 ? "s" : ""}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Financial Summary Table ──────────────────────────────────────────────────

class _FinancialSummaryTable extends StatelessWidget {
  const _FinancialSummaryTable({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final colors = [_kGreen, _kGold, const Color(0xFFEF4444), _kSub];
    return _ChartCard(
      title: 'Récapitulatif financier',
      subtitle: 'Toutes périodes confondues',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            children: const [
              _Th('Catégorie'), _Th('Nb factures'), _Th('Montant'), _Th('% du total'),
            ],
          ),
          ...data.financialSummary.asMap().entries.map((e) {
            final row   = e.value;
            final bg    = e.key.isEven ? Colors.transparent : const Color(0xFFF8FAFC);
            final color = colors[e.key % colors.length];
            return TableRow(
              decoration: BoxDecoration(color: bg),
              children: [
                _Td(child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(row.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ])),
                _Td(child: Text('${row.count}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText))),
                _Td(child: Text(_fmtXaf.format(row.amount),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
                _Td(child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: row.pct / 100,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${row.pct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ])),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Chart Card wrapper ───────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.height,
  });
  final String  title;
  final String  subtitle;
  final Widget  child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: _kSub)),
          const SizedBox(height: 12),
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 2.6,
            ),
            itemCount: 8,
            itemBuilder: (_, _) => const _Shimmer(height: 80, radius: 12),
          ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(flex: 3, child: _Shimmer(height: 270, radius: 14)),
            SizedBox(width: 16),
            Expanded(flex: 2, child: _Shimmer(height: 270, radius: 14)),
          ]),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(flex: 2, child: _Shimmer(height: 250, radius: 14)),
            SizedBox(width: 16),
            Expanded(flex: 3, child: _Shimmer(height: 250, radius: 14)),
          ]),
          const SizedBox(height: 16),
          const _Shimmer(height: 200, radius: 14),
          const SizedBox(height: 16),
          const _Shimmer(height: 200, radius: 14),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.height, this.radius = 8});
  final double height; final double radius;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
        const SizedBox(height: 12),
        Text('Erreur de chargement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 4),
        Text(error, style: TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );
}
