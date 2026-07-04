# Architecture logicielle — Module licence (`lib/licensing/`)

> **Statut : SOCLE CLIENT IMPLÉMENTÉ & VÉRIFIÉ** (2026-07-04).
> `flutter analyze` = 0 · 23 tests licence verts (dont round-trip Ed25519 réel) ·
> `flutter build linux --debug` OK. Décisions gelées : voir `docs/adr/ADR-licence.md`.
> Ce document décrit l'**organisation du code**. Le « pourquoi » technique est dans
> `docs/ABONNEMENT_LICENCE_ARCHITECTURE.md`.

## Principe : îlot hexagonal transverse

Module **transverse** (pas une feature) : `lib/licensing/`. Règle de dépendance
unique — **les flèches pointent vers le domaine** ; le domaine ne dépend de rien ;
l'infrastructure implémente ses ports ; l'application dépend des ports (jamais des
impls) ; la présentation câble le tout. Aucun cycle possible.

## Arborescence livrée

```
lib/licensing/
├── domain/            (Dart pur — testable sans Flutter/plugin)
│   ├── license.dart              License (immuable) + fromClaims()
│   ├── license_phase.dart        LicensePhase + computeLicensePhase() (double horloge)
│   ├── entitlement.dart          Entitlement + grantsModule/phaseAt/canWriteAt (fail-soft)
│   ├── license_validator.dart    règles: identité + version monotone (PAS issued_at)
│   └── ports.dart                TrustState + 4 ports
├── application/
│   └── license_service.dart      bootstrap · refresh · swap atomique · bestKnownNow
├── infrastructure/    (seul couplage plugins)
│   ├── ed25519_verifier.dart     JWS Ed25519 (pkg cryptography), dispatch kid
│   ├── secure_license_store.dart flutter_secure_storage (TrustState JSON atomique)
│   ├── monotonic_clock.dart      horloge murale + monotone
│   └── supabase_license_gateway.dart  PULL Edge Function license-issuer
└── presentation/
    └── license_providers.dart    pinnedKeys · licenseService · entitlementProvider
```
Application de l'enforcement : **verrou plan** dans `core/router/app_router.dart`
(`redirect`, avant le verrou 3, fail-soft).

## Responsabilités (SRP)

| Composant | Responsabilité unique | Ne connaît jamais |
|---|---|---|
| `License` | porter les faits signés décodés | crypto, stockage, réseau, Flutter |
| `Entitlement` | vue évaluée : `grantsModule`, `phaseAt`, `canWriteAt` | I/O |
| `computeLicensePhase` | phase depuis la double horloge (pur) | statut serveur, UI |
| `LicenseValidator` | règles d'acceptation (identité, version) | **crypto** |
| `LicenseService` | orchestrer fetch→vérifie→valide→swap atomique, fail-soft | impls concrètes, Flutter, **PowerSync** |
| `Ed25519Verifier` | vérifier signature + décoder claims | règles métier |
| `SecureLicenseStore` | lire/écrire/effacer le `TrustState` | contenu de la licence |
| `SupabaseLicenseGateway` | récupérer un token frais hors-bande | validation, stockage |
| `MonotonicClock` | temps mural + monotone | licence, UI |
| `entitlementProvider` | détenir l'`Entitlement` mémoire, `refreshLicense` | crypto (déléguée) |

## Injection (Riverpod)
- **Singletons `keepAlive`** : `licenseServiceProvider` (racine de composition),
  `entitlementProvider`. Les impls infra sont instanciées **uniquement** là.
- **Immuables** : `License`, `Entitlement`, `TrustState` (recréés, jamais mutés).
- **Injectés par port** : les 4 ports → `overrideWith` en test (fakes mémoire).

## Testabilité (réalisée)
`test/licensing/` : `fakes.dart` (4 fakes), `domain_test.dart` (phase/validator/
entitlement), `license_service_test.dart` (bootstrap/refresh/rollback/identité/
offline/écriture-KO/anti-recul-horloge), `ed25519_roundtrip_test.dart` (signe →
vérifie → altère → kid inconnu). **80 % de la logique testée sans réseau/plugin.**

## État & activation
- **Enforcement DORMANT** : `licensePinnedKeysProvider` est **vide** ⇒ aucun token ne
  décode ⇒ `Entitlement.none()` ⇒ comportement actuel de l'app **strictement préservé**.
- **Activation** (Vague 1/7, non faite) : générer la paire Ed25519, déployer l'Edge
  Function `license-issuer`, **renseigner les clés publiques épinglées**. Réversible.

## Reste à faire (vagues suivantes)
1. **Vague 1** : paire Ed25519 + Edge Function `license-issuer` (clé privée isolée) +
   2 étages de licence (provisoire/plein terme, gap C4 métier).
2. **Vague 7** : (ré)émission sur changement d'abonnement + déclencheurs refresh
   (login / `SyncStatus.connected`) ; câbler `entitlementProvider.refreshLicense`.
3. **Vague 6 (reste)** : bannière fail-soft offline + gating des mutations sur `canWriteAt`.
4. **Vague 8 (différé)** : `license_pointer`, activation offline (USB/QR, N8),
   fenêtre adaptative, supersession de tenant (E1/E2).
