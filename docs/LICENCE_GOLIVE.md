# Go-live licence — procédure d'ACTIVATION (prod, pilote-first)

> ⚠️ Tant que cette procédure n'est pas exécutée, l'enforcement est **DORMANT**
> (`licensePinnedKeysProvider` vide → `Entitlement.none()` → aucun blocage).
> Chaque étape est réversible jusqu'au pin des clés + déploiement de la fonction.
> Décisions : `docs/adr/ADR-licence.md`. Code : `epilote/lib/licensing/`,
> `supabase/functions/license-issuer/`.

## 0. Prérequis serveur — ✅ FAIT
- **Compteur de version monotone** : `school_groups.license_version` +
  `next_license_version(uuid)` — migration `0026`, **appliquée en prod**. La
  fonction incrémente à chaque émission (ancre anti-rollback autoritaire, ADR-0005).

## 1. Générer la paire Ed25519 (hors dépôt — la privée est le secret n°1)
```bash
openssl genpkey -algorithm ed25519 -out license_priv.pem
openssl pkey -in license_priv.pem -pubout -out license_pub.pem
# PKCS8 base64 (secret de la fonction) :
openssl pkey -in license_priv.pem -outform DER | base64 -w0 > license_priv.pkcs8.b64
# Clé publique BRUTE (32 o) pour l'épinglage Dart = 12 derniers octets d'en-tête retirés :
openssl pkey -in license_pub.pem -pubin -outform DER | tail -c 32 | xxd -i
```
> Ne JAMAIS committer `license_priv*`. Stocker la privée hors ligne (coffre).

## 2. Provisionner le secret + déployer la fonction (PROD)
> ⚠️ **Blocage outillage constaté** : le CLI `supabase` (wrapper npm installé) n'a
> **pas de binaire pour linux-x64** et il faut de toute façon un **Personal Access
> Token** (dashboard → Account → Access Tokens) que l'environnement n'a pas. Deux
> voies :
> - **A. Dashboard** : Edge Functions → New function `license-issuer` → coller
>   `supabase/functions/license-issuer/index.ts` → Deploy ; puis Settings → Secrets.
> - **B. CLI avec un vrai binaire + PAT** :
>   `export SUPABASE_ACCESS_TOKEN=<PAT>` puis binaire officiel (GitHub releases).

Secrets à poser (les 4) :
```
LICENSE_PRIVATE_KEY_PKCS8_B64 = <contenu de lic_priv.pkcs8.b64>   # clé privée Ed25519 (secret n°1)
LICENSE_KID                   = 2026-07
LICENSE_OFFLINE_WINDOW_DAYS   = 30
LICENSE_PILOT_GROUP_IDS       = <group_id du PILOTE>              # garde-pilote (voir §4)
```
> **GARDE-PILOTE** : tant que `LICENSE_PILOT_GROUP_IDS` est **définie**, la fonction
> n'émet QUE pour les groupes listés (les autres reçoivent `403 not_in_pilot` →
> restent dormants). Déploiement initial = liste = un seul groupe test.
> À ce stade, aucun appareil ne vérifie encore (clés non épinglées côté app, §3).

## 3. Épingler la clé publique dans l'app (active la vérification)
Renseigner `licensePinnedKeysProvider` (`epilote/lib/licensing/presentation/license_providers.dart`)
avec `{ '2026-07': <les 32 octets de l'étape 1> }`. **C'est l'interrupteur d'activation.**

## 4. Pilote sur UN groupe, PAS le parc
1. Déployer d'abord une build épinglée à **un groupe scolaire pilote** (ou feature-flag serveur).
2. Vérifier e2e : login staff → `license-issuer` renvoie un token → coffre écrit →
   `Entitlement` enforced → modules du plan **inchangés** pour un groupe actif ;
   un groupe expiré passe en lecture seule (bannière), **synchro jamais bloquée**.
3. Contrôler qu'aucun staff légitime n'est bloqué (les modules émis = `plan_modules`).

## 5. Élargir progressivement
Ajouter des group_id à `LICENSE_PILOT_GROUP_IDS` (secret, sans redéploiement du
code) par vagues, en surveillant. **Fleet-wide** = retirer complètement la variable.
Revenir à dormant instantanément = vider `licensePinnedKeysProvider` (build) OU
remettre `LICENSE_PILOT_GROUP_IDS=` (vide → personne).

## Rollback
- Vider `licensePinnedKeysProvider` → dormant immédiat (prochaine build).
- Ou `supabase functions delete license-issuer` → plus d'émission (les licences
  déjà en coffre expirent via la fenêtre de confiance).

## Vérifications automatiques déjà en place
`epilote/test/licensing/` (23 tests, dont round-trip Ed25519 réel) valide toute la
chaîne client signature→décodage→validation→phase. Le déploiement n'ajoute que le
côté serveur d'émission.
