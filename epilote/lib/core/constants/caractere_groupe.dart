/// ─── SECTEUR ET CARACTÈRE — DEUX QUESTIONS, DEUX CHAMPS ───────────────────
///
/// ⚠️ CE FICHIER EXISTE PARCE QUE LA CONFUSION A COÛTÉ TROIS CHOIX MORTS.
/// Le formulaire de groupe proposait « Public · Privé · Catholique · Islamique
/// · Protestant » dans UN seul champ. L'enum `group_type` n'en accepte que
/// deux : créer un groupe catholique échouait sur un 22P02, et le filtre
/// « Type » de la liste ne pouvait jamais rendre une ligne.
///
/// Parce que `group_type` ne dit pas « quel genre de groupe », il dit LE
/// SECTEUR — le binôme juridique dont dépendent le barème de frais
/// (`adminGroupePublicProvider`), le type de l'école (`schools.school_type`,
/// verrouillé par 0060) et le `secteur` rendu par `tutelle_groupes()`. Une
/// école catholique EST une école privée : ranger sa confession dans la
/// colonne du secteur, c'est perdre le secteur.
///
/// Le caractère a donc sa propre colonne depuis la migration 0180. Les deux
/// listes vivent ICI, ensemble, pour qu'on ne puisse plus les confondre en
/// les recopiant — elles l'étaient déjà en quatre exemplaires : le formulaire,
/// le filtre de la liste, `groupTypeLabel` et `_typeLabel` de l'espace groupe,
/// ce dernier avec un troisième vocabulaire inventé (« confessionnel »,
/// « ministere », « reseau ») qu'aucune base n'a jamais accepté.
library;

// ─── Le secteur ─────────────────────────────────────────────────────────────

/// Les deux seules valeurs de `school_groups.group_type`, dans l'ordre
/// d'affichage. ⚠️ NE JAMAIS ÉTENDRE : voir l'en-tête et la migration 0180.
const kSecteursGroupe = <String>['public', 'prive'];

/// Libellé du secteur. Rend la valeur brute pour un code inconnu — la voir
/// telle quelle à l'écran vaut mieux que la traduire en « Autre » et perdre
/// l'information qu'une donnée aberrante existe.
String libelleSecteur(String? s) => switch (s) {
      'public' => 'Public',
      'prive' => 'Privé',
      _ => s == null || s.isEmpty ? '—' : s,
    };

/// Vrai si le groupe relève de l'enseignement public.
bool estSecteurPublic(String? s) => s == 'public';

// ─── Le caractère ───────────────────────────────────────────────────────────

/// Les caractères possibles d'un groupe PRIVÉ, dans l'ordre d'affichage.
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

/// Le caractère se saisit-il sur ce groupe ?
///
/// Seulement sur un groupe PRIVÉ : un établissement public n'a pas de
/// caractère propre. ⚠️ C'est une règle d'ÉCRAN, délibérément pas une
/// contrainte de base (migration 0180) — si le terrain nous détrompe, c'est
/// cette ligne qui change, pas une migration.
bool caractereSeSaisit(String? secteur) => secteur == 'prive';
