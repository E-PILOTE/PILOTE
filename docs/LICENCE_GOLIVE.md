# Go-live licence — procédure d'ACTIVATION (prod, pilote-first)

> ⚠️ Tant que cette procédure n'est pas exécutée, l'enforcement est **DORMANT**
> (`licensePinnedKeysProvider` vide → `Entitlement.none()` → aucun blocage).
> Chaque étape est réversible jusqu'au pin des clés + déploiement de la fonction.
> Décisions : `docs/adr/ADR-licence.md`. Code : `epilote/lib/licensing/`,
> `supabase/functions/license-issuer/`.

## 0. Prérequis serveur (une fois)
- **Compteur de version monotone** : remplacer le `version` INTERIM de la fonction
  (`epoch(updated_at)`) par un compteur dédié, p.ex. colonne
  `school_groups.license_version int not null default 0` incrémentée à chaque
  émission (ancre anti-rollback autoritaire — ADR-0005).

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
```bash
supabase secrets set \
  LICENSE_PRIVATE_KEY_PKCS8_B64="$(cat license_priv.pkcs8.b64)" \
  LICENSE_KID="2026-07" LICENSE_OFFLINE_WINDOW_DAYS="30"
supabase functions deploy license-issuer --project-ref wqpdamlnrwgozfvzjjpo
```
> À ce stade la fonction émet, mais **aucun appareil ne vérifie encore** (clés
> non épinglées). Toujours dormant côté app.

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
Rollout par vagues (zone/groupe), en surveillant. Garder le **feature-flag serveur
d'assouplissement** (punch-list C) pour revenir à dormant instantanément si besoin.

## Rollback
- Vider `licensePinnedKeysProvider` → dormant immédiat (prochaine build).
- Ou `supabase functions delete license-issuer` → plus d'émission (les licences
  déjà en coffre expirent via la fenêtre de confiance).

## Vérifications automatiques déjà en place
`epilote/test/licensing/` (23 tests, dont round-trip Ed25519 réel) valide toute la
chaîne client signature→décodage→validation→phase. Le déploiement n'ajoute que le
côté serveur d'émission.
