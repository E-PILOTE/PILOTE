---
name: examens-frais-stats-convocations
description: "Frais d'examen branchés au revenu (mig 0058), statistiques de réussite, convocations et attribution en masse ; règles \"dette dérivée\" et \"taux sur résultats connus\""
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-18T16:02:37.665Z
---

Livré le 2026-07-18 (branche `feat/examens-nationaux`, commits après `8f2efac`).

**FRAIS D'EXAMEN = revenu de l'école, donc du groupe (ministère).** L'enum
`fee_type` contenait **déjà `frais_examens`** → aucune table nouvelle. Migration
**0058** : `fee_structures.exam_session_id`.
⚠️ Le lien est posé sur le **barème** et non sur la session : `exam_sessions` est
**nationale**, un barème est **par école**. Index unique (school_id, exam_session_id).

**La dette est DÉRIVÉE, jamais matérialisée** : `inscrits × montant − encaissé`.
Aucune ligne de paiement « en attente » — elles finiraient comptées comme du
revenu ou devraient être purgées à chaque désinscription. Le revenu ne compte
que l'argent reçu (`status = confirmed`). Voir `models/exam_fee.dart`, 10 tests.

**Relation Finance = aucun pont.** L'encaissement passe par `savePayment()` du
module Paiements → même reçu, même statut, même remontée au revenu. Un chemin
parallèle aurait divergé.
⚠️ **`student_payments.enrollment_id` est NOT NULL** mais `savePayment` l'accepte
`null` → un paiement sans inscription ferait rejeter la ligne et **abandonner le
lot PowerSync entier, silencieusement**. On résout via `resolveEnrollmentId()` et
on refuse net (`MissingEnrollmentException`). *Le reste du module Finance garde
ce risque latent — à auditer.*

**STATISTIQUES — le taux porte sur les résultats CONNUS**, jamais sur l'effectif :
sinon une session non proclamée afficherait 0 % et ferait passer une école
irréprochable pour sinistrée. Sans résultat connu, `rate` vaut **null**, pas zéro
(l'écran dit « en attente »). L'assiette est toujours affichée à côté du
pourcentage. `models/exam_stats.dart`, 10 tests. Calculé sur le **périmètre**
(`scoped`), pas sur la recherche texte.

**CONVOCATIONS** : une par page, un seul PDF pour tout le périmètre.
Imprimables même sans n° de candidat ni centre (la DEC les communique après le
début de la distribution) → mention « à compléter ».
`center_name` ajouté à `ExamCandidateRow` (LEFT JOIN `exam_centers`).

**ATTRIBUTION EN MASSE** : centre pour une sélection + numéros collés du tableur
DEC. Correspondance **POSITIONNELLE** → l'écran montre l'appariement et alerte si
le nombre de lignes diffère (un décalage d'une ligne donnerait à chaque élève le
numéro de son voisin, invisible jusqu'au centre d'examen). Lignes vides ignorées.

**« Voir » ≠ « Inscrire »** : c'était le même modal de cases à cocher, illisible
passé quelques dizaines d'inscrits. Désormais `class_candidates_dialog.dart`
(virtualisé + recherche + état dossier/frais). Voir [[examens-stages-dossiers-reels]].

**Bouton retour** : `onBack` optionnel remonté ModuleScaffold → AppShell →
AppHeader (additif, réutilisable par tout module).

État : analyze 0, **354 tests**, build release OK, `.deb` 3.0.2 reconstruit.
**Non vérifié en GUI** (pilote Nouveau instable) — cf. [[gui-testing-linux]].
