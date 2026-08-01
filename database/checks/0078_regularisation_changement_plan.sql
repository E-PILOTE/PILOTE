-- ════════════════════════════════════════════════════════════════════════════
--  VÉRIFICATION DE LA MIGRATION 0078 — à rejouer après tout déploiement.
--
--  Ne modifie rien durablement : tout se passe dans une transaction close par
--  ROLLBACK. Peut donc tourner sur la production.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0078_regularisation_changement_plan.sql
--  Attendu : toutes les lignes ✅ et `echecs = 0`.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE t_res(nom text, attendu text, obtenu text);

\echo '════ A. tarif annualisé, comparable entre périodicités'
DO $$
DECLARE
  v_prem uuid;
  v_old  billing_period;
BEGIN
  SELECT id, billing_period INTO v_prem, v_old
    FROM subscription_plans WHERE slug = 'premium';

  UPDATE subscription_plans
     SET price_xaf = 120000, billing_period = 'annuel' WHERE id = v_prem;
  INSERT INTO t_res VALUES ('120 000 / an → annualisé',
      '120000', plan_annualized_xaf(v_prem)::text);

  UPDATE subscription_plans
     SET price_xaf = 10000, billing_period = 'mensuel' WHERE id = v_prem;
  INSERT INTO t_res VALUES ('10 000 / mois → annualisé',
      '120000', plan_annualized_xaf(v_prem)::text);

  UPDATE subscription_plans
     SET price_xaf = 30000, billing_period = 'trimestriel' WHERE id = v_prem;
  INSERT INTO t_res VALUES ('30 000 / trimestre → annualisé',
      '120000', plan_annualized_xaf(v_prem)::text);
END $$;

\echo '════ B. montée en gamme : facture complémentaire au prorata'
DO $$
DECLARE
  v_low   uuid;
  v_high  uuid;
  v_grp   uuid := gen_random_uuid();
  v_me    uuid;
  v_inv   uuid;
  v_end   date;
  v_days  integer;
  v_att   integer;
  v_got   integer;
  v_notes text;
  v_n     integer;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, true);

  -- Deux plans annuels aux tarifs connus.
  SELECT id INTO v_low  FROM subscription_plans WHERE slug = 'premium';
  SELECT id INTO v_high FROM subscription_plans WHERE slug = 'pro';
  UPDATE subscription_plans SET price_xaf = 120000, billing_period = 'annuel'
   WHERE id = v_low;
  UPDATE subscription_plans SET price_xaf = 360000, billing_period = 'annuel'
   WHERE id = v_high;

  -- Un groupe ACTIF sur le plan bas — activé par le chemin normal : la facture
  -- d'ouverture est encaissée, ce qui satisfait le verrou dur ADR-0009.
  INSERT INTO school_groups(id, name, slug, group_type, plan_id,
                            subscription_status, admin_email,
                            subscription_start)
  VALUES (v_grp, 'ZZ regul', 'zz-0078-regul', 'prive', v_low,
          'trial', 'zz0078@test.local', CURRENT_DATE);

  SELECT id INTO v_inv FROM group_invoices WHERE group_id = v_grp;
  PERFORM mark_invoice_paid(v_inv, 'especes');

  SELECT subscription_status, subscription_end INTO v_notes, v_end
    FROM school_groups WHERE id = v_grp;
  INSERT INTO t_res VALUES ('le groupe est bien actif avant la régularisation',
      'active', v_notes);

  DELETE FROM group_invoices WHERE group_id = v_grp;  -- on isole la régul

  UPDATE school_groups SET plan_id = v_high WHERE id = v_grp;

  v_days := v_end - CURRENT_DATE;
  v_att  := ROUND((360000 - 120000)::numeric * v_days / 365.0);
  SELECT amount_xaf, notes INTO v_got, v_notes
    FROM group_invoices WHERE group_id = v_grp;

  INSERT INTO t_res VALUES ('montée : montant au prorata',
      v_att::text, COALESCE(v_got::text, 'aucune facture'));
  INSERT INTO t_res VALUES ('montée : facture en attente, pas payée',
      'pending',
      (SELECT status::text FROM group_invoices WHERE group_id = v_grp));
  INSERT INTO t_res VALUES ('montée : période = aujourd''hui → échéance',
      CURRENT_DATE::text || '→' || v_end::text,
      (SELECT period_start::text || '→' || period_end::text
         FROM group_invoices WHERE group_id = v_grp));
  INSERT INTO t_res VALUES ('montée : la facture s''explique',
      'oui', CASE WHEN v_notes ILIKE '%Régularisation%' THEN 'oui' ELSE 'non' END);

  -- ── Descente : aucune facture, aucun avoir ──
  DELETE FROM group_invoices WHERE group_id = v_grp;
  UPDATE school_groups SET plan_id = v_low WHERE id = v_grp;
  SELECT count(*) INTO v_n FROM group_invoices WHERE group_id = v_grp;
  INSERT INTO t_res VALUES ('descente : aucune facture émise', '0', v_n::text);

  -- ── Groupe en essai : rien à régulariser ──
  UPDATE school_groups SET subscription_status = 'trial' WHERE id = v_grp;
  DELETE FROM group_invoices WHERE group_id = v_grp;
  UPDATE school_groups SET plan_id = v_high WHERE id = v_grp;
  SELECT count(*) INTO v_n FROM group_invoices WHERE group_id = v_grp;
  INSERT INTO t_res VALUES ('essai : pas de régularisation', '0', v_n::text);

  PERFORM set_config('request.jwt.claims', '', true);
END $$;

\echo '════ C. l''échéance d''un groupe ACTIF ne peut pas reculer'
DO $$
DECLARE
  v_plan uuid;
  v_grp  uuid := gen_random_uuid();
  v_me   uuid;
  v_inv  uuid;
  v_loin date;
  v_end  date;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, true);
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'premium';
  UPDATE subscription_plans SET price_xaf = 120000, billing_period = 'annuel'
   WHERE id = v_plan;

  -- Activation par le chemin normal : la facture d'ouverture (un an) est
  -- encaissée, le groupe devient actif jusqu'à son terme.
  INSERT INTO school_groups(id, name, slug, group_type, plan_id,
                            subscription_status, admin_email, subscription_start)
  VALUES (v_grp, 'ZZ recul', 'zz-0078-recul', 'prive', v_plan,
          'trial', 'zz0078b@test.local', CURRENT_DATE);
  SELECT id INTO v_inv FROM group_invoices WHERE group_id = v_grp;
  PERFORM mark_invoice_paid(v_inv, 'especes');
  SELECT subscription_end INTO v_loin FROM school_groups WHERE id = v_grp;

  -- Puis une facture COURTE — typiquement une régularisation. L'encaisser ne
  -- doit pas ramener le groupe en arrière.
  v_inv := gen_random_uuid();
  INSERT INTO group_invoices(id, group_id, invoice_number, amount_xaf,
                             period_start, period_end, plan_id, status, created_by)
  VALUES (v_inv, v_grp, generate_invoice_number(), 5000,
          CURRENT_DATE, CURRENT_DATE + 30, v_plan, 'pending', v_me);
  PERFORM mark_invoice_paid(v_inv, 'especes');

  SELECT subscription_end INTO v_end FROM school_groups WHERE id = v_grp;
  INSERT INTO t_res VALUES ('actif : échéance conservée après une facture courte',
      v_loin::text, v_end::text);

  PERFORM set_config('request.jwt.claims', '', true);
END $$;

\echo '════ D. un groupe PAS ENCORE actif prend la période qu''il a payée'
DO $$
DECLARE
  v_plan uuid;
  v_grp  uuid := gen_random_uuid();
  v_me   uuid;
  v_inv  uuid;
  v_end  date;
  v_stat text;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, true);
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'premium';

  -- Échéance d'essai posée LOIN devant, au-delà de tout reçu : prendre le
  -- maximum lui donnerait un terme qu'aucun paiement ne couvre, et le verrou
  -- dur refuserait alors l'activation — le groupe resterait bloqué APRÈS avoir
  -- payé. C'est exactement ce que ce test empêche de réintroduire.
  INSERT INTO school_groups(id, name, slug, group_type, plan_id,
                            subscription_status, admin_email,
                            subscription_start, subscription_end)
  VALUES (v_grp, 'ZZ essai', 'zz-0078-essai', 'prive', v_plan,
          'trial', 'zz0078c@test.local', CURRENT_DATE, CURRENT_DATE + 400);

  DELETE FROM group_invoices WHERE group_id = v_grp;
  v_inv := gen_random_uuid();
  INSERT INTO group_invoices(id, group_id, invoice_number, amount_xaf,
                             period_start, period_end, plan_id, status, created_by)
  VALUES (v_inv, v_grp, generate_invoice_number(), 5000,
          CURRENT_DATE, CURRENT_DATE + 30, v_plan, 'pending', v_me);

  PERFORM mark_invoice_paid(v_inv, 'especes');

  SELECT subscription_status::text, subscription_end INTO v_stat, v_end
    FROM school_groups WHERE id = v_grp;
  INSERT INTO t_res VALUES ('essai : le paiement active le groupe',
      'active', v_stat);
  INSERT INTO t_res VALUES ('essai : échéance = période payée',
      (CURRENT_DATE + 30)::text, v_end::text);

  PERFORM set_config('request.jwt.claims', '', true);
END $$;

\echo ''
SELECT CASE WHEN attendu = obtenu THEN '✅' ELSE '❌' END AS ok,
       nom AS "vérification", attendu, obtenu FROM t_res;

SELECT count(*) FILTER (WHERE attendu <> obtenu) AS echecs FROM t_res;

ROLLBACK;
