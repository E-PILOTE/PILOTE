---
name: alerte-echeance-cinq-jours-et-ecole
description: "⏰ L'alerte d'échéance : réglable (elle l'était déjà), ramenée à 5 j, et enfin visible dans les écoles — mig 0106, échelle cloche/bandeau/grâce"
metadata:
  type: project
---

# L'alerte d'échéance passe à 5 jours et atteint l'école

Décidé et livré le **2026-08-14** (mig `0106`, appliquée en prod).

## Ce qui existait déjà (ne pas re-construire)

Le réglage **était déjà dynamique** depuis la mig `0097` : clé
`platform_settings.data->>'subscription_alert_days'`, servie en ligne par la RPC
`get_subscription_settings()`, champ dans l'écran Paramètres super_admin, lue
par 4 consommateurs (`subscription_banner`, `admin_dashboard_provider`,
`admin_subscription_provider`, `dunning_provider`).

⚠️ **Mais elle n'avait JAMAIS été réglée** : `platform_settings.data` ne
contenait que `trial_days`. Tout tournait sur les défauts SQL. Vérifier la
valeur en base avant de conclure qu'un réglage « ne marche pas ».

## L'échelle d'escalade (le modèle à retenir)

Deux canaux, deux rôles, jamais confondus :

```
J-30 🔔  J-15 🔔  J-7 🔔  │ J-5 🟠 BANDEAU │  J-1 🔔  J0 🔔
                          J+1 ⛔ hard-lock école
                          J+15 🔴 lecture seule groupe
```

- **🔔 cloche** (`notif_reminder_days`, cron pg 06:00) = information datée,
  ponctuelle → peut sonner **tôt** sans fatiguer. Défaut **30,15,7,1,0**.
- **🟠 bandeau** (`subscription_alert_days`) = pression permanente sur toutes
  les pages → doit venir **tard**. Défaut **5** (valait 30, puis 7).

Raison du décalage : le METP paie 2 500 000 XAF par circuit du Trésor ; 5 jours
de préavis ne suffisent pas à monter un mandat, mais un bandeau de 30 jours
n'est plus lu. On sépare prévenir et presser.

⚠️ **INVARIANT** : il doit toujours rester **au moins un seuil de rappel
≤ `alert_days`** (sinon la cloche se tait pile dans les jours qui décident du
paiement). Testé (`remindersCoverAlertWindow`), et l'écran Paramètres affiche un
avertissement quand la règle est violée.

## Comment le réglage atteint une école HORS LIGNE

Le poste école ne peut pas lire `platform_settings` (RLS super_admin, table non
synchronisée), et la licence signée ne pouvait pas servir de véhicule :
l'émission est bornée par `LICENSE_PILOT_GROUP_IDS`, donc **quasiment aucun
groupe n'a de licence** — le compte à rebours staff, branché sur
`license.validTo`, ne s'affichait pratiquement jamais.

Solution : **colonne miroir `school_groups.subscription_alert_days`**, recopiée
par trigger depuis `platform_settings`. `school_groups` descend déjà en entier
sur chaque appareil (`SELECT * FROM school_groups WHERE id = bucket.gid`) →
**aucune sync-rule à redéployer**, il a suffi d'ajouter la colonne au schéma
local Dart. La source de vérité reste `platform_settings` ; ne jamais écrire
dans la colonne à la main.

## Ce qui a bougé dans le code

- `core/utils/subscription_days.dart` — accueille `kSubscriptionAlertDays` (5),
  `alertDaysLeft`, `parseReminderDays`, `remindersCoverAlertWindow`. C'est le
  seul endroit où vit la sémantique de la fenêtre, partagée online/offline.
- `core/widgets/school_subscription_banner.dart` — **NOUVEAU** : compte à rebours
  école, PowerSync pur, indépendant de toute licence.
- `licensing/presentation/license_banner.dart` — a **perdu** son compte à
  rebours (et `subscriptionCountdownLabel`) : il ne traite plus que les phases
  de licence (grâce / lecture seule / hard-lock).
- `super_admin/widgets/subscription_cycle_section.dart` — **NOUVEAU** bloc
  « Cycle d'abonnement » : les 4 réglages réunis (ils étaient répartis sur deux
  onglets), frise de l'échelle, contrôle de cohérence live.
- `admin_dashboard_screen.dart` — ⚠️ piège Flutter : un
  `SingleChildScrollView` **ne remplit pas** son axe de défilement
  (`size = constraints.constrain(child.size)`). Dans une `Column` en
  `crossAxisAlignment.center`, les onglets se retrouvaient CENTRÉS. L'`Align`
  retiré « parce que le viewport colle déjà à gauche » était indispensable.

## État vérifié le 2026-08-14

RPC → `{alert_days: 5, grace_days: 15, reminder_days: "30,15,7,1,0"}` ; les 7
groupes portent le miroir à 5. METP échoit le **31/08** (J-17) avec le seuil 30
déjà journalisé → **aucune notification de rattrapage** ; la prochaine tombera
à J-15 le 16/08. EDEC est échu depuis le 31/07.

Liens : [[abonnement-notifications-echeance]] · [[abonnement-etat-reel-enforcement]] ·
[[licence-dernier-jour-paye]] · [[abonnement-infra-reelle-hardlock]]
