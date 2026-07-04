-- 0025_expire_subscriptions_trial.sql
-- ➊ Fondation abonnement : matérialiser l'expiration de façon AUTORITAIRE côté serveur.
--
-- Bug constaté (2026-07-04) : expire_subscriptions() ne basculait que
-- subscription_status = 'active'. Les groupes en 'trial' dont la date de fin
-- est dépassée restaient 'trial' indéfiniment (ex. METP, fin 2026-06-28).
-- Un essai échu DOIT devenir 'expired' au même titre qu'un abonnement payant échu.
--
-- 'suspended' (impayé, posé manuellement par super_admin) et 'cancelled'
-- (terminal) ne sont volontairement PAS touchés par le cron.
--
-- Idempotent : ne bascule que ce qui est réellement échu ; réexécutable sans effet de bord.

CREATE OR REPLACE FUNCTION public.expire_subscriptions()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_count integer;
BEGIN
  -- Appel REST → réservé super_admin ; appel serveur/cron (sans JWT) → autorisé
  IF auth.uid() IS NOT NULL AND NOT is_super_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  UPDATE school_groups
  SET subscription_status = 'expired'::subscription_status,
      updated_at = now()
  WHERE subscription_status IN ('active'::subscription_status,
                                'trial'::subscription_status)
    AND subscription_end IS NOT NULL
    AND subscription_end < CURRENT_DATE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;
