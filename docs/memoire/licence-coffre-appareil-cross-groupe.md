---
name: licence-coffre-appareil-cross-groupe
description: "Bug poste partagé — licence d'un ancien groupe empoisonne le nouveau (staff voit \"abonnement expiré\" alors qu'actif) ; coffre licence appareil-global"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a40fc29-8762-4c8e-bbec-655c8bf3d09a
---

**Symptôme** (2026-07-08, pauline proviseur) : un membre du personnel voit « abonnement expiré / pas d'accès aux modules » alors que son groupe est ACTIF (admin_groupe le voit actif en ligne). Se produit quand la machine a DÉJÀ servi à un autre groupe scolaire dont l'abonnement/licence était expiré.

**Cause racine** : `SecureLicenseStore` (flutter_secure_storage) utilise une clé UNIQUE par appareil (`license_trust_state_v1`), sans scope par groupe. Sur poste partagé, la licence de l'ancien groupe reste dans le coffre. `LicenseService.bootstrap()` la renvoyait sans vérifier le `group_id` → le nouvel utilisateur héritait de la licence expirée. Pire : `refresh()` prenait le `version` de l'ancien groupe comme plancher anti-rollback → la licence légitime entrante (compteur `next_license_version` propre à chaque groupe, donc version plus basse) était rejetée en `rollback` et l'ancienne conservée. Le `timeHighWater` de l'ancien groupe faussait aussi l'horloge (`bestKnownNow`). ⇒ deux groupes ne pouvaient pas cohabiter sur une même machine.

**Diagnostic clé** : le serveur était SAIN — appeler l'Edge Function `license-issuer` avec le jeton du user (grant password → `/functions/v1/license-issuer`) puis décoder les claims JWS a montré `valid_to=2026-12-31` (futur), 28 modules, `provisional:false`. Donc le mal était 100 % côté client (coffre local).

**Fix livré** (commit 1041b19, `feat/poste-vitrine-securite`) : `bootstrap({expectedGroupId})` purge le coffre si `license.groupId != expectedGroupId` (repart version 0 + horloge murale) ; `refresh()` applique la purge en amont ; `license_providers.dart` passe `profile.groupId`. Fail-soft intact. 42 tests licence verts. ⚠️ Pour débloquer un poste déjà pollué : hot-restart app + re-login du user (la purge s'exécute au prochain `bootstrap`). Voir [[licence-socle-implemente]] [[abonnement-etat-reel-enforcement]].

**Piège dormant lié** : idem à surveiller pour le PIN de poste / autres données locales device-global lors d'un changement de groupe sur poste partagé.
