-- 0019_timetable_slots_rls.sql
-- DURCISSEMENT : comble une faille héritée. `timetable_slots` et
-- `lesson_entries` n'avaient AUCUNE RLS (lecture/écriture par tout utilisateur
-- authentifié via l'API). Seule la minimisation des sync-rules les protégeait —
-- insuffisant contre un accès API direct hors périmètre. On applique la même
-- garde multi-tenant que rooms / class_subjects.
--
-- À appliquer après vérification : aucune écriture légitime ne doit échouer
-- (le connecteur PowerSync écrit en tant qu'utilisateur de l'école → couvert
-- par la clause school_id = auth_school_id()).

-- NB : sur l'instance de prod, RLS était DÉJÀ activée et ces policies DÉJÀ
-- présentes (le schema.sql in-repo était périmé). Migration rendue idempotente
-- (DROP IF EXISTS + CREATE) pour rester sûre quel que soit l'état de départ.

ALTER TABLE public.timetable_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS timetable_slots_tenant ON public.timetable_slots;
CREATE POLICY timetable_slots_tenant ON public.timetable_slots
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

ALTER TABLE public.lesson_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_entries_tenant ON public.lesson_entries;
CREATE POLICY lesson_entries_tenant ON public.lesson_entries
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );
