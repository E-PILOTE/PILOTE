-- 0092_le_statut_decide_du_regime_d_arrivee.sql
--
-- ════════════════════════════════════════════════════════════════════════════
--  TOUT LE MONDE N'ARRIVE PAS PAR UNE NOTE D'AFFECTATION
-- ════════════════════════════════════════════════════════════════════════════
--
--  La 0091 a posé une règle juste — « une école publique ne recrute pas, elle
--  reçoit » — mais l'a appliquée à TOUT LE MONDE. Or dans un lycée d'État du
--  Congo cohabitent deux populations qui n'arrivent pas de la même façon :
--
--    • le FONCTIONNAIRE, agent de l'État. Il est nommé, muté, détaché, mis à
--      disposition par le ministère. Sa carrière est complète : corps, grade,
--      échelon, ancienneté. Il arrive avec un acte, et son arrivée n'a de sens
--      qu'avec la référence de cet acte ;
--
--    • le NON-FONCTIONNAIRE — volontaire, bénévole, vacataire/prestataire,
--      stagiaire. Il est engagé SUR PLACE, souvent payé par l'APE ou sur les
--      ressources propres de l'établissement. Aucun arrêté ne le concerne : le
--      chef d'établissement l'a recruté, point.
--
--  En exigeant un acte de tout le monde, la 0091 rendait le second groupe
--  IMPOSSIBLE à enregistrer en école publique. Dans beaucoup d'établissements
--  congolais, ce groupe fait une part considérable du corps enseignant : la
--  moitié du personnel serait restée hors de l'application, ou — pire — aurait
--  été enregistrée sous une référence d'acte inventée pour passer l'écran.
--
--  ── LA RÈGLE, DÉSORMAIS ────────────────────────────────────────────────────
--  Ce n'est pas le SECTEUR qui décide du régime d'arrivée, c'est le STATUT :
--
--    statut            │ motifs d'arrivée possibles          │ acte
--    ──────────────────┼─────────────────────────────────────┼──────────────
--    fonctionnaire     │ mutation, détachement, mise à       │ obligatoire
--                      │ disposition, intérim, réintégration │
--    contractuel       │ les mêmes + recrutement             │ selon le motif
--    volontaire        │ recrutement                         │ non
--    bénévole          │ recrutement                         │ non
--    prestataire       │ recrutement                         │ non
--    stagiaire         │ recrutement                         │ non
--
--  « contractuel » couvre deux réalités que l'énumération ne distingue pas :
--  le contractuel de l'État (arrive par acte) et le contractuel de
--  l'établissement (recruté sur place). On lui ouvre donc les deux familles, et
--  c'est le MOTIF choisi qui décide si l'acte est exigé — pas le secteur.
--
--  Conséquence heureuse : `profiles.employment_status`, aujourd'hui NULL sur
--  les 342 profils de la base, se remplit enfin dès l'enregistrement. Les
--  répartitions « fonctionnaires / non-fonctionnaires » du ministère cessent
--  d'être aveugles sur le personnel arrivé par l'application.
--
--  ⚠️ `audit_logs.action` est un varchar(20). Ne jamais y écrire plus long.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Quels motifs d'arrivée pour quel statut ─────────────────────────────────
-- ⚠️ Tenu identique à `motifsArriveePourStatut` (Dart, agent_creation_provider).
-- « reprise_historique » n'y figure jamais : c'est une reprise de données, pas
-- une arrivée constatée par un chef d'établissement.
CREATE OR REPLACE FUNCTION motifs_arrivee_pour_statut(p_statut text)
RETURNS text[]
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE p_statut
    -- Agent de l'État : nommé par le ministère, jamais recruté par l'école.
    WHEN 'fonctionnaire' THEN
      ARRAY['mutation', 'detachement', 'mise_a_disposition',
            'interim', 'reintegration']
    -- Contrat : de l'État (par acte) ou de l'établissement (par recrutement).
    WHEN 'contractuel' THEN
      ARRAY['mutation', 'detachement', 'mise_a_disposition',
            'interim', 'reintegration', 'recrutement']
    -- Engagés sur place : APE, ressources propres, convention de stage.
    WHEN 'volontaire'  THEN ARRAY['recrutement']
    WHEN 'benevole'    THEN ARRAY['recrutement']
    WHEN 'prestataire' THEN ARRAY['recrutement']
    WHEN 'stagiaire'   THEN ARRAY['recrutement']
    ELSE ARRAY[]::text[]
  END;
$$;

COMMENT ON FUNCTION motifs_arrivee_pour_statut(text) IS
  'Motifs d''arrivée qu''une école peut constater pour un statut d''emploi '
  'donné. Un fonctionnaire n''est jamais « recruté » par son lycée ; un '
  'volontaire payé par l''APE n''arrive jamais par arrêté.';

-- ── Quels motifs supposent un acte écrit ────────────────────────────────────
-- Une mutation, un détachement, une mise à disposition, un intérim ou une
-- réintégration procèdent TOUJOURS d'une décision écrite de l'autorité — dans
-- le public comme dans le privé qui accueille un détaché. Le recrutement, lui,
-- est l'acte de l'établissement lui-même : rien à référencer d'extérieur.
CREATE OR REPLACE FUNCTION motif_exige_un_acte(p_motif text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT p_motif = ANY (ARRAY['mutation', 'detachement', 'mise_a_disposition',
                              'interim', 'reintegration']);
$$;

COMMENT ON FUNCTION motif_exige_un_acte(text) IS
  'Vrai si le motif d''arrivée procède d''une décision écrite de l''autorité, '
  'dont la référence doit être saisie. Indépendant du secteur : un détaché '
  'accueilli par un établissement privé a lui aussi un arrêté.';

-- ════════════════════════════════════════════════════════════════════════════
--  ENREGISTRER UN AGENT — le statut d'emploi devient obligatoire
-- ════════════════════════════════════════════════════════════════════════════
-- Le nombre d'arguments change : `CREATE OR REPLACE` créerait une surcharge et
-- rendrait tout appel ambigu. On dépose la signature de la 0091.
DROP FUNCTION IF EXISTS creer_agent_ecole(text, text, text, text, user_role,
  uuid, text, text, date, date, text, text, text, date, text);

CREATE OR REPLACE FUNCTION creer_agent_ecole(
  p_email             text,
  p_password          text,
  p_first_name        text,
  p_last_name         text,
  p_role              user_role,
  p_access_profile_id uuid,
  p_employment_status text,
  p_arrival_motif     text,
  p_acte_reference    text DEFAULT NULL,
  p_acte_date         date DEFAULT NULL,
  p_start_date        date DEFAULT NULL,
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
  v_motifs   text[];
  v_acte     text := nullif(btrim(coalesce(p_acte_reference, '')), '');
  v_debut    date := coalesce(p_start_date, CURRENT_DATE);
BEGIN
  IF NOT est_chef_etablissement() THEN
    RAISE EXCEPTION 'Seule la direction de l''établissement peut enregistrer un agent.';
  END IF;

  SELECT * INTO v_moi FROM profiles WHERE id = auth.uid();

  -- Un chef ne crée pas un chef (0088, inchangé).
  IF NOT (p_role = ANY (roles_provisionnables_par_ecole())) THEN
    RAISE EXCEPTION
      'La fonction « % » ne peut être attribuée que par l''administration du groupe.',
      p_role;
  END IF;

  -- ── LE STATUT, QUI COMMANDE TOUT LE RESTE ────────────────────────────────
  IF p_employment_status IS NULL
     OR NOT (p_employment_status = ANY (
              ARRAY(SELECT unnest(enum_range(NULL::employment_status))::text)))
  THEN
    RAISE EXCEPTION 'Statut d''emploi obligatoire : c''est lui qui dit comment '
                    'l''agent est arrivé (fonctionnaire, contractuel, '
                    'volontaire, bénévole, prestataire, stagiaire).';
  END IF;

  v_motifs := motifs_arrivee_pour_statut(p_employment_status);

  IF p_arrival_motif IS NULL OR NOT (p_arrival_motif = ANY (v_motifs)) THEN
    RAISE EXCEPTION 'Un agent « % » n''arrive pas par « % ». Attendus : %.',
      p_employment_status, coalesce(p_arrival_motif, '(vide)'),
      array_to_string(v_motifs, ', ');
  END IF;

  -- ── L'ACTE, QUAND LE MOTIF LE SUPPOSE ────────────────────────────────────
  IF motif_exige_un_acte(p_arrival_motif) THEN
    IF v_acte IS NULL THEN
      RAISE EXCEPTION 'La référence de l''acte est obligatoire : c''est elle '
                      'qui justifie la présence de l''agent dans votre '
                      'établissement.';
    END IF;
    IF p_acte_date IS NULL THEN
      RAISE EXCEPTION 'La date de l''acte est obligatoire.';
    END IF;
    IF p_acte_date > CURRENT_DATE THEN
      RAISE EXCEPTION 'Un acte ne peut pas être daté du futur.';
    END IF;
  END IF;

  IF v_debut > CURRENT_DATE + 90 THEN
    RAISE EXCEPTION 'Une prise de service ne s''enregistre pas plus de trois '
                    'mois à l''avance.';
  END IF;

  -- ── Les garde-fous de la 0088, inchangés ─────────────────────────────────
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
    -- Le statut et la prise de service : le volet carrière de la 0023 cesse
    -- d'être vide au moment même où l'agent entre dans l'établissement.
    employment_status = p_employment_status::employment_status,
    hire_date         = v_debut,
    updated_at        = now()
  WHERE id = v_nouveau;

  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     acte_reference, acte_date, notes, created_by)
  VALUES
    (v_moi.group_id, v_moi.school_id, v_nouveau, p_role, v_debut,
     p_arrival_motif, v_acte, p_acte_date,
     'Arrivée constatée par la direction de l''établissement.', auth.uid());

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, new_values)
  VALUES (v_moi.group_id, v_moi.school_id, auth.uid(), v_moi.role,
          'ENREGISTREMENT_AGENT', 'profiles', v_nouveau,
          jsonb_build_object('role', p_role, 'email', lower(p_email),
                             'statut_emploi', p_employment_status,
                             'motif_arrivee', p_arrival_motif,
                             'acte_reference', v_acte,
                             'acte_date', p_acte_date,
                             'profil_acces', p_access_profile_id));

  RETURN v_nouveau;
END;
$$;

REVOKE ALL ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
  text, text, text, date, date, text, text, text, date, text) FROM public;
GRANT EXECUTE ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
  text, text, text, date, date, text, text, text, date, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
--  CE QUE L'ÉCRAN A BESOIN DE SAVOIR AVANT D'AFFICHER LE FORMULAIRE
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION contexte_creation_agent()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_moi     profiles%ROWTYPE;
  v_max     integer;
  v_actuel  integer;
  v_public  boolean;
BEGIN
  IF NOT est_chef_etablissement() THEN
    RETURN jsonb_build_object('autorise', false);
  END IF;
  SELECT * INTO v_moi FROM profiles WHERE id = auth.uid();
  v_public := groupe_est_public(v_moi.group_id);

  SELECT sp.max_staff INTO v_max
    FROM school_groups sg
    LEFT JOIN subscription_plans sp ON sp.id = sg.plan_id
   WHERE sg.id = v_moi.group_id;

  SELECT count(*) INTO v_actuel FROM profiles
   WHERE group_id = v_moi.group_id AND is_active
     AND role NOT IN ('super_admin', 'parent', 'eleve');

  RETURN jsonb_build_object(
    'autorise', true,
    'secteur_public', v_public,
    -- Ordre d'affichage : le statut le plus fréquent du secteur en premier.
    -- Dans un lycée d'État on saisit surtout des fonctionnaires ; dans un
    -- établissement privé, des contractuels.
    'statuts_emploi', to_jsonb(
      CASE WHEN v_public
        THEN ARRAY['fonctionnaire', 'contractuel', 'volontaire',
                   'benevole', 'prestataire', 'stagiaire']
        ELSE ARRAY['contractuel', 'prestataire', 'volontaire',
                   'benevole', 'stagiaire', 'fonctionnaire']
      END),
    'motifs_par_statut', (
      SELECT jsonb_object_agg(s, to_jsonb(motifs_arrivee_pour_statut(s)))
        FROM unnest(enum_range(NULL::employment_status)::text[]) AS s),
    'motifs_avec_acte', to_jsonb(ARRAY['mutation', 'detachement',
                                       'mise_a_disposition', 'interim',
                                       'reintegration']),
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

-- La règle « secteur → motifs » de la 0091 n'a plus de lecteur : le statut a
-- pris sa place. On la retire pour qu'aucun appelant futur ne la reprenne en
-- croyant qu'elle dit encore le droit.
DROP FUNCTION IF EXISTS motifs_arrivee_constatables(boolean);

COMMIT;
