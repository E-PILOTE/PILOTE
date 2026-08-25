-- ════════════════════════════════════════════════════════════════════════════
--  0103 — UN TARIF D'EXAMEN VISE L'EXAMEN, PAS L'INSTANCE DE L'ANNÉE
--
--  Constat (13/08/2026) : sur 35 sessions, 6 années et 7 groupes, il y avait
--  ZÉRO `fee_structures.exam_session_id` renseigné. Le rattachement n'a jamais
--  servi une seule fois — et le filet (`exam_sessions.fee_amount`) n'était posé
--  que sur 2 sessions sur 35, toutes deux MEPSA. Côté METP, la caisse d'examen
--  était fermée partout.
--
--  La cause est dans le modèle. `exam_sessions` est un référentiel NATIONAL
--  (aucun `group_id`) qui empile une instance par examen ET par année. Deux
--  conséquences :
--
--   1. viser une session oblige à re-pointer le tarif CHAQUE ANNÉE ;
--   2. surtout, un ministère fixe ses frais PAR ARRÊTÉ **puis** ouvre les
--      inscriptions. Exiger la session inverse l'ordre réel du travail : on ne
--      peut pas tarifer un examen dont la session n'existe pas encore.
--
--  D'où `applies_to_exam_id` → `national_exams`. L'examen est stable, la
--  session en est l'instance. Le tarif porte déjà son `academic_year_id` ; le
--  poste résout la session en rapprochant `academic_years.label` de
--  `exam_sessions.year_label` — correspondance vérifiée EXACTE sur les 7
--  groupes et les 2 années ouvertes.
--
--  `exam_session_id` survit pour l'exception : une session de rattrapage au
--  tarif différent. Les deux ciblages s'excluent.
--
--  Recette (bloc DO auto-annulé, 13/08) : les deux ciblages à la fois → 23514 ;
--  un type autre que `frais_examens` visant un examen → 23514 ; doublon sur le
--  même examen → 23505 ; deux examens différents la même année → acceptés.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.fee_structures
  ADD COLUMN IF NOT EXISTS applies_to_exam_id uuid REFERENCES public.national_exams(id);

COMMENT ON COLUMN public.fee_structures.applies_to_exam_id IS
  'Examen national visé. Le poste résout la session de l''année du tarif '
  '(academic_years.label = exam_sessions.year_label). Exclusif avec '
  'exam_session_id, qui ne sert qu''à viser UNE session précise.';

-- Un tarif ne vise pas à la fois l'examen et une de ses sessions.
ALTER TABLE public.fee_structures
  DROP CONSTRAINT IF EXISTS fee_structures_un_seul_ciblage_examen;
ALTER TABLE public.fee_structures
  ADD CONSTRAINT fee_structures_un_seul_ciblage_examen
  CHECK (exam_session_id IS NULL OR applies_to_exam_id IS NULL);

-- Viser un examen n'a de sens que pour un frais d'examen. Sans cette règle,
-- une « mensualité » pouvait pointer sur le BAC — et le module Examens
-- l'aurait réclamée à chaque candidat.
ALTER TABLE public.fee_structures
  DROP CONSTRAINT IF EXISTS fee_structures_examen_reserve_au_type;
ALTER TABLE public.fee_structures
  ADD CONSTRAINT fee_structures_examen_reserve_au_type
  CHECK (
    (exam_session_id IS NULL AND applies_to_exam_id IS NULL)
    OR fee_type = 'frais_examens'
  );

CREATE INDEX IF NOT EXISTS idx_fee_structures_applies_to_exam_id
  ON public.fee_structures (applies_to_exam_id);

-- ⚠️ La clé d'unicité doit connaître le nouveau ciblage, sinon deux tarifs
-- pour le MÊME examen et la même année passeraient — et le dû d'un candidat
-- redeviendrait non déterministe, ce que la migration 0099 avait fermé.
DROP INDEX IF EXISTS public.uniq_fee_structure_portee_active;
CREATE UNIQUE INDEX uniq_fee_structure_portee_active
  ON public.fee_structures (
    group_id, academic_year_id, fee_type, school_id,
    applies_to_level_id, applies_to_education_level_id,
    exam_session_id, applies_to_exam_id
  )
  NULLS NOT DISTINCT
  WHERE is_active;
