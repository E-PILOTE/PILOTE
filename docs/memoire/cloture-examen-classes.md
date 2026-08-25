---
name: cloture-examen-classes
description: "Clôture des classes d'examen — 2e onglet de /user/passage : reporter la proclamation DEC, réinscrire les ajournés, prononcer les sorties diplômées"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-01T06:27:32.911Z
---

`/user/passage` porte désormais **deux onglets** (`YearEndRegimeTabs`) : *Classes
de passage* (le conseil décide) et *Classes d'examen* (la DEC proclame). Réunis,
ils couvrent TOUTES les classes de l'école — aucune ne peut rester sans issue au
30 juin. Code : `features/evaluation/{providers/cloture_examen_provider.dart,
screens/cloture_examen_section.dart}` ; commit fdb514d, 19 tests.

**Why:** le résultat DEC restait une ligne dans `exam_candidates` sans toucher la
scolarité. `graduated` existait dans l'enum et **aucune ligne de code ne
l'écrivait** ; l'ajourné — cas le plus fréquent — devait être ressaisi à la main
comme un élève inconnu.

**How to apply:**
- Règle de report : `admis` ⇒ `passe`, `ajourne`/`absent` ⇒ `redouble`, `fraude`
  ⇒ rien (conseil de discipline). Écrit dans `class_enrollments.promotion_*`
  (mig 0074), jamais par-dessus une décision manuelle.
- ⚠️ La classe qui suit une classe d'examen **change de cycle** (3ème → 2nde) :
  `_nextLevelClass` cherche `level_order+1` du même cycle **puis** le premier
  niveau du cycle supérieur. `level_order` seul ne trouve jamais rien.
- ⚠️ `nextLevelClass == null` est ambigu : école sans niveau suivant **ou**
  structure non reconduite. D'où `nextYearHasStructure` — sans lui on proposait
  de prononcer des sorties diplômées (irréversibles) par erreur.
- `graduateLeavers` est la **seule** écriture de `status = 'graduated'` : geste
  explicite, jamais automatique, l'élève sort des effectifs actifs.
- Piège de lecture rencontré ici : [[powersync-is-active-egalite-stricte]].

Voir [[evaluation-notes-bulletins]], [[metp-partage-dec-classes-passage]].
