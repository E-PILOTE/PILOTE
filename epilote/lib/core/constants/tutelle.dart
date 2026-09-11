/// ─── LE MINISTÈRE DE TUTELLE, EN UN SEUL EXEMPLAIRE ────────────────────────
///
/// La République du Congo confie l'enseignement scolaire à DEUX ministères :
///
///   • `mepsa` — Enseignement Préscolaire, Primaire, Secondaire et de
///     l'Alphabétisation : la voie GÉNÉRALE (école, CEG, lycée général).
///   • `metp`  — Enseignement Technique et Professionnel : la voie TECHNIQUE
///     et professionnelle (CET, lycée technique, lycée professionnel, centre
///     de métiers).
///
/// (Un troisième ministère couvre l'Enseignement supérieur — hors périmètre
/// d'une plateforme scolaire.)
///
/// ⚠️ POURQUOI CE FICHIER EXISTE. Le libellé et la couleur de la tutelle
/// étaient écrits TROIS fois — `_libelleTutelle` dans le PDF de l'état de
/// rentrée, et deux `tutColor` locaux dans les tableaux de bord d'examens. Le
/// barème des mentions avait déjà appris ce que coûtent quatre exemplaires
/// d'une même règle : l'un d'eux finit par diverger, et c'est celui-là qui
/// s'imprime.
///
/// ⚠️ LA TUTELLE APPARTIENT AU GROUPE (migration 0153), pas à l'école :
/// l'école en hérite par déclencheur. Un groupe n'est jamais mixte — chaque
/// ministère agrée ses propres établissements privés, par sa propre commission.
library;

/// Les deux tutelles, dans l'ordre où on les présente.
const kTutelles = <String>['mepsa', 'metp'];

/// Sigle court — celui qui figure sur les états ministériels.
///
/// ⚠️ Rend `null` pour une valeur absente ou inconnue. Ne JAMAIS retomber sur
/// « MEPSA » : ranger d'office un lycée technique sous le ministère de
/// l'enseignement général est une erreur qu'aucun écran ne rattraperait.
String? sigleTutelle(String? t) => switch (t) {
      'mepsa' => 'MEPSA',
      'metp' => 'METP',
      _ => null,
    };

/// Sigle pour un affichage qui ne supporte pas le vide (cellule de tableau,
/// champ de PDF). Le tiret DIT l'absence au lieu de la masquer.
String sigleTutelleOuTiret(String? t) => sigleTutelle(t) ?? '—';

/// Intitulé complet du ministère.
String? nomTutelle(String? t) => switch (t) {
      'mepsa' =>
        "Ministère de l'Enseignement Préscolaire, Primaire, Secondaire "
            "et de l'Alphabétisation",
      'metp' =>
        "Ministère de l'Enseignement Technique et Professionnel",
      _ => null,
    };

/// Ce que la tutelle recouvre, en une ligne — le texte qui aide à choisir.
String? domaineTutelle(String? t) => switch (t) {
      'mepsa' => 'Enseignement général — école, CEG, lycée général',
      'metp' => 'Technique et professionnel — CET, lycée technique, centre de métiers',
      _ => null,
    };

/// Vrai si [t] est une tutelle connue. Sert aux validateurs de formulaire.
bool tutelleConnue(String? t) => t != null && kTutelles.contains(t);

// ─── UN MINISTÈRE N'EST PAS UN GROUPE SCOLAIRE ──────────────────────────────
//
// ⚠️ Il y a DEUX ministères au Congo, et ils vivent dans la même table que les
// groupes privés parce qu'ils exploitent eux aussi des écoles. Cette
// commodité de modèle ne doit pas remonter à l'écran : afficher « MEPSA » à
// côté de « Réseau Saint-Pierre », dans la même pastille et la même couleur,
// range les deux sur la même ligne et laisse croire qu'ils ne diffèrent que
// par le sigle.
//
// Ils diffèrent par NATURE. Un ministère n'a pas de clients, il a un réseau ;
// il n'est pas agréé, il agrée ; il ne remonte pas d'état à sa tutelle, il la
// tient. Ces deux fonctions donnent le mot juste, en un seul endroit — le
// libellé de la tutelle avait déjà été écrit trois fois avant d'atterrir ici.

/// Ce qu'un groupe EST, avant son nom.
///
/// [estTutelle] = `school_groups.administre_referentiel_national`.
String natureGroupe({required bool estTutelle}) =>
    estTutelle ? 'Ministère de tutelle' : 'Groupe scolaire';

/// Nom d'usage d'un ministère — « Ministère MEPSA ».
///
/// Rend `null` hors d'un ministère connu : il n'y a rien à nommer, et inventer
/// « Ministère » tout court désignerait n'importe lequel des deux.
String? nomUsageMinistere(String? t) {
  final sigle = sigleTutelle(t);
  return sigle == null ? null : 'Ministère $sigle';
}

// La COULEUR de la tutelle vit dans `core/widgets/admin_tokens.dart`
// (`couleurTutelle`) : ce fichier-ci reste du Dart pur, comme le reste de
// `core/constants/`, pour rester utilisable depuis un test sans Flutter.
