import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/active_agent_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT DU CODE PIN, VU DEPUIS « MON PROFIL »
//
//  ── POURQUOI CE CODE N'EST PAS UN MOT DE PASSE ────────────────────────────
//  Le mot de passe ouvre le COMPTE, côté serveur, pour tous les appareils. Le
//  code PIN ouvre une IDENTITÉ AU CLAVIER, sur CET appareil, sans réseau : il
//  est haché localement (`agent_pin_<id>` dans les préférences) et n'est jamais
//  synchronisé. Deux objets différents, deux endroits pour les changer — d'où
//  deux cartes distinctes dans « Sécurité », et jamais un bouton commun.
//
//  ── LA CONSÉQUENCE QUI SURPREND ───────────────────────────────────────────
//  Changer son code ici ne le change QUE sur ce poste. Dans une école à trois
//  ordinateurs, l'ancien code continue d'ouvrir les deux autres. Ce n'est pas
//  un défaut à corriger : un code qui se propagerait devrait passer par le
//  réseau, et le verrou cesserait de fonctionner le jour où le réseau manque —
//  c'est-à-dire précisément le jour où l'on en a besoin. L'écran le DIT, au
//  lieu de laisser croire à un changement global.
//
//  ── L'ASYMÉTRIE AVEC LE RESTE DE LA CARTE « SÉCURITÉ » ────────────────────
//  Mot de passe et « fermer les sessions » sont refusés quand la session
//  appartient à quelqu'un d'autre (`estLeCompteAppareil` faux) : on ne touche
//  pas au compte d'un collègue. Le code PIN, lui, est ouvert exactement dans
//  ce cas-là — c'est le code de l'agent au clavier, sur sa machine. Refuser ici
//  reviendrait à ne jamais laisser changer son code à personne d'autre qu'au
//  compte qui a enrôlé l'appareil : la direction.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que « Mon profil » sait du code PIN de l'agent affiché, sur CE poste.
class EtatCodePin {
  const EtatCodePin({
    required this.sApplique,
    this.existe = false,
    this.poseLe,
    this.resetDemande = false,
  });

  /// Le verrou de poste concerne-t-il ce rôle ? (cf. [agentLockApplies] :
  /// ni `super_admin`, ni `admin_groupe`, ni les familles.) Faux ⇒ la carte ne
  /// s'affiche pas du tout : proposer un code à qui n'en aura jamais besoin
  /// n'ajoute pas de sécurité, seulement une case à remplir.
  final bool sApplique;

  /// Un code est-il enrôlé sur CET appareil pour cette personne ?
  final bool existe;

  /// Quand il a été posé ici — la seule date honnête dont on dispose, puisque
  /// rien de tout cela ne remonte au serveur.
  final DateTime? poseLe;

  /// Un administrateur de groupe a demandé la réinitialisation, postérieurement
  /// au code local : celui-ci ne vaut plus rien, l'agent doit en reposer un.
  ///
  /// ⚠️ Faux quand aucun code n'existe sur ce poste, même si la demande est là :
  /// annoncer « votre ancien code ne fonctionne plus » à qui n'en a jamais posé
  /// ici lui ferait chercher un code qu'il n'a jamais eu.
  final bool resetDemande;

  /// Poser un code (première fois, ou après un reset) plutôt que le changer.
  /// Dans ce cas on ne peut évidemment pas réclamer l'ancien.
  bool get aPoser => !existe || resetDemande;
}

/// État du code PIN pour un profil donné, sur cet appareil.
///
/// `family` sur l'identifiant plutôt que sur « l'agent actif » : la page montre
/// la fiche de la personne au clavier, et c'est bien SON code qu'on manipule —
/// pas celui du compte qui a authentifié la machine.
final etatCodePinProvider =
    FutureProvider.autoDispose.family<EtatCodePin, ({String id, String role})>(
        (ref, cible) async {
  if (!agentLockApplies(cible.role)) {
    return const EtatCodePin(sApplique: false);
  }

  final svc = ref.watch(agentPinServiceProvider);
  final existe = await svc.hasPin(cible.id);
  final poseLe = await svc.pinSetAt(cible.id);

  // `pin_reset_requested_at` arrive par PowerSync : la demande d'un
  // administrateur de groupe est visible ici même hors ligne, dès la synchro
  // suivante. Lecture directe plutôt que via `switchableAgentsProvider`, qui
  // ne liste que les collègues de l'école et pourrait ne pas contenir la
  // personne affichée (poste personnel, annuaire encore vide).
  DateTime? resetLe;
  try {
    final rows = await db.getAll(
      'SELECT pin_reset_requested_at FROM profiles WHERE id = ? LIMIT 1',
      [cible.id],
    );
    final brut = rows.isEmpty ? null : rows.first['pin_reset_requested_at'];
    if (brut is String) resetLe = DateTime.tryParse(brut);
  } catch (_) {
    // Base locale absente (espace en ligne) : sans agentLockApplies on n'est
    // pas censé arriver ici, mais une lecture ratée ne doit pas masquer la
    // carte — au pire on n'affiche pas la demande de reset.
  }

  return EtatCodePin(
    sApplique: true,
    existe: existe,
    poseLe: poseLe,
    resetDemande: existe && pinResetInvalidates(resetLe, poseLe),
  );
});
