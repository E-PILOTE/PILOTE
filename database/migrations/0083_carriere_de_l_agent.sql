-- ════════════════════════════════════════════════════════════════════════════
--  0083 — LA CARRIÈRE DE L'AGENT : CE QUE LA MUTATION NE DOIT PLUS DÉTRUIRE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  Une ligne `profiles` confond trois choses :
--    1. la PERSONNE  — nom, naissance, matricule, diplômes ;
--    2. l'AFFECTATION — `school_id`, la fonction exercée, la date d'entrée ;
--    3. le COMPTE     — `id` = `auth.users.id`, `is_active`.
--
--  Conséquences, aujourd'hui :
--
--  • MUTER un agent, c'est écraser `school_id`. L'école de départ ne peut plus
--    dire « il a servi chez nous de 2019 à 2026 » : la phrase n'est écrite
--    nulle part. L'ancienneté d'un fonctionnaire n'est pas un détail — elle
--    ouvre des droits.
--
--  • SORTIR un agent, c'est `is_active = false`. Un retraité, un muté, un
--    démissionnaire, un révoqué et un mort deviennent le même booléen. Or ils
--    n'appellent pas les mêmes actes : le retraité reste consultable (pension,
--    attestations), le révoqué ne doit jamais revenir, et le MUTÉ N'EST PAS
--    INACTIF — il sert ailleurs. Le désactiver le coupe d'un poste où on
--    l'attend.
--
--  ── LA FORME ───────────────────────────────────────────────────────────────
--  `staff_affectations` dit QUI était OÙ, QUAND, et EN VERTU DE QUEL ACTE.
--  Dans la fonction publique congolaise, aucun mouvement n'existe sans arrêté
--  ou note de service : porter la référence de l'acte est ce qui distingue un
--  registre d'un pense-bête.
--
--  `profiles` garde la PERSONNE et l'affectation COURANTE (c'est elle que
--  PowerSync synchronise déjà, et qui décide de ce que l'agent voit). La table
--  porte l'HISTOIRE. Les deux ne se contredisent jamais : seules les fonctions
--  ci-dessous écrivent les deux, dans la même transaction.
--
--  ⚠️ TABLE EN LIGNE UNIQUEMENT — hors PowerSync, donc AUCUNE modification des
--  sync-rules avant le 2 octobre. C'est délibéré : muter est un acte de
--  l'autorité de tutelle (groupe / ministère), pas de l'école. L'école en voit
--  la conséquence — l'agent entre dans son effectif, ou en sort — via
--  `profiles.school_id`, déjà synchronisé.
--
--  ⚠️ MOTIFS À FAIRE VALIDER par le MEPSA et le METP, comme ceux de la sortie
--  d'élève (migration 0082). Ils reprennent le vocabulaire statutaire usuel ;
--  aucun n'a été confirmé. Les modifier = cette contrainte ET
--  `core/utils/mouvement_agent.dart`, tenus identiques.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Le registre des affectations ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS staff_affectations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES schools(id)       ON DELETE CASCADE,
  profile_id   uuid NOT NULL REFERENCES profiles(id)      ON DELETE CASCADE,

  -- La fonction EXERCÉE DANS CETTE ÉCOLE. Un enseignant muté peut arriver
  -- directeur : le rôle appartient au poste, pas à la personne.
  role         user_role NOT NULL,

  start_date   date NOT NULL,
  end_date     date,                       -- NULL = affectation en cours

  arrival_motif   text NOT NULL,
  departure_motif text,                    -- renseigné à la clôture

  -- L'acte administratif qui fonde le mouvement (arrêté, décision, note de
  -- service). Facultatif — une école privée n'en produit pas — mais c'est lui
  -- qui rend le registre opposable.
  acte_reference  text,
  acte_date       date,

  notes        text,
  created_by   uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  -- Dérivé, jamais saisi : une affectation close ne peut pas rester courante.
  is_current   boolean GENERATED ALWAYS AS (end_date IS NULL) STORED,

  CONSTRAINT staff_affectations_dates_check
    CHECK (end_date IS NULL OR end_date >= start_date),

  CONSTRAINT staff_affectations_arrivee_check
    CHECK (arrival_motif IN (
      'recrutement',        -- premier poste : l'agent entre dans le système
      'mutation',           -- vient d'un autre établissement
      'detachement',        -- mis à disposition par une autre administration
      'mise_a_disposition',
      'interim',            -- occupe temporairement le poste d'un autre
      'reintegration',      -- revient après disponibilité, détachement, congé
      'reprise_historique'  -- ⚠️ créé par la reprise de l'existant : la date
                            --    d'entrée réelle n'est pas connue
    )),

  CONSTRAINT staff_affectations_depart_check
    CHECK (departure_motif IS NULL OR departure_motif IN (
      -- L'agent reste dans le système, ailleurs.
      'mutation',
      -- L'agent s'absente durablement, mais pourra revenir.
      'detachement', 'disponibilite',
      -- L'agent quitte le service.
      'retraite', 'demission', 'licenciement', 'revocation',
      'abandon_de_poste', 'deces', 'fin_de_contrat',
      -- Fin d'une situation temporaire.
      'fin_interim',
      'autre'
    ))
);

-- Un agent n'occupe qu'un poste à la fois. Le prédicat porte sur `end_date`
-- plutôt que sur la colonne dérivée : c'est l'écriture la plus sûre.
CREATE UNIQUE INDEX IF NOT EXISTS staff_affectations_courante_key
  ON staff_affectations (profile_id) WHERE end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_affectations_profil ON staff_affectations (profile_id, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_affectations_ecole  ON staff_affectations (school_id) WHERE end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_affectations_groupe ON staff_affectations (group_id, start_date DESC);

COMMENT ON TABLE staff_affectations IS
  'Qui a servi où, quand, et en vertu de quel acte. `profiles` porte la '
  'personne et son poste courant ; cette table porte l''histoire. Écriture par '
  'muter_agent / radier_agent / reintegrer_agent uniquement. Hors PowerSync.';

-- ── 2. Ce que `is_active` ne disait pas ─────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS departure_motif text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS departure_date  date;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_departure_motif_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_departure_motif_check
  CHECK (departure_motif IS NULL OR departure_motif IN (
    'detachement', 'disponibilite', 'retraite', 'demission', 'licenciement',
    'revocation', 'abandon_de_poste', 'deces', 'fin_de_contrat', 'fin_interim',
    'autre'
  ));
-- ⚠️ 'mutation' est ABSENT de cette liste, et c'est le cœur du correctif :
--    un agent muté n'a pas quitté le service. Il n'a pas de motif de départ.

COMMENT ON COLUMN profiles.departure_motif IS
  'Pourquoi l''agent ne sert plus — ce que `is_active = false` ne disait pas. '
  'Jamais ''mutation'' : un muté reste actif. Tenu identique à '
  'core/utils/mouvement_agent.dart.';

-- ── 3. Reprise de l'existant ────────────────────────────────────────────────
-- Chaque agent en poste reçoit une affectation courante. La date d'entrée
-- réelle n'est nulle part (`hire_date` est vide sur toute la base) : on prend
-- `hire_date` s'il existe, sinon la création du compte, et on le DIT par le
-- motif `reprise_historique`. Antidater serait inventer une ancienneté.
INSERT INTO staff_affectations
  (group_id, school_id, profile_id, role, start_date, arrival_motif, notes)
SELECT p.group_id, p.school_id, p.id, p.role,
       COALESCE(p.hire_date, p.created_at::date),
       'reprise_historique',
       'Créée par la migration 0083. La date d''entrée réelle n''était pas '
       'enregistrée : à corriger au vu du dossier de l''agent.'
FROM   profiles p
WHERE  p.school_id IS NOT NULL
  AND  p.group_id  IS NOT NULL
  AND  p.is_active
  AND  p.role NOT IN ('super_admin', 'admin_groupe', 'parent', 'eleve')
  AND  NOT EXISTS (SELECT 1 FROM staff_affectations a
                    WHERE a.profile_id = p.id AND a.end_date IS NULL);

-- ── 4. Les trois mouvements ────────────────────────────────────────────────
-- SECURITY DEFINER : elles écrivent `profiles` ET `staff_affectations` dans la
-- même transaction. Les laisser à l'appelant, c'est accepter qu'un poste soit
-- clos sans que le suivant s'ouvre. `search_path` figé — cette faille a déjà
-- été refermée une fois sur ce projet (migrations 0070/0071).

CREATE OR REPLACE FUNCTION _agent_mouvement_autorise(p_profile_id uuid, p_school_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_groupe_agent uuid; v_groupe_cible uuid;
BEGIN
  IF is_super_admin() THEN RETURN true; END IF;
  IF NOT is_admin_groupe() THEN RETURN false; END IF;

  SELECT group_id INTO v_groupe_agent FROM profiles WHERE id = p_profile_id;
  -- L'agent ET l'école de destination doivent relever du groupe de l'appelant :
  -- un admin ne déplace pas un agent hors de son périmètre, et n'en fait pas
  -- entrer un chez lui à l'insu de son groupe d'origine.
  IF v_groupe_agent IS DISTINCT FROM auth_group_id() THEN RETURN false; END IF;
  IF p_school_id IS NULL THEN RETURN true; END IF;

  SELECT group_id INTO v_groupe_cible FROM schools WHERE id = p_school_id;
  RETURN v_groupe_cible = auth_group_id();
END;
$$;

-- ── 4a. MUTER ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION muter_agent(
  p_profile_id     uuid,
  p_school_id      uuid,
  p_effective_date date,
  p_role           user_role DEFAULT NULL,   -- NULL = conserve la fonction
  p_acte_reference text      DEFAULT NULL,
  p_acte_date      date      DEFAULT NULL,
  p_notes          text      DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_agent      profiles%ROWTYPE;
  v_groupe     uuid;
  v_role       user_role;
  v_nouvelle   uuid;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, p_school_id) THEN
    RAISE EXCEPTION 'Mutation non autorisée sur cet agent.';
  END IF;

  SELECT group_id INTO v_groupe FROM schools WHERE id = p_school_id AND is_active;
  IF v_groupe IS NULL THEN RAISE EXCEPTION 'École de destination introuvable.'; END IF;

  IF v_agent.school_id = p_school_id THEN
    RAISE EXCEPTION 'L''agent est déjà affecté à cet établissement.';
  END IF;

  v_role := COALESCE(p_role, v_agent.role);

  -- Le poste quitté se ferme la veille de la prise de fonction : sans cela,
  -- l'agent compterait deux fois dans les effectifs du jour de bascule.
  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date - 1),
         departure_motif = 'mutation',
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     acte_reference, acte_date, notes, created_by)
  VALUES
    (v_groupe, p_school_id, p_profile_id, v_role, p_effective_date, 'mutation',
     p_acte_reference, p_acte_date, p_notes, auth.uid())
  RETURNING id INTO v_nouvelle;

  -- L'agent RESTE ACTIF : il sert ailleurs, on l'attend à son nouveau poste.
  UPDATE profiles
     SET school_id       = p_school_id,
         group_id        = v_groupe,
         role            = v_role,
         is_active       = true,
         departure_motif = NULL,
         departure_date  = NULL,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_groupe, p_school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'MUTATION_AGENT', 'staff_affectations', v_nouvelle,
          jsonb_build_object('school_id', v_agent.school_id, 'role', v_agent.role),
          jsonb_build_object('school_id', p_school_id, 'role', v_role,
                             'acte', p_acte_reference, 'date', p_effective_date));
  RETURN v_nouvelle;
END;
$$;

-- ── 4b. RADIER (sortie du service) ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION radier_agent(
  p_profile_id     uuid,
  p_motif          text,
  p_effective_date date,
  p_acte_reference text DEFAULT NULL,
  p_acte_date      date DEFAULT NULL,
  p_notes          text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_agent profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, NULL) THEN
    RAISE EXCEPTION 'Radiation non autorisée sur cet agent.';
  END IF;

  IF p_motif = 'mutation' THEN
    RAISE EXCEPTION 'Une mutation n''est pas un départ : utiliser muter_agent.';
  END IF;

  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date),
         departure_motif = p_motif,
         acte_reference  = COALESCE(p_acte_reference, acte_reference),
         acte_date       = COALESCE(p_acte_date, acte_date),
         notes           = COALESCE(p_notes, notes),
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  -- On NE SUPPRIME RIEN. Un agent parti reste consultable : c'est de lui que
  -- dépendent l'attestation de service, la pension, et la traçabilité des
  -- notes qu'il a saisies.
  UPDATE profiles
     SET is_active       = false,
         departure_motif = p_motif,
         departure_date  = p_effective_date,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_agent.group_id, v_agent.school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'DEPART_AGENT', 'profiles', p_profile_id,
          jsonb_build_object('is_active', v_agent.is_active),
          jsonb_build_object('motif', p_motif, 'date', p_effective_date,
                             'acte', p_acte_reference));
END;
$$;

-- ── 4c. RÉINTÉGRER ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION reintegrer_agent(
  p_profile_id     uuid,
  p_school_id      uuid,
  p_effective_date date,
  p_role           user_role DEFAULT NULL,
  p_acte_reference text      DEFAULT NULL,
  p_acte_date      date      DEFAULT NULL,
  p_notes          text      DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_agent    profiles%ROWTYPE;
  v_groupe   uuid;
  v_role     user_role;
  v_nouvelle uuid;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, p_school_id) THEN
    RAISE EXCEPTION 'Réintégration non autorisée sur cet agent.';
  END IF;

  -- Une révocation et un décès ne se défont pas d'un clic. Les rouvrir doit
  -- passer par une correction explicite, tracée, pas par ce guichet.
  IF v_agent.departure_motif IN ('revocation', 'deces') THEN
    RAISE EXCEPTION 'Réintégration impossible après une % : corriger le dossier d''abord.',
      v_agent.departure_motif;
  END IF;

  SELECT group_id INTO v_groupe FROM schools WHERE id = p_school_id AND is_active;
  IF v_groupe IS NULL THEN RAISE EXCEPTION 'École d''accueil introuvable.'; END IF;

  v_role := COALESCE(p_role, v_agent.role);

  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date - 1),
         departure_motif = COALESCE(departure_motif, 'autre'),
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     acte_reference, acte_date, notes, created_by)
  VALUES
    (v_groupe, p_school_id, p_profile_id, v_role, p_effective_date,
     'reintegration', p_acte_reference, p_acte_date, p_notes, auth.uid())
  RETURNING id INTO v_nouvelle;

  UPDATE profiles
     SET school_id       = p_school_id,
         group_id        = v_groupe,
         role            = v_role,
         is_active       = true,
         departure_motif = NULL,
         departure_date  = NULL,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_groupe, p_school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'REINTEGRATION', 'staff_affectations', v_nouvelle,
          jsonb_build_object('motif_sortie', v_agent.departure_motif),
          jsonb_build_object('school_id', p_school_id, 'date', p_effective_date));
  RETURN v_nouvelle;
END;
$$;

-- ── 5. Le guichet : ce matricule est-il déjà porté ? ────────────────────────
-- Symétrique du guichet élève (migration 0081). Avant de créer un agent,
-- l'admin vérifie que le matricule de la fonction publique n'appartient pas
-- déjà à quelqu'un — dans SON groupe ou dans un autre. On ne BLOQUE pas : un
-- rejet en pleine saisie de rentrée coûte plus cher qu'un doublon signalé.
-- Projection minimale, et jamais le compte de connexion.
CREATE OR REPLACE FUNCTION verifier_matricule_agent(p_employee_number text)
RETURNS TABLE (
  first_name      text,
  last_name       text,
  role            text,
  school_name     text,
  group_name      text,
  is_active       boolean,
  departure_motif text,
  meme_groupe     boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_employee_number IS NULL OR length(trim(p_employee_number)) < 3 THEN
    RETURN;
  END IF;
  IF NOT (is_super_admin() OR is_admin_groupe()) THEN
    RAISE EXCEPTION 'Consultation réservée à l''administration.';
  END IF;

  RETURN QUERY
  SELECT p.first_name::text, p.last_name::text, p.role::text,
         s.name::text, g.name::text, p.is_active, p.departure_motif,
         (p.group_id = auth_group_id())
  FROM   profiles p
  LEFT   JOIN schools s      ON s.id = p.school_id
  LEFT   JOIN school_groups g ON g.id = p.group_id
  WHERE  upper(trim(p.employee_number)) = upper(trim(p_employee_number))
  ORDER  BY p.is_active DESC
  LIMIT  5;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_profiles_matricule
  ON profiles (upper(trim(employee_number))) WHERE employee_number IS NOT NULL;

-- ── 6. Droits ───────────────────────────────────────────────────────────────
ALTER TABLE staff_affectations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS affectations_lecture   ON staff_affectations;
DROP POLICY IF EXISTS affectations_ecriture  ON staff_affectations;

CREATE POLICY affectations_lecture ON staff_affectations FOR SELECT
  USING (is_super_admin()
         OR group_id = auth_group_id()
         OR profile_id = auth.uid());   -- chacun peut lire sa propre carrière

CREATE POLICY affectations_ecriture ON staff_affectations FOR ALL
  USING (is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id()))
  WITH CHECK (is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id()));

REVOKE ALL ON FUNCTION _agent_mouvement_autorise(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION muter_agent(uuid, uuid, date, user_role, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION radier_agent(uuid, text, date, text, date, text)           TO authenticated;
GRANT EXECUTE ON FUNCTION reintegrer_agent(uuid, uuid, date, user_role, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION verifier_matricule_agent(text)                             TO authenticated;

-- ── 7. Ce que le ministère pourra lire ──────────────────────────────────────
CREATE OR REPLACE VIEW v_mouvements_personnel AS
SELECT a.group_id,
       a.school_id,
       date_trunc('year', a.start_date)::date AS annee,
       a.arrival_motif                        AS motif_arrivee,
       a.departure_motif                      AS motif_depart,
       count(*)                               AS effectif,
       count(*) FILTER (WHERE p.gender = 'F') AS femmes
FROM   staff_affectations a
JOIN   profiles p ON p.id = a.profile_id
GROUP  BY 1, 2, 3, 4, 5;

COMMENT ON VIEW v_mouvements_personnel IS
  'Mouvements du personnel par école et par année — entrées, sorties, motifs. '
  'Le premier agrégat de gestion des ressources humaines que la plateforme '
  'rende possible.';

COMMIT;
