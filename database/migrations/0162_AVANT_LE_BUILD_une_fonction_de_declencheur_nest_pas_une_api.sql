-- ═══════════════════════════════════════════════════════════════════════════
--  0162 — UNE FONCTION DE DÉCLENCHEUR N'EST PAS UNE API
--
--  ── CE QUE LES AVIS SUPABASE ONT MONTRÉ (2026-08-31) ─────────────────────
--  97 fonctions `SECURITY DEFINER` sont appelables par le rôle `anon`, donc
--  par n'importe qui, sans compte, via `/rest/v1/rpc/<nom>`. Parmi elles, les
--  51 fonctions de DÉCLENCHEUR : `fn_update_updated_at`, `fn_enforce_*`,
--  `profiles_garde_colonnes_de_pouvoir`… Aucune n'a de raison d'être appelée
--  autrement que par son déclencheur.
--
--  ── LE POINT QU'IL FALLAIT MESURER ───────────────────────────────────────
--  ⚠️ Retirer `EXECUTE` empêche-t-il le déclencheur de tourner ? NON — vérifié
--  en base le 2026-08-31 : privilège retiré, puis UPDATE sous une identité
--  `authenticated` → `updated_at` est bien passé de 2000-01-01 à maintenant.
--  PostgreSQL contrôle `EXECUTE` à la CRÉATION du déclencheur, pas à chaque
--  déclenchement. Sans cette mesure, on n'aurait pas osé la migration.
--
--  ── ⚠️ LE PIÈGE QUI REND LA MOITIÉ DES CORRECTIFS INUTILES ───────────────
--  `REVOKE ... FROM anon, authenticated` ne suffit PAS. PostgreSQL accorde
--  `EXECUTE` à **PUBLIC** par défaut sur toute fonction créée, et les deux
--  rôles en héritent. Mesuré : après un REVOKE sur les deux rôles nommés,
--  `has_function_privilege('authenticated', …)` renvoyait encore `true`.
--  Il faut retirer à PUBLIC. C'est la ligne qui fait le travail.
--
--  ── CE QUE CETTE MIGRATION NE FAIT PAS, ET POURQUOI ──────────────────────
--  Elle ne retire RIEN à `anon` sur les fonctions hors déclencheurs. Une au
--  moins est légitimement appelée sans session valide : `derniere_version()`,
--  interrogée au démarrage de chaque poste — y compris, dit son propre
--  commentaire, « hors ligne, session expirée ». Couper `anon` dessus
--  priverait de mise à jour les postes dont la session a expiré, c'est-à-dire
--  exactement ceux qu'un correctif doit atteindre.
--  Le tri des 46 autres reste à faire, une par une, en vérifiant leur appelant.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

DO $revoke$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_proc p
      JOIN pg_namespace ns ON ns.oid = p.pronamespace
      LEFT JOIN pg_depend d
             ON d.objid = p.oid AND d.deptype = 'e'   -- fonctions d'extension
     WHERE ns.nspname = 'public'
       AND pg_get_function_result(p.oid) = 'trigger'
       AND d.objid IS NULL
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM authenticated', r.sig);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'EXECUTE retire sur % fonctions de declencheur', n;
END;
$revoke$;

-- Garde : aucune fonction appelée par l'application ne doit être un
-- déclencheur. Si l'une l'était, on viendrait de couper une fonctionnalité.
DO $garde$
DECLARE v_faute text;
BEGIN
  SELECT string_agg(p.proname, ', ') INTO v_faute
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND pg_get_function_result(p.oid) = 'trigger'
     AND p.proname = ANY (ARRAY[
       'circulaire_accuser','circulaire_publier','create_admin_user',
       'create_renewal_invoice','create_school_user','delete_admin_user',
       'delete_school_group','derniere_version','get_group_module_access',
       'get_group_users','get_passage_merit','get_platform_admins',
       'get_subscription_settings','group_school_counts','mark_invoice_paid',
       'parc_versions','publish_academic_year','rollover_academic_year',
       'signaler_version','tutelle_ecoles','tutelle_groupes']);
  IF v_faute IS NOT NULL THEN
    RAISE EXCEPTION 'Ces fonctions sont appelees par l''application ET rendent '
      'un trigger : % — la revocation les casserait.', v_faute;
  END IF;
END;
$garde$;

-- ── Les deux aides internes, jamais appelées depuis l'application ─────────
-- `authenticated` en garde le droit : la politique RLS de
-- `circulaire_destinataires` l'appelle, et une politique s'évalue avec les
-- privilèges de celui qui interroge. Le retirer fermerait l'écran.
REVOKE EXECUTE ON FUNCTION public.circulaire_emetteur(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.circulaire_emetteur(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.platform_monthly_cost_xaf() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.platform_monthly_cost_xaf() TO authenticated;

-- ── Une table verrouillée que personne ne peut plus lire ─────────────────
-- `subscription_reminder_log` a la RLS active et AUCUNE politique : le cron
-- l'écrit (SECURITY DEFINER, il passe outre), mais plus personne ne peut la
-- consulter. Un journal illisible n'est pas un journal — et c'est lui qu'on
-- ouvrira le jour où un groupe dira n'avoir jamais été prévenu.
DROP POLICY IF EXISTS reminder_log_super_admin ON public.subscription_reminder_log;
CREATE POLICY reminder_log_super_admin ON public.subscription_reminder_log
  FOR SELECT TO authenticated
  USING (public.is_super_admin());

COMMIT;
