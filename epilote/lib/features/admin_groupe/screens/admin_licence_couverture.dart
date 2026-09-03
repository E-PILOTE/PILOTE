import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../providers/admin_licence_provider.dart';
import '../providers/admin_subscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE LA LICENCE ACHÈTE — et ce qu'elle coûte par établissement
//
//  ── LE MANQUE ─────────────────────────────────────────────────────────────
//  La carte de licence dit ce qu'on PAIE. Elle ne disait rien de ce qu'on
//  ACHÈTE. Sur un marché à quarante millions, c'est la moitié manquante : un
//  ordonnateur qui rouvre le dossier six mois plus tard veut retrouver, sur la
//  même page, la contrepartie — combien d'établissements sont supervisés,
//  combien d'élèves, et ce que la plateforme ouvre en propre au ministère.
//
//  ── ⚠️ LE SEUL CHIFFRE QUI SE DÉFEND EN RÉUNION ───────────────────────────
//  Ce n'est pas le montant : c'est le montant DIVISÉ. « Quarante millions »
//  s'attaque tout seul ; « 1 600 000 F par établissement et par an », ou
//  « 3 200 F par élève », se compare — à un manuel scolaire, à une tournée
//  d'inspection, à un logiciel concurrent. C'est le chiffre que le ministère
//  devra citer pour défendre la ligne budgétaire, et il n'existait nulle part.
//
//  ── ⚠️ CE QUE LE RÉSEAU COMPTE, ET CE QU'IL NE COMPTE PAS ─────────────────
//  `reseauSuperviseProvider` retire du périmètre les écoles que le ministère
//  exploite LUI-MÊME : superviser son propre établissement n'est pas de la
//  tutelle. On additionne donc les deux explicitement, et on le DIT — un
//  ministère qui ne retrouve pas ses douze écoles dans le total croirait à
//  une panne plutôt qu'à un périmètre.
//
//  ── CHARGEMENT SÉPARÉ, DÉLIBÉRÉMENT ───────────────────────────────────────
//  Le réseau est le chargement le plus lourd de l'espace groupe (deux RPC qui
//  agrègent les effectifs école par école, plus de mille à la cible). Il a
//  donc son propre `.when` : le contrat s'affiche tout de suite, la couverture
//  arrive après. L'inverse — faire attendre le montant du marché derrière un
//  décompte d'élèves — serait absurde.
// ════════════════════════════════════════════════════════════════════════════

class LicenceCouvertureSection extends ConsumerWidget {
  const LicenceCouvertureSection({super.key, required this.sub});

  final GroupSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licences = ref.watch(licencesDuGroupeProvider).valueOrNull;
    final licence = licences == null ? null : licenceAMontrer(licences);
    final reseau = ref.watch(reseauSuperviseProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      reseau.when(
        loading: () => const _ReseauEnAttente(),
        // ⚠️ On DIT l'échec plutôt que d'afficher « 0 établissement ». Un zéro
        // faux sur cette page finit recopié dans un état ministériel.
        error: (e, _) => AdminErrorBanner(message: '$e'),
        data: (r) => _Couverture(sub: sub, reseau: r, licence: licence),
      ),
      if (licences != null && licences.length > 1) ...[
        const SizedBox(height: 20),
        const AdminSectionTitle('Licences précédentes',
            icon: Icons.history_rounded,
            subtitle: 'Les marchés antérieurs restent consultables'),
        const SizedBox(height: 12),
        _Historique(licences: licences),
      ],
    ]);
  }
}

class _Couverture extends StatelessWidget {
  const _Couverture(
      {required this.sub, required this.reseau, required this.licence});

  final GroupSubscription sub;
  final ReseauSupervise reseau;
  final LicenceDuGroupe? licence;

  @override
  Widget build(BuildContext context) {
    final ecolesSupervisees = reseau.ecoles.length;
    final ecolesTotal = ecolesSupervisees + reseau.nbEcolesPropres;
    final eleves = reseau.ecoles.fold<int>(0, (s, e) => s + e.nbEleves) +
        sub.studentsUsed;
    final personnel =
        reseau.ecoles.fold<int>(0, (s, e) => s + e.nbPersonnel) + sub.staffUsed;

    final parEcole = licence?.coutAnnuelParEtablissement(ecolesTotal);
    final parEleve = licence?.coutAnnuelParEleve(eleves);

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.hub_rounded, size: 18, color: kNavy),
          const SizedBox(width: 8),
          Text('Ce que couvre votre licence',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 28, runSpacing: 14, children: [
          _Chiffre(
              icone: Icons.account_tree_rounded,
              valeur: '${reseau.groupes.length}',
              label: 'groupes supervisés',
              couleur: kNavy),
          _Chiffre(
              icone: Icons.school_rounded,
              valeur: '$ecolesTotal',
              label: reseau.nbEcolesPropres > 0
                  ? 'établissements · dont ${reseau.nbEcolesPropres} en propre'
                  : 'établissements',
              couleur: kGreen),
          _Chiffre(
              icone: Icons.groups_rounded,
              valeur: fmtInt(eleves),
              label: 'élèves',
              couleur: kAccent),
          _Chiffre(
              icone: Icons.badge_rounded,
              valeur: fmtInt(personnel),
              label: 'personnels',
              couleur: const Color(0xFF7C3AED)),
          _Chiffre(
              icone: Icons.extension_rounded,
              valeur: '${sub.moduleCount}',
              label: 'modules ouverts',
              couleur: kNavy),
        ]),
        if (parEcole != null || parEleve != null) ...[
          const SizedBox(height: 18),
          Divider(color: kBorder, height: 1),
          const SizedBox(height: 14),
          Text('CE QUE ÇA REPRÉSENTE',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kTextMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 26, runSpacing: 10, children: [
            if (parEcole != null)
              _Ratio(
                  valeur: fmtXaf(parEcole),
                  label: 'par établissement et par an'),
            if (parEleve != null)
              _Ratio(valeur: fmtXaf(parEleve), label: 'par élève et par an'),
          ]),
        ],
        const SizedBox(height: 16),
        const _DroitsDeTutelle(),
      ]),
    );
  }
}

/// Ce que la licence ouvre en propre, au-delà des chiffres. Écrit en toutes
/// lettres parce que c'est l'objet du marché : ce sont ces quatre droits que
/// la plateforme vend, et aucun écran ne les listait.
class _DroitsDeTutelle extends StatelessWidget {
  const _DroitsDeTutelle();

  static const _droits = <(IconData, String, String)>[
    (
      Icons.verified_rounded,
      'Référentiel national des examens',
      'Vous seul écrivez les examens, sessions et barèmes de votre tutelle. '
          'Les autres groupes les lisent.'
    ),
    (
      Icons.hub_rounded,
      'Vue sur tout votre réseau',
      'Effectifs, résultats et couverture des établissements que vous '
          'supervisez, publics comme privés.'
    ),
    (
      Icons.campaign_rounded,
      'Circulaires à votre réseau',
      'Une note descend jusqu’au poste de direction et se lit hors ligne ; '
          'l’accusé de lecture remonte.'
    ),
    (
      Icons.workspace_premium_rounded,
      'Aucun quota, aucune échéance',
      'Écoles, élèves et personnels illimités. Aucun terme d’abonnement ne '
          'suspend un ministère.'
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icone, titre, texte) in _droits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icone, size: 15, color: kGreen),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary)),
                        Text(texte,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: kTextMuted,
                                height: 1.4)),
                      ]),
                ),
              ]),
            ),
        ],
      );
}

// ─── Historique ─────────────────────────────────────────────────────────────
class _Historique extends StatelessWidget {
  const _Historique({required this.licences});

  final List<LicenceDuGroupe> licences;

  @override
  Widget build(BuildContext context) {
    final courante = licenceAMontrer(licences);
    final autres = [
      for (final l in licences)
        if (!identical(l, courante)) l,
    ];
    return Column(
      children: [
        for (final l in autres)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                AdminBadge(l.statutLabel,
                    color: couleurStatutLicence(l.statut)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.intitule,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary)),
                        Text(
                            '${_annee(l.dateDebut)} → ${_annee(l.dateFin)}'
                            '${l.referenceMarche == null ? '' : ' · ${l.referenceMarche}'}',
                            style:
                                TextStyle(fontSize: 11, color: kTextMuted)),
                      ]),
                ),
                const SizedBox(width: 12),
                Text(fmtXaf(l.montantXaf),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ─── Pièces ─────────────────────────────────────────────────────────────────
class _ReseauEnAttente extends StatelessWidget {
  const _ReseauEnAttente();

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
          const SizedBox(width: 10),
          Text('Décompte de votre réseau…',
              style: TextStyle(fontSize: 12.5, color: kTextMuted)),
        ]),
      );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(
      {required this.icone,
      required this.valeur,
      required this.label,
      required this.couleur});

  final IconData icone;
  final String valeur, label;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 17, color: couleur),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valeur,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: kTextPrimary)),
              Text(label, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ],
          ),
        ],
      );
}

class _Ratio extends StatelessWidget {
  const _Ratio({required this.valeur, required this.label});

  final String valeur, label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valeur,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
        ],
      );
}

String _annee(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
