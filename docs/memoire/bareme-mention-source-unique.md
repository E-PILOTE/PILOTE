---
name: bareme-mention-source-unique
description: "Le barème des mentions avait dérivé de 2 points côté bulletins (8/20 = « Passable ») ; unifié dans core/utils/mention.dart + migration 0059, vérifié en GUI le 2026-07-23"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-23T00:46:09.941Z
---

**Le bug** (constaté à l'écran, 2026-07-23) : le barème des mentions vivait en
**trois exemplaires** — `GradeModel.mention`, `mentionFor()` du module
Bulletins, et la fonction SQL `get_mention()`. Deux avaient dérivé de **deux
points**, et c'est la version décalée qui **s'imprimait sur les bulletins** :
15/20 ressortait « Très Bien », et surtout **8/20 — une note d'échec —
ressortait « Passable »**.

⚠️ Piège : `CLAUDE.md` **et** deux jeux de tests affirmaient/verrouillaient
l'alignement — la dérive avait l'air délibérée. Elle ne l'était pas.

**Barème officiel (METP, confirmé par l'utilisateur)** :
Excellent ≥18, Très Bien ≥16, Bien ≥14, Assez Bien ≥12, Passable ≥10,
Insuffisant <10 ; barre de réussite **10/20**.

**Correctif** (commit `f4dea28`) :
- **Source unique** : `lib/core/utils/mention.dart` (`mentionFor`, `isPassing`,
  `kPassingMark`). `bulletins_provider.dart` la ré-exporte ; `grade_model.dart`
  la réutilise.
- **Migration 0059** : réécrit `get_mention()` — ⚠️ garder le type de retour
  `character varying` (pas `text`), sinon Postgres exige un DROP. Table
  `bulletins` vide à l'application → rien à reprendre (sinon
  `UPDATE bulletins SET mention = get_mention(overall_average)`).
- Tests : `test/mention_test.dart` (10, seuil + juste-en-dessous) ;
  `evaluation_logic_test.dart` réaligné (il verrouillait l'ancien barème).
- `CLAUDE.md` corrigé.

**Toute modif future touche le Dart ET le SQL** — les deux doivent rester
identiques, sinon la mention change selon qu'on la lit à l'écran ou en base.

Voir [[evaluation-notes-bulletins]], [[perte-silencieuse-identifiants-vides]].
