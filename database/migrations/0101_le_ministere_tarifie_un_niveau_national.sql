-- ════════════════════════════════════════════════════════════════════════════
--  0101 — LE MINISTÈRE TARIFE UN NIVEAU, L'ÉCOLE L'APPLIQUE
--
--  ── LE TROU ────────────────────────────────────────────────────────────────
--  Depuis la 0096, le groupe définit et l'école applique. Mais « l'inscription
--  en 6e coûte X dans tout le réseau » restait INEXPRIMABLE :
--  `applies_to_level_id` pointe sur `school_levels`, dont chaque ligne
--  appartient à UNE école (180 lignes pour 16 noms de niveau). Un tarif réseau
--  visant « la 6e de l'école A » ne toucherait jamais les élèves de l'école B.
--  Pour tarifer la 6e du pays, il aurait fallu autant de lignes que d'écoles —
--  et à 1 000 écoles, personne ne le fait à la main.
--
--  ── CE QUI EXISTAIT DÉJÀ, ET QU'ON BRANCHE ─────────────────────────────────
--  `education_levels` EST le référentiel national : ses lignes standard portent
--  `group_id IS NULL` (« Sixième (6e) », « Seconde », « Terminale », « CP1 »…).
--  Et `school_levels.education_level_id` est renseigné à 100 % dans tous les
--  groupes réels — METP 42/42, MEPSA 70/70, EDEC 20/20. La correspondance
--  « ce niveau d'école EST la 6e nationale » est donc déjà là.
--
--  Il ne manquait qu'une colonne pour que le barème sache la nommer.
--
--  ── LA RÈGLE, EN DEUX CONTRAINTES ──────────────────────────────────────────
--   1. Un tarif vise UN niveau, pas deux référentiels à la fois.
--   2. Un tarif de portée RÉSEAU ne peut JAMAIS viser le niveau d'une école.
--      Cette règle n'était qu'un commentaire Dart et une discipline de saisie ;
--      elle devient une contrainte, donc vraie pour tous les écrivains.
--
--  ── CE QUE ÇA CHANGE POUR L'ÉCOLE ──────────────────────────────────────────
--  Rien à saisir. Elle reçoit le tarif et l'applique : son propre niveau porte
--  déjà `education_level_id`, la correspondance se fait toute seule. C'est la
--  même grammaire que le reste — le groupe décide, l'école constate.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── 1. Le niveau du RÉFÉRENTIEL NATIONAL entre dans le barème ──────────────
ALTER TABLE fee_structures
  ADD COLUMN IF NOT EXISTS applies_to_education_level_id uuid
  REFERENCES education_levels(id);

COMMENT ON COLUMN fee_structures.applies_to_education_level_id IS
  'Niveau du référentiel partagé (education_levels) visé par ce barème. '
  'C''est le SEUL ciblage par niveau possible sur un tarif de portée réseau : '
  'applies_to_level_id désigne le niveau d''UNE école et ne vaut que pour elle.';

-- ─── 2. Un tarif vise UN niveau ─────────────────────────────────────────────
ALTER TABLE fee_structures
  ADD CONSTRAINT fee_structures_un_seul_referentiel_de_niveau
  CHECK (applies_to_level_id IS NULL OR applies_to_education_level_id IS NULL);

-- ─── 3. Un tarif RÉSEAU ne vise jamais le niveau d'une école ────────────────
-- Vérifié avant pose : 0 ligne concernée sur les 7 existantes.
ALTER TABLE fee_structures
  ADD CONSTRAINT fee_structures_reseau_vise_le_referentiel
  CHECK (school_id IS NOT NULL OR applies_to_level_id IS NULL);

CREATE INDEX IF NOT EXISTS idx_fee_structures_education_level_id
  ON fee_structures (applies_to_education_level_id);

-- ─── 4. L'unicité compte le nouveau niveau ──────────────────────────────────
-- Sans cela, « Inscription 6e » et « Inscription 5e » au réseau seraient vues
-- comme un doublon : même group/année/type/portée, niveaux différents.
DROP INDEX IF EXISTS uniq_fee_structure_portee_active;
CREATE UNIQUE INDEX uniq_fee_structure_portee_active
  ON fee_structures (
    group_id, academic_year_id, fee_type, school_id,
    applies_to_level_id, applies_to_education_level_id, exam_session_id
  )
  NULLS NOT DISTINCT
  WHERE is_active;
