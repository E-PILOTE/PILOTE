import 'license.dart';
import 'license_phase.dart';

/// Vue ÉVALUÉE des droits, consommée par l'app (objet valeur immuable).
///
/// Fail-soft de bout en bout : quand aucune licence n'est présente (déploiement
/// progressif, coffre vide, licence illisible), l'entitlement N'ENTRAVE RIEN —
/// c'est exactement le comportement actuel de l'app (aucun enforcement). Le
/// durcissement ne s'active QUE lorsqu'une licence valide est présente.
class Entitlement {
  const Entitlement({required this.license, required this.lastSyncAt});

  /// État « aucune licence » : tout est permis (fail-soft, non-enforcé).
  const Entitlement.none() : license = null, lastSyncAt = null;

  final License? license;
  final DateTime? lastSyncAt;

  bool get isEnforced => license != null;

  /// Verrou plan (route). `true` si non-enforcé OU module présent au plan.
  /// N'est PAS piloté par la phase `readOnly` : une phase `readOnly` laisse
  /// OUVRIR le module (lecture seule) — c'est `canWrite` qui bride les mutations.
  /// Le hard-lock, lui, se gère séparément via [isHardLockedAt] côté route/sidebar
  /// (avec liste d'exemptions), pour ne pas mélanger « module hors plan » et
  /// « module gelé pour impayé ».
  bool grantsModule(String slug) =>
      license == null || license!.grantsModule(slug);

  /// Phase courante (double horloge). `now` = meilleur temps connu (calculé
  /// par la couche application à partir du repère haute-eau).
  LicensePhase phaseAt(DateTime now) {
    final lic = license;
    if (lic == null) return LicensePhase.active;
    return computeLicensePhase(
      validTo: lic.validTo,
      offlineWindow: lic.offlineWindow,
      lastSyncAt: lastSyncAt,
      now: now,
      hardLockEligible: lic.hardLockable,
    );
  }

  /// Écriture autorisée ? `active`/`grace` seulement. Fail-soft : non-enforcé
  /// ⇒ `true` (aucune licence ⇒ phase `active`).
  bool canWriteAt(DateTime now) {
    final p = phaseAt(now);
    return p == LicensePhase.active || p == LicensePhase.grace;
  }

  /// Hard-lock actif ? ⇒ les modules (hors zone neutre) deviennent inaccessibles
  /// (clic mort, mur de renouvellement). Fail-soft : non-enforcé ⇒ `false`.
  bool isHardLockedAt(DateTime now) => phaseAt(now) == LicensePhase.hardLock;
}

/// Miroir global de l'entitlement courant, lisible au MOMENT de l'écriture
/// (sans `ref`). Alimenté par `EntitlementNotifier`. Permet au chokepoint
/// d'écriture staff `runModuleWrite` d'appliquer la lecture seule de façon
/// UNIFORME sur tous les modules, sans coupler chaque provider à Riverpod.
///
/// Fail-soft : défaut `none()` ⇒ jamais bloquant tant qu'aucune licence enforced.
/// Ne concerne QUE l'écriture locale (jamais la synchro — C4).
class LicenseEnforcement {
  LicenseEnforcement._();
  static Entitlement current = const Entitlement.none();

  /// L'écriture doit-elle être refusée MAINTENANT (lecture seule OU hard-lock) ?
  static bool get writeBlockedNow =>
      current.isEnforced && !current.canWriteAt(DateTime.now().toUtc());

  /// Hard-lock actif MAINTENANT ? Lecture sans `ref` pour le shell/router.
  /// Fail-soft : défaut `none()` ⇒ jamais bloquant tant qu'aucune licence privée
  /// enforced n'est expirée au-delà de la grâce.
  static bool get isHardLockedNow =>
      current.isEnforced && current.isHardLockedAt(DateTime.now().toUtc());
}
