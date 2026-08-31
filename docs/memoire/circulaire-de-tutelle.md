---
name: circulaire-de-tutelle
description: "Le ministère ÉCRIT à son réseau (mig 0161) : note descendante + accusé PAR ÉTABLISSEMENT ; aucune politique d'UPDATE (RPC seules) ; ⚠️ school_type_enum ≠ group_type"
metadata: 
  node_type: memory
  type: project
---

**2026-08-31 — appliqué et vérifié en production.** Le pendant écrit de
« Réseau sous tutelle » : après avoir compté son réseau, un ministère lui écrit.

## Ce que c'est, et ce que ce n'est pas

Une note **descendante, datée et ACCUSÉE**. Pas une messagerie : ni fil, ni
réponse, ni destinataire individuel. **Toute la valeur tient dans la colonne
`lu_le`** — une circulaire dont on ne peut pas prouver la réception n'a aucune
valeur administrative.

⚠️ **Les destinataires sont des ÉTABLISSEMENTS, jamais des personnes.** La
chaîne est ministère → groupe / chef d'établissement. Jamais l'élève, jamais le
parent : ouvrir un canal par lequel l'État écrit aux familles d'une école privée
ne se décide pas par commodité technique, et **ne se referme plus**. Un test
(`test/circulaires_test.dart`) relit la RPC et échoue si elle touche `students`,
`student_tutors`, `'parent'` ou `'eleve'`.

## Les décisions qui tiennent

- **Deux temps : rédiger (brouillon) → publier.** La publication **fige** la
  liste des destinataires et ne se refait pas (`23505` à la republication).
  Une école créée le mois suivant n'a pas à apparaître « en défaut de lecture »
  d'une circulaire envoyée avant qu'elle n'existe : un taux de lecture qui bouge
  tout seul est un taux dont on ne peut rien conclure.
- **AUCUNE politique d'UPDATE.** Publier et accuser passent par deux RPC
  `SECURITY DEFINER`. Un UPDATE que le `USING` écarte ne lève RIEN — zéro ligne,
  204, « enregistré » à l'écran (piège trouvé 3× le 2026-08-30). Une RPC qui
  refuse, elle, LÈVE.
- **L'accusé se donne par ÉCOLE**, pas par groupe : un groupe de trois écoles
  qui accuserait « pour tout le monde » produirait une preuve fausse.
- **La première date d'accusé ne se réécrit jamais.** Rappuyer sur le bouton ne
  repousse pas la preuve dans le temps.
- **Publier affiche le nombre d'établissements touchés.** « Publiée » tout court
  laisserait le rédacteur sans moyen de vérifier son ciblage — et un ciblage trop
  étroit ne se voit pas.
- **`tauxLecture` vaut `null`, jamais 0 %, sans destinataire.** « 0 % lu » se
  lirait comme un échec de diffusion alors qu'il n'y avait rien à diffuser.

## Le piège qui a mordu

⚠️ **`school_type_enum` ≠ `group_type`.** Deux énumérations distinctes portant
les **mêmes libellés** (`public` | `prive`) : l'une sur le groupe, l'autre sur
l'école. `cible_secteur` avait été déclarée en `group_type` ; Postgres refuse la
comparaison (**42883**) — et seulement **à la publication**, donc au pire moment.
Pris par une sonde avant la première circulaire réelle.

## Mesuré sous les identités réelles (transaction annulée)

| | résultat |
|---|---|
| MEPSA publie | **25 établissements / 6 groupes** |
| republication | refusée `23505` |
| groupe privé émet | refusé **`42501`** |
| ce que voit le groupe privé | 1 circulaire, **3 destinataires** (ses écoles seulement) |
| accusé / ré-accusé | enregistré, puis `deja_lu` sans réécrire la date |
| ce que voit le MEPSA | 25 destinataires, 1 lu |

## ⚠️ Ce qui n'est PAS livré

La réception **hors ligne** par le chef d'établissement. Elle demande deux flux
PowerSync, écrits **en commentaire** dans `powersync/config/sync-rules.yaml` et
**non validés** contre le moteur : `circulaires` n'est pas filtrable par
`school_id` sans JOIN en paramètres, et les autres buckets l'évitent
volontairement. À reprendre au dashboard (coller → Validate → Deploy), et à
déclarer aussi dans `powersync_schema.dart`.

Aujourd'hui : émission `/admin/tutelle/circulaires` (tutelle seule), réception
`/admin/circulaires` (tout groupe), **en ligne**.

Voir [[tarif-par-ecole-et-couts-reels]] · [[abonnement-licence-de-tutelle]]
