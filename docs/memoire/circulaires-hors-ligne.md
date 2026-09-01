---
name: circulaires-hors-ligne
description: "La circulaire descend jusqu'au chef d'établissement hors ligne (0167) — ⚠️ les Sync Rules INTERDISENT le JOIN en requête de paramètres, le plan noté dans le dépôt était faux ; l'instantané figé remplace la jointure ; ⚠️ sync-rules NON déployées"
metadata:
  node_type: memory
  type: project
---

**2026-09-01.** La circulaire de tutelle ([[circulaire-de-tutelle]], 0161)
s'arrêtait à l'admin de groupe, en ligne. Le chef d'établissement — celui dont
l'accusé fait toute la valeur administrative de la note — ne la recevait pas.

## ⚠️ Le plan que le dépôt gardait ne pouvait PAS marcher

`sync-rules.yaml` conservait, en commentaire, un bucket dont la requête de
PARAMÈTRES joignait `circulaire_destinataires` à `profiles`. Le commentaire
disait « pas vérifié contre le moteur ». Vérifié : **il était faux.**

> Les Sync Rules PowerSync interdisent explicitement les JOIN, les
> sous-requêtes et les CTE dans une requête de paramètres, et n'autorisent
> **qu'une seule table**.

La règle aurait échoué à `validate` — ou, collée sans contrôle, serait passée
sans rien faire descendre. Les JOIN existent dans les **Sync Streams** (bêta,
qui remplaceront les Sync Rules) : pas à quatre semaines du déploiement
national.

Docs : `docs.powersync.com/usage/sync-rules/parameter-queries` et
`.../operators-and-functions`.

## Ce qu'on a fait à la place : ne rien avoir à joindre

`circulaire_destinataires` porte déjà `school_id`, donc elle se filtre seule.
**0167 y pose l'INSTANTANÉ de la circulaire** (objet, corps, référence,
priorité, échéance, accusé requis, nom de l'émetteur, date de publication),
écrit une seule fois par `circulaire_publier`.

⚠️ **Ce n'est pas un cache, c'est un instantané.** Une circulaire publiée est
immuable par construction : aucune politique d'UPDATE (0161), republication
refusée `23505`, assiette des destinataires figée à la publication. Et comme
[[une copie qui ne peut pas diverger|0164]], la base l'impose : un déclencheur
`BEFORE UPDATE` **LÈVE 42501** si l'instantané bouge. Pas un `USING` — un
`USING` qui écarte rend zéro ligne alors que le poste a déjà changé sa copie
locale, et l'écran dirait « enregistré ». Voir [[blocage-de-file-visible]].

`lu_le` / `lu_par` sont volontairement HORS de la comparaison : c'est la seule
chose qui bouge dans la vie d'une circulaire.

## ⚠️ Pourquoi PAS un bucket « par tutelle », qui aurait été plus simple

Une colonne `tutelle` sur `profiles` et toutes les circulaires du ministère
descendues à toutes ses écoles : moins de code, aucune duplication. Et
`cible_secteur` / `cible_departement` seraient devenus **décoratifs** — une
école délibérément exclue du ciblage aurait reçu le texte quand même. Une école
reçoit ce qui lui est adressé, rien d'autre.

**Coût assumé** : le corps est dupliqué par établissement destinataire.
0 circulaire et 0 destinataire en base au moment du changement — le moment le
moins cher possible. À l'échelle nationale, ~2 Ko × 1 000 écoles par
circulaire côté serveur, quelques dizaines de Ko par poste et par an.

## ⚠️ Bucket SÉPARÉ, jamais une ligne de plus dans `by_school`

Modifier un bucket existant en change le contenu : les postes resynchronisent
**tout** ce qu'il porte — élèves, inscriptions, candidatures d'examen — pour
une note de deux pages. Le bucket `circulaires_ecole` est neuf, donc seul son
contenu descend. Un test le garde.

## Lecture hors ligne, accusé EN LIGNE — et c'est délibéré

`circulaire_destinataires` n'a **aucune politique d'UPDATE**. Un accusé écrit
localement partirait, ne toucherait aucune ligne et **se tairait**. L'accusé
passe donc par la RPC `circulaire_accuser` — qui acceptait déjà un utilisateur
d'école (`OR auth_school_id() = p_school_id`), rien à changer côté droits.

Le bouton est **désactivé et non masqué** quand le poste est hors ligne
(`isSyncingProvider`), avec sa raison : masquer ferait croire qu'aucun accusé
n'est attendu. Une preuve administrative ne s'invente pas sur un poste.

## Un seul provider, deux chemins

`circulairesRecuesProvider` est devenu un **`StreamProvider` scope-aware** :
`CommScope.school` → `db.watch()` local ; sinon → Supabase en ligne. Même
écran pour les deux espaces, conformément à la règle « pas de duplication par
espace ». Route `/user/circulaires`, gardée par `directionRoles` **au routeur
ET dans la sidebar** — l'accusé engage l'établissement.

`circulaire_publier` notifie désormais aussi le chef d'établissement, vers sa
propre route (`/user/circulaires`) : sans cela il ne découvrirait la note qu'en
ouvrant l'écran de lui-même, alors que c'est de lui qu'on attend l'accusé.

## Mesuré le 2026-09-01 (transaction annulée, identité MEPSA réelle)

| | résultat |
|---|---|
| publication | 25 établissements / 6 groupes |
| instantanés écrits | 25, **0 ligne creuse** |
| notifications chefs d'établissement | 14 |
| notifications admin de groupe | 1 |
| réécrire le corps / l'objet / déplacer l'école | **REFUSÉ 42501** |
| accuser (`lu_le`) | **passe** — 1 ligne |

⚠️ **Le premier test mesurait la RLS, pas le déclencheur.** L'UPDATE lancé sous
l'identité MEPSA touchait zéro ligne (aucune politique d'UPDATE) et se taisait :
le déclencheur n'était jamais atteint. Il a fallu repasser en rôle propriétaire
pour le mettre à l'épreuve. Une sonde qui traverse la RLS ne prouve rien sur ce
qu'il y a derrière.

## ⚠️ CE QUI N'EST PAS ENCORE LIVRÉ

| pièce | état |
|---|---|
| migration 0167 | ✅ **appliquée** en production |
| build portant le schéma local + l'écran | ✅ **v3.4.3 (build 27) publiée**, mise à jour ouverte au parc |
| `sync-rules.yaml` (bucket `circulaires_ecole`) | ✅ **déployé sur Production `…66759`** le 2026-09-01 |

**La chaîne est complète.** Déroulé du déploiement, dans l'ordre prescrit :
`pull instance` AVANT (diff live ↔ dépôt = le seul bucket attendu, donc rien à
préserver du tableau de bord) → `validate` (dont **`Validate Sync Config`**,
l'étape que la version avec JOIN aurait échouée) → `deploy sync-config` →
`pull instance` APRÈS (**diff vide**) → `status` : `Initial replication done:
true`, lag 3 432 octets, et `public.circulaire_destinataires` dans les tables
répliquées.

⚠️ **Ma première vérification d'après-déploiement ne prouvait rien** : le
second `pull` écrit dans `sync-fetched.yaml`, PAS dans `sync-config.yaml`. Je
comparais donc ma propre copie au dépôt — identique par construction. C'est
`sync-fetched.yaml` qu'il faut differ.

## ✅ Éprouvée de bout en bout le 2026-09-01, sur un vrai poste

Deux circulaires d'essai publiées, au rayon le plus étroit possible :

| réf. | émetteur | ciblage | destinataires |
|---|---|---|---|
| `ESSAI-2026-001` | MEPSA | dépt **Bouenza** | 1 — École Primaire de Madingou |
| `ESSAI-2026-002` | METP | dépt **Sangha** | 1 — CET de Ouésso (**le poste de recette**) |

`ESSAI-2026-002` visait délibérément l'école du poste de développement : après
75 s d'application ouverte, sa base SQLite locale contient **une ligne**, avec
l'instantané complet — émetteur, référence, objet, priorité, `accuse_requis=1`,
échéance, `publiee_le`, et les 227 caractères du corps. `lu_le` reste nul.

⚠️ **Et le ciblage se prouve par la NÉGATIVE** : il n'y a qu'UNE ligne en
local. La circulaire MEPSA n'est pas descendue — autre tutelle, autre école.
Un bucket qui descendrait tout aurait donné deux lignes.

La chaîne complète est donc vérifiée : `circulaire_publier` → instantané figé
sur la ligne du destinataire → bucket `circulaires_ecole` → SQLite du poste.
Notifications comprises : 1 au chef d'établissement (route `/user/circulaires`,
ouverte par `context.go` depuis le tiroir) et 1 à l'admin de groupe.

⚠️ Les deux circulaires d'essai sont de VRAIES lignes en production. Leur objet
le dit. À supprimer quand elles auront servi — un `DELETE` sur `circulaires`
emporte ses destinataires.

⚠️ **Conséquence tant que la règle n'est pas déployée** : l'écran existe et la
vue locale est créée (vérifié sur une base réelle après installation), mais
elle reste VIDE. Sans effet visible aujourd'hui — il y a 0 circulaire en base —
et sans effet non plus le jour où la règle partira : ce qui aura été publié
entre-temps descendra à ce moment-là.

Le déploiement des sync-rules exige un `PS_ADMIN_TOKEN` — voir
[[powersync-deploiement-cli]] — et vise **Production `…66759`**, jamais
Development.

✅ **L'ordre est sans risque, et c'est vérifié** : une table qui descend avant
d'être déclarée dans le schéma client est conservée dans `ps_untyped`,
inaccessible mais intacte, et PowerSync l'extrait **automatiquement** quand le
build la déclare. Déployer la règle avant le build ne perd rien.

Voir [[circulaire-de-tutelle]] · [[blocage-de-file-visible]] ·
[[powersync-deux-instances]]
