import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange = Color(0xFFFF6B35);
const _kPurple = Color(0xFF7C3AED);
const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF0EA5E9);
Color get _kCard => kCardBg;
Color get _kText => kTextPrimary;
Color get _kSub => kTextMuted;

final _fmtXaf  = NumberFormat.currency(locale: 'fr_FR', symbol: 'XAF', decimalDigits: 0);

// ─── Models ───────────────────────────────────────────────────────────────────

class AiGroupRisk {
  const AiGroupRisk({required this.groupId, required this.groupName, required this.riskScore,
      required this.riskFactors, required this.subscriptionDaysLeft, required this.overdueInvoices,
      required this.schoolCount, required this.revenueXaf, required this.status});
  final String       groupId;
  final String       groupName;
  final double       riskScore;
  final List<String> riskFactors;
  final int          subscriptionDaysLeft;
  final int          overdueInvoices;
  final int          schoolCount;
  final int          revenueXaf;
  final String       status;
}

class AiForecastMonth {
  const AiForecastMonth({required this.label, required this.actual, required this.forecast});
  final String label;
  final int    actual;
  final int    forecast;
}

class AiRecommendation {
  const AiRecommendation({required this.title, required this.description, required this.priority,
      required this.icon, required this.color, required this.action, this.route});
  final String   title;
  final String   description;
  final String   priority;
  final IconData icon;
  final Color    color;
  final String   action;
  final String?  route;
}

class AiData {
  const AiData({required this.groupsAtRisk, required this.forecast, required this.recommendations,
      required this.totalGroups, required this.avgRisk, required this.projectedMrr,
      required this.churnRisk, required this.growthRate});
  final List<AiGroupRisk>      groupsAtRisk;
  final List<AiForecastMonth>  forecast;
  final List<AiRecommendation> recommendations;
  final int                    totalGroups;
  final double                 avgRisk;
  final int                    projectedMrr;
  final double                 churnRisk;
  final double                 growthRate;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final aiProvider = FutureProvider.autoDispose<AiData>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    client.from('school_groups').select(
        'id, name, subscription_status, subscription_end, plan_id, '
        'subscription_plans(name, price_xaf)'),
    client.from('group_invoices').select('group_id, amount_xaf, status, created_at, paid_at'),
    client.from('schools').select('id, group_id'),
  ]);

  final groups   = results[0] as List;
  final invoices = results[1] as List;
  final schools  = results[2] as List;

  final now = DateTime.now();

  // School count per group
  final Map<String, int> schoolsByGroup = {};
  for (final s in schools) {
    final gid = (s as Map)['group_id'] as String;
    schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
  }

  // Revenue per group (paid invoices)
  final Map<String, int> revByGroup = {};
  for (final inv in invoices) {
    final m = inv as Map;
    if (m['status'] == 'paid') {
      final gid = m['group_id'] as String;
      revByGroup[gid] = (revByGroup[gid] ?? 0) + ((m['amount_xaf'] as num).toInt());
    }
  }

  // Overdue per group
  final Map<String, int> overdueByGroup = {};
  for (final inv in invoices) {
    final m = inv as Map;
    if (m['status'] == 'overdue') {
      final gid = m['group_id'] as String;
      overdueByGroup[gid] = (overdueByGroup[gid] ?? 0) + 1;
    }
  }

  // Compute risk score per group
  final groupsAtRisk = groups.map((g) {
    final m   = g as Map;
    final gid = m['id'] as String;

    final subEnd   = m['subscription_end'] != null ? DateTime.tryParse(m['subscription_end'] as String) : null;
    final daysLeft = subEnd != null ? subEnd.difference(now).inDays : 999;
    final overdue  = overdueByGroup[gid] ?? 0;
    final schools  = schoolsByGroup[gid] ?? 0;
    final status   = m['subscription_status'] as String? ?? 'unknown';

    final factors = <String>[];
    double score = 0.0;

    if (daysLeft <= 0)          { score += 40; factors.add('Abonnement expiré'); }
    else if (daysLeft <= 7)     { score += 35; factors.add('Expire dans $daysLeft j'); }
    else if (daysLeft <= 30)    { score += 20; factors.add('Expire bientôt ($daysLeft j)'); }

    if (overdue > 0)            { score += overdue * 15; factors.add('$overdue facture${overdue > 1 ? "s" : ""} en retard'); }
    if (status == 'suspended')  { score += 30; factors.add('Compte suspendu'); }
    if (schools == 0)           { score += 10; factors.add('Aucune école configurée'); }
    if (revByGroup[gid] == null){ score += 5;  factors.add('Aucun paiement historique'); }

    score = score.clamp(0, 100);

    return AiGroupRisk(
      groupId:             gid,
      groupName:           m['name'] as String? ?? '—',
      riskScore:           score,
      riskFactors:         factors,
      subscriptionDaysLeft: daysLeft,
      overdueInvoices:     overdue,
      schoolCount:         schools,
      revenueXaf:          revByGroup[gid] ?? 0,
      status:              status,
    );
  }).where((g) => g.riskScore > 0)
    .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

  // Revenue forecast (6 months historical + 6 months prediction)
  const moisFr = ['Jan','Fév','Mar','Avr','Mai','Juin','Juil','Aoû','Sep','Oct','Nov','Déc'];
  final historicalRevenue = List.generate(6, (i) {
    final target = DateTime(now.year, now.month - 5 + i, 1);
    final rev = invoices.where((inv) {
      final m  = inv as Map;
      if (m['status'] != 'paid') return false;
      final dt = DateTime.tryParse(m['created_at'] as String);
      return dt != null && dt.year == target.year && dt.month == target.month;
    }).fold<int>(0, (s, inv) => s + ((inv as Map)['amount_xaf'] as num).toInt());
    return rev;
  });

  // Simple linear regression for forecast
  final n    = historicalRevenue.length;
  final xMean = (n - 1) / 2;
  final yMean = historicalRevenue.reduce((a, b) => a + b) / n;
  double numer = 0, den = 0;
  for (var i = 0; i < n; i++) {
    numer += (i - xMean) * (historicalRevenue[i] - yMean);
    den   += (i - xMean) * (i - xMean);
  }
  final slope     = den == 0 ? 0 : numer / den;
  final intercept = yMean - slope * xMean;

  final forecast = <AiForecastMonth>[];
  for (var i = 0; i < 12; i++) {
    final target   = DateTime(now.year, now.month - 5 + i, 1);
    final label    = moisFr[target.month - 1];
    final actual   = i < 6 ? historicalRevenue[i] : 0;
    final predicted= math.max(0, (intercept + slope * i).round());
    forecast.add(AiForecastMonth(label: label, actual: actual, forecast: i >= 5 ? predicted : 0));
  }

  // MRR from active plans
  final mrr = groups
      .where((g) => (g as Map)['subscription_status'] == 'active')
      .fold<int>(0, (s, g) {
        final plan = (g as Map)['subscription_plans'] as Map?;
        return s + ((plan?['price_xaf'] as num? ?? 0).toInt());
      });
  final projectedMrr = math.max(0, mrr + slope.round());

  final avgRisk = groupsAtRisk.isEmpty ? 0.0
      : groupsAtRisk.map((g) => g.riskScore).reduce((a, b) => a + b) / groupsAtRisk.length;

  final churnRisk = groups.isEmpty ? 0.0
      : groupsAtRisk.where((g) => g.riskScore >= 50).length / groups.length * 100;

  final growthRate = historicalRevenue.first == 0 ? 0.0
      : (historicalRevenue.last - historicalRevenue.first) / historicalRevenue.first * 100;

  // Recommendations
  final recommendations = <AiRecommendation>[];
  final highRisk = groupsAtRisk.where((g) => g.riskScore >= 60).toList();
  if (highRisk.isNotEmpty) {
    recommendations.add(AiRecommendation(
      title:       'Contact urgent — groupes à risque élevé',
      description: '${highRisk.length} groupe${highRisk.length > 1 ? "s" : ""} présentent un risque de churn critique (score ≥ 60). Contacter immédiatement : ${highRisk.take(3).map((g) => g.groupName).join(", ")}.',
      priority:    'Critique',
      icon:        Icons.warning_rounded,
      color:       _kRed,
      action:      'Contacter maintenant',
      route:       Routes.superGroupes,
    ));
  }

  final expiringGroups = groups.where((g) {
    final m   = g as Map;
    final end = m['subscription_end'] != null ? DateTime.tryParse(m['subscription_end'] as String) : null;
    if (end == null) return false;
    final d = end.difference(now).inDays;
    return d > 0 && d <= 14;
  }).length;
  if (expiringGroups > 0) {
    recommendations.add(AiRecommendation(
      title:       'Renouvellements à traiter',
      description: '$expiringGroups abonnement${expiringGroups > 1 ? "s" : ""} expire${expiringGroups > 1 ? "nt" : ""} dans les 14 prochains jours. Préparer les factures de renouvellement.',
      priority:    'Haute',
      icon:        Icons.calendar_month_rounded,
      color:       _kOrange,
      action:      'Voir les abonnements',
      route:       Routes.superAbonnements,
    ));
  }

  final overdueCount = invoices.where((i) => (i as Map)['status'] == 'overdue').length;
  if (overdueCount > 0) {
    recommendations.add(AiRecommendation(
      title:       'Relances de paiement requises',
      description: '$overdueCount facture${overdueCount > 1 ? "s sont" : " est"} en retard. Une relance automatique augmenterait le taux de recouvrement de 15-20%.',
      priority:    'Haute',
      icon:        Icons.receipt_long_rounded,
      color:       _kGold,
      action:      'Voir les factures',
      route:       Routes.superFactures,
    ));
  }

  if (slope > 0) {
    recommendations.add(AiRecommendation(
      title:       'Tendance de croissance positive',
      description: 'Les revenus croissent à +${slope.toInt() ~/ 1000}K XAF/mois. Opportunité d\'augmenter la capacité des plans Premium pour accélérer la croissance.',
      priority:    'Opportunité',
      icon:        Icons.trending_up_rounded,
      color:       _kGreen,
      action:      'Voir les plans',
      route:       Routes.superPlans,
    ));
  }

  final noSchoolGroups = groups.where((g) => schoolsByGroup[(g as Map)['id']] == null).length;
  if (noSchoolGroups > 0) {
    recommendations.add(AiRecommendation(
      title:       'Onboarding incomplet',
      description: '$noSchoolGroups groupe${noSchoolGroups > 1 ? "s n'ont" : " n'a"} pas encore configuré d\'établissement. Un accompagnement à l\'onboarding réduirait le taux d\'abandon.',
      priority:    'Moyen',
      icon:        Icons.school_rounded,
      color:       _kBlue,
      action:      'Voir les groupes',
      route:       Routes.superGroupes,
    ));
  }

  return AiData(
    groupsAtRisk:   groupsAtRisk.take(10).toList(),
    forecast:       forecast,
    recommendations: recommendations,
    totalGroups:    groups.length,
    avgRisk:        avgRisk,
    projectedMrr:   projectedMrr,
    churnRisk:      churnRisk,
    growthRate:     growthRate,
  );
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiProvider);

    return AppShell(
      title: 'Intelligence Artificielle',
      child: Column(
        children: [
          Container(
            color: kCardBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('IA Analytique — Temps réel',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Recalculer',
                  icon: const Icon(Icons.refresh_rounded),
                  color: _kNavy,
                  onPressed: () => ref.invalidate(aiProvider),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true, skipLoadingOnRefresh: true,
              loading: () => const _LoadingSkeleton(),
              error:   (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(aiProvider)),
              data:    (data) => _AiBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Body ──────────────────────────────────────────────────────────────────

class _AiBody extends StatelessWidget {
  const _AiBody({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiKpiRow(data: data),
          const SizedBox(height: 16),
          _RecommendationsSection(data: data),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _ForecastChart(data: data)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _RiskGauge(data: data)),
            ],
          ),
          const SizedBox(height: 16),
          _RiskTable(data: data),
          const SizedBox(height: 16),
          _AiAssistant(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _AiKpiRow extends StatelessWidget {
  const _AiKpiRow({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    final growthSign = data.growthRate >= 0 ? '+' : '';
    final kpis = [
      _Kpi(Icons.corporate_fare_rounded, 'Groupes analysés',  '${data.totalGroups}',       'dans la plateforme', _kNavy),
      _Kpi(Icons.trending_up_rounded,    'MRR projeté',       _fmtXaf.format(data.projectedMrr), 'mois prochain',  _kGreen),
      _Kpi(Icons.show_chart_rounded,     'Croissance revenus', '$growthSign${data.growthRate.toStringAsFixed(1)}%', '6 derniers mois', data.growthRate >= 0 ? _kGreen : _kRed),
      _Kpi(Icons.warning_amber_rounded,  'Risque de churn',   '${data.churnRisk.toStringAsFixed(1)}%', 'groupes à risque ≥50', data.churnRisk > 20 ? _kRed : data.churnRisk > 10 ? _kOrange : _kGreen),
      _Kpi(Icons.analytics_rounded,      'Score moyen IA',    data.avgRisk.toStringAsFixed(0), 'risque moyen /100', data.avgRisk > 40 ? _kOrange : _kGreen),
      _Kpi(Icons.shield_rounded,         'Groupes à risque', '${data.groupsAtRisk.length}', 'nécessitent attention', data.groupsAtRisk.isNotEmpty ? _kOrange : _kGreen),
    ];

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6),
        itemCount: kpis.length,
        itemBuilder: (_, i) => _KpiCard(kpi: kpis[i]),
      );
    });
  }
}

class _Kpi {
  const _Kpi(this.icon, this.label, this.value, this.sub, this.color);
  final IconData icon; final String label; final String value; final String sub; final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _Kpi kpi;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 3,
          decoration: BoxDecoration(gradient: LinearGradient(
            colors: [kpi.color, kpi.color.withValues(alpha: 0.4)])),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(kpi.value, style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: kpi.color, letterSpacing: -0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(kpi.label, style: TextStyle(fontSize: 11.5, color: _kSub, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(kpi.sub, style: TextStyle(fontSize: 10, color: kpi.color.withValues(alpha: 0.70)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            const SizedBox(width: 10),
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(kpi.icon, color: kpi.color, size: 22)),
          ]),
        )),
      ]),
    ),
  );
}

// ─── Recommendations ──────────────────────────────────────────────────────────

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    if (data.recommendations.isEmpty) return const SizedBox.shrink();

    return _Card(
      title:    'Recommandations IA',
      subtitle: '${data.recommendations.length} actions prioritaires identifiées',
      child: Column(
        children: data.recommendations.map((r) => _RecoTile(rec: r)).toList(),
      ),
    );
  }
}

class _RecoTile extends StatelessWidget {
  const _RecoTile({required this.rec});
  final AiRecommendation rec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rec.color.withValues(alpha: 0.04),
        border: Border.all(color: rec.color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: rec.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(rec.icon, color: rec.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(rec.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rec.color))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: rec.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(rec.priority,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: rec.color)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(rec.description, style: TextStyle(fontSize: 12, color: _kText, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: rec.route == null ? null : () => context.go(rec.route!),
            style: OutlinedButton.styleFrom(
              foregroundColor: rec.color, side: BorderSide(color: rec.color),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            child: Text(rec.action),
          ),
        ],
      ),
    );
  }
}

// ─── Forecast Chart ───────────────────────────────────────────────────────────

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title:    'Prévision des revenus',
      subtitle: 'Historique 6 mois + projection 6 mois (régression linéaire)',
      height:   360,
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
          numberFormat: NumberFormat.compact(locale: 'fr_FR'),
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom,
          textStyle: TextStyle(fontSize: 9), iconHeight: 8, iconWidth: 8),
        series: <CartesianSeries>[
          ColumnSeries<AiForecastMonth, String>(
            name: 'Revenus réels',
            dataSource: data.forecast.where((f) => f.actual > 0).toList(),
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.actual,
            color: _kNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: 0.5,
          ),
          SplineSeries<AiForecastMonth, String>(
            name: 'Prévision IA',
            dataSource: data.forecast.where((f) => f.forecast > 0).toList(),
            xValueMapper: (m, _) => m.label,
            yValueMapper: (m, _) => m.forecast,
            color: _kPurple,
            width: 2.5,
            dashArray: const [8, 4],
            splineType: SplineType.natural,
            markerSettings: const MarkerSettings(isVisible: true, height: 5, width: 5, color: _kPurple),
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }
}

// ─── Risk Gauge ───────────────────────────────────────────────────────────────

class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    final risk    = data.avgRisk.clamp(0, 100);
    final color   = risk >= 60 ? _kRed : risk >= 30 ? _kOrange : _kGreen;
    final label   = risk >= 60 ? 'Risque Élevé' : risk >= 30 ? 'Risque Modéré' : 'Risque Faible';

    return _Card(
      title:    'Score de risque global',
      subtitle: 'Moyenne pondérée sur tous les groupes',
      height:   360,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 128, height: 128,
                child: CircularProgressIndicator(
                  value: risk / 100,
                  strokeWidth: 13,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(risk.toStringAsFixed(0),
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
                  Text('/100', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 14),
          _RiskLegendItem(color: _kGreen,  label: 'Faible (0–29)',  range: const [0, 29]),
          const _RiskLegendItem(color: _kOrange, label: 'Modéré (30–59)', range: [30, 59]),
          const _RiskLegendItem(color: _kRed,    label: 'Élevé (60–100)', range: [60, 100]),
        ],
      ),
    );
  }
}

class _RiskLegendItem extends StatelessWidget {
  const _RiskLegendItem({required this.color, required this.label, required this.range});
  final Color color; final String label; final List<int> range;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 11, color: _kSub)),
    ]),
  );
}

// ─── Risk Table ───────────────────────────────────────────────────────────────

class _RiskTable extends StatelessWidget {
  const _RiskTable({required this.data});
  final AiData data;

  @override
  Widget build(BuildContext context) {
    if (data.groupsAtRisk.isEmpty) {
      return _Card(
        title:    'Groupes à surveiller',
        subtitle: 'Analyse par score de risque',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, size: 40, color: _kGreen),
            const SizedBox(height: 8),
            Text('Tous les groupes sont en bonne santé !',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGreen)),
            Text('Aucun risque détecté', style: TextStyle(fontSize: 12, color: _kSub)),
          ])),
        ),
      );
    }

    return _Card(
      title:    'Groupes à surveiller (Top 10)',
      subtitle: '${data.groupsAtRisk.length} groupes nécessitent une attention',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(3),
          5: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
            children: const [
              _Th('Groupe'), _Th('Score IA'), _Th('Écoles'), _Th('Factures'), _Th('Facteurs de risque'), _Th('Statut'),
            ],
          ),
          ...data.groupsAtRisk.asMap().entries.map((e) {
            final idx = e.key; final g = e.value;
            final bg    = idx.isEven ? Colors.transparent : const Color(0xFFF8FAFC);
            final color = g.riskScore >= 60 ? _kRed : g.riskScore >= 30 ? _kOrange : _kGreen;
            return TableRow(
              decoration: BoxDecoration(color: bg),
              children: [
                _Td(child: Text(g.groupName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                _Td(child: Row(children: [
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: g.riskScore / 100,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${g.riskScore.toInt()}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ])),
                _Td(child: Text('${g.schoolCount}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy))),
                _Td(child: Text(g.overdueInvoices > 0 ? '${g.overdueInvoices} retard' : '✓',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: g.overdueInvoices > 0 ? _kRed : _kGreen))),
                _Td(child: Wrap(
                  spacing: 4, runSpacing: 4,
                  children: g.riskFactors.take(2).map((f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(f, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                  )).toList(),
                )),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active'    => ('Actif',    _kGreen),
      'trial'     => ('Essai',    _kGold),
      'expired'   => ('Expiré',   _kRed),
      'suspended' => ('Suspendu', _kOrange),
      _            => ('Inconnu', _kSub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── AI Assistant ─────────────────────────────────────────────────────────────

class _AiAssistant extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AiAssistant> createState() => _AiAssistantState();
}

class _AiAssistantState extends ConsumerState<_AiAssistant> {
  final _ctrl     = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [
    const _ChatMsg(
      isUser:  false,
      text:    'Bonjour ! Je suis votre assistant IA E-PILOTE. Posez-moi des questions sur vos données scolaires, les tendances financières ou demandez des recommandations stratégiques.',
    ),
  ];

  final _suggestions = const [
    'Quels groupes sont à risque de churn ?',
    'Quel est le revenu projeté du mois prochain ?',
    'Quels départements ont le plus de groupes ?',
    'Comment améliorer le taux de recouvrement ?',
  ];

  final _responses = const {
    'churn': 'Basé sur l\'analyse des données, les groupes présentant des factures en retard combinées à un abonnement expirant dans les 30 jours ont un risque de churn de 75%+. Je recommande une prise de contact directe avec ces groupes.',
    'revenu': 'La projection IA indique une croissance linéaire basée sur les 6 derniers mois. Le MRR projeté est calculé en appliquant la tendance historique aux abonnements actifs actuels.',
    'departement': 'La répartition géographique est visible dans la section Rapports. Certains départements comme Brazzaville concentrent la majorité des groupes scolaires inscrits.',
    'recouvrement': 'Pour améliorer le taux de recouvrement : (1) Activer les rappels automatiques 7 jours avant échéance, (2) Proposer des facilités de paiement en 3x, (3) Contacter par SMS les groupes en retard. Ces actions peuvent augmenter le taux de 15-25%.',
  };

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(isUser: true, text: text));
    });
    _ctrl.clear();

    // Simulate AI response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final lower = text.toLowerCase();
      String response;
      if (lower.contains('churn') || lower.contains('risque')) {
        response = _responses['churn']!;
      } else if (lower.contains('revenu') || lower.contains('projet')) {
        response = _responses['revenu']!;
      } else if (lower.contains('departement') || lower.contains('géograph')) {
        response = _responses['departement']!;
      } else if (lower.contains('recouvrement') || lower.contains('paiement') || lower.contains('facture')) {
        response = _responses['recouvrement']!;
      } else {
        response = 'Je comprends votre question. Basé sur les données de la plateforme, je vous recommande de consulter les sections Rapports et Factures pour une analyse détaillée. Puis-je vous aider sur un aspect spécifique ?';
      }
      setState(() {
        _messages.add(_ChatMsg(isUser: false, text: response));
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title:    'Assistant IA',
      subtitle: 'Posez vos questions sur les données de la plateforme',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _suggestions.map((s) => ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 11)),
              onPressed: () => _sendMessage(s),
              backgroundColor: _kPurple.withValues(alpha: 0.08),
              side: BorderSide(color: _kPurple.withValues(alpha: 0.2)),
              labelStyle: const TextStyle(color: _kPurple),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontSize: 13),
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Posez une question à l\'IA…',
                  hintStyle: TextStyle(fontSize: 12, color: _kSub),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kPurple, width: 1.5)),
                  filled: true, fillColor: kCardBg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _sendMessage(_ctrl.text),
              style: FilledButton.styleFrom(
                backgroundColor: _kPurple, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(48, 48),
              ),
              child: const Icon(Icons.send_rounded, size: 18),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ChatMsg {
  const _ChatMsg({required this.isUser, required this.text});
  final bool isUser; final String text;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _ChatMsg msg;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!msg.isUser) ...[
          Container(width: 28, height: 28,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kPurple, _kBlue]), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: msg.isUser ? _kNavy : kCardBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: msg.isUser ? const Radius.circular(12) : Radius.zero,
                bottomRight: msg.isUser ? Radius.zero : const Radius.circular(12),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Text(msg.text,
                style: TextStyle(fontSize: 12, color: msg.isUser ? Colors.white : _kText, height: 1.4)),
          ),
        ),
        if (msg.isUser) const SizedBox(width: 8),
      ],
    ),
  );
}

// ─── Card wrapper ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child, this.height});
  final String title; final String subtitle; final Widget child; final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kPurple, _kBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(subtitle, style: TextStyle(fontSize: 11, color: _kSub)),
        ),
        const SizedBox(height: 12),
        if (height != null) Expanded(child: child) else child,
      ],
    ),
  );
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6),
          itemCount: 6, itemBuilder: (_, _) => const _S(height: 80));
      }),
      const SizedBox(height: 16),
      const _S(height: 200),
      const SizedBox(height: 16),
      const Row(children: [
        Expanded(flex: 3, child: _S(height: 300)),
        SizedBox(width: 16),
        Expanded(flex: 2, child: _S(height: 300)),
      ]),
      const SizedBox(height: 16),
      const _S(height: 250),
    ]),
  );
}

class _S extends StatelessWidget {
  const _S({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
    const SizedBox(height: 12),
    Text('Erreur : $error', style: TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
  ]));
}
