---
name: demo-metp-seed-technique
description: "Jeu de démo METP (2026-07-25) : groupe Ministère existant enrichi — filières techniques, 80 candidats BET avec résultats ventilés, 52 stages"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-25T14:27:47.041Z
---

**2026-07-25 — Données de démonstration METP semées en PROD** (additif + idempotent, script `scratchpad/seed_metp.sql`, validé par dry-run `ROLLBACK` avant exécution).

**Le groupe METP EXISTAIT DÉJÀ** : `da3954ca-e2a4-486e-ac07-a2ebf992f2c6` « Ministère de l'Enseignement Technique et Professionnel », **14 écoles** (tutelle `metp`) sur 7 départements (Brazzaville, Pointe-Noire, Pool, Niari, Kouilou, Bouenza, Plateaux, Sangha). ⚠️ Ne PAS en créer un autre.

**État avant** : 40 classes / 297 élèves, mais **5 classes seulement avec filière** (séries générales A/C/D), **7 candidats**, **0 résultat proclamé**, **1 stage**, 0 `education_programs`.

**Ce qui a été semé** : filières **techniques** sur 14 classes de 4ᵉ/3ᵉ (dominante par école : `hashtext(school)%8 + hashtext(nom)%2`) ; **73 candidats BET** (session `cc38aa08…`, 2025-2026 ouverte) ; **80 résultats** proclamés ; 8 entreprises ; **51 stages** (85 % avec attestation — les 15 % restants alimentent VOLONTAIREMENT l'alerte « dossier bloqué »).

**Pourquoi le BET** : les écoles METP sont peuplées au **collège** (7 classes de 3ᵉ, 80 inscrits) et quasi vides au lycée (Tle ≈ 1 élève) ; or **BET = diplôme METP de cycle collège**. BEP/BAC_T/CAP/CQP/BTF existent en sessions ouvertes mais **sans classes `formation_pro` ni élèves** → les montrer exigerait de créer classes+élèves.

**Résultat lisible en démo** — filières : Hôtellerie 100 %, Compta 83 %, Froid 83 %, Électro 78 %, Secrétariat 65 %, **BTP 46 %** ; départements : Bouenza 100 %, Plateaux/Pool 83 %, Kouilou 78 %, Brazzaville 71 %, Niari 60 %, **Pointe-Noire 46 %**. Taux volontairement DIFFÉRENCIÉS : c'est le signal « où renforcer l'offre » qui fait réagir un ministère.

⚠️ Aléa **déterministe** (`hashtext`) → une démo doit être reproductible. `classes.filiere_label` ET `filiere_code` existent (PAS `filiere_id` — piège). Voir [[demo-metp-donnees-kinkala]], [[examens-nationaux-socle]].
