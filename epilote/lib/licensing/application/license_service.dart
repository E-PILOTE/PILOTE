// Params nommés publics liés à des champs privés → l'initialisation en liste
// est volontaire (une formelle d'initialisation exposerait `_verifier:` au site
// d'appel).
// ignore_for_file: prefer_initializing_formals

import '../domain/entitlement.dart';
import '../domain/license.dart';
import '../domain/license_validator.dart';
import '../domain/ports.dart';

/// Orchestrateur unique du cycle de vie de la licence (Dart pur, ports seuls).
///
/// Invariants (cf. ADR) :
///  - fail-soft absolu : tout échec renvoie l'entitlement courant, jamais un
///    état sans licence ni une exception qui remonte à l'UI ;
///  - remplacement ATOMIQUE : on ne persiste une nouvelle licence qu'après
///    vérification + validation ; en cas d'échec, l'ancienne est conservée ;
///  - « meilleur temps connu » = max(horloge murale, repère haute-eau) →
///    robuste au recul d'horloge (piles CMOS mortes).
///  - ce service NE touche JAMAIS PowerSync (connexion/synchro) — C4.
class LicenseService {
  LicenseService({
    required SignatureVerifier verifier,
    required LicenseStore store,
    required LicenseGateway gateway,
    required Clock clock,
    LicenseValidator validator = const LicenseValidator(),
  })  : _verifier = verifier,
        _store = store,
        _gateway = gateway,
        _clock = clock,
        _validator = validator;

  final SignatureVerifier _verifier;
  final LicenseStore _store;
  final LicenseGateway _gateway;
  final Clock _clock;
  final LicenseValidator _validator;

  /// Meilleur temps connu : l'horloge murale ne peut pas faire « reculer » le
  /// temps sous le repère haute-eau (plancher, jamais plafond — C3).
  DateTime bestKnownNow(TrustState? state) {
    final wall = _clock.wallNow().toUtc();
    final hw = state?.timeHighWater;
    return (hw != null && hw.isAfter(wall)) ? hw : wall;
  }

  /// Démarrage : recharge la licence du coffre et la re-vérifie. Coffre vide ou
  /// illisible ⇒ `Entitlement.none()` (fail-soft, app non-enforcée).
  Future<Entitlement> bootstrap() async {
    final state = await _safeRead();
    if (state == null) return const Entitlement.none();
    final license = await _decode(state.token);
    if (license == null) return const Entitlement.none();
    return Entitlement(license: license, lastSyncAt: state.lastSyncAt);
  }

  /// Renouvellement hors-bande. Ne remplace la licence QUE si le nouveau token
  /// est vérifié ET validé (identité + version ≥ repère). Sinon conserve
  /// l'existant. `expectedGroupId` = identité authentifiée (passée en paramètre,
  /// pas de port Identity — C1).
  Future<Entitlement> refresh({required String expectedGroupId}) async {
    final current = await bootstrap();

    final token = await _safeFetch();
    if (token == null) return current; // hors ligne / indisponible

    final license = await _decode(token);
    if (license == null) return current; // signature/format KO

    final state = await _safeRead();
    final floor = state?.version ?? 0;
    final verdict = _validator.validate(
      license,
      expectedGroupId: expectedGroupId,
      versionFloor: floor,
    );
    if (!verdict.isOk) return current; // identité/rollback → on garde l'ancienne

    final now = bestKnownNow(state);
    final next = TrustState(
      token: token,
      version: license.version,
      timeHighWater: now, // avance le plancher
      lastSyncAt: now,
    );
    final written = await _safeWrite(next);
    if (!written) return current; // échec d'écriture → ancienne conservée

    return Entitlement(license: license, lastSyncAt: now);
  }

  // ── Enveloppes fail-soft : aucune exception ne remonte à l'appelant ──────
  Future<TrustState?> _safeRead() async {
    try { return await _store.read(); } catch (_) { return null; }
  }

  Future<bool> _safeWrite(TrustState s) async {
    try { await _store.write(s); return true; } catch (_) { return false; }
  }

  Future<String?> _safeFetch() async {
    try { return await _gateway.fetchLicenseToken(); } catch (_) { return null; }
  }

  Future<License?> _decode(String token) async {
    try {
      final claims = await _verifier.verifyAndDecode(token);
      if (claims == null) return null;
      return License.fromClaims(claims);
    } catch (_) {
      return null;
    }
  }
}
