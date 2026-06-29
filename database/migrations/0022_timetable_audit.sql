-- 0022_timetable_audit.sql
-- JOURNAL D'AUDIT EDT — historique « qui a modifié quoi, quand » sur l'emploi du
-- temps. Plutôt que d'instrumenter chaque mutation Dart, un TRIGGER serveur écrit
-- dans la table `audit_logs` existante à chaque INSERT/UPDATE/DELETE sur les
-- tables EDT. Avantage : capture AUSSI les écritures offline (au moment où
-- PowerSync les remonte, dans le contexte JWT de l'utilisateur → `auth.uid()`
-- = l'acteur réel). Aucune écriture si pas d'acteur (auth.uid() NULL) pour ne
-- jamais bloquer une opération système / seed.

CREATE OR REPLACE FUNCTION public.log_edt_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor uuid := auth.uid();
  rrole public.user_role;
BEGIN
  IF actor IS NULL THEN
    RETURN NULL; -- AFTER trigger : valeur de retour ignorée
  END IF;
  SELECT role INTO rrole FROM public.profiles WHERE id = actor;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs
      (group_id, school_id, user_id, user_role, action, table_name, record_id,
       old_values, new_values)
    VALUES (OLD.group_id, OLD.school_id, actor, rrole, 'DELETE', TG_TABLE_NAME,
            OLD.id, to_jsonb(OLD), NULL);
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs
      (group_id, school_id, user_id, user_role, action, table_name, record_id,
       old_values, new_values)
    VALUES (NEW.group_id, NEW.school_id, actor, rrole, 'INSERT', TG_TABLE_NAME,
            NEW.id, NULL, to_jsonb(NEW));
  ELSE
    INSERT INTO public.audit_logs
      (group_id, school_id, user_id, user_role, action, table_name, record_id,
       old_values, new_values)
    VALUES (NEW.group_id, NEW.school_id, actor, rrole, 'UPDATE', TG_TABLE_NAME,
            NEW.id, to_jsonb(OLD), to_jsonb(NEW));
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_timetable_slots ON public.timetable_slots;
CREATE TRIGGER trg_audit_timetable_slots
  AFTER INSERT OR UPDATE OR DELETE ON public.timetable_slots
  FOR EACH ROW EXECUTE FUNCTION public.log_edt_audit();

DROP TRIGGER IF EXISTS trg_audit_timetable_exceptions ON public.timetable_exceptions;
CREATE TRIGGER trg_audit_timetable_exceptions
  AFTER INSERT OR UPDATE OR DELETE ON public.timetable_exceptions
  FOR EACH ROW EXECUTE FUNCTION public.log_edt_audit();

DROP TRIGGER IF EXISTS trg_audit_timetable_versions ON public.timetable_versions;
CREATE TRIGGER trg_audit_timetable_versions
  AFTER INSERT OR UPDATE OR DELETE ON public.timetable_versions
  FOR EACH ROW EXECUTE FUNCTION public.log_edt_audit();
