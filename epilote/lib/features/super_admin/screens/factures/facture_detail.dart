part of '../invoices_screen.dart';

// Fiche détaillée d’une facture.

class _InvoiceDetailModal extends StatelessWidget {
  const _InvoiceDetailModal({
    required this.invoice,
    required this.onMarkPaid,
    required this.onCancel,
    required this.onReopen,
  });

  final InvoiceDetail invoice;
  final VoidCallback  onMarkPaid;
  final VoidCallback  onCancel;
  final VoidCallback  onReopen;

  @override
  Widget build(BuildContext context) {
    final inv   = invoice;
    final color = _statusColor(inv.status);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Icon(_statusIcon(inv.status), color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.invoiceNumber, style: TextStyle(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(inv.groupName, style: TextStyle(
                    color: _kMuted, fontSize: 13)),
              ])),
              _StatusBadge(status: inv.status),
              const SizedBox(width: 10),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _kSurface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
                  ),
                ),
              ),
            ]),
          ),

          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Montant
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_money(inv.amountXaf)} XAF', style: TextStyle(
                          color: color, fontSize: 28,
                          fontWeight: FontWeight.w900, letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text(inv.planName ?? 'Sans plan',
                          style: TextStyle(color: _kMuted, fontSize: 13)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Émise le', style: TextStyle(color: _kMuted, fontSize: 11)),
                      Text(_fmtDate(inv.createdAt), style: TextStyle(
                          color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
                // Détails
                _DetailSection('Période de facturation', [
                  _DetailRow(Icons.calendar_today_rounded, 'Début de période', _fmtDate(inv.periodStart)),
                  _DetailRow(Icons.event_rounded, 'Fin de période', _fmtDate(inv.periodEnd)),
                ]),
                const SizedBox(height: 16),
                _DetailSection('Paiement', [
                  _DetailRow(Icons.payment_rounded, 'Mode de paiement', _methodLabel(inv.paymentMethod)),
                  _DetailRow(Icons.receipt_rounded, 'Référence', inv.paymentReference ?? '—'),
                  _DetailRow(Icons.check_circle_rounded, 'Payée le', _fmtDate(inv.paidAt)),
                ]),
                if (inv.notes != null) ...[
                  const SizedBox(height: 16),
                  _DetailSection('Notes', [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                      child: Text(inv.notes!, style: TextStyle(
                          color: _kMuted, fontSize: 13)),
                    ),
                  ]),
                ],
              ]),
            ),
          ),

          // Actions footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Actions document officiel
              _IconBtn(
                icon: Icons.copy_rounded,
                tooltip: 'Copier le N°',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inv.invoiceNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Numéro copié'),
                        behavior: SnackBarBehavior.floating));
                },
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.print_rounded,
                tooltip: 'Imprimer',
                onTap: () => InvoicePdfService.printInvoice(inv),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.share_rounded,
                tooltip: 'Partager',
                onTap: () => InvoicePdfService.shareInvoice(inv),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.picture_as_pdf_rounded,
                tooltip: 'Télécharger PDF',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final path = await InvoicePdfService.downloadInvoice(inv);
                  messenger.showSnackBar(SnackBar(
                    content: Text(path != null
                        ? 'Facture enregistrée : $path'
                        : 'Échec de l\'enregistrement du PDF'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: path != null ? _kGreen : _kRed,
                  ));
                },
              ),
              const Spacer(),
              if (inv.isPending || inv.isOverdue) ...[
                // Annuler
                _FooterBtn(
                  icon: Icons.cancel_rounded,
                  label: 'Annuler',
                  color: _kRed,
                  onTap: onCancel,
                ),
                const SizedBox(width: 10),
                // Marquer payée
                _FooterBtn(
                  icon: Icons.check_circle_rounded,
                  label: 'Marquer payée',
                  color: _kGreen,
                  filled: true,
                  onTap: onMarkPaid,
                ),
              ] else if (inv.isCancelled)
                _FooterBtn(
                  icon: Icons.restore_rounded,
                  label: 'Remettre en attente',
                  color: _kNavy,
                  onTap: onReopen,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title.toUpperCase(), style: TextStyle(
        color: _kMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: children),
    ),
  ]);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String   label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(color: _kMuted, fontSize: 12.5))),
      Text(value, style: TextStyle(
          color: _kText, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _FooterBtn extends StatelessWidget {
  const _FooterBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });
  final IconData     icon;
  final String       label;
  final Color        color;
  final bool         filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:  filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.25)),
          boxShadow: filled ? [BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

// ─── Dialogue confirmation paiement ──────────────────────────────────────────
