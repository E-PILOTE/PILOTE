// ════════════════════════════════════════════════════════════════════════════
//  LES DEUX « DÉCISIONS » — DEUX COLONNES, DEUX SENS, JAMAIS LE MÊME MOT
//
//  Une école prend deux décisions sur un élève, et elles portent le même nom
//  dans deux tables différentes. Les confondre ne lève AUCUNE erreur : les
//  deux colonnes sont du texte libre côté serveur, et les deux fonctions de
//  lecture (`awardFor`, `verdictFor`) rendent simplement `null` sur un code
//  qu'elles ne connaissent pas.
//
//  ── 1. LA DISTINCTION DU CONSEIL DE CLASSE ────────────────────────────────
//  `bulletins.decision` — trois fois par an, un par trimestre. Le conseil
//  APPRÉCIE le travail : Félicitations, Encouragements, Tableau d'honneur,
//  Avertissement (travail ou conduite), Blâme. Il n'oriente pas.
//
//  ── 2. LE VERDICT ANNUEL DE PASSAGE ───────────────────────────────────────
//  `class_enrollments.promotion_decision` — une seule fois, en fin d'année.
//  `passe` · `redouble` · `reoriente`. C'est celui-là qui décide de l'année
//  suivante d'un enfant.
//
//  ── CE QUE COÛTE LA CONFUSION, EXACTEMENT ─────────────────────────────────
//  Écrire « Admis en classe supérieure » dans `bulletins.decision` :
//    • aucune erreur, aucun avertissement, l'écriture réussit ;
//    • `awardFor()` rend `null` — le bulletin s'imprime sans distinction ;
//    • les compteurs du module Conseils restent à zéro, et personne ne
//      cherche pourquoi, puisque la saisie « a marché ».
//  Le sens inverse est pire : un `felicitations` dans `promotion_decision`
//  n'est ni `passe` ni `redouble` — l'élève disparaît des deux listes de fin
//  d'année, et sa réinscription avec lui.
//
//  ── POURQUOI CE FICHIER EXISTE ────────────────────────────────────────────
//  Les deux vocabulaires vivaient chacun dans son écran, mêlés à des couleurs
//  et des icônes, et RIEN ne refusait la valeur de l'autre. Ce fichier est
//  l'autorité : du Dart pur, sans Flutter, lisible par un test. Les listes
//  d'affichage (`councilAwards`, `passageVerdicts`) gardent leurs libellés et
//  leurs couleurs, mais leurs CODES doivent correspondre exactement à ceux-ci
//  — `test/deux_decisions_test.dart` échoue sinon.
//
//  Miroir en base : les contraintes `bulletins_decision_check` et
//  `class_enrollments_promotion_decision_check` (migration 0206).
// ════════════════════════════════════════════════════════════════════════════

/// Distinctions du conseil de classe — `bulletins.decision`.
///
/// Ordre : les trois valorisantes, puis les trois sanctions.
const Set<String> kDistinctionsConseil = {
  'felicitations',
  'encouragements',
  'tableau_honneur',
  'avertissement_travail',
  'avertissement_conduite',
  'blame',
};

/// Verdicts annuels de passage — `class_enrollments.promotion_decision`.
const Set<String> kVerdictsPassage = {
  'passe',
  'redouble',
  'reoriente',
};

/// Vérifie un code de distinction AVANT qu'il n'atteigne la base.
///
/// `null` et la chaîne vide signifient « pas de distinction » — c'est une
/// valeur légitime : la plupart des bulletins n'en portent aucune.
///
/// ⚠️ LÈVE si le code est inconnu, et c'est voulu. Le seul chemin qui mène
/// ici est une liste FIXE de l'interface : un code inconnu n'est pas une
/// saisie utilisateur, c'est une erreur de câblage. La lever fort pendant le
/// développement vaut infiniment mieux que l'écrire en base, où elle
/// deviendrait un bulletin muet que personne ne saura expliquer.
String? distinctionConseilValide(String? code) {
  if (code == null || code.isEmpty) return null;
  if (!kDistinctionsConseil.contains(code)) {
    throw ArgumentError.value(
      code,
      'decision',
      'Pas une distinction de conseil de classe. Attendu : '
          '${kDistinctionsConseil.join(", ")}. '
          '${kVerdictsPassage.contains(code) ? "C'est un VERDICT DE PASSAGE — "
              "il va dans class_enrollments.promotion_decision." : ""}',
    );
  }
  return code;
}

/// Vérifie un verdict de passage AVANT qu'il n'atteigne la base.
/// Voir [distinctionConseilValide] pour la raison de la levée.
String? verdictPassageValide(String? code) {
  if (code == null || code.isEmpty) return null;
  if (!kVerdictsPassage.contains(code)) {
    throw ArgumentError.value(
      code,
      'promotion_decision',
      'Pas un verdict annuel de passage. Attendu : '
          '${kVerdictsPassage.join(", ")}. '
          '${kDistinctionsConseil.contains(code) ? "C'est une DISTINCTION DE "
              "CONSEIL — elle va dans bulletins.decision." : ""}',
    );
  }
  return code;
}
