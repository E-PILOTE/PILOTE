import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange, kListPurple;
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../providers/admin_licence_provider.dart';
import '../providers/admin_subscription_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉTAIL DERRIÈRE CHAQUE CHIFFRE DE LA PAGE LICENCE
//
//  ── LA RÈGLE ──────────────────────────────────────────────────────────────
//  Un KPI cliquable qui ouvre un joli cadre sans rien de plus est pire qu'un
//  KPI inerte : il a promis quelque chose. Chacune de ces fiches montre donc
//  la DÉCOMPOSITION du nombre affiché — les établissements un par un, les
//  groupes un par un, le calcul du coût unitaire posé en toutes lettres.
//
//  ⚠️ Aucune de ces fiches n'invente : tout vient de `tutelle_ecoles()` et
//  `tutelle_groupes()`, déjà chargés pour la page. Ouvrir un détail ne
//  déclenche AUCUNE requête — sur une liaison congolaise, un clic qui part au
//  serveur pour afficher ce qu'on a déjà est un clic qui semble cassé.
// ════════════════════════════════════════════════════════════════════════════

/// Les quatre droits que la licence ouvre. Déclarés ici parce que deux écrans
/// les affichent : la page de couverture, et la fiche « modules ouverts ».
const kDroitsDeTutelle = <(IconData, String, String)>[
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

/// Ce que la licence couvre, calculé UNE fois et partagé.
///
/// ⚠️ Le total additionne le réseau supervisé ET les établissements propres du
/// ministère. `reseauSuperviseProvider` retire les seconds du périmètre —
/// superviser sa propre école n'est pas de la tutelle — mais la licence, elle,
/// couvre bien les deux. Les compter à deux endroits différents avait déjà
/// produit deux totaux sur la même page.
class CouvertureLicence {
  const CouvertureLicence({
    required this.ecolesSupervisees,
    required this.ecolesPropres,
    required this.eleves,
    required this.filles,
    required this.personnel,
    required this.classes,
  });

  factory CouvertureLicence.calculer({
    required GroupSubscription sub,
    required ReseauSupervise reseau,
  }) {
    var eleves = 0, filles = 0, personnel = 0, classes = 0;
    for (final e in reseau.ecoles) {
      eleves += e.nbEleves;
      filles += e.nbFilles;
      personnel += e.nbPersonnel;
      classes += e.nbClasses;
    }
    return CouvertureLicence(
      ecolesSupervisees: reseau.ecoles.length,
      ecolesPropres: reseau.nbEcolesPropres,
      // Les effectifs PROPRES du ministère viennent des compteurs de son
      // abonnement : les mêmes écoles, comptées par l'autre bout.
      eleves: eleves + sub.studentsUsed,
      filles: filles,
      personnel: personnel + sub.staffUsed,
      classes: classes,
    );
  }

  final int ecolesSupervisees, ecolesPropres, eleves, filles, personnel, classes;

  int get ecolesTotal => ecolesSupervisees + ecolesPropres;
}

// ─── Les fiches ─────────────────────────────────────────────────────────────

void ouvrirDetailEtablissements(
    BuildContext context, ReseauSupervise reseau, CouvertureLicence c) {
  final parDep = <String, int>{};
  for (final e in reseau.ecoles) {
    final d = (e.departement ?? '').trim().isEmpty
        ? 'Non renseigné'
        : e.departement!;
    parDep[d] = (parDep[d] ?? 0) + 1;
  }
  final lignes = parDep.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  _ouvrir(
    context,
    icone: Icons.school_rounded,
    titre: 'Établissements couverts',
    couleur: kNavy,
    total: '${c.ecolesTotal}',
    totalLabel: 'Établissements',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.ecolesPropres > 0)
        _Ligne(
            titre: 'Vos propres établissements',
            valeur: '${c.ecolesPropres}',
            sousTitre: 'exploités directement par le ministère'),
      _Ligne(
          titre: 'Établissements supervisés',
          valeur: '${c.ecolesSupervisees}',
          sousTitre: 'répartis sur ${parDep.length} département'
              '${parDep.length > 1 ? 's' : ''}'),
      const SizedBox(height: 14),
      const _Titre('Par département'),
      for (final e in lignes)
        _Ligne(titre: e.key, valeur: '${e.value}', compact: true),
    ]),
  );
}

void ouvrirDetailEleves(
    BuildContext context, ReseauSupervise reseau, CouvertureLicence c) {
  final ecoles = [...reseau.ecoles]
    ..sort((a, b) => b.nbEleves.compareTo(a.nbEleves));
  final top = ecoles.take(12).toList();

  _ouvrir(
    context,
    icone: Icons.groups_rounded,
    titre: 'Élèves couverts',
    couleur: kGreen,
    total: fmtInt(c.eleves),
    totalLabel: 'Élèves',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Ligne(
          titre: 'Filles',
          valeur: fmtInt(c.filles),
          sousTitre: c.eleves == 0
              ? null
              : '${(c.filles * 100 / c.eleves).round()} % de l’effectif '
                  'supervisé'),
      _Ligne(titre: 'Classes', valeur: fmtInt(c.classes)),
      const SizedBox(height: 14),
      _Titre(top.length < ecoles.length
          ? '12 plus gros établissements sur ${ecoles.length}'
          : 'Par établissement'),
      for (final e in top)
        _Ligne(
            titre: e.nom,
            valeur: fmtInt(e.nbEleves),
            sousTitre: e.departement ?? '',
            compact: true),
    ]),
  );
}

void ouvrirDetailGroupes(BuildContext context, ReseauSupervise reseau) {
  final groupes = [...reseau.groupes]
    ..sort((a, b) => b.nbEleves.compareTo(a.nbEleves));

  _ouvrir(
    context,
    icone: Icons.account_tree_rounded,
    titre: 'Groupes supervisés',
    couleur: kAccent,
    total: '${reseau.groupes.length}',
    totalLabel: 'Groupes tiers',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Note(
        'Les opérateurs que vous supervisez sans les administrer — publics '
        'comme privés. Votre propre groupe n’y figure pas.',
      ),
      const SizedBox(height: 12),
      for (final g in groupes)
        _Ligne(
            titre: g.nom,
            valeur: fmtInt(g.nbEleves),
            sousTitre: '${g.nbEcoles} établissement'
                '${g.nbEcoles > 1 ? 's' : ''} · ${fmtInt(g.nbPersonnel)} '
                'personnel${g.nbPersonnel > 1 ? 's' : ''}',
            compact: true),
    ]),
  );
}

void ouvrirDetailDroits(BuildContext context) {
  _ouvrir(
    context,
    icone: Icons.extension_rounded,
    titre: 'Ce que la licence ouvre',
    couleur: kListPurple,
    total: '4',
    totalLabel: 'Droits de tutelle',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (icone, titre, texte) in kDroitsDeTutelle)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icone, size: 16, color: kGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(texte,
                        style: TextStyle(
                            fontSize: 12, color: kTextMuted, height: 1.45)),
                  ]),
            ),
          ]),
        ),
    ]),
  );
}

void ouvrirDetailCoutUnitaire(
    BuildContext context, LicenceDuGroupe l, CouvertureLicence c) {
  final parEcole = l.coutAnnuelParEtablissement(c.ecolesTotal);
  final parEleve = l.coutAnnuelParEleve(c.eleves);

  _ouvrir(
    context,
    icone: Icons.calculate_rounded,
    titre: 'Ce que la licence représente',
    couleur: kListOrange,
    total: fmtXaf(parEcole ?? 0),
    totalLabel: 'Par établissement / an',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Note(
        '⚠️ C’est le seul chiffre qui se défend en réunion. Un montant global '
        's’attaque tout seul ; un coût unitaire se compare — à un manuel '
        'scolaire, à une tournée d’inspection, à un logiciel concurrent.',
      ),
      const SizedBox(height: 14),
      const _Titre('Le calcul'),
      _Ligne(titre: 'Montant du marché', valeur: fmtXaf(l.montantXaf)),
      _Ligne(
          titre: 'Durée',
          valeur: '${l.dureeJours} j',
          sousTitre: 'soit ${l.moisCouverts} mois'),
      _Ligne(
          titre: 'Ramené à l’année',
          valeur: fmtXaf(l.annuelXaf),
          sousTitre: '⚠️ un marché de 3 ans n’est pas ce montant PAR an'),
      const SizedBox(height: 12),
      const _Titre('Divisé par ce qu’il couvre'),
      _Ligne(
          titre: 'Établissements',
          valeur: '${c.ecolesTotal}',
          sousTitre: parEcole == null
              ? null
              : '${fmtXaf(parEcole)} par établissement et par an'),
      _Ligne(
          titre: 'Élèves',
          valeur: fmtInt(c.eleves),
          sousTitre: parEleve == null
              ? null
              : '${fmtXaf(parEleve)} par élève et par an'),
    ]),
  );
}

void ouvrirDetailReglement(BuildContext context, LicenceDuGroupe l) {
  final retard = (l.partReglee == null) ? null : l.partEcoulee - l.partReglee!;
  _ouvrir(
    context,
    icone: Icons.payments_rounded,
    titre: 'Règlement du marché',
    couleur: l.soldee ? kGreen : kListOrange,
    total: fmtXaf(l.soldeXaf < 0 ? 0 : l.soldeXaf),
    totalLabel: l.soldee ? 'Solde' : 'Reste à régler',
    corps: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Ligne(titre: 'Montant du marché', valeur: fmtXaf(l.montantXaf)),
      if (l.avanceXaf > 0)
        _Ligne(titre: 'Avance de démarrage', valeur: fmtXaf(l.avanceXaf)),
      _Ligne(titre: 'Réglé à ce jour', valeur: fmtXaf(l.montantRegleXaf)),
      const SizedBox(height: 14),
      const _Titre('Où en est l’exécution'),
      _Barre(
          label: 'Période écoulée',
          valeur: l.partEcoulee,
          couleur: kTextMuted),
      const SizedBox(height: 8),
      _Barre(
          label: 'Marché réglé',
          valeur: l.partReglee ?? 0,
          couleur: retard != null && retard > 0.15 ? kListOrange : kGreen),
      const SizedBox(height: 12),
      _Note(
        retard == null
            ? 'Ce marché ne porte aucun montant : il n’y a rien à régler.'
            : retard > 0.15
                ? 'Le règlement a ${(retard * 100).round()} points de retard '
                    'sur la période consommée.'
                : 'Le règlement suit la période consommée.',
      ),
      const SizedBox(height: 12),
      const _Note(
        '⚠️ Rappel : ni ce solde ni ce retard ne suspendent votre accès. '
        'Une coupure serait une décision distincte, prise et notifiée '
        'séparément par E-PILOTE Congo.',
      ),
    ]),
  );
}

// ─── La coquille ────────────────────────────────────────────────────────────
void _ouvrir(
  BuildContext context, {
  required IconData icone,
  required String titre,
  required Color couleur,
  required String total,
  required String totalLabel,
  required Widget corps,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => AdminFormDialog(
      icon: icone,
      title: titre,
      accent: couleur,
      width: 560,
      hero: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          Text(totalLabel.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kTextMuted)),
          const Spacer(),
          Text(total,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kTextPrimary)),
        ]),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Row(children: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: kTextMuted)),
          ),
        ]),
      ),
      body: corps,
    ),
  );
}

class _Ligne extends StatelessWidget {
  const _Ligne(
      {required this.titre,
      required this.valeur,
      this.sousTitre,
      this.compact = false});

  final String titre, valeur;
  final String? sousTitre;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 8 : 10),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 12 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  if (sousTitre != null && sousTitre!.isNotEmpty)
                    Text(sousTitre!,
                        maxLines: 2,
                        style: TextStyle(fontSize: 11, color: kTextMuted)),
                ]),
          ),
          const SizedBox(width: 12),
          Text(valeur,
              style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
        ]),
      );
}

class _Barre extends StatelessWidget {
  const _Barre(
      {required this.label, required this.valeur, required this.couleur});

  final String label;
  final double valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: valeur.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: couleur.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(couleur),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text('${(valeur * 100).round()} %',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texte.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: kTextMuted)),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5));
}
