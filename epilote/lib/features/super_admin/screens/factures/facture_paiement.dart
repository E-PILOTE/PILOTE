part of '../invoices_screen.dart';

// Confirmation d’un paiement.

class _PaymentConfirmDialog extends StatefulWidget {
  const _PaymentConfirmDialog({required this.invoice});
  final InvoiceDetail invoice;

  @override
  State<_PaymentConfirmDialog> createState() => _PaymentConfirmDialogState();
}

class _PaymentConfirmDialogState extends State<_PaymentConfirmDialog> {
  String _method = 'especes';
  final _refCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const _methods = {
    'especes':     ('Espèces',      Icons.payments_rounded),
    'mtn_money':   ('MTN Money',    Icons.phone_android_rounded),
    'airtel_money':('Airtel Money', Icons.phone_android_rounded),
    'visa':        ('Visa / Carte', Icons.credit_card_rounded),
  };

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kNavy, const Color(0xFF2A4F7A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Confirmer le paiement',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${inv.groupName} — ${inv.invoiceNumber}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Montant
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.monetization_on_rounded, color: _kGreen, size: 20),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Montant à encaisser',
                            style: TextStyle(fontSize: 11, color: _kMuted)),
                        Text('${_money(inv.amountXaf)} XAF',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kGreen)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Méthode de paiement
                  Text('Mode de paiement',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _methods.entries.map((e) {
                      final sel = _method == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _method = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? _kNavy : kCardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? _kNavy : _kBorder,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(e.value.$2, size: 14,
                                color: sel ? Colors.white : _kMuted),
                            const SizedBox(width: 6),
                            Text(e.value.$1,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _kText,
                                )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Référence
                  Text('Référence de paiement (optionnel)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _refCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ex: TXN-0045678, reçu papier n°…',
                      hintStyle: TextStyle(fontSize: 12, color: _kMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy)),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  Text('Notes internes (optionnel)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Observations…',
                      hintStyle: TextStyle(fontSize: 12, color: _kMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy)),
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avertissement
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Cette action activera le groupe scolaire et rendra ses modules accessibles.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kMuted,
                          side: BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, {
                          'method': _method,
                          'ref':    _refCtrl.text,
                          'notes':  _notesCtrl.text,
                        }),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Confirmer le paiement',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
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
