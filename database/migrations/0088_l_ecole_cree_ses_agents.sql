-- ════════════════════════════════════════════════════════════════════════════
--  0088 — L'ÉTABLISSEMENT PROVISIONNE SON PROPRE PERSONNEL
--
--  ── LE BLOCAGE D'ÉCHELLE ───────────────────────────────────────────────────
--  `create_school_user` exige `is_admin_groupe()`. Mille établissements, une
--  vingtaine d'agents chacun : vingt mille comptes à créer par un seul
--  guichet, qui ne connaît ni les noms, ni les fonctions, ni les arrivées de
--  septembre. Le déploiement par vagues ne passe pas ce goulot.
--
--  Le chef d'établissement, lui, sait qui travaille chez lui. C'est à lui de
--  provisionner — dans son périmètre, et seulement là.
--
--  ── LES QUATRE GARDE-FOUS, ET POURQUOI CHACUN ──────────────────────────────
--  1. L'ÉCOLE N'EST PAS UN PARAMÈTRE. La fonction ne prend pas de `school_id` :
--     elle écrit celui de l'appelant. On ne peut pas se tromper d'école, ni
--     placer un agent ailleurs « par erreur ».
--
--  2. UN CHEF NE CRÉE PAS UN CHEF. Ni `super_admin`, ni `admin_groupe`, ni
--     `directeur`, ni `proviseur`. Sans cette règle, tout compte de direction
--     pourrait s'en fabriquer un second, hors de portée de sa hiérarchie —
--     c'est le chemin d'élévation de privilèges classique. Nommer un chef
--     d'établissement reste un acte de l'autorité de tutelle.
--
--  3. LE PROFIL D'ACCÈS EST OBLIGATOIRE. Un agent créé sans profil se connecte
--     sur une application VIDE : aucune entrée de menu, rien à faire. Le
--     symptôme est déjà connu du projet, et sur mille écoles il produirait mille
--     appels au support le même matin.
--
--  4. LE QUOTA D'ABONNEMENT S'APPLIQUE. Le contourner ici viderait de son sens
--     le plan souscrit par le groupe.
--
--  Chaque création est journalisée : qui a créé quel compte, dans quelle école.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Qui dirige un établissement ─────────────────────────────────────────────
-- Volontairement plus étroit que « personnel scolaire » : un surveillant ou un
-- comptable n'a pas à ouvrir des comptes.
CREATE OR REPLACE FUNCTION est_chef_etablissement()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
     WHERE id = auth.uid()
       AND is_active
       AND school_id IS NOT NULL
       AND role IN ('directeur', 'proviseur')
  );
$$;

COMMENT ON FUNCTION est_chef_etablissement() IS
  'Direction d''un établissement — plus étroit que _isStaffRole. Seul ce rôle '
  'peut provisionner du personnel dans son école.';

-- ── Les fonctions qu'un chef d'établissement peut ouvrir ────────────────────
CREATE OR REPLACE FUNCTION roles_provisionnables_par_ecole()
RETURNS user_role[]
LANGUAGE sql IMMUTABLE
AS $$
  SELECT ARRAY['enseignant', 'cpe', 'comptable', 'secretaire', 'surveillant',
               'infirmier', 'responsable_cantine']::user_role[];
$$;

COMMENT ON FUNCTION roles_provisionnables_par_ecole() IS
  '⚠️ Ni directeur ni proviseur : un chef d''établissement ne se fabrique pas '
  'un pair hors de portée de sa hiérarchie. Tenu identique à '
  'kRolesProvisionnablesParEcole (Dart).';

-- ── Créer un agent ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION creer_agent_ecole(
  p_email             text,
  p_password          text,
  p_first_name        text,
  p_last_name         text,
  p_role              user_role,
  p_access_profile_id uuid,
  p_phone             text DEFAULT NULL,
  p_employee_number   text DEFAULT NULL,
  p_gender            text DEFAULT NULL,
  p_date_of_birth     date DEFAULT NULL,
  p_birth_place       text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $$
DECLARE
  v_moi      profiles%ROWTYPE;
  v_nouveau  uuid;
BEGIN
  IF NOT est_chef_etablissement() THEN
    RAISE EXCEPTION 'Seule la direction de l''établissement peut créer un compte.';
  END IF;

  SELECT * INTO v_moi FROM profiles WHERE id = auth.uid();

  -- 2. Un chef ne crée pas un chef. Voir l'en-tête.
  IF NOT (p_role = ANY (roles_provisionnables_par_ecole())) THEN
    RAISE EXCEPTION
      'La fonction « % » ne peut être attribuée que par l''administration du groupe.',
      p_role;
  END IF;

  -- 3. Sans profil d'accès, l'agent se connecte sur une application vide.
  IF p_access_profile_id IS NULL THEN
    RAISE EXCEPTION 'Un profil d''accès est obligatoire : sans lui, l''agent '
                    'ouvrirait une application sans aucun module.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM access_profiles
                  WHERE id = p_access_profile_id
                    AND group_id = v_moi.group_id
                    AND is_active) THEN
    RAISE EXCEPTION 'Profil d''accès inconnu dans votre réseau.';
  END IF;

  -- 4. Le plan souscrit fait loi.
  IF NOT check_quota(v_moi.group_id, 'staff') THEN
    RAISE EXCEPTION 'Le nombre d''agents autorisé par votre abonnement est '
                    'atteint. Rapprochez-vous de l''administration du réseau.';
  END IF;

  IF p_email IS NULL OR position('@' IN p_email) = 0 THEN
    RAISE EXCEPTION 'Adresse électronique invalide.';
  END IF;
  IF length(coalesce(p_password, '')) < 8 THEN
    RAISE EXCEPTION 'Le mot de passe doit comporter au moins 8 caractères.';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(p_email)) THEN
    RAISE EXCEPTION 'Cette adresse est déjà utilisée par un autre compte.';
  END IF;

  v_nouveau := gen_random_uuid();

  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    role, aud, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token
  ) VALUES (
    v_nouveau, '00000000-0000-0000-0000-000000000000', lower(p_email),
    crypt(p_password, gen_salt('bf')), now(),
    'authenticated', 'authenticated', now(), now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('first_name', p_first_name, 'last_name', p_last_name,
                       'role', p_role::text),
    false, '', '', '', '', '', '', '', ''
  );

  INSERT INTO auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_nouveau::text, v_nouveau,
    jsonb_build_object('sub', v_nouveau::text, 'email', lower(p_email),
                       'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  -- 1. L'école de l'appelant, jamais un paramètre.
  UPDATE profiles SET
    first_name        = p_first_name,
    last_name         = p_last_name,
    phone             = p_phone,
    group_id          = v_moi.group_id,
    school_id         = v_moi.school_id,
    role              = p_role,
    access_profile_id = p_access_profile_id,
    employee_number   = p_employee_number,
    gender            = p_gender,
    date_of_birth     = p_date_of_birth,
    birth_place       = p_birth_place,
    updated_at        = now()
  WHERE id = v_nouveau;

  -- L'affectation s'ouvre le jour même : la carrière commence ici
  -- (migration 0083), et non le jour d'une première mutation.
  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     notes, created_by)
  VALUES
    (v_moi.group_id, v_moi.school_id, v_nouveau, p_role, CURRENT_DATE,
     'recrutement', 'Compte ouvert par la direction de l''établissement.',
     auth.uid());

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, new_values)
  VALUES (v_moi.group_id, v_moi.school_id, auth.uid(), v_moi.role,
          'CREATION_AGENT', 'profiles', v_nouveau,
          jsonb_build_object('role', p_role, 'email', lower(p_email),
                             'profil_acces', p_access_profile_id));

  RETURN v_nouveau;
END;
$$;

REVOKE ALL ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
                                         text, text, text, date, text) FROM public;
GRANT EXECUTE ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
                                            text, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION est_chef_etablissement()            TO authenticated;
GRANT EXECUTE ON FUNCTION roles_provisionnables_par_ecole()   TO authenticated;

-- ── Ce que l'écran a besoin de savoir AVANT d'ouvrir le formulaire ──────────
-- Les profils d'accès du réseau, et la place restante sur l'abonnement. Sans
-- ce second chiffre, l'agent remplit un formulaire entier pour se voir refuser
-- à l'enregistrement.
CREATE OR REPLACE FUNCTION contexte_creation_agent()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_moi     profiles%ROWTYPE;
  v_max     integer;
  v_actuel  integer;
BEGIN
  IF NOT est_chef_etablissement() THEN
    RETURN jsonb_build_object('autorise', false);
  END IF;
  SELECT * INTO v_moi FROM profiles WHERE id = auth.uid();

  SELECT sp.max_staff INTO v_max
    FROM school_groups sg
    LEFT JOIN subscription_plans sp ON sp.id = sg.plan_id
   WHERE sg.id = v_moi.group_id;

  SELECT count(*) INTO v_actuel FROM profiles
   WHERE group_id = v_moi.group_id AND is_active
     AND role NOT IN ('super_admin', 'parent', 'eleve');

  RETURN jsonb_build_object(
    'autorise', true,
    'max_staff', v_max,
    'agents_actuels', v_actuel,
    'illimite', (v_max IS NULL OR v_max = -1),
    'profils_acces', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', ap.id, 'name', ap.name)
                       ORDER BY ap.name)
        FROM access_profiles ap
       WHERE ap.group_id = v_moi.group_id AND ap.is_active), '[]'::jsonb),
    'roles', to_jsonb(roles_provisionnables_par_ecole())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION contexte_creation_agent() TO authenticated;

COMMIT;
