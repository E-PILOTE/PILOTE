import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_ui.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CHROME DES MODALES D'ÉCONOMIE — en-tête, sous-titre, pied, pastille
//
//  ⚠️ SORTI DE `part` LE JOUR OÙ LE FORMULAIRE DE LICENCE A DÛ S'OUVRIR
//  DEPUIS DEUX ÉCRANS. Le fondateur a activé une licence puis est allé la voir
//  sur la page où il gère les abonnements — elle n'y était pas : le contrat
//  vivait dans « Économie », un autre écran qu'il faut savoir chercher.
//  « La création et l'affectation de la licence devrait être simple comme pour
//  les mensuelles. »
//
//  Pour que le MÊME formulaire s'ouvre depuis Abonnements et depuis Économie,
//  il fallait qu'il cesse d'être un `part` d'un seul écran. Ces quatre pièces
//  le suivent — dupliquer un en-tête de modale aurait été le premier pas vers
//  deux modales qui divergent.
// ════════════════════════════════════════════════════════════════════════════

class EnteteDialog extends StatelessWidget {
  const EnteteDialog({
    super.key,
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onFermer,
  });

  final IconData icone;
  final String titre, sousTitre;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          Icon(icone, size: 21, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(sousTitre,
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ]),
          ),
          IconButton(
              onPressed: onFermer,
              icon: const Icon(Icons.close_rounded, size: 19)),
        ]),
      );
}

class SousTitreDialog extends StatelessWidget {
  const SousTitreDialog(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: kTextMuted));
}

class PiedDialog extends StatelessWidget {
  const PiedDialog({
    super.key,
    required this.saving,
    required this.onAnnuler,
    required this.onEnregistrer,
    this.onSupprimer,
  });

  final bool saving;
  final VoidCallback onAnnuler;
  final VoidCallback? onEnregistrer, onSupprimer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        decoration:
            BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
        child: Row(children: [
          if (onSupprimer != null)
            TextButton.icon(
              onPressed: saving ? null : onSupprimer,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444)),
            ),
          const Spacer(),
          TextButton(
              onPressed: saving ? null : onAnnuler,
              child: const Text('Annuler')),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: saving ? null : onEnregistrer,
            icon: saving
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Enregistrer'),
          ),
        ]),
      );
}

class PuceEconomie extends StatelessWidget {
  const PuceEconomie({
    super.key,required this.texte, required this.couleur});
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(texte,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: couleur)),
      );
}
