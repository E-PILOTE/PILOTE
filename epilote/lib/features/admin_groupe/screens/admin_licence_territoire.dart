import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/fiche_detail.dart';
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../../tutelle/widgets/tutelle_ecole_detail.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE TERRITOIRE COUVERT PAR LA LICENCE — département par département
//
//  ── LA DEMANDE, MOT POUR MOT ──────────────────────────────────────────────
//  « Quand je clique sur département, je veux plus de détails, ensuite le
//    moyen d'imprimer ça, c'est très important parce que ce sont là les
//    capacités du ministère. On ne peut pas prendre ça à la légère. Ça va se
//    remplir demain, il y a quinze départements, beaucoup de choses vont y
//    arriver. »
//
//  Ce qui existait s'arrêtait à « Kouilou · 7 ». Le département était un
//  cul-de-sac : le nombre s'affichait, et rien derrière. Or c'est l'unité de
//  découpage de l'administration scolaire congolaise — celle des directions
//  départementales, des inspections, des tournées. Un ministre qui prépare une
//  réunion ne demande pas « combien d'écoles au total », il demande « qu'est-ce
//  que j'ai dans la Likouala ».
//
//  ── DEUX NIVEAUX, ET LE TROISIÈME EXISTAIT DÉJÀ ───────────────────────────
//  Départements → un département → un établissement. Le dernier niveau
//  réutilise `ouvrirFicheEcole` (fiche complète, déjà imprimable) : le chef
//  d'établissement, les coordonnées et l'agrément y sont déjà, il n'y avait
//  aucune raison d'en écrire une seconde version.
//
//  ⚠️ AUCUN PLAFOND ICI. Ni `take(n)`, ni « les 10 premiers » : la modale est
//  virtualisée et le PDF paginé. Un département de trois cents écoles s'ouvre
//  et s'imprime comme un département de trois.
// ════════════════════════════════════════════════════════════════════════════

/// Le libellé des écoles sans département. Déclaré UNE fois : le graphe, la
/// fiche « Établissements » et celle-ci comptent la même chose sous le même
/// nom — sinon deux totaux du même réseau finissent par diverger.
///
/// ⚠️ « Non renseigné » n'est pas un département : c'est un défaut de saisie
/// qu'on rend visible plutôt que de le faire disparaître du décompte.
const String kDepartementNonRenseigne = 'Non renseigné';

/// Un département, avec les établissements qui s'y trouvent.
class DepartementCouvert {
  const DepartementCouvert({required this.nom, required this.ecoles});

  final String nom;
  final List<TutelleEcole> ecoles;

  int get nbEcoles => ecoles.length;
  int get eleves => _somme((e) => e.nbEleves);
  int get filles => _somme((e) => e.nbFilles);
  int get personnel => _somme((e) => e.nbPersonnel);
  int get classes => _somme((e) => e.nbClasses);
  int get publiques => ecoles.where((e) => e.estPublic).length;

  /// Les opérateurs présents dans le département — un ministère y lit d'un
  /// coup d'œil s'il traite avec un réseau ou avec vingt écoles isolées.
  List<String> get groupes {
    final noms = <String>{for (final e in ecoles) e.groupeNom};
    return noms.toList()..sort();
  }

  int _somme(int Function(TutelleEcole) champ) =>
      ecoles.fold(0, (s, e) => s + champ(e));

  bool get renseigne => nom != kDepartementNonRenseigne;
}

/// Regroupe le réseau par département, du plus peuplé au moins peuplé.
List<DepartementCouvert> departementsCouverts(ReseauSupervise reseau) {
  final parNom = <String, List<TutelleEcole>>{};
  for (final e in reseau.ecoles) {
    final d = (e.departement ?? '').trim();
    parNom
        .putIfAbsent(d.isEmpty ? kDepartementNonRenseigne : d, () => [])
        .add(e);
  }
  final out = [
    for (final e in parNom.entries)
      DepartementCouvert(nom: e.key, ecoles: e.value),
  ]..sort((a, b) => b.eleves.compareTo(a.eleves));
  return out;
}

// ─── Niveau 1 : tous les départements ───────────────────────────────────────

void ouvrirFicheDepartements(BuildContext context, ReseauSupervise reseau) {
  final deps = departementsCouverts(reseau);
  final eleves = deps.fold(0, (s, d) => s + d.eleves);

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: 'Couverture territoriale',
      sousTitre: 'Le réseau placé sous votre tutelle, département par '
          'département',
      icone: Icons.map_rounded,
      couleur: kNavy,
      total: '${deps.length}',
      totalLabel: deps.length > 1 ? 'Départements couverts' : 'Département',
      nomFichier: 'Licence_Couverture_territoriale',
      chiffres: [
        ('établissements', fmtInt(reseau.ecoles.length)),
        ('élèves', fmtInt(eleves)),
        ('groupes', fmtInt(reseau.groupes.length)),
      ],
      sections: [
        SectionFiche(
          titre: 'Par département',
          enTetes: const [
            'Département',
            'Établiss.',
            'Personnels',
            'Élèves'
          ],
          flex: const [4, 2, 2, 2],
          lignes: [
            for (final d in deps)
              LigneFiche(
                titre: d.nom,
                sousTitre: _sousTitreDepartement(d),
                colonnes: [fmtInt(d.nbEcoles), fmtInt(d.personnel)],
                valeur: fmtInt(d.eleves),
                onTap: (ctx) => ouvrirFicheDepartement(ctx, d),
              ),
          ],
          note: 'Total : ${fmtInt(reseau.ecoles.length)} établissement(s), '
              '${fmtInt(eleves)} élève(s).',
          videLabel: 'Aucun établissement supervisé pour l’instant.',
        ),
      ],
      notes: const [
        'Chaque département s’ouvre sur la liste de ses établissements, et '
            'chaque établissement sur sa fiche.',
        '⚠️ « Non renseigné » regroupe les établissements dont le département '
            'n’a pas été saisi. Ce ne sont pas des établissements sans '
            'territoire : ce sont des fiches à compléter.',
      ],
    ),
  );
}

String _sousTitreDepartement(DepartementCouvert d) {
  final parts = <String>[
    if (d.groupes.length == 1)
      d.groupes.first
    else
      '${d.groupes.length} opérateurs',
    if (d.publiques > 0 && d.publiques < d.nbEcoles)
      '${d.publiques} public${d.publiques > 1 ? 's' : ''} · '
          '${d.nbEcoles - d.publiques} privé'
          '${d.nbEcoles - d.publiques > 1 ? 's' : ''}'
    else if (d.publiques == d.nbEcoles)
      'entièrement public'
    else
      'entièrement privé',
    '${fmtInt(d.classes)} classes',
  ];
  return parts.join(' · ');
}

// ─── Niveau 2 : un département ──────────────────────────────────────────────

void ouvrirFicheDepartement(BuildContext context, DepartementCouvert d) {
  final ecoles = [...d.ecoles]..sort((a, b) => b.nbEleves.compareTo(a.nbEleves));

  // Par groupe : qui exploite quoi dans ce département.
  final parGroupe = <String, List<TutelleEcole>>{};
  // Par type : CEG, lycée, école primaire… la maille des directions
  // départementales.
  final parType = <String, List<TutelleEcole>>{};
  for (final e in ecoles) {
    parGroupe.putIfAbsent(e.groupeNom, () => []).add(e);
    final t = (e.typeEtablissementCourt ?? e.typeEtablissement ?? '').trim();
    parType.putIfAbsent(t.isEmpty ? 'Type non précisé' : t, () => []).add(e);
  }

  ouvrirFicheDetail(
    context,
    FicheDetail(
      titre: d.nom,
      sousTitre: 'Département · ${fmtInt(d.nbEcoles)} établissement'
          '${d.nbEcoles > 1 ? 's' : ''} sous votre tutelle',
      icone: Icons.location_on_rounded,
      couleur: kNavy,
      total: fmtInt(d.eleves),
      totalLabel: 'Élèves couverts',
      nomFichier: 'Licence_Departement_${_fichier(d.nom)}',
      chiffres: [
        ('établissements', fmtInt(d.nbEcoles)),
        if (d.eleves > 0)
          ('de filles', '${(d.filles * 100 / d.eleves).round()} %'),
        ('personnels', fmtInt(d.personnel)),
        ('classes', fmtInt(d.classes)),
        ('opérateurs', fmtInt(d.groupes.length)),
      ],
      sections: [
        SectionFiche(
          titre: 'Établissements',
          enTetes: const ['Établissement', 'Personnels', 'Classes', 'Élèves'],
          flex: const [5, 2, 2, 2],
          lignes: [
            for (final e in ecoles)
              LigneFiche(
                titre: e.nom,
                sousTitre: _sousTitreEcole(e),
                colonnes: [fmtInt(e.nbPersonnel), fmtInt(e.nbClasses)],
                valeur: fmtInt(e.nbEleves),
                onTap: (ctx) => ouvrirFicheEcole(ctx, e),
              ),
          ],
          note: 'Cliquez un établissement pour sa fiche complète : chef '
              'd’établissement, coordonnées, agrément.',
        ),
        SectionFiche(
          titre: 'Par opérateur',
          enTetes: const ['Groupe scolaire', 'Établiss.', 'Élèves'],
          flex: const [5, 2, 2],
          lignes: [
            for (final g in _classe(parGroupe))
              LigneFiche(
                titre: g.key,
                colonnes: [fmtInt(g.value.length)],
                valeur: fmtInt(_eleves(g.value)),
              ),
          ],
        ),
        SectionFiche(
          titre: 'Par type d’établissement',
          enTetes: const ['Type', 'Établiss.', 'Élèves'],
          flex: const [5, 2, 2],
          lignes: [
            for (final t in _classe(parType))
              LigneFiche(
                titre: t.key,
                colonnes: [fmtInt(t.value.length)],
                valeur: fmtInt(_eleves(t.value)),
              ),
          ],
        ),
      ],
      notes: [
        if (!d.renseigne)
          '⚠️ Ces établissements n’ont pas de département saisi. Ils comptent '
              'dans votre licence, mais ils manqueront à toute répartition '
              'territoriale tant que la fiche n’est pas complétée.',
        'Effectifs agrégés remontés par les établissements. Aucun nom d’élève, '
            'aucune note et aucun paiement ne sortent de leur école : la '
            'tutelle voit des totaux, pas des dossiers.',
      ],
    ),
  );
}

String _sousTitreEcole(TutelleEcole e) => [
      e.groupeNom,
      if ((e.ville ?? '').trim().isNotEmpty) e.ville!.trim(),
      if ((e.arrondissement ?? '').trim().isNotEmpty) e.arrondissement!.trim(),
      e.estPublic ? 'public' : 'privé',
      if (!e.actif) 'inactif',
    ].join(' · ');

List<MapEntry<String, List<TutelleEcole>>> _classe(
        Map<String, List<TutelleEcole>> m) =>
    m.entries.toList()
      ..sort((a, b) => _eleves(b.value).compareTo(_eleves(a.value)));

int _eleves(List<TutelleEcole> l) => l.fold(0, (s, e) => s + e.nbEleves);

/// Un nom de département dans un nom de fichier : ni accent, ni espace, ni
/// séparateur de chemin — « Pointe-Noire » ne doit pas créer un dossier.
String _fichier(String nom) =>
    nom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'_+$'), '');
