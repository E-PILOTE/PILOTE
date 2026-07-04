import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../application/license_service.dart';
import '../domain/entitlement.dart';
import '../infrastructure/ed25519_verifier.dart';
import '../infrastructure/monotonic_clock.dart';
import '../infrastructure/secure_license_store.dart';
import '../infrastructure/supabase_license_gateway.dart';

/// Clés publiques Ed25519 ÉPINGLÉES (kid → octets bruts, 32 o).
///
/// ⚡ ACTIVÉ le 2026-07-04 (go-live pilote). La clé `2026-07` correspond à la
/// clé privée détenue par l'Edge Function `license-issuer`. L'émission est
/// bornée côté serveur par `LICENSE_PILOT_GROUP_IDS` (rollout contrôlé) : les
/// groupes hors pilote reçoivent 403 → aucune licence → restent dormants.
/// Vider ce map = retour immédiat à dormant (cf. docs/LICENCE_GOLIVE.md).
final licensePinnedKeysProvider = Provider<Map<String, List<int>>>((ref) {
  return const {
    '2026-07': [
      207, 117, 121, 94, 125, 120, 211, 118, 236, 187, 20, 95, 208, 35, 247, 140,
      179, 35, 8, 145, 32, 221, 216, 52, 102, 115, 93, 182, 195, 42, 196, 12,
    ],
  };
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
    final profile = ref.watch(authNotifierProvider).valueOrNull;

    Entitlement ent;
    try {
      ent = await ref.read(licenseServiceProvider).bootstrap();
    } catch (_) {
      ent = const Entitlement.none();
    }

    // Rafraîchissement hors-bande au login (personnel scolaire uniquement).
    // Auto-inerte tant que les clés ne sont pas épinglées : `refreshLicense`
    // n'émet alors AUCUNE requête réseau (voir garde ci-dessous).
    final role = profile?.role;
    final groupId = profile?.groupId;
    final isStaff = role != null &&
        role != AppConstants.roleSuperAdmin &&
        role != AppConstants.roleAdminGroupe;
    if (isStaff && groupId != null && groupId.isNotEmpty) {
      Future.microtask(() => refreshLicense(groupId));
    }
    return ent;
  }

  /// Rafraîchit la licence hors-bande (déclenché à la connexion / au signal de
  /// synchro). `expectedGroupId` = identité authentifiée.
  Future<void> refreshLicense(String expectedGroupId) async {
    // Dormant : sans clé publique épinglée, aucun token ne pourrait être
    // vérifié → on n'émet même pas de requête réseau (zéro impact tant que
    // l'activation n'a pas eu lieu).
    if (ref.read(licensePinnedKeysProvider).isEmpty) return;
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
