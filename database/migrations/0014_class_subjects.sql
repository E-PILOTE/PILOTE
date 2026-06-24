-- 0014_class_subjects.sql
-- Programme par classe : une matière dispensée dans une classe donnée, avec son
-- coefficient EFFECTIF (override) et son volume horaire. Résout la réalité Congo
-- « Maths coef 4 en Tle C vs coef 2 en Tle A » : chaque série étant une classe
-- distincte, l'override vit sur la paire (classe, matière), indépendamment du
-- professeur (qui reste sur teacher_subjects).
--
-- Modèle à deux étages :
--   subjects.coefficient            = coef PAR DÉFAUT au niveau (baseline catalogue)
--   class_subjects.coefficient NULL = hérite du coef niveau ; sinon = override classe.

CREATE TABLE IF NOT EXISTS public.class_subjects (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  class_id     uuid NOT NULL REFERENCES public.classes(id)       ON DELETE CASCADE,
  subject_id   uuid NOT NULL REFERENCES public.subjects(id)      ON DELETE CASCADE,
  coefficient  smallint,                       -- NULL = hérite du coef niveau
  weekly_hours smallint,                        -- volume horaire hebdo (optionnel)
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_id, subject_id)
);

ALTER TABLE public.class_subjects ENABLE ROW LEVEL SECURITY;

-- Même garde multi-tenant que teacher_subjects (école pour le personnel,
-- groupe entier pour admin_groupe, tout pour super_admin).
CREATE POLICY class_subjects_tenant ON public.class_subjects
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

-- Index FK (politique « 0 FK sans index » de db-scale-hardening).
CREATE INDEX IF NOT EXISTS idx_class_subjects_class   ON public.class_subjects(class_id);
CREATE INDEX IF NOT EXISTS idx_class_subjects_subject ON public.class_subjects(subject_id);
CREATE INDEX IF NOT EXISTS idx_class_subjects_school  ON public.class_subjects(school_id);
CREATE INDEX IF NOT EXISTS idx_class_subjects_group   ON public.class_subjects(group_id);
