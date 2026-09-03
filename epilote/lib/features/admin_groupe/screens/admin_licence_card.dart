import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tutelle.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/badge_ministere.dart';
import '../providers/admin_licence_provider.dart';
import '../providers/admin_subscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CARTE DE LICENCE — CE QU'UN MINISTÈRE VOIT À LA PLACE D'UN ABONNEMENT
//
//  ── LE DÉFAUT MESURÉ ──────────────────────────────────────────────────────
//  Après 0182, la page Abonnement d'un ministère affichait :
//      « Plan Licence de tutelle · Actif · Gratuit
//        Début : 01/01/2026 — Échéance : — »
//  Soit, pour le ministère de l'Éducation nationale : la mention « Gratuit »,
//  aucun montant, aucun terme, et juste en dessous une grille de six offres
//  mensuelles avec un bouton « Demander ce plan ». Trois de ces offres, la
//  base les refuse désormais (0182). La quatrième, « Renouveler mon
//  abonnement », est refusée depuis 0183.
//
//  ── CE QUE CETTE CARTE MONTRE À LA PLACE ──────────────────────────────────
//  Le contrat réel, lu dans `tutelle_licences` : intitulé, référence de
//  marché, période NÉGOCIÉE, montant, avance, réglé, solde et signataire.
//  C'est ce que le ministère a signé ; il a le droit de le relire.
//
//  ── ⚠️ LA LIGNE QUI NE DOIT JAMAIS DISPARAÎTRE ────────────────────────────
//  « Votre accès ne dépend pas de cette licence. » Ce n'est pas une politesse,
//  c'est la contrainte C4 du 0160, et elle est vraie dans le code : une
//  licence échue ou impayée ne ferme rien, et 0183 garantit qu'un ministère
//  n'a pas d'échéance d'abonnement. Sans cette phrase, un solde affiché en
//  rouge se lit comme une menace de coupure — et c'est l'État qu'on menace.
// ════════════════════════════════════════════════════════════════════════════

class LicenceDeTutelleSection extends ConsumerWidget {
  const LicenceDeTutelleSection({super.key, required this.sub});

  final GroupSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = couleurTutelle(sub.tutelle);
    final async = ref.watch(licencesDuGroupeProvider);

    return AdminCard(
      accent: couleur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnTete(sub: sub, couleur: couleur),
          const SizedBox(height: 16),
          Divider(color: kBorder, height: 1),
          const SizedBox(height: 16),
          async.when(
            loading: () => const _Attente(),
            error: (e, _) => _Incident(erreur: e),
            data: (licences) {
              final l = licenceAMontrer(licences);
              return l == null
                  ? const _AucuneLicence()
                  : _Contrat(licence: l, couleur: couleur);
            },
          ),
          const SizedBox(height: 16),
          const _AccesNeDependPasDeLaLicence(),
        ],
      ),
    );
  }
}

// ─── En-tête : qui est ce groupe, et à quel titre ───────────────────────────
class _EnTete extends StatelessWidget {
  const _EnTete({required this.sub, required this.couleur});

  final GroupSubscription sub;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.account_balance_rounded, color: couleur, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                nomAffichableGroupe(
                  nom: sub.groupName,
                  estMinistere: true,
                  tutelle: sub.tutelle,
                ),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary),
              ),
              BadgeMinistere(estMinistere: true, tutelle: sub.tutelle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // ⚠️ Le mot juste : un ministère n'est pas « abonné ». Il commande
            // une licence nationale, et son terme est celui de son marché.
            'Licence de tutelle — ${nomTutelle(sub.tutelle) ?? sub.groupName}',
            style: TextStyle(
                fontSize: 13, color: kTextMuted, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    ]);
  }
}

// ─── Le contrat ─────────────────────────────────────────────────────────────
class _Contrat extends StatelessWidget {
  const _Contrat({required this.licence, required this.couleur});

  final LicenceDuGroupe licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(l.intitule,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
        AdminBadge(l.statutLabel,
            color: couleurStatutLicence(l.statut), icon: Icons.circle),
        if (l.referenceMarche != null && l.referenceMarche!.trim().isNotEmpty)
          AdminBadge('Marché ${l.referenceMarche}',
              color: kTextMuted, icon: Icons.gavel_rounded),
      ]),
      const SizedBox(height: 14),
      _Periode(licence: l),
      const SizedBox(height: 16),
      _Montants(licence: l, couleur: couleur),
      if (l.signataire != null && l.signataire!.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        _Ligne(
            icone: Icons.draw_rounded,
            label: 'Signataire',
            valeur: l.signataire!),
      ],
      if (l.notes != null && l.notes!.trim().isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(l.notes!.trim(),
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5)),
      ],
    ]);
  }
}

class _Periode extends StatelessWidget {
  const _Periode({required this.licence});

  final LicenceDuGroupe licence;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    final j = l.joursRestants;
    // ⚠️ Aucune de ces pastilles n'annonce une coupure : elles informent d'un
    // terme contractuel. « Échue » invite à un avenant, pas à un paiement pour
    // rouvrir un accès qui n'a jamais été fermé.
    final (String texte, Color couleur, IconData icone) = switch (j) {
      null => ('Terme inconnu', kTextMuted, Icons.help_outline_rounded),
      final n when n < 0 => (
          'Échue depuis ${-n} jour${-n > 1 ? 's' : ''}',
          kAccent,
          Icons.event_busy_rounded
        ),
      final n when n <= 90 => (
          'Terme dans $n jour${n > 1 ? 's' : ''}',
          kAccent,
          Icons.timelapse_rounded
        ),
      final n => ('$n jours de couverture', kGreen, Icons.event_available_rounded),
    };

    return Wrap(spacing: 18, runSpacing: 10, children: [
      _Ligne(
          icone: Icons.play_arrow_rounded,
          label: 'Début',
          valeur: _date(l.dateDebut)),
      _Ligne(icone: Icons.flag_rounded, label: 'Terme', valeur: _date(l.dateFin)),
      AdminBadge(texte, color: couleur, icon: icone),
    ]);
  }
}

class _Montants extends StatelessWidget {
  const _Montants({required this.licence, required this.couleur});

  final LicenceDuGroupe licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    final part = l.partReglee;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 26, runSpacing: 12, children: [
        _Somme(label: 'Montant du marché', valeur: l.montantXaf, fort: true),
        if (l.avanceXaf > 0)
          _Somme(label: 'Avance de démarrage', valeur: l.avanceXaf),
        _Somme(label: 'Réglé à ce jour', valeur: l.montantRegleXaf),
        // Le solde est la seule des trois sommes qui intéresse un ordonnateur.
        // Il reste NEUTRE tant qu'il est dû : ce n'est pas un impayé, c'est le
        // reste d'un échéancier de marché public.
        _Somme(
            label: l.soldee ? 'Solde' : 'Reste à régler',
            valeur: l.soldeXaf < 0 ? 0 : l.soldeXaf,
            teinte: l.soldee ? kGreen : kTextPrimary),
      ]),
      if (part != null) ...[
        const SizedBox(height: 12),
        AdminProgressBar(
            value: l.montantRegleXaf, max: l.montantXaf, color: couleur),
        const SizedBox(height: 6),
        Text('${(part * 100).round()} % du marché réglé',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
      ],
    ]);
  }
}

// ─── États sans contrat ─────────────────────────────────────────────────────
class _AucuneLicence extends StatelessWidget {
  const _AucuneLicence();

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.description_outlined, size: 20, color: kTextMuted),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Aucune licence enregistrée',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(
            'Les conditions de votre licence (période, montant, référence '
            "de marché) n'ont pas encore été saisies par E-PILOTE Congo. "
            "Votre accès et celui de votre réseau n'en dépendent pas.",
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
        ]),
      ),
    ]);
  }
}

class _Attente extends StatelessWidget {
  const _Attente();

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
        const SizedBox(width: 10),
        Text('Lecture de votre licence…',
            style: TextStyle(fontSize: 12.5, color: kTextMuted)),
      ]);
}

class _Incident extends StatelessWidget {
  const _Incident({required this.erreur});

  final Object erreur;

  @override
  Widget build(BuildContext context) {
    // ⚠️ On DIT l'échec. Afficher « aucune licence » sur une requête ratée
    // ferait croire à un ministère que son marché n'est pas enregistré.
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.error_outline_rounded, size: 20, color: kRed),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Votre licence n’a pas pu être lue — $erreur',
          style: TextStyle(fontSize: 12.5, color: kRed, height: 1.5),
        ),
      ),
    ]);
  }
}

class _AccesNeDependPasDeLaLicence extends StatelessWidget {
  const _AccesNeDependPasDeLaLicence();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.08),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_rounded, size: 16, color: kGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Votre accès ne dépend pas de cette licence : aucun terme et '
            'aucun solde ne suspend un ministère de tutelle, ni son réseau. '
            'Le renouvellement se règle par avenant avec E-PILOTE Congo.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45),
          ),
        ),
      ]),
    );
  }
}

// ─── Pièces communes ────────────────────────────────────────────────────────
class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.label, required this.valeur});

  final IconData icone;
  final String label, valeur;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 14, color: kTextMuted),
        const SizedBox(width: 6),
        Text('$label : ', style: TextStyle(fontSize: 12, color: kTextMuted)),
        Text(valeur,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]);
}

class _Somme extends StatelessWidget {
  const _Somme(
      {required this.label, required this.valeur, this.fort = false, this.teinte});

  final String label;
  final int valeur;
  final bool fort;
  final Color? teinte;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 2),
          Text(fmtXaf(valeur),
              style: TextStyle(
                  fontSize: fort ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: teinte ?? kTextPrimary)),
        ],
      );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
