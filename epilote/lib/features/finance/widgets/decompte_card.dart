import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/decompte_du_provider.dart';
import '../services/obligation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉCOMPTE, AU GUICHET
//
//  ── CE QUE CETTE CARTE RÉPARE ──────────────────────────────────────────────
//  La fiche de paiement d'un élève affichait « Total réglé : 20 000 F » et
//  l'historique des versements. Rien sur ce qu'il DOIT. Le caissier voyait donc
//  ce qui était entré et jamais ce qui manquait — et quand un parent demandait
//  « je dois combien ? », la seule réponse disponible était un solde global
//  qu'aucune ligne ne justifiait.
//
//  Depuis que trois mécanismes agissent sur le montant — la fenêtre de présence
//  (0107/lot A), les frais annexes multiples (0108), l'exonération (0109) —
//  un total opaque est devenu indéfendable : trois élèves d'une même classe
//  peuvent devoir trois sommes différentes, toutes justes.
//
//  ⚠️ La carte ne décide de rien. Elle affiche `DecompteDu`, qui décompose ce
//  que `duScolarite` totalise, avec les mêmes règles et les mêmes exclusions.
// ════════════════════════════════════════════════════════════════════════════

class DecompteCard extends ConsumerWidget {
  const DecompteCard({super.key, required this.enrollmentId});

  final String enrollmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(decompteDuProvider(enrollmentId));
    final d = async.valueOrNull;

    // Tant que le décompte charge, on n'affiche rien plutôt qu'un « 0 F dû »
    // qui se lirait « rien à payer ».
    if (d == null) return const SizedBox.shrink();

    if (d.vide) {
      return _Cadre(
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 17, color: kTextMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              // Trente écoles publiques du réseau n'ont aucun tarif posé.
              // Afficher « 0 F dû » leur ferait annoncer la gratuité.
              'Aucun barème ne s\'applique à cet élève : on ne peut rien '
              'affirmer sur ce qu\'il doit.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: kTextMuted),
            ),
          ),
        ]),
      );
    }

    final couleur = _couleur(d.etat);
    return _Cadre(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_outlined, size: 17, color: kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Ce que doit cet élève',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
          ),
          AdminBadge(libelleEtat(d.etat), color: couleur),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Chiffre(label: 'Dû', valeur: d.net, couleur: kTextPrimary),
          _Chiffre(label: 'Versé', valeur: d.verse, couleur: kGreen),
          _Chiffre(
              label: 'Reste',
              valeur: d.reste,
              couleur: d.reste > 0 ? kRed : kGreen),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
        for (final l in d.lignes) _LigneDecompte(d: d, ligne: l),
        if (d.verseLibre > 0) ...[
          const SizedBox(height: 6),
          // Un versement dont le barème a été retiré, ou saisi en « Autre /
          // libre ». Il compte dans le total encaissé ; le taire donnerait un
          // versé supérieur à la somme des lignes, sans explication.
          Text(
            'Dont ${fmtXaf(d.verseLibre)} encaissés hors décompte '
            '(versement libre ou barème retiré).',
            style: TextStyle(
                fontSize: 11.5, fontStyle: FontStyle.italic, color: kTextMuted),
          ),
        ],
        if (d.estExonere)
          _Bandeau(
            icone: Icons.volunteer_activism_outlined,
            couleur: kGreen,
            texte: 'Exonération de ${d.exoneration} % sur la scolarité '
                '(−${fmtXaf(d.remise)})'
                '${(d.motifExoneration ?? '').trim().isEmpty ? '' : ' · ${d.motifExoneration!.trim()}'}',
          )
        else if (d.boursierSansTaux)
          // ⚠️ C'est ICI que le silence coûte le plus cher : le caissier est
          // sur le point de réclamer le plein tarif à une famille qui a obtenu
          // une bourse. On le dit, et on désigne où la régulariser — sans
          // jamais deviner de taux.
          _Bandeau(
            icone: Icons.error_outline_rounded,
            couleur: kAccent,
            texte: 'Élève déclaré BOURSIER, mais aucun taux d\'exonération '
                'n\'est saisi : le montant ci-dessus est celui de la scolarité '
                'entière. À régulariser depuis son dossier d\'inscription '
                'avant d\'encaisser.',
          ),
        if (d.mois > 0 &&
            d.lignes.any((l) => l.feeType == 'mensualite')) ...[
          const SizedBox(height: 8),
          // Sans cette phrase, un parent arrivé en mars voit une scolarité
          // deux fois moindre que celle de son voisin et croit à une erreur.
          Text(
            'La scolarité est comptée sur ${d.mois} mois de présence.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ],
      ]),
    );
  }

  /// L'ambre de l'avance partielle est délibéré : ni le vert du soldé, ni le
  /// rouge de l'impayé. Un parent qui a versé la moitié n'est pas un mauvais
  /// payeur, et l'écran ne doit pas le désigner comme tel.
  Color _couleur(EtatObligation e) => switch (e) {
        EtatObligation.aJour => kGreen,
        EtatObligation.exonere => kGreen,
        EtatObligation.partiel => const Color(0xFFF59E0B),
        EtatObligation.impaye => kRed,
        EtatObligation.sansBareme => kTextMuted,
      };
}

class _Cadre extends StatelessWidget {
  const _Cadre({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: child,
      );
}

class _Bandeau extends StatelessWidget {
  const _Bandeau(
      {required this.icone, required this.couleur, required this.texte});
  final IconData icone;
  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: couleur.withValues(alpha: 0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icone, size: 15, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.4, color: kTextPrimary)),
            ),
          ]),
        ),
      );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(
      {required this.label, required this.valeur, required this.couleur});
  final String label;
  final int valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: kTextMuted)),
          const SizedBox(height: 2),
          Text(fmtXaf(valeur),
              style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800, color: couleur)),
        ]),
      );
}

class _LigneDecompte extends StatelessWidget {
  const _LigneDecompte({required this.d, required this.ligne});
  final DecompteDu d;
  final LigneDu ligne;

  @override
  Widget build(BuildContext context) {
    final du = d.duDe(ligne);
    final reste = d.resteDe(ligne);
    final solde = reste == 0;
    final remise = ligne.montant - du;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            solde
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: solde ? kGreen : kTextMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                ligne.feeType == 'mensualite' && d.mois > 1
                    ? '${ligne.libelle} (${d.mois} mois)'
                    : ligne.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            if (remise > 0)
              Text('tarif ${fmtXaf(ligne.montant)} · remise ${fmtXaf(remise)}',
                  style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtXaf(du),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          Text(
              solde
                  ? 'réglé'
                  : ligne.verse > 0
                      ? 'reste ${fmtXaf(reste)}'
                      : 'non réglé',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: solde ? kGreen : const Color(0xFFF59E0B))),
        ]),
      ]),
    );
  }
}
