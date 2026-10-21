/// ─── LE CARACTÈRE D'UN GROUPE SCOLAIRE PRIVÉ ──────────────────────────────
///
/// Laïc, catholique, protestant, islamique… : ce qui décrit le PROMOTEUR.
/// Il a sa propre colonne depuis la migration 0180 (`school_groups.caractere`).
///
/// ⚠️ Le SECTEUR (public / privé) a disparu de l'application le 2026-10-21 :
/// la plateforme ne sert plus que des groupes privés. `kSecteursGroupe`,
/// `libelleSecteur`, `estSecteurPublic` et `caractereSeSaisit` ont été retirés
/// avec lui — un champ qui vaut toujours la même chose est une case morte.
library;

/// Les caractères possibles d'un groupe, dans l'ordre d'affichage.
///
/// ⚠️ `null` n'est pas dans cette liste et n'y sera jamais : « non renseigné »
/// n'est pas un caractère. Un groupe dont personne n'a renseigné le caractère
/// n'est pas laïc pour autant — répondre à sa place serait inventer la donnée.
const kCaracteresGroupe = <String>[
  'laic',
  'catholique',
  'protestant',
  'islamique',
  'autre',
];

/// Libellé du caractère, ou `null` s'il n'est pas renseigné.
String? libelleCaractere(String? c) => switch (c) {
      'laic' => 'Laïc',
      'catholique' => 'Catholique',
      'protestant' => 'Protestant',
      'islamique' => 'Islamique',
      'autre' => 'Autre confession',
      _ => null,
    };

/// Libellé pour un affichage qui ne supporte pas le vide (cellule, PDF).
/// « Non renseigné » DIT le manque au lieu de le masquer derrière un tiret.
String libelleCaractereOuManque(String? c) =>
    libelleCaractere(c) ?? 'Non renseigné';

/// Vrai si [c] est un caractère connu. Sert aux validateurs de formulaire.
bool caractereConnu(String? c) => c != null && kCaracteresGroupe.contains(c);
