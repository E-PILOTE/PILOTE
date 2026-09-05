import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';

/// Une ligne de la carte « Sécurité » : icône, titre, explication, action.
///
/// Partagée par le mot de passe, la dernière connexion et le code PIN. Ces
/// trois lignes doivent se ressembler au pixel près : ce sont les seuls
/// endroits du produit où l'on répond à « comment je prouve que c'est moi », et
/// une différence de gabarit entre elles se lirait comme une différence de
/// nature.
class LigneSecurite extends StatelessWidget {
  const LigneSecurite({
    super.key,
    required this.icone,
    required this.titre,
    required this.detail,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: kNavy, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(detail,
                style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.35)),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ]);
}

/// Bouton d'action d'une ligne de sécurité — même gabarit partout.
class BoutonSecurite extends StatelessWidget {
  const BoutonSecurite({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onPressed,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icone, size: 16),
        label: Text(libelle),
        style: OutlinedButton.styleFrom(
          foregroundColor: kNavy,
          side: BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      );
}
