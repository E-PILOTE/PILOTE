---
name: journal-audit-hors-ligne-chiffrage
description: "Ce que coûterait de faire descendre le journal d'audit sur le poste — ⚠️ `now()` est INTERDIT en sync-rules, une fenêtre glissante n'est pas exprimable ; et `audit_logs` descend DÉJÀ, limitée aux 3 tables d'EDT"
metadata:
  node_type: memory
  type: project
---

**2026-09-01.** Chiffrage préparé pour une décision produit, pas une décision
prise. `/user/journal-audit` lit Supabase en direct depuis l'espace personnel —
ce qui viole la règle centrale, et la route l'assume en commentaire (« online »).

## Ce qui a déjà été corrigé, sans préjuger de la suite

⚠️ Hors ligne, la page affichait ses onglets, ses filtres, **et rien d'autre**.
Le garde `scope == null` ne couvre PAS ce cas : le profil vient de PowerSync,
donc le périmètre se résout très bien sans réseau ; ce sont les requêtes qui
échouent, et la seule branche d'erreur était un `SizedBox.shrink()`.

Un directeur y lisait « aucun événement » là où il fallait lire « je n'ai pas
pu regarder ». **C'est le refus muet de la RLS transposé à la LECTURE** :
l'absence d'information prend l'apparence d'une information. Corrigé, et gardé
par `test/audit_scope_test.dart`.

## Le fait qui change la question : `audit_logs` DESCEND déjà

Trois requêtes dans `by_school`, volontairement limitées aux tables d'EDT
(`timetable_slots`, `timetable_exceptions`, `timetable_versions`) — le
commentaire dit « data-minimization ». Ce n'est donc pas un oubli, et élargir
est **mécanique** : une requête de plus par `table_name` voulu. PowerSync
n'accepte pas `IN (liste)` en data-query, seulement `=` ou `IN (SELECT …)`.

## ⚠️ Une fenêtre glissante n'est PAS exprimable

`now()` est interdit dans les sync-rules : elles doivent être déterministes,
PowerSync pré-calcule l'appartenance aux buckets. `WHERE created_at > now() -
interval '90 days'` ne passera jamais. Les contournements documentés sont une
colonne `sync_actif` retournée par un cron, ou les Sync Streams (bêta).

C'est **exactement le piège du JOIN** ([[circulaires-hors-ligne]]) : une idée
naturelle, invalide dans ce moteur, et qui ne se découvre qu'au déploiement.

## Le coût, mesuré

| | |
|---|---|
| octets utiles par ligne d'audit | **367** (moyenne mesurée) |
| plus gros diff observé | 928 o |
| volume actuel | 83 lignes, dont 15 rattachées à une école |

Le volume actuel n'est pas représentatif (usage de développement). L'ordre de
grandeur utile est donc **par millier de lignes : ≈ 0,37 Mo**.

Pour une école, l'audit porte désormais 15 tables (mig 0170) : notes,
bulletins, inscriptions, évaluations, paiements, paie, élèves, incidents,
matières, niveaux, tarifs et EDT. Un ordre de grandeur raisonnable est **1 000
à 5 000 lignes par école et par an**, soit **0,4 à 1,8 Mo par poste et par an**.
À comparer à la base locale actuelle : 23,7 Mo pour 131 élèves.

## Les options, et ce qu'elles coûtent vraiment

| | ce qu'il faut faire | coût | ce qu'on obtient |
|---|---|---|---|
| **A — statu quo** | rien | 0 | page honnête hors ligne, mais vide |
| **B — élargir à tout** | +12 requêtes de données | 0,4-1,8 Mo/école/an, **non borné** | journal complet hors ligne |
| **C — B + fenêtre glissante** | colonne `sync_actif` + cron pg_cron | idem borné | quelques Mo économisés |
| **D — élargir au sensible** | +6 requêtes (notes, bulletins, paiements, paie, inscriptions, évaluations) | ~la moitié de B | ce qu'un directeur consulte vraiment |

⚠️ **L'option C est celle qu'il faut écarter en premier**, et c'est
contre-intuitif : elle demande une colonne, un cron et une mécanique de
péremption pour économiser quelques mégaoctets sur un poste qui en porte déjà
vingt-quatre. Le coût de la machinerie dépasse le coût du stockage.

Le vrai arbitrage est **A contre D** : un journal d'audit consultable hors
ligne est-il attendu d'un produit offline-first, ou est-ce une donnée de
gouvernance qu'on accepte de ne lire qu'en ligne ? Ce n'est pas une question
technique.

Voir [[audit-module-partage-scope]] · [[circulaires-hors-ligne]] ·
[[blocage-de-file-visible]]
