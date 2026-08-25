import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_subscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Réabonnement (renouvellement du MÊME plan).
//
//  Avant, l'admin_groupe ne pouvait PAS se réabonner : le bouton du plan courant
//  était désactivé, et « Renouveler » ne faisait que le déposer sur une page où
//  la seule action possible était de demander un AUTRE plan.
//
//  Ici, il génère (ou récupère) une facture de renouvellement pour son plan
//  actuel via `create_renewal_invoice`. Le paiement reste hors-ligne, confirmé
//  par la plateforme (`mark_invoice_paid`) — cette fonction émet donc une
//  SOMME DUE, pas un encaissement.
// ════════════════════════════════════════════════════════════════════════════

Future<void> showRenewSubscriptionDialog(
  BuildContext context,
  GroupSubscription sub,
) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _RenewSubscriptionDialog(sub: sub),
  );
}

class _RenewSubscriptionDialog extends ConsumerStatefulWidget {
  const _RenewSubscriptionDialog({required this.sub});
  final GroupSubscription sub;

  @override
  ConsumerState<_RenewSubscriptionDialog> createState() =>
      _RenewSubscriptionDialogState();
}

class _RenewSubscriptionDialogState
    extends ConsumerState<_RenewSubscriptionDialog> {
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _result; // succès → on bascule sur l'écran de confirmation

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(adminSubscriptionServiceProvider).requestRenewal();
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _humanError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _humanError(String raw) {
    if (raw.contains('Aucun plan')) {
      return "Aucun plan n'est attribué à votre groupe. Contactez la plateforme.";
    }
    if (raw.contains('Accès refusé')) {
      return "Vous n'êtes pas autorisé à effectuer cette action.";
    }
    return 'Une erreur est survenue. Réessayez ou contactez la plateforme.';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _result != null ? _successView() : _confirmView(),
        ),
      ),
    );
  }

  // ── Écran 1 : confirmation ──────────────────────────────────────────────────
  Widget _confirmView() {
    final s = widget.sub;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.autorenew_rounded, color: kNavy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Renouveler mon abonnement',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
        ]),
        const SizedBox(height: 18),
        _row('Plan', s.planName),
        _row('Montant', s.priceXaf == 0 ? 'Gratuit' : '${fmtXaf(s.priceXaf)} / an'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.priceXaf == 0
                    ? 'Votre plan est gratuit : le renouvellement est immédiat.'
                    : 'Une facture de renouvellement sera générée. Réglez-la '
                        'auprès de la plateforme — votre abonnement sera '
                        'réactivé dès confirmation du paiement.',
                style: TextStyle(
                    fontSize: 12.5, color: kTextMuted, height: 1.45),
              ),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AdminErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextMuted,
                side: BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _confirm,
              icon: _saving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 17),
              label: Text(_saving ? 'Traitement…' : 'Confirmer'),
              style: FilledButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Écran 2 : confirmation de la facture générée ────────────────────────────
  Widget _successView() {
    final r = _result!;
    final free = r['free'] == true;
    final already = r['already_pending'] == true;
    final amount = (r['amount_xaf'] as num?)?.toInt() ?? widget.sub.priceXaf;
    final invNo = r['invoice_number'] as String?;

    final title = free
        ? 'Abonnement renouvelé'
        : (already ? 'Facture déjà en attente' : 'Facture de renouvellement générée');
    final body = free
        ? 'Votre plan gratuit a été prolongé d\'un an.'
        : (already
            ? 'Une facture de renouvellement était déjà en attente de paiement. '
                'Réglez-la auprès de la plateforme pour réactiver votre abonnement.'
            : 'Réglez ce montant auprès de la plateforme. Votre abonnement sera '
                'réactivé dès confirmation du paiement.');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(free ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                color: kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
        ]),
        const SizedBox(height: 16),
        if (!free) ...[
          if (invNo != null) _row('Facture', invNo),
          _row('Montant dû', fmtXaf(amount)),
          const SizedBox(height: 12),
        ],
        Text(body,
            style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Compris'),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ),
        ]),
      );
}
