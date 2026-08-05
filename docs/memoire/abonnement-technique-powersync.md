---
name: abonnement-technique-powersync
description: "Audit technique d'implémentation du système de licence offline (PowerSync/Supabase/SQLite) — décisions d'archi validées"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

Audit technique (2026-07-04) de l'implémentation du système de licence conçu dans [[abonnement-architecture-offline]]. Phase design, rien codé. Verdict : techniquement sain, s'intègre proprement, faible dette SI on respecte la séparation ci-dessous.

**PRINCIPE FONDATEUR : la licence NE transite PAS par PowerSync.** C'est un credential, pas de la donnée métier → deux voies parallèles qui ne se rejoignent qu'à l'app.

**1. Intégration PowerSync**
- Licence PAS dans une table synchronisée / PAS dans les buckets. Raison : toute table du schéma PowerSync est localement INSCRIPTIBLE (db.execute crée un CRUD local lu avant réconciliation) + SQLite en clair inspectable.
- Stockage = coffre dédié `flutter_secure_storage` (Keychain/Keystore), PAS le SQLite PowerSync → découple du `disconnectAndClear()` (ne pas effacer la licence sur bascule d'agent).
- ⚠️ Desktop Linux/Windows : secure storage FAIBLE (libsecret dépend d'un démon parfois absent) → l'intégrité repose sur la SIGNATURE, pas le coffre (défense en profondeur seulement).
- Intégration = écouter `SyncStatus.connected` de PowerSync pour déclencher un refresh de licence hors-bande (réutiliser le signal, pas coupler).
- Option recommandée : PETITE table synchronisée read-only `{group_id, license_version, updated_at}` = pointeur de changement bon marché ; falsifié = inoffensif (fetch inutile). Découple « signal » (sync) de « credential » (hors-bande).
- Renouvellement = fetch hors-bande + swap atomique → ZÉRO contact file CRUD/buckets, aucune interférence synchro métier.

**2. Cycle technique** : Abonnement change → Edge Function `license-issuer` ISOLÉE (clé privée) → signe token compact → distribution par PULL HTTPS authentifié (login/connect/refresh) ou paquet d'activation signé (canal offline rural) → validation (signature via kid + group_id==identité + version≥repère + issued_at cohérent) → écriture ATOMIQUE coffre + MAJ repère → décodage EntitlementState mémoire → archivage AUDIT seulement (jamais réactiver une archivée).

**3. Format** : JWS/JWT signé **Ed25519** (64o, vérif sub-ms, en-tête `kid` pour rotation). Payload : group_id, plan, modules[], quotas, valid_from/to, offline_window, version, issued_at. Zéro PII.

**4. Vérification — SÉPARER 2 coûts** : crypto (0,1-2ms, ÉVÉNEMENTIELLE : démarrage + arrivée nouvelle licence, jamais en boucle) vs entitlement (µs, lookup mémoire, à la demande). Stratégie : service centralisé (provider Riverpod keepAlive `EntitlementState`) + garde légère = 2ᵉ verrou (plan) inséré dans le `redirect` de app_router.dart (réutilise cascade rôle→plan→profil→périmètre). Réévaluation dates = tick 1×/jour + au premier plan (pas de crypto). ANTI-PATTERN : vérifier signature dans build()/db.watch().

**5. Perf** : impact ~nul si crypto hors chemin chaud. EntitlementState = qq Ko. Aucune requête SQLite pour un droit (mémoire) → ne concurrence pas les I/O PowerSync.

**6. Sécu impl** : intégrité = SIGNATURE (pas stockage) ; clé publique épinglée multi-kid, privée jamais dans l'app ; repère version = valeur anti-rollback la plus sensible ; remplacement atomique (write-temp→vérifie→commit, échec = garder l'ancienne) ; fail-soft obligatoire (jamais briquer) ; group_id==identité à l'application ; temps monotone entre synchros.

📄 **Design consolidé → `docs/ABONNEMENT_LICENCE_ARCHITECTURE.md`** (spec unique + découpage vagues 0-4, ancrée sur le code existant : `SubscriptionModel` online + cascade `redirect` app_router).

Choix : Ed25519 + JWS + coffre dédié + pointeur version synchronisé. Prochaine étape possible : modèle métier états/transitions, puis schéma tables serveur + Edge Function émettrice.
