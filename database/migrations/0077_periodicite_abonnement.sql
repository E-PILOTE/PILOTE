-- ════════════════════════════════════════════════════════════════════════════
--  0077 — LA PÉRIODICITÉ D'ABONNEMENT : MENSUEL, TRIMESTRIEL, SEMESTRIEL, ANNUEL
--
--  ── LE MENSONGE QU'ON CORRIGE ──────────────────────────────────────────────
--  L'écran des plans annonçait « Prix mensuel ». La base, elle, facturait ce
--  même montant pour DOUZE MOIS :
--
--      fn_auto_create_invoice   : v_end := v_start + INTERVAL '1 year'
--      create_renewal_invoice   : v_end := v_start + INTERVAL '1 year'
--
--  Les deux ne pouvaient pas avoir raison. Les factures réellement émises
--  tranchent : `INV-2026-0004`, 900 000 FCFA, période 2026-01-01 → 2026-12-31.
--  Le tarif était donc ANNUEL, et l'étiquette « mensuel » était fausse — avec
--  un facteur 12 sur le revenu affiché.
--
--  ── CE QUE ÇA CHANGE ───────────────────────────────────────────────────────
--  La durée cesse d'être une constante enfouie dans deux fonctions pour devenir
--  une propriété du plan, choisie à l'écran. Un plan mensuel facture 1 mois, un
--  plan trimestriel 3, etc. La facture et la date de fin d'abonnement suivent.
--
--  ── LE DÉFAUT EST `annuel`, ET C'EST UN CHOIX ──────────────────────────────
--  Pas par prudence : par fidélité aux faits. Les quatre plans existants ont
--  produit des factures annuelles ; les déclarer mensuels d'office aurait
--  rétroactivement divisé par douze la période de tout ce qui a été vendu.
--  Chaque plan reste modifiable à l'écran en un clic.
--
--  ⚠️ Le revenu récurrent (MRR) doit désormais RAMENER chaque tarif au mois —
--  2 500 000 FCFA/an, ce n'est pas 2 500 000 FCFA de MRR. Côté Dart :
--  `PlanDetail.monthlyRevenue`, couvert par `test/plan_referential_test.dart`.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
--  1. LE TYPE ET LA COLONNE
-- ────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'billing_period') THEN
    CREATE TYPE billing_period AS ENUM
      ('mensuel', 'trimestriel', 'semestriel', 'annuel');
  END IF;
END $$;

ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS billing_period billing_period NOT NULL DEFAULT 'annuel';

COMMENT ON COLUMN public.subscription_plans.billing_period IS
  'Durée couverte par price_xaf. Pilote la période des factures (0077).';

-- Le nombre de mois d'une période — une seule table de correspondance, pour la
-- base ET pour l'app (`billingPeriodMonths` en Dart lui répond mot pour mot).
CREATE OR REPLACE FUNCTION public.billing_period_months(p billing_period)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p
           WHEN 'mensuel'     THEN 1
           WHEN 'trimestriel' THEN 3
           WHEN 'semestriel'  THEN 6
           WHEN 'annuel'      THEN 12
         END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
--  2. LA FACTURE À LA CRÉATION D'UN GROUPE SUIT LE PLAN
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_auto_create_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_price      integer;
  v_months     integer;
  v_start      date;
  v_end        date;
  v_inv_number varchar;
BEGIN
  SELECT price_xaf, billing_period_months(billing_period)
    INTO v_price, v_months
    FROM subscription_plans WHERE id = NEW.plan_id;

  v_start := COALESCE(NEW.subscription_start, CURRENT_DATE);
  -- La durée vient du PLAN, elle n'est plus une constante de cette fonction.
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;

  -- Plan gratuit → actif immédiatement pour le terme (l'essai ne s'applique pas).
  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET
      subscription_status = 'active'::subscription_status,
      subscription_start  = v_start,
      subscription_end    = v_end
    WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  -- Plan payant → facture PENDING pour le terme COMPLET. Le groupe reste en
  -- essai (subscription_end court) jusqu'au paiement ; mark_invoice_paid posera
  -- alors subscription_end = period_end (= v_end). La fenêtre d'essai est un
  -- accès gratuit borné, distinct du terme facturé.
  v_inv_number := generate_invoice_number();
  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by
  ) VALUES (
    NEW.id, v_inv_number, v_price,
    v_start, v_end, NEW.plan_id,
    'pending'::invoice_status,
    COALESCE(NEW.created_by, auth.uid())
  );
  RETURN NEW;
END;
$function$;

-- ────────────────────────────────────────────────────────────────────────────
--  3. LE RÉABONNEMENT AUSSI
--
--  Seule la ligne de calcul de `v_end` change ; le reste (autorisation, plan
--  gratuit, idempotence sur facture impayée) est repris à l'identique.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_renewal_invoice(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_plan_id    uuid;
  v_price      integer;
  v_months     integer;
  v_cur_end    date;
  v_start      date;
  v_end        date;
  v_inv_number varchar;
  v_group_name text;
  v_existing   group_invoices%ROWTYPE;
BEGIN
  -- Garde-fou NULL : `x = NULL` vaut NULL (ni vrai ni faux) et laisserait
  -- filer la vérification d'autorisation. On l'écarte explicitement.
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non spécifié';
  END IF;

  -- Autorisation : super_admin, ou l'admin_groupe de CE groupe uniquement.
  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = p_group_id)) THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  SELECT plan_id, subscription_end, name
    INTO v_plan_id, v_cur_end, v_group_name
    FROM school_groups WHERE id = p_group_id;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'Aucun plan attribué — contactez la plateforme pour en choisir un.';
  END IF;

  SELECT price_xaf, billing_period_months(billing_period)
    INTO v_price, v_months
    FROM subscription_plans WHERE id = v_plan_id;

  -- Nouvelle période : enchaîne sur la fin courante si encore future, sinon
  -- démarre aujourd'hui (pas de rétroactivité qui « brûlerait » des jours).
  v_start := GREATEST(COALESCE(v_cur_end, CURRENT_DATE), CURRENT_DATE);
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;

  -- Plan gratuit : pas de facture, prolongation directe.
  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET
      subscription_status = 'active'::subscription_status,
      subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
      subscription_end    = v_end,
      is_active           = true,
      updated_at          = NOW()
    WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true, 'free', true,
                              'period_end', v_end);
  END IF;

  -- Idempotence : une facture impayée existe déjà → on la renvoie.
  SELECT * INTO v_existing FROM group_invoices
   WHERE group_id = p_group_id
     AND status IN ('pending'::invoice_status, 'overdue'::invoice_status)
   ORDER BY created_at DESC LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true, 'already_pending', true,
      'invoice_id', v_existing.id,
      'invoice_number', v_existing.invoice_number,
      'amount_xaf', v_existing.amount_xaf,
      'period_start', v_existing.period_start,
      'period_end', v_existing.period_end);
  END IF;

  v_inv_number := generate_invoice_number();

  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by
  ) VALUES (
    p_group_id, v_inv_number, v_price,
    v_start, v_end, v_plan_id,
    'pending'::invoice_status, auth.uid()
  );

  RETURN jsonb_build_object(
    'success', true,
    'invoice_number', v_inv_number,
    'amount_xaf', v_price,
    'period_start', v_start,
    'period_end', v_end,
    'group_name', v_group_name);
END;
$function$;

COMMIT;
