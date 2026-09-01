---
name: booleen-defaut-vrai
description: "Un booléen NOT NULL DEFAULT TRUE lu `?? false` / `== 1` rend « non » ce qui n'est que « non renseigné » — ⚠️ le garde-fou nommait `is_active` EN DUR et a laissé passer trois fois le même défaut sous d'autres noms (2026-09-01)"
metadata:
  node_type: memory
  type: project
---

## La règle

Une colonne booléenne `NOT NULL DEFAULT TRUE` ne rend jamais `null` **depuis la
base**. Le `null` arrive par une autre porte :

- **en ligne** — la colonne n'était pas dans le `select()` (déjà arrivé : le
  bucket `directory` ne projetait aucune colonne de carrière) ;
- **hors ligne** — la ligne a été écrite par l'application sans renseigner la
  colonne, le défaut vivant côté serveur.

Dans les deux cas, l'absence signifie « rien ne dit le contraire », donc
**oui**. La lire `?? false`, `== 1` ou `== true` rend « non ».

| chemin | forme sûre |
|---|---|
| en ligne (`supabase.from`, `bool?`) | `actifEnLigne(...)` — `core/utils/booleen_en_ligne.dart` |
| hors ligne (SQLite PowerSync, `int?`) | `actifOffline(...)` — `core/utils/booleen_offline.dart` |
| SQL local | `COALESCE(col, 1) <> 0` |

⚠️ **Défaut FAUX = règle inverse, et irrattrapable.** Rien ne distingue
« faux » de « pas renseigné » : `?? false` y est JUSTE, et une colonne à défaut
faux dont la valeur compte doit être écrite explicitement à l'insertion.

## ⚠️ Ce que le 2026-09-01 a appris : un garde qui nomme UNE colonne ne garde qu'elle

`offline_booleen_test.dart` interdisait ces formes depuis le 18/08 — mais ses
expressions régulières contenaient littéralement `is_active`. **Trois fois le
même défaut est passé sous d'autres noms**, trouvés en balayant la BASE
(`information_schema`, `column_default = 'true'`) plutôt qu'en relisant du code :

| lecture | conséquence |
|---|---|
| `payment_methods_provider:80` — `is_test_mode ?? false` | une configuration de paiement en **TEST** comptée comme production, sur le tableau de bord de l'opérateur |
| `group_chat_provider:199` — `is_group == 1 \|\| == true` | un **groupe** affiché comme conversation à deux — et l'autre lecture du MÊME fichier disait déjà « oui » |
| `circulaires_provider` — `accuse_requis == 1` | « aucun accusé demandé » : la circulaire perd la seule chose qui lui donne une valeur administrative |

**Aucun des trois ne se voyait** : 0 conversation et 0 configuration de paiement
en base. Exactement ce qui rendait la divergence de `is_active` dangereuse en
août — elle ne se voyait sur aucun écran non plus.

Le garde-fou nomme désormais une **propriété** et non une colonne :
`_autresColonnesDefautVrai` dans `offline_booleen_test.dart`. Sa liste se met à
jour en **relevant la base**, pas en relisant le dépôt.

⚠️ **Vérifié qu'il se déclenche** : son prédicat, appliqué au code d'avant
correction, retrouve les trois lignes. Un garde-fou écrit après le correctif
passe toujours — ça ne prouve rien.

## ⚠️ Le piège des noms ambigus

`is_active` existe dans **31 tables**, dont **une** au défaut FAUX
(`payment_configs.is_active` — « activé seulement après configuration
complète »). Un garde-fou par nom seul y produit des faux positifs. D'où deux
régimes :

- `is_active` garde ses tests dédiés, qui ne lui interdisent que `== true`
  (`?? false` y est légitime pour `payment_configs`) ;
- les colonnes **sans homonyme** — `accuse_requis`, `is_group`, `is_present`,
  `is_public`, `is_test_mode`, `payment_confirmed` — sont gardées entièrement.

Avant d'ajouter une entrée : **revérifier le défaut en base**, il se change par
migration.

Voir [[blocage-de-file-visible]] · [[circulaires-hors-ligne]]
