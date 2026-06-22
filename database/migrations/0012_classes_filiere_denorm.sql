-- 0012_classes_filiere_denorm.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- Dénormalise la FILIÈRE sur la classe (dérivée de classe→niveau→filière, via
-- school_levels.program_id → education_programs). But : les KPI « par filière »
-- de la page Inscriptions (lycée/formation pro.) deviennent RÉELS et disponibles
-- OFFLINE (table `classes` déjà synchronisée par PowerSync, SELECT *) sans avoir
-- à synchroniser education_programs. Aujourd'hui aucune école n'a encore adopté
-- de filière → colonnes NULL partout → la section « par filière » reste vide et
-- s'allumera dès qu'une filière sera créée par la direction (structure
-- académique). Aucune heuristique : si NULL, pas de filière.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.classes
  ADD COLUMN IF NOT EXISTS filiere_code  text,
  ADD COLUMN IF NOT EXISTS filiere_label text;

UPDATE public.classes c
SET filiere_code  = ep.code,
    filiere_label = ep.name,
    updated_at    = now()
FROM public.school_levels sl
JOIN public.education_programs ep ON ep.id = sl.program_id
WHERE c.level_id = sl.id
  AND c.filiere_code IS DISTINCT FROM ep.code;
