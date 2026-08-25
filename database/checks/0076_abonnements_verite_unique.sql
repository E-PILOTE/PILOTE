-- ════════════════════════════════════════════════════════════════════════════
--  VÉRIFICATION DE LA MIGRATION 0076 — à rejouer après tout déploiement.
--
--  Ce script n'est PAS une migration : il ne modifie rien durablement. Tout se
--  passe dans une transaction close par ROLLBACK. Il crée un groupe jetable,
--  onze comptes jetables, bouscule les liens de modules, et rend tout à l'état
--  initial. Il peut donc tourner sur la base de production.
--
--  Ce que le test de Flutter ne peut pas couvrir : les triggers et
--  `check_quota()` vivent en base. Le seul moyen honnête de savoir s'ils
--  refusent ce qu'ils doivent refuser, c'est de le leur demander.
--
--  Usage :
--    psql "$DATABASE_URL" -f database/checks/0076_abonnements_verite_unique.sql
--  Attendu : 10 lignes ✅ et `echecs = 0`.
-- ════════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP on
BEGIN;

\echo '════ A. module_count est dérivé de plan_modules'
CREATE TEMP TABLE t_res(nom text, attendu text, obtenu text);

DO $$
DECLARE
  v_plan uuid;
  v_mod  uuid;
  v_cnt  int;
BEGIN
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'gratuit';
  SELECT module_id INTO v_mod FROM plan_modules WHERE plan_id = v_plan LIMIT 1;

  DELETE FROM plan_modules WHERE plan_id = v_plan AND module_id = v_mod;
  SELECT module_count INTO v_cnt FROM subscription_plans WHERE id = v_plan;
  INSERT INTO t_res VALUES ('DELETE décrémente module_count', '6', v_cnt::text);

  INSERT INTO plan_modules(plan_id, module_id) VALUES (v_plan, v_mod);
  SELECT module_count INTO v_cnt FROM subscription_plans WHERE id = v_plan;
  INSERT INTO t_res VALUES ('INSERT réincrémente module_count', '7', v_cnt::text);

  -- Une saisie manuelle fantaisiste est écrasée dès que plan_modules bouge.
  UPDATE subscription_plans SET module_count = 999 WHERE id = v_plan;
  DELETE FROM plan_modules WHERE plan_id = v_plan AND module_id = v_mod;
  INSERT INTO plan_modules(plan_id, module_id) VALUES (v_plan, v_mod);
  SELECT module_count INTO v_cnt FROM subscription_plans WHERE id = v_plan;
  INSERT INTO t_res VALUES ('une valeur saisie à la main est corrigée', '7', v_cnt::text);
END $$;

\echo '════ B/C/D/E. quota de personnel sur profiles'
DO $$
DECLARE
  v_grp   uuid := gen_random_uuid();
  v_plan  uuid;
  v_actor uuid;
  v_id    uuid;
  v_ok    boolean;
  i       int;
BEGIN
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'gratuit';  -- max_staff = 10

  INSERT INTO school_groups(id, name, slug, group_type, plan_id, subscription_status, admin_email)
  VALUES (v_grp, 'ZZ Test Quota', 'zz-test-quota-0076', 'prive', v_plan, 'trial', 'zz0076@test.local');

  -- 10 agents rattachés (écriture d'administration : auth.uid() NULL ⇒ exemptée)
  FOR i IN 1..10 LOOP
    v_id := gen_random_uuid();
    INSERT INTO auth.users(id, instance_id, email, aud, role, created_at, updated_at)
    VALUES (v_id, '00000000-0000-0000-0000-000000000000',
            'zz0076_' || i || '@test.local', 'authenticated', 'authenticated', now(), now());
    UPDATE profiles SET group_id = v_grp, role = 'enseignant', is_active = true WHERE id = v_id;
    IF i = 1 THEN v_actor := v_id; END IF;
  END LOOP;

  SELECT check_quota(v_grp, 'staff') INTO v_ok;
  INSERT INTO t_res VALUES ('check_quota compte les profiles (10/10 ⇒ plein)', 'false', v_ok::text);

  -- On se fait passer pour un utilisateur authentifié non super_admin.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_actor)::text, true);

  -- D. Créer le compte ne consomme rien : le profil naît sans groupe.
  v_id := gen_random_uuid();
  INSERT INTO auth.users(id, instance_id, email, aud, role, created_at, updated_at)
  VALUES (v_id, '00000000-0000-0000-0000-000000000000',
          'zz0076_11@test.local', 'authenticated', 'authenticated', now(), now());
  INSERT INTO t_res VALUES ('un compte sans groupe passe malgré le quota plein', 'ok', 'ok');

  -- C. Le rattachement au groupe, lui, est refusé.
  BEGIN
    UPDATE profiles SET group_id = v_grp, role = 'enseignant' WHERE id = v_id;
    INSERT INTO t_res VALUES ('le 11e rattachement est refusé', 'refusé', 'ACCEPTÉ !');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO t_res VALUES ('le 11e rattachement est refusé', 'refusé', 'refusé');
  END;

  -- E. Un élève n'est pas du personnel.
  BEGIN
    UPDATE profiles SET role = 'eleve', group_id = v_grp WHERE id = v_id;
    INSERT INTO t_res VALUES ('un élève ne consomme pas de siège', 'accepté', 'accepté');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO t_res VALUES ('un élève ne consomme pas de siège', 'accepté', 'REFUSÉ !');
  END;

  PERFORM set_config('request.jwt.claims', '', true);
END $$;

\echo '════ F. -1 vaut illimité'
DO $$
DECLARE
  v_grp uuid;
  v_ok  boolean;
BEGIN
  SELECT id INTO v_grp FROM school_groups WHERE name ILIKE '%Enseignement Technique%' LIMIT 1;
  SELECT check_quota(v_grp, 'students') INTO v_ok;
  INSERT INTO t_res VALUES ('élèves illimités sur institutionnel', 'true', v_ok::text);
  SELECT check_quota(v_grp, 'staff') INTO v_ok;
  INSERT INTO t_res VALUES ('personnel illimité sur institutionnel', 'true', v_ok::text);
  SELECT check_quota(v_grp, 'schools') INTO v_ok;
  INSERT INTO t_res VALUES ('écoles illimitées sur institutionnel', 'true', v_ok::text);
END $$;

\echo ''
SELECT CASE WHEN attendu = obtenu THEN '✅' ELSE '❌' END AS ok,
       nom AS "vérification", attendu, obtenu FROM t_res;

SELECT count(*) FILTER (WHERE attendu <> obtenu) AS echecs FROM t_res;

ROLLBACK;
