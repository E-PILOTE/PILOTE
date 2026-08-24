import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../services/rapport_effectifs.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BRIQUES DE LA PAGE RAPPORTS
//
//  Une carte par état. Elle annonce ce que le document CONTIENT et ce qu'il
//  EXCLUT avant d'en proposer l'aperçu : c'est la seule occasion de le dire.
//  Un état signé et transmis ne porte plus aucune trace de ce qu'on a choisi
//  d'en retirer.
// ════════════════════════════════════════════════════════════════════════════

/// Réexporté pour que l'écran n'importe pas le service de comptage rien que
/// pour un libellé.
const String kSansClasseLibelle = kSansClasse;

class RapportsEntete extends StatelessWidget {
  const RapportsEntete({super.key, this.annee});
  final String? annee;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_rounded, color: kNavy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('États de l\'établissement',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(
                  annee == null
                      ? 'Documents officiels, arrêtés à la date d\'édition.'
                      : 'Année $annee — documents officiels, arrêtés à la date '
                          'd\'édition.',
                  style: TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
              ],
            ),
          ),
        ],
      );
}

class RapportCard extends StatelessWidget {
  const RapportCard({
    super.key,
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.contient,
    required this.exclut,
    required this.pret,
    required this.messageVide,
    this.resume,
    this.alerte,
    this.onApercu,
  });

  final IconData icone;
  final Color couleur;
  final String titre;

  /// Ce que le document contient, en clair — pas des noms de colonnes.
  final List<String> contient;

  /// Ce qu'il laisse dehors. ⚠️ Jamais facultatif : une exclusion tue un
  /// document officiel quand on l'apprend après signature.
  final String exclut;

  /// Une anomalie à corriger AVANT transmission, ou `null`.
  final String? alerte;

  final String? resume;
  final bool pret;
  final String messageVide;
  final VoidCallback? onApercu;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: couleur, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      if (resume != null) ...[
                        const SizedBox(height: 2),
                        Text(resume!,
                            style:
                                TextStyle(fontSize: 12.5, color: kTextMuted)),
                      ],
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: pret ? onApercu : null,
                  style: FilledButton.styleFrom(backgroundColor: couleur),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                  label: const Text('Aperçu'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final c in contient)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.check_rounded, size: 14, color: kGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c,
                          style:
                              TextStyle(fontSize: 12.5, color: kTextPrimary)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            _Mention(
              icone: Icons.remove_circle_outline_rounded,
              couleur: kTextMuted,
              texte: 'Non inclus : $exclut',
            ),
            if (alerte != null) ...[
              const SizedBox(height: 8),
              _Mention(
                icone: Icons.warning_amber_rounded,
                couleur: kAccent,
                texte: alerte!,
                encadre: true,
              ),
            ],
            if (!pret) ...[
              const SizedBox(height: 8),
              _Mention(
                icone: Icons.hourglass_empty_rounded,
                couleur: kTextMuted,
                texte: messageVide,
              ),
            ],
          ],
        ),
      );
}

class _Mention extends StatelessWidget {
  const _Mention({
    required this.icone,
    required this.couleur,
    required this.texte,
    this.encadre = false,
  });
  final IconData icone;
  final Color couleur;
  final String texte;
  final bool encadre;

  @override
  Widget build(BuildContext context) {
    final ligne = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icone, size: 14, color: couleur),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texte,
              style: TextStyle(
                  fontSize: 12,
                  color: encadre ? kTextPrimary : kTextMuted,
                  height: 1.35)),
        ),
      ],
    );
    if (!encadre) return ligne;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: couleur.withValues(alpha: .35)),
      ),
      child: ligne,
    );
  }
}
