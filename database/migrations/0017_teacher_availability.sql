-- 0017_teacher_availability.sql
-- Disponibilités / indisponibilités / préférences des ENSEIGNANTS — comble le
-- manque n°1 fonctionnel (aujourd'hui on peut placer un prof un jour où il n'est
-- pas là, ou affecter n'importe quel membre du personnel).
--
-- Convention (défaut permissif) :
--   ABSENCE de ligne          → enseignant réputé DISPONIBLE.
--   status = 'unavailable'    → ne PEUT PAS être placé sur cette plage (DUR).
--   status = 'preference_against' → à éviter (SOUPLE).
--   status = 'preference_for'     → privilégié (SOUPLE).
-- Une plage = (jour, [start_time, end_time]). start/end NULL = journée entière.
-- `academic_year_id` NULL = vaut pour toute année (récurrent).

CREATE TABLE IF NOT EXISTS public.teacher_availability (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  staff_id         uuid NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  academic_year_id uuid REFERENCES public.academic_years(id)        ON DELETE CASCADE,
  day_of_week      smallint    NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time       time,
  end_time         time,
  status           varchar(20) NOT NULL DEFAULT 'unavailable',
  note             varchar(200),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.teacher_availability ENABLE ROW LEVEL SECURITY;

CREATE POLICY teacher_availability_tenant ON public.teacher_availability
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_teacher_avail_staff  ON public.teacher_availability(staff_id);
CREATE INDEX IF NOT EXISTS idx_teacher_avail_school ON public.teacher_availability(school_id);
CREATE INDEX IF NOT EXISTS idx_teacher_avail_group  ON public.teacher_availability(group_id);
