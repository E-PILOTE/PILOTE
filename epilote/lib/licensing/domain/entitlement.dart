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
  /// N'est PAS piloté par la phase : une phase `readOnly` laisse OUVRIR le
  /// module (lecture seule) — c'est `canWrite` qui bride les mutations.
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
    );
  }

  /// Écriture autorisée ? Fail-soft : non-enforcé ⇒ `true`.
  bool canWriteAt(DateTime now) => phaseAt(now) != LicensePhase.readOnly;
}
