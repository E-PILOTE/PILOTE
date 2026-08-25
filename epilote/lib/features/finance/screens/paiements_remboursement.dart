import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/paiements_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REMBOURSER UN ENCAISSEMENT
//
//  `payment_status` portait déjà la valeur `refunded`, mais rien ne disait
//  COMBIEN avait été rendu, quand, par qui, ni pourquoi : un remboursement
//  partiel était inexprimable. La migration 0094 a ajouté les colonnes ; cette
//  boîte les remplit.
//
//  ⚠️ Fichier séparé, et la boîte POSSÈDE son contrôleur.
//  `await showDialog` rend la main au `Navigator.pop`, PAS à la fin de
//  l'animation de sortie : libérer le contrôleur depuis l'appelant le détruit
//  pendant que le champ en dépend encore, et l'écran vire au rouge sur
//  « _dependents.isEmpty is not true ». Constaté à l'écran au lot 0.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que l'utilisateur a saisi : montant rendu et motif.
typedef SaisieRemboursement = ({int montant, String motif});

class RemboursementDialog extends StatefulWidget {
  const RemboursementDialog({
    super.key,
    required this.encaisse,
    required this.date,
  });

  /// Montant confirmé de l'encaissement : plafond du remboursement.
  final int encaisse;
  final String? date;

  @override
  State<RemboursementDialog> createState() => _RemboursementDialogState();
}

class _RemboursementDialogState extends State<RemboursementDialog> {
  late final TextEditingController _montant =
      TextEditingController(text: '${widget.encaisse}');
  final _motif = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _montant.dispose();
    _motif.dispose();
    super.dispose();
  }

  void _valider() {
    final montant = int.tryParse(_montant.text.trim().replaceAll(' ', ''));
    if (montant == null) {
      setState(() => _erreur = 'Montant illisible');
      return;
    }
    final probleme = montantRemboursementInvalide(montant, widget.encaisse);
    if (probleme != null) {
      setState(() => _erreur = probleme);
      return;
    }
    if (_motif.text.trim().isEmpty) {
      setState(() => _erreur = 'Le motif du remboursement est obligatoire');
      return;
    }
    Navigator.pop<SaisieRemboursement>(
        context, (montant: montant, motif: _motif.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Rembourser cet encaissement ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Encaissé le ${widget.date ?? '—'} : ${fmtXaf(widget.encaisse)}. '
            'Un remboursement partiel est possible.',
            style: TextStyle(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _montant,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: adminFilledInput('Montant remboursé (FCFA)',
                icon: Icons.payments_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motif,
            maxLines: 2,
            decoration: adminFilledInput('Motif du remboursement',
                icon: Icons.edit_note_rounded),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 10),
            Text(_erreur!,
                style: TextStyle(
                    fontSize: 12, color: kRed, fontWeight: FontWeight.w600)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Renoncer')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: _valider,
            child: const Text('Rembourser'),
          ),
        ],
      );
}
