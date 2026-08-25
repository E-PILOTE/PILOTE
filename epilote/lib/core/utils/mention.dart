// ════════════════════════════════════════════════════════════════════════════
//  MENTIONS — barème officiel du METP, source unique.
//
//  Ce barème vivait en trois exemplaires : `GradeModel.mention`,
//  `mentionFor()` dans le module Bulletins, et la fonction SQL `get_mention()`.
//  Deux d'entre eux avaient dérivé de deux points, si bien qu'un bulletin
//  affichait « Très Bien » pour 15/20 et — plus grave — « Passable » pour
//  8/20, une note d'échec présentée comme une réussite.
//
//  D'où ce fichier : un seul endroit côté Dart, tenu identique à
//  `database/migrations/0059_get_mention_bareme_officiel.sql`. Toute
//  modification doit toucher les deux, sinon la mention change selon qu'on la
//  lit à l'écran ou en base.
//
//    Excellent    ≥ 18
//    Très Bien    ≥ 16
//    Bien         ≥ 14
//    Assez Bien   ≥ 12
//    Passable     ≥ 10
//    Insuffisant  < 10   ← la barre de réussite est 10/20
// ════════════════════════════════════════════════════════════════════════════

/// Mention correspondant à une moyenne sur 20.
///
/// `null` en entrée = pas de moyenne calculable (aucune note connue) : on
/// renvoie un tiret plutôt qu'« Insuffisant », qui accuserait à tort un élève
/// dont les notes ne sont simplement pas encore saisies.
String mentionFor(double? average) {
  if (average == null) return '—';
  if (average >= 18) return 'Excellent';
  if (average >= 16) return 'Très Bien';
  if (average >= 14) return 'Bien';
  if (average >= 12) return 'Assez Bien';
  if (average >= 10) return 'Passable';
  return 'Insuffisant';
}

/// Seuil de réussite, sur 20. Distinct du barème des mentions : une moyenne
/// peut être « Insuffisant » sans être en dessous de la barre dans un autre
/// système — ici les deux coïncident, mais la constante reste nommée.
const double kPassingMark = 10.0;

/// Vrai si la moyenne atteint la barre de réussite.
bool isPassing(double? average) => average != null && average >= kPassingMark;
