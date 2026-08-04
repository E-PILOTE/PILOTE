-- ════════════════════════════════════════════════════════════════════════════
--  0091 — L'ÉCOLE CONSTATE UNE ARRIVÉE, ELLE NE LA DÉCIDE PAS
--
--  ── CE QUI ÉTAIT FAUX ──────────────────────────────────────────────────────
--  La migration 0088 a donné à la direction le droit d'ouvrir les comptes de
--  son personnel — nécessaire : mille écoles, vingt agents chacune, un seul
--  guichet ne tient pas. Mais elle écrivait dans la carrière de l'agent :
--
--      arrival_motif  = 'recrutement'      -- l'école a recruté
--      acte_reference = NULL               -- sans aucun acte
--
--  Dans l'enseignement PUBLIC, c'est faux. Un enseignant n'est pas recruté par
--  son lycée : il y est AFFECTÉ par une note de l'autorité de tutelle. L'école
--  le reçoit, elle ne le choisit pas. Les colonnes `acte_reference` et
--  `acte_date` existent depuis la 0083 — la table même qui a été construite
--  pour qu'une mutation ne détruise pas une carrière — et on les laissait
--  vides.
--
--  Conséquence si on n'y touche pas : à la première campagne de mouvement,
--  le ministère lit vingt mille agents « recrutés par leur établissement ».
--  La carrière est faussée à la seconde de l'arrivée, et c'est cette donnée-là
--  que la tutelle exploitera.
--
--  ── LE PRINCIPE ────────────────────────────────────────────────────────────
--  L'école TRANSCRIT un acte administratif. Elle ne le produit pas.
--
--   • à l'entrée   : l'acte est obligatoire dans le PUBLIC (référence + date),
--                    et « recrutement » y est interdit comme motif ;
--                    dans le PRIVÉ la direction EST l'employeur, « recrutement »
--                    est vrai et la référence de contrat reste facultative ;
--   • après        : l'école CORRIGE une fiche (faute de frappe, téléphone,
--                    matricule, photo) — liste blanche de colonnes. Elle ne
--                    mute pas, ne transfère pas, ne désactive pas, ne change
--                    pas la fonction : la fonction EST l'affectation ;
--   • l'erreur     : un enregistrement peut être ANNULÉ tant qu'il n'a rien
--                    produit. Ce n'est pas supprimer une carrière, c'est
--                    effacer une saisie qui n'a jamais existé.
--
--  La RLS `profiles_update` (super_admin | admin_groupe du groupe | soi-même)
--  reste INCHANGÉE : c'est elle la règle. Les fonctions ci-dessous sont les
--  seules portes, étroites et nommées, ouvertes à la direction d'école.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Le secteur commande la règle ────────────────────────────────────────────
-- `school_groups.group_type` vaut 'public' ou 'prive' (enum à deux valeurs).
CREATE OR REPLACE FUNCTION groupe_est_public(p_group_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT sg.group_type::text = 'public'
       FROM school_groups sg WHERE sg.id = p_group_id),
    true);   -- secteur inconnu → on applique la règle la plus exigeante
$$;

COMMENT ON FUNCTION groupe_est_public(uuid) IS
  'Secteur du réseau. Public : l''agent arrive par acte d''affectation. '
  'Privé : la direction est l''employeur et recrute par contrat. Un secteur '
  'inconnu est traité comme public — mieux vaut exiger un acte à tort que '
  'laisser une carrière sans acte.';

-- ── Les motifs d'arrivée qu'une ÉCOLE peut constater ────────────────────────
-- Sous-ensemble de `staff_affectations_arrivee_check`. « reprise_historique »
-- n'y est pas : c'est une reprise de données, pas une arrivée constatée.
CREATE OR REPLACE FUNCTION motifs_arrivee_constatables(p_public boolean)
RETURNS text[]
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE WHEN p_public
    -- Une école publique ne recrute pas : elle reçoit.
    THEN ARRAY['mutation', 'detachement', 'mise_a_disposition',
               'interim', 'reintegration']
    -- Une école privée embauche, et peut aussi accueillir un détaché.
    ELSE ARRAY['recrutement', 'mise_a_disposition', 'interim']
  END;
$$;

COMMENT ON FUNCTION motifs_arrivee_constatables(boolean) IS
  '⚠️ Tenu identique à kMotifsArriveeConstatables (Dart). Public : jamais '
  '« recrutement » — un lycée d''État ne recrute pas son personnel.';

-- ════════════════════════════════════════════════════════════════════════════
--  1. CRÉER UN AGENT — l'acte devient partie de l'acte de création
-- ════════════════════════════════════════════════════════════════════════════
-- Le nombre d'arguments change : `CREATE OR REPLACE` créerait une surcharge et
-- rendrait tout appel ambigu. On dépose l'ancienne signature.
DROP FUNCTION IF EXISTS creer_agent_ecole(text, text, text, text, user_role,
                                          uuid, text, text, text, date, text);

-- ⚠️ `audit_logs.action` est un varchar(20) : tout libellé plus long lève
-- « value too long » AU MOMENT DE L'ÉCRITURE, c'est-à-dire une fois l'agent
-- déjà créé. Les trois actions de cette migration tiennent dans vingt
-- caractères, et c'est délibéré.
CREATE OR REPLACE FUNCTION creer_agent_ecole(
  p_email             text,
  p_password          text,
  p_first_name        text,
  p_last_name         text,
  p_role              user_role,
  p_access_profile_id uuid,
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
  v_public   boolean;
  v_motifs   text[];
  v_acte     text := nullif(btrim(coalesce(p_acte_reference, '')), '');
  v_debut    date := coalesce(p_start_date, CURRENT_DATE);
BEGIN
  IF NOT est_chef_etablissement() THEN
    RAISE EXCEPTION 'Seule la direction de l''établissement peut enregistrer un agent.';
  END IF;

  SELECT * INTO v_moi FROM profiles WHERE id = auth.uid();
  v_public := groupe_est_public(v_moi.group_id);
  v_motifs := motifs_arrivee_constatables(v_public);

  -- Un chef ne crée pas un chef (0088, inchangé).
  IF NOT (p_role = ANY (roles_provisionnables_par_ecole())) THEN
    RAISE EXCEPTION
      'La fonction « % » ne peut être attribuée que par l''administration du groupe.',
      p_role;
  END IF;

  -- ── L'ACTE ───────────────────────────────────────────────────────────────
  IF p_arrival_motif IS NULL OR NOT (p_arrival_motif = ANY (v_motifs)) THEN
    RAISE EXCEPTION 'Motif d''arrivée « % » impossible ici. Attendus : %.',
      coalesce(p_arrival_motif, '(vide)'), array_to_string(v_motifs, ', ');
  END IF;

  IF v_public THEN
    -- Public : sans référence d'acte, la carrière naîtrait sans justification.
    IF v_acte IS NULL THEN
      RAISE EXCEPTION 'La référence de la note d''affectation est obligatoire : '
                      'c''est elle qui justifie la présence de l''agent dans '
                      'votre établissement.';
    END IF;
    IF p_acte_date IS NULL THEN
      RAISE EXCEPTION 'La date de la note d''affectation est obligatoire.';
    END IF;
    IF p_acte_date > CURRENT_DATE THEN
      RAISE EXCEPTION 'La note d''affectation ne peut pas être datée du futur.';
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
    updated_at        = now()
  WHERE id = v_nouveau;

  -- La carrière s'ouvre AVEC son acte. C'est tout l'objet de cette migration.
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
                             'motif_arrivee', p_arrival_motif,
                             'acte_reference', v_acte,
                             'acte_date', p_acte_date,
                             'profil_acces', p_access_profile_id));

  RETURN v_nouveau;
END;
$$;

REVOKE ALL ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
  text, text, date, date, text, text, text, date, text) FROM public;
GRANT EXECUTE ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
  text, text, date, date, text, text, text, date, text) TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
--  2. CORRIGER UNE FICHE — liste blanche, jamais la fonction
-- ════════════════════════════════════════════════════════════════════════════
--  Une faute de frappe sur un nom, un téléphone qui change, une photo qu'on
--  ajoute : ce sont des soins apportés à un dossier, pas des actes de carrière.
--  L'école doit pouvoir les faire — elle a l'agent devant elle.
--
--  ⚠️ NE FIGURENT PAS dans cette liste, et c'est délibéré :
--     `role`              → la fonction EST l'affectation ;
--     `is_active`         → un départ est un acte de l'autorité ;
--     `school_id`         → une mutation est un acte de l'autorité ;
--     `access_profile_id` → ce que voit un agent relève du réseau.
--  Il n'y a pas de paramètre pour elles : on ne peut donc pas les passer par
--  inadvertance. Une liste blanche qui se lit dans la SIGNATURE est plus sûre
--  qu'une liste noire vérifiée dans le corps.
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION corriger_fiche_agent(
  p_profile_id      uuid,
  p_first_name      text DEFAULT NULL,
  p_last_name       text DEFAULT NULL,
  p_phone           text DEFAULT NULL,
  p_employee_number text DEFAULT NULL,
  p_gender          text DEFAULT NULL,
  p_date_of_birth   date DEFAULT NULL,
  p_birth_place     text DEFAULT NULL,
  p_avatar_url      text DEFAULT NULL,
  p_effacer_photo   boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_moi   profiles%ROWTYPE;
  v_cible profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_moi   FROM profiles WHERE id = auth.uid();
  SELECT * INTO v_cible FROM profiles WHERE id = p_profile_id;

  IF v_cible.id IS NULL THEN
    RAISE EXCEPTION 'Agent introuvable.';
  END IF;
  IF v_cible.role IN ('eleve', 'parent') THEN
    RAISE EXCEPTION 'Cette fiche n''est pas celle d''un agent.';
  END IF;

  IF NOT (
       is_super_admin()
    OR (is_admin_groupe() AND v_cible.group_id = auth_group_id())
    OR (est_chef_etablissement()
        AND v_cible.school_id IS NOT NULL
        AND v_cible.school_id = v_moi.school_id)
    OR p_profile_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Vous ne pouvez corriger que les fiches des agents de '
                    'votre établissement.';
  END IF;

  -- Une photo doit venir de NOTRE espace de stockage. Cette URL est affichée
  -- dans toute l'application ; accepter une adresse quelconque reviendrait à
  -- laisser poser un mouchard sur chaque écran qui montre cet agent.
  IF p_avatar_url IS NOT NULL
     AND p_avatar_url !~ '^https://[a-z0-9.-]+/storage/v1/object/public/avatars/' THEN
    RAISE EXCEPTION 'Photo refusée : adresse hors de l''espace de stockage.';
  END IF;

  UPDATE profiles SET
    first_name      = coalesce(nullif(btrim(p_first_name), ''),      first_name),
    last_name       = coalesce(nullif(btrim(p_last_name), ''),       last_name),
    phone           = coalesce(nullif(btrim(p_phone), ''),           phone),
    employee_number = coalesce(nullif(btrim(p_employee_number), ''), employee_number),
    gender          = coalesce(nullif(btrim(p_gender), ''),          gender),
    date_of_birth   = coalesce(p_date_of_birth,                      date_of_birth),
    birth_place     = coalesce(nullif(btrim(p_birth_place), ''),     birth_place),
    avatar_url      = CASE WHEN p_effacer_photo THEN NULL
                           ELSE coalesce(p_avatar_url, avatar_url) END,
    updated_at      = now()
  WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, new_values)
  VALUES (v_cible.group_id, v_cible.school_id, auth.uid(), v_moi.role,
          'CORRECTION_AGENT', 'profiles', p_profile_id,
          jsonb_strip_nulls(jsonb_build_object(
            'first_name', p_first_name, 'last_name', p_last_name,
            'phone', p_phone, 'employee_number', p_employee_number,
            'photo', CASE WHEN p_effacer_photo THEN 'effacée'
                          WHEN p_avatar_url IS NOT NULL THEN 'remplacée'
                          ELSE NULL END)));
END;
$$;

REVOKE ALL ON FUNCTION corriger_fiche_agent(uuid, text, text, text, text, text,
  date, text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION corriger_fiche_agent(uuid, text, text, text, text, text,
  date, text, text, boolean) TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
--  3. ANNULER UN ENREGISTREMENT — l'erreur de saisie, et rien d'autre
-- ════════════════════════════════════════════════════════════════════════════
--  Trois conditions, toutes nécessaires :
--    a. l'agent ne s'est JAMAIS connecté ;
--    b. il ne porte AUCUN travail (classe, matière, créneau, note, paie…) ;
--    c. c'est CETTE école qui l'a enregistré, et l'affectation est courante.
--
--  ⚠️ Pourquoi ce n'est pas un simple DELETE : soixante et une clés étrangères
--  pointent vers `profiles`, dont plusieurs en CASCADE (staff_career,
--  staff_diplomas, staff_members, conversation_members…). Supprimer sans
--  vérifier détruirait des diplômes en silence. Les conditions ci-dessus
--  rendent ces tables vides par construction ; le contrôle explicite ci-dessous
--  le VÉRIFIE au lieu de le supposer.
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION annuler_enregistrement_agent(p_profile_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_moi    profiles%ROWTYPE;
  v_cible  profiles%ROWTYPE;
  v_aff    staff_affectations%ROWTYPE;
  v_bloc   text[] := ARRAY[]::text[];
  v_n      integer;
  v_email  text;
BEGIN
  SELECT * INTO v_moi   FROM profiles WHERE id = auth.uid();
  SELECT * INTO v_cible FROM profiles WHERE id = p_profile_id;

  IF v_cible.id IS NULL THEN
    RAISE EXCEPTION 'Agent introuvable.';
  END IF;
  IF NOT (est_chef_etablissement()
          AND v_cible.school_id IS NOT NULL
          AND v_cible.school_id = v_moi.school_id) THEN
    RAISE EXCEPTION 'Seule la direction de l''établissement où l''agent a été '
                    'enregistré peut annuler cet enregistrement.';
  END IF;

  -- (c) C'est bien NOUS qui l'avons enregistré, et rien n'a bougé depuis.
  SELECT * INTO v_aff FROM staff_affectations
   WHERE profile_id = p_profile_id AND end_date IS NULL;
  IF v_aff.id IS NULL OR v_aff.school_id <> v_moi.school_id THEN
    RAISE EXCEPTION 'Cet agent n''a pas d''affectation courante dans votre '
                    'établissement.';
  END IF;
  IF v_aff.created_by IS NULL
     OR NOT EXISTS (SELECT 1 FROM profiles
                     WHERE id = v_aff.created_by AND school_id = v_moi.school_id) THEN
    RAISE EXCEPTION 'Cet agent a été enregistré par l''administration du '
                    'réseau : elle seule peut revenir dessus.';
  END IF;
  IF (SELECT count(*) FROM staff_affectations WHERE profile_id = p_profile_id) > 1 THEN
    RAISE EXCEPTION 'Cet agent a déjà une histoire dans le réseau : son dossier '
                    'ne s''annule pas, il se clôt par un acte.';
  END IF;

  -- (a) Jamais connecté.
  SELECT u.email INTO v_email FROM auth.users u WHERE u.id = p_profile_id;
  IF v_cible.last_login IS NOT NULL
     OR EXISTS (SELECT 1 FROM auth.users
                 WHERE id = p_profile_id AND last_sign_in_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Cet agent s''est déjà connecté : son compte a vécu, il ne '
                    's''annule plus.';
  END IF;

  -- (b) Aucun travail rattaché. On NOMME ce qui bloque : un refus qu'on ne
  --     comprend pas se contourne au hasard.
  SELECT count(*) INTO v_n FROM classes WHERE main_teacher_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s classe(s) dont il est professeur principal', v_n); END IF;

  SELECT count(*) INTO v_n FROM teacher_subjects WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s matière(s) qui lui sont confiées', v_n); END IF;

  SELECT count(*) INTO v_n FROM timetable_slots WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s créneau(x) à son emploi du temps', v_n); END IF;

  SELECT count(*) INTO v_n FROM staff_attendance WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s pointage(s)', v_n); END IF;

  SELECT count(*) INTO v_n FROM payroll WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s bulletin(s) de paie', v_n); END IF;

  SELECT count(*) INTO v_n FROM leave_requests WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s demande(s) de congé', v_n); END IF;

  SELECT count(*) INTO v_n FROM lesson_entries WHERE staff_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s entrée(s) au cahier de textes', v_n); END IF;

  SELECT count(*) INTO v_n FROM staff_diplomas WHERE profile_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s diplôme(s) au dossier', v_n); END IF;

  SELECT count(*) INTO v_n FROM staff_career WHERE profile_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || format('%s étape(s) de parcours', v_n); END IF;

  SELECT count(*) INTO v_n FROM schools WHERE director_id = p_profile_id;
  IF v_n > 0 THEN v_bloc := v_bloc || 'la direction d''un établissement'; END IF;

  IF array_length(v_bloc, 1) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'motif', 'travail_rattache',
      'bloquants', to_jsonb(v_bloc));
  END IF;

  -- L'audit AVANT la suppression : après, la ligne n'existe plus pour être
  -- décrite. On garde le nom et l'adresse — c'est ce qui permettra de dire
  -- plus tard ce qui a été annulé.
  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values)
  VALUES (v_cible.group_id, v_cible.school_id, auth.uid(), v_moi.role,
          'ANNULATION_AGENT', 'profiles', p_profile_id,
          jsonb_build_object(
            'first_name', v_cible.first_name, 'last_name', v_cible.last_name,
            'role', v_cible.role, 'email', v_email,
            'motif_arrivee', v_aff.arrival_motif,
            'acte_reference', v_aff.acte_reference));

  -- `profiles.id` référence `auth.users(id)` : supprimer le compte emporte la
  -- fiche et l'affectation (CASCADE), toutes deux vides par les contrôles
  -- ci-dessus. Les clés NO ACTION restantes lèveraient 23503 — ce serait un
  -- travail que nous n'avons pas su nommer, et le refus vaut mieux que la perte.
  DELETE FROM auth.users WHERE id = p_profile_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION annuler_enregistrement_agent(uuid) FROM public;
GRANT EXECUTE ON FUNCTION annuler_enregistrement_agent(uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION groupe_est_public(uuid)              TO authenticated;
GRANT EXECUTE ON FUNCTION motifs_arrivee_constatables(boolean) TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
--  4. Le contexte que l'écran demande AVANT d'ouvrir le formulaire
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
    'acte_obligatoire', v_public,
    'motifs_arrivee', to_jsonb(motifs_arrivee_constatables(v_public)),
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

COMMENT ON FUNCTION creer_agent_ecole(text, text, text, text, user_role, uuid,
  text, text, date, date, text, text, text, date, text) IS
  'L''école CONSTATE une arrivée. Public : acte d''affectation obligatoire, '
  '« recrutement » interdit. Privé : la direction est l''employeur.';
COMMENT ON FUNCTION corriger_fiche_agent(uuid, text, text, text, text, text,
  date, text, text, boolean) IS
  'Liste blanche lisible dans la SIGNATURE. Ni rôle, ni is_active, ni '
  'school_id, ni access_profile_id : ce sont des actes de l''autorité.';
COMMENT ON FUNCTION annuler_enregistrement_agent(uuid) IS
  'Efface une SAISIE, jamais une carrière : jamais connecté + aucun travail '
  'rattaché + enregistré par cette école. Sinon, refus nommant ce qui bloque.';

COMMIT;
