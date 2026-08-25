-- 0042 — Tutelle ministérielle (MEPSA/METP) + filières au collège
--
-- VERROU N°1 de l'analyse fonctionnelle du 2026-07-17
-- (docs/superpowers/specs/2026-07-17-analyse-fonctionnelle-modules-examens.md).
--
-- Constat : la plateforme est une commande MEPSA + METP, mais RIEN ne dit de
-- quel ministère relève un établissement. La seule colonne de typage est :
--
--     school_type_enum = public | prive | mixte
--
-- …qui est le RÉGIME DE PROPRIÉTÉ, pas la TUTELLE. Conséquence directe et
-- invisible depuis l'interface : « 3e générale -> BEPC » et « 3e technique ->
-- BET » sont INDÉCIDABLES. Aucun module Examens ne peut être posé tant que le
-- système ne sait pas répondre à « cette école est-elle générale ou technique ? ».
--
-- Second constat : le cycle « college » a has_programs = false et ZÉRO filière
-- (les filières n'existent qu'au lycée — séries A/C/D/E/F/G — et en formation
-- professionnelle). Une « 3e Enseignement Technique » est donc littéralement
-- inexprimable dans le modèle.
--
-- Cette migration lève les deux verrous. Elle est ADDITIVE : aucune colonne
-- supprimée, aucune valeur existante réécrite hors backfill documenté ci-dessous.
--
-- Deux discriminants complémentaires sont posés, volontairement :
--   • tutelle sur l'ÉCOLE  -> statistiques par ministère + cas des collèges
--     dont les classes ne portent pas encore de filière (le parc actuel) ;
--   • filière sur la CLASSE -> cas des établissements MIXTES, où la tutelle de
--     l'école ne suffit pas à trancher classe par classe.
-- La règle d'éligibilité (migration suivante) sait exploiter les deux, du plus
-- spécifique au plus général.

BEGIN;

-- ── 1) Tutelle ministérielle ────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tutelle_enum') THEN
    CREATE TYPE tutelle_enum AS ENUM ('mepsa', 'metp');
  END IF;
END $$;

ALTER TABLE schools ADD COLUMN IF NOT EXISTS tutelle tutelle_enum;

COMMENT ON COLUMN schools.tutelle IS
  'Ministère de tutelle : mepsa (enseignement général) | metp (technique et '
  'professionnel). À NE PAS confondre avec school_type (public/prive/mixte), '
  'qui est le régime de propriété. Détermine notamment BEPC vs BET.';

-- Backfill FONDÉ SUR LA DONNÉE, pas sur une supposition : les deux ministères
-- sont eux-mêmes des tenants (school_groups), leur nom est explicite.
UPDATE schools s
   SET tutelle = 'metp'
  FROM school_groups g
 WHERE g.id = s.group_id
   AND s.tutelle IS NULL
   AND g.name ILIKE '%technique%';

UPDATE schools s
   SET tutelle = 'mepsa'
  FROM school_groups g
 WHERE g.id = s.group_id
   AND s.tutelle IS NULL
   AND (g.name ILIKE '%MEPSA%' OR g.name ILIKE '%primaire%');

-- Les groupes privés (collèges/complexes d'enseignement général) relèvent de la
-- tutelle MEPSA : un établissement privé général reste sous tutelle MEPSA, le
-- privé étant un régime de propriété, non une tutelle. Reste corrigeable par
-- l'admin ; la colonne est nullable et aucune règle ne casse si elle est NULL.
UPDATE schools SET tutelle = 'mepsa' WHERE tutelle IS NULL;

-- ── 2) Filières au collège ─────────────────────────────────────────────────
-- Rend « 3e technique » exprimable. has_programs ne fait qu'AFFICHER la section
-- filières (vérifié : academic_structure_parts.dart, school_education_section.dart)
-- -> bascule non destructrice, aucune saisie rendue obligatoire.
UPDATE education_cycles SET has_programs = true, updated_at = now()
 WHERE code = 'college' AND has_programs = false;

-- Référentiel NATIONAL (group_id NULL) : le motif déjà en place pour les cycles,
-- niveaux et séries du lycée. Idempotent.
INSERT INTO education_programs (cycle_id, code, name, description, order_index, group_id, is_active)
SELECT c.id, v.code, v.name, v.description, v.order_index, NULL, true
  FROM education_cycles c
  CROSS JOIN (VALUES
    ('college_general',   'Enseignement Général',                'Collège d''enseignement général (tutelle MEPSA) — prépare le BEPC.',            1),
    ('college_technique', 'Enseignement Technique',              'Collège d''enseignement technique (tutelle METP) — prépare le BET.',            2)
  ) AS v(code, name, description, order_index)
 WHERE c.code = 'college'
   AND NOT EXISTS (
     SELECT 1 FROM education_programs p
      WHERE p.cycle_id = c.id AND p.code = v.code AND p.group_id IS NULL
   );

COMMIT;

-- ── Vérifications (à exécuter après application) ────────────────────────────
-- select tutelle, count(*) from schools group by 1;
-- select code, has_programs from education_cycles where code='college';
-- select p.code, p.name from education_programs p
--   join education_cycles c on c.id=p.cycle_id where c.code='college';
