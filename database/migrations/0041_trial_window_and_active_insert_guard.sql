-- 0041 — Période d'essai : durée définie, datée À LA SOURCE (protection du revenu)
--
-- Constat (audit du workflow abonnement) : le chemin PRINCIPAL de création de
-- groupe (super_admin ▸ Groupes scolaires) posait `subscription_status = 'trial'`
-- SANS `subscription_start` ni `subscription_end`. Or `expire_subscriptions()`
-- ne fait expirer un essai QUE si `subscription_end < aujourd'hui`. Résultat :
-- un essai sans échéance n'expirait JAMAIS → essai gratuit à vie → fuite de
-- revenu. De plus aucune notion de DURÉE d'essai n'existait.
--
-- Règle métier posée ici, à la SOURCE (comme la mig 0040) :
--   • un groupe créé en 'trial' reçoit TOUJOURS une fenêtre datée :
--       subscription_start = aujourd'hui, subscription_end = +N jours ;
--   • N = platform_settings.data->>'trial_days' (défaut 3), réglable depuis le
--     dashboard super_admin (Paramètres ▸ Facturation), sans toucher au code.
--   • une échéance explicitement saisie (formulaire Abonnements) est RESPECTÉE.
--
-- ⚠️ N'entrave PAS la synchro offline du personnel (règle C4) : c'est un
-- garde-fou d'ÉCRITURE sur les dates/le statut, pas un gate de modules.

-- ① Réglage par défaut : poser trial_days = 3 si absent (idempotent).
UPDATE platform_settings
   SET data = jsonb_set(data, '{trial_days}', '"3"', true)
 WHERE id = 1
   AND NULLIF(btrim(COALESCE(data->>'trial_days', '')), '') IS NULL;

-- Lecteur curé de la durée d'essai (défaut 3, plancher 0).
CREATE OR REPLACE FUNCTION public.fn_trial_days()
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(0, COALESCE(
    NULLIF(btrim((SELECT data->>'trial_days' FROM platform_settings WHERE id = 1)),
           '')::int,
    3));
$function$;

-- ② Datage automatique de la fenêtre d'essai (BEFORE INSERT).
CREATE OR REPLACE FUNCTION public.fn_set_trial_window()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_days integer;
BEGIN
  -- Uniquement un essai SANS échéance explicite (on respecte une saisie manuelle).
  IF NEW.subscription_status = 'trial'::subscription_status
     AND NEW.subscription_end IS NULL THEN
    v_days := fn_trial_days();
    NEW.subscription_start := COALESCE(NEW.subscription_start, CURRENT_DATE);
    NEW.subscription_end   := NEW.subscription_start + v_days;  -- date + int → date
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_set_trial_window ON public.school_groups;
CREATE TRIGGER trg_set_trial_window
  BEFORE INSERT ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION fn_set_trial_window();

-- ③ Étendre le garde-fou « actif ⟺ reçu payé / gratuit » à l'INSERT.
--    La mig 0040 ne gardait que la TRANSITION en UPDATE : on pouvait donc
--    INSÉRER directement un groupe 'active' (payant) sans aucun reçu — même
--    trou de revenu, à la porte d'entrée. On généralise à INSERT + UPDATE via
--    TG_OP. Conséquence voulue : pour un plan PAYANT, 'active' est INATTEIGNABLE
--    à l'insert (aucun reçu ne peut préexister au groupe) → le seul chemin reste
--    trial → facture → mark_invoice_paid → active. C'est la boucle de revenu.
CREATE OR REPLACE FUNCTION public.fn_guard_active_requires_payment()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_price integer;
BEGIN
  -- Ne concerne que l'état 'active'.
  IF NEW.subscription_status <> 'active'::subscription_status THEN
    RETURN NEW;
  END IF;
  -- En UPDATE, on ne rejoue pas la règle sur un groupe DÉJÀ actif (éditions).
  IF TG_OP = 'UPDATE'
     AND OLD.subscription_status = 'active'::subscription_status THEN
    RETURN NEW;
  END IF;

  SELECT price_xaf INTO v_price FROM subscription_plans WHERE id = NEW.plan_id;

  -- Plan gratuit → activation libre (mais une échéance reste requise).
  IF v_price IS NULL OR v_price = 0 THEN
    IF NEW.subscription_end IS NULL THEN
      NEW.subscription_end := (COALESCE(NEW.subscription_start, CURRENT_DATE)
                               + INTERVAL '1 year')::date;
    END IF;
    RETURN NEW;
  END IF;

  -- Plan payant → échéance obligatoire ET reçu payé qui la couvre.
  IF NEW.subscription_end IS NULL THEN
    RAISE EXCEPTION 'Activation refusée : échéance manquante pour un plan payant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM group_invoices gi
     WHERE gi.group_id = NEW.id
       AND gi.status   = 'paid'::invoice_status
       AND gi.period_end >= NEW.subscription_end
  ) THEN
    RAISE EXCEPTION
      'Activation refusée : aucun reçu payé ne couvre cette période. '
      'Enregistrez le paiement de la facture pour activer les modules.';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_active_requires_payment_ins ON public.school_groups;
CREATE TRIGGER trg_guard_active_requires_payment_ins
  BEFORE INSERT ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION fn_guard_active_requires_payment();

-- ④ Backfill : dater les essais existants SANS échéance depuis leur création.
--    Un essai créé il y a longtemps obtient une échéance passée → le prochain
--    passage de expire_subscriptions() le basculera en 'expired' (comportement
--    correct : il a déjà largement dépassé sa fenêtre). Le super_admin peut
--    toujours renouveler/prolonger ceux qui comptent.
UPDATE school_groups
   SET subscription_start = COALESCE(subscription_start, created_at::date),
       subscription_end   = COALESCE(subscription_start, created_at::date)
                            + fn_trial_days(),
       updated_at         = now()
 WHERE subscription_status = 'trial'::subscription_status
   AND subscription_end IS NULL;
