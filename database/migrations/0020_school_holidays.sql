-- 0020_school_holidays.sql
-- CALENDRIER SCOLAIRE — jours NON OUVRÉS de l'année (vacances scolaires et jours
-- fériés). Socle indispensable des vues calendaires (mois/trimestre/semestre/
-- annuel) de l'emploi du temps : sans lui, projeter la trame hebdomadaire sur le
-- calendrier réel afficherait des cours les jours fériés / pendant les vacances.
-- Une ligne = une PLAGE non ouvrée [start_date, end_date] (1 jour = mêmes dates).
--   kind = 'ferie'    : jour férié (souvent national, 1 journée) ;
--          'vacances' : congés scolaires (plage de plusieurs jours).
-- Périmètre : école (la direction gère son calendrier), rattachée à l'année.

CREATE TABLE IF NOT EXISTS public.school_holidays (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         uuid NOT NULL REFERENCES public.school_groups(id)   ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES public.schools(id)         ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id)  ON DELETE CASCADE,
  label            varchar(80)  NOT NULL,                  -- ex. "Fête de l'Indépendance", "Vacances de Noël"
  kind             varchar(20)  NOT NULL DEFAULT 'ferie',  -- ferie | vacances
  start_date       date         NOT NULL,
  end_date         date         NOT NULL,
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT school_holidays_date_order CHECK (end_date >= start_date)
);

ALTER TABLE public.school_holidays ENABLE ROW LEVEL SECURITY;

CREATE POLICY school_holidays_tenant ON public.school_holidays
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_school_holidays_school ON public.school_holidays(school_id);
CREATE INDEX IF NOT EXISTS idx_school_holidays_group  ON public.school_holidays(group_id);
CREATE INDEX IF NOT EXISTS idx_school_holidays_year   ON public.school_holidays(academic_year_id);
