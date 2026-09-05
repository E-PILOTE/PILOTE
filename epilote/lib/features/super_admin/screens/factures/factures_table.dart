part of '../invoices_screen.dart';

// Vue tableau.

class _TableView extends StatelessWidget {
  const _TableView({required this.items, required this.onView});
  final List<InvoiceDetail> items;
  final ValueChanged<InvoiceDetail> onView;

  static Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: TextStyle(
        color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();

    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38, color: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _hdr('N° Facture',   2),
              _hdr('Groupe',       3),
              _hdr('Plan',         2),
              _hdr('Montant XAF',  2),
              _hdr('Période',      3),
              _hdr('Mode',         2),
              _hdr('Payée le',     2),
              SizedBox(width: 80, child: Center(
                child: Text('Statut', style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              )),
              const SizedBox(width: 36),
            ]),
          ),
          Divider(height: 1, color: _kBorder),
          ...items.asMap().entries.map((e) => _TableRow(
            inv:   e.value,
            isOdd: e.key.isOdd,
            onTap: () => onView(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.inv, required this.isOdd, required this.onTap});
  final InvoiceDetail inv;
  final bool         isOdd;
  final VoidCallback onTap;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final inv   = widget.inv;
    final color = _statusColor(inv.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hov
                ? _kNavy.withValues(alpha: 0.04)
                : widget.isOdd ? _kSurface.withValues(alpha: 0.5) : _kBg,
            border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.6))),
          ),
          child: Row(children: [
            // N° Facture
            Expanded(flex: 2, child: Text(
              inv.invoiceNumber,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy),
              overflow: TextOverflow.ellipsis,
            )),
            // Groupe
            Expanded(flex: 3, child: Text(
              inv.groupName,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kText),
              overflow: TextOverflow.ellipsis,
            )),
            // Plan
            Expanded(flex: 2, child: Text(
              inv.planName ?? '—',
              style: TextStyle(fontSize: 12, color: inv.planName != null ? _kText : _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Montant
            Expanded(flex: 2, child: Text(
              '${_money(inv.amountXaf)} F',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kText),
              overflow: TextOverflow.ellipsis,
            )),
            // Période
            Expanded(flex: 3, child: Text(
              _fmtPeriod(inv.periodStart, inv.periodEnd),
              style: TextStyle(fontSize: 11, color: _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Mode paiement
            Expanded(flex: 2, child: Row(children: [
              Icon(_methodIcon(inv.paymentMethod), size: 13, color: _kMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(
                _methodLabel(inv.paymentMethod),
                style: TextStyle(fontSize: 11, color: _kMuted),
                overflow: TextOverflow.ellipsis,
              )),
            ])),
            // Payée le
            Expanded(flex: 2, child: Text(
              _fmtDate(inv.paidAt),
              style: TextStyle(fontSize: 11, color: _kMuted),
              overflow: TextOverflow.ellipsis,
            )),
            // Statut
            SizedBox(width: 96, child: _StatusBadge(status: inv.status)),
            // Action
            SizedBox(width: 36, child: Tooltip(
              message: 'Voir la facture',
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Icon(Icons.open_in_new_rounded, size: 13, color: color),
              ),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Vue Cartes ───────────────────────────────────────────────────────────────
