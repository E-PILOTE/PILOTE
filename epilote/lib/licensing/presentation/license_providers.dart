import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../application/license_service.dart';
import '../domain/entitlement.dart';
import '../infrastructure/ed25519_verifier.dart';
import '../infrastructure/monotonic_clock.dart';
import '../infrastructure/secure_license_store.dart';
import '../infrastructure/supabase_license_gateway.dart';

/// Clés publiques Ed25519 ÉPINGLÉES (kid → octets bruts, 32 o).
///
/// VIDE tant que la paire de clés n'est pas provisionnée (Vague 1 : génération
/// + Edge Function `license-issuer`). Conséquence voulue : aucun token ne
/// décode → `Entitlement.none()` → **aucun enforcement** = comportement actuel
/// de l'app strictement préservé. Renseigner ce map ACTIVE le durcissement.
final licensePinnedKeysProvider = Provider<Map<String, List<int>>>((ref) {
  return const {};
});

/// Racine de composition du module licence (impls → ports). Seul endroit couplé
/// aux plugins. `keepAlive` : services à instance unique et longue vie.
final licenseServiceProvider = Provider<LicenseService>((ref) {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  return LicenseService(
    verifier: Ed25519Verifier(ref.watch(licensePinnedKeysProvider)),
    store: SecureLicenseStore(),
    gateway: SupabaseLicenseGateway(client),
    clock: MonotonicClock(),
  );
});

/// État d'entitlement courant (mémoire). Bootstrap au démarrage ; `refresh`
/// hors-bande sur signal. Fail-soft : au doute, `Entitlement.none()` (permissif).
final entitlementProvider =
    AsyncNotifierProvider<EntitlementNotifier, Entitlement>(
        EntitlementNotifier.new);

class EntitlementNotifier extends AsyncNotifier<Entitlement> {
  @override
  Future<Entitlement> build() async {
    ref.keepAlive();
    try {
      return await ref.read(licenseServiceProvider).bootstrap();
    } catch (_) {
      return const Entitlement.none();
    }
  }

  /// Rafraîchit la licence hors-bande (déclenché à la connexion / au signal de
  /// synchro). `expectedGroupId` = identité authentifiée.
  Future<void> refreshLicense(String expectedGroupId) async {
    try {
      final ent = await ref
          .read(licenseServiceProvider)
          .refresh(expectedGroupId: expectedGroupId);
      state = AsyncData(ent);
    } catch (_) {
      // fail-soft : on garde l'état courant.
    }
  }
}
