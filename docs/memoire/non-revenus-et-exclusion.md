---
name: non-revenus-et-exclusion
description: "Détection des élèves non revenus (3e onglet du Passage) + exclusion définitive — ⚠️ academic_years.school_id est NULL, les années sont portées par le GROUPE"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T14:41:54.176Z
---

# Les deux façons de disparaître d'un effectif (2026-08-03)

Suite de [[motifs-de-sortie-eleve]] : les motifs existaient, rien ne les
DÉCLENCHAIT.

## Non revenus — 3e onglet du Passage

`features/evaluation/providers/non_revenus_provider.dart` +
`screens/non_revenus_section.dart`. `YearEndRegimeTabs` est passé d'un booléen
à l'enum **`YearEndTab { passage, examen, nonRevenus }`**.

**⚠️ LE GARDE-FOU COMPTE PLUS QUE L'ÉCRAN.** Tant que la rentrée n'est pas
saisie, personne n'a d'inscription dans l'année en cours → la requête déclare
TOUTE l'école disparue (868 alertes). En dessous de **30 %** de réinscriptions
(`BilanRentree.rentreeSaisie`), l'écran se tait et explique. Une liste fausse
ne se rattrape pas.

**⚠️ PIÈGE DE DONNÉE MAJEUR : `academic_years.school_id` est NULL** — les années
sont portées par le **GROUPE**, pas par l'école (plusieurs lignes peuvent
partager une période). Résoudre « l'année précédente » par identifiant pouvait
désigner une ligne sans inscription → même effet catastrophique. La requête
raisonne donc **par élève** : `ROW_NUMBER() OVER (PARTITION BY student_id
ORDER BY ay.start_date DESC)` sur les inscriptions `active` antérieures.
Vérifié sur données réelles : 868 → 700 réinscrits, 168 non revenus.

Motif écrit : **`non_reinscrit` et rien d'autre** — « l'école ignore ce qu'il
est devenu ». Écrire « abandon » inventerait une cause. Qui SAIT passe par la
fiche de l'élève.

## Exclusion définitive

`exclusion_definitive` **manquait** à `kSanctions` (`core/utils/discipline_vocab.dart`) :
une école qui renvoyait un élève pour de bon n'avait aucun mot pour le dire.
Ajoutée, avec `sanctionMetFinALaScolarite()`.

Le formulaire d'incident **PROPOSE** de fermer l'inscription (motif
`exclusion`) — jamais automatique : c'est un acte d'établissement, le chef
peut attendre le conseil de discipline. Refuser n'affecte pas la sanction.
`exclusion_temporaire`, `exclusion_cours` et `conseil_discipline` ne ferment
**rien** — test garde-fou sur chaque sanction de la liste.

## Où c'est branché

- `prononcerNonRetour(ids)` et `prononcerExclusion(...)` : `db.execute` local
  (offline-first, espace école).
- La date de la SANCTION fait foi si connue, pas le jour de la saisie.

Liens : [[motifs-de-sortie-eleve]] · [[cloture-examen-classes]] ·
[[vie-scolaire-categorie]] · [[ine-identifiant-national-eleve]]
