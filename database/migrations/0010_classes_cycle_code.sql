-- 0010_classes_cycle_code.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- Dénormalise le CODE DE CYCLE sur la classe (dérivé de classe→niveau→cycle).
-- But : les KPI « par cycle » de la page Inscriptions deviennent RÉELS et
-- disponibles OFFLINE (table `classes` déjà synchronisée par PowerSync, SELECT *)
-- sans avoir à synchroniser le référentiel education_cycles. Les 5 codes de cycle
-- sont un standard national stable (prescolaire/primaire/college/lycee/
-- formation_pro) → libellés mappés côté Dart.
-- Le code est posé/maj quand une classe reçoit un niveau (structure académique).
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.classes
  ADD COLUMN IF NOT EXISTS cycle_code text;

UPDATE public.classes c
SET cycle_code = ec.code, updated_at = now()
FROM public.school_levels sl
JOIN public.education_cycles ec ON ec.id = sl.cycle_id
WHERE c.level_id = sl.id AND c.cycle_code IS DISTINCT FROM ec.code;
