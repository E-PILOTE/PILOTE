-- ═══════════════════════════════════════════════════════════════════════════
--  LE GARDE-FOU DU POUVOIR EMPÊCHAIT DE CRÉER UN COMPTE
--
--  ── CE QUI EST ARRIVÉ ─────────────────────────────────────────────────────
--  La 0188 a posé `aa_profiles_garde_pouvoir` sur `profiles` : personne ne se
--  donne un rôle, un groupe, une école. C'était juste, et ça reste juste.
--
--  Mais depuis le 2026-09-04, PLUS AUCUN COMPTE NE POUVAIT ÊTRE CRÉÉ, sauf
--  par un super_admin. Silencieusement : le formulaire affichait « Utilisateur
--  créé avec succès », le compte s'authentifiait, et l'application le rejetait.
--
--  ── LE MÉCANISME, PAS À PAS ───────────────────────────────────────────────
--  `create_school_user` procède en deux temps :
--    1. `insert into auth.users` → le déclencheur `fn_handle_new_user` insère
--       le profil avec le seul contenu des métadonnées : prénom, nom, rôle.
--       **`group_id` et `school_id` y sont NULS** ;
--    2. `update profiles set group_id = …, school_id = …` — c'est cette
--       deuxième instruction qui rattache la personne.
--
--  Or le garde, sur cet UPDATE, évalue son bloc C :
--
--      IF v_admin_groupe AND OLD.group_id IS NOT DISTINCT FROM auth_group_id()
--
--  `OLD.group_id` vaut NULL (le profil vient d'être inséré vide).
--  `NULL IS NOT DISTINCT FROM '<uuid du groupe>'` vaut **FAUX**.
--  Le bloc C est donc sauté, et l'on tombe dans le bloc final :
--
--      NEW.group_id := OLD.group_id;          -- NULL
--      NEW.school_id := OLD.school_id;        -- NULL
--      NEW.access_profile_id := OLD.access_profile_id;  -- NULL
--
--  Le rattachement est annulé au moment même où il s'écrit. Prénom, nom et
--  téléphone passent (ils ne sont pas des colonnes de pouvoir) — d'où un profil
--  qui a l'air complet et n'appartient à rien.
--
--  ⚠️ LE MÊME DÉFAUT FRAPPE `creer_agent_ecole` : un chef d'établissement
--  n'est ni super_admin ni admin_groupe, il tombe directement dans le bloc
--  final. Les deux seules portes de provisionnement du produit étaient donc
--  fermées, et aucune des deux ne le disait.
--
--  ── POURQUOI PERSONNE NE L'A VU ───────────────────────────────────────────
--  Un déclencheur BEFORE qui réécrit `NEW` ne lève rien et ne journalise rien.
--  L'UPDATE « réussit » — il écrit simplement autre chose que ce qu'on lui a
--  demandé. C'est la même famille que les `catch (_) {}` : le silence d'un
--  refus le rend invisible, pas inoffensif.
--
--  ── LE CORRECTIF ──────────────────────────────────────────────────────────
--  Le garde existe pour empêcher un CLIENT d'écrire directement dans
--  `profiles` (PostgREST écrit sous le rôle `authenticated`). Il n'a jamais eu
--  pour objet d'entraver les fonctions d'approvisionnement, qui sont
--  `SECURITY DEFINER`, propriété de `postgres`, et qui portent DÉJÀ leurs
--  propres contrôles — plus stricts que ceux du déclencheur :
--
--    · `create_school_user` : super_admin ou admin_groupe, ET l'école doit
--      appartenir au groupe de l'appelant ;
--    · `creer_agent_ecole`  : direction d'établissement, rôle pris dans
--      `roles_provisionnables_par_ecole()`, quota vérifié ;
--    · `create_admin_user`  : super_admin seulement.
--
--  On distingue donc les deux mondes par `current_user` : `authenticated` /
--  `anon` = écriture directe du client, à garder ; tout le reste = code écrit
--  et audité, à laisser passer. C'est l'idiome PostgreSQL habituel.
--
--  ⚠️ LA RÈGLE B RESTE APPLIQUÉE À TOUT LE MONDE, y compris aux fonctions de
--  confiance : le rôle `super_admin` ne peut être attribué que par un
--  super_admin. C'était le cœur de la 0188 et il ne bouge pas d'un pouce.
--
--  ── CE QUE LE CORRECTIF OBLIGE À FERMER D'ABORD ───────────────────────────
--  `seed_account` était `SECURITY DEFINER`, **sans le moindre contrôle de
--  permission**, et EXÉCUTABLE PAR `authenticated`. Aujourd'hui le garde
--  masquait à moitié le problème en annulant ses écritures. Le laisser ouvert
--  après ce correctif donnerait à n'importe quel compte connecté le pouvoir de
--  créer un `admin_groupe` dans n'importe quel réseau. C'est un outil
--  d'amorçage : il n'a rien à faire dans la surface d'appel du client.
--
--  ── ⚠️ LE PIÈGE QUI M'A FAIT ÉCHOUER UNE PREMIÈRE FOIS ────────────────────
--  Premier jet : le garde restait `SECURITY DEFINER` et testait `current_user`.
--  **Cela désactivait le garde en entier.** Dans une fonction SECURITY DEFINER,
--  `current_user` vaut TOUJOURS le propriétaire — ici `postgres` — quel que
--  soit l'appelant. La condition était donc vraie à chaque écriture, y compris
--  celles du client.
--
--  Constaté en essayant de déplacer un admin de groupe vers un autre groupe
--  depuis un contexte `authenticated` : l'écriture est passée. Corrigé dans la
--  minute en repassant le déclencheur en `SECURITY INVOKER`, où `current_user`
--  désigne enfin celui qui écrit vraiment. Le garde n'a besoin d'aucun
--  privilège propre : les trois aides qui lisent `profiles`
--  (`is_super_admin`, `is_admin_groupe`, `auth_group_id`) sont elles-mêmes
--  SECURITY DEFINER.
--
--  ⚠️ Ne JAMAIS remettre ce déclencheur en SECURITY DEFINER sans retirer le
--  test `current_user` : les deux ensemble ouvrent la table en grand.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Fermer l'outil d'amorçage AVANT d'ouvrir la voie aux fonctions ───────
REVOKE EXECUTE ON FUNCTION public.seed_account(
  text, text, text, text, user_role, uuid, uuid, uuid,
  boolean, boolean, boolean, text) FROM PUBLIC, anon, authenticated;

-- ── 2. Le garde, qui cesse d'entraver le provisionnement ────────────────────
CREATE OR REPLACE FUNCTION public.profiles_garde_colonnes_de_pouvoir()
RETURNS trigger
LANGUAGE plpgsql
-- ⚠️ INVOKER, PAS DEFINER — voir l'en-tête. C'est ce qui rend `current_user`
-- capable de distinguer le client du code de confiance.
SECURITY INVOKER
SET search_path = public, pg_temp
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

  -- B. `super_admin` ne se donne pas — jamais une maladresse, donc on lève.
  --    ⚠️ VOLONTAIREMENT AVANT le laissez-passer ci-dessous : cette règle-là
  --    s'applique même au code de confiance. C'est l'invariant de la 0188.
  IF NEW.role = 'super_admin'::user_role
     AND (TG_OP = 'INSERT' OR OLD.role IS DISTINCT FROM 'super_admin'::user_role)
     AND NOT v_super THEN
    RAISE EXCEPTION
      'Refusé : le rôle super_admin ne peut être attribué que par un '
      'super_admin de la plateforme.'
      USING ERRCODE = '42501';
  END IF;

  -- ── Écriture directe du client, ou code de confiance ? ───────────────────
  --  PostgREST écrit sous `authenticated` (ou `anon`). Une fonction
  --  `SECURITY DEFINER` propriété de `postgres` écrit sous `postgres`.
  --  Le garde n'a de sens que pour la première : la seconde porte déjà ses
  --  propres contrôles, et c'est elle qui RATTACHE un profil à son groupe.
  --  Sans cette distinction, créer un compte était impossible (voir l'en-tête).
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- A. Personne ne se donne quoi que ce soit — y compris un super_admin.
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

  IF v_super THEN
    RETURN NEW;
  END IF;

  v_admin_groupe := public.is_admin_groupe();

  -- C. L'administrateur d'un groupe, sur les autres membres de son groupe.
  IF v_admin_groupe
     AND OLD.group_id IS NOT DISTINCT FROM public.auth_group_id() THEN
    NEW.group_id := OLD.group_id;
    IF NEW.role IS DISTINCT FROM OLD.role
       AND NOT (NEW.role = ANY (public.roles_administrables_par_groupe())) THEN
      NEW.role := OLD.role;
    END IF;
    RETURN NEW;
  END IF;

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

-- ── 3. Gardes de recette ───────────────────────────────────────────────────
DO $garde$
DECLARE v_ouvert boolean;
BEGIN
  SELECT has_function_privilege('authenticated',
           'public.seed_account(text,text,text,text,user_role,uuid,uuid,uuid,'
           'boolean,boolean,boolean,text)', 'EXECUTE')
    INTO v_ouvert;
  IF v_ouvert THEN
    RAISE EXCEPTION 'seed_account reste exécutable par le client.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'profiles_garde_colonnes_de_pouvoir'
       AND p.prosrc LIKE '%current_user NOT IN%'
  ) THEN
    RAISE EXCEPTION 'Le garde n''a pas été remplacé.';
  END IF;

  -- La règle B doit rester AVANT le laissez-passer, sinon une fonction de
  -- confiance pourrait fabriquer un super_admin.
  IF (SELECT position('super_admin ne peut être attribué' IN p.prosrc)
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname='public' AND p.proname='profiles_garde_colonnes_de_pouvoir')
     > (SELECT position('current_user NOT IN' IN p.prosrc)
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname='public' AND p.proname='profiles_garde_colonnes_de_pouvoir')
  THEN
    RAISE EXCEPTION 'La règle super_admin est passée APRÈS le laissez-passer.';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname='public'
                AND p.proname='profiles_garde_colonnes_de_pouvoir'
                AND p.prosecdef) THEN
    RAISE EXCEPTION 'Le garde est SECURITY DEFINER : le test current_user y '
                    'est toujours vrai, donc le garde ne garde plus rien.';
  END IF;

  RAISE NOTICE 'Garde corrigé, seed_account refermé.';
END;
$garde$;

COMMIT;
