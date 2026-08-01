-- ════════════════════════════════════════════════════════════════════════════
--  0076 — ABONNEMENTS : UNE SEULE VÉRITÉ, ET QU'ELLE CIRCULE
--
--  ── LE SYMPTÔME ────────────────────────────────────────────────────────────
--  Le 2026-08-01 le prix du plan `institutionnel` est passé à 2 500 000 FCFA.
--  L'écriture a réussi. Et absolument rien n'a bougé ailleurs dans l'app : le
--  revenu récurrent du tableau de bord, la fiche d'abonnement de l'admin de
--  groupe, les cartes de groupes — tout continuait d'afficher l'ancien montant
--  jusqu'au redémarrage de l'application.
--
--  Trois causes empilées, dont deux vivent ici :
--
--  1. `subscription_plans` n'appartenait PAS à la publication
--     `supabase_realtime` (seulement à `powersync`), et sa réplication était
--     en identité par défaut. Or quatre abonnements `postgres_changes`
--     l'écoutent depuis toujours dans `plans_provider.dart` et
--     `modules_provider.dart` : ils se souscrivaient à une table muette. Un
--     canal Realtime sur une table hors publication ne lève aucune erreur — il
--     se tait, ce qui est la pire des façons d'échouer.
--
--  2. `module_count` était une colonne SAISIE en plus des lignes réelles de
--     `plan_modules`. Deux écritures pour un seul fait : elles avaient déjà
--     divergé (plan `pro` = 26 annoncés, 28 réels). La carte mentait au client.
--
--  Le troisième maillon (les providers Riverpod `keepAlive` qui n'écoutaient
--  que `school_groups`) se corrige côté Dart, dans le même commit.
--
--  ── ET UN QUOTA QUI N'EN ÉTAIT PAS UN ──────────────────────────────────────
--  `check_quota(group, 'staff')` comptait `staff_members` : 0 ligne, table que
--  l'application n'écrit jamais. Le personnel vit dans `profiles`. Donc la
--  limite `max_staff` ne bloquait rien, et la jauge « Personnel » de l'écran
--  Abonnement affichait perpétuellement 0 / 200. Une limite décorative est pire
--  qu'une limite absente : elle donne au client l'illusion d'être encadré.
--
--  ⚠️ POURQUOI LE TRIGGER PORTE AUSSI SUR `UPDATE OF group_id` — c'est le point
--  qui décide de tout. `create_school_user` insère dans `auth.users` ; le
--  trigger `trg_on_auth_user_created` crée alors un profil AVEC `group_id`
--  NULL ; la RPC fait ENSUITE un UPDATE qui pose `group_id`. Un trigger BEFORE
--  INSERT seul n'aurait jamais rien vu passer : le siège n'est pas consommé à
--  la création du compte, mais au moment où il est rattaché au groupe.
--
--  ── COHÉRENCE DU PLAN INSTITUTIONNEL ───────────────────────────────────────
--  Écoles illimitées, mais 50 000 élèves : le MEPSA vise plus de 1000 écoles ;
--  à 300 élèves par école le mur tombe à la 167ᵉ. Promettre l'illimité en
--  écoles tout en plafonnant les élèves, c'est promettre ce qu'on ne peut pas
--  tenir. Les deux plafonds passent à -1.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
--  1. LA PUBLICATION REALTIME — ET LA REPLICA IDENTITY QUI VA AVEC
--
--  Idempotent : `ALTER PUBLICATION ... ADD TABLE` échoue si la table y est
--  déjà, et cette migration doit pouvoir se rejouer.
--
--  Les trois tables sont lisibles par tous (`USING true`), donc l'autorisation
--  Realtime passe sans policy supplémentaire.
--
--  ⚠️ `REPLICA IDENTITY FULL` N'EST PAS UN DÉTAIL — vérifié à l'écran le
--  2026-08-01. Avec la publication seule et la réplication par défaut (clé
--  primaire), un UPDATE de `subscription_plans` n'a produit AUCUN évènement :
--  le tableau de bord est resté à 10,5 M. La table posée en `FULL`, le même
--  UPDATE a fait passer le revenu à 11,2 M en deux secondes, sans toucher à
--  l'application. La différence se lisait déjà en base : `school_groups`, la
--  seule table dont le temps réel fonctionnait, était en `FULL` (`relreplident
--  = 'f'`) là où les autres étaient en `'d'`.
--
--  Coût : chaque UPDATE écrit l'ancienne ligne entière dans le WAL. Sur quatre
--  lignes de tarifs modifiées quelques fois par an, c'est nul. Ne pas
--  généraliser à une table de flux (notes, présences, paiements).
-- ────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['subscription_plans', 'plan_modules', 'modules'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
    EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
  END LOOP;
END $$;

-- ────────────────────────────────────────────────────────────────────────────
--  2. `module_count` DEVIENT DÉRIVÉ
--
--  On garde la colonne : huit endroits la lisent dans un `select` de
--  `subscription_plans`, et une vue obligerait à toucher chacun d'eux. Mais
--  elle change de statut — de valeur saisie à cache maintenu, avec un écrivain
--  unique : ce trigger. Le formulaire des plans cesse de l'envoyer.
--
--  Le défaut passe de 8 à 0 : un plan neuf n'a aucun module tant qu'on ne lui
--  en a pas lié, et « 8 » était un chiffre inventé.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_sync_plan_module_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_plan uuid := COALESCE(NEW.plan_id, OLD.plan_id);
BEGIN
  UPDATE subscription_plans p
     SET module_count = (SELECT count(*) FROM plan_modules pm WHERE pm.plan_id = p.id)
   WHERE p.id = v_plan;

  -- Un UPDATE qui déplace un lien d'un plan à l'autre touche DEUX plans.
  IF TG_OP = 'UPDATE' AND NEW.plan_id IS DISTINCT FROM OLD.plan_id THEN
    UPDATE subscription_plans p
       SET module_count = (SELECT count(*) FROM plan_modules pm WHERE pm.plan_id = p.id)
     WHERE p.id = OLD.plan_id;
  END IF;

  RETURN NULL;  -- AFTER trigger : la valeur de retour est ignorée.
END;
$$;

DROP TRIGGER IF EXISTS trg_plan_modules_count ON public.plan_modules;
CREATE TRIGGER trg_plan_modules_count
  AFTER INSERT OR UPDATE OR DELETE ON public.plan_modules
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_plan_module_count();

ALTER TABLE public.subscription_plans ALTER COLUMN module_count SET DEFAULT 0;

-- Rattrapage de la dérive existante.
UPDATE subscription_plans p
   SET module_count = (SELECT count(*) FROM plan_modules pm WHERE pm.plan_id = p.id)
 WHERE p.module_count IS DISTINCT FROM
       (SELECT count(*) FROM plan_modules pm WHERE pm.plan_id = p.id);

-- ────────────────────────────────────────────────────────────────────────────
--  3. LE QUOTA DE PERSONNEL COMPTE LE PERSONNEL RÉEL
--
--  Périmètre du compte : tout compte ACTIF rattaché au groupe, sauf
--    • `super_admin` — opérateur de la plateforme, il n'appartient à aucun
--      groupe et ne consomme aucun siège client ;
--    • `parent` et `eleve` — ce sont des familles, pas du personnel. Les
--      compter ferait exploser le quota d'un collège de 600 élèves dès le
--      premier parent inscrit.
--  `admin_groupe` EST compté : c'est un compte du groupe, et l'exclure
--  ouvrirait un siège gratuit illimité par simple choix de rôle.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.check_quota(p_group_id uuid, p_quota_type character varying)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_max     INTEGER;
  v_current INTEGER;
BEGIN
  SELECT CASE p_quota_type
           WHEN 'schools'  THEN sp.max_schools
           WHEN 'students' THEN sp.max_students
           WHEN 'staff'    THEN sp.max_staff
         END
  INTO v_max
  FROM school_groups sg
  JOIN subscription_plans sp ON sp.id = sg.plan_id
  WHERE sg.id = p_group_id;

  -- Pas de plan/limite, ou -1 → illimité
  IF v_max IS NULL OR v_max = -1 THEN
    RETURN TRUE;
  END IF;

  CASE p_quota_type
    WHEN 'schools' THEN
      SELECT COUNT(*) INTO v_current FROM schools
      WHERE group_id = p_group_id AND is_active = TRUE;
    WHEN 'students' THEN
      SELECT COUNT(*) INTO v_current FROM students
      WHERE group_id = p_group_id AND is_active = TRUE;
    WHEN 'staff' THEN
      -- `staff_members` était la mauvaise table : l'app n'y écrit jamais.
      SELECT COUNT(*) INTO v_current FROM profiles
      WHERE group_id = p_group_id
        AND is_active = TRUE
        AND role NOT IN ('super_admin', 'parent', 'eleve');
  END CASE;

  RETURN COALESCE(v_current, 0) < v_max;
END;
$$;

-- Le trigger sur `staff_members` n'a plus de sens : il compterait `profiles` à
-- l'occasion d'une écriture dans une table que personne n'utilise.
DROP TRIGGER IF EXISTS trg_enforce_staff_quota ON public.staff_members;

CREATE OR REPLACE FUNCTION public.fn_enforce_staff_quota()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_max INTEGER;
BEGIN
  -- Le siège se consomme au RATTACHEMENT au groupe, pas à la création du
  -- compte : `fn_handle_new_user` crée le profil sans `group_id`.
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.group_id IS NOT DISTINCT FROM OLD.group_id THEN
    RETURN NEW;
  END IF;

  -- Ni les familles ni l'opérateur ne consomment de siège.
  IF NEW.role IN ('super_admin', 'parent', 'eleve') THEN
    RETURN NEW;
  END IF;

  -- Compte inactif : il ne prend pas de place tant qu'il n'est pas réactivé.
  IF NEW.is_active IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- L'opérateur de la plateforme n'est pas soumis au quota qu'il vend.
  -- `auth.uid()` NULL = écriture service_role / console SQL / migration : ce
  -- sont des chemins d'administration, jamais l'application cliente (la clé
  -- anon sans session ne franchit pas la RLS de `profiles`).
  IF is_super_admin() OR auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT check_quota(NEW.group_id, 'staff') THEN
    SELECT sp.max_staff INTO v_max
      FROM school_groups sg JOIN subscription_plans sp ON sp.id = sg.plan_id
     WHERE sg.id = NEW.group_id;
    RAISE EXCEPTION
      'Quota de personnel atteint : le plan de ce groupe autorise % comptes.', v_max
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_staff_quota_profiles ON public.profiles;
CREATE TRIGGER trg_enforce_staff_quota_profiles
  BEFORE INSERT OR UPDATE OF group_id ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_staff_quota();

-- ────────────────────────────────────────────────────────────────────────────
--  4. LE PLAN INSTITUTIONNEL TIENT SA PROMESSE
-- ────────────────────────────────────────────────────────────────────────────

UPDATE subscription_plans
   SET max_students = -1,
       max_staff    = -1,
       updated_at   = NOW()
 WHERE slug = 'institutionnel'
   AND (max_students <> -1 OR max_staff <> -1);

COMMIT;
