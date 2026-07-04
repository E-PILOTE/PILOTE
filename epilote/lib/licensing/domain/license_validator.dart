import 'license.dart';

/// Motif de rejet d'une licence entrante (structural/métier — PAS crypto).
enum LicenseRejection {
  identityMismatch, // group_id de la licence != identité authentifiée
  rollback,         // version < repère monotone local (rejeu d'une ancienne)
}

class ValidationResult {
  const ValidationResult.ok() : rejection = null;
  const ValidationResult.rejected(this.rejection);
  final LicenseRejection? rejection;
  bool get isOk => rejection == null;
}

/// Règles d'acceptation d'une licence entrante. PUR, sans I/O ni crypto.
///
/// SRP : distinct du [SignatureVerifier] (crypto). Deux raisons de changer.
///
/// ⚠️ C3 — l'anti-rollback repose UNIQUEMENT sur `version` (compteur serveur
/// monotone). On NE rejette JAMAIS sur `issued_at` / l'horloge : un appareil à
/// pile CMOS morte a une horloge dans le passé et rejetterait une licence
/// fraîche parfaitement valide → verrouillage d'une école honnête.
class LicenseValidator {
  const LicenseValidator();

  ValidationResult validate(
    License incoming, {
    required String expectedGroupId,
    required int versionFloor,
  }) {
    if (incoming.groupId != expectedGroupId) {
      return const ValidationResult.rejected(LicenseRejection.identityMismatch);
    }
    if (incoming.version < versionFloor) {
      return const ValidationResult.rejected(LicenseRejection.rollback);
    }
    return const ValidationResult.ok();
  }
}
