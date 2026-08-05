---
name: seed-demo-national-pipeline
description: "Le jeu de démonstration national vit dans database/seed/ 00→07 + 99_purge ; sans le 07 (droits), toute l'application est vide pour le personnel"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-02T19:53:05.683Z
---

# Le jeu de démonstration national — `database/seed/`

Reconstruit en août 2026 après le vidage de la base ([[base-videe-et-referentiel-restaure]]).
Tout identifiant vient de `seed_uuid(clé) = md5('epilote:seed:' || clé)::uuid` :
rejouable, idempotent, et **reconnaissable** — c'est ce qui permet à la purge de
n'effacer que ce que les seeds possèdent.

| Fichier | Contenu | Volume |
|---|---|---|
| `00_socle` | `seed_uuid()` | — |
| `01_ecoles_et_annees` | 37 écoles (15 départements), 2 années/groupe, profils d'accès | 7 groupes |
| `02_structure` | cycles, niveaux, matières, classes | 494 classes |
| `03_personnel` | comptes `auth.users` + profils | 342 comptes |
| `04_eleves` | élèves + inscriptions **2025-2026 seulement** | 9 104 |
| `05_evaluation` | trimestres, `class_subjects`, évaluations, notes, bulletins T1/T2 | 431 250 notes |
| `06_examens` | candidats + proclamation, sessions 2026-2027 ouvertes | 2 126 candidats |
| `07_droits` | `profile_permissions` | 665 |
| `99_purge` | exige `-v purge_confirm=oui` | — |

## ⚠️ Le 07 n'est pas facultatif — c'est le verrou qui bloquait tout

Un profil d'accès **sans `profile_permissions` n'ouvre RIEN**. Sans le 07, chaque
agent se connectait sur « Aucun module attribué » : les 431 250 notes existaient
et pas un écran ne les montrait. Le 07 reprend à l'identique les modèles du
produit (`_kPresets` dans `admin_access_screen.dart`) — un seed qui accorderait
d'autres droits montrerait un produit qui n'existe pas. Cf. [[modules-acces-hierarchie]].

- `profile_permissions.can_write` est une colonne **GÉNÉRÉE** (`can_create OR can_update`) : l'INSERT échoue si on la renseigne.
- `access_profiles` n'a pas de `slug` ; la clé est `role_type`.
- `profile_permissions.profile_id` désigne l'**access_profile**, pas le profil utilisateur.

## Ce qui est laissé VIDE exprès

2026-2027 a sa structure mais pas ses effectifs ; les bulletins du T3 ne sont pas
générés. C'est l'état d'un établissement en juillet — et ce sont les deux gestes
que la démonstration fait en séance (délibérer, réinscrire). Un jeu qui a déjà
tout fait ne prouve rien.

## Cohérence vérifiée

- `get_passage_merit` (SQL, mig 0061) retrouve **au millième près** les moyennes
  des bulletins semés : deux implémentations indépendantes, même résultat.
- Moyennes réseau T1→T3 : 11,50 → 11,99 → 12,50 (une cohorte qui stagne se voit).
- Taux d'examen ancrés sur la DEC : Bac T&P 50,48 % (national 51,61 %),
  BET 75,58 % (77,59 %). L'écart n'est PAS corrigé — cf. [[reseau-vs-national-reference]].
- `exam_candidates.average`/`mention` restent **NULL** : la DEC ne renvoie pas de
  notes ([[metp-partage-dec-classes-passage]]).

## Deux pièges trouvés en semant

- **Identités du personnel** : tirer un nom au hasard dans un pool de 16 pour 10
  agents garantit des collisions (paradoxe des anniversaires) — 4 homonymes dans
  une même école. Il faut dériver l'identité du **rang** de l'agent, par pas de
  17 (pas de 1 : seul le prénom bouge, toute l'école porte le même patronyme).
- **Deux années scolaires réveillent les filtres d'année dormants.** Tant qu'une
  seule année portait des classes, un `SELECT … FROM classes` sans
  `academic_year_id` marchait par accident. `examOverviewProvider` comptait donc
  4 classes d'examen pour 2 et affichait des lignes « 0 élève ». Chercher ce
  motif avant d'ouvrir une année.
