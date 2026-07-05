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
- **⚡ ACTIVÉ (pilote METP) le 2026-07-04.** `licensePinnedKeysProvider` contient la
  clé `2026-07` ; l'émission est bornée serveur par `LICENSE_PILOT_GROUP_IDS`. Vider
  le map OU la liste = retour dormant immédiat (`Entitlement.none()`, app préservée).

## Reste à faire (état 2026-07-05)
- ✅ **Vague 1** (émission serveur) : Edge Function `license-issuer` déployée, paire
  Ed25519, 2 étages provisoire/plein terme (C4, `payment_confirmed`), fenêtre
  adaptative (G3, `offline_window_days`). Vérité sur `school_groups` (pas `subscriptions`).
- ✅ **Vague 7** (re-émission/refresh) : compteur `license_version` monotone
  (`next_license_version`), refresh hors-bande câblé au login staff.
- ✅ **Vague 6** (enforcement doux) : bannières staff+admin, gating écriture uniforme
  (`runModuleWrite` + `LicenseEnforcement`, ADR-0008), `canProvider` verrou 3.
- ✅ **Vague 3 (tick)** : ré-évaluation « 1×/jour + premier plan » sur les deux
  bannières (resume + timer 6 h) → bascule grâce→lecture-seule sans redémarrage.
- ⏸ **Quotas souples** (advisory dépassement offline + réconciliation synchro) :
  différé assumé — `quotas:{}` aujourd'hui, jamais bloquant (backlog).
- ⏸ **Vague 8 / 4 (différé, au vrai besoin)** : `license_pointer`, activation offline
  (USB/QR, N8), supersession de tenant (fusion/scission, E1/E2).
