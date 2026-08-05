---
name: abonnement-etat-reel-enforcement
description: "État RÉEL du système d'abonnement (base live) + implémentation ➊+➋ (matérialisation serveur + soft-gate online admin_groupe)"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

Audit code+base LIVE (2026-07-04) puis 1ʳᵉ implémentation d'enforcement. Complète le design [[abonnement-architecture-offline]] / [[abonnement-technique-powersync]] par l'état du terrain.

**⚠️ La table `subscriptions` N'EXISTE PAS.** La vérité d'abonnement vit sur **`school_groups`** : `plan_id`, `subscription_status` (enum: trial/active/suspended/expired/cancelled), `subscription_start`, `subscription_end`. Le `SubscriptionModel` (mappe une table `subscriptions`) est trompeur ; le provider online lit bien `school_groups` (`admin_subscription_provider.dart:245`, modèle réel = `GroupSubscription`).

**Cause du bug « abonnement expiré → accès maintenu » = DEUX défauts :**
1. **Matérialisation incomplète (serveur)** : le cron `expire_subscriptions()` (pg_cron `expire-subscriptions`, tous les jours 01:05) ne basculait que `status='active'`. Les `trial` échus restaient `trial` pour toujours (ex. METP, fin 2026-06-28). → **corrigé par `database/migrations/0025_expire_subscriptions_trial.sql`** : `WHERE status IN ('active','trial')`. Déployé + exécuté en prod (METP → expired). `suspended`/`cancelled` volontairement non touchés.
2. **Zéro enforcement** : même en `expired`, RIEN ne le lit. `activeModulesProvider` (`module_navigation_provider.dart:50`) ne lit que `plan_id` (jamais effacé) ; le `redirect` de `app_router.dart` n'a pas de verrou plan ; **0 policy RLS** ne gate sur `subscription_status` (vérifié `pg_policies`) ; `check_quota` ignore le statut ET n'est pas appelé côté client.

**➋ Soft-gate ONLINE admin_groupe LIVRÉ (2026-07-04, non commité, PAS encore GUI-vérifié)** :
- `features/admin_groupe/providers/subscription_access_provider.dart` : enum `SubscriptionPhase{active,grace,readOnly}` + `computeSubscriptionAccess()` (fonction PURE testée, 11 tests `test/subscription_access_test.dart`) + `subscriptionAccessProvider` (online, lit `school_groups`, **fail-soft** : erreur/inconnu ⇒ `active`, ne bloque jamais au doute) + garde `ensureSubscriptionWritable(ref,context)`.
- Cascade : `active` → `grace` (échu ≤ **15 j**, `kSubscriptionGraceDays`, accès complet + alerte) → `readOnly` (au-delà, OU suspended/cancelled sans grâce). Robuste au retard du cron (calcul date locale).
- `core/widgets/subscription_banner.dart` : bandeau shell (ambre grâce/fin proche, rouge lecture seule) → `Routes.adminAbonnement`. Câblé dans `app_shell.dart` (gaté `role==adminGroupe`, à côté de `SyncFailureBanner`).
- Read-only câblé sur les créations coûteuses : `_openCreate` de `admin_schools_screen` + `admin_users_screen`.

**Périmètre ➋ v1 (à compléter)** : lecture seule NON encore posée sur édition/désactivation, attribution de modules, autres écrans admin. Le personnel **offline** n'est PAS gaté (= Vagues 1-3 du design licence). RLS serveur (vraies dents) volontairement écarté du v1 (risque couperet sur réconciliation offline).

`flutter analyze` = 0. **Reste** : GUI-vérifier le bandeau (login admin_groupe d'un groupe expiré — seul METP l'est), puis commit ; puis ➌/Vague 0 (clés Ed25519 + 2 étages de licence).
