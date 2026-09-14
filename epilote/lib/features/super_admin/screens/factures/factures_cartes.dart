part of '../invoices_screen.dart';

// Vue cartes, badge de statut, état vide.

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.items, required this.onView});
  final List<InvoiceDetail> items;
  final ValueChanged<InvoiceDetail> onView;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14, crossAxisSpacing: 14,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _InvoiceCard(inv: items[i], onTap: () => onView(items[i])),
    );
  }
}

class _InvoiceCard extends StatefulWidget {
  const _InvoiceCard({required this.inv, required this.onTap});
  final InvoiceDetail inv;
  final VoidCallback  onTap;
  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov ? color.withValues(alpha: 0.4) : _kBorder,
            ),
            boxShadow: _hov
                ? [BoxShadow(color: color.withValues(alpha: 0.08),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(_statusIcon(inv.status), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.invoiceNumber, style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800, color: _kNavy),
                    overflow: TextOverflow.ellipsis),
                Text(inv.groupName, style: TextStyle(
                    fontSize: 11.5, color: _kMuted),
                    overflow: TextOverflow.ellipsis),
              ])),
              _StatusBadge(status: inv.status),
            ]),
            const SizedBox(height: 10),
            Text('${_money(inv.amountXaf)} XAF', style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 4),
            Text(inv.planName ?? 'Sans plan', style: TextStyle(
                color: _kMuted, fontSize: 11.5)),
            const Spacer(),
            Row(children: [
              Icon(Icons.calendar_today_rounded, size: 11, color: _kMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(
                _fmtPeriod(inv.periodStart, inv.periodEnd),
                style: TextStyle(fontSize: 10.5, color: _kMuted),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
            if (inv.paidAt != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.check_circle_outline_rounded, size: 11, color: _kGreen),
                const SizedBox(width: 4),
                Text('Payée le ${_fmtDate(inv.paidAt)}',
                    style: TextStyle(fontSize: 10.5, color: _kGreen)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 11, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(_statusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.description_rounded, size: 56, color: _kBorder),
      const SizedBox(height: 16),
      Text('Aucune facture trouvée', style: TextStyle(
          color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Modifiez vos filtres pour voir plus de résultats.',
          style: TextStyle(color: _kMuted, fontSize: 13)),
    ]),
  );
}

// ─── Modal Détail Facture ─────────────────────────────────────────────────────
