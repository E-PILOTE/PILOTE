---
name: demo-metp-donnees-kinkala
description: "Données de démo pour le 25/08/2026 : programmes collège + notes 3ème A semés sur Collège Public de Kinkala ; + duplications de classes à nettoyer"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-23T01:41:52.590Z
---

**Démo METP prévue le 25 août 2026.** École vitrine : **Collège Public de
Kinkala** (`d1000000-0000-4000-8000-000000000007`, groupe
`da3954ca-e2a4-486e-ac07-a2ebf992f2c6`, année courante 2025-2026
`da000000-...-a1`, 3e trimestre courant `5ab68657-...`, directeur Aline Massamba
`dfb227bd-...`).

**Semé le 2026-07-23** (SQL direct → PowerSync réplique) :
- **6 matières collège** créées (Anglais, SVT, Physique-Chimie, Histoire-Géo,
  Éducation Civique, EPS) ; réutilise Français/Maths existants.
- **Programmes** (`class_subjects`) des 4 classes collège peuplées : 6ème A(14),
  5ème A(15), 4ème A(15), 3ème A(15). 6ème/5ème = 7 matières ; 4ème/3ème = 8
  (+Physique-Chimie). Coef Français/Maths 4, sciences/langues/HG 2, ECM/EPS 1.
- **3ème A entièrement notée** (classe examen BEPC) : 16 évaluations (Devoir
  coef 1 + Composition coef 2 par matière), 240 notes. Distribution réaliste :
  moyenne classe **11,75**, **67 % d'admis**, éventail complet de mentions
  (Insuffisant→Très Bien) — montre le barème corrigé [[bareme-mention-source-unique]].
- Script : `scratchpad/seed_demo.sql` (idempotent).
- ⚠️ Bulletins **non générés** (laissé à faire en démo live) ; programmes des
  3 autres classes prêts pour saisie live.

**✅ Déduplication des classes faite (2026-07-23).** Les niveaux collège étaient
en double : `Nème A` (riche : programme + notes) ET `Ne A` (fine : 8 élèves,
rien). Zéro recouvrement d'élèves (2 séries distinctes de vrais élèves, séquence
MAT-07-xxx). **Fusionné** les fines DANS les riches (convention groupe = `Nème A`,
7 écoles), repointé les 7 candidats BEPC + 1 stage (portés par la 3e fine),
supprimé les 4 classes fines. `scratchpad/dedup_classes.sql` + backups CSV.
Résultat : 1 classe/niveau, 3ème A = **23 élèves** tous notés — moyenne **12,85**,
**74 % d'admis**, **6 mentions couvertes** (Insuffisant→Excellent).
⚠️ Le re-seed a d'abord **dupliqué les 16 évaluations** (insert non gardé) :
corrigé — `seed_demo.sql` évaluations désormais idempotent (`WHERE NOT EXISTS`
sur classe/matière/titre) + notes mappées sur les VRAIES évals en base
(`_evalmap`, plus `_evals.id`). Doublons purgés.

Rappel : sans programme (`class_subjects`), la création d'évaluation est
bloquée (« Aucune matière au programme ») → ni Notes ni Bulletins démontrables.
