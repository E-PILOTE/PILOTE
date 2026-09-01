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

✅ **Réserve levée le 2026-09-01, sur une vraie base de 23,7 Mo.** La crainte
était qu'ajouter `kind` à une `Table.localOnly` fasse perdre les lignes. Elle
n'avait pas lieu d'être, et la raison vaut pour TOUTE table local-only :
PowerSync ne matérialise pas les colonnes. La table réelle est
`ps_data_local__sync_failures(id, data)` — les colonnes déclarées vivent dans
le JSON `data` et sont exposées par une **vue**. Un changement de schéma
recrée la vue, jamais la table : il ne peut structurellement rien perdre.

Mesuré après le premier démarrage d'un build portant la colonne : la vue
`sync_failures` expose bien `kind`, et la base a gardé son contenu (88 vues,
131 élèves, 9 profils, 8 classes).

⚠️ **Le piège de la mesure, lui, est réel.** Lire la base avec
`sqlite3.connect(..., mode=ro)` renvoie le fichier principal SANS appliquer le
`-wal` — ici 4 Ko d'en-tête contre 6 Mo de journal, soit trois jours de
changements invisibles. Et le Python de l'« install manager » (paquet MSIX)
**virtualise `%APPDATA%`** : il montrait un fichier fantôme là où `bash` et
PowerShell voyaient le vrai. Pour inspecter une base PowerSync : copier les
trois fichiers (`.db`, `-wal`, `-shm`) hors de `%APPDATA%` avec un outil non
virtualisé, puis ouvrir la copie en lecture/écriture.

## Deux messages, jamais le même mot

- **blocage** (orange, `cloud_off`) : « Ce poste n'envoie plus rien au serveur.
  **Rien n'est perdu** : vos saisies repartiront dès la mise à jour. »
- **abandon** (rouge, `sync_problem`) : « n'a pas pu être synchronisée et **n'a
  pas été enregistrée** » → il faut ressaisir.

Dire « perdu » sur un blocage ferait ressaisir une école pour rien ; dire « en
attente » sur un abandon lui ferait attendre un envoi qui n'aura jamais lieu.
Le bandeau trie : un blocage passe devant, il arrête TOUT l'envoi du poste.

## La chasse aux refus muets — reprise et corrigée le 2026-09-01

Le même défaut trouvé cinq fois en deux jours méritait d'être cherché partout
d'un coup. `database/checks/0166` l'a fait le 31/08 — et **annonçait une
couverture qu'il n'avait pas**.

| ce que 0166 disait | ce qui était vrai |
|---|---|
| « sonde les 86 tables synchronisées » | son tableau en listait **67** |
| | **87** descendent réellement sur les postes |
| | **20** n'avaient jamais été sondées |

Parmi les vingt : `audit_logs`, `schools`, `school_groups`, `staff_members`,
`payment_configs`, `profile_permissions`, et tous les référentiels
`education_*` / `exam_*`.

⚠️ **Et il ne sondait que `DELETE`** — alors que le défaut d'origine (0154,
0155, 0157) était un **UPDATE**.

⚠️ **Une sonde qui annonce une couverture qu'elle n'a pas est pire qu'une sonde
absente** : elle transforme « je n'ai pas regardé » en « j'ai regardé et il n'y
a rien ». Personne ne rouvre le second.

`database/checks/0169_refus_muets_update_et_delete.sql` la remplace : les deux
verbes, les 87 tables, et une liste **tenue par un test**
(`sync_rules_publient_le_schema_local_test.dart`) qui échoue dès qu'une table
publiée par un bucket n'y figure pas — dans les deux sens.

### Relevé du 2026-09-01, identité DIRECTEUR, transaction annulée

87 tables énumérées · **58 sans ligne visible** · 29 réellement testées.

| verbe | permis | lèvent | **muets** |
|---|---|---|---|
| UPDATE | 10 | **0** | **19** |
| DELETE | 6 | 3 | **20** (les 19 + `profiles`) |

⚠️ **Aucun UPDATE ne lève, jamais.** Tout refus d'écriture est silencieux : la
seule protection réelle est que l'écran ne propose pas le geste. `profiles` est
l'inverse instructif — un directeur peut MODIFIER un profil, pas le supprimer.

### Croisement au dépôt : un seul chemin, désormais gardé

Sur les 87 tables, un seul chemin d'écriture hors ligne vise une table muette :
**`school_holidays`**, en UPDATE et en DELETE
(`structure/providers/school_holidays_provider.dart`).

L'écran cadenassait déjà la croix sur les lignes nationales — mais
`updateHoliday` n'avait **aucun appelant**, ce qui en faisait une arme chargée :
le jour où quelqu'un y branche un bouton « modifier », il obtient « je l'ai
modifié et c'est revenu ». Les deux fonctions LÈVENT désormais
(`FerieNationalNonModifiable`) au lieu de laisser le serveur se taire.

### Complété le 2026-09-01 : la carte des écritures, et un second mode

⚠️ **PowerSync réplique en CONTOURNANT la RLS.** Un poste détient donc des
lignes que son utilisateur ne peut pas sélectionner en ligne — tous les
référentiels de groupe. La sonde les SAUTAIT, faute de pouvoir les lire. En
choisissant la ligne en rôle propriétaire puis en écrivant sous l'identité de
l'école : sur les **45 tables peuplées**, écrire une ligne qui n'appartient pas
à l'établissement est refusé **45 fois sur 45, toujours en silence**.
L'isolement entre établissements tient parfaitement ; il ne se signale jamais.

Croisement complet des 87 tables avec le dépôt : **58 reçoivent une écriture
hors ligne**, et ✅ **aucune n'est un référentiel de groupe ou national**.
`school_holidays` était la seule exception, refermée.

⚠️ **42 des 87 tables sont VIDES dans toute la base** : aucune identité ne les
rendra testables. C'est une limite de DONNÉES, pas de méthode — seul un jeu de
recette y changerait quelque chose.

**Aucun autre défaut.** Et la limite reste : 58 tables sur 87 n'ont aucune ligne
visible, donc ne sont pas testées. « Rien trouvé » vaut pour les tables
peuplées, pas pour le schéma.

## Ce que ça débloque

Le jour où un build portant cette détection sera **adopté**, retirer une colonne
cesse d'être un pari : un poste resté en arrière le DIRA. C'est la condition qui
manquait à `0146` — et à tout futur changement de schéma.

Voir [[chaine-livraison-windows]] · `docs/DEPLOIEMENT_ORDRE.md`
