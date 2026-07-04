// Les 4 ports du module licence. Chaque port existe parce qu'il crée une
// COUTURE DE TEST sur une préoccupation infernale à tester avec un vrai
// implémenteur (crypto, coffre plateforme, réseau, temps). Voir ADR-0005.
//
// Dart pur : ces abstractions sont définies dans le domaine ; leurs
// implémentations vivent dans `infrastructure/` (règle de dépendance).

/// État de confiance persisté atomiquement dans le coffre (fusionne licence +
/// repères anti-rejeu, cf. C1). Un seul enregistrement, une seule écriture.
class TrustState {
  const TrustState({
    required this.token,
    required this.version,
    required this.timeHighWater,
    required this.lastSyncAt,
  });

  /// Le JWS compact tel que reçu (re-vérifié au chargement).
  final String token;

  /// Repère de version monotone (anti-rollback) — la valeur la plus sensible.
  final int version;

  /// Repère temporel haute-eau (anti recul d'horloge) — plancher, jamais plafond.
  final DateTime timeHighWater;

  /// Dernière synchro réussie de la licence (horloge 2 / fenêtre de confiance).
  final DateTime lastSyncAt;
}

/// Vérifie la signature d'un token et renvoie ses *claims*, ou `null` si la
/// signature/le format sont invalides. Connaît la crypto + les clés publiques
/// épinglées (dispatch par `kid`). Ne connaît RIEN des règles métier.
abstract interface class SignatureVerifier {
  Future<Map<String, dynamic>?> verifyAndDecode(String token);
}

/// Coffre local du `TrustState`. Écriture ATOMIQUE. Survit à
/// `disconnectAndClear()` de PowerSync (hors SQLite synchronisé).
abstract interface class LicenseStore {
  Future<TrustState?> read();
  Future<void> write(TrustState state);
  Future<void> clear();
}

/// Récupère un token de licence frais, hors-bande (PULL HTTPS). Renvoie `null`
/// si indisponible (hors ligne, erreur) — le service gère en fail-soft.
abstract interface class LicenseGateway {
  Future<String?> fetchLicenseToken();
}

/// Source de temps. `wallNow` = horloge murale (falsifiable) ; `sessionElapsed`
/// = durée monotone depuis le démarrage (non falsifiable en cours de session).
/// Le « meilleur temps connu » se calcule dans l'application via le repère
/// haute-eau, pas ici.
abstract interface class Clock {
  DateTime wallNow();
  Duration sessionElapsed();
}
