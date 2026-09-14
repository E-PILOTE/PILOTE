-- ════════════════════════════════════════════════════════════════════════════
--  0183 — LE TERME D'UN MINISTÈRE EST CELUI DE SA LICENCE
--
--  0182 a sorti les deux ministères de la formule mensuelle et mis leur
--  `subscription_end` à NULL. Cette migration fait de ce NULL une RÈGLE, parce
--  que la valeur seule ne tenait pas : CINQ chemins d'écriture la réinstallent.
--
--  ── POURQUOI LE NULL EST LA PROTECTION ────────────────────────────────────
--  Tout ce qui compte les jours d'un abonnement ignore un `subscription_end`
--  nul — et c'est la seule chose qui protège un ministère :
--    • `expire_subscriptions()`      → `AND subscription_end IS NOT NULL`
--    • `emit_subscription_reminders()` → `where subscription_end is not null`
--    • `fn_regularize_school_count()`  → `OR subscription_end IS NULL → RETURN`
--    • `computeSubscriptionAccess` (Dart) → `daysLeft == null ⇒ dateOk`
--  Rendez la date, et la cascade repart : rappels « votre abonnement expire
--  dans 30 jours » adressés au ministère, passage automatique en `expired`,
--  puis — quinze jours de grâce plus tard — **espace en LECTURE SEULE**.
--  C'est-à-dire le ministère de l'Éducation nationale mis à l'arrêt par une
--  date de facturation. Le 0160 l'avait déjà écrit : « une licence échue ne
--  coupe pas un ministère — on ne ferme pas l'État pour un mandat en retard ».
--
--  ── LES CINQ CHEMINS QUI LA RÉINSTALLAIENT, MESURÉS ───────────────────────
--   1. `fn_set_trial_window` (BEFORE INSERT) — l'écran de création envoie
--      `subscription_status = 'trial'` (group_form_modal.dart) : tout nouveau
--      ministère naissait donc avec une **période d'essai**.
--   2. `fn_auto_create_invoice` (AFTER INSERT) — plan à 0 XAF ⇒
--      `subscription_end = début + 12 mois`. Le nouveau ministère héritait de
--      l'échéance que 0182 venait de retirer aux deux autres.
--   3. `fn_guard_active_requires_payment` (BEFORE INSERT/UPDATE) — plan gratuit
--      et échéance nulle ⇒ il en **fabrique une**. Ne se déclenche pas sur un
--      groupe déjà actif, donc pas aujourd'hui ; il suffit qu'un ministère
--      repasse un jour de `expired` à `active` pour que la date revienne.
--   4. `create_renewal_invoice()` — le bouton « Renouveler mon abonnement » de
--      l'espace groupe : plan à 0 XAF ⇒ écrit `subscription_end = +12 mois`.
--   5. Toute écriture manuelle sur la colonne.
--
--  ── LA RÈGLE ──────────────────────────────────────────────────────────────
--  `administre_referentiel_national` ⇒ `subscription_end IS NULL`.
--
--  Elle est posée DEUX fois, et c'est délibéré — même partage des rôles qu'en
--  0178 : les quatre fonctions ci-dessus se comportent bien (elles savent
--  POURQUOI elles s'abstiennent, et le disent), et le déclencheur normalise ce
--  qui passerait quand même, quel que soit le chemin.
--
--  ── CE QUE CETTE MIGRATION NE FAIT PAS ────────────────────────────────────
--  Elle ne force PAS `subscription_status`. Un ministère ne peut plus expirer
--  tout seul (plus de date), mais le fondateur garde la main pour suspendre ou
--  résilier s'il le décide — sauf à la création, où `'trial'` n'a aucun sens
--  pour un ministère et devient `'active'`.
--
--  Elle ne touche à AUCUN groupe privé : chaque garde teste le drapeau de
--  ministère et retombe, sinon, sur le comportement d'avant, à la ligne près.
--  Les factures déjà émises restent — ce sont des faits comptables.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Le déclencheur devient aussi le normalisateur ───────────────────────
--  ⚠️ Il écoute désormais TOUTE mise à jour, plus seulement `plan_id` et
--  `administre_referentiel_national` : une échéance réinstallée par une autre
--  colonne (ou par le UPDATE d'un déclencheur AFTER) passerait sinon dessous.
CREATE OR REPLACE FUNCTION public.fn_ministere_sur_licence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_slug text;
BEGIN
  SELECT slug::text INTO v_slug
    FROM public.subscription_plans WHERE id = NEW.plan_id;

  IF NEW.administre_referentiel_national AND v_slug IS DISTINCT FROM 'licence' THEN
    RAISE EXCEPTION
      'Un ministere de tutelle ne se facture pas au mois'
      USING ERRCODE = '23514',
            HINT = 'Un ministère de tutelle est rattaché au plan « Licence de '
                   'tutelle », et ses conditions réelles se saisissent dans '
                   'Économie › Licences. Les formules mensuelles sont '
                   'réservées aux groupes scolaires privés.';
  END IF;

  IF v_slug = 'licence' AND NOT NEW.administre_referentiel_national THEN
    RAISE EXCEPTION
      'Le plan Licence de tutelle est reserve aux ministeres'
      USING ERRCODE = '23514',
            HINT = 'Ce plan ne porte aucun prix : y rattacher un groupe privé '
                   'le sortirait du revenu mensuel de la plateforme. '
                   'Choisissez une formule mensuelle.';
  END IF;

  -- NORMALISATION. Pas une exception : personne ne « demande » cette date, ce
  -- sont des automatismes de facturation qui la posent. Les refuser ferait
  -- échouer une création de groupe parfaitement légitime ; on la retire.
  IF NEW.administre_referentiel_national THEN
    NEW.subscription_end := NULL;

    -- Un ministère n'est pas en période d'essai. L'écran de création envoie
    -- 'trial' pour tout le monde ; on ne corrige qu'à la naissance, pour
    -- laisser au fondateur la main sur les statuts par la suite.
    IF TG_OP = 'INSERT'
       AND NEW.subscription_status = 'trial'::subscription_status THEN
      NEW.subscription_status := 'active'::subscription_status;
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.fn_ministere_sur_licence() IS
  'Deux natures de client, deux relations : ministere -> plan licence (contrat '
  'dans tutelle_licences, SANS subscription_end), groupe prive -> plan mensuel '
  '(revenu de la plateforme). Refuse les deux confusions de plan et normalise '
  'l''echeance d''un ministere a NULL, quel que soit le chemin d''ecriture.';

DROP TRIGGER IF EXISTS trg_ministere_sur_licence ON public.school_groups;
CREATE TRIGGER trg_ministere_sur_licence
  BEFORE INSERT OR UPDATE
  ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_ministere_sur_licence();

-- ── 2. Pas de période d'essai pour un ministère ────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_set_trial_window()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_days integer;
BEGIN
  -- Un ministère de tutelle n'essaie pas la plateforme : il la commande. Son
  -- terme est celui de sa licence (tutelle_licences), pas un compte à rebours.
  IF COALESCE(NEW.administre_referentiel_national, false) THEN
    RETURN NEW;
  END IF;

  -- Uniquement un essai SANS échéance explicite (on respecte une saisie manuelle).
  IF NEW.subscription_status = 'trial'::subscription_status
     AND NEW.subscription_end IS NULL THEN
    v_days := fn_trial_days();
    NEW.subscription_start := COALESCE(NEW.subscription_start, CURRENT_DATE);
    NEW.subscription_end   := NEW.subscription_start + v_days;  -- date + int → date
  END IF;
  RETURN NEW;
END;
$fn$;

-- ── 3. Pas de facture ni d'échéance auto pour un ministère ─────────────────
CREATE OR REPLACE FUNCTION public.fn_auto_create_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_price integer; v_months integer; v_schools integer; v_start date;
        v_end date; v_inv_number varchar;
BEGIN
  v_schools := group_school_count(NEW.id);

  -- Un ministère n'a pas d'abonnement à ouvrir : sa licence se saisit à la
  -- main dans Économie › Licences, avec son montant négocié et sa durée. Lui
  -- poser ici une échéance à +12 mois le remettrait dans la file des
  -- expirations, des rappels, puis de la lecture seule.
  IF COALESCE(NEW.administre_referentiel_national, false) THEN
    UPDATE school_groups
       SET billed_schools      = v_schools,
           subscription_status = 'active'::subscription_status,
           subscription_start  = COALESCE(NEW.subscription_start, CURRENT_DATE),
           subscription_end    = NULL
     WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  v_price   := group_price_xaf(NEW.id, NEW.plan_id);
  SELECT billing_period_months(billing_period) INTO v_months
    FROM subscription_plans WHERE id = NEW.plan_id;
  v_start := COALESCE(NEW.subscription_start, CURRENT_DATE);
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;
  UPDATE school_groups SET billed_schools = v_schools WHERE id = NEW.id;
  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET subscription_status = 'active'::subscription_status,
      subscription_start = v_start, subscription_end = v_end WHERE id = NEW.id;
    RETURN NEW;
  END IF;
  v_inv_number := generate_invoice_number();
  INSERT INTO group_invoices (group_id, invoice_number, amount_xaf, period_start,
                              period_end, plan_id, status, created_by, notes)
  VALUES (NEW.id, v_inv_number, v_price, v_start, v_end, NEW.plan_id,
          'pending'::invoice_status, COALESCE(NEW.created_by, auth.uid()),
          'Assiette : ' || v_schools || ' ecole(s).');
  RETURN NEW;
END;
$fn$;

-- ── 4. Le garde d'activation ne fabrique pas d'échéance pour un ministère ──
CREATE OR REPLACE FUNCTION public.fn_guard_active_requires_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_price  integer;
  v_months integer;
BEGIN
  -- Ne concerne que l'état 'active'.
  IF NEW.subscription_status <> 'active'::subscription_status THEN
    RETURN NEW;
  END IF;

  -- Un ministère s'active sans reçu et sans échéance : il ne paie pas
  -- d'abonnement, il exécute un marché. Le contrôle du règlement se fait sur
  -- la licence (montant_regle_xaf), pas en barrant l'accès de l'État.
  IF COALESCE(NEW.administre_referentiel_national, false) THEN
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
$fn$;

-- ── 5. « Renouveler mon abonnement » n'a pas de sens pour un ministère ─────
CREATE OR REPLACE FUNCTION public.create_renewal_invoice(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_plan_id uuid; v_price integer; v_months integer; v_schools integer;
        v_cur_end date; v_start date; v_end date; v_inv_number varchar;
        v_group_name text; v_ministere boolean; v_existing group_invoices%ROWTYPE;
BEGIN
  IF p_group_id IS NULL THEN RAISE EXCEPTION 'Groupe non specifie'; END IF;
  IF NOT (is_super_admin() OR (is_admin_groupe() AND auth_group_id() = p_group_id)) THEN
    RAISE EXCEPTION 'Acces refuse';
  END IF;
  SELECT plan_id, subscription_end, name, administre_referentiel_national
    INTO v_plan_id, v_cur_end, v_group_name, v_ministere
    FROM school_groups WHERE id = p_group_id;

  -- Une licence de tutelle ne se renouvelle pas d'un clic : elle se renégocie.
  -- Sans ce refus, le plan étant à 0 XAF, la branche « gratuit » plus bas
  -- réécrivait `subscription_end = +12 mois` — et remettait le ministère dans
  -- la file des expirations que 0182 et cette migration en sortent.
  IF COALESCE(v_ministere, false) THEN
    RAISE EXCEPTION 'Un ministere de tutelle ne renouvelle pas un abonnement'
      USING ERRCODE = '23514',
            HINT = 'Votre accès repose sur une licence de tutelle, dont le '
                   'terme et le montant sont fixés par votre marché avec '
                   'E-PILOTE Congo. Contactez la plateforme pour un avenant.';
  END IF;

  IF v_plan_id IS NULL THEN RAISE EXCEPTION 'Aucun plan attribue - contactez la plateforme pour en choisir un.'; END IF;
  v_schools := group_school_count(p_group_id);
  v_price   := group_price_xaf(p_group_id, v_plan_id);
  SELECT billing_period_months(billing_period) INTO v_months FROM subscription_plans WHERE id = v_plan_id;
  v_start := GREATEST(COALESCE(v_cur_end, CURRENT_DATE), CURRENT_DATE);
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;
  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET subscription_status = 'active'::subscription_status,
      subscription_start = COALESCE(subscription_start, CURRENT_DATE), subscription_end = v_end,
      billed_schools = v_schools, is_active = true, updated_at = NOW() WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true, 'free', true, 'period_end', v_end, 'schools', v_schools);
  END IF;
  SELECT * INTO v_existing FROM group_invoices WHERE group_id = p_group_id
   AND status IN ('pending'::invoice_status, 'overdue'::invoice_status) ORDER BY created_at DESC LIMIT 1;
  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'already_pending', true, 'invoice_id', v_existing.id,
      'invoice_number', v_existing.invoice_number, 'amount_xaf', v_existing.amount_xaf,
      'period_start', v_existing.period_start, 'period_end', v_existing.period_end);
  END IF;
  v_inv_number := generate_invoice_number();
  INSERT INTO group_invoices (group_id, invoice_number, amount_xaf, period_start, period_end, plan_id, status, created_by, notes)
  VALUES (p_group_id, v_inv_number, v_price, v_start, v_end, v_plan_id, 'pending'::invoice_status, auth.uid(),
          'Assiette : ' || v_schools || ' ecole(s).');
  UPDATE school_groups SET billed_schools = v_schools WHERE id = p_group_id;
  RETURN jsonb_build_object('success', true, 'invoice_number', v_inv_number, 'amount_xaf', v_price,
    'schools', v_schools, 'period_start', v_start, 'period_end', v_end, 'group_name', v_group_name);
END;
$fn$;

-- ── 6. Vérification : l'invariant tient sur les lignes existantes ──────────
DO $verif$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.school_groups
   WHERE administre_referentiel_national AND subscription_end IS NOT NULL;
  IF n > 0 THEN
    RAISE EXCEPTION 'Invariant viole : % ministere(s) portent encore une '
      'echeance d''abonnement.', n;
  END IF;
END;
$verif$;

COMMIT;
