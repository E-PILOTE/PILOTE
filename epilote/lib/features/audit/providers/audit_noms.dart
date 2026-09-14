// ════════════════════════════════════════════════════════════════════════════
//  UN NOM DE REMPLACEMENT N'EST PAS UNE ATTRIBUTION
//
//  Le journal d'audit répond à UNE question : qui a fait quoi. Quand la
//  résolution des noms échouait, six `catch (_) {}` laissaient les valeurs de
//  repli s'installer — « Système » dans la liste, « Utilisateur » dans le top
//  des acteurs. Ce ne sont pas des étiquettes manquantes : ce sont des
//  RÉPONSES FAUSSES à la question du registre. « Système » exonère celui qui a
//  réellement agi ; sur une suppression, cela déplace la responsabilité d'une
//  personne vers la plateforme.
//
//  On distingue donc trois cas qui se confondaient en un seul :
//   • pas d'auteur du tout (`user_id` nul) → « Système », et c'est VRAI ;
//   • auteur connu, nom illisible (lecture en échec) → [kNomNonResolu] ;
//   • auteur connu, profil absent (compte supprimé) → [kCompteIntrouvable].
// ════════════════════════════════════════════════════════════════════════════

/// Le nom n'a pas pu être lu. **Jamais** « Système » : voir ci-dessus.
const kNomNonResolu = 'Nom non résolu';

/// La lecture a réussi, le profil n'existe plus. Un compte supprimé reste
/// responsable de ce qu'il a fait — c'est même la raison d'être du registre.
const kCompteIntrouvable = 'Compte supprimé';
