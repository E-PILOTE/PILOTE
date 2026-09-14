import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/fiche_detail.dart';
import '../../../core/widgets/list_chrome.dart' show kListOrange, kListPurple;
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../../tutelle/widgets/tutelle_ecole_detail.dart';
import '../../tutelle/widgets/tutelle_groupe_detail.dart';
import '../providers/admin_licence_provider.dart';
import '../providers/admin_subscription_provider.dart';
import 'admin_licence_territoire.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉTAIL DERRIÈRE CHAQUE CHIFFRE DE LA PAGE LICENCE
//
//  ── LA RÈGLE ──────────────────────────────────────────────────────────────
//  Un KPI cliquable qui ouvre un joli cadre sans rien de plus est pire qu'un
//  KPI inerte : il a promis quelque chose. Chacune de ces fiches montre donc la
//  DÉCOMPOSITION du nombre affiché — les établissements un par un, les groupes
//  un par un, le calcul du coût unitaire posé en toutes lettres.
//
//  ── CE QUI A CHANGÉ, ET POURQUOI ──────────────────────────────────────────
//  Ces fiches étaient des widgets. Elles sont devenues des DONNÉES
//  (`FicheDetail`) : la même fiche s'affiche et s'imprime, se cherche et se
//  parcourt sans plafond. Trois conséquences directes :
//   • plus de « 12 plus gros établissements sur 25 » — une troncature
//     d'affichage devient un chiffre faux dès qu'on la recopie ;
//   • chaque fiche a son bouton « Imprimer », avec aperçu avant impression ;
//   • un département se clique et descend sur ses établissements, puis sur la
//     fiche d'un établissement (`admin_licence_territoire.dart`).
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
/// ministère. `reseauSuperviseProvider` retire les seconds du PÉRIMÈTRE DE
/// TUTELLE — superviser sa propre école n'est pas de la tutelle — mais la
/// licence, elle, couvre bien les deux. Les compter à deux endroits différents
/// avait déjà produit deux totaux sur la même page.
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
    for (final e in reseau.toutesLesEcoles) {
      eleves += e.nbEleves;
      filles += e.nbFilles;
      personnel += e.nbPersonnel;
      classes += e.nbClasses;
    }
    // ⚠️ REPLI, et seulement un repli. Quand les écoles propres sont
    // remontées, leurs effectifs viennent de la même source que les autres —
    // sinon la somme des lignes ne retombe jamais sur le total affiché, et
    // c'est le total qu'on accuse. Les compteurs d'abonnement ne servent que
    // lorsque ces écoles ne sont pas dans la liste.
    if (reseau.ecolesPropres.isEmpty) {
      eleves += sub.studentsUsed;
      personnel += sub.staffUsed;
    }
    return CouvertureLicence(
      ecolesSupervisees: reseau.ecoles.length,
      ecolesPropres: reseau.nbEcolesPropres,
      eleves: eleves,
      filles: filles,
      personnel: personnel,
      classes: classes,
    );
  }

  final int ecolesSupervisees, ecolesPropres, eleves, filles, personnel, classes;

  int get ecolesTotal => ecolesSupervisees + ecolesPropres;

  /// Les élèves que les listes détaillent, ligne à ligne.
  int elevesDetailles(ReseauSupervise r) =>
      r.toutesLesEcoles.fold(0, (s, e) => s + e.nbEleves);
}

/// ⚠️ LA PHRASE QUI ÉVITE DE CROIRE À UN DOUBLON. Les listes mélangent deux
/// natures d'établissement : ceux que le ministère supervise et ceux qu'il
/// exploite. Les seconds portent la mention « en propre ». Sans cette note, un
/// lecteur qui connaît ses douze écoles les retrouve au milieu du réseau et
/// croit à un double comptage.
String? _notePropres(CouvertureLicence c) => c.ecolesPropres == 0
    ? null
    : 'Vos ${c.ecolesPropres} établissement(s) en propre sont inclus et '
        'signalés « en propre » : la licence les couvre au même titre que le '
        'réseau que vous supervisez.';

// ─── Établissements ─────────────────────────────────────────────────────────

void ouvrirDetailEtablissements(
    BuildContext context, ReseauSupervise reseau, CouvertureLicence c) {
  final deps = departementsCouverts(reseau);
  final couvertes = reseau.toutesLesEcoles;
  final parType = <String, List<TutelleEcole>>{};
  var publiques = 0;
  for (final e in couvertes) {
    final t = (e.typeEtablissementCourt ?? e.typeEtablissement ?? '').trim();
    parType.putIfAbsent(t.isEmpty ? 'Type non précisé' : t, () => []).add(e);
    if (e.estPublic) publiques++;
  }

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Établissements couverts',
      sousTitre: 'Ce que votre licence couvre sur le territoire',
      icone: Icons.school_rounded,
      couleur: kNavy,
      total: '${c.ecolesTotal}',
      totalLabel: 'Établissements',
      nomFichier: 'Licence_Etablissements',
      chiffres: [
        if (c.ecolesPropres > 0) ('en propre', '${c.ecolesPropres}'),
        ('supervisés', '${c.ecolesSupervisees}'),
        ('départements', '${deps.length}'),
        ('groupes', '${reseau.groupes.length}'),
      ],
      sections: [
        SectionFiche(
          titre: 'Par département',
          enTetes: const ['Département', 'Établiss.', 'Élèves', 'Personnels'],
          flex: const [4, 2, 2, 2],
          lignes: [
            for (final d in deps)
              LigneFiche(
                titre: d.nom,
                sousTitre: '${d.groupes.length} opérateur'
                    '${d.groupes.length > 1 ? 's' : ''} · '
                    '${fmtInt(d.classes)} classes',
                colonnes: [fmtInt(d.nbEcoles), fmtInt(d.eleves)],
                valeur: fmtInt(d.personnel),
                onTap: (ctx) => ouvrirFicheDepartement(ctx, d),
              ),
          ],
          note: 'Cliquez un département pour la liste de ses établissements.',
          videLabel: 'Aucun établissement supervisé pour l’instant.',
        ),
        SectionFiche(
          titre: 'Par type d’établissement',
          enTetes: const ['Type', 'Élèves', 'Établiss.'],
          flex: const [5, 2, 2],
          lignes: [
            for (final t in _parVolume(parType))
              LigneFiche(
                titre: t.key,
                colonnes: [fmtInt(_eleves(t.value))],
                valeur: '${t.value.length}',
              ),
          ],
        ),
        SectionFiche(
          titre: 'Par secteur',
          enTetes: const ['Secteur', 'Part', 'Établiss.'],
          flex: const [5, 2, 2],
          lignes: [
            LigneFiche(
              titre: 'Public',
              colonnes: [_part(publiques, couvertes.length)],
              valeur: '$publiques',
            ),
            LigneFiche(
              titre: 'Privé',
              colonnes: [
                _part(couvertes.length - publiques, couvertes.length)
              ],
              valeur: '${couvertes.length - publiques}',
            ),
          ],
        ),
      ],
      notes: [
        if (_notePropres(c) != null) _notePropres(c)!,
      ],
    ),
  );
}

// ─── Élèves ─────────────────────────────────────────────────────────────────

void ouvrirDetailEleves(
    BuildContext context, ReseauSupervise reseau, CouvertureLicence c) {
  final ecoles = [...reseau.toutesLesEcoles]
    ..sort((a, b) => b.nbEleves.compareTo(a.nbEleves));
  final deps = departementsCouverts(reseau);

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Élèves couverts',
      sousTitre: 'L’effectif que votre licence couvre',
      icone: Icons.groups_rounded,
      couleur: kGreen,
      total: fmtInt(c.eleves),
      totalLabel: 'Élèves',
      nomFichier: 'Licence_Eleves',
      chiffres: [
        if (c.eleves > 0)
          ('de filles', '${(c.filles * 100 / c.eleves).round()} %'),
        ('classes', fmtInt(c.classes)),
        ('établissements', '${c.ecolesTotal}'),
      ],
      sections: [
        SectionFiche(
          titre: 'Par département',
          enTetes: const ['Département', 'Établiss.', 'Élèves'],
          flex: const [5, 2, 2],
          lignes: [
            for (final d in deps)
              LigneFiche(
                titre: d.nom,
                colonnes: [fmtInt(d.nbEcoles)],
                valeur: fmtInt(d.eleves),
                onTap: (ctx) => ouvrirFicheDepartement(ctx, d),
              ),
          ],
        ),
        SectionFiche(
          // ⚠️ TOUS les établissements, plus « les 12 plus gros ». La liste est
          // virtualisée et cherchable : la longueur n'est plus un argument.
          titre: 'Par établissement',
          enTetes: const ['Établissement', 'Classes', 'Élèves'],
          flex: const [5, 2, 2],
          lignes: [
            for (final e in ecoles)
              LigneFiche(
                titre: e.nom,
                sousTitre: [
                  e.groupeNom,
                  if ((e.departement ?? '').isNotEmpty) e.departement!,
                ].join(' · '),
                colonnes: [fmtInt(e.nbClasses)],
                valeur: fmtInt(e.nbEleves),
                onTap: (ctx) => ouvrirFicheEcole(ctx, e),
              ),
          ],
          note: 'Total détaillé : '
              '${fmtInt(c.elevesDetailles(reseau))} élève(s).',
        ),
      ],
      notes: [
        if (_notePropres(c) != null) _notePropres(c)!,
        'Effectifs agrégés : aucun nom d’élève ne sort de son établissement.',
      ],
    ),
  );
}

// ─── Personnels et groupes ──────────────────────────────────────────────────

void ouvrirDetailPersonnels(
    BuildContext context, ReseauSupervise reseau, CouvertureLicence c) {
  final groupes = [...reseau.groupes]
    ..sort((a, b) => b.nbPersonnel.compareTo(a.nbPersonnel));
  final ecoles = [...reseau.toutesLesEcoles]
    ..sort((a, b) => b.nbPersonnel.compareTo(a.nbPersonnel));

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Personnels couverts',
      sousTitre: 'Les agents des établissements que vous supervisez',
      icone: Icons.badge_rounded,
      couleur: kAccent,
      total: fmtInt(c.personnel),
      totalLabel: 'Personnels',
      nomFichier: 'Licence_Personnels',
      chiffres: [
        ('groupes', '${reseau.groupes.length}'),
        ('établissements', '${c.ecolesTotal}'),
        ('classes', fmtInt(c.classes)),
      ],
      sections: [
        SectionFiche(
          titre: 'Par groupe scolaire',
          enTetes: const ['Groupe', 'Établiss.', 'Élèves', 'Personnels'],
          flex: const [4, 2, 2, 2],
          lignes: [
            for (final g in groupes)
              LigneFiche(
                titre: g.nom,
                sousTitre: g.estPublic ? 'public' : 'privé',
                colonnes: [fmtInt(g.nbEcoles), fmtInt(g.nbEleves)],
                valeur: fmtInt(g.nbPersonnel),
                onTap: (ctx) => ouvrirFicheGroupe(
                  ctx,
                  g,
                  ecoles: [
                    for (final e in reseau.ecoles)
                      if (e.groupId == g.id) e,
                  ],
                ),
              ),
          ],
          note: 'Les opérateurs que vous supervisez sans les administrer. '
              'Votre propre groupe n’y figure pas.',
          videLabel: 'Aucun groupe tiers supervisé.',
        ),
        SectionFiche(
          titre: 'Par établissement',
          enTetes: const ['Établissement', 'Classes', 'Personnels'],
          flex: const [5, 2, 2],
          lignes: [
            for (final e in ecoles)
              LigneFiche(
                titre: e.nom,
                sousTitre: [
                  e.groupeNom,
                  if ((e.departement ?? '').isNotEmpty) e.departement!,
                ].join(' · '),
                colonnes: [fmtInt(e.nbClasses)],
                valeur: fmtInt(e.nbPersonnel),
                onTap: (ctx) => ouvrirFicheEcole(ctx, e),
              ),
          ],
        ),
      ],
      notes: [
        if (_notePropres(c) != null) _notePropres(c)!,
      ],
    ),
  );
}

// ─── Droits ouverts ─────────────────────────────────────────────────────────

void ouvrirDetailDroits(BuildContext context, int nbModules) {
  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Ce que la licence ouvre',
      sousTitre: 'Les droits attachés à votre marché',
      icone: Icons.extension_rounded,
      couleur: kListPurple,
      total: '$nbModules',
      totalLabel: 'Modules ouverts',
      nomFichier: 'Licence_Droits',
      chiffres: const [('droits de tutelle', '4')],
      sections: [
        SectionFiche(
          titre: 'Droits de tutelle',
          enTetes: const ['Droit', 'État'],
          flex: const [6, 2],
          lignes: [
            for (final (_, titre, texte) in kDroitsDeTutelle)
              LigneFiche(titre: titre, sousTitre: texte, valeur: 'Ouvert'),
          ],
        ),
      ],
      notes: const [
        '⚠️ Les modules sont accordés par le PLAN de licence, pas un par un. '
            'Ils ne dépendent ni du règlement du marché, ni de son statut.',
      ],
    ),
  );
}

// ─── Coût unitaire ──────────────────────────────────────────────────────────

void ouvrirDetailCoutUnitaire(
    BuildContext context, LicenceDuGroupe l, CouvertureLicence c) {
  final parEcole = l.coutAnnuelParEtablissement(c.ecolesTotal);
  final parEleve = l.coutAnnuelParEleve(c.eleves);

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Ce que la licence représente',
      sousTitre: l.intitule,
      icone: Icons.calculate_rounded,
      couleur: kListOrange,
      total: fmtXaf(parEcole ?? 0),
      totalLabel: 'Par établissement / an',
      nomFichier: 'Licence_Cout_unitaire',
      chiffres: [
        ('marché', fmtXaf(l.montantXaf)),
        ('par an', fmtXaf(l.annuelXaf)),
        if (parEleve != null) ('par élève / an', fmtXaf(parEleve)),
      ],
      sections: [
        SectionFiche(
          titre: 'Le calcul',
          enTetes: const ['Élément', 'Valeur'],
          lignes: [
            LigneFiche(
                titre: 'Montant du marché', valeur: fmtXaf(l.montantXaf)),
            LigneFiche(
                titre: 'Durée',
                sousTitre: 'soit ${l.moisCouverts} mois',
                valeur: '${l.dureeJours} j'),
            LigneFiche(
                titre: 'Ramené à l’année',
                sousTitre:
                    '⚠️ un marché de 3 ans n’est pas ce montant PAR an',
                valeur: fmtXaf(l.annuelXaf)),
          ],
        ),
        SectionFiche(
          titre: 'Divisé par ce qu’il couvre',
          enTetes: const ['Assiette', 'Coût annuel', 'Nombre'],
          flex: const [4, 3, 2],
          lignes: [
            LigneFiche(
              titre: 'Établissements',
              colonnes: [parEcole == null ? '—' : fmtXaf(parEcole)],
              valeur: '${c.ecolesTotal}',
            ),
            LigneFiche(
              titre: 'Élèves',
              colonnes: [parEleve == null ? '—' : fmtXaf(parEleve)],
              valeur: fmtInt(c.eleves),
            ),
          ],
        ),
      ],
      notes: const [
        '⚠️ C’est le seul chiffre qui se défend en réunion. Un montant global '
            's’attaque tout seul ; un coût unitaire se compare — à un manuel '
            'scolaire, à une tournée d’inspection, à un logiciel concurrent.',
      ],
    ),
  );
}

// ─── Règlement ──────────────────────────────────────────────────────────────

void ouvrirDetailReglement(BuildContext context, LicenceDuGroupe l) {
  final retard = (l.partReglee == null) ? null : l.partEcoulee - l.partReglee!;

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Règlement du marché',
      sousTitre: l.intitule,
      icone: Icons.payments_rounded,
      couleur: l.soldee ? kGreen : kListOrange,
      total: fmtXaf(l.soldeXaf < 0 ? 0 : l.soldeXaf),
      totalLabel: l.soldee ? 'Solde' : 'Reste à régler',
      nomFichier: 'Licence_Reglement',
      chiffres: [
        ('marché', fmtXaf(l.montantXaf)),
        ('réglé', fmtXaf(l.montantRegleXaf)),
        if (l.avanceXaf > 0) ('avance', fmtXaf(l.avanceXaf)),
      ],
      barres: [
        BarreFiche(
            label: 'Période écoulée', valeur: l.partEcoulee, couleur: kNavy),
        BarreFiche(
          label: 'Marché réglé',
          valeur: l.partReglee ?? 0,
          couleur: retard != null && retard > 0.15 ? kListOrange : kGreen,
        ),
      ],
      sections: [
        SectionFiche(
          titre: 'Les montants',
          enTetes: const ['Poste', 'Montant'],
          lignes: [
            LigneFiche(
                titre: 'Montant du marché', valeur: fmtXaf(l.montantXaf)),
            if (l.avanceXaf > 0)
              LigneFiche(
                  titre: 'Avance de démarrage', valeur: fmtXaf(l.avanceXaf)),
            LigneFiche(
                titre: 'Réglé à ce jour', valeur: fmtXaf(l.montantRegleXaf)),
            LigneFiche(
                titre: 'Reste à régler',
                valeur: fmtXaf(l.soldeXaf < 0 ? 0 : l.soldeXaf)),
          ],
        ),
      ],
      notes: [
        retard == null
            ? 'Ce marché ne porte aucun montant : il n’y a rien à régler.'
            : retard > 0.15
                ? 'Le règlement a ${(retard * 100).round()} points de retard '
                    'sur la période consommée.'
                : 'Le règlement suit la période consommée.',
        '⚠️ Rappel : ni ce solde ni ce retard ne suspendent votre accès. Une '
            'coupure serait une décision distincte, prise et notifiée '
            'séparément par E-PILOTE Congo.',
      ],
    ),
  );
}

// ─── Petits calculs partagés ────────────────────────────────────────────────

List<MapEntry<String, List<TutelleEcole>>> _parVolume(
        Map<String, List<TutelleEcole>> m) =>
    m.entries.toList()
      ..sort((a, b) => _eleves(b.value).compareTo(_eleves(a.value)));

int _eleves(List<TutelleEcole> l) => l.fold(0, (s, e) => s + e.nbEleves);

String _part(int n, int total) =>
    total == 0 ? '—' : '${(n * 100 / total).round()} %';
