-- ════════════════════════════════════════════════════════════════════════════
--  VÉRIFICATION DE LA MIGRATION 0077 — à rejouer après tout déploiement.
--
--  Ce script ne modifie rien durablement : tout se passe dans une transaction
--  close par ROLLBACK. Il crée des groupes jetables pour observer les périodes
--  réellement posées sur les factures, puis rend la base à son état initial.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0077_periodicite_abonnement.sql
--  Attendu : toutes les lignes ✅ et `echecs = 0`.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE t_res(nom text, attendu text, obtenu text);

\echo '════ A. correspondance période → mois'
INSERT INTO t_res
SELECT 'billing_period_months(' || p || ')', a::text,
       billing_period_months(p::billing_period)::text
FROM (VALUES ('mensuel',1),('trimestriel',3),('semestriel',6),('annuel',12))
     AS v(p, a);

\echo '════ B. la facture d''ouverture couvre la période DU PLAN'
DO $$
DECLARE
  v_plan uuid;
  v_grp  uuid;
  v_days int;
  v_me   uuid;
  r      record;
BEGIN
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'premium';

  -- `group_invoices.created_by` est NOT NULL et se remplit avec `auth.uid()` :
  -- il faut donc un appelant identifié, même pour un test.
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, true);

  FOR r IN SELECT * FROM (VALUES
      ('mensuel', 28, 31), ('trimestriel', 89, 92),
      ('semestriel', 180, 184), ('annuel', 364, 366)) AS v(per, lo, hi)
  LOOP
    UPDATE subscription_plans
       SET billing_period = r.per::billing_period WHERE id = v_plan;

    v_grp := gen_random_uuid();
    INSERT INTO school_groups(id, name, slug, group_type, plan_id,
                              subscription_status, admin_email, subscription_start)
    VALUES (v_grp, 'ZZ ' || r.per, 'zz-0077-' || r.per, 'prive', v_plan,
            'trial', 'zz0077@test.local', CURRENT_DATE);

    SELECT (period_end - period_start) INTO v_days
      FROM group_invoices WHERE group_id = v_grp;

    INSERT INTO t_res VALUES (
      'facture ' || r.per || ' : durée plausible',
      'entre ' || r.lo || ' et ' || r.hi || ' j',
      CASE WHEN v_days BETWEEN r.lo AND r.hi
           THEN 'entre ' || r.lo || ' et ' || r.hi || ' j'
           ELSE v_days || ' j' END);
  END LOOP;
END $$;

\echo '════ C. le réabonnement suit la même règle'
DO $$
DECLARE
  v_plan uuid;
  v_grp  uuid;
  v_me   uuid;
  v_res  jsonb;
  v_days int;
BEGIN
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'premium';
  UPDATE subscription_plans
     SET billing_period = 'trimestriel' WHERE id = v_plan;

  -- create_renewal_invoice exige un appelant autorisé : on emprunte
  -- l'identité du super_admin existant.
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, true);

  v_grp := gen_random_uuid();
  INSERT INTO school_groups(id, name, slug, group_type, plan_id,
                            subscription_status, admin_email, subscription_end)
  VALUES (v_grp, 'ZZ renouv', 'zz-0077-renouv', 'prive', v_plan,
          'trial', 'zz0077r@test.local', CURRENT_DATE);

  -- La facture d'ouverture est déjà là (pending) : on la solde pour que le
  -- renouvellement en crée une nouvelle plutôt que de renvoyer l'existante.
  UPDATE group_invoices SET status = 'paid' WHERE group_id = v_grp;

  v_res := create_renewal_invoice(v_grp);
  v_days := ((v_res->>'period_end')::date - (v_res->>'period_start')::date);

  INSERT INTO t_res VALUES (
    'renouvellement trimestriel : ~3 mois',
    'entre 89 et 92 j',
    CASE WHEN v_days BETWEEN 89 AND 92 THEN 'entre 89 et 92 j'
         ELSE COALESCE(v_days::text, 'null') || ' j' END);

  PERFORM set_config('request.jwt.claims', '', true);
END $$;

\echo ''
SELECT CASE WHEN attendu = obtenu THEN '✅' ELSE '❌' END AS ok,
       nom AS "vérification", attendu, obtenu FROM t_res;

SELECT count(*) FILTER (WHERE attendu <> obtenu) AS echecs FROM t_res;

ROLLBACK;
