-- 0009_school_levels_cycle.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- STRUCTURE ACADÉMIQUE (fondation) : un NIVEAU d'école (`school_levels`, cible de
-- `classes.level_id`) appartient désormais à un CYCLE (et éventuellement à une
-- FILIÈRE pour le lycée/FP). Permet le vrai chemin classe → niveau → cycle
-- (fini l'heuristique par nom de classe sur la page Inscriptions).
-- Non destructif : colonnes nullable + index FK.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.school_levels
  ADD COLUMN IF NOT EXISTS cycle_id uuid REFERENCES public.education_cycles(id);
ALTER TABLE public.school_levels
  ADD COLUMN IF NOT EXISTS program_id uuid REFERENCES public.education_programs(id);

CREATE INDEX IF NOT EXISTS idx_school_levels_cycle   ON public.school_levels(cycle_id);
CREATE INDEX IF NOT EXISTS idx_school_levels_program ON public.school_levels(program_id);
CREATE INDEX IF NOT EXISTS idx_school_levels_school  ON public.school_levels(school_id);
