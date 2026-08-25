// ════════════════════════════════════════════════════════════════════════════
//  Reprise sur session Supabase morte
//
//  ── LE PROBLÈME ────────────────────────────────────────────────────────────
//  `super_admin` et `admin_groupe` interrogent Supabase EN DIRECT. Quand leur
//  jeton d'accès expire et que le renouvellement échoue, chaque requête revient
//  en `PGRST303 — JWT expired`. L'application n'en tirait aucune conséquence :
//  elle continuait d'interroger avec un jeton mort, indéfiniment, en affichant
//  l'exception brute. Le bouton « Réessayer » échouait à l'identique. La
//  plateforme entière paraissait morte alors qu'une reconnexion suffisait.
//
//  Trois scénarios ordinaires y mènent sur un poste d'établissement :
//    • la machine dort tout un week-end, le jeton de rafraîchissement expire ;
//    • la liaison tombe au moment précis du renouvellement ;
//    • deux copies de l'application tournent — la rotation du jeton de
//      rafraîchissement révoque celui de l'autre instance. (Le verrou
//      d'instance unique dans `windows/runner/main.cpp` traite ce cas-là.)
//
//  ── LE CHOIX D'IMPLÉMENTATION ──────────────────────────────────────────────
//  L'interception est GLOBALE, via un `ProviderObserver` : `providerDidFail`
//  voit échouer n'importe quel provider, y compris les erreurs portées par un
//  `AsyncValue`. On couvre donc les 167 sites d'appel sans en toucher un seul,
//  et un écran écrit demain est couvert d'office.
//
//  ── CE QU'ON NE FAIT PAS ───────────────────────────────────────────────────
//  On ne purge RIEN. `signOut()` est sans danger pour la base locale depuis le
//  2026-08-04 (cf. `powersync_service.dart`) : une déconnexion subie ne doit
//  jamais coûter son corpus hors ligne à une école.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Message à afficher à l'agent quand sa session est tombée toute seule.
/// `null` tant que rien ne s'est produit. Lu par l'écran de connexion.
final sessionMorteMessageProvider = StateProvider<String?>((ref) => null);

const String _kMessageSessionExpiree =
    'Votre session a expiré. Reconnectez-vous pour continuer — '
    'aucune donnée n’a été perdue.';

/// Vrai si [error] traduit un jeton d'accès mort, et non une erreur métier.
///
/// On reste volontairement étroit : élargir ferait passer une panne réseau ou
/// un refus RLS pour une expiration, et déconnecterait un agent qui travaille.
bool estSessionMorte(Object error) {
  if (error is PostgrestException) {
    // PGRST301 : JWT invalide · PGRST303 : JWT expiré
    if (error.code == 'PGRST301' || error.code == 'PGRST303') return true;
    final m = error.message.toLowerCase();
    return m.contains('jwt expired') ||
        m.contains('jwt is expired') ||
        m.contains('invalid claim');
  }
  // Le jeton de rafraîchissement lui-même a disparu ou a été révoqué : plus
  // aucune reprise automatique n'est possible.
  if (error is AuthApiException) {
    final c = error.code;
    return c == 'refresh_token_not_found' || c == 'refresh_token_already_used';
  }
  return false;
}

/// Tente de sauver la session ; à défaut, déconnecte proprement.
///
/// Sérialisé : cent providers peuvent échouer d'un coup sur le même écran, on
/// ne veut qu'UNE tentative de renouvellement, pas cent.
class RecuperationSession {
  RecuperationSession._();

  static Future<void>? _enCours;

  static Future<void> declencher(ProviderContainer container) {
    return _enCours ??= _executer(container).whenComplete(() {
      _enCours = null;
    });
  }

  static Future<void> _executer(ProviderContainer container) async {
    final auth = Supabase.instance.client.auth;

    // Déjà déconnecté : le routeur a fait son travail, rien à ajouter.
    if (auth.currentSession == null) return;

    try {
      await auth.refreshSession();
      appLogger.i('Session renouvelée après un jeton expiré.');
      return;
    } on Object catch (e, st) {
      appLogger.w('Renouvellement de session impossible — déconnexion',
          error: e, stackTrace: st);
    }

    // Le renouvellement a échoué : on rend la main à l'agent plutôt que de le
    // laisser devant un écran d'erreur qui ne partira jamais. Le `redirect` du
    // routeur l'emmène vers la connexion — ou vers la reprise de poste si
    // l'appareil se reconnaît, ce qui évite d'enfermer dehors une école dont
    // personne ne connaît le mot de passe.
    container.read(sessionMorteMessageProvider.notifier).state =
        _kMessageSessionExpiree;
    try {
      await auth.signOut();
    } on Object catch (e, st) {
      appLogger.w('Déconnexion après session morte en échec',
          error: e, stackTrace: st);
    }
  }
}

/// Branche la reprise sur TOUTES les erreurs de providers de l'application.
class ObservateurSessionMorte extends ProviderObserver {
  const ObservateurSessionMorte();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (!estSessionMorte(error)) return;
    // Hors du cycle de construction : on ne modifie pas un provider pendant
    // qu'un autre se construit.
    scheduleMicrotask(() => RecuperationSession.declencher(container));
  }
}
