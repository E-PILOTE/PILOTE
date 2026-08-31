---
name: blocage-de-file-visible
description: "Un poste qui n'envoie plus rien le DIT désormais (kind='blocage') ; ⚠️ 42703 n'est PAS devenu fatal — le rendre fatal jetterait les écritures de l'école"
metadata: 
  node_type: memory
  type: project
---

**2026-08-31.** Le pire défaut possible d'un produit hors-ligne, corrigé.

## Le défaut

`SupabasePowerSyncConnector.uploadData` traite trois familles comme définitives
(`^22…`, `^23…`, `^42501`) : il abandonne la transaction, journalise la perte,
affiche un bandeau. **Tout le reste est `rethrow`** → PowerSync rejoue.

Pour une panne réseau, c'est exactement ce qu'il faut. Pour un **désaccord de
schéma** — `42703`, colonne inconnue, parce que le poste tourne sur un build
antérieur — le rejeu ne réussira **jamais**. L'école continue de travailler,
tout paraît normal à l'écran, et **plus une seule inscription ne remonte**.

C'est aussi ce qui tenait [[abonnement-infra-reelle-hardlock]] et surtout la
migration **0146** en otage : on ne retire pas une colonne tant qu'un poste
resté en arrière se bloque en silence.

## ⚠️ Ce qu'il ne fallait PAS faire

**Ajouter `42703` aux codes fatals.** Ç'aurait été jeter les écritures saisies
par l'école pour lui épargner un bandeau — le remède pire que le mal. Un test
le garde (`test/sync_blocage_test.dart`, groupe « Les deux familles ne doivent
JAMAIS se recouvrir »).

## Ce qui a été fait

Le rejeu est **conservé** (rien n'est perdu, le lot reste en file) et le blocage
devient **visible** :

| | |
|---|---|
| détection | `estDesaccordDeSchema()` — `42703`, `42P01`, `42804`, `42883`, `42P10` |
| signalé | **dès le 1er échec** pour ces codes ; après **5 échecs identiques** pour les autres (`40001`, `53300` se résolvent seuls) |
| journal | `sync_failures` gagne `kind` : `'abandon'` (perdu) \| `'blocage'` (arrêté) |
| identifiant | **déterministe** `'blocage:<code>'` + `INSERT OR REPLACE` — le rejeu revient toutes les secondes, sans cela le journal se remplirait de milliers de lignes identiques |
| effacement | **automatique** à la première transaction réussie. Aucun acquittement : un indicateur de blocage qu'on acquitte à la main finit acquitté pour toujours |

⚠️ **`_blocagePeutEtreEnBase` vaut `true` au démarrage, délibérément.** Le
drapeau mémoire repart à faux à chaque lancement, mais la ligne, elle, survit
dans SQLite. Sans cette valeur initiale, la première transaction réussie
sauterait l'effacement et **le bandeau resterait affiché pour toujours sur un
poste réparé** — un indicateur qui ment dans ce sens-là ne sera plus jamais cru
dans l'autre.

⚠️ **Réserve non vérifiée** : `sync_failures` est une `Table.localOnly`, et
l'ajout de la colonne `kind` provoque une mise à jour du schéma local. Je n'ai
PAS vérifié si PowerSync conserve les lignes existantes d'une table local-only
lors d'un changement de schéma. Au pire, un poste perd son journal de pertes
NON ACQUITTÉES au moment de la mise à jour — diagnostic, pas donnée métier,
mais à savoir avant de s'appuyer dessus pour un incident en cours.

## Deux messages, jamais le même mot

- **blocage** (orange, `cloud_off`) : « Ce poste n'envoie plus rien au serveur.
  **Rien n'est perdu** : vos saisies repartiront dès la mise à jour. »
- **abandon** (rouge, `sync_problem`) : « n'a pas pu être synchronisée et **n'a
  pas été enregistrée** » → il faut ressaisir.

Dire « perdu » sur un blocage ferait ressaisir une école pour rien ; dire « en
attente » sur un abandon lui ferait attendre un envoi qui n'aura jamais lieu.
Le bandeau trie : un blocage passe devant, il arrête TOUT l'envoi du poste.

## La chasse systématique aux refus muets (2026-08-31)

Le même défaut trouvé cinq fois en deux jours méritait d'être cherché partout
d'un coup, pas une fois de plus par hasard.
`database/checks/0166_refus_muets_de_la_rls.sql` sonde les **86 tables
synchronisées** sous l'identité d'un DIRECTEUR — le rôle scolaire le mieux doté,
donc ce qu'il ne peut pas faire, personne de l'école ne le peut — et classe
chaque DELETE en **permis / lève / muet**.

| 2026-08-31 | |
|---|---|
| permis | 6 |
| lèvent (bon comportement) | 3 |
| **sans ligne visible — NON TESTÉES** | **50** |
| muets | 8 |

⚠️ **Un refus muet n'est PAS un défaut en soi.** Une table de référentiel du
groupe DOIT refuser la suppression au personnel d'école. Le défaut, c'est le
refus muet **plus un écran qui propose le geste**. D'où la seconde moitié,
au dépôt : `grep -rn "DELETE FROM <table>" epilote/lib`.

Croisement fait : sur les 8 muets, une seule table (`school_holidays`) a un
chemin de suppression hors ligne — et l'écran l'interdit déjà pour les lignes
nationales (cadenas « Férié légal fixé par le groupe »). Son commentaire décrit
mot pour mot le défaut cherché : « je l'ai supprimé et il est revenu ».
**Aucun défaut nouveau.**

⚠️ **Et la limite compte autant que le résultat** : 50 tables sur 86 n'ont
aucune ligne visible dans la base de démonstration, donc n'ont pas été testées.
« Rien trouvé » vaut pour les tables peuplées, pas pour le schéma. À rejouer sur
une base réelle — c'est pour ça que le contrôle est rejouable.

## Ce que ça débloque

Le jour où un build portant cette détection sera **adopté**, retirer une colonne
cesse d'être un pari : un poste resté en arrière le DIRA. C'est la condition qui
manquait à `0146` — et à tout futur changement de schéma.

Voir [[chaine-livraison-windows]] · `docs/DEPLOIEMENT_ORDRE.md`
