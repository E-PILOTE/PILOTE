-- 0021_timetable_exceptions.sql
-- EXCEPTIONS À LA TRAME — un emploi du temps scolaire est une trame hebdomadaire
-- récurrente, mais la réalité comporte des écarts PONCTUELS à une DATE précise :
--   • 'cancelled' : séance annulée ce jour (prof absent, jour spécial…) ;
--   • 'moved'     : séance déplacée (nouvel horaire/salle/prof le même jour) ;
--   • 'extra'     : séance EXCEPTIONNELLE ajoutée (rattrapage, devoir surveillé)
--                   non issue de la trame → slot_id NULL, classe/matière portées
--                   par les colonnes new_*.
-- C'est la couche qui rend EXACTES les vues calendaires (mois/trimestre/année) :
-- on projette la trame PUIS on applique les exceptions de chaque date.

CREATE TABLE IF NOT EXISTS public.timetable_exceptions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         uuid NOT NULL REFERENCES public.school_groups(id)   ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES public.schools(id)         ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id)  ON DELETE CASCADE,
  slot_id          uuid REFERENCES public.timetable_slots(id) ON DELETE CASCADE, -- NULL si 'extra'
  exception_date   date         NOT NULL,
  kind             varchar(20)  NOT NULL DEFAULT 'cancelled',
  -- Surcharges (moved / extra)
  new_start_time   time,
  new_end_time     time,
  new_room_id      uuid REFERENCES public.rooms(id)    ON DELETE SET NULL,
  new_staff_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  new_subject_id   uuid REFERENCES public.subjects(id) ON DELETE SET NULL, -- 'extra'
  new_class_id     uuid REFERENCES public.classes(id)  ON DELETE SET NULL, -- 'extra'
  reason           text,
  created_by       uuid,
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT tt_exc_kind CHECK (kind IN ('cancelled','moved','extra'))
);

ALTER TABLE public.timetable_exceptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY tt_exceptions_tenant ON public.timetable_exceptions
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_tt_exc_school ON public.timetable_exceptions(school_id);
CREATE INDEX IF NOT EXISTS idx_tt_exc_slot   ON public.timetable_exceptions(slot_id);
CREATE INDEX IF NOT EXISTS idx_tt_exc_date   ON public.timetable_exceptions(exception_date);
CREATE INDEX IF NOT EXISTS idx_tt_exc_year   ON public.timetable_exceptions(academic_year_id);
