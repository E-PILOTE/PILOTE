import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COULEURS DE SÉRIE — pour les GRAPHIQUES, et pour eux seuls
//
//  ── POURQUOI CE FICHIER EXISTE ─────────────────────────────────────────────
//  Les graphes du dépôt peignaient leurs séries avec les jetons de marque
//  (`kNavy`, `kAccent`, `kGreen`). Ces jetons sont justes — pour du TEXTE et de
//  la chrome. Mesurés comme couleurs de DONNÉE sur une carte blanche, ils
//  échouent :
//
//    • `kNavy` #1E3A5F — chroma OKLCH 0,074, sous le plancher de 0,10 : à
//      l'écran il « lit gris ». Une colonne censée porter une identité de série
//      rend un bloc terne. Sa clarté (L 0,346) est également hors de la bande
//      lisible 0,43–0,77.
//    • `kAccent` #FBBC04 — contraste 1,66:1 sur blanc, là où 3:1 est le
//      minimum. Un aplat jaune sur une carte blanche est à la limite du visible.
//
//  Ce n'est pas une question de goût : ces deux nombres se calculent. On ne
//  pouvait pas corriger les jetons eux-mêmes — `test/palette_test.dart` les
//  verrouille au hex près, et à raison : le thème ne doit pas déplacer
//  l'apparence de l'existant. D'où une palette SÉPARÉE, réservée aux séries.
//
//  ── COMMENT CES VALEURS ONT ÉTÉ CHOISIES ───────────────────────────────────
//  Par validation, pas à l'œil. Chaque jeu passe les cinq contrôles (bande de
//  clarté, plancher de chroma, séparation sous déficience de vision des
//  couleurs, plancher en vision normale, contraste sur la surface) :
//
//    Clair  sur #FFFFFF : #3B6FD4, #D97706, #00875A → 5 PASS
//                         (pire paire adjacente ΔE 28,0 protan ; 33,3 normal)
//    Sombre sur #161B22 : #4C8AD9, #C2811A, #12A87C → 5 PASS
//    Melack sur #0B1017 : les mêmes                 → 5 PASS
//
//  ⚠️ Le sombre n'est PAS le clair éclairci. La bande de clarté lisible sur
//  fond sombre est 0,48–0,67 — plus étroite ET plus basse que l'intuition ne le
//  suggère : des teintes pâles (#6BA1E8, #34D399) la dépassent et se mettent à
//  vibrer sur le fond. Chaque mode a ses propres paliers, validés contre SA
//  surface.
//
//  ⚠️ Avant de toucher une seule de ces valeurs, refaire tourner la validation.
//  Une couleur « qui paraît mieux » est exactement la façon dont les deux
//  défauts ci-dessus sont arrivés.
// ════════════════════════════════════════════════════════════════════════════

/// Les couleurs de série d'un graphique, pour le thème courant.
///
/// L'ordre est FIXE : une série garde sa teinte quel que soit le nombre de
/// séries affichées. Filtrer une série ne doit jamais repeindre les autres —
/// un lecteur qui a appris « le bleu, c'est validé » ne doit pas être trahi.
@immutable
class ChartPalette {
  const ChartPalette({
    required this.serie1,
    required this.serie2,
    required this.serie3,
  });

  /// Série principale (le flux qu'on vient lire).
  final Color serie1;

  /// Série secondaire, typiquement empilée sur la première.
  final Color serie2;

  /// Troisième série — un stock, une courbe de fond.
  final Color serie3;

  static const ChartPalette _clair = ChartPalette(
    serie1: Color(0xFF3B6FD4),
    serie2: Color(0xFFD97706),
    serie3: Color(0xFF00875A),
  );

  static const ChartPalette _sombre = ChartPalette(
    serie1: Color(0xFF4C8AD9),
    serie2: Color(0xFFC2811A),
    serie3: Color(0xFF12A87C),
  );

  /// La palette du thème courant.
  ///
  /// On lit la luminosité du `Theme` et non `activePalette` : c'est le `Theme`
  /// qui reconstruit l'arbre, donc le seul à garantir que la couleur suive un
  /// changement de thème sans redémarrage.
  static ChartPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _sombre : _clair;
}
