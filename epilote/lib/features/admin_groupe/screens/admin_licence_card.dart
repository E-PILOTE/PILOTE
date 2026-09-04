import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tutelle.dart';
import '../../../core/services/licence_pdf_service.dart';
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
//  base les refuse depuis 0182 ; la quatrième, « Renouveler mon abonnement »,
//  depuis 0183.
//
//  ── ⚠️ CE QUE CETTE PAGE DOIT AVOIR L'AIR D'ÊTRE ──────────────────────────
//  Une licence de tutelle se vend **40 millions de francs** au départ. La page
//  qui la porte n'est pas une carte d'abonnement : c'est la fiche d'un marché
//  public. Elle doit répondre aux quatre questions que pose un ordonnateur,
//  dans cet ordre :
//
//    1. COMBIEN ?      le montant du marché, en toutes lettres de chiffres,
//                      plus ses équivalents mensuel et annuel — parce qu'un
//                      budget d'État se vote à l'année.
//    2. OÙ EN EST LE PAIEMENT ?  dû / avance / réglé / SOLDE. Un marché public
//                      se règle en tranches ; le solde est le seul des quatre
//                      nombres qui appelle une décision.
//    3. JUSQU'À QUAND ?  la période, et surtout la part ÉCOULÉE — deux barres
//                      côte à côte, temps et règlement, qui ne racontent pas
//                      la même histoire.
//    4. POUR QUOI ?    ce que la licence ouvre (`admin_licence_couverture`) et
//                      ce qu'elle coûte par établissement et par élève.
//
//  ── ⚠️ LA LIGNE QUI NE DOIT JAMAIS DISPARAÎTRE ────────────────────────────
//  « Votre accès ne dépend pas de cette licence. » Ce n'est pas une politesse,
//  c'est la contrainte C4 du 0160, et elle est vraie dans le code : une
//  licence échue ou impayée ne ferme rien, et 0183 garantit qu'un ministère
//  n'a pas d'échéance d'abonnement. Sans cette phrase, un solde de trente
//  millions affiché en rouge se lit comme une menace de coupure — et c'est
//  l'État qu'on menacerait.
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
          const SizedBox(height: 18),
          async.when(
            loading: () => const _Attente(),
            error: (e, _) => _Incident(erreur: e),
            data: (licences) {
              final l = licenceAMontrer(licences);
              return l == null
                  ? const _AucuneLicence()
                  : _Contrat(
                      licence: l,
                      couleur: couleur,
                      tutelle: sub.tutelle,
                      nomGroupe: sub.groupName);
            },
          ),
          const SizedBox(height: 18),
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
  const _Contrat(
      {required this.licence,
      required this.couleur,
      required this.tutelle,
      required this.nomGroupe});

  final LicenceDuGroupe licence;
  final Color couleur;
  final String? tutelle;
  final String nomGroupe;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.intitule,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            AdminBadge(l.statutLabel,
                color: couleurStatutLicence(l.statut), icon: Icons.circle),
            if (l.referenceMarche != null &&
                l.referenceMarche!.trim().isNotEmpty)
              AdminBadge('Marché ${l.referenceMarche}',
                  color: kTextMuted, icon: Icons.gavel_rounded),
          ]),
      if (l.motifStatut != null && l.motifStatut!.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        _MotifDuStatut(licence: l),
      ],
      const SizedBox(height: 18),
      _MontantDuMarche(licence: l, couleur: couleur),
      const SizedBox(height: 20),
      _Echeancier(licence: l, couleur: couleur),
      const SizedBox(height: 20),
      _Couverture(licence: l, couleur: couleur),
      if (l.signataire != null && l.signataire!.trim().isNotEmpty) ...[
        const SizedBox(height: 16),
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
      const SizedBox(height: 16),
      // Le ministère imprime SA fiche : c'est la pièce qu'un cabinet range
      // dans le dossier du marché, et qu'il produit en réunion budgétaire.
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => LicencePdfService.imprimer(ficheAImprimer(l)),
          icon: const Icon(Icons.print_rounded, size: 16),
          label: const Text('Imprimer la fiche'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kNavy,
            side: BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    ]);
  }

  /// Traduit la licence du ministère en fiche imprimable.
  ///
  /// ⚠️ Le nom d'USAGE du ministère, pas sa raison sociale : la base porte
  /// « MEPSA — Ministère Enseign. Primaire » d'un côté et l'intitulé complet
  /// de l'autre. Sur un document qui part dans un dossier de marché, c'est le
  /// nom officiel qu'on veut lire.
  LicenceAImprimer ficheAImprimer(LicenceDuGroupe l) => LicenceAImprimer(
        ministere: nomTutelle(tutelle) ?? nomGroupe,
        sigleTutelle: sigleTutelle(tutelle),
        intitule: l.intitule,
        statut: l.statut,
        statutLabel: l.statutLabel,
        dateDebut: l.dateDebut,
        dateFin: l.dateFin,
        montantXaf: l.montantXaf,
        avanceXaf: l.avanceXaf,
        montantRegleXaf: l.montantRegleXaf,
        referenceMarche: l.referenceMarche,
        signataire: l.signataire,
        notes: l.notes,
        motifStatut: l.motifStatut,
      );
}

/// Le motif d'une suspension ou d'une résiliation, écrit par E-PILOTE Congo.
///
/// ⚠️ AFFICHÉ AU MINISTÈRE, pas seulement au fondateur. Une décision qui
/// l'affecte et qu'il découvrirait sans explication est une décision qu'il
/// vient contester par téléphone — et il a raison. Le texte est le MÊME des
/// deux côtés : c'est la seule façon qu'il n'y ait pas deux versions.
class _MotifDuStatut extends StatelessWidget {
  const _MotifDuStatut({required this.licence});

  final LicenceDuGroupe licence;

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutLicence(licence.statut);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.sticky_note_2_rounded, size: 16, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                licence.statutChangeLe == null
                    ? 'Motif'
                    : 'Motif · ${_date(licence.statutChangeLe!)}',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kTextMuted)),
            const SizedBox(height: 3),
            Text(licence.motifStatut!.trim(),
                style: TextStyle(
                    fontSize: 12.5, color: kTextPrimary, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}

// ─── 1. COMBIEN ─────────────────────────────────────────────────────────────
class _MontantDuMarche extends StatelessWidget {
  const _MontantDuMarche({required this.licence, required this.couleur});

  final LicenceDuGroupe licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        border: Border.all(color: couleur.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MONTANT DU MARCHÉ',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: kTextMuted)),
        const SizedBox(height: 6),
        // ⚠️ Le montant EXACT, jamais « 40,0 M ». Sur la fiche d'un marché
        // public, un chiffre arrondi est un chiffre qu'on ne peut pas
        // rapprocher d'un mandat de paiement.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(fmtXaf(l.montantXaf),
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: kTextPrimary)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 22, runSpacing: 8, children: [
          _Equivalent(
              label: 'soit par an',
              valeur: fmtXaf(l.annuelXaf),
              aide: 'un budget d’État se vote à l’année'),
          _Equivalent(
              label: 'soit par mois',
              valeur: fmtXaf(l.mensuelXaf),
              aide: '${l.moisCouverts} mois couverts'),
        ]),
      ]),
    );
  }
}

class _Equivalent extends StatelessWidget {
  const _Equivalent(
      {required this.label, required this.valeur, required this.aide});

  final String label, valeur, aide;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
          const SizedBox(height: 1),
          Text(valeur,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          Text(aide, style: TextStyle(fontSize: 10, color: kTextMuted)),
        ],
      );
}

// ─── 2. OÙ EN EST LE PAIEMENT ───────────────────────────────────────────────
class _Echeancier extends StatelessWidget {
  const _Echeancier({required this.licence, required this.couleur});

  final LicenceDuGroupe licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    final part = l.partReglee;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('RÈGLEMENT',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: kTextMuted)),
      const SizedBox(height: 10),
      Wrap(spacing: 26, runSpacing: 12, children: [
        if (l.avanceXaf > 0)
          _Somme(label: 'Avance de démarrage', valeur: l.avanceXaf),
        _Somme(label: 'Réglé à ce jour', valeur: l.montantRegleXaf),
        // Le solde reste NEUTRE tant qu'il est dû : ce n'est pas un impayé,
        // c'est le reste d'un échéancier de marché public.
        _Somme(
            label: l.soldee ? 'Solde' : 'Reste à régler',
            valeur: l.soldeXaf < 0 ? 0 : l.soldeXaf,
            fort: !l.soldee,
            teinte: l.soldee ? kGreen : kTextPrimary),
      ]),
      if (part != null) ...[
        const SizedBox(height: 12),
        AdminProgressBar(
            value: l.montantRegleXaf, max: l.montantXaf, color: couleur),
        const SizedBox(height: 6),
        Text(
            l.soldee
                ? 'Marché intégralement réglé'
                : '${(part * 100).round()} % du marché réglé',
            style: TextStyle(fontSize: 11.5, color: kTextMuted)),
      ],
    ]);
  }
}

// ─── 3. JUSQU'À QUAND ───────────────────────────────────────────────────────
class _Couverture extends StatelessWidget {
  const _Couverture({required this.licence, required this.couleur});

  final LicenceDuGroupe licence;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final l = licence;
    final j = l.joursRestants;
    // ⚠️ Aucune de ces pastilles n'annonce une coupure : elles informent d'un
    // terme contractuel. « Échue » invite à un avenant, pas à un paiement pour
    // rouvrir un accès qui n'a jamais été fermé.
    final (String texte, Color teinte, IconData icone) = switch (j) {
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
      final n => (
          '$n jours de couverture',
          kGreen,
          Icons.event_available_rounded
        ),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PÉRIODE COUVERTE',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: kTextMuted)),
      const SizedBox(height: 10),
      Wrap(spacing: 18, runSpacing: 10, children: [
        _Ligne(
            icone: Icons.play_arrow_rounded,
            label: 'Début',
            valeur: _date(l.dateDebut)),
        _Ligne(
            icone: Icons.flag_rounded, label: 'Terme', valeur: _date(l.dateFin)),
        AdminBadge(texte, color: teinte, icon: icone),
      ]),
      const SizedBox(height: 12),
      // La SECONDE barre. Les deux ne racontent pas la même histoire : un
      // marché peut être couvert à 80 % du temps et réglé à 25 %.
      AdminProgressBar(
          value: (l.partEcoulee * 1000).round(), max: 1000, color: couleur),
      const SizedBox(height: 6),
      Text(
          '${(l.partEcoulee * 100).round()} % de la période écoulée '
          '· ${l.dureeJours} jours au total',
          style: TextStyle(fontSize: 11.5, color: kTextMuted)),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
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
            child:
                CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
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
  const _Ligne(
      {required this.icone, required this.label, required this.valeur});

  final IconData icone;
  final String label, valeur;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 14, color: kTextMuted),
        const SizedBox(width: 6),
        Text('$label : ', style: TextStyle(fontSize: 12, color: kTextMuted)),
        Text(valeur,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
      ]);
}

class _Somme extends StatelessWidget {
  const _Somme(
      {required this.label,
      required this.valeur,
      this.fort = false,
      this.teinte});

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
