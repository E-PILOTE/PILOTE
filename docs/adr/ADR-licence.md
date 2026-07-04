# Journal ADR — Système d'abonnement & licence offline-first

> Décisions d'architecture **gelées** (2026-07-04). Statut de chacune : **Acceptée**.
> Toute remise en cause exige un défaut critique, documenté ici avant application.
> Contexte complet : `docs/ABONNEMENT_LICENCE_ARCHITECTURE.md` (technique) et
> `docs/ABONNEMENT_ARCHITECTURE_LOGICIELLE.md` (organisation du code).

---

## ADR-0001 — Séparer Abonnement (serveur) et Licence (projection signée)
**Décision.** L'**Abonnement** est la vérité contractuelle, serveur-only, mutable
(porté par `school_groups`). La **Licence** est une projection **signée, immuable,
versionnée, jetable** de l'abonnement, taillée pour l'offline. Le client est un
pur applicateur : il ne crée jamais un droit.
**Conséquence.** Tout changement d'abonnement ⇒ **émission** d'une nouvelle licence,
jamais d'édition.

## ADR-0002 — La licence ne transite PAS par PowerSync
**Décision.** La licence est un *credential*, pas de la donnée métier. Elle n'est
ni une table synchronisée, ni dans un bucket. Deux voies parallèles : donnée
métier (PowerSync) ; credential (fetch HTTPS hors-bande, réutilisant la session
Supabase).
**Pourquoi.** Toute table PowerSync est localement **inscriptible** (`db.execute`
crée un CRUD local) et le SQLite est **en clair** ; de plus `disconnectAndClear()`
l'effacerait à chaque bascule d'agent. Le coffre doit **survivre** à cela.
**Conséquence.** Stockage en coffre dédié `flutter_secure_storage`, hors SQLite.

## ADR-0003 — Intégrité par SIGNATURE, pas par stockage (Ed25519)
**Décision.** Signature **asymétrique Ed25519** (JWS compact, en-tête `kid`).
Jamais HMAC (clé symétrique = forgeable côté client). Clé privée hors app
(Edge Function isolée) ; clés publiques **épinglées** dans l'app, indexées par `kid`.
**Pourquoi.** Le secure storage est **faible sur desktop** (libsecret). L'intégrité
ne peut donc pas reposer sur le coffre → elle repose sur la vérification de signature.
Le coffre n'est que défense en profondeur.
**Dépendance ajoutée.** `cryptography` (Ed25519) — `crypto` seul ne fait que SHA/HMAC.

## ADR-0004 — Double horloge indépendante
**Décision.** (1) **Expiration métier** (`valid_to`) → cascade douce
`grâce (15 j) → lecture seule`. (2) **Fenêtre de confiance** (`offline_window`)
→ au-delà, lecture seule (comble l'angle mort de la révocation invisible hors ligne).
La phase courante = **la pire** des deux ladders.
**Backstop réel.** La dépendance opérationnelle à la synchro, pas la crypto.

## ADR-0005 — Anti-rollback par `version` monotone UNIQUEMENT (correction C3)
**Décision.** L'anti-rejeu repose **exclusivement** sur un compteur `version`
monotone (ancre serveur). `issued_at` ne sert **jamais** à rejeter une licence.
**Pourquoi (défaut critique évité).** Un appareil à pile CMOS morte a une horloge
dans le passé ; rejeter sur `issued_at`/horloge verrouillerait une **école honnête**.
`issued_at` = audit/affichage + plancher haute-eau seulement (jamais plafond).

## ADR-0006 — L'état de licence ne gate JAMAIS la synchro PowerSync (correction C4)
**Décision.** Le verrou plan gate l'**UI et les features** (routes, mutations),
**jamais** `db.connect()`/la synchronisation. La synchro tourne toujours.
**Pourquoi.** Gater la synchro détruirait le backstop (dépendance à la synchro) et
risquerait la **perte de données** (écritures locales jamais remontées). Fail-soft
absolu : au doute (pas de licence, illisible, erreur), **on n'entrave rien**.

## ADR-0007 — Architecture logicielle minimale (corrections C1/C2/C5/C6)
**Décision.** Îlot hexagonal `lib/licensing/` (domaine pur / application /
infrastructure / présentation), **4 ports seulement** (`SignatureVerifier`,
`LicenseStore`, `LicenseGateway`, `Clock`), justifiés par leur couture de test.
**Coupes assumées** vs le design « riche » initial :
- **C1** : supprimés `VersionAnchor`, `IdentityContext`, `RefreshSignal` (abstractions
  prématurées, sans 2ᵉ implémenteur) ; identité passée en paramètre ; repères fondus
  dans `LicenseStore` (`TrustState`) ; table `license_pointer` **différée** (optimisation).
- **C2** : pas de classe `EntitlementService` — l'état vit dans un provider Riverpod,
  la logique dans l'objet valeur `Entitlement` (`can`/`phase`).
- **C5** : online (`subscription_access`) et offline (licence) restent **deux politiques
  distinctes** ; on ne partage qu'une primitive (échelle grâce→lecture seule + seuil).
- **C6** : module **transverse** `lib/licensing/` (pas `features/`), `infrastructure/` plate.
- Pas de `LicenseRepository` : `Store` + `Gateway` + `Service` suffisent (anti-cérémonie).

---

## Notes d'environnement
- **Build Linux** : `flutter_secure_storage` requiert `libsecret-1-dev`
  (`sudo apt-get install -y libsecret-1-dev`). À reporter dans la CI.
