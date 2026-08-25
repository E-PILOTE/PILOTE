-- ════════════════════════════════════════════════════════════════════════════
--  0108 — UNE ÉCOLE PEUT AVOIR PLUSIEURS FRAIS ANNEXES
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  L'enum `fee_type` n'a que cinq valeurs : inscription, mensualite,
--  frais_examens, cotisation_ape, et `autre`. Tout ce qu'une école privée
--  facture en plus de la scolarité — cantine, transport, tenue, fournitures,
--  assurance — tombe donc dans `autre`.
--
--  Or `uniq_fee_structure_portee_active` traite `fee_type` comme une identité :
--  UNE seule ligne active par (groupe, année, type, portée). Une école ne
--  pouvait donc déclarer qu'UN SEUL frais annexe. Cantine OU transport, jamais
--  les deux : la seconde publication était refusée par un doublon de clé.
--
--  Le message d'erreur, lui, disait « modifiez le tarif existant plutôt que
--  d'en publier un second » — conseil juste pour deux tarifs d'inscription
--  concurrents, absurde pour la cantine et le bus, qui sont deux choses.
--
--  L'issue qui restait à l'école était d'écraser un intitulé et de cumuler les
--  montants sur une ligne fourre-tout. La caisse aurait alors encaissé 25 000 F
--  de « frais divers » sans que personne ne puisse dire, six mois plus tard,
--  ce que la famille avait réglé. Un remboursement de cantine serait devenu
--  impossible à justifier.
--
--  ── CE QUE POSE CETTE MIGRATION ────────────────────────────────────────────
--  L'index unique se scinde en deux, selon que le type est à instance unique
--  ou non :
--
--    · inscription / mensualite / cotisation_ape / frais_examens →
--      identité INCHANGÉE. Deux lignes de même portée restent un doublon, et
--      c'est vital : elles feraient réclamer deux sommes différentes au même
--      élève. `frais_examens` était DÉJÀ pluriel sans le dire — douze lignes
--      coexistent en prod, distinguées par `applies_to_exam_id`, qui fait
--      partie de la clé. Rien ne change pour lui.
--
--    · autre → l'identité devient (portée, INTITULÉ). Deux frais annexes ne
--      sont un doublon que s'ils portent le même nom. « Cantine » et
--      « Transport » cohabitent ; deux « Cantine » restent refusées.
--
--  L'intitulé est normalisé (`lower(btrim(...))`) : sans cela, « Cantine » et
--  « cantine » passeraient tous les deux et l'école aurait deux lignes pour la
--  même chose — exactement ce que l'index doit empêcher.
--
--  ── CONTREPARTIE CÔTÉ CLIENT (obligatoire) ─────────────────────────────────
--  `baremesApplicables` (Dart) ne retenait AUSSI qu'une ligne par `fee_type`.
--  Ouvrir la base sans ouvrir le client aurait produit le pire des deux mondes :
--  deux frais annexes enregistrés, un seul réclamé, l'autre invisible et jamais
--  encaissé. Les deux verrous se lèvent ENSEMBLE — cf. `bareme_applicable.dart`,
--  où la clé de résolution devient `autre|<intitulé>` pour ce seul type.
--
--  ── SÛRETÉ ─────────────────────────────────────────────────────────────────
--  Aucune ligne `autre` n'existe en prod au 16/08/2026 : la recréation d'index
--  ne peut échouer sur l'existant. Le nouvel index est STRICTEMENT plus
--  permissif que l'ancien pour `autre` et strictement identique pour tout le
--  reste — aucun barème actif ne devient illégal.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Un frais annexe doit porter un nom ───────────────────────────────────
-- L'intitulé cesse d'être une étiquette pour devenir une IDENTITÉ. Deux lignes
-- au nom vide se percuteraient comme avant ; pire, le reçu remis à la famille
-- ne dirait pas ce qu'elle a payé.
ALTER TABLE public.fee_structures
  ADD CONSTRAINT fee_structures_nom_non_vide
  CHECK (btrim(name) <> '');

-- ── 2. Les types à instance unique ──────────────────────────────────────────
DROP INDEX IF EXISTS public.uniq_fee_structure_portee_active;

CREATE UNIQUE INDEX uniq_fee_structure_portee_active
  ON public.fee_structures (
    group_id, academic_year_id, fee_type, school_id,
    applies_to_level_id, applies_to_education_level_id,
    exam_session_id, applies_to_exam_id
  )
  NULLS NOT DISTINCT
  WHERE is_active AND fee_type <> 'autre';

-- ── 3. La catégorie ouverte ─────────────────────────────────────────────────
-- `exam_session_id` et `applies_to_exam_id` sont absents de la clé : la
-- contrainte `fee_structures_examen_reserve_au_type` les force déjà à NULL
-- hors de `frais_examens`. Les inclure n'ajouterait rien et laisserait croire
-- qu'un frais annexe peut viser un examen.
CREATE UNIQUE INDEX uniq_fee_structure_annexe_active
  ON public.fee_structures (
    group_id, academic_year_id, school_id,
    applies_to_level_id, applies_to_education_level_id,
    lower(btrim(name))
  )
  NULLS NOT DISTINCT
  WHERE is_active AND fee_type = 'autre';

COMMIT;
