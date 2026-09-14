-- ════════════════════════════════════════════════════════════════════════════
--  0190 — LA FACTURE DU MOIS S'ÉMET TOUTE SEULE
--
--  ── CE QUI MANQUAIT (constaté le 2026-09-04 sur la base de production) ────
--  Les cinq plans clients sont MENSUELS. Or rien, dans toute la plateforme,
--  n'émettait la facture du mois suivant :
--
--    • les deux tâches de nuit se contentaient d'EXPIRER (`expire_subscriptions`)
--      et de RAPPELER (`emit_subscription_reminders`) ;
--    • `fn_auto_create_invoice` ne se déclenche qu'à la CRÉATION du groupe —
--      la toute première facture, jamais la deuxième ;
--    • `create_renewal_invoice` était branchée sur UN SEUL bouton, celui du
--      client, visible uniquement dans les 5 jours précédant l'échéance ;
--    • `backfill_missing_invoices` ne rattrape que les groupes qui n'ont
--      AUCUNE facture — un pansement de reprise, pas un cycle.
--
--  Autrement dit : le mois 1 était facturé, le mois 2 attendait que le client
--  pense à cliquer. Et le fondateur, lui, n'avait aucun moyen d'émettre quoi
--  que ce soit : son écran ne sait que marquer PAYÉE une facture existante.
--  À cinq clients cela se rattrape à la main ; à mille écoles, non.
--
--  ── CE QUE FAIT CETTE MIGRATION ───────────────────────────────────────────
--  1. Elle EXTRAIT le calcul d'une facture de renouvellement dans une fonction
--     interne, `_emettre_facture_renouvellement(groupe)`. Un seul endroit
--     calcule une période et un montant — la boucle de nuit et le bouton du
--     client appellent LE MÊME code. Deux implémentations du même contrat
--     divergent au premier champ ajouté.
--  2. `create_renewal_invoice` garde sa garde d'accès et délègue.
--  3. `emettre_factures_a_echoir()` parcourt chaque nuit les groupes NON
--     ministériels dont l'échéance tombe dans les `facturation_avance_jours`
--     (défaut 7) — échéance dépassée comprise, c'est le cas de rattrapage.
--  4. Un job pg_cron l'exécute à 01 h 20, APRÈS l'expiration de 01 h 05 : un
--     groupe qui vient de basculer reçoit sa facture dans la même nuit.
--
--  ── CE QUI REND LA BOUCLE SÛRE ────────────────────────────────────────────
--  • IDEMPOTENCE : tant qu'une facture `pending`/`overdue` existe pour le
--    groupe, on n'en crée pas d'autre. Repasser dix fois ne produit pas dix
--    factures. C'est CETTE règle qui autorise une tâche quotidienne.
--  • Un ministère est refusé net (sa licence se renégocie, elle ne se
--    renouvelle pas d'un clic — 0182/0183).
--  • Un plan à 0 F ne fabrique pas une facture à zéro : sa fenêtre est
--    prolongée. Un client gratuit ne doit pas se retrouver en lecture seule
--    pour une somme qui n'existe pas.
--  • La période part du PLUS TARD entre l'échéance courante et aujourd'hui :
--    ni mois offert, ni jours perdus.
--
--  ⚠️ EXPOSITION (leçon de 0189) : `emettre_factures_a_echoir` et la fonction
--  interne ÉCRIVENT. Elles sont donc révoquées de `anon` et `authenticated` —
--  `anon`, c'est la clé publique présente dans chaque installateur. Le cron
--  s'exécute sous `postgres`, propriétaire : il garde son droit. Le fondateur
--  passe, lui, par `create_renewal_invoice`, qui vérifie l'appelant.
--  `expire_subscriptions` est révoquée dans le même geste, pour la même
--  raison : elle écrivait et n'était protégée que par un `auth.uid() IS NULL`
--  — or un appel avec la clé publique a précisément un `auth.uid()` NUL.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── 1. Le cœur, appelé par les deux chemins ────────────────────────────────

CREATE OR REPLACE FUNCTION public._emettre_facture_renouvellement(
  p_group_id uuid,
  p_notifier boolean DEFAULT true
)
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

  -- Une licence de tutelle ne se renouvelle pas d'un clic : elle se renégocie.
  IF COALESCE(v_ministere, false) THEN
    RAISE EXCEPTION 'Un ministere de tutelle ne renouvelle pas un abonnement'
      USING ERRCODE = '23514',
            HINT = 'Votre accès repose sur une licence de tutelle, dont le '
                   'terme et le montant sont fixés par votre marché avec '
                   'E-PILOTE Congo. Contactez la plateforme pour un avenant.';
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

  -- Plan gratuit : on prolonge, on ne fabrique pas une facture à zéro franc.
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

  -- ⚠️ L'idempotence de toute la boucle nocturne tient à ces six lignes.
  SELECT * INTO v_existante FROM group_invoices
   WHERE group_id = p_group_id
     AND status IN ('pending'::invoice_status, 'overdue'::invoice_status)
   ORDER BY created_at DESC LIMIT 1;

  IF v_existante.id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'already_pending', true,
      'invoice_id', v_existante.id, 'invoice_number', v_existante.invoice_number,
      'amount_xaf', v_existante.amount_xaf,
      'period_start', v_existante.period_start,
      'period_end', v_existante.period_end);
  END IF;

  -- ⚠️ `group_invoices.created_by` est NOT NULL, et sous cron il n'y a PAS de
  -- JWT : `auth.uid()` vaut NULL. L'ancienne version n'avait jamais rencontré
  -- ce cas — elle n'était appelée que depuis un écran, donc toujours avec une
  -- session. Sans ce repli, la toute première nuit de facturation automatique
  -- aurait échoué sur CHAQUE groupe, silencieusement (le WHEN OTHERS de la
  -- boucle avale l'erreur pour ne pas priver les autres). Trouvé en répétition
  -- à blanc, avant la première vraie exécution.
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

  -- Le client doit apprendre qu'une somme est due sans avoir à ouvrir l'écran.
  --
  -- ⚠️ Deux détails qui ont l'air cosmétiques et ne le sont pas :
  --  • l'échéance citée est CELLE DU GROUPE (`v_cur_end`), pas le début de la
  --    période facturée. Sur un groupe déjà échu les deux diffèrent, et
  --    annoncer « arrive à échéance aujourd'hui » à quelqu'un dont
  --    l'abonnement a expiré il y a cinq semaines lui apprend le contraire de
  --    sa situation ;
  --  • le montant est formaté. « 52000 XAF » dans un message qu'on relit au
  --    téléphone se lit mal ; « 52 000 FCFA » est la forme employée partout
  --    ailleurs dans l'application.
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

COMMENT ON FUNCTION public._emettre_facture_renouvellement(uuid, boolean) IS
  '0190 — usage INTERNE. Seul endroit qui calcule une facture de '
  'renouvellement (période, assiette, montant). Appelée par '
  'create_renewal_invoice (client/fondateur) et emettre_factures_a_echoir '
  '(cron). N''écrit qu''après avoir vérifié qu''aucune facture n''est déjà en '
  'attente. Ne jamais l''exposer à anon ou authenticated : elle ne vérifie pas '
  'l''appelant.';

-- ─── 2. Le bouton : la garde d'accès, puis le même cœur ─────────────────────

CREATE OR REPLACE FUNCTION public.create_renewal_invoice(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non specifie';
  END IF;
  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = p_group_id)) THEN
    RAISE EXCEPTION 'Acces refuse';
  END IF;
  RETURN _emettre_facture_renouvellement(p_group_id);
END;
$function$;

COMMENT ON FUNCTION public.create_renewal_invoice(uuid) IS
  '0190 — garde d''accès (super_admin, ou l''admin du groupe lui-même) puis '
  'délègue à _emettre_facture_renouvellement. Le calcul ne vit plus ici.';

-- ─── 3. La boucle de nuit ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.emettre_factures_a_echoir(
  p_avance_jours integer DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_avance  integer;
  v_grp     record;
  v_res     jsonb;
  v_emises  integer := 0;
BEGIN
  -- Ceinture : la fonction est révoquée d'anon/authenticated (voir plus bas),
  -- mais si quelqu'un la ré-expose un jour, elle refusera quand même.
  IF auth.uid() IS NOT NULL AND NOT is_super_admin() THEN
    RAISE EXCEPTION 'Accès refusé';
  END IF;

  v_avance := COALESCE(
    p_avance_jours,
    (SELECT NULLIF(btrim(data->>'facturation_avance_jours'), '')::int
       FROM platform_settings WHERE id = 1),
    7);
  IF v_avance < 0 THEN v_avance := 7; END IF;

  FOR v_grp IN
    SELECT sg.id, sg.name
      FROM school_groups sg
     WHERE COALESCE(sg.administre_referentiel_national, false) = false
       AND sg.subscription_end IS NOT NULL
       AND sg.plan_id IS NOT NULL
       AND sg.subscription_status <> 'cancelled'::subscription_status
       -- Échéance déjà dépassée comprise : c'est le cas de rattrapage.
       AND sg.subscription_end - CURRENT_DATE <= v_avance
     ORDER BY sg.subscription_end
  LOOP
    BEGIN
      v_res := _emettre_facture_renouvellement(v_grp.id);
      IF COALESCE((v_res->>'already_pending')::boolean, false) = false
         AND COALESCE((v_res->>'free')::boolean, false) = false THEN
        v_emises := v_emises + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Un groupe mal configuré ne doit pas priver les autres de leur facture.
      RAISE WARNING 'Facturation impossible pour % (%) : %',
        v_grp.name, v_grp.id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE 'Facturation automatique : % facture(s) emise(s), avance % jour(s)',
    v_emises, v_avance;
  RETURN v_emises;
END;
$function$;

COMMENT ON FUNCTION public.emettre_factures_a_echoir(integer) IS
  '0190 — tâche de nuit (cron, sous postgres). Émet la facture de la période '
  'suivante pour chaque groupe non ministériel dont l''échéance tombe dans '
  'facturation_avance_jours (défaut 7), échéance dépassée comprise. '
  'Idempotente : aucune émission tant qu''une facture reste en attente. '
  'Ne pas exposer à anon/authenticated.';

-- ─── 4. Le réglage, visible par l'écran Paramètres ──────────────────────────

UPDATE platform_settings
   SET data = data || jsonb_build_object('facturation_avance_jours', '7')
 WHERE id = 1
   AND NOT (data ? 'facturation_avance_jours');

CREATE OR REPLACE FUNCTION public.get_subscription_settings()
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce(
    (select jsonb_build_object(
       'grace_days',    coalesce(nullif(btrim(data->>'grace_days'), '')::int, 15),
       'alert_days',    public.effective_alert_days(data),
       'reminder_days', coalesce(nullif(btrim(data->>'notif_reminder_days'), ''), '30,15,7,1,0'),
       'billing_lead_days',
                        coalesce(nullif(btrim(data->>'facturation_avance_jours'), '')::int, 7)
     )
     from platform_settings where id = 1),
    jsonb_build_object('grace_days', 15, 'alert_days', 5,
                       'reminder_days', '30,15,7,1,0', 'billing_lead_days', 7)
  );
$function$;

-- ─── 5. Exposition : ces fonctions écrivent, elles ne sont pas publiques ────

REVOKE EXECUTE ON FUNCTION public._emettre_facture_renouvellement(uuid, boolean)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.emettre_factures_a_echoir(integer)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.expire_subscriptions()
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.expire_subscriptions() IS
  '0190 — tâche de nuit (cron, sous postgres). Sa garde interne laissait '
  'passer un appelant sans JWT — or la clé publique anon a précisément un '
  'auth.uid() NUL. Révoquée d''anon/authenticated.';

-- ─── 6. Le job : 01 h 20, APRÈS l'expiration de 01 h 05 ─────────────────────

SELECT cron.unschedule('emettre-factures')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'emettre-factures');

SELECT cron.schedule('emettre-factures', '20 1 * * *',
                     'SELECT public.emettre_factures_a_echoir();');
