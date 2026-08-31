-- ═══════════════════════════════════════════════════════════════════════════
--  0159 — LE PRIX SUIT LE NOMBRE D'ÉCOLES
--
--  ── LA FALAISE QU'ON SUPPRIME ────────────────────────────────────────────
--  Grille au 2026-08-31 : Pro 220 000/mois jusqu'à 10 écoles, puis
--  Institutionnel 2 500 000/mois. La 11ᵉ école coûtait ×11,4. Un groupe à
--  11 écoles n'avait que trois issues : refuser, partir, ou déclarer 10 écoles.
--  Les deux ministères étaient exactement dans ce trou.
--
--  ── LE MODÈLE ────────────────────────────────────────────────────────────
--  Le PLAN vend des MODULES. Le NOMBRE D'ÉCOLES fait le PRIX.
--    prix = base(plan) + Σ (écoles de la tranche × tarif de tranche)
--  Tranches : 2-5 · 6-10 · 11-20 · 21+. Dégressif, donc jamais de falaise,
--  et calculable de tête par le client — c'est un argument de vente, pas une
--  coquetterie : un prix qu'on ne peut pas vérifier soi-même ne se signe pas.
--
--  ⚠️ Les quotas d'écoles passent à ILLIMITÉ sur les plans payants. Bloquer
--  la croissance d'un client qui PAIE à l'école est absurde : le prix fait
--  déjà le travail. Seule « Découverte » (gratuite) reste bornée.
--
--  ── CE QUI RESTE VRAI ────────────────────────────────────────────────────
--  `is_public_plan = true` ⇒ AUCUN hard-lock (ADR-0009 : on ne coupe pas une
--  école publique pour impayé). C'est la raison d'être du plan Institutionnel.
--  ⚠️ Rien n'empêchait un groupe PRIVÉ d'être posé sur ce plan et d'échapper
--  ainsi au hard-lock sans que personne ne le voie. Un garde ferme ce trou.
--
--  ── COÛT RÉEL COUVERT (relevé 2026-08-31) ────────────────────────────────
--  Supabase Pro 25 $/mois · PowerSync Cloud Pro 49 $/mois (30 Go synchro et
--  1 000 clients simultanés inclus, puis 1 $/Go et 30 $/1 000 clients).
--  Plancher fixe ≈ 74 $/mois ≈ 48 500 XAF ⇒ DEUX groupes mono-école couvrent
--  l'infrastructure. Le coût marginal d'une école (~0,2 à 0,5 $/mois) est
--  sans commune mesure avec 30 000 XAF : le prix par école est sûr.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Les tranches, sur le plan ─────────────────────────────────────────
ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS extra_school_2_5_xaf   integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS extra_school_6_10_xaf  integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS extra_school_11_20_xaf integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS extra_school_21p_xaf   integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.subscription_plans.extra_school_2_5_xaf IS
  'Prix par école pour les écoles 2 a 5, dans la periodicite du plan.';

-- ── 2. Le groupe : tarif négocié + assiette facturée ─────────────────────
ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS price_override_xaf integer,
  ADD COLUMN IF NOT EXISTS billed_schools     integer;

COMMENT ON COLUMN public.school_groups.price_override_xaf IS
  'Tarif negocie qui REMPLACE la grille (NULL = grille). Sert au maintien de '
  'prix d''un client anterieur comme a un accord particulier. super_admin seul.';
COMMENT ON COLUMN public.school_groups.billed_schools IS
  'Nombre d''ecoles servant d''assiette a la derniere facture. Repond a la '
  'question que le client POSERA : « sur combien d''ecoles m''avez-vous facture ? »';

-- ── 3. Le calcul, source unique ──────────────────────────────────────────
-- ⚠️ Miroir Dart obligatoire : `lib/core/utils/tarif_ecoles.dart`. Toute
-- modification ici touche les deux, sinon l'écran annonce un prix que la
-- facture contredit.
CREATE OR REPLACE FUNCTION public.plan_price_xaf(p_plan_id uuid, p_schools integer)
RETURNS integer LANGUAGE sql STABLE SET search_path = public, pg_temp AS $fn$
  SELECT COALESCE((
    SELECT sp.price_xaf
         + GREATEST(LEAST(GREATEST(COALESCE(p_schools, 1), 1),  5) -  1, 0) * sp.extra_school_2_5_xaf
         + GREATEST(LEAST(GREATEST(COALESCE(p_schools, 1), 1), 10) -  5, 0) * sp.extra_school_6_10_xaf
         + GREATEST(LEAST(GREATEST(COALESCE(p_schools, 1), 1), 20) - 10, 0) * sp.extra_school_11_20_xaf
         + GREATEST(     GREATEST(COALESCE(p_schools, 1), 1)       - 20, 0) * sp.extra_school_21p_xaf
      FROM subscription_plans sp WHERE sp.id = p_plan_id), 0);
$fn$;

-- Écoles ACTIVES du groupe, plancher à 1 : un groupe sans école reste un
-- abonné (il vient d'être créé), il n'est pas gratuit.
CREATE OR REPLACE FUNCTION public.group_school_count(p_group_id uuid)
RETURNS integer LANGUAGE sql STABLE SET search_path = public, pg_temp AS $fn$
  SELECT GREATEST(
    (SELECT COUNT(*)::integer FROM schools
      WHERE group_id = p_group_id AND is_active = true), 1);
$fn$;

CREATE OR REPLACE FUNCTION public.group_price_xaf(p_group_id uuid, p_plan_id uuid DEFAULT NULL)
RETURNS integer LANGUAGE sql STABLE SET search_path = public, pg_temp AS $fn$
  SELECT COALESCE(
    (SELECT sg.price_override_xaf FROM school_groups sg WHERE sg.id = p_group_id),
    plan_price_xaf(
      COALESCE(p_plan_id, (SELECT sg.plan_id FROM school_groups sg WHERE sg.id = p_group_id)),
      group_school_count(p_group_id)),
    0);
$fn$;

CREATE OR REPLACE FUNCTION public.group_annualized_xaf(p_group_id uuid, p_plan_id uuid DEFAULT NULL)
RETURNS integer LANGUAGE sql STABLE SET search_path = public, pg_temp AS $fn$
  SELECT (group_price_xaf(p_group_id, p_plan_id)::numeric * 12
          / GREATEST(billing_period_months(
              (SELECT sp.billing_period FROM subscription_plans sp
                WHERE sp.id = COALESCE(p_plan_id,
                  (SELECT sg.plan_id FROM school_groups sg WHERE sg.id = p_group_id)))), 1)
         )::integer;
$fn$;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 2 — LA FACTURATION SUIT LE MÊME CALCUL
--
--  ⚠️ Trois fonctions lisaient `subscription_plans.price_xaf` EN DIRECT. Les
--  laisser ainsi aurait produit la pire des pannes : l'écran affiche le prix
--  par école, la facture porte la base seule, et personne ne s'en aperçoit
--  avant la première réclamation d'un client.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.plan_annualized_for(p_plan_id uuid, p_schools integer)
RETURNS integer LANGUAGE sql STABLE SET search_path = public, pg_temp AS $fn$
  SELECT (plan_price_xaf(p_plan_id, p_schools)::numeric * 12
          / GREATEST(billing_period_months(
              (SELECT sp.billing_period FROM subscription_plans sp WHERE sp.id = p_plan_id)), 1)
         )::integer;
$fn$;

-- ── Création d'un groupe : première facture au bon prix ──────────────────
CREATE OR REPLACE FUNCTION public.fn_auto_create_invoice()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE
  v_price      integer;
  v_months     integer;
  v_schools    integer;
  v_start      date;
  v_end        date;
  v_inv_number varchar;
BEGIN
  v_schools := group_school_count(NEW.id);
  v_price   := group_price_xaf(NEW.id, NEW.plan_id);

  SELECT billing_period_months(billing_period) INTO v_months
    FROM subscription_plans WHERE id = NEW.plan_id;

  v_start := COALESCE(NEW.subscription_start, CURRENT_DATE);
  v_end   := (v_start + make_interval(months => COALESCE(v_months, 12)))::date;

  -- L'assiette est posée dans TOUS les cas, gratuit compris : sans elle, la
  -- premiere ecole ajoutee ensuite serait facturee comme un ajout.
  UPDATE school_groups SET billed_schools = v_schools WHERE id = NEW.id;

  IF v_price IS NULL OR v_price = 0 THEN
    UPDATE school_groups SET
      subscription_status = 'active'::subscription_status,
      subscription_start  = v_start,
      subscription_end    = v_end
    WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  v_inv_number := generate_invoice_number();
  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by, notes
  ) VALUES (
    NEW.id, v_inv_number, v_price,
    v_start, v_end, NEW.plan_id,
    'pending'::invoice_status,
    COALESCE(NEW.created_by, auth.uid()),
    'Assiette : ' || v_schools || ' ecole(s).'
  );
  RETURN NEW;
END;
$fn$;

-- ── Renouvellement : recompte les écoles à l'échéance ────────────────────
CREATE OR REPLACE FUNCTION public.create_renewal_invoice(p_group_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE
  v_plan_id    uuid;
  v_price      integer;
  v_months     integer;
  v_schools    integer;
  v_cur_end    date;
  v_start      date;
  v_end        date;
  v_inv_number varchar;
  v_group_name text;
  v_existing   group_invoices%ROWTYPE;
BEGIN
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non specifie';
  END IF;

  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = p_group_id)) THEN
    RAISE EXCEPTION 'Acces refuse';
  END IF;

  SELECT plan_id, subscription_end, name
    INTO v_plan_id, v_cur_end, v_group_name
    FROM school_groups WHERE id = p_group_id;

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
    UPDATE school_groups SET
      subscription_status = 'active'::subscription_status,
      subscription_start  = COALESCE(subscription_start, CURRENT_DATE),
      subscription_end    = v_end,
      billed_schools      = v_schools,
      is_active           = true,
      updated_at          = NOW()
    WHERE id = p_group_id;
    RETURN jsonb_build_object('success', true, 'free', true,
                              'period_end', v_end, 'schools', v_schools);
  END IF;

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
    period_start, period_end, plan_id, status, created_by, notes
  ) VALUES (
    p_group_id, v_inv_number, v_price,
    v_start, v_end, v_plan_id,
    'pending'::invoice_status, auth.uid(),
    'Assiette : ' || v_schools || ' ecole(s).'
  );

  UPDATE school_groups SET billed_schools = v_schools WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_number', v_inv_number,
    'amount_xaf', v_price,
    'schools', v_schools,
    'period_start', v_start,
    'period_end', v_end,
    'group_name', v_group_name);
END;
$fn$;

-- ── Changement de plan : comparer à nombre d'écoles ÉGAL ─────────────────
CREATE OR REPLACE FUNCTION public.fn_regularize_plan_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE
  v_old_year integer; v_new_year integer; v_days integer; v_delta integer;
  v_inv varchar; v_old_name text; v_new_name text; v_actor uuid; v_schools integer;
BEGIN
  IF NEW.subscription_status <> 'active'::subscription_status
     OR NEW.subscription_end IS NULL
     OR NEW.subscription_end <= CURRENT_DATE THEN
    RETURN NULL;
  END IF;

  -- Un tarif negocie ne bouge pas parce que le plan change : c'est tout
  -- l'objet d'un tarif negocie.
  IF NEW.price_override_xaf IS NOT NULL THEN RETURN NULL; END IF;

  v_schools  := group_school_count(NEW.id);
  v_old_year := plan_annualized_for(OLD.plan_id, v_schools);
  v_new_year := plan_annualized_for(NEW.plan_id, v_schools);
  v_days     := NEW.subscription_end - CURRENT_DATE;

  SELECT name INTO v_old_name FROM subscription_plans WHERE id = OLD.plan_id;
  SELECT name INTO v_new_name FROM subscription_plans WHERE id = NEW.plan_id;
  v_actor := COALESCE(auth.uid(), NEW.created_by);

  IF v_new_year <= v_old_year THEN
    INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
    SELECT NEW.id, p.id, 'subscription',
           'Changement de plan - ' || COALESCE(v_new_name, '-'),
           'Votre abonnement passe au plan ' || COALESCE(v_new_name, '-')
             || '. La periode en cours reste reglee aux conditions precedentes ; '
             || 'le nouveau tarif s''appliquera a votre prochain renouvellement, le '
             || to_char(NEW.subscription_end, 'DD/MM/YYYY') || '.',
           false
      FROM profiles p
     WHERE p.group_id = NEW.id AND p.role = 'admin_groupe' AND p.is_active;
    RETURN NULL;
  END IF;

  v_delta := ROUND((v_new_year - v_old_year)::numeric * v_days / 365.0);
  IF v_delta <= 0 THEN RETURN NULL; END IF;

  v_inv := generate_invoice_number();
  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by, notes
  ) VALUES (
    NEW.id, v_inv, v_delta, CURRENT_DATE, NEW.subscription_end, NEW.plan_id,
    'pending'::invoice_status, v_actor,
    'Regularisation : passage du plan ' || COALESCE(v_old_name, '-')
      || ' au plan ' || COALESCE(v_new_name, '-')
      || ' le ' || to_char(CURRENT_DATE, 'DD/MM/YYYY')
      || ' - ' || v_days || ' jour(s) au prorata, ' || v_schools || ' ecole(s).'
  );

  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT NEW.id, p.id, 'subscription',
         'Facture de regularisation - ' || v_inv,
         'Votre abonnement passe au plan ' || COALESCE(v_new_name, '-')
           || '. Une facture complementaire de ' || v_delta
           || ' XAF couvre les ' || v_days || ' jour(s) restants jusqu''au '
           || to_char(NEW.subscription_end, 'DD/MM/YYYY') || '.',
         false
    FROM profiles p
   WHERE p.group_id = NEW.id AND p.role = 'admin_groupe' AND p.is_active;

  RETURN NULL;
END;
$fn$;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 3 — AJOUTER UNE ÉCOLE EN COURS DE PÉRIODE
--
--  Le prix suit le nombre d'écoles ; il faut donc décider ce qui se passe
--  quand une école arrive le lendemain d'une facture. Trois options :
--    (a) rien jusqu'au renouvellement  → une année entière non facturée ;
--    (b) refacturer tout               → le client paie deux fois la période ;
--    (c) PRORATA sur les jours restants → retenu.
--  C'est déjà ce que fait `fn_regularize_plan_change` pour un changement de
--  plan : même forme, même notification, aucune surprise pour l'utilisateur.
--
--  ⚠️ `billed_schools` est l'assiette de la DERNIÈRE facture, pas le compte
--  courant. C'est ce qui rend l'opération idempotente : trois écoles ajoutées
--  une par une facturent chacune leur delta, et jamais deux fois le même.
--
--  ⚠️ Retirer une école ne rembourse RIEN et ne baisse pas l'assiette en
--  cours — la période est payée. Le renouvellement recompte, lui.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_regularize_school_count()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE
  g          school_groups%ROWTYPE;
  v_now      integer;
  v_was      integer;
  v_days     integer;
  v_delta    integer;
  v_inv      varchar;
  v_plan     text;
BEGIN
  -- Écritures d'administration (seed, service_role, console SQL) : on ne
  -- facture pas un import. Sans ce garde, restaurer une base émettrait des
  -- dizaines de factures à des clients réels.
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  IF NEW.group_id IS NULL THEN RETURN NULL; END IF;

  SELECT * INTO g FROM school_groups WHERE id = NEW.group_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Tarif négocié : figé par construction.
  IF g.price_override_xaf IS NOT NULL THEN RETURN NULL; END IF;

  IF g.subscription_status <> 'active'::subscription_status
     OR g.subscription_end IS NULL
     OR g.subscription_end <= CURRENT_DATE THEN
    RETURN NULL;
  END IF;

  v_now := group_school_count(NEW.group_id);
  v_was := COALESCE(g.billed_schools, v_now);

  IF v_now <= v_was THEN RETURN NULL; END IF;

  v_days  := g.subscription_end - CURRENT_DATE;
  v_delta := ROUND(
    (plan_annualized_for(g.plan_id, v_now)
     - plan_annualized_for(g.plan_id, v_was))::numeric * v_days / 365.0);

  -- L'assiette monte même si le delta est nul (plan gratuit, tranche à 0) :
  -- sinon la MÊME école serait recomptée au prochain ajout.
  UPDATE school_groups SET billed_schools = v_now WHERE id = NEW.group_id;

  IF v_delta <= 0 THEN RETURN NULL; END IF;

  SELECT name INTO v_plan FROM subscription_plans WHERE id = g.plan_id;
  v_inv := generate_invoice_number();

  INSERT INTO group_invoices (
    group_id, invoice_number, amount_xaf,
    period_start, period_end, plan_id, status, created_by, notes
  ) VALUES (
    NEW.group_id, v_inv, v_delta, CURRENT_DATE, g.subscription_end, g.plan_id,
    'pending'::invoice_status, auth.uid(),
    'Regularisation : passage de ' || v_was || ' a ' || v_now || ' ecole(s) le '
      || to_char(CURRENT_DATE, 'DD/MM/YYYY') || ' - ' || v_days
      || ' jour(s) au prorata, plan ' || COALESCE(v_plan, '-') || '.'
  );

  INSERT INTO notifications (group_id, recipient_id, type, title, body, is_read)
  SELECT NEW.group_id, p.id, 'subscription',
         'Facture de regularisation - ' || v_inv,
         'Votre reseau passe de ' || v_was || ' a ' || v_now
           || ' ecole(s). Une facture complementaire de ' || v_delta
           || ' XAF couvre les ' || v_days || ' jour(s) restants jusqu''au '
           || to_char(g.subscription_end, 'DD/MM/YYYY') || '.',
         false
    FROM profiles p
   WHERE p.group_id = NEW.group_id AND p.role = 'admin_groupe' AND p.is_active;

  RETURN NULL;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_regularize_school_count ON public.schools;
CREATE TRIGGER trg_regularize_school_count
  AFTER INSERT OR UPDATE OF is_active, group_id ON public.schools
  FOR EACH ROW WHEN (NEW.is_active = true)
  EXECUTE FUNCTION public.fn_regularize_school_count();

-- ═══════════════════════════════════════════════════════════════════════════
--  LE TROU DU HARD-LOCK
--
--  `is_public_plan = true` ⇒ la licence est émise SANS `hard_lock` : l'école
--  n'est jamais coupée pour impayé (ADR-0009 — on ne ferme pas une école
--  publique). Mais « public » est une propriété du GROUPE (`group_type`),
--  pas du plan. Rien n'empêchait de poser un groupe PRIVÉ sur le plan
--  Institutionnel : il échappait alors au hard-lock, en silence, pour
--  toujours. Aucun écran ne l'aurait montré.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_plan_coherent_avec_secteur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE v_public boolean; v_plan text;
BEGIN
  SELECT is_public_plan, name INTO v_public, v_plan
    FROM subscription_plans WHERE id = NEW.plan_id;

  IF COALESCE(v_public, false) AND NEW.group_type = 'prive'::group_type THEN
    RAISE EXCEPTION
      'Le plan % est reserve au secteur public : un groupe prive qui y serait '
      'pose echapperait au hard-lock pour impaye. Choisir un plan prive, ou '
      'passer le groupe en group_type = public.', COALESCE(v_plan, '?')
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_plan_coherent_avec_secteur ON public.school_groups;
CREATE TRIGGER trg_plan_coherent_avec_secteur
  BEFORE INSERT OR UPDATE OF plan_id, group_type ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_plan_coherent_avec_secteur();

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 4 — LA GRILLE
--
--  Ancrage donné par l'utilisateur : 1 école = 30 000 XAF/mois, 2 écoles =
--  40 000. Tout le reste en découle par tranches dégressives.
--
--  ┌───────────────┬────────┬───────┬───────┬────────┬──────┐
--  │ plan          │ 1 ecole│  2-5  │  6-10 │ 11-20  │ 21+  │
--  ├───────────────┼────────┼───────┼───────┼────────┼──────┤
--  │ Decouverte    │      0 │   —   │   —   │   —    │  —   │  1 ecole, 100 eleves
--  │ Standard      │ 30 000 │10 000 │ 8 000 │  6 000 │4 000 │  17 modules
--  │ Pro           │ 50 000 │16 000 │13 000 │ 10 000 │7 000 │  30 modules
--  │ Institutionnel│ 40 000 │12 000 │10 000 │  8 000 │5 000 │  32 modules, SECTEUR PUBLIC
--  └───────────────┴────────┴───────┴───────┴────────┴──────┘
--
--  ⚠️ Institutionnel est MOINS cher que Pro par école, avec plus de modules.
--  Ce n'est pas une erreur : c'est le plan du SECTEUR PUBLIC — budget d'État,
--  volumes nationaux, et surtout aucun hard-lock. Le garde de la partie 3
--  interdit qu'un groupe privé s'y pose.
--
--  ⚠️ Les quotas d'écoles/élèves/personnel passent à -1 (illimité) sur les
--  plans payants. Un client qui paie À L'ÉCOLE ne doit jamais rencontrer un
--  mur : le prix est déjà la limite. Seule Découverte reste bornée — c'est
--  un essai, pas une offre.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

UPDATE public.subscription_plans SET
  name = 'Découverte', price_xaf = 0,
  extra_school_2_5_xaf = 0, extra_school_6_10_xaf = 0,
  extra_school_11_20_xaf = 0, extra_school_21p_xaf = 0,
  max_schools = 1, max_students = 100, max_staff = 10,
  description = 'Essai gratuit : 1 ecole, 100 eleves. Pour evaluer, pas pour exploiter.',
  updated_at = NOW()
WHERE slug = 'gratuit'::plan_slug;

UPDATE public.subscription_plans SET
  name = 'Standard', price_xaf = 30000,
  extra_school_2_5_xaf = 10000, extra_school_6_10_xaf = 8000,
  extra_school_11_20_xaf = 6000, extra_school_21p_xaf = 4000,
  max_schools = -1, max_students = -1, max_staff = -1,
  description = '30 000 XAF/mois pour 1 ecole, +10 000 par ecole ensuite (degressif). '
                'Le quotidien de l''etablissement.',
  updated_at = NOW()
WHERE slug = 'premium'::plan_slug;

UPDATE public.subscription_plans SET
  name = 'Pro', price_xaf = 50000,
  extra_school_2_5_xaf = 16000, extra_school_6_10_xaf = 13000,
  extra_school_11_20_xaf = 10000, extra_school_21p_xaf = 7000,
  max_schools = -1, max_students = -1, max_staff = -1,
  description = '50 000 XAF/mois pour 1 ecole, +16 000 par ecole ensuite (degressif). '
                'Tout le pilotage reseau.',
  updated_at = NOW()
WHERE slug = 'pro'::plan_slug;

UPDATE public.subscription_plans SET
  name = 'Institutionnel', price_xaf = 40000,
  extra_school_2_5_xaf = 12000, extra_school_6_10_xaf = 10000,
  extra_school_11_20_xaf = 8000, extra_school_21p_xaf = 5000,
  max_schools = -1, max_students = -1, max_staff = -1,
  is_public_plan = true,
  description = 'Secteur public : 40 000 XAF/mois pour 1 ecole, +12 000 ensuite '
                '(degressif). Jamais coupe pour impaye.',
  updated_at = NOW()
WHERE slug = 'institutionnel'::plan_slug;

-- Assiette de départ : ce que chaque groupe a AUJOURD'HUI. Sans cette ligne,
-- la première école ajoutée demain serait facturée comme un ajout alors que
-- le groupe n'a jamais été facturé sur la nouvelle grille.
UPDATE public.school_groups sg
   SET billed_schools = public.group_school_count(sg.id)
 WHERE sg.billed_schools IS NULL;

-- ── Le garde du garde ────────────────────────────────────────────────────
-- Une grille fausse ne lève aucune erreur : elle facture. On vérifie donc
-- les deux points d'ancrage AVANT de valider la transaction.
DO $verif$
DECLARE
  v_plan uuid;
  v1 integer; v2 integer; v5 integer; v10 integer; v21 integer;
BEGIN
  SELECT id INTO v_plan FROM subscription_plans WHERE slug = 'premium'::plan_slug;

  v1  := plan_price_xaf(v_plan, 1);
  v2  := plan_price_xaf(v_plan, 2);
  v5  := plan_price_xaf(v_plan, 5);
  v10 := plan_price_xaf(v_plan, 10);
  v21 := plan_price_xaf(v_plan, 21);

  IF v1 <> 30000 OR v2 <> 40000 THEN
    RAISE EXCEPTION 'Ancrage rompu : 1 ecole = % (attendu 30000), 2 ecoles = % (attendu 40000)', v1, v2;
  END IF;
  IF v5 <> 70000 OR v10 <> 110000 OR v21 <> 174000 THEN
    RAISE EXCEPTION 'Tranches fausses : 5=% (70000), 10=% (110000), 21=% (174000)', v5, v10, v21;
  END IF;
  -- Une borne à 0 école ne doit jamais rendre moins que le tarif d'une école.
  IF plan_price_xaf(v_plan, 0) <> 30000 OR plan_price_xaf(v_plan, NULL) <> 30000 THEN
    RAISE EXCEPTION 'Le plancher a 1 ecole ne tient pas';
  END IF;
  RAISE NOTICE 'Grille verifiee : 1=% 2=% 5=% 10=% 21=%', v1, v2, v5, v10, v21;
END;
$verif$;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 5 — LE QUATRIÈME LECTEUR DE `price_xaf`
--
--  `backfill_missing_invoices()` rattrape les groupes sans aucune facture.
--  Il lisait lui aussi la base du plan en direct : un groupe de 8 écoles
--  rattrapé aurait reçu une facture au tarif d'UNE école, marquée « payée »
--  si le groupe était actif. Une erreur de facturation qui se solde toute
--  seule et ne laisse aucune trace d'anomalie.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.backfill_missing_invoices()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE
  v_rec RECORD; v_count integer := 0; v_price integer; v_schools integer;
  v_inv varchar; v_status invoice_status; v_admin_id uuid;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Acces refuse : reserve au super administrateur';
  END IF;

  SELECT id INTO v_admin_id FROM profiles WHERE role = 'super_admin' LIMIT 1;

  FOR v_rec IN
    SELECT sg.id, sg.plan_id, sg.subscription_status,
           sg.subscription_start, sg.subscription_end, sg.created_by
    FROM school_groups sg
    WHERE NOT EXISTS (SELECT 1 FROM group_invoices gi WHERE gi.group_id = sg.id)
  LOOP
    v_schools := group_school_count(v_rec.id);
    v_price   := group_price_xaf(v_rec.id, v_rec.plan_id);

    IF v_price IS NULL OR v_price = 0 THEN
      UPDATE school_groups SET subscription_status = 'active', billed_schools = v_schools
       WHERE id = v_rec.id;
    ELSE
      v_inv := generate_invoice_number();
      IF v_rec.subscription_status::text = 'active' THEN
        v_status := 'paid'::invoice_status;
      ELSE
        v_status := 'pending'::invoice_status;
      END IF;

      INSERT INTO group_invoices (
        group_id, invoice_number, amount_xaf,
        period_start, period_end, plan_id, status,
        paid_at, payment_method, receipt_number, created_by, notes
      ) VALUES (
        v_rec.id, v_inv, v_price,
        COALESCE(v_rec.subscription_start, CURRENT_DATE),
        COALESCE(v_rec.subscription_end, CURRENT_DATE + INTERVAL '1 year'),
        v_rec.plan_id, v_status,
        CASE WHEN v_status = 'paid'::invoice_status THEN NOW() ELSE NULL END,
        CASE WHEN v_status = 'paid'::invoice_status THEN 'especes'::payment_method ELSE NULL END,
        CASE WHEN v_status = 'paid'::invoice_status THEN 'REC-' || substring(v_inv from 5) ELSE NULL END,
        COALESCE(v_rec.created_by, v_admin_id),
        'Rattrapage - assiette : ' || v_schools || ' ecole(s).'
      );
      UPDATE school_groups SET billed_schools = v_schools WHERE id = v_rec.id;
    END IF;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$fn$;

COMMIT;
