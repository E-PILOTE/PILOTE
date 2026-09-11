-- ════════════════════════════════════════════════════════════════════════════
--  0188 — NUL NE SE DONNE LE POUVOIR, ET NUL NE CHANGE DE TUTELLE
--
--  ── CE QUI A ÉTÉ MESURÉ (2026-09-04, base de production, en transaction
--     ANNULÉE) ─────────────────────────────────────────────────────────────
--  Deux escalades de privilège, ouvertes à chacun des huit comptes
--  `admin_groupe` — c'est-à-dire à l'administrateur de CHAQUE client, dont les
--  deux ministères :
--
--   1. SE FAIRE SUPER_ADMIN. Un simple
--          update profiles set role = 'super_admin' where id = <soi>
--      passait. Vérifié : `is_super_admin()` répondait `true` dans la foulée.
--      Le compte devenait administrateur de la PLATEFORME : les finances de
--      tous les groupes, les licences, la suppression d'un groupe entier.
--
--   2. CHANGER DE GROUPE. Un
--          update profiles set group_id = <un autre groupe> where id = <soi>
--      passait aussi. Vérifié : l'admin du METP se retrouvait admin du MEPSA —
--      un client devenu administrateur d'un autre client.
--
--  ── POURQUOI LES GARDES EXISTANTES NE SUFFISAIENT PAS ─────────────────────
--  Elles couvraient toutes le cas « quelqu'un touche à la ligne d'un AUTRE » :
--   • la politique RLS `profiles_update` autorise trois cas, dont
--     `id = auth.uid()` — sa propre ligne, sans restriction de colonne. Elle
--     n'a pas de `WITH CHECK`, donc PostgreSQL réutilise le `USING` sur la
--     ligne NOUVELLE : `id = auth.uid()` reste vrai quel que soit le rôle
--     écrit. La politique ne pouvait donc pas voir l'escalade ;
--   • le déclencheur `profiles_garde_colonnes_de_pouvoir` (BEFORE UPDATE) gèle
--     bien les colonnes de pouvoir… mais il RENDAIT LA MAIN, sans rien geler,
--     dès que l'auteur était `is_admin_groupe()` et que la ligne appartenait à
--     son groupe. Or sa propre ligne appartient à son groupe.
--
--  Les RPC, elles, étaient correctes : `create_admin_user` exige super_admin,
--  `create_school_user` REFUSE `super_admin` et `admin_groupe`,
--  `delete_admin_user` et `delete_school_group` exigent super_admin. Le trou
--  n'était pas dans les fonctions : il était sur la table, via PostgREST, que
--  n'importe quel client authentifié peut appeler directement.
--
--  ── LA RÈGLE POSÉE ICI ────────────────────────────────────────────────────
--   A. Personne ne modifie ses PROPRES colonnes de pouvoir — pas même un
--      super_admin. On ne se promeut pas, et on ne se rétrograde pas non plus :
--      avec UN SEUL super_admin en base, une rétrogradation accidentelle ferme
--      la plateforme à tout le monde, définitivement.
--   B. Écrire `super_admin` exige d'être déjà super_admin. Ce cas-là LÈVE une
--      exception au lieu de geler en silence : ce n'est jamais une maladresse.
--   C. Un `admin_groupe` n'attribue que les rôles que son écran propose (les
--      neuf rôles du personnel scolaire), et ne déplace personne hors de son
--      groupe. Il peut toujours corriger un profil existant sans en changer le
--      rôle — sinon éditer le téléphone d'un parent deviendrait impossible.
--
--  ⚠️ CE QUE CETTE MIGRATION NE CASSE PAS, vérifié dans le code Flutter :
--   • `admin_profile_provider.dart` (« Mon profil ») n'écrit que `first_name`,
--     `last_name`, `phone` — aucune colonne de pouvoir ;
--   • `admin_users_provider.dart` écrit `role`, `school_id`,
--     `access_profile_id` pour les AUTRES, et son sélecteur ne propose que
--     `kStaffRoles` — les neuf rôles autorisés ci-dessous ;
--   • aucun écran n'envoie jamais `group_id` sur `profiles`.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Le vocabulaire, déclaré une fois ────────────────────────────────────────
--  Les neuf rôles qu'un administrateur de groupe peut attribuer. C'est la
--  liste `kStaffRoles` de l'application, côté serveur : tant qu'elles ne
--  diffèrent pas, l'écran ne propose rien que la base refusera.
--
--  ⚠️ Composée à partir de `roles_provisionnables_par_ecole()` — ce qu'une
--  ÉCOLE peut créer — plus la direction, qu'un groupe seul nomme. Les deux
--  listes se ressemblent et ne sont pas la même : les écrire deux fois
--  entières, c'est les laisser diverger.
CREATE OR REPLACE FUNCTION public.roles_administrables_par_groupe()
RETURNS user_role[]
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public.roles_provisionnables_par_ecole()
         || ARRAY['directeur', 'proviseur']::user_role[];
$$;

COMMENT ON FUNCTION public.roles_administrables_par_groupe() IS
  'Les rôles qu''un admin_groupe peut attribuer (miroir serveur de kStaffRoles).';

-- ── La garde ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.profiles_garde_colonnes_de_pouvoir()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_moi          uuid := auth.uid();
  v_super        boolean;
  v_admin_groupe boolean;
BEGIN
  -- Pas de JWT : migration, tâche serveur, Edge Function. On n'entrave pas.
  IF v_moi IS NULL THEN
    RETURN NEW;
  END IF;

  v_super := public.is_super_admin();

  -- ══ B. `super_admin` ne se donne pas ══════════════════════════════════════
  -- Vaut à l'INSERT comme à l'UPDATE, et avant tout le reste : c'est la seule
  -- règle dont la violation n'est jamais une maladresse.
  IF NEW.role = 'super_admin'::user_role
     AND (TG_OP = 'INSERT' OR OLD.role IS DISTINCT FROM 'super_admin'::user_role)
     AND NOT v_super THEN
    RAISE EXCEPTION
      'Refusé : le rôle super_admin ne peut être attribué que par un '
      'super_admin de la plateforme.'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- ══ A. Personne ne se donne quoi que ce soit ══════════════════════════════
  -- Y COMPRIS un super_admin. Le nom, le téléphone, l'avatar restent libres :
  -- seules les colonnes qui DONNENT du pouvoir sont figées.
  IF NEW.id = v_moi THEN
    NEW.role              := OLD.role;
    NEW.access_profile_id := OLD.access_profile_id;
    NEW.school_id         := OLD.school_id;
    NEW.group_id          := OLD.group_id;
    NEW.is_active         := OLD.is_active;
    NEW.sync_finance      := OLD.sync_finance;
    NEW.sync_medical      := OLD.sync_medical;
    NEW.sync_discipline   := OLD.sync_discipline;
    RETURN NEW;
  END IF;

  -- Les administrateurs de la plateforme administrent.
  IF v_super THEN
    RETURN NEW;
  END IF;

  v_admin_groupe := public.is_admin_groupe();

  -- ══ C. L'administrateur d'un groupe, sur les autres membres du groupe ═════
  IF v_admin_groupe
     AND OLD.group_id IS NOT DISTINCT FROM public.auth_group_id() THEN
    -- Nul ne transfère un compte d'un client à un autre.
    NEW.group_id := OLD.group_id;
    -- Il attribue les rôles de son écran ; il peut aussi laisser en place un
    -- rôle qu'il n'aurait pas le droit d'attribuer (un parent, un élève, un
    -- autre admin de groupe) — sinon corriger un numéro de téléphone
    -- deviendrait impossible sur ces profils.
    IF NEW.role IS DISTINCT FROM OLD.role
       AND NOT (NEW.role = ANY (public.roles_administrables_par_groupe())) THEN
      NEW.role := OLD.role;
    END IF;
    RETURN NEW;
  END IF;

  -- Tout le reste : les colonnes qui donnent du pouvoir gardent leur valeur,
  -- quoi qu'on ait écrit.
  NEW.role              := OLD.role;
  NEW.access_profile_id := OLD.access_profile_id;
  NEW.school_id         := OLD.school_id;
  NEW.group_id          := OLD.group_id;
  NEW.is_active         := OLD.is_active;
  NEW.sync_finance      := OLD.sync_finance;
  NEW.sync_medical      := OLD.sync_medical;
  NEW.sync_discipline   := OLD.sync_discipline;
  RETURN NEW;
END;
$$;

-- Le déclencheur existant ne couvrait que UPDATE ; la règle B doit aussi
-- valoir à l'insertion. `aa_` garde le nom : les déclencheurs se déclenchent
-- par ordre alphabétique, et celui-ci doit passer en premier.
DROP TRIGGER IF EXISTS aa_profiles_garde_pouvoir ON public.profiles;
CREATE TRIGGER aa_profiles_garde_pouvoir
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_garde_colonnes_de_pouvoir();

COMMENT ON FUNCTION public.profiles_garde_colonnes_de_pouvoir() IS
  '0188 — nul ne modifie ses propres colonnes de pouvoir ; super_admin ne '
  's''attribue que par un super_admin ; un admin_groupe ne déplace personne '
  'hors de son groupe.';
