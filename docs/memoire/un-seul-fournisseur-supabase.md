---
name: un-seul-fournisseur-supabase
description: 🟢 DÉCISION 2026-08-29 — la plateforme n'a QUE Supabase, Firebase/FCM est écarté définitivement ; le canal de notification est la table `notifications` + PowerSync + la cloche. Espace élève/parent planifié EN DERNIER.
metadata:
  node_type: memory
  type: project
---

# Un seul fournisseur : Supabase

**Décision du propriétaire, 2026-08-29** — verbatim : « nous utilisons que
supabase et non firebase », et « l'espace eleve et parent seront à la fin ».

Ce n'est **pas** un ajournement de FCM, c'est un remplacement. Le cahier des
charges (règle métier n°3) promettait « notification push FCM » : la promesse
est tenue par un autre canal, meilleur sur ce terrain précis.

## Pourquoi le remplacement est un gain, pas un renoncement

|  | FCM | table `notifications` + PowerSync |
|---|---|---|
| Windows (les écoles) | **jamais** — Android/iOS seulement | oui |
| Poste éteint au moment de l'événement | perdu | **retrouvé au démarrage** |
| Hors ligne | rien | oui, c'est la base locale |
| Fournisseur supplémentaire | Firebase | aucun |

Les écoles travaillent sur des **postes Windows partagés** — secrétariat,
surveillance et direction s'y succèdent. Un push n'aurait jamais sonné là où le
travail se fait. La cloche, elle, est *stockée* et non *diffusée* : c'est ce qui
la rend robuste à la coupure, qui est l'état normal au Congo.

Ce qui existe et fonctionne déjà : table `notifications`, déclencheurs
`notify_on_announcement` / `notify_on_message`, synchro PowerSync, cloche et
tiroir de l'en-tête. Le personnel scolaire lit **en local**
(`_notificationsOffline`), voir [[espace-ecole-coquille]].

## Ce que le build 3.3.1+21 a retiré

Deux colonnes mortes, **côté client seulement** :

- `profiles.fcm_token` — 0 valeur sur 344 profils. C'est une **clé d'appareil** :
  qui la détient peut faire sonner le téléphone d'un collègue. Retirée du schéma
  PowerSync **et** de `ProfileModel`.
- `notifications.fcm_message_id` — 0 valeur sur 121 lignes. Retirée du schéma
  PowerSync.

Garde : `epilote/test/notification_sans_firebase_test.dart` (aucune dépendance
ni import Firebase, aucun code ne touche le jeton, les sync-rules ne le
projettent pas, la cloche reste offline pour le personnel).

## ⚠️ Le piège de la migration 0146 — à ne PAS appliquer trop tôt

`database/migrations/0146_APRES_TOUS_LES_POSTES_...sql` fait les deux `DROP
COLUMN`. **Elle attend que TOUT le parc soit passé en ≥ 3.3.1+21.**

Le danger n'est pas la perte de données (les colonnes sont vides), c'est le
**blocage de synchro** : un poste resté sur un build antérieur déclare encore
`fcm_token` dans son schéma local, donc l'envoie dans ses upserts `profiles`.
Contre une colonne disparue, PostgREST répond **42703** — que
`_fatalResponseCodes` (`^22`, `^23`, `^42501`) ne reconnaît pas. Le connecteur
ne complète donc pas la transaction : il **rejoue le lot indéfiniment**. Ce
poste n'envoie plus rien, jamais, sans le moindre message à l'écran.

C'est la même famille de piège que [[bug-powersync-role-utilisateur]] : une
synchro morte en silence. Deux colonnes nulles ne coûtent rien ; une école dont
les inscriptions ne remontent plus coûte tout.

## Espace élève et parent — planifié EN DERNIER

Sur 344 profils : **zéro parent, zéro élève** (enseignant 202, secrétaire 37,
surveillant 37, directeur 27, comptable 22, proviseur 11, admin_groupe 7,
super_admin 1). `/user/espace-parent` est un `StaffComingSoonScreen` et la
plateforme compte 2 tuteurs en tout.

La décision de le traiter en dernier **ferme une question qui revenait** : la
règle n°3 ne peut pas être « complète » côté familles tant que les familles
n'ont pas de compte, et ce n'est pas un défaut à corriger — c'est l'ordre du
chantier. Ne plus le compter comme une dette.
