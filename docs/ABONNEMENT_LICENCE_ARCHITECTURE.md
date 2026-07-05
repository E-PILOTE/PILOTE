# Abonnement & Licence offline-first — Architecture technique

> **Statut : DÉCISIONS GELÉES (ADR) · SOCLE CLIENT IMPLÉMENTÉ & VÉRIFIÉ (2026-07-04).**
> Décisions figées → `docs/adr/ADR-licence.md`. Organisation du code livré →
> `docs/ABONNEMENT_ARCHITECTURE_LOGICIELLE.md` (`epilote/lib/licensing/`, analyze 0,
> 23 tests verts, build Linux OK, enforcement **dormant** tant que les clés publiques
> ne sont pas épinglées). Stress-test adversarial : **7/10 → 9/10** une fois le §9 fermé.
>
> **⚠️ Corrections appliquées au design initial (audit implémenteur C1–C6) — priment sur le corps ci-dessous :**
> - **C1** : abstractions prématurées supprimées (`VersionAnchor`/`IdentityContext`/`RefreshSignal`) ;
>   repères fondus dans `TrustState` ; **table `license_pointer` = optionnelle/différée** (le §5 la
>   présentait comme recommandée : elle devient une optimisation Vague 8).
> - **C2** : pas de classe `EntitlementService` (état = provider Riverpod, logique = objet `Entitlement`).
> - **C3** : anti-rollback = **`version` monotone SEULE** ; `issued_at` ne rejette JAMAIS (anti-lockout CMOS).
> - **C4** : l'état de licence **ne gate jamais la synchro PowerSync** (UI/features uniquement).
> - **C5** : online (`subscription_access`) et offline (licence) = **deux politiques**, non fusionnées.
> - **C6** : module **transverse** `lib/licensing/` (pas `features/`).

Ce document est le cahier des charges du **volet enforcement offline** de l'abonnement.
Le volet **facturation online** existe déjà (voir §2) — ce document ne le refait pas, il s'y branche.

---

## 1. Les deux concepts (clé de voûte)

Ne jamais les confondre. C'est la décision structurante de tout le système.

| | **Abonnement** (Subscription) | **Licence** (License / Entitlement) |
|---|---|---|
| Nature | Vérité contractuelle | Projection **signée** de l'abonnement |
| Localisation | **Serveur uniquement** | Émise serveur → poussée aux appareils |
| Mutabilité | Mutable (états, facturation) | **Immuable + versionnée** |
| Cycle de vie | Éditée en place | **Jetable** : tout changement ⇒ on ÉMET une nouvelle licence, jamais d'édition |
| Rôle client | — | Pur **applicateur** : vérifie la signature et applique les droits |

**Source de vérité unique** : le serveur seul émet/modifie. Le client ne crée **jamais** un droit ;
il remonte des **faits** (usage, quotas consommés) = des preuves, pas de l'autorité.

> ⚠️ **NE PAS** modéliser la licence comme une table PowerSync éditable. C'est un artefact
> signé poussé en sens unique, pas de la donnée métier. Voir §5.

---

## 2. Ce qui existe déjà (point d'ancrage — NE PAS refaire)

Le volet **online** est en place et sert admin_groupe / super_admin (chemin `supabase.from()` direct) :

- `lib/data/models/subscription_model.dart` — `SubscriptionModel` (status, `start_date`, `end_date`, `is_auto_renew`, jointure `subscription_plans`).
- `lib/features/admin_groupe/screens/admin_subscription_screen.dart` + `providers/admin_subscription_provider.dart` — l'admin_groupe **voit/pilote** son abonnement.
- `lib/features/super_admin/screens/{subscriptions,plans}_screen.dart` — le super_admin **administre** abonnements & plans.
- Tables serveur `subscriptions`, `subscription_plans` (base live).

Le **tenant facturé = le groupe scolaire** (`group_id`), jamais l'école.
Le **décideur / payeur = `admin_groupe`** : c'est le seul notifié des échéances (voir [`role-admin-groupe`]).

**Le trou** : rien ne pousse un droit **vérifiable hors ligne** vers les appareils du **personnel scolaire**
(`_isStaffRole`, chemin PowerSync). C'est l'objet de ce document.

---

## 3. Les deux horloges INDÉPENDANTES

Deux mécanismes distincts, à ne jamais fusionner :

### 3.1 Expiration métier
- = date de fin (`valid_to`), calculée **en local**.
- Pilote une **cascade douce** : `grâce → lecture seule → restriction`.
- **Jamais** de purge, **jamais** de blocage sec. La **fenêtre examens prime** (biais disponibilité).

### 3.2 Fenêtre de confiance (Trust Window)
- champ `max_offline_duration` (~30–45 j) = temps maximal **hors ligne sans revalidation**.
- Comble l'angle mort de la **RÉVOCATION** (suspension / impayé imprévisibles, invisibles hors ligne).
- **Dégrade en douceur**, ce n'est **pas** un couperet.
- C'est un **fil-piège** (force la reconnexion), pas un rempart cryptographique.

> **Backstop réel de l'enforcement = la dépendance opérationnelle à la synchro**
> (l'école DOIT se reconnecter pour fonctionner), **PAS** la crypto.
> Appareil hors-ligne + horloge figée = **inenforçable**, c'est assumé.

---

## 4. Sécurité — principes cryptographiques

- **Signature ASYMÉTRIQUE** — jamais HMAC. Clé privée serveur, clé publique épinglée dans l'app.
- **Format : JWS / JWT signé Ed25519** (64 o, vérif sub-ms, en-tête `kid` pour rotation multi-clés).
- **Version monotone anti-rejeu** : l'ancre réelle est le **serveur**, pas le local.
  - 1ʳᵉ activation online obligatoire → re-sème le repère.
  - un `restore` (sauvegarde) doit **revalider online**.
- **Repère temporel haute-eau anti-recul-horloge** : on garde le max de temps vu.
  - une anomalie n'est **pas** une fraude automatique (piles CMOS mortes fréquentes au Congo).
- **Temps monotone** entre deux synchros (minuterie), jamais l'horloge murale absolue.
- **`group_id` de la licence == identité authentifiée** vérifié **à l'application** (anti-échange entre écoles).
- **Zéro PII** dans le payload.

### Payload de la licence (JWS)
```jsonc
{
  "group_id":  "uuid",            // tenant
  "plan":      "string",          // slug du plan
  "modules":   ["slug", "..."],   // modules accordés
  "quotas":    { "schools": 5, "students": 2000, "...": 0 },
  "valid_from":"iso8601",
  "valid_to":  "iso8601",         // horloge 3.1
  "offline_window": 2592000,      // secondes — horloge 3.2 (max_offline_duration)
  "version":   42,                // monotone (anti-rollback)
  "issued_at": "iso8601"
}
```
En-tête JWS : `{ "alg": "EdDSA", "kid": "2026-07" }`.

---

## 5. Intégration PowerSync — PRINCIPE FONDATEUR

**La licence NE transite PAS par PowerSync.** C'est un *credential*, pas de la donnée métier.
Deux voies parallèles qui ne se rejoignent qu'à l'app.

| | Voie « donnée métier » | Voie « credential » |
|---|---|---|
| Canal | PowerSync (buckets, sync-rules) | Fetch HTTPS hors-bande |
| Stockage local | SQLite PowerSync (inscriptible !) | `flutter_secure_storage` (coffre dédié) |
| Effacé par `disconnectAndClear()` | Oui | **Non** (survit à la bascule d'agent) |

Raisons de sortir la licence de PowerSync :
- Toute table du schéma PowerSync est **localement inscriptible** (`db.execute` crée un CRUD local
  lu avant réconciliation) → un client pourrait forger ses propres droits.
- SQLite PowerSync est **en clair, inspectable**.

> ⚠️ **Desktop Linux/Windows** : `flutter_secure_storage` est **faible** (libsecret dépend d'un
> démon parfois absent). L'intégrité repose donc sur la **SIGNATURE**, pas sur le coffre.
> Le coffre n'est que de la **défense en profondeur**.

### Pointeur de changement (option recommandée)
Une **petite** table synchronisée **read-only** sert de signal bon marché :
```
license_pointer { group_id, license_version, updated_at }
```
- Falsifiée = **inoffensif** (au pire un fetch inutile).
- Découple le **signal** (« il y a du neuf », via sync) du **credential** (récupéré hors-bande).
- Alternative sans table : écouter `SyncStatus.connected` de PowerSync pour déclencher un
  refresh hors-bande (réutiliser le signal, **pas** coupler).

### Renouvellement
Fetch hors-bande → **swap atomique** du coffre → **zéro** contact avec la file CRUD / les buckets.
Aucune interférence avec la synchro métier.

---

## 6. Cycle technique de bout en bout

```
Abonnement change (serveur)
   │
   ▼
Edge Function `license-issuer`  ── ISOLÉE, détient la clé privée (HSM / service séparé)
   │   signe un token compact Ed25519 (payload §4)
   ▼
Distribution
   ├─ PULL HTTPS authentifié   (au login / connect / refresh)          ← cas nominal
   └─ Paquet d'activation signé (USB / QR, ingéré 1×)                   ← canal offline rural (§9 N8)
   │
   ▼
Validation client (ATOMIQUE)
   1. signature vérifiée via `kid` (clé publique épinglée)
   2. group_id == identité authentifiée
   3. version ≥ repère local monotone     (anti-rollback)
   4. issued_at cohérent                   (anti recul d'horloge)
   │
   ▼
Écriture ATOMIQUE coffre (write-temp → vérifie → commit ; échec ⇒ garder l'ancienne)
   + MAJ du repère de version
   │
   ▼
Décodage → EntitlementState (mémoire)      ← provider Riverpod keepAlive
   │
   └─ archivage AUDIT seulement (jamais réactiver une licence archivée)
```

---

## 7. Vérification — séparer les DEUX coûts

| Coût | Quand | Fréquence |
|---|---|---|
| **Crypto** (vérif signature) | démarrage + arrivée d'une nouvelle licence | **ÉVÉNEMENTIELLE** (0,1–2 ms), jamais en boucle |
| **Entitlement** (lookup droit) | à la demande | lookup **mémoire** (µs) |

**Stratégie** :
- Service centralisé : provider Riverpod `keepAlive` exposant un `EntitlementState` (quelques Ko en mémoire).
- **Garde légère = 2ᵉ verrou (plan)** inséré dans le `redirect` de
  `lib/core/router/app_router.dart`, dans la cascade existante `rôle → plan → profil → périmètre`
  (voir [`modules-acces-hierarchie`]). Aujourd'hui le `redirect` a déjà : garde de rôle (l.225),
  calendrier direction (l.245), **verrou 3 modules** (l.255). Le **verrou plan** s'insère
  **avant** le verrou 3 : « ce module est-il dans `entitlement.modules` ? ».
- Réévaluation des **dates** : tick **1×/jour** + au retour premier plan (aucune crypto).

> **ANTI-PATTERN à proscrire** : vérifier la signature dans `build()` ou dans `db.watch()`.
> La crypto reste **hors du chemin chaud** → impact perf ~nul, aucune requête SQLite pour un droit
> (tout en mémoire) → ne concurrence pas les I/O PowerSync.

---

## 8. Punch-list (traiter en 1ʳᵉ classe — conditionne l'approbation)

| # | Règle | Détail |
|---|---|---|
| **A** | **Quotas SOUPLES** *(le + important)* | Consommation offline multi-appareils inbornable en dur → **autoriser le dépassement**, réconcilier à la synchro (upsell). **NE JAMAIS bloquer une inscription hors ligne.** |
| **B** | **Noyau irréductible** | Hors-ligne + horloge figée = inenforçable par crypto. Vrai backstop = dépendance opérationnelle à la synchro. Trust window = fil-piège. |
| **C** | **Fail-soft / rayon de souffle** | Licence illisible ⇒ état **utilisable-mais-alerté**, jamais écran noir. Feature-flag serveur d'assouplissement + rollout progressif (sinon on brique le parc national pendant les examens). |
| **D** | **Clé de signature = secret n°1** | Service isolé ; clé publique **épinglée + versionnée**. |
| **E** | **Révocation urgente** | Best-effort jusqu'à reconnexion ; fenêtre paramétrable par risque. |
| **F** | **Downgrade offline** | Retirer l'accès module, **jamais détruire** les données créées sous ce module. |

Autres invariants :
- Liaison licence au **TENANT**, pas au matériel (device-bind dur = cauchemar support au Congo).
- Horodatage **serveur-autoritaire** (une horloge falsifiée corrompt aussi présences & notes).
- **N12** : toujours autoriser l'**export des dossiers élèves**, même en état restreint (poids légal).
- Application **ATOMIQUE** de la licence.

---

## 9. Les 5 trous BLOQUANTS (à fermer AVANT dev) — stress-test 2026-07-04

| Sévérité | Trou | Correctif |
|---|---|---|
| 🔴 | **C4 — paiement refusé après émission** (mortel sur mobile money) | **2 étages** : licence **PROVISOIRE courte** (3–7 j) sur paiement en attente ; licence **plein terme** seulement sur règlement **confirmé**. Ne jamais émettre une licence pleine sur paiement non confirmé. |
| 🔴 | **F2/F3 — clé de signature** (rotation ratée ou clé volée = brique/gratuité fleet-wide) | En-tête **`kid` multi-clés** + chevauchement + **ordre** : distribuer le **vérificateur AVANT** de basculer le signataire. Clé privée en **HSM** / service isolé. Licences **courtes** ⇒ limitent le rayon d'une clé volée. |
| ❌ | **N8 — 1ʳᵉ activation en zone déjà hors ligne** (cœur de cible rural) | Activation online obligatoire = onboarding impossible → **canal d'activation OFFLINE** : pré-activation avant expédition, **ou** paquet d'activation signé (USB / QR) ingéré une fois. |
| ❌ | **G3 / G2 — verrouillage d'écoles HONNÊTES** (risque réputationnel n°1) | Fenêtre **généreuse + adaptative par zone** ; dégradation douce réversible ; fail-soft sur anomalie d'horloge ; **biais assumé vers la DISPONIBILITÉ** ; temps avancé via **minuterie monotone**. |
| ⚠️ | **E1/E2 — cycle de vie du tenant** (fusion / scission d'écoles) | **Non conçu.** Spécifier : processus de **supersession de licence** + migration de données inter-tenant. |

---

## 10. Tension centrale (arbitrage gouvernant)

**Longueur de la fenêtre de confiance** :
- **COURTE** → limite fraude / clé volée / révocation lente, MAIS brique l'offline honnête.
- **LONGUE** → respecte le terrain, MAIS allonge l'exposition.

**Réponse = fenêtre ADAPTATIVE** : généreuse par défaut / par zone ; raccourcie pour les comptes
à risque, les paiements provisoires, le post-incident.

Rappel : le vrai enforcement ne vient pas de la crypto mais de la **dépendance opérationnelle à la synchro**.

---

## 11. Découpage de l'implémentation — ÉTAT 2026-07-05

> ⚡ **Activé en prod (pilote METP) le 2026-07-04.** Vagues 0→3 livrées & vérifiées ;
> Vague 4 différée. Décisions gelées : `docs/adr/ADR-licence.md`.
> ⚠️ Correction de fond appliquée pendant la mise en œuvre : la table `subscriptions`
> **n'existe pas** ; la vérité d'abonnement est portée par **`school_groups`**
> (`subscription_status`, `subscription_end`, `plan_id`, `license_version`,
> `payment_confirmed`, `offline_window_days`). Tout le code cible `school_groups`.

**Vague 0 — Décisions & secrets** ✅
- [x] Paire Ed25519 ; clé privée = secret de l'Edge Function `license-issuer`.
- [x] Stratégie `kid` (`2026-07`) + clé publique épinglée dans l'app.
- [x] 2 étages provisoire/plein terme (§9 C4, `payment_confirmed`).

**Vague 1 — Émission serveur** ✅
- [x] États/transitions **sur `school_groups`** (PAS `subscriptions` — inexistante).
- [x] Edge Function `license-issuer` : signe le payload §4, endpoint PULL authentifié,
      garde-pilote `LICENSE_PILOT_GROUP_IDS`, version via `next_license_version`.
- [ ] (Option, différée V8) table read-only `license_pointer` + sync-rule.

**Vague 2 — Applicateur client (Flutter)** ✅
- [x] `SecureLicenseStore` sur `flutter_secure_storage` (survit à `disconnectAndClear()`).
- [x] `Ed25519Verifier` (signature + `group_id==identité` + **version ≥ repère seule**, C3).
- [x] `Entitlement` + provider Riverpod `keepAlive` (décodage mémoire).
- [x] Refresh hors-bande au login staff (`refreshLicense`).

**Vague 3 — Enforcement doux** ✅
- [x] **Verrou plan** dans le `redirect` de `app_router.dart` (avant le verrou 3).
- [x] Cascade douce grâce → lecture seule (double horloge, `computeLicensePhase`).
- [x] Bannières fail-soft staff + admin (cohérentes avec le shell).
- [x] **Tick 1×/jour + premier plan** : ré-évaluation resume + timer 6 h sur les deux
      bannières (bascule grâce→lecture-seule sans redémarrage).
- [ ] Quotas souples (advisory offline + réconciliation) — **différé** (`quotas:{}`).

**Vague 4 — Canaux & cas limites (§9 N8 / E1-E2)** ⏸ différée (au vrai besoin)
- [ ] Paquet d'activation OFFLINE signé (USB / QR) ingéré une fois.
- [ ] Feature-flag serveur d'assouplissement + rollout progressif.
- [ ] Supersession de licence + migration inter-tenant (fusion/scission).

---

## Références croisées (mémoires projet)

- [`abonnement-architecture-offline`] — règles métier / fonctionnelles validées.
- [`abonnement-technique-powersync`] — audit technique d'implémentation.
- [`modules-acces-hierarchie`] — l'abonnement = verrou le plus haut de la cascade `rôle → plan → profil → périmètre`.
- [`role-admin-groupe`] — décideur / payeur = `admin_groupe`, seul notifié des échéances.
- [`sync-config-divergence`] — déploiement des sync-rules (dashboard PowerSync Cloud).
