# Notifications d'échéance d'abonnement — Design

- **Date** : 2026-07-05
- **Branche** : `feat/notifications-echeance-abonnement`
- **Statut** : validé (brainstorming), prêt pour plan d'implémentation
- **ADR liés** : ADR-0009 (hard-lock uniforme jour-même), ADR-0006/C4 (ne jamais gater la synchro)

## Problème

Le hard-lock tombe **le jour même** de l'échéance (ADR-0009, Edge Function `license-issuer` v7 en prod). Aujourd'hui, rien n'avertit **proactivement** avant ce mur :

- L'**admin_groupe** (le payeur) ne voit le bandeau `SubscriptionBanner` que s'il ouvre l'app ; aucune entrée dans la cloche, aucune poussée quand il ne regarde pas.
- Le **super_admin** n'a pas de vue « qui expire quand / combien est dû » pour relancer activement.
- Le **personnel école** (offline) est bloqué sans préavis sur son appareil : `LicenseBanner` n'affiche rien tant que la phase est `active` (`phase==active → SizedBox.shrink()`).

Objectif : rendre l'échéance **visible et poussée** aux trois audiences avant le blocage, pour maximiser le recouvrement — sans complexité inutile et sans jamais gater la synchro (C4).

## Décisions de cadrage (brainstorming)

- **Audiences** : admin_groupe (payeur) **+** super_admin (recouvrement) **+** tout le personnel école (avant le mur).
- **Staff visé** : *tout* le personnel voit le compte à rebours (pression sociale interne au paiement — choix propriétaire).
- **Approche retenue** : **hybride** — moteur serveur `pg_cron` pour les audiences online ; bandeau client calculé localement depuis la licence signée pour le staff offline.

## Faits d'ancrage (code réel vérifié le 2026-07-05)

| Élément | État réel |
|---|---|
| Table `notifications` | Existe : `id, group_id (NOT NULL), recipient_id (NOT NULL→profiles), type, title, body, data jsonb, is_read, read_at, sent_at, created_at, updated_at`. Synchronisée PowerSync par `recipient_id`. |
| Cloche in-app | `notifications_provider.dart` : online (`recipient_id == moi`) pour super_admin/admin_groupe, offline SQLite pour le staff. Realtime câblé. |
| Bandeau admin | `core/widgets/subscription_banner.dart` : `SubscriptionBanner` (admin_groupe only) — compte à rebours ≤30 j + grâce + lecture-seule. Monté `app_shell.dart:166`. |
| Phase admin online | `subscription_access_provider.dart` : `computeSubscriptionAccess` (active/grace/readOnly), `expiresSoon` (≤30 j). Fail-soft `unknown()`. |
| Bandeau staff | `licensing/presentation/license_banner.dart` : `LicenseBanner` — **n'affiche QUE grace + readOnly** ; `phase==active → rien`. Monté `app_shell.dart:165` (staff only). |
| Entitlement staff | `entitlementProvider` → `Entitlement` porte `license.validTo` (déjà signé/synchronisé). `phaseAt(now)`, `canWriteAt`, `isHardLockedAt`. |
| `pg_cron` | **Pas encore utilisé** (aucun `cron.schedule` en base). Standard Supabase PG17 → à activer par migration. |
| Réglages | `platform_settings.data` (jsonb, 1 ligne id=1). **Clés existantes réutilisées** (déjà exposées dans `super_admin/screens/settings_screen.dart`) : `notif_subscription_expiry` (flag master on/off) + `notif_reminder_days` (champ texte des seuils). Aussi `grace_days`, `due_days`. |

## Architecture — 5 composants

### § 1. Moteur serveur `pg_cron` (audiences online)

Migration `database/migrations/0029_subscription_reminders.sql` :

1. `create extension if not exists pg_cron;`
2. Table-ledger d'idempotence :
   ```sql
   create table subscription_reminder_log (
     group_id         uuid not null references school_groups(id),
     subscription_end date not null,   -- cycle courant
     threshold        int  not null,   -- seuil J-X (30/15/7/1/0)
     notified_at      timestamptz not null default now(),
     primary key (group_id, subscription_end, threshold)
   );
   ```
3. Fonction `emit_subscription_reminders()` (SECURITY DEFINER) :
   - **Garde master** : si `platform_settings.data->>'notif_subscription_expiry'` est explicitement `false` → ne rien émettre (respecte le toggle super_admin existant). Absent → activé (fail-soft).
   - Lit les seuils depuis `platform_settings.data->>'notif_reminder_days'` (champ texte, **parse CSV** en liste d'entiers, ex. `"30,15,7,1,0"` ou `"7"`). Vide/illisible → défaut codé `{30,15,7,1,0}`.
   - Pour chaque `school_groups` avec `subscription_end` non nul :
     - `days_left = subscription_end - current_date`.
     - Si `days_left` ∈ seuils **et** pas déjà dans le ledger pour `(group, subscription_end, days_left)` :
       - `insert` dans le ledger (le `PK unique` garantit l'idempotence même si le cron rejoue).
       - `insert` une `notifications` (`type='abonnement_echeance'`, `title`/`body` selon J-X, `data = {end, threshold, plan_id}`) **par profil admin_groupe** du groupe (`profiles.role='admin_groupe' and group_id=…`).
   - Fail-soft : aucun admin_groupe → aucune notif (pas d'erreur). Seuils illisibles → défaut codé.
4. `select cron.schedule('subscription-reminders', '0 6 * * *', $$select emit_subscription_reminders()$$);` (06:00 UTC quotidien).

**Idempotence = le nerf.** Le ledger a le `PK (group_id, subscription_end, threshold)` : rejouer la fonction n'émet jamais de doublon. Un renouvellement (nouveau `subscription_end`) ouvre un nouveau cycle → les seuils se rejouent proprement.

**Aucune touche aux sync-rules.** Les notifs ciblent des `recipient_id` admin_groupe (online) — elles ne fuient pas vers le staff (qui ne synchronise que ses propres `recipient_id`).

### § 2. Réception admin_groupe (le payeur)

- Les notifs atterrissent dans la cloche via le chemin online **existant** de `notificationsProvider` — **aucun code de lecture à écrire**.
- Ajout : mapping d'icône + route pour `type='abonnement_echeance'` dans le drawer/timeline de notifications → tap ouvre `Routes.adminAbonnement`. (`notification_types.dart` / `notifications_drawer.dart`.)
- `SubscriptionBanner` inchangé.

### § 3. Vue recouvrement super_admin (lean)

- Provider `dunningProvider` (`FutureProvider`, online, pur read-model) : `school_groups` (⋈ `subscription_plans`, ⋈ impayés `group_invoices`) triés par `subscription_end`, rangés en **3 seaux** par une **fonction pure** `bucketDunning(...)` :
  - `expire ≤7 j` (encore actif), `en grâce` (échu ≤ grâce), `échu/impayé` (au-delà + montant dû).
- Rendu : **panneau compact « Recouvrement »** ajouté à l'écran factures super_admin existant (`super_admin/screens/invoices_screen.dart`) — pas de nouvel écran ni route lourde. Réutilise `InvoiceDetail`.
- Le montant dû par groupe agrège `group_invoices` `isOverdue/isPending`.

### § 4. Avertissement staff avant le mur (client, offline)

- **Extension de `LicenseBanner`** (ne pas créer de widget) :
  - Nouvel état **compte à rebours** : quand `phase==active` **et** `license.validTo` non nul **et** `daysLeft ∈ [0..30]` (ou sous seuil), afficher en ambre : « Abonnement de l'établissement expire dans X jour(s) ; au-delà, l'accès aux modules sera suspendu. »
  - État `hardLock` (rouge, cadenas) : « Accès aux modules suspendu — abonnement à renouveler auprès de votre administration. » (visible sur la zone neutre où le staff reste, cf. `RenewalWallScreen`).
  - Ordre de priorité d'affichage : `hardLock` > `readOnly` > `grace` > compte à rebours > rien.
- Calcul 100 % local depuis `license.validTo` (déjà signé/synchronisé) → **zéro backend, zéro sync-rule, s'affiche hors-ligne**.
- Label extrait en **fonction pure** `subscriptionCountdownLabel(DateTime? validTo, DateTime now)` (dans `license_banner.dart` ou un helper voisin) pour être testable sans widget.
- Le tick 6 h + `resumed` déjà en place assure la bascule de jour sans redémarrage.

### § 5. Réglages + tests

- **Seuils** : réutilise `platform_settings.data.notif_reminder_days` (déjà édité dans `super_admin/screens/settings_screen.dart`) + garde master `notif_subscription_expiry`. Lus côté SQL (§1) ; défaut fail-soft `[30,15,7,1,0]`. **GUI déjà en place** — au plus, faire accepter un CSV au champ existant (aujourd'hui mono-valeur) : ajustement mineur, pas un nouvel écran.
- **Tests** :
  1. `subscriptionCountdownLabel` (pur, Dart) : seuils exacts, singulier/pluriel, J0 « aujourd'hui », `validTo` nul → rien, dépassé → rien (laisse la main aux états grace/hardLock).
  2. `bucketDunning` (pur, Dart) : classement dans les 3 seaux aux frontières (7 j, grâce, au-delà), montant dû agrégé.
  3. Priorité d'affichage `LicenseBanner` : hardLock > readOnly > grace > countdown > rien.
  4. Idempotence SQL : appeler `emit_subscription_reminders()` deux fois pour un groupe à J-7 → **1 seule** ligne ledger + **1 seule** notif/admin (test SQL ciblé exécuté sur la base, ou pgTAP minimal).

## Invariants (non négociables)

- **C4** : aucun composant ne gate la synchro PowerSync.
- **Fail-soft** : au doute (pas de licence, pas d'admin, seuils illisibles, réseau) → on n'entrave rien et on ne spamme pas.
- **Offline natif** : le staff n'a besoin d'aucun réseau pour son compte à rebours (source = licence locale).
- **Pas de fuite** : les notifs d'échéance ne ciblent que les admin_groupe (`recipient_id`), jamais synchronisées vers le staff.
- **Convention** : fichiers Dart ≤ 500 lignes ; logique en fonctions pures testables.

## Périmètre exclu (YAGNI)

- Email / SMS (pas d'infra confirmée).
- Nouvel écran GUI de réglage (les clés `notif_subscription_expiry` / `notif_reminder_days` existent déjà dans les réglages super_admin).
- Notification serveur au staff (le bandeau client couvre le besoin).
- Relance automatique / facturation (hors périmètre : ce chantier *informe*, il ne facture pas).

## Livrables

1. `database/migrations/0029_subscription_reminders.sql` (pg_cron + ledger + fonction + schedule).
2. Étendu : `licensing/presentation/license_banner.dart` (+ `subscriptionCountdownLabel`).
3. Nouveau : `super_admin/providers/dunning_provider.dart` (+ `bucketDunning`) et panneau Recouvrement dans `invoices_screen.dart`.
4. Mapping notif `abonnement_echeance` (icône/route) dans la couche communication.
5. Tests : countdown, bucketing, priorité bandeau, idempotence SQL.
