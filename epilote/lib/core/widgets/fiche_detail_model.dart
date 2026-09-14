import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE FICHE DE DÉTAIL — le même objet à l'écran ET sur le papier
//
//  ── LE DÉFAUT QU'IL CORRIGE ───────────────────────────────────────────────
//  Chaque KPI cliquable ouvrait une modale composée de widgets. Trois
//  conséquences, toutes payées :
//   1. RIEN N'ÉTAIT IMPRIMABLE. Un ministre voit à l'écran la couverture de son
//      marché et ne peut rien poser sur une table de réunion. Le fondateur :
//      « ensuite le moyen d'imprimer ça, c'est très important parce que ce sont
//      là les capacités du ministère ».
//   2. LES LISTES ÉTAIENT TRONQUÉES pour tenir dans la boîte (« 12 plus gros
//      établissements sur 25 »). Une troncature d'affichage devient un chiffre
//      faux dès qu'on la recopie.
//   3. TOUT ÉTAIT CONSTRUIT D'UN COUP. Douze lignes passent ; mille écoles
//      construisent mille widgets avant le premier pixel.
//
//  ── LE PRINCIPE ───────────────────────────────────────────────────────────
//  Une fiche est une DONNÉE, pas un arbre de widgets : un total, des sections,
//  des lignes. L'écran la rend (virtualisée, filtrable, cliquable), le service
//  PDF la rend aussi (paginée). Aucune des deux ne peut montrer autre chose que
//  l'autre — et une fiche nouvelle est imprimable sans écrire une ligne de PDF.
//
//  ⚠️ « Ça va se remplir demain, il y a quinze départements, beaucoup de choses
//  vont y arriver. » Rien ici ne suppose une taille : ni la modale, ni le
//  document. Ce qui plafonne aujourd'hui casse le jour de la montée en charge,
//  c'est-à-dire le jour où l'on regarde.
// ════════════════════════════════════════════════════════════════════════════

/// Une ligne : un libellé, éventuellement des colonnes, une valeur.
class LigneFiche {
  const LigneFiche({
    required this.titre,
    required this.valeur,
    this.sousTitre,
    this.colonnes = const <String>[],
    this.onTap,
  });

  final String titre;

  /// Le chiffre de droite — celui que l'œil cherche.
  final String valeur;

  final String? sousTitre;

  /// Colonnes intermédiaires, imprimées entre le libellé et la valeur.
  /// Une section doit alors déclarer autant d'en-têtes (`enTetes`).
  final List<String> colonnes;

  /// Descendre d'un cran (un département vers ses établissements, un
  /// établissement vers sa fiche). `null` = ligne inerte.
  ///
  /// ⚠️ Ignoré à l'impression : un PDF ne se clique pas. Ce que le clic
  /// révélerait doit donc exister comme fiche imprimable à son tour, jamais
  /// comme seule façon d'atteindre une information.
  final void Function(BuildContext context)? onTap;

  bool contient(String motif) {
    if (motif.isEmpty) return true;
    final m = motif.toLowerCase();
    return titre.toLowerCase().contains(m) ||
        (sousTitre ?? '').toLowerCase().contains(m) ||
        valeur.toLowerCase().contains(m) ||
        colonnes.any((c) => c.toLowerCase().contains(m));
  }
}

/// Un bloc de lignes sous un titre.
class SectionFiche {
  const SectionFiche({
    required this.titre,
    required this.lignes,
    this.enTetes = const <String>[],
    this.flex = const <int>[],
    this.note,
    this.videLabel = 'Aucune ligne à afficher.',
  });

  final String titre;
  final List<LigneFiche> lignes;

  /// En-têtes du tableau imprimé : libellé, colonnes…, valeur.
  final List<String> enTetes;

  /// Largeurs relatives des colonnes imprimées. Vide = réparti.
  final List<int> flex;

  /// Commentaire sous le dernier bloc du tableau (un total, une moyenne).
  final String? note;

  final String videLabel;

  int get nbColonnes => lignes.isEmpty ? 0 : lignes.first.colonnes.length;

  /// ⚠️ Se répare au lieu de planter. Un en-tête oublié ne doit pas empêcher un
  /// document de sortir : `table()` lève dès que les longueurs divergent, et un
  /// PDF qui n'existe pas est bien pire qu'un en-tête générique.
  List<String> get enTetesEffectifs {
    final n = 2 + nbColonnes;
    if (enTetes.length == n) return enTetes;
    return ['Libellé', for (var i = 0; i < n - 2; i++) '—', 'Valeur'];
  }

  List<int> get flexEffectif {
    final n = 2 + nbColonnes;
    if (flex.length == n) return flex;
    return [4, for (var i = 0; i < n - 2; i++) 2, 2];
  }

  /// Vrai dès qu'une ligne porte un sous-titre sans colonnes : le libellé
  /// imprimé tient alors sur deux lignes.
  bool get libelleSurDeuxLignes =>
      nbColonnes == 0 && lignes.any((l) => (l.sousTitre ?? '').isNotEmpty);

  SectionFiche filtree(String motif) => SectionFiche(
        titre: titre,
        lignes: [
          for (final l in lignes)
            if (l.contient(motif)) l,
        ],
        enTetes: enTetes,
        flex: flex,
        note: note,
        videLabel: videLabel,
      );
}

/// Une barre d'exécution (0..1). Deux barres superposées disent en un coup
/// d'œil ce que trois paragraphes n'expliquent pas : le retard entre ce qui
/// est consommé et ce qui est réglé.
class BarreFiche {
  const BarreFiche({
    required this.label,
    required this.valeur,
    required this.couleur,
    this.legende,
  });

  final String label;
  final double valeur;
  final Color couleur;
  final String? legende;
}

/// La fiche complète.
class FicheDetail {
  const FicheDetail({
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.total,
    required this.totalLabel,
    required this.nomFichier,
    this.sousTitre,
    this.chiffres = const <(String, String)>[],
    this.barres = const <BarreFiche>[],
    this.sections = const <SectionFiche>[],
    this.notes = const <String>[],
    this.filtre = '',
  });

  final String titre;
  final IconData icone;
  final Color couleur;

  /// Le nombre en tête, déjà formaté (`fmtXaf`, `fmtInt`…).
  final String total;
  final String totalLabel;

  /// Base du nom de fichier PDF, sans extension.
  final String nomFichier;

  final String? sousTitre;

  /// Chiffres secondaires du bandeau — (libellé, valeur).
  final List<(String, String)> chiffres;

  final List<BarreFiche> barres;
  final List<SectionFiche> sections;

  /// Paragraphes de fin : ce que le lecteur doit savoir avant de citer la
  /// fiche. Imprimés comme à l'écran.
  final List<String> notes;

  /// Filtre actif. Non vide = la fiche est une VUE, et le document le dit.
  final String filtre;

  int get nbLignes =>
      sections.fold(0, (somme, s) => somme + s.lignes.length);

  /// ⚠️ On imprime CE QUI EST À L'ÉCRAN. Sortir la liste entière pendant que
  /// la modale n'en montre que trois lignes produirait un document que
  /// personne n'a vu — et c'est celui-là qui partirait en réunion.
  FicheDetail filtree(String motif) {
    final m = motif.trim();
    if (m.isEmpty) return this;
    return FicheDetail(
      titre: titre,
      icone: icone,
      couleur: couleur,
      total: total,
      totalLabel: totalLabel,
      nomFichier: nomFichier,
      sousTitre: sousTitre,
      chiffres: chiffres,
      barres: barres,
      sections: [
        for (final s in sections) s.filtree(m),
      ],
      notes: notes,
      filtre: m,
    );
  }
}
