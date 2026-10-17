-- ============================================================================
-- 0208 — DONNÉES : remise à zéro de tous les groupes scolaires
-- ----------------------------------------------------------------------------
-- Décision du fondateur, 2026-10-17 : le projet ministériel est annulé, la
-- plateforme ne sert plus que les groupes privés. Aucun compte d'un groupe
-- privé ne s'était jamais connecté (données de démonstration) ; les groupes
-- publics n'ont plus d'objet. On repart de zéro pour supprimer toute
-- confusion public / privé.
--
-- ⚠️ IRRÉVERSIBLE ICI. Tout a été copié AVANT dans le schéma
--    `sauvegarde_20261017` (109 tables de `public` + auth.users,
--    auth.identities, storage.objects), nombre de lignes vérifié table par
--    table. Ce schéma n'est pas exposé à l'API ; il doit être exporté hors de
--    la base puis supprimé.
--
-- CE QUI RESTE : la STRUCTURE (tables, RLS, fonctions — elle n'existe que
-- dans la base), les RÉFÉRENTIELS (modules, catégories, plans, plan_modules,
-- examens nationaux, sessions, règles d'éligibilité, cycles/programmes/
-- niveaux nationaux, types d'établissement, départements, inspections,
-- versions de l'app, réglages et coûts de la plateforme) et le compte
-- super_admin.
--
-- Les déclencheurs sont suspendus le temps de la purge (`replica`) : ils
-- garderaient un ministère contre la suppression, journaliseraient chaque
-- ligne effacée et notifieraient des quotas. Les suppressions d'auth.users se
-- font APRÈS, déclencheurs rétablis, pour que leurs cascades (identités,
-- sessions) jouent. Répété d'abord en transaction annulée : 0 référence
-- orpheline.
--
-- Les 72 fichiers stockés (avatars, logos, pièces jointes) ne s'effacent pas
-- par SQL : à vider depuis le tableau de bord Supabase (Storage).
-- ============================================================================
DO $$
DECLARE
  keep text[] := ARRAY['app_releases','departments','education_pathways',
    'exam_sessions','inspections','institution_types','module_categories',
    'modules','national_exams','plan_modules','platform_costs',
    'platform_partners','platform_service_messages','platform_settings',
    'subscription_plans','education_cycles','education_levels',
    'education_programs','exam_eligibility_rules','app_installations',
    'profiles','access_profiles','schools','school_groups'];
  liste text;
  sa uuid;
BEGIN
  IF (SELECT count(*) FROM pg_namespace WHERE nspname = 'sauvegarde_20261017') = 0 THEN
    RAISE EXCEPTION 'Sauvegarde absente : remise à zéro refusée';
  END IF;

  SELECT id INTO sa FROM public.profiles WHERE role = 'super_admin';
  IF sa IS NULL THEN
    RAISE EXCEPTION 'Aucun super_admin : remise à zéro refusée';
  END IF;

  SELECT string_agg(format('public.%I', c.relname), ', ') INTO liste
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
   WHERE ns.nspname = 'public' AND c.relkind = 'r' AND c.relname <> ALL (keep);

  SET LOCAL session_replication_role = replica;
  DELETE FROM public.education_levels WHERE group_id IS NOT NULL;
  DELETE FROM public.app_installations
   WHERE profile_id IS DISTINCT FROM sa OR group_id IS NOT NULL;
  EXECUTE 'TRUNCATE ' || liste;
  DELETE FROM public.profiles WHERE id <> sa;
  DELETE FROM public.access_profiles;
  DELETE FROM public.schools;
  DELETE FROM public.school_groups;
  SET LOCAL session_replication_role = origin;

  DELETE FROM auth.users WHERE id <> sa;
END $$;
