import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/tarif_ecoles.dart' show mensualiteGroupe;

import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/paged_fetch.dart';
import '../../../core/utils/plan_referential_realtime.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class ReportMonthly {
  const ReportMonthly({
    required this.label,
    required this.revenueXaf,
    required this.invoiceCount,
    required this.paidCount,
    required this.pendingCount,
  });
  final String label;
  final int    revenueXaf;
  final int    invoiceCount;
  final int    paidCount;
  final int    pendingCount;
}

class ReportsByPlan {
  const ReportsByPlan({
    required this.planName,
    required this.groupCount,
    required this.revenueXaf,
    required this.color,
  });
  final String planName;
  final int    groupCount;
  final int    revenueXaf;
  final int    color; // ARGB hex
}

class TopGroupEntry {
  const TopGroupEntry({
    required this.name,
    required this.schoolCount,
    required this.planName,
    required this.status,
    required this.department,
    required this.revenueXaf,
    required this.groupType,
  });
  final String name;
  final int    schoolCount;
  final String planName;
  final String status;
  final String department;
  final int    revenueXaf;
  final String groupType;
}

class FinancialSummaryRow {
  const FinancialSummaryRow({
    required this.label,
    required this.amount,
    required this.count,
    required this.pct,
  });
  final String label;
  final int    amount;
  final int    count;
  final double pct;
}

class ReportsData {
  const ReportsData({
    required this.totalGroupes,
    required this.totalEcoles,
    required this.totalEleves,
    required this.totalPersonnel,
    required this.totalRevenusXaf,
    required this.totalFacturesPending,
    required this.mrr,
    required this.arr,
    required this.paymentRate,
    required this.totalPublic,
    required this.totalPrivate,
    required this.groupsByPlan,
    required this.monthly,
    required this.topGroups,
    required this.groupsByDept,
    required this.staffByContract,
    required this.financialSummary,
    required this.totalFacturesOverdue,
    required this.totalFacturesCancelled,
  });

  final int                     totalGroupes;
  final int                     totalEcoles;
  final int                     totalEleves;
  final int                     totalPersonnel;
  final int                     totalRevenusXaf;
  final int                     totalFacturesPending;
  final int                     mrr;
  final int                     arr;
  final double                  paymentRate;
  final int                     totalPublic;
  final int                     totalPrivate;
  final List<ReportsByPlan>     groupsByPlan;
  final List<ReportMonthly>     monthly;
  final List<TopGroupEntry>     topGroups;
  final Map<String, int>        groupsByDept;
  final Map<String, int>        staffByContract;
  final List<FinancialSummaryRow> financialSummary;
  final int                     totalFacturesOverdue;
  final int                     totalFacturesCancelled;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final reportsPeriodProvider = StateProvider.autoDispose<int>((ref) => 6);

final reportsProvider = FutureProvider.autoDispose<ReportsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final months = ref.watch(reportsPeriodProvider);

  // Le chiffre d'affaires de ce rapport est calculé sur le TARIF COURANT des
  // plans. `keepAlive` sans écoute figeait le rapport sur les prix connus au
  // premier affichage — un rapport faux est pire qu'un rapport absent.
  Timer? debounce;
  try {
    final channel = client
        .channel('platform_reports_referential')
        .watchPlanReferential(() {
          debounce?.cancel();
          debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
        })
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {/* hors-ligne / token expiré → on continue */}

  // ⚠️ Élèves et personnel se COMPTENT : les ramener plafonnait le rapport
  // national à 1 000 lignes (cf. `paged_fetch.dart`). Le personnel vit dans
  // `profiles`, pas dans `staff_members` — table vide que rien n'écrit.
  final results = await Future.wait([
    client.from('school_groups').select(
        'id, name, department, subscription_status, plan_id, group_type, '
        'price_override_xaf, billed_schools, subscription_plans!plan_id(name, price_xaf, billing_period, extra_school_2_5_xaf, extra_school_6_10_xaf, extra_school_11_20_xaf, extra_school_21p_xaf)'),
    client.from('schools').select('id, group_id'),
    client.from('group_invoices').select(
        'id, amount_xaf, status, created_at, group_id'),
  ]);

  final groups   = results[0] as List;
  final schools  = results[1] as List;
  final invoices = results[2] as List;

  final int totalElevesCount =
      await client.from('students').count(CountOption.exact);
  final staff = await fetchAllRows(() => client
      .from('profiles')
      .select('id, employment_status')
      .not('role', 'in', '(super_admin,admin_groupe,parent,eleve)'));

  // ── KPIs ──────────────────────────────────────────────────────────────────
  final paidInvoices     = invoices.where((i) => (i as Map)['status'] == 'paid').toList();
  final pendingInvoices  = invoices.where((i) => ['pending','overdue'].contains((i as Map)['status'])).toList();
  final overdueInvoices  = invoices.where((i) => (i as Map)['status'] == 'overdue').toList();
  final cancelledInvoices= invoices.where((i) => (i as Map)['status'] == 'cancelled').toList();

  final totalRevenusXaf = paidInvoices
      .fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());

  final paymentRate = invoices.isEmpty ? 0.0
      : paidInvoices.length / invoices.length;

  // MRR = somme des tarifs RAMENÉS AU MOIS des groupes actifs. Additionner
  // des prix bruts mêlerait des annuels et des mensuels dans un même total.
  final mrr = groups
      .where((g) => (g as Map)['subscription_status'] == 'active')
      .fold<int>(0, (s, g) {
        return s + mensualiteGroupe(g as Map);
      });

  // Public / Privé
  int totalPublic  = 0;
  int totalPrivate = 0;
  for (final g in groups) {
    final t = (g as Map)['group_type'] as String? ?? '';
    if (t == 'public') {
      totalPublic++;
    } else {
      totalPrivate++;
    }
  }

  // ── Groups by plan ─────────────────────────────────────────────────────────
  const planColors = [0xFF1E3A5F, 0xFF009A44, 0xFFFBBC04, 0xFFFF6B35, 0xFF7C3AED];
  final Map<String, _PlanAgg> planAgg = {};
  for (final g in groups) {
    final m       = g as Map;
    final planMap = m['subscription_plans'] as Map?;
    final name    = planMap?['name'] as String? ?? 'Sans plan';
    final price   = mensualiteGroupe(m);
    final agg     = planAgg[name] ?? const _PlanAgg(0, 0);
    planAgg[name] = _PlanAgg(agg.count + 1, agg.revenue + price);
  }
  int colorIdx = 0;
  final groupsByPlan = planAgg.entries
      .map((e) => ReportsByPlan(
            planName:   e.key,
            groupCount: e.value.count,
            revenueXaf: e.value.revenue,
            color:      planColors[colorIdx++ % planColors.length],
          ))
      .toList()
    ..sort((a, b) => b.groupCount.compareTo(a.groupCount));

  // ── Dept ───────────────────────────────────────────────────────────────────
  final Map<String, int> groupsByDept = {};
  for (final g in groups) {
    final dept = (g as Map)['department'] as String? ?? 'Non précisé';
    groupsByDept[dept] = (groupsByDept[dept] ?? 0) + 1;
  }

  // ── Top 5 groups ───────────────────────────────────────────────────────────
  final Map<String, int> schoolsByGroup = {};
  for (final s in schools) {
    final gid = (s as Map)['group_id'] as String;
    schoolsByGroup[gid] = (schoolsByGroup[gid] ?? 0) + 1;
  }
  final Map<String, int> revByGroup = {};
  for (final inv in paidInvoices) {
    final gid = (inv as Map)['group_id'] as String;
    revByGroup[gid] = (revByGroup[gid] ?? 0) + ((inv)['amount_xaf'] as num).toInt();
  }
  final topGroups = groups.map((g) {
    final m       = g as Map;
    final planMap = m['subscription_plans'] as Map?;
    return TopGroupEntry(
      name:        m['name'] as String? ?? '—',
      schoolCount: schoolsByGroup[m['id'] as String] ?? 0,
      planName:    planMap?['name'] as String? ?? '—',
      status:      m['subscription_status'] as String? ?? 'unknown',
      department:  m['department'] as String? ?? '—',
      revenueXaf:  revByGroup[m['id'] as String] ?? 0,
      groupType:   m['group_type'] as String? ?? 'private',
    );
  }).toList()
    ..sort((a, b) => b.schoolCount.compareTo(a.schoolCount));

  // ── Staff by contract ──────────────────────────────────────────────────────
  final Map<String, int> staffByContract = {};
  for (final s in staff) {
    final ct = (s)['employment_status'] as String? ?? 'inconnu';
    staffByContract[ct] = (staffByContract[ct] ?? 0) + 1;
  }

  // ── Monthly data ───────────────────────────────────────────────────────────
  const moisFr = ['Jan','Fév','Mar','Avr','Mai','Juin','Juil','Aoû','Sep','Oct','Nov','Déc'];
  final now = DateTime.now();
  final monthly = List.generate(months, (i) {
    final target = DateTime(now.year, now.month - (months - 1) + i, 1);
    final monthInvoices = invoices.where((inv) {
      final dt = DateTime.parse((inv as Map)['created_at'] as String);
      return dt.year == target.year && dt.month == target.month;
    }).toList();
    final rev = monthInvoices
        .where((inv) => (inv as Map)['status'] == 'paid')
        .fold<int>(0, (s, inv) => s + ((inv as Map)['amount_xaf'] as num).toInt());
    final paid    = monthInvoices.where((inv) => (inv as Map)['status'] == 'paid').length;
    final pending = monthInvoices.where((inv) => (inv as Map)['status'] == 'pending').length;
    return ReportMonthly(
      label:        moisFr[target.month - 1],
      revenueXaf:   rev,
      invoiceCount: monthInvoices.length,
      paidCount:    paid,
      pendingCount: pending,
    );
  });

  // ── Financial summary ──────────────────────────────────────────────────────
  final totalAll = invoices.fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());
  final paidAmt    = paidInvoices.fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());
  final pendingAmt = pendingInvoices.fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());
  final overdueAmt = overdueInvoices.fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());
  final cancelAmt  = cancelledInvoices.fold<int>(0, (s, i) => s + ((i as Map)['amount_xaf'] as num).toInt());
  double pct(int amt) => totalAll > 0 ? amt / totalAll * 100 : 0.0;

  final financialSummary = [
    FinancialSummaryRow(label: 'Factures payées',    amount: paidAmt,    count: paidInvoices.length,      pct: pct(paidAmt)),
    FinancialSummaryRow(label: 'En attente',         amount: pendingAmt, count: pendingInvoices.length,   pct: pct(pendingAmt)),
    FinancialSummaryRow(label: 'En retard',          amount: overdueAmt, count: overdueInvoices.length,   pct: pct(overdueAmt)),
    FinancialSummaryRow(label: 'Annulées',           amount: cancelAmt,  count: cancelledInvoices.length, pct: pct(cancelAmt)),
  ];

  return ReportsData(
    totalGroupes:          groups.length,
    totalEcoles:           schools.length,
    totalEleves:           totalElevesCount,
    totalPersonnel:        staff.length,
    totalRevenusXaf:       totalRevenusXaf,
    totalFacturesPending:  pendingInvoices.length,
    mrr:                   mrr,
    arr:                   mrr * 12,
    paymentRate:           paymentRate,
    totalPublic:           totalPublic,
    totalPrivate:          totalPrivate,
    groupsByPlan:          groupsByPlan,
    monthly:               monthly,
    topGroups:             topGroups.take(5).toList(),
    groupsByDept:          groupsByDept,
    staffByContract:       staffByContract,
    financialSummary:      financialSummary,
    totalFacturesOverdue:  overdueInvoices.length,
    totalFacturesCancelled:cancelledInvoices.length,
  );
});

class _PlanAgg {
  const _PlanAgg(this.count, this.revenue);
  final int count;
  final int revenue;
}
