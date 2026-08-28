// ════════════════════════════════════════════════════════════════════════════
//  UNE ERREUR MÉTIER PORTE UNE PHRASE, PAS UNE TRACE
//
//  L'application pré-valide beaucoup d'écritures AVANT que la base ne les
//  refuse : une classe qui existe déjà, un INE déjà rattaché, un ouvrage déjà
//  emprunté, un poste budgétaire déjà ouvert. Ce n'est pas de la coquetterie —
//  un refus de la base est un code fatal pour le connecteur PowerSync, qui
//  jette le LOT ENTIER d'écritures en attente sur le poste.
//
//  Chacun de ces gardes lève une phrase écrite POUR L'AGENT, en français, qui
//  dit la cause et souvent quoi faire. Levées en `Exception` ou en
//  `StateError`, elles tombaient toutes dans le repli de `messageErreur` et
//  s'affichaient « Une erreur inattendue est survenue. (_Exception) ».
//  Quarante gardes parlaient dans le vide : l'agent voyait un générique, ne
//  savait pas quoi corriger, et recommençait le même geste.
//
//  ── POURQUOI UN TYPE, ET PAS UNE DEVINETTE SUR LE TEXTE ───────────────────
//  `message_erreur_test.dart` exige depuis l'origine qu'un `StateError('boom')`
//  NE remonte PAS son détail : une erreur venue d'une bibliothèque est un bug,
//  pas un message. Les deux règles sont justes, et seul le TYPE les sépare.
//  Écrire `ErreurMetier`, c'est déclarer « ceci s'adresse à la personne devant
//  l'écran » ; tout le reste reste un incident technique.
// ════════════════════════════════════════════════════════════════════════════

/// Une règle métier refuse l'opération, et [message] l'explique à l'agent.
///
/// Le texte est affiché TEL QUEL par `messageErreur` : il doit être une phrase
/// française, compréhensible sans connaître la base, et dire quoi faire quand
/// il y a quelque chose à faire.
///
/// À ne PAS utiliser pour un incident technique (service indisponible, réponse
/// mal formée, invariant interne rompu) : ceux-là restent des `Exception` ou
/// des `StateError`, et l'agent reçoit un message générique avec un code court
/// pour le support.
class ErreurMetier implements Exception {
  const ErreurMetier(this.message);

  /// Phrase destinée à l'agent, affichée mot pour mot.
  final String message;

  @override
  String toString() => message;
}
