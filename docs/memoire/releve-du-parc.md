---
name: releve-du-parc
description: "📡 Relevé du parc (2026-08-29, mig 0150) — `app_installations` + RPC `signaler_version` ; ⚠️ le chiffre qui décide est `jamais_signale`, PAS `a_jour` ; seuil `0146` = build **24** (21/22/23 jamais distribués) ; table HORS PowerSync"
metadata:
  node_type: memory
  type: project
---

# Savoir quelle version tourne où (2026-08-29, migration 0150)

## Le trou

`docs/DEPLOIEMENT_ORDRE.md` faisait dépendre `0146` d'une condition écrite noir
sur blanc — « tous les postes l'ont reçu » — que **rien** ne permettait
d'observer. `build_number` n'existait que dans `app_releases` : ce qui est
**proposé**, jamais ce qui est **installé**.

Une condition qu'on ne peut pas observer est une condition qu'on finira par
supposer. Et se tromper ici ne se voit pas : `0146` supprime une colonne que les
postes en retard envoient encore → 42703 → non reconnu par `_fatalResponseCodes`
→ le lot rejoue indéfiniment → **ce poste n'envoie plus rien, jamais, sans un
mot à l'écran**.

## ⚠️ L'ABSENCE DE SIGNALEMENT EST LE SIGNAL

Les builds antérieurs à 24 n'ont pas le code pour se signaler : ils
n'apparaîtront **jamais** dans `app_installations`. Un profil absent est donc
soit sur une version ancienne, soit jamais revenu — indiscernables, et tous deux
des risques.

D'où la règle du provider : `certitude` est **faux** dès qu'un seul profil est
en retard **ou** muet. Jamais « probablement oui ».

Le piège que les tests tiennent : le jour de la mise en service la table est
vide, et un calcul naïf (« 0 en retard sur 0 connus = 100 % ») annoncerait une
couverture parfaite alors qu'on ne sait rien de personne.

**`partConnue` est un taux de CONNAISSANCE, pas de mise à jour.** Les confondre
ferait lire un échec comme un succès.

## ⚠️ Le seuil est 24 — ni 21, ni 23

Les colonnes Firebase ont quitté le schéma local au build **21**, mais **21, 22
et 23 n'ont jamais été distribués** : `app_releases` ne contenait que 3.3.0+20 et
le dépôt public que `v3.3.0`. Le parc passe donc de **20 à 24** directement.

Et 24 est aussi le premier build qui sait se signaler — ce qui rend le seuil
doublement juste.

`kBuildSansFirebase = 24` dans `super_admin/providers/parc_provider.dart`.

## Décisions

- **RPC, pas PowerSync.** Ce n'est pas une donnée de travail : personne ne la lit
  hors ligne, elle n'a rien à faire dans les buckets d'une école. Elle voyage là
  où le poste demande déjà « existe-t-il une version plus récente ? » — même
  instant, même réseau, même silence quand il n'y en a pas. ⚠️ La table n'est
  **ni** dans `powersync_schema.dart` **ni** dans `sync-rules.yaml` ; un test le
  verrouille.
- **`unawaited`.** Un réseau lent ne doit pas retarder d'un aller-retour la seule
  chose qui compte : savoir qu'un correctif existe. Et une RPC absente (0150 non
  appliquée) ne doit pas emporter la vérification de mise à jour.
- **Le serveur décide du périmètre.** La RPC ne reçoit que version / build /
  plateforme ; profil, groupe et école sont dérivés de `auth.uid()`. Un client ne
  peut ni écrire pour autrui, ni mentir sur son périmètre. Aucune politique
  INSERT/UPDATE sur la table : elle ne se remplit que par la fonction
  `SECURITY DEFINER`.
- **Rien d'identifiant.** Pas d'ID d'appareil, pas d'IP, pas de matériel. Une
  ligne par profil suffit : si tous signalent ≥ N, tous les postes qu'ils
  utilisent sont ≥ N.
- **Le parc s'affiche AVANT le catalogue** dans l'écran Versions. L'ordre inverse
  laisserait croire que publier suffit.

## Où c'est

`database/migrations/0150_AVANT_LE_BUILD_savoir_quelle_version_tourne_ou.sql`
(appliquée) · `super_admin/providers/parc_provider.dart` ·
`super_admin/widgets/parc_section.dart` ·
`updates/providers/update_provider.dart` (`_signalerVersion`) ·
garde `test/parc_versions_test.dart` (13 tests).

Liens : [[deploiement-national-octobre]] · [[powersync-status]]

## ⚠️ Relevé du 2026-09-01 — il n'y a pas de parc

| | |
|---|---|
| installations déclarées | **1** (la machine de dev, build 27) |
| écoles actives | 37 |
| comptes actifs | 344 |
| comptes ayant OUVERT une session | **10**, entre le 06/08 et le 27/08 |

⚠️ **`app_installations` ne peut pas répondre à la question qu'on lui pose.**
Elle ne remonte que depuis le **2026-08-29** (migration 0150), et les 10
sessions datent toutes d'AVANT. Un poste resté sur un vieux build y serait donc
INVISIBLE : l'absence de vieux poste dans cette table n'est pas une preuve
d'absence.

⚠️ Autre colonne morte croisée au passage : **`profiles.last_login` est nulle
sur les 344 comptes** — elle n'est écrite nulle part. Le « 10 sessions » vient
de `auth.users.last_sign_in_at`, pas d'elle. Voir [[portail-parents-etat-reel]]
pour le même motif (`parent_portal_enabled`, retirée par 0168).

Conséquence pour [[blocage-de-file-visible]] et `0146` : la condition « tous
les postes ont le build » ne peut pas être VÉRIFIÉE par cette table. Ce qui a
débloqué le raisonnement est ailleurs — dans le code, pas dans le parc : voir
l'en-tête de `database/migrations/0146_*.sql`.
