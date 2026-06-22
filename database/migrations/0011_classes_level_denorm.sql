-- 0011_classes_level_denorm.sql
-- Dénormalise le NIVEAU (code + ordre pédagogique) sur la classe, depuis le vrai
-- school_levels (classe→niveau). Permet des KPI « par niveau » (6e, 5e, 4e, 3e…)
-- RÉELS et OFFLINE sur la page Inscriptions, sans synchroniser school_levels.
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS level_code  text;
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS level_order integer;

UPDATE public.classes c
SET level_code = sl.code, level_order = sl.order_index, updated_at = now()
FROM public.school_levels sl
WHERE c.level_id = sl.id
  AND (c.level_code IS DISTINCT FROM sl.code OR c.level_order IS DISTINCT FROM sl.order_index);
