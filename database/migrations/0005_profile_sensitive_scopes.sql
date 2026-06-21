-- 0005_profile_sensitive_scopes.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- BUT : rendre la synchro PowerSync des données SENSIBLES (finance/RH, discipline,
--       médical) pilotée par le PROFIL D'ACCÈS et non plus par le RÔLE.
--
-- Avant : les buckets sync-rules `sensitive_<role>` filtraient `WHERE role = 'X'`.
--         → un enseignant à qui l'admin donne un profil « Comptable » voyait le
--           module Finance (verrou 3 = profile_permissions) mais sans AUCUNE
--           donnée sur l'appareil (sync gatée par rôle). Module vide hors-ligne.
--
-- Après : 3 booléens dénormalisés sur `profiles` (sync_finance / sync_discipline /
--         sync_medical), recalculés par trigger depuis `profile_permissions` du
--         profil d'accès du membre. Les sync-rules filtreront sur ces drapeaux.
--         → N'importe quel rôle peut recevoir n'importe quel profil et obtenir
--           RÉELLEMENT la donnée correspondante hors-ligne.
--
-- Mapping capacité → modules (catalogue v2, slugs réels) :
--   sync_finance    : depenses | budget | personnel | presences-personnel | conges | paie
--                     (tables : payroll, expenses, budget_lines, staff_members)
--   sync_discipline : discipline           (table : discipline_incidents)
--   sync_medical    : infirmerie           (table : infirmary_visits)
--   NB : frais-scolarite & paiements-eleves NE sont PAS sensibles (déjà synchro
--        à tout le personnel via le bucket by_school).
--
-- ⚠️ Conséquence : après migration, la donnée sensible suit le PROFIL, pas le
--    rôle. Un membre sans profil d'accès n'a aucune donnée sensible — ce qui est
--    cohérent : sans profil, la sidebar est déjà vide (verrou 3). Aucune
--    fonctionnalité réellement utilisable n'est perdue.
--
-- Additif & réversible (voir bloc ROLLBACK en bas).
-- ⚠️ Après application : RÉÉCRIRE puis REDÉPLOYER les sync-rules PowerSync
--    (dashboard / PAT). Tant que les sync-rules ne sont pas redéployées, rien ne
--    change côté synchro (les colonnes existent mais ne sont pas encore lues).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) Colonnes capacité ───────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS sync_finance    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sync_discipline boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sync_medical    boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.sync_finance IS
  'Dérivé du profil d''accès (trigger). true si le profil donne can_read sur un module finance/RH sensible (depenses/budget/personnel/presences-personnel/conges/paie). Pilote la sync PowerSync de payroll/expenses/budget_lines/staff_members.';
COMMENT ON COLUMN public.profiles.sync_discipline IS
  'Dérivé du profil d''accès (trigger). true si can_read sur le module discipline. Pilote la sync de discipline_incidents.';
COMMENT ON COLUMN public.profiles.sync_medical IS
  'Dérivé du profil d''accès (trigger). true si can_read sur le module infirmerie. Pilote la sync de infirmary_visits.';

-- 2) Recalcul pour un profil d'accès donné → met à jour TOUS ses membres ──────
CREATE OR REPLACE FUNCTION public.recompute_sensitive_flags_for_profile(p_apid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_finance    boolean;
  v_discipline boolean;
  v_medical    boolean;
BEGIN
  IF p_apid IS NULL THEN
    RETURN;
  END IF;

  SELECT
    COALESCE(bool_or(m.slug IN
      ('depenses','budget','personnel','presences-personnel','conges','paie')), false),
    COALESCE(bool_or(m.slug = 'discipline'),  false),
    COALESCE(bool_or(m.slug = 'infirmerie'),  false)
  INTO v_finance, v_discipline, v_medical
  FROM profile_permissions pp
  JOIN modules m ON m.id = pp.module_id
  WHERE pp.profile_id = p_apid
    AND pp.can_read = true;

  UPDATE profiles
  SET sync_finance    = COALESCE(v_finance,    false),
      sync_discipline = COALESCE(v_discipline, false),
      sync_medical    = COALESCE(v_medical,    false)
  WHERE access_profile_id = p_apid;
END;
$$;

-- 3) Trigger sur profiles : (ré)affecter un profil recalcule la ligne ─────────
--    BEFORE → on pose les drapeaux directement sur NEW (pas de second UPDATE).
CREATE OR REPLACE FUNCTION public.trg_profiles_sensitive_flags()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_finance    boolean := false;
  v_discipline boolean := false;
  v_medical    boolean := false;
BEGIN
  IF NEW.access_profile_id IS NOT NULL THEN
    SELECT
      COALESCE(bool_or(m.slug IN
        ('depenses','budget','personnel','presences-personnel','conges','paie')), false),
      COALESCE(bool_or(m.slug = 'discipline'),  false),
      COALESCE(bool_or(m.slug = 'infirmerie'),  false)
    INTO v_finance, v_discipline, v_medical
    FROM profile_permissions pp
    JOIN modules m ON m.id = pp.module_id
    WHERE pp.profile_id = NEW.access_profile_id
      AND pp.can_read = true;
  END IF;

  NEW.sync_finance    := COALESCE(v_finance,    false);
  NEW.sync_discipline := COALESCE(v_discipline, false);
  NEW.sync_medical    := COALESCE(v_medical,    false);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sensitive_flags ON public.profiles;
CREATE TRIGGER profiles_sensitive_flags
  BEFORE INSERT OR UPDATE OF access_profile_id ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.trg_profiles_sensitive_flags();

-- 4) Trigger sur profile_permissions : un droit change → recalcul des membres ─
CREATE OR REPLACE FUNCTION public.trg_perms_sensitive_flags()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.recompute_sensitive_flags_for_profile(
            COALESCE(NEW.profile_id, OLD.profile_id));
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS perms_sensitive_flags ON public.profile_permissions;
CREATE TRIGGER perms_sensitive_flags
  AFTER INSERT OR UPDATE OR DELETE ON public.profile_permissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_perms_sensitive_flags();

-- 5) Backfill initial : recalculer pour tous les profils d'accès existants ────
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM access_profiles LOOP
    PERFORM public.recompute_sensitive_flags_for_profile(r.id);
  END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLLBACK (si besoin) :
--   DROP TRIGGER IF EXISTS perms_sensitive_flags ON public.profile_permissions;
--   DROP TRIGGER IF EXISTS profiles_sensitive_flags ON public.profiles;
--   DROP FUNCTION IF EXISTS public.trg_perms_sensitive_flags();
--   DROP FUNCTION IF EXISTS public.trg_profiles_sensitive_flags();
--   DROP FUNCTION IF EXISTS public.recompute_sensitive_flags_for_profile(uuid);
--   ALTER TABLE public.profiles
--     DROP COLUMN IF EXISTS sync_finance,
--     DROP COLUMN IF EXISTS sync_discipline,
--     DROP COLUMN IF EXISTS sync_medical;
-- ─────────────────────────────────────────────────────────────────────────────
