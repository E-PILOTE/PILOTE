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

## ADR-0008 — Périmètre d'enforcement uniforme (couverture plateforme)
**Décision.** L'enforcement couvre la plateforme **sans exception**, mais via
**deux mécanismes distincts** (C5 : online ≠ offline), chacun uniforme dans son périmètre.

**Personnel scolaire (offline, modules du catalogue) — read-only UNIFORME :**
- Route : verrou plan dans `redirect` sur **tout** module (`moduleSlugForLocation`
  + hôte générique `/user/m/:slug`).
- Écriture : **un seul chokepoint** `runModuleWrite` (52 sites) refuse l'écriture
  locale en lecture seule (`LicenseEnforcement.writeBlockedNow`). Il couvre les
  **7 domaines de modules du catalogue** (classes, evaluation, finance, staff,
  structure, students, vie_scolaire) ; aucun provider n'est gaté individuellement
  → zéro particularité par écran DANS le périmètre catalogue.
- Visibilité : `LicenseBanner` sur **tout** écran staff ; `canProvider` masque les
  actions mutantes (verrou 3), `read`/`export` toujours permis (N12).

**Exclusions ASSUMÉES du gating écriture staff (hors catalogue) :**
- `features/communication/` (tissu **natif** hors catalogue : messagerie, annonces,
  notifications, événements, stories, tickets) et `features/user/` (**espace
  personnel** : Mon profil, Paramètres, support) écrivent hors `runModuleWrite`.
- **Choix délibéré**, pas un oubli : la licence gate les **modules facturables**,
  jamais le canal de communication ni le self-service. Esprit N12 étendu — ne pas
  transformer en piège le moyen par lequel une école lapsée reçoit l'info ou dépose
  sa demande de renouvellement/support. Cohérent avec « communication = tissu natif »
  (hors catalogue de modules).

**admin_groupe (online, gouvernance) — scope INTENTIONNEL « pas de croissance » :**
- Passé la grâce, on suspend la **création de ressources facturables** (écoles,
  utilisateurs) via `ensureSubscriptionWritable`. La **gestion** de l'existant, la
  consultation et les **exports restent accessibles** (esprit N12 : ne pas piéger
  un admin dont l'abonnement a lapsé ; permettre la clôture/mise à jour).
- Ce n'est PAS une lecture seule totale : messages bandeau/snackbar alignés sur ce
  périmètre. Choix assumé, pas un oubli.

**Invariant commun** : jamais de gate sur la synchro PowerSync (C4) ; fail-soft
partout (au doute, on autorise) — miroir staff `LicenseEnforcement` défaut `none()`,
provider admin `subscriptionAccessProvider` défaut `unknown()` = non bloquant.

---

## ADR-0009 — Hard-lock UNIFORME à l'expiration (rentabilité)
**Contexte.** Le read-only souple (ADR-0008) ne crée pas assez de pression de
paiement sur un marché où un impayé peut être opportuniste : une école lapsée
continue de consulter/imprimer indéfiniment. Décision produit du propriétaire
(2026-07-05) : ajouter un cran plus dur APRÈS la grâce.

**Décision.** Nouvelle phase `LicensePhase.hardLock` (plus sévère que `readOnly`) :
passé la grâce, les **modules deviennent inaccessibles** (clic → mur
`/user/renouvellement`) ; seuls Dashboard / Profil / Paramètres et les routes
natives (communication, non-modules) restent — assez pour voir l'état et
renouveler, rien de plus. L'écriture reste bloquée (déjà via `canWriteAt`).

**Portée : TOUS les groupes, public comme privé.** Décision révisée le 2026-07-05 :
pas d'exception par type de plan. À l'échéance, tout groupe se durcit de la même
façon. (La v1 distinguait `is_public_plan` ; abandonné pour rester simple et
uniforme.)

**Garde-fous (non négociables).**
1. **Grâce préservée.** Le hard-lock ne frappe qu'APRÈS `kLicenseGraceDays`
   (15 j) — une école honnête en léger retard n'est jamais bloquée du jour au
   lendemain.
2. **Impayé CONFIRMÉ seulement.** Le hard-lock ne vient QUE de l'horloge métier
   (`valid_to` dépassé + grâce). La **fenêtre de confiance** (offline) n'escalade
   jamais au-delà de `readOnly` : un souci de réseau ≠ un impayé.
3. **Fail-soft absolu.** `hardLockable` par défaut `false` : tant que l'émetteur
   ne stampe pas le flag `hard_lock`, comportement identique à ADR-0008. Aucune
   licence / dormant ⇒ jamais de hard-lock. Le flag reste dans le domaine comme
   filet de sécurité (l'émetteur le met à `true` pour tout groupe provisionné).
4. **Invariant C4/ADR-0006 respecté.** Aucune donnée touchée, synchro toujours
   active ; tout est restauré au paiement (réémission licence, version +1).

**Portée technique.** Espace **staff offline** uniquement. Le chemin online
`admin_groupe` n'est **pas** hard-locké : c'est l'admin qui renouvelle — le
bloquer serait contre-productif (scope « pas de croissance » d'ADR-0008).

**Activation.** L'Edge Function `license-issuer` émet `hard_lock: true` pour tout
groupe provisionné. Déployée le 2026-07-05.

---

## Notes d'environnement
- **Build Linux** : `flutter_secure_storage` requiert `libsecret-1-dev`
  (`sudo apt-get install -y libsecret-1-dev`). À reporter dans la CI.
