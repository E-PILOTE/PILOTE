import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

class ReceiptModel {
  const ReceiptModel({
    required this.id,
    required this.invoiceNumber,
    required this.groupId,
    required this.groupName,
    required this.planName,
    required this.amountXaf,
    required this.periodStart,
    required this.periodEnd,
    required this.paidAt,
    required this.paymentMethod,
    required this.paymentReference,
    required this.createdAt,
    this.storedReceiptNumber,
  });

  final String  id;
  final String  invoiceNumber;
  final String  groupId;
  final String  groupName;
  final String  planName;
  final int     amountXaf;
  final String  periodStart;
  final String  periodEnd;
  final String  paidAt;
  final String  paymentMethod;
  final String  paymentReference;
  final String  createdAt;
  final String? storedReceiptNumber;

  String get receiptNumber =>
      (storedReceiptNumber != null && storedReceiptNumber!.isNotEmpty)
          ? storedReceiptNumber!
          : 'REC-${invoiceNumber.replaceFirst('INV-', '')}';
}

class UnpaidInvoice {
  const UnpaidInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.groupName,
    required this.amountXaf,
    required this.status,
  });
  final String id, invoiceNumber, groupName, status;
  final int    amountXaf;

  String get label =>
      '$invoiceNumber · $groupName · ${amountXaf ~/ 1000}K XAF';
}

final unpaidInvoicesProvider =
    FutureProvider.autoDispose<List<UnpaidInvoice>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('group_invoices')
      .select('id, invoice_number, amount_xaf, status, school_groups(name)')
      .inFilter('status', ['pending', 'overdue'])
      .order('created_at', ascending: false) as List;
  return rows.map((r) {
    final m  = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    return UnpaidInvoice(
      id:            m['id'] as String,
      invoiceNumber: m['invoice_number'] as String? ?? '—',
      groupName:     sg['name'] as String? ?? '—',
      amountXaf:     (m['amount_xaf'] as num).toInt(),
      status:        m['status'] as String? ?? 'pending',
    );
  }).toList();
});

/// Enregistre le paiement d'une facture → génère un reçu (statut paid).
Future<void> recordInvoicePayment(
  dynamic client, {
  required String invoiceId,
  required String invoiceNumber,
  required String paymentMethod,
  required String paymentReference,
}) async {
  final now = DateTime.now().toIso8601String();
  await client.from('group_invoices').update({
    'status':            'paid',
    'paid_at':           now,
    'payment_method':    paymentMethod,
    'payment_reference': paymentReference,
    'receipt_number':    'REC-${invoiceNumber.replaceFirst('INV-', '')}',
    'updated_at':        now,
  }).eq('id', invoiceId);
}

class ReceiptsData {
  const ReceiptsData({
    required this.receipts,
    required this.totalCount,
    required this.totalAmountXaf,
    required this.monthAmountXaf,
    required this.avgAmountXaf,
    required this.byMethod,
  });

  final List<ReceiptModel>   receipts;
  final int                  totalCount;
  final int                  totalAmountXaf;
  final int                  monthAmountXaf;
  final int                  avgAmountXaf;
  final Map<String, int>     byMethod;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final receiptsProvider = FutureProvider.autoDispose<ReceiptsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('group_invoices')
      .select(
        'id, invoice_number, group_id, amount_xaf, period_start, period_end, '
        'paid_at, payment_method, payment_reference, receipt_number, created_at, '
        'school_groups(name), subscription_plans(name)',
      )
      .eq('status', 'paid')
      .order('paid_at', ascending: false);

  final receipts = (rows as List).map((r) {
    final m = r as Map;
    final sg = m['school_groups'] as Map? ?? {};
    final sp = m['subscription_plans'] as Map? ?? {};
    return ReceiptModel(
      id:               m['id'] as String,
      invoiceNumber:    m['invoice_number'] as String? ?? '—',
      groupId:          m['group_id'] as String,
      groupName:        sg['name'] as String? ?? '—',
      planName:         sp['name'] as String? ?? '—',
      amountXaf:        (m['amount_xaf'] as num).toInt(),
      periodStart:      m['period_start'] as String? ?? '',
      periodEnd:        m['period_end'] as String? ?? '',
      paidAt:           m['paid_at'] as String? ?? '',
      paymentMethod:    m['payment_method'] as String? ?? '',
      paymentReference: m['payment_reference'] as String? ?? '',
      createdAt:        m['created_at'] as String,
      storedReceiptNumber: m['receipt_number'] as String?,
    );
  }).toList();

  final total    = receipts.fold<int>(0, (s, r) => s + r.amountXaf);
  final avg      = receipts.isEmpty ? 0 : total ~/ receipts.length;

  final now   = DateTime.now();
  final month = receipts
      .where((r) {
        if (r.paidAt.isEmpty) return false;
        final d = DateTime.tryParse(r.paidAt);
        return d != null && d.year == now.year && d.month == now.month;
      })
      .fold<int>(0, (s, r) => s + r.amountXaf);

  final Map<String, int> byMethod = {};
  for (final r in receipts) {
    byMethod[r.paymentMethod] = (byMethod[r.paymentMethod] ?? 0) + r.amountXaf;
  }

  return ReceiptsData(
    receipts:       receipts,
    totalCount:     receipts.length,
    totalAmountXaf: total,
    monthAmountXaf: month,
    avgAmountXaf:   avg,
    byMethod:       byMethod,
  );
});
