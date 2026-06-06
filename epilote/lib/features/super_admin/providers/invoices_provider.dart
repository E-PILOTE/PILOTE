import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class InvoiceDetail {

  factory InvoiceDetail.fromMap(Map<String, dynamic> m) => InvoiceDetail(
    id:               m['id'] as String,
    groupId:          m['group_id'] as String,
    groupName:        m['group_name'] as String? ?? '—',
    invoiceNumber:    m['invoice_number'] as String,
    amountXaf:        (m['amount_xaf'] as num).toInt(),
    periodStart:      DateTime.parse(m['period_start'] as String),
    periodEnd:        DateTime.parse(m['period_end'] as String),
    status:           m['status'] as String,
    createdAt:        DateTime.parse(m['created_at'] as String),
    updatedAt:        DateTime.parse(m['updated_at'] as String),
    planName:         m['plan_name'] as String?,
    planId:           m['plan_id'] as String?,
    paidAt:           m['paid_at'] != null
        ? DateTime.parse(m['paid_at'] as String) : null,
    paymentMethod:    m['payment_method'] as String?,
    paymentReference: m['payment_reference'] as String?,
    notes:            m['notes'] as String?,
  );
  const InvoiceDetail({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invoiceNumber,
    required this.amountXaf,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.planName,
    this.planId,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.notes,
  });

  final String    id;
  final String    groupId;
  final String    groupName;
  final String    invoiceNumber;
  final int       amountXaf;
  final DateTime  periodStart;
  final DateTime  periodEnd;
  final String    status;
  final DateTime  createdAt;
  final DateTime  updatedAt;
  final String?   planName;
  final String?   planId;
  final DateTime? paidAt;
  final String?   paymentMethod;
  final String?   paymentReference;
  final String?   notes;

  bool get isPaid      => status == 'paid';
  bool get isOverdue   => status == 'overdue';
  bool get isPending   => status == 'pending';
  bool get isCancelled => status == 'cancelled';
}

class InvoicesData {
  const InvoicesData({
    required this.invoices,
    required this.total,
    required this.totalPaid,
    required this.totalPending,
    required this.totalOverdue,
    required this.totalCancelled,
    required this.montantEncaisse,
    required this.montantPending,
  });

  final List<InvoiceDetail> invoices;
  final int total;
  final int totalPaid;
  final int totalPending;
  final int totalOverdue;
  final int totalCancelled;
  final int montantEncaisse;
  final int montantPending;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final invoicesProvider = FutureProvider.autoDispose<InvoicesData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('group_invoices')
      .select('*, school_groups(name), subscription_plans(name)')
      .order('created_at', ascending: false);

  final invoices = (rows as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    m['group_name'] = (r['school_groups'] as Map?)?['name'];
    m['plan_name']  = (r['subscription_plans'] as Map?)?['name'];
    return InvoiceDetail.fromMap(m);
  }).toList();

  final montantEncaisse = invoices
      .where((i) => i.isPaid)
      .fold<int>(0, (s, i) => s + i.amountXaf);
  final montantPending = invoices
      .where((i) => i.isPending || i.isOverdue)
      .fold<int>(0, (s, i) => s + i.amountXaf);

  return InvoicesData(
    invoices:        invoices,
    total:           invoices.length,
    totalPaid:       invoices.where((i) => i.isPaid).length,
    totalPending:    invoices.where((i) => i.isPending).length,
    totalOverdue:    invoices.where((i) => i.isOverdue).length,
    totalCancelled:  invoices.where((i) => i.isCancelled).length,
    montantEncaisse: montantEncaisse,
    montantPending:  montantPending,
  );
});
