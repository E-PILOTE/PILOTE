import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/receipts_provider.dart';
import '../services/financial_pdf_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kPurple = Color(0xFF7C3AED);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);

final _fmtXaf  = NumberFormat.currency(locale: 'fr_FR', symbol: 'XAF', decimalDigits: 0);
final _fmtNum  = NumberFormat.decimalPattern('fr_FR');
final _fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');
final _fmtMo   = DateFormat('dd/MM/yy', 'fr_FR');

// ─── Local state ──────────────────────────────────────────────────────────────

final _searchProvider  = StateProvider.autoDispose<String>((ref) => '');
final _methodProvider  = StateProvider.autoDispose<String>((ref) => 'all');
final _viewProvider    = StateProvider.autoDispose<bool>((ref) => true); // true = table
final _sortAscProvider = StateProvider.autoDispose<bool>((ref) => false); // false = plus récent en premier

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptsProvider);

    return AppShell(
      title: 'Reçus de Paiement',
      child: async.when(
        skipLoadingOnReload: true, skipLoadingOnRefresh: true,
        loading: () => const _LoadingSkeleton(),
        error:   (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(receiptsProvider)),
        data:    (data) => _ReceiptsBody(data: data),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ReceiptsBody extends ConsumerWidget {
  const _ReceiptsBody({required this.data});
  final ReceiptsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchProvider);
    final method = ref.watch(_methodProvider);
    final isTable= ref.watch(_viewProvider);

    final sortAsc = ref.watch(_sortAscProvider);
    var receipts = data.receipts;
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      receipts = receipts.where((r) =>
          r.groupName.toLowerCase().contains(q) ||
          r.invoiceNumber.toLowerCase().contains(q) ||
          r.receiptNumber.toLowerCase().contains(q)).toList();
    }
    if (method != 'all') {
      receipts = receipts.where((r) => r.paymentMethod == method).toList();
    }
    receipts = [...receipts]..sort((a, b) {
      if (a.paidAt.isEmpty && b.paidAt.isEmpty) return 0;
      if (a.paidAt.isEmpty) return 1;
      if (b.paidAt.isEmpty) return -1;
      final cmp = DateTime.parse(a.paidAt).compareTo(DateTime.parse(b.paidAt));
      return sortAsc ? cmp : -cmp;
    });

    return Column(
      children: [
        _KpiBar(data: data),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _FilterBar(isTable: isTable),
        ),
        Expanded(
          child: isTable
              ? _TableView(receipts: receipts)
              : _CardView(receipts: receipts),
        ),
      ],
    );
  }
}

// ─── KPI Bar ──────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.data});
  final ReceiptsData data;

  @override
  Widget build(BuildContext context) {
    final methodTotals = data.byMethod;
    final mtnAmt    = methodTotals['mtn_money']    ?? 0;
    final airtelAmt = methodTotals['airtel_money'] ?? 0;
    final visaAmt   = methodTotals['visa']         ?? 0;
    final cashAmt   = methodTotals['especes']      ?? 0;

    final kpis = [
      _Kpi(icon: Icons.receipt_long_rounded,       label: 'Total reçus',         value: _fmtNum.format(data.totalCount),        sub: 'paiements confirmés', color: _kNavy),
      _Kpi(icon: Icons.account_balance_wallet_rounded, label: 'Total encaissé',  value: _fmtXaf.format(data.totalAmountXaf),    sub: 'toutes périodes', color: _kGreen),
      _Kpi(icon: Icons.calendar_month_rounded,     label: 'Ce mois',             value: _fmtXaf.format(data.monthAmountXaf),    sub: 'paiements du mois en cours', color: _kPurple),
      _Kpi(icon: Icons.bar_chart_rounded,          label: 'Montant moyen',       value: _fmtXaf.format(data.avgAmountXaf),      sub: 'par reçu', color: _kGold),
      _Kpi(icon: Icons.phone_android_rounded,      label: 'MTN Money',           value: _fmtXaf.format(mtnAmt),                 sub: methodTotals['mtn_money'] != null ? 'actif' : 'aucun', color: _kGold),
      _Kpi(icon: Icons.phone_android_rounded,      label: 'Airtel Money',        value: _fmtXaf.format(airtelAmt),              sub: 'transactions', color: const Color(0xFFEF4444)),
      _Kpi(icon: Icons.credit_card_rounded,        label: 'Carte Visa',          value: _fmtXaf.format(visaAmt),                sub: 'transactions', color: const Color(0xFF1A1F71)),
      _Kpi(icon: Icons.payments_rounded,           label: 'Espèces',             value: _fmtXaf.format(cashAmt),                sub: 'transactions', color: _kGreen),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: kpis.length,
          itemBuilder: (_, i) => _KpiCard(kpi: kpis[i]),
        );
      }),
    );
  }
}

class _Kpi {
  const _Kpi({required this.icon, required this.label, required this.value, required this.sub, required this.color});
  final IconData icon; final String label; final String value; final String sub; final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _Kpi kpi;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(kpi.icon, color: kpi.color, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kpi.label, style: const TextStyle(fontSize: 10, color: _kSub, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(kpi.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(kpi.sub, style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.isTable});
  final bool isTable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortAsc = ref.watch(_sortAscProvider);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher par groupe, numéro de reçu…',
                hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kSub),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _DropFilter(
            items: const {'all': 'Tous modes', 'mtn_money': 'MTN Money', 'airtel_money': 'Airtel Money', 'visa': 'Visa', 'especes': 'Espèces'},
            value: ref.watch(_methodProvider),
            onChanged: (v) => ref.read(_methodProvider.notifier).state = v ?? 'all',
          ),
        ),
        const SizedBox(width: 8),
        // Tri par date
        Tooltip(
          message: sortAsc ? 'Plus ancien en premier' : 'Plus récent en premier',
          child: OutlinedButton.icon(
            onPressed: () => ref.read(_sortAscProvider.notifier).state = !sortAsc,
            icon: Icon(sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14),
            label: Text(sortAsc ? 'Ancien' : 'Récent', style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kNavy,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Créer un reçu
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _NewReceiptDialog(),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Créer un reçu'),
          style: FilledButton.styleFrom(
            backgroundColor: _kGreen, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _ViewBtn(icon: Icons.table_rows_rounded, selected: isTable,  onTap: () => ref.read(_viewProvider.notifier).state = true),
              _ViewBtn(icon: Icons.grid_view_rounded,  selected: !isTable, onTap: () => ref.read(_viewProvider.notifier).state = false),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded),
          color: _kNavy,
          onPressed: () => ref.invalidate(receiptsProvider),
        ),
      ],
    );
  }
}

class _DropFilter extends StatelessWidget {
  const _DropFilter({required this.items, required this.value, required this.onChanged});
  final Map<String, String> items; final String value; final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value, onChanged: onChanged,
    items: items.entries.map((e) => DropdownMenuItem(value: e.key,
        child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
    decoration: InputDecoration(
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      filled: true, fillColor: Colors.white,
    ),
  );
}

class _ViewBtn extends StatelessWidget {
  const _ViewBtn({required this.icon, required this.selected, required this.onTap});
  final IconData icon; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected ? _kNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 18, color: selected ? Colors.white : _kSub),
    ),
  );
}

// ─── Table view ───────────────────────────────────────────────────────────────

class _TableView extends StatelessWidget {
  const _TableView({required this.receipts});
  final List<ReceiptModel> receipts;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) return const _EmptyState();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            _TableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: receipts.length,
                itemBuilder: (ctx, i) => _TableRow(receipt: receipts[i], index: i, context: ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: const Row(children: [
      Expanded(flex: 2, child: _Th('N° Reçu')),
      Expanded(flex: 3, child: _Th('Groupe')),
      Expanded(flex: 2, child: _Th('Plan')),
      Expanded(flex: 2, child: _Th('Montant')),
      Expanded(flex: 2, child: _Th('Date paiement')),
      Expanded(flex: 2, child: _Th('Période')),
      Expanded(flex: 2, child: _Th('Mode')),
      SizedBox(width: 60, child: _Th('Actions')),
    ]),
  );
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSub));
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.receipt, required this.index, required this.context});
  final ReceiptModel receipt; final int index; final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final bg = index.isEven ? Colors.transparent : const Color(0xFFF8FAFC);
    return GestureDetector(
      onTap: () => _showDetail(ctx, receipt),
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(flex: 2, child: Text(receipt.receiptNumber,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(receipt.groupName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(receipt.planName,
              style: const TextStyle(fontSize: 11, color: _kSub),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(_fmtXaf.format(receipt.amountXaf),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGreen))),
          Expanded(flex: 2, child: Text(
              receipt.paidAt.isNotEmpty ? _fmtDate.format(DateTime.parse(receipt.paidAt)) : '—',
              style: const TextStyle(fontSize: 11, color: _kText))),
          Expanded(flex: 2, child: Text(
              receipt.periodStart.isNotEmpty
                  ? '${_fmtMo.format(DateTime.parse(receipt.periodStart))} → ${_fmtMo.format(DateTime.parse(receipt.periodEnd))}'
                  : '—',
              style: const TextStyle(fontSize: 10, color: _kSub))),
          Expanded(flex: 2, child: _MethodChip(method: receipt.paymentMethod)),
          SizedBox(width: 60, child: Row(
            children: [
              _IconBtn(icon: Icons.visibility_rounded, tooltip: 'Voir', onTap: () => _showDetail(ctx, receipt)),
              _IconBtn(icon: Icons.picture_as_pdf_rounded, tooltip: 'Imprimer / PDF',
                  onTap: () => ReceiptPdfService.printReceipt(receipt)),
            ],
          )),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon; final String tooltip; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16), tooltip: tooltip,
    color: _kSub, onPressed: onTap,
    padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
  );
}

// ─── Card view ────────────────────────────────────────────────────────────────

class _CardView extends StatelessWidget {
  const _CardView({required this.receipts});
  final List<ReceiptModel> receipts;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) return const _EmptyState();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0,
          ),
          itemCount: receipts.length,
          itemBuilder: (ctx, i) => _ReceiptCard(receipt: receipts[i], context: ctx),
        );
      }),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt, required this.context});
  final ReceiptModel receipt; final BuildContext context;

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: () => _showDetail(ctx, receipt),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(receipt.receiptNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy)),
              _MethodChip(method: receipt.paymentMethod),
            ],
          ),
          const SizedBox(height: 6),
          Text(receipt.groupName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(receipt.planName, style: const TextStyle(fontSize: 11, color: _kSub)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtXaf.format(receipt.amountXaf),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kGreen)),
              Text(receipt.paidAt.isNotEmpty
                  ? _fmtDate.format(DateTime.parse(receipt.paidAt)) : '—',
                  style: const TextStyle(fontSize: 11, color: _kSub)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── Method chip ──────────────────────────────────────────────────────────────

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (method) {
      'mtn_money'    => ('MTN',    _kGold),
      'airtel_money' => ('Airtel', const Color(0xFFEF4444)),
      'visa'         => ('Visa',   const Color(0xFF1A1F71)),
      'especes'      => ('Cash',   _kGreen),
      _               => (method,  _kSub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Detail modal ─────────────────────────────────────────────────────────────

void _showDetail(BuildContext context, ReceiptModel receipt) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _ReceiptDetail(receipt: receipt),
    ),
  );
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.receipt});
  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    final paidDate  = receipt.paidAt.isNotEmpty     ? _fmtDate.format(DateTime.parse(receipt.paidAt))     : '—';
    final startDate = receipt.periodStart.isNotEmpty ? _fmtDate.format(DateTime.parse(receipt.periodStart)) : '—';
    final endDate   = receipt.periodEnd.isNotEmpty   ? _fmtDate.format(DateTime.parse(receipt.periodEnd))   : '—';
    final now       = DateFormat('dd/MM/yyyy', 'fr_FR').format(DateTime.now());

    return SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête du dialog ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Text('Document officiel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copier le numéro',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: receipt.receiptNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Numéro de reçu copié !'), duration: Duration(seconds: 2)));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: _kSub,
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: _kSub),
                ],
              ),
            ),
            // ── Document papier ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header E-PILOTE ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF2A4F7A)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo E-PILOTE
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_rounded, color: Color(0xFF1E3A5F), size: 22),
                                  Text('EP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1E3A5F))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('E-PILOTE CONGO',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                const Text('Plateforme de Gestion Scolaire',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF009A44),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('REÇU DE PAIEMENT OFFICIEL',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                                ),
                              ],
                            ),
                          ),
                          // Info document
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(receipt.receiptNumber,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Émis le $now',
                                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
                              Text('Payé le $paidDate',
                                  style: const TextStyle(color: Color(0xFFFBBC04), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Bandeau groupe ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      color: const Color(0xFFF0F4F8),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _kNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kNavy.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.corporate_fare_rounded, color: _kNavy, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(receipt.groupName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kText)),
                                Text('Groupe Scolaire · Plan : ${receipt.planName}',
                                    style: const TextStyle(fontSize: 11, color: _kSub)),
                              ],
                            ),
                          ),
                          // Badge PAYÉ
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text('PAYÉ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ]),
                          ),
                        ],
                      ),
                    ),

                    // ── Corps du document ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Montant encadré
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: _kGreen.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kGreen.withValues(alpha: 0.25), width: 1.5),
                            ),
                            child: Column(children: [
                              const Text('MONTANT TOTAL PAYÉ',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 1.0)),
                              const SizedBox(height: 8),
                              Text(_fmtXaf.format(receipt.amountXaf),
                                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: _kGreen)),
                              const Text('Francs CFA', style: TextStyle(fontSize: 11, color: _kSub)),
                            ]),
                          ),

                          // Table de détails
                          _DocRow(label: 'N° Reçu',           value: receipt.receiptNumber, bold: true),
                          _DocRow(label: 'N° Facture',         value: receipt.invoiceNumber),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          _DocRow(label: 'Groupe scolaire',   value: receipt.groupName),
                          _DocRow(label: 'Plan d\'abonnement', value: receipt.planName),
                          _DocRow(label: 'Période couverte',  value: '$startDate → $endDate'),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          _DocRow(label: 'Date de paiement',  value: paidDate, color: _kGreen),
                          _DocRow(label: 'Mode de règlement', value: _methodLabel(receipt.paymentMethod)),
                          if (receipt.paymentReference.isNotEmpty)
                            _DocRow(label: 'Réf. transaction', value: receipt.paymentReference, mono: true),
                        ],
                      ),
                    ),

                    // ── Pied de page légal ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Ce document est un justificatif officiel de paiement émis par la plateforme E-PILOTE Congo.',
                            style: TextStyle(fontSize: 10, color: _kSub),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text('Référence : ${receipt.receiptNumber} — Conservez ce document pour vos archives.',
                              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Boutons d'action ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptPdfService.printReceipt(receipt),
                      icon: const Icon(Icons.print_rounded, size: 14),
                      label: const Text('Imprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kNavy, side: const BorderSide(color: _kNavy),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptPdfService.shareReceipt(receipt),
                      icon: const Icon(Icons.share_rounded, size: 14),
                      label: const Text('Partager'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kSub, side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final path = await ReceiptPdfService.downloadReceipt(receipt);
                        messenger.showSnackBar(SnackBar(
                          content: Text(path != null
                              ? 'Reçu enregistré : $path'
                              : 'Échec de l\'enregistrement du PDF'),
                          backgroundColor: path != null ? _kGreen : Colors.red,
                        ));
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: const Text('Télécharger PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreen, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.label, required this.value, this.bold = false, this.mono = false, this.color});
  final String label; final String value; final bool bold; final bool mono; final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kSub))),
        Expanded(child: Text(value,
            style: TextStyle(
              fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? _kText,
              fontFamily: mono ? 'monospace' : null,
            ))),
      ],
    ),
  );
}

// ─── Dialogue création manuelle de reçu ───────────────────────────────────────

class _NewReceiptDialog extends ConsumerStatefulWidget {
  const _NewReceiptDialog();
  @override
  ConsumerState<_NewReceiptDialog> createState() => _NewReceiptDialogState();
}

class _NewReceiptDialogState extends ConsumerState<_NewReceiptDialog> {
  final _refCtrl     = TextEditingController();
  String  _method    = 'mtn_money';
  String? _invoiceId;
  bool    _sending   = false;

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_rounded, color: _kGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Créer un reçu manuel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                    Text('Enregistrement d\'un paiement hors-plateforme', style: TextStyle(fontSize: 11, color: _kSub)),
                  ],
                )),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), color: _kSub),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Pour les paiements effectués en dehors du système. Sélectionnez la facture correspondante puis enregistrez le paiement.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Facture à régler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              Consumer(builder: (_, ref, _) {
                final async = ref.watch(unpaidInvoicesProvider);
                return async.when(
                  loading: () => const SizedBox(
                    height: 42,
                    child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (e, _) => Text('Erreur : $e', style: const TextStyle(fontSize: 11, color: Colors.red)),
                  data: (invoices) {
                    if (invoices.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('Aucune facture en attente de paiement.',
                            style: TextStyle(fontSize: 12, color: _kSub)),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _invoiceId,
                      isExpanded: true,
                      hint: const Text('Sélectionner une facture', style: TextStyle(fontSize: 12, color: _kSub)),
                      onChanged: (v) => setState(() => _invoiceId = v),
                      items: invoices.map((inv) => DropdownMenuItem(
                        value: inv.id,
                        child: Text(inv.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      decoration: InputDecoration(
                        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
              const Text('Référence de paiement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              TextField(
                controller: _refCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ex : TXN-MTN-20250315-001',
                  hintStyle: const TextStyle(fontSize: 12, color: _kSub),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy)),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Mode de règlement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _method,
                onChanged: (v) => setState(() => _method = v ?? _method),
                items: const [
                  DropdownMenuItem(value: 'mtn_money',    child: Text('MTN Mobile Money', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'airtel_money', child: Text('Airtel Money',      style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'visa',         child: Text('Visa / Carte',       style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'especes',      child: Text('Espèces',             style: TextStyle(fontSize: 12))),
                ],
                decoration: InputDecoration(
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      if (_invoiceId == null) {
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Veuillez sélectionner une facture')));
                        return;
                      }
                      if (_refCtrl.text.trim().isEmpty) {
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Veuillez saisir une référence de paiement')));
                        return;
                      }
                      setState(() => _sending = true);
                      try {
                        final client = ref.read(supabaseClientProvider);
                        final invoices = ref.read(unpaidInvoicesProvider).valueOrNull ?? [];
                        final inv = invoices.firstWhere((i) => i.id == _invoiceId);
                        await recordInvoicePayment(
                          client,
                          invoiceId:        _invoiceId!,
                          invoiceNumber:    inv.invoiceNumber,
                          paymentMethod:    _method,
                          paymentReference: _refCtrl.text.trim(),
                        );
                        ref.invalidate(receiptsProvider);
                        ref.invalidate(unpaidInvoicesProvider);
                        navigator.pop();
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Reçu créé avec succès'), backgroundColor: _kGreen));
                      } catch (e) {
                        if (mounted) setState(() => _sending = false);
                        messenger.showSnackBar(
                            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
                      }
                    },
                    icon: _sending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Créer le reçu'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

String _methodLabel(String m) => switch (m) {
  'mtn_money'    => 'MTN Mobile Money',
  'airtel_money' => 'Airtel Money',
  'visa'         => 'Visa / Carte bancaire',
  'especes'      => 'Espèces',
  _               => m,
};

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Aucun reçu trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 4),
      const Text('Les reçus apparaissent après confirmation de paiement',
          style: TextStyle(fontSize: 12, color: _kSub)),
    ]),
  );
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.8),
        itemCount: 8, itemBuilder: (_, _) => const _Shim(height: 70)),
      const SizedBox(height: 12),
      const _Shim(height: 40),
      const SizedBox(height: 12),
      const _Shim(height: 400),
    ]),
  );
}

class _Shim extends StatelessWidget {
  const _Shim({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
  );
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
      const SizedBox(height: 12),
      Text('Erreur : $error', style: const TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
    ]),
  );
}
