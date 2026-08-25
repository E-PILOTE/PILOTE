-- ════════════════════════════════════════════════════════════════════════════
--  0078 — CHANGER DE PLAN EN COURS D'ABONNEMENT
--
--  ── LE TROU ────────────────────────────────────────────────────────────────
--  `trg_auto_create_invoice` ne se déclenche qu'à la CRÉATION d'un groupe.
--  Déplacer ensuite un groupe d'un plan à l'autre ne produisait rien : ni
--  facture, ni trace, ni notification. Le cas est en base — le METP a réglé
--  `INV-2026-0007` (150 000 FCFA, plan premium) et se trouve aujourd'hui sur
--  `institutionnel`, actif jusqu'au 2027-05-30 sur la foi d'un reçu premium.
--  L'écart était offert, et personne ne le voyait.
--
--  ── LA RÈGLE, ET POURQUOI ELLE EST ASYMÉTRIQUE ─────────────────────────────
--  MONTÉE EN GAMME → facture complémentaire immédiate, au prorata des jours
--  restants. Le groupe consomme dès maintenant les quotas et modules du plan
--  supérieur : il paie la différence sur la période déjà courue d'avance.
--
--  DESCENTE EN GAMME → aucune facture, aucun remboursement. La période en cours
--  a été payée, elle est due ; le nouveau tarif s'applique au renouvellement.
--  C'est le seul comportement qui n'exige ni avoir, ni remboursement — deux
--  objets que `group_invoices` ne sait pas représenter (`amount_xaf` négatif
--  traverserait tous les totaux de la plateforme). Une notification l'annonce
--  au client, plutôt que de laisser croire à un geste commercial.
--
--  ── LE PRORATA ─────────────────────────────────────────────────────────────
--      annualisé(plan) = price_xaf × 12 ÷ mois_de_la_période
--      delta = (annualisé_nouveau − annualisé_ancien) × jours_restants ÷ 365
--
--  Passer par l'annualisé plutôt que par le montant facturé rend le calcul
--  indépendant de la périodicité : comparer un plan mensuel à un plan annuel
--  sur leurs montants bruts n'aurait aucun sens (cf. migration 0077).
--
--  ── ⚠️ UN VERROU QUI POUVAIT RECULER ───────────────────────────────────────
--  `mark_invoice_paid` posait `subscription_end = period_end` sans condition.
--  Or la facture de régularisation se termine à l'échéance COURANTE. Si un
--  renouvellement (période future) était déjà réglé, encaisser ensuite la
--  régularisation RAMENAIT l'échéance en arrière — le groupe perdait l'année
--  qu'il venait de payer. L'échéance ne peut désormais qu'avancer.
--
--  Rien ici ne touche au verrou dur ADR-0009 : la facture naît `pending`, le
--  groupe reste actif jusqu'à son échéance, et `fn_guard_active_requires_payment`
--  continue d'exiger un reçu payé pour toute NOUVELLE activation.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
--  1. LE TARIF ANNUALISÉ — seule base de comparaison entre deux périodicités
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.plan_annualized_xaf(p_plan_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT (sp.price_xaf::numeric * 12
             / GREATEST(billing_period_months(sp.billing_period), 1))::integer
       FROM subscription_plans sp WHERE sp.id = p_plan_id),
    0);
$$;

COMMENT ON FUNCTION public.plan_annualized_xaf(uuid) IS
  'Tarif ramené à l''année — comparable entre périodicités (0077/0078).';

-- ────────────────────────────────────────────────────────────────────────────
--  2. LA RÉGULARISATION
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_regularize_plan_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_old_year  integer;
  v_new_year  integer;
  v_days      integer;
  v_delta     integer;
  v_inv       varchar;
  v_old_name  text;
  v_new_name  text;
  v_actor     uuid;
BEGIN
  -- Rien à régulariser hors d'un abonnement actif et non échu : un groupe en
  -- essai ou expiré n'a pas de période payée d'avance à corriger.
  IF NEW.subscription_status <> 'active'::subscription_status
     OR NEW.subscription_end IS NULL
     OR NEW.subscription_end <= CURRENT_DATE THEN
    RETURN NULL;
  END IF;

  v_old_year := plan_annualized_xaf(OLD.plan_id);
  v_new_year := plan_annualized_xaf(NEW.plan_id);
  v_days     := NEW.subscription_end - CURRENT_DATE;

  SELECT name INTO v_old_name FROM subscription_plans WHERE id = OLD.plan_id;
  SELECT name INTO v_new_name FROM subscription_plans WHERE id = NEW.plan_id;
  v_actor := COALESCE(auth.uid(), NEW.created_by);

  -- ── Descente en gamme : rien à facturer, mais on le DIT ──────────────────
  IF v_new_year <= v_old_year THEN
    INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
    SELECT NEW.id, p.id, 'subscription',
           'Changement de plan — ' || COALESCE(v_new_name, '—'),
           'Votre abonnement passe au plan ' || COALESCE(v_new_name, '—')
             || '. La période en cours reste réglée aux conditions '
             || 'précédentes ; le nouveau tarif s''appliquera à votre '
             || 'prochain renouvellement, le '
             || to_char(NEW.subscription_end, 'DD/MM/YYYY') || '.',
           false
      FROM profiles p
     WHERE p.group_id = NEW.id AND p.role = 'admin_groupe' AND p.is_active;
    RETURN NULL;
  END IF;

  -- ── Montée en gamme : facture complémentaire au prorata ──────────────────
  v_delta := ROUND((v_new_year - v_old_year)::numeric * v_days / 365.0);

  -- Un écart nul (deux plans au même tarif annualisé) ne mérite pas de facture.
  IF v_delta <= 0 THEN
    RETURN NULL;
  END IF;

  v_inv := generate_invoice_number();

  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by, notes
  ) VALUES (
    NEW.id, v_inv, v_delta,
    CURRENT_DATE, NEW.subscription_end, NEW.plan_id,
    'pending'::invoice_status, v_actor,
    'Régularisation : passage du plan ' || COALESCE(v_old_name, '—')
      || ' au plan ' || COALESCE(v_new_name, '—')
      || ' le ' || to_char(CURRENT_DATE, 'DD/MM/YYYY')
      || ' — ' || v_days || ' jour(s) restant(s) au prorata.'
  );

  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT NEW.id, p.id, 'subscription',
         'Facture de régularisation — ' || v_inv,
         'Votre abonnement passe au plan ' || COALESCE(v_new_name, '—')
           || '. Une facture complémentaire de ' || v_delta
           || ' XAF couvre les ' || v_days
           || ' jour(s) restants jusqu''au '
           || to_char(NEW.subscription_end, 'DD/MM/YYYY') || '.',
         false
    FROM profiles p
   WHERE p.group_id = NEW.id AND p.role = 'admin_groupe' AND p.is_active;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_regularize_plan_change ON public.school_groups;
CREATE TRIGGER trg_regularize_plan_change
  AFTER UPDATE OF plan_id ON public.school_groups
  FOR EACH ROW
  WHEN (OLD.plan_id IS DISTINCT FROM NEW.plan_id)
  EXECUTE FUNCTION public.fn_regularize_plan_change();

-- ────────────────────────────────────────────────────────────────────────────
--  3. L'ÉCHÉANCE NE PEUT PLUS RECULER
--
--  Seule la ligne `subscription_end` change ; le reste de `mark_invoice_paid`
--  est repris à l'identique.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.mark_invoice_paid(
  p_invoice_id uuid,
  p_payment_method text,
  p_payment_ref text DEFAULT NULL::text,
  p_notes text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_group_id   UUID;
  v_plan_id    UUID;
  v_amount     INTEGER;
  v_period_end DATE;
  v_inv_number VARCHAR;
  v_status     invoice_status;
  v_rec_number VARCHAR;
  v_new_end    DATE;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Accès refusé : seul le super administrateur peut enregistrer un paiement';
  END IF;

  SELECT group_id, plan_id, amount_xaf, period_end, invoice_number, status
    INTO v_group_id, v_plan_id, v_amount, v_period_end, v_inv_number, v_status
    FROM group_invoices WHERE id = p_invoice_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Facture introuvable';
  END IF;
  IF v_status = 'paid'::invoice_status THEN
    RAISE EXCEPTION 'Facture déjà réglée';
  END IF;

  v_rec_number := 'REC-' || substring(v_inv_number from 5);

  UPDATE group_invoices SET
    status            = 'paid'::invoice_status,
    paid_at           = NOW(),
    payment_method    = p_payment_method::payment_method,
    payment_reference = p_payment_ref,
    receipt_number    = v_rec_number,
    notes             = COALESCE(p_notes, notes),
    updated_at        = NOW()
  WHERE id = p_invoice_id;

  -- ⚠️ L'échéance d'un groupe DÉJÀ ACTIF ne peut qu'avancer : une facture de
  -- régularisation se termine à l'échéance courante, et l'encaisser après un
  -- renouvellement déjà réglé aurait ramené le groupe en arrière — il aurait
  -- perdu l'année qu'il venait de payer.
  --
  -- Pour un groupe NON encore actif, c'est l'inverse : la période payée fait
  -- foi, point. Prendre le maximum lui offrirait une échéance qu'aucun reçu ne
  -- couvre — et `fn_guard_active_requires_payment` refuserait l'activation,
  -- laissant le groupe bloqué APRÈS avoir payé.
  SELECT CASE WHEN subscription_status = 'active'::subscription_status
              THEN GREATEST(COALESCE(subscription_end, v_period_end), v_period_end)
              ELSE v_period_end
         END
    INTO v_new_end
    FROM school_groups WHERE id = v_group_id;

  -- Activation : le SEUL endroit qui pose status=active + subscription_end.
  UPDATE school_groups SET
    subscription_status = 'active'::subscription_status,
    subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
    subscription_end    = v_new_end,
    is_active           = true,
    updated_at          = NOW()
  WHERE id = v_group_id;

  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT v_group_id, p.id, 'payment',
         'Paiement confirmé — ' || v_rec_number,
         'Votre facture de ' || v_amount || ' XAF a été réglée. '
           || 'Votre abonnement est actif jusqu''au '
           || to_char(v_new_end, 'DD/MM/YYYY') || '.',
         false
    FROM profiles p
   WHERE p.group_id = v_group_id AND p.role = 'admin_groupe' AND p.is_active;

  RETURN jsonb_build_object(
    'success', true,
    'receipt_number', v_rec_number,
    'amount_xaf', v_amount,
    'period_end', v_new_end);
END;
$function$;

-- ────────────────────────────────────────────────────────────────────────────
--  4. LE VERROU DUR SUIT AUSSI LA PÉRIODICITÉ
--
--  Sa branche « plan gratuit » posait une échéance à un an en dur, reste de
--  l'époque où la durée était une constante (cf. 0077).
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_guard_active_requires_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_price  integer;
  v_months integer;
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

  SELECT price_xaf, billing_period_months(billing_period)
    INTO v_price, v_months
    FROM subscription_plans WHERE id = NEW.plan_id;

  -- Plan gratuit → activation libre (mais une échéance reste requise).
  IF v_price IS NULL OR v_price = 0 THEN
    IF NEW.subscription_end IS NULL THEN
      NEW.subscription_end := (COALESCE(NEW.subscription_start, CURRENT_DATE)
                               + make_interval(months => COALESCE(v_months, 12)))::date;
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

COMMIT;
