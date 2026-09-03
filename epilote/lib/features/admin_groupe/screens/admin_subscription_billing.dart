import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../super_admin/providers/invoices_provider.dart' show InvoiceDetail;
import '../../super_admin/providers/receipts_provider.dart' show ReceiptModel;
import '../../super_admin/services/financial_pdf_service.dart';
import '../providers/admin_subscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FACTURATION DU GROUPE — factures, reçus, exports PDF
//
//  Sorti de `admin_subscription_screen.dart` (1 641 lignes) le jour où cette
//  page a cessé de raconter une seule histoire : depuis 0182, un ministère y
//  lit sa LICENCE et un groupe privé son ABONNEMENT. La facturation, elle,
//  reste commune aux deux — d'où la coupure ici, le long de cette couture.
//
//  ⚠️ Lecture seule de bout en bout. Le groupe consulte et exporte ; il
//  n'écrit pas. Marquer une facture payée reste un geste de la plateforme
//  (`mark_invoice_paid`, super_admin).
// ════════════════════════════════════════════════════════════════════════════

// ─── Section facturation (factures + reçus, lecture seule) ─────────────────────
/// Publique : c'est le seul point d'entrée du bloc, appelé par
/// `admin_subscription_screen.dart` pour les deux natures de groupe.
class BillingSection extends StatelessWidget {
  const BillingSection({super.key, required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final invoices = data.invoices;
    if (invoices.isEmpty) {
      return AdminCard(
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, color: kTextMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Aucune facture émise pour le moment.',
                style: TextStyle(color: kTextMuted, fontSize: 13)),
          ),
        ]),
      );
    }
    return Column(children: [
      _BillingSummary(data: data),
      const SizedBox(height: 12),
      ...invoices.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InvoiceRow(inv: i),
          )),
    ]);
  }
}

class _BillingSummary extends StatelessWidget {
  const _BillingSummary({required this.data});
  final AdminSubscriptionData data;

  @override
  Widget build(BuildContext context) {
    final reste = data.outstandingTotal;
    final items = [
      _MiniStat(label: 'Total facturé', value: data.billedTotal,
          color: kNavy, icon: Icons.summarize_rounded),
      _MiniStat(label: 'Encaissé', value: data.paidTotal,
          color: kGreen, icon: Icons.verified_rounded),
      _MiniStat(label: 'Reste à payer', value: reste,
          color: reste > 0 ? kRed : kTextMuted, icon: Icons.pending_actions_rounded),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 3 : 1;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: items.map((i) => SizedBox(width: w, child: i)).toList(),
      );
    });
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: kTextMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(fmtXaf(value), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Ligne facture (export PDF facture + reçu) ─────────────────────────────────
class _InvoiceRow extends StatefulWidget {
  const _InvoiceRow({required this.inv});
  final InvoiceDetail inv;

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  bool _busy = false;

  (Color, String, IconData) _statusMeta(String s) => switch (s) {
    'paid'      => (kGreen, 'Payée', Icons.check_circle_rounded),
    'pending'   => (kAccent, 'En attente', Icons.schedule_rounded),
    'overdue'   => (kRed, 'En retard', Icons.error_rounded),
    'cancelled' => (kTextMuted, 'Annulée', Icons.cancel_rounded),
    _           => (kTextMuted, s, Icons.circle),
  };

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  ReceiptModel _toReceipt(InvoiceDetail i) => ReceiptModel(
        id: i.id,
        invoiceNumber: i.invoiceNumber,
        groupId: i.groupId,
        groupName: i.groupName,
        planName: i.planName ?? '—',
        amountXaf: i.amountXaf,
        periodStart: i.periodStart.toIso8601String(),
        periodEnd: i.periodEnd.toIso8601String(),
        paidAt: i.paidAt?.toIso8601String() ?? '',
        paymentMethod: i.paymentMethod ?? '',
        paymentReference: i.paymentReference ?? '',
        createdAt: i.createdAt.toIso8601String(),
      );

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kRed,
          content: Text('Génération PDF impossible : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pdfBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.inv;
    final (sc, sl, si) = _statusMeta(i.status);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 560;
        final info = Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(si, color: sc, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(i.invoiceNumber, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextPrimary)),
                ),
                const SizedBox(width: 8),
                AdminBadge(sl, color: sc),
              ]),
              const SizedBox(height: 3),
              Text('${_d(i.periodStart)} → ${_d(i.periodEnd)}',
                  style: TextStyle(fontSize: 12, color: kTextMuted)),
            ]),
          ),
          const SizedBox(width: 12),
          Text(fmtXaf(i.amountXaf),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sc)),
        ]);
        final actions = _busy
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _pdfBtn('Facture', Icons.description_rounded, kNavy,
                    () => _run(() => InvoicePdfService.printInvoice(i))),
                if (i.isPaid) ...[
                  const SizedBox(width: 8),
                  _pdfBtn('Reçu', Icons.receipt_rounded, kGreen,
                      () => _run(() => ReceiptPdfService.printReceipt(_toReceipt(i)))),
                ],
              ]);
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            info,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: actions),
          ]);
        }
        return Row(children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          actions,
        ]);
      }),
    );
  }
}
