-- ════════════════════════════════════════════════════════════════════════════
--  0209 — UNE FACTURE EN ATTENTE SUIT LE NOMBRE D'ÉCOLES
--
--  Le prix d'un groupe suit son nombre d'écoles (0159). Mais la facture
--  d'ouverture est émise À LA CRÉATION DU GROUPE (fn_auto_create_invoice),
--  avant que la moindre école n'existe : `group_school_count` vaut alors 1.
--  Un réseau de sept écoles recevait une facture de 50 000 F au lieu du prix
--  de sept écoles — constaté le 2026-10-21 en créant un groupe de démo.
--
--  Et rien ne la rattrapait : `fn_regularize_school_count` montait bien
--  `billed_schools` à 7, mais
--    • pendant l'essai, il s'arrêtait là (pas de prorata hors `active`) ;
--    • après paiement, plus rien : le compteur étant déjà à 7, aucune
--      régularisation ne se déclenchait jamais.
--  Le client payait durablement le prix d'une école. Même défaut pour une
--  facture de renouvellement émise, puis un réseau qui grandit avant de
--  la régler : la période suivante partait sous-facturée.
--
--  Correctif : quand le nombre d'écoles MONTE, toute facture d'ASSIETTE
--  encore impayée (`pending` / `overdue`, notes « Assiette : … ») est
--  recalculée au prix courant. Les factures payées ne bougent jamais ; les
--  factures de régularisation (prorata) non plus — elles portent un montant
--  calculé pour une période déjà couverte, pas une assiette.
--
--  Le prorata du groupe ACTIF reste inchangé : il couvre la période en cours
--  (déjà payée), la facture recalculée couvre la suivante. Pas de recouvrement.
-- ════════════════════════════════════════════════════════════════════════════

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

  UPDATE school_groups SET billed_schools = v_now WHERE id = NEW.group_id;

  -- 0209 : l'assiette encore due suit le réseau réel.
  UPDATE group_invoices gi
     SET amount_xaf = group_price_xaf(NEW.group_id, gi.plan_id),
         notes      = 'Assiette : ' || v_now || ' ecole(s).',
         updated_at = now()
   WHERE gi.group_id = NEW.group_id
     AND gi.status IN ('pending'::invoice_status, 'overdue'::invoice_status)
     AND gi.notes LIKE 'Assiette :%'
     AND gi.amount_xaf < group_price_xaf(NEW.group_id, gi.plan_id);

  IF g.price_override_xaf IS NOT NULL THEN RETURN NULL; END IF;
  IF g.subscription_status <> 'active'::subscription_status OR g.subscription_end IS NULL
     OR g.subscription_end <= CURRENT_DATE THEN RETURN NULL; END IF;

  v_days  := g.subscription_end - CURRENT_DATE;
  v_delta := ROUND((plan_annualized_for(g.plan_id, v_now) - plan_annualized_for(g.plan_id, v_was))::numeric * v_days / 365.0);
  IF v_delta <= 0 THEN RETURN NULL; END IF;

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
