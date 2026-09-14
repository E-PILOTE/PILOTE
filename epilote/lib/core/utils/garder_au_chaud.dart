import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GARDER UNE LECTURE AU CHAUD, MAIS PAS POUR TOUJOURS
//
//  ── CE QUE ÇA CORRIGE (mesuré le 2026-09-06) ──────────────────────────────
//  35 providers des espaces `super_admin` et `admin_groupe` étaient
//  `autoDispose` sans `ref.keepAlive()` : quitter l'écran DÉTRUIT la donnée, y
//  revenir la retélécharge en entier. Sur une liaison congolaise, chaque
//  aller-retour dans la navigation se paie en secondes — pour des chiffres qui
//  n'ont pas bougé.
//
//  ── POURQUOI PAS UN `keepAlive()` NU ──────────────────────────────────────
//  Parce qu'un `keepAlive()` sans fin garde la donnée pour toute la durée de la
//  session. Un ministère laisse l'application ouverte la journée entière : le
//  soir, il regarderait les chiffres du matin sans le savoir. Le silence d'une
//  donnée périmée est le même défaut que le silence d'une lecture ratée.
//
//  On garde donc au chaud PENDANT UN TEMPS BORNÉ. Au-delà, la donnée se libère
//  et la visite suivante relit. C'est le compromis que font les grandes
//  plateformes, et il tient en dix lignes.
//
//  ── CE QUE ÇA NE REMPLACE PAS ─────────────────────────────────────────────
//  ⚠️ Une écriture doit TOUJOURS invalider son provider. Sans cela, on crée
//  une licence et on ne la voit pas apparaître pendant cinq minutes — un défaut
//  bien pire que la lenteur qu'on corrige. Le cache accélère la lecture ; il ne
//  dispense jamais de dire « ceci vient de changer ».
// ════════════════════════════════════════════════════════════════════════════

/// Durée par défaut pour une donnée de gestion — écoles, frais, licences,
/// comptes. Elle bouge à la journée, pas à la minute.
const Duration kChaudCourant = Duration(minutes: 5);

/// Durée pour ce qui porte un STATUT CONTRACTUEL — licence de tutelle, droit
/// d'accès après suspension pour impayé.
///
/// ⚠️ Volontairement courte. Ces états changent depuis l'espace du fondateur,
/// sur une AUTRE machine, et aucun temps réel ne les suit ici. Une minute rend
/// la navigation fluide sans laisser un réseau suspendu se croire encore ouvert
/// tout un quart d'heure. Le serveur refuse de toute façon — l'écran ne fait
/// qu'expliquer — mais expliquer faux reste expliquer faux.
const Duration kChaudContrat = Duration(minutes: 1);

/// Durée pour un RÉFÉRENTIEL — types d'établissement, niveaux, vocabulaire
/// d'examen, versions publiées. Ces tables changent quelques fois par an.
const Duration kChaudReferentiel = Duration(minutes: 20);

/// Garde le résultat de ce provider en mémoire pendant [pendant], puis le
/// libère.
///
/// À appeler en première ligne du corps d'un provider `autoDispose`, à la place
/// de `ref.keepAlive()` :
///
/// ```dart
/// final xProvider = FutureProvider.autoDispose<X>((ref) async {
///   garderAuChaud(ref);
///   ...
/// });
/// ```
///
/// Le minuteur est annulé si le provider disparaît avant l'échéance — sans
/// quoi il maintiendrait en vie un objet que plus personne ne regarde.
KeepAliveLink garderAuChaud(Ref ref, {Duration pendant = kChaudCourant}) {
  final lien = ref.keepAlive();
  final minuteur = Timer(pendant, lien.close);
  ref.onDispose(minuteur.cancel);
  return lien;
}
