// ════════════════════════════════════════════════════════════════════════════
//  MENTIONS — barème officiel du METP, source unique.
//
//  Ce barème vivait en QUATRE exemplaires : `GradeModel.mention`,
//  `mentionFor()` dans le module Bulletins, `AppConstants.seuil*`, et la
//  fonction SQL `get_mention()`. Deux d'entre eux avaient dérivé de deux
//  points, si bien qu'un bulletin affichait « Très Bien » pour 15/20 et — plus
//  grave — « Passable » pour 8/20, une note d'échec présentée comme une
//  réussite.
//
//  D'où ce fichier, et il est désormais le SEUL. Les constantes mortes
//  d'`AppConstants` et la fonction SQL `get_mention()` ont été supprimées le
//  2026-08-25 (migration 0117) : aucune des deux n'avait d'appelant, donc
//  aucun test — et une règle qu'on ne teste pas dérive en silence.
//
//  ⚠️ Ne pas recréer de copie « pour le serveur ». L'application est
//  offline-first : elle doit savoir calculer une mention sans réseau, donc
//  l'autorité est ici. Si un besoin SQL apparaît, il faudra un test qui
//  compare les deux barèmes ligne à ligne.
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
