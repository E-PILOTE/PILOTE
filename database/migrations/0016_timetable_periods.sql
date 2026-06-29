-- 0016_timetable_periods.sql
-- Trame horaire CONFIGURABLE par école (auparavant codée en dur `kStdPeriods`
-- dans timetable_provider.dart). Une ligne = une bande horaire de la
-- journée-type : séance de cours, récréation ou pause méridienne. Peut être
-- spécialisée par cycle (le primaire n'a pas la même trame que le lycée) via
-- `cycle_code` ; NULL = s'applique à tous les cycles. La trame devient
-- l'ossature FIXE des grilles d'affichage (comparaison inter-classes correcte).

CREATE TABLE IF NOT EXISTS public.school_periods (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  cycle_code   varchar(30),                            -- NULL = tous les cycles
  label        varchar(40)  NOT NULL,                  -- ex. "M1", "Récré", "Pause"
  period_index smallint     NOT NULL,                  -- ordre dans la journée
  kind         varchar(20)  NOT NULL DEFAULT 'cours',  -- cours|recreation|pause_meridienne
  start_time   time         NOT NULL,
  end_time     time         NOT NULL,
  is_active    boolean      NOT NULL DEFAULT true,
  created_at   timestamptz  NOT NULL DEFAULT now(),
  updated_at   timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT school_periods_time_order CHECK (end_time > start_time)
);

ALTER TABLE public.school_periods ENABLE ROW LEVEL SECURITY;

CREATE POLICY school_periods_tenant ON public.school_periods
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_school_periods_school ON public.school_periods(school_id);
CREATE INDEX IF NOT EXISTS idx_school_periods_group  ON public.school_periods(group_id);
