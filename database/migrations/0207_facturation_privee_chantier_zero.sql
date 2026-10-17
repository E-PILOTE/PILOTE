-- ============================================================================
-- 0207 — Chantier 0 du recentrage privé : la facturation, seul revenu restant
-- ----------------------------------------------------------------------------
-- Audit du 2026-10-17 (docs/analyse-2026-10/audit-public-prive-tutelle.md).
--
-- C1. Encaisser une facture dont la période est ÉCOULÉE réactivait le groupe
--     jusqu'à cette date passée. Test en transaction annulée : solder
--     INV-2026-0043 (oct. 2025, déjà couvert par l'annuel INV-2026-0051)
--     donnait « actif jusqu'au 01/11/2025 », puis `expired` à 01 h 05.
--     → Une facture déjà couverte par un reçu se REFUSE (elle se fait annuler).
--     → Une facture d'arriérés s'ENCAISSE sans toucher à l'abonnement.
--
-- C2. `_emettre_facture_renouvellement` s'arrêtait sur N'IMPORTE QUELLE
--     facture en attente. Une facture d'octobre 2025 a ainsi bloqué toute
--     relance de deux groupes échus au 30/09, chaque nuit, en « succeeded ».
--     → Seule bloque une facture qui PROLONGE l'échéance actuelle.
--
-- M7. `billed_schools` restait à 1 pour des groupes de 2 ou 3 écoles :
--     `fn_regularize_school_count` sortait si `auth.uid()` était nul, si le
--     groupe n'était pas actif, ou s'il était en essai. L'assiette suit
--     désormais TOUJOURS le nombre d'écoles ; seule la facture de prorata
--     reste réservée à un groupe actif.
--
-- M8. Le quota d'élèves REFUSAIT l'insertion en 23514. Sur le chemin hors
--     ligne, c'est un code FATAL (`_fatalResponseCodes`, classe 23) : l'élève
--     inscrit au-delà du quota était JETÉ en silence, avec tout son lot
--     PowerSync. La barrière passe dans l'application, AVANT l'écriture
--     locale (quota porté par la licence signée) ; le serveur CONSTATE et
--     prévient, il ne jette plus rien.
-- ============================================================================


-- ── C1 ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_invoice_paid(
  p_invoice_id uuid, p_payment_method text,
  p_payment_ref text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_group_id     UUID;
  v_plan_id      UUID;
  v_amount       INTEGER;
  v_period_start DATE;
  v_period_end   DATE;
  v_inv_number   VARCHAR;
  v_status       invoice_status;
  v_rec_number   VARCHAR;
  v_new_end      DATE;
  v_couvrante    VARCHAR;
  v_arrieres     BOOLEAN;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Accès refusé : seul le super administrateur peut enregistrer un paiement';
  END IF;

  SELECT group_id, plan_id, amount_xaf, period_start, period_end, invoice_number, status
    INTO v_group_id, v_plan_id, v_amount, v_period_start, v_period_end, v_inv_number, v_status
    FROM group_invoices WHERE id = p_invoice_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Facture introuvable';
  END IF;
  IF v_status = 'paid'::invoice_status THEN
    RAISE EXCEPTION 'Facture déjà réglée';
  END IF;

  -- ⚠️ Une période déjà payée ne se paie pas deux fois. Encaisser ici, c'est
  -- prendre l'argent du client pour un service qu'il a déjà réglé.
  SELECT gi.invoice_number INTO v_couvrante
    FROM group_invoices gi
   WHERE gi.group_id = v_group_id
     AND gi.id <> p_invoice_id
     AND gi.status = 'paid'::invoice_status
     AND gi.period_start <= v_period_start
     AND gi.period_end   >= v_period_end
   ORDER BY gi.paid_at DESC NULLS LAST
   LIMIT 1;

  IF v_couvrante IS NOT NULL THEN
    RAISE EXCEPTION 'Periode deja reglee par %', v_couvrante
      USING ERRCODE = '23514',
            HINT = format(
              'La période du %s au %s est déjà couverte par le reçu de la '
              'facture %s. Encaisser %s ferait payer deux fois le même mois : '
              'annulez-la plutôt.',
              to_char(v_period_start, 'DD/MM/YYYY'),
              to_char(v_period_end, 'DD/MM/YYYY'),
              v_couvrante, v_inv_number);
  END IF;

  -- Arriérés : la période est entièrement écoulée. On ENREGISTRE l'argent,
  -- mais on ne réactive rien : poser une échéance passée remettrait le
  -- groupe « actif » jusqu'à hier, et l'expiration de la nuit le défaierait.
  v_arrieres := v_period_end < CURRENT_DATE;

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

  IF v_arrieres THEN
    INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
    SELECT v_group_id, p.id, 'payment',
           'Règlement d''arriérés — ' || v_rec_number,
           'Votre règlement de ' || v_amount || ' XAF pour la période du '
             || to_char(v_period_start, 'DD/MM/YYYY') || ' au '
             || to_char(v_period_end, 'DD/MM/YYYY')
             || ' a été enregistré. Il ne prolonge pas votre abonnement en cours.',
           false
      FROM profiles p
     WHERE p.group_id = v_group_id AND p.role = 'admin_groupe' AND p.is_active;

    RETURN jsonb_build_object(
      'success', true,
      'receipt_number', v_rec_number,
      'amount_xaf', v_amount,
      'arrieres', true,
      'period_end', NULL);
  END IF;

  -- L'échéance d'un groupe DÉJÀ ACTIF ne peut qu'avancer. Pour un groupe NON
  -- actif, la période payée fait foi — et elle est, ici, non écoulée.
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
    'arrieres', false,
    'period_end', v_new_end);
END;
$function$;


-- ── C2 ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._emettre_facture_renouvellement(
  p_group_id uuid, p_notifier boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_plan_id   uuid;
  v_price     integer;
  v_months    integer;
  v_schools   integer;
  v_cur_end   date;
  v_start     date;
  v_end       date;
  v_inv       varchar;
  v_nom       text;
  v_ministere boolean;
  v_auteur    uuid;
  v_existante group_invoices%ROWTYPE;
BEGIN
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non specifie';
  END IF;

  SELECT plan_id, subscription_end, name, administre_referentiel_national
    INTO v_plan_id, v_cur_end, v_nom, v_ministere
    FROM school_groups WHERE id = p_group_id;

  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'Groupe introuvable';
  END IF;

  IF COALESCE(v_ministere, false) THEN
    RAISE EXCEPTION 'Un ministere de tutelle ne renouvelle pas un abonnement'
      USING ERRCODE = '23514';
  END IF;

  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'Aucun plan attribue - contactez la plateforme pour en choisir un.';
  END IF;

  v_schools := group_school_count(p_group_id);
  v_price   := group_price_xaf(p_group_id, v_plan_id);
  SELECT billing_period_months(billing_period) INTO v_months
    FROM subscription_plans WHERE id = v_plan_id;

  v_start := GREATEST(COALESCE(v_cur_end, CURRENT_DATE), CURRENT_DATE);
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;

  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups
       SET subscription_status = 'active'::subscription_status,
           subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
           subscription_end    = v_end,
           billed_schools      = v_schools,
           is_active           = true,
           updated_at          = NOW()
     WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true, 'free', true,
                              'period_end', v_end, 'schools', v_schools);
  END IF;

  -- ⚠️ Idempotence : on ne réémet pas si une facture en attente PROLONGE
  -- déjà l'échéance AU-DELÀ D'AUJOURD'HUI. Une facture en attente dont la
  -- période est écoulée (arriérés, régularisation, relance restée impayée)
  -- ne renouvelle rien — `mark_invoice_paid` l'encaisse sans réactiver : elle
  -- ne doit pas empêcher le renouvellement. C'est elle qui avait tari le
  -- revenu de trois groupes échus, sans un seul message.
  SELECT * INTO v_existante FROM group_invoices
   WHERE group_id = p_group_id
     AND status IN ('pending'::invoice_status, 'overdue'::invoice_status)
     AND period_end > GREATEST(COALESCE(v_cur_end, CURRENT_DATE), CURRENT_DATE)
   ORDER BY created_at DESC LIMIT 1;

  IF v_existante.id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'already_pending', true,
      'invoice_id', v_existante.id, 'invoice_number', v_existante.invoice_number,
      'amount_xaf', v_existante.amount_xaf,
      'period_start', v_existante.period_start,
      'period_end', v_existante.period_end);
  END IF;

  v_auteur := COALESCE(
    auth.uid(),
    (SELECT id FROM profiles WHERE role = 'super_admin' ORDER BY created_at LIMIT 1),
    (SELECT created_by FROM school_groups WHERE id = p_group_id));

  IF v_auteur IS NULL THEN
    RAISE EXCEPTION 'Aucun auteur imputable pour la facture (ni session, ni super_admin)';
  END IF;

  v_inv := generate_invoice_number();

  INSERT INTO group_invoices (group_id, invoice_number, amount_xaf, period_start,
                              period_end, plan_id, status, created_by, notes)
  VALUES (p_group_id, v_inv, v_price, v_start, v_end, v_plan_id,
          'pending'::invoice_status, v_auteur,
          'Assiette : ' || v_schools || ' ecole(s).');

  UPDATE school_groups SET billed_schools = v_schools WHERE id = p_group_id;

  IF p_notifier THEN
    INSERT INTO notifications (group_id, recipient_id, type, title, body, data, sent_at)
    SELECT p_group_id, p.id, 'subscription',
           'Facture de renouvellement — ' || v_inv,
           CASE
             WHEN v_cur_end IS NULL THEN ''
             WHEN v_cur_end < CURRENT_DATE THEN
               'Votre abonnement est arrivé à échéance le '
                 || to_char(v_cur_end, 'DD/MM/YYYY') || '. '
             ELSE
               'Votre abonnement arrive à échéance le '
                 || to_char(v_cur_end, 'DD/MM/YYYY') || '. '
           END
             || 'Une facture de '
             || replace(to_char(v_price, 'FM999G999G999'), ',', ' ')
             || ' FCFA couvre la période du '
             || to_char(v_start, 'DD/MM/YYYY') || ' au '
             || to_char(v_end, 'DD/MM/YYYY') || ' (' || v_schools || ' école(s)).',
           jsonb_build_object('route', '/admin/abonnement',
                              'invoice_number', v_inv,
                              'amount_xaf', v_price,
                              'period_end', v_end),
           now()
      FROM profiles p
     WHERE p.group_id = p_group_id AND p.role = 'admin_groupe' AND p.is_active;
  END IF;

  RETURN jsonb_build_object('success', true, 'invoice_number', v_inv,
    'amount_xaf', v_price, 'schools', v_schools,
    'period_start', v_start, 'period_end', v_end, 'group_name', v_nom);
END;
$function$;


-- ── M7 ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_regularize_school_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE g school_groups%ROWTYPE; v_now integer; v_was integer; v_days integer;
        v_delta integer; v_inv varchar; v_plan text; v_auteur uuid;
BEGIN
  IF NEW.group_id IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO g FROM school_groups WHERE id = NEW.group_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_now := group_school_count(NEW.group_id);
  v_was := COALESCE(g.billed_schools, v_now);
  IF v_now <= v_was THEN RETURN NULL; END IF;

  -- L'ASSIETTE suit toujours le parc réel — quel que soit le statut, et quel
  -- que soit le chemin d'écriture (session, script, migration). Une baisse ne
  -- se crédite pas en cours de période : le renouvellement recompte.
  UPDATE school_groups SET billed_schools = v_now WHERE id = NEW.group_id;

  -- La FACTURE de prorata, elle, ne concerne qu'une période payée en cours.
  IF g.price_override_xaf IS NOT NULL THEN RETURN NULL; END IF;
  IF g.subscription_status <> 'active'::subscription_status OR g.subscription_end IS NULL
     OR g.subscription_end <= CURRENT_DATE THEN RETURN NULL; END IF;

  v_days  := g.subscription_end - CURRENT_DATE;
  v_delta := ROUND((plan_annualized_for(g.plan_id, v_now) - plan_annualized_for(g.plan_id, v_was))::numeric * v_days / 365.0);
  IF v_delta <= 0 THEN RETURN NULL; END IF;

  -- `created_by` est NOT NULL : hors session, on impute à l'opérateur plutôt
  -- que de faire échouer la création de l'école.
  v_auteur := COALESCE(
    auth.uid(),
    (SELECT id FROM profiles WHERE role = 'super_admin' ORDER BY created_at LIMIT 1),
    g.created_by);
  IF v_auteur IS NULL THEN RETURN NULL; END IF;

  SELECT name INTO v_plan FROM subscription_plans WHERE id = g.plan_id;
  v_inv := generate_invoice_number();
  INSERT INTO group_invoices (group_id, invoice_number, amount_xaf, period_start, period_end, plan_id, status, created_by, notes)
  VALUES (NEW.group_id, v_inv, v_delta, CURRENT_DATE, g.subscription_end, g.plan_id, 'pending'::invoice_status, v_auteur,
    'Regularisation : passage de ' || v_was || ' a ' || v_now || ' ecole(s) le ' || to_char(CURRENT_DATE, 'DD/MM/YYYY')
      || ' - ' || v_days || ' jour(s) au prorata, plan ' || COALESCE(v_plan, '-') || '.');
  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT NEW.group_id, p.id, 'subscription', 'Facture de regularisation - ' || v_inv,
         'Votre reseau passe de ' || v_was || ' a ' || v_now || ' ecole(s). Une facture complementaire de '
           || v_delta || ' XAF couvre les ' || v_days || ' jour(s) restants jusqu''au '
           || to_char(g.subscription_end, 'DD/MM/YYYY') || '.', false
    FROM profiles p WHERE p.group_id = NEW.group_id AND p.role = 'admin_groupe' AND p.is_active;
  RETURN NULL;
END; $function$;

-- Rattrapage : les trois groupes dont l'assiette était restée à une école.
UPDATE public.school_groups g
   SET billed_schools = public.group_school_count(g.id)
 WHERE COALESCE(g.billed_schools, 0) < public.group_school_count(g.id);


-- ── M8 ─────────────────────────────────────────────────────────────────────
-- Le serveur ne REFUSE plus un élève : sur le chemin hors ligne, refuser
-- c'est jeter. Il CONSTATE le dépassement et prévient l'administrateur du
-- groupe — une fois par jour, pas une fois par élève importé.
CREATE OR REPLACE FUNCTION public.fn_enforce_student_quota()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_max integer; v_n integer; v_plan text;
BEGIN
  IF NEW.group_id IS NULL OR NOT COALESCE(NEW.is_active, true) THEN
    RETURN NULL;
  END IF;

  SELECT sp.max_students, sp.name INTO v_max, v_plan
    FROM school_groups sg JOIN subscription_plans sp ON sp.id = sg.plan_id
   WHERE sg.id = NEW.group_id;

  IF v_max IS NULL OR v_max < 0 THEN RETURN NULL; END IF;

  SELECT count(*) INTO v_n FROM students
   WHERE group_id = NEW.group_id AND is_active;
  IF v_n <= v_max THEN RETURN NULL; END IF;

  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT NEW.group_id, p.id, 'subscription',
         'Quota d''élèves dépassé',
         'Votre formule ' || COALESCE(v_plan, '') || ' autorise ' || v_max
           || ' élèves ; votre réseau en compte ' || v_n
           || '. Passez à une formule supérieure pour continuer à inscrire.',
         false
    FROM profiles p
   WHERE p.group_id = NEW.group_id AND p.role = 'admin_groupe' AND p.is_active
     AND NOT EXISTS (
       SELECT 1 FROM notifications n
        WHERE n.recipient_id = p.id
          AND n.title = 'Quota d''élèves dépassé'
          AND n.created_at >= CURRENT_DATE);
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_student_quota ON public.students;
CREATE TRIGGER trg_enforce_student_quota
  AFTER INSERT ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_student_quota();
