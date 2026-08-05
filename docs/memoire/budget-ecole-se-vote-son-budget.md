---
name: budget-ecole-se-vote-son-budget
description: "Dette connue — l'école crée/modifie/supprime ses propres lignes de budget alors que le groupe devrait les attribuer ; HORS PÉRIMÈTRE tant que le user ne l'ouvre pas"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-05T06:12:20.638Z
---

`budget_lines` a `school_id NOT NULL` et `budget_provider.dart` fait `INSERT`,
`UPDATE` **et `DELETE`** depuis l'espace école : **une école se vote elle-même
son budget annuel de fonctionnement**. C'est exactement le défaut corrigé sur
les barèmes de frais ([[frais-public-vs-prive]]) — même table-pattern, même
absence de référence opposable.

Le 2026-08-05 le user a posé la doctrine « tout quitte du ministère (groupe
scolaire) » **et** a explicitement demandé de **ne pas toucher au budget pour
l'instant** — « garde en mémoire, nous allons pas à pas ».

**Why:** la dette est réelle et identifiée, mais l'ouvrir en même temps que les
barèmes doublait la surface de risque à deux mois du déploiement national. Le
user séquence volontairement.

**How to apply:** ne pas modifier `budget_lines`, `budget_provider.dart` ni la
règle de synchro du budget sans demande explicite. Quand le sujet s'ouvrira :
même remède que les frais — écriture réservée à `admin_groupe` par RLS,
`school_id` signifie « s'applique à » et non « créé par », l'école consulte et
consomme. ⚠️ Différence de nature à ne pas oublier : un barème est un **prix**
(règle appliquée à N élèves), un budget est une **enveloppe** (quantité
consommée) — le versioning temporel des barèmes ne se transpose pas tel quel.
