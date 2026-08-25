-- ════════════════════════════════════════════════════════════════════════════
--  0071 — LE RÉFÉRENTIEL DES EXAMENS APPARTIENT AU MINISTÈRE
--
--  ── L'ERREUR DE RATTACHEMENT QU'ON CORRIGE ─────────────────────────────────
--  Les examens nationaux, leurs sessions et leurs règles d'éligibilité étaient
--  en écriture `is_super_admin()`. Or les deux rôles ne font pas le même
--  métier :
--    • `super_admin`  = l'OPÉRATEUR du SaaS. Il vend, facture, surveille
--                       l'adoption. Il ne connaît pas le calendrier de la DEC
--                       et ne reçoit aucun arrêté.
--    • `admin_groupe` = le MINISTÈRE (METP, MEPSA). C'est lui qui connaît ses
--                       examens, reçoit les arrêtés et pilote ses écoles.
--  Faire saisir un arrêté ministériel par l'éditeur du logiciel était une
--  inversion des responsabilités : le référentiel passe à `admin_groupe`.
--
--  ── PORTÉE DU DROIT ────────────────────────────────────────────────────────
--  Décision assumée : TOUT `admin_groupe` écrit le référentiel national, sans
--  marqueur ministériel — rien en base ne distingue aujourd'hui un ministère
--  d'un réseau privé, et introduire ce marqueur n'a pas été retenu.
--  ⚠️ CONSÉQUENCE À CONNAÎTRE : un groupe privé peut donc modifier un examen
--  que tout le pays consomme. Le jour où l'on voudra le refermer, le geste est
--  petit — ajouter `school_groups.is_ministry` et le poser dans les trois
--  politiques ci-dessous. `super_admin` conserve l'écriture (dépannage).
--
--  La LECTURE ne change pas : le référentiel reste public pour tout compte
--  authentifié, et redescend hors ligne par le bucket PowerSync
--  `global_catalog`.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) Le catalogue des examens ────────────────────────────────────────────
DROP POLICY IF EXISTS national_exams_write ON national_exams;
CREATE POLICY national_exams_write ON national_exams FOR ALL
  TO authenticated
  USING      (is_super_admin() OR is_admin_groupe())
  WITH CHECK (is_super_admin() OR is_admin_groupe());

-- ── 2) Le calendrier (arrêtés de session) ──────────────────────────────────
DROP POLICY IF EXISTS exam_sessions_write ON exam_sessions;
CREATE POLICY exam_sessions_write ON exam_sessions FOR ALL
  TO authenticated
  USING      (is_super_admin() OR is_admin_groupe())
  WITH CHECK (is_super_admin() OR is_admin_groupe());

-- ── 3) Les règles d'éligibilité ────────────────────────────────────────────
--
-- L'ancienne politique bornait `admin_groupe` à ses PROPRES règles
-- (`group_id = auth_group_id()`), ce qui lui interdisait précisément la règle
-- NATIONALE (`group_id IS NULL`) — celle qui fait tout le travail. Le
-- ministère écrivant désormais le référentiel national, la borne saute.
DROP POLICY IF EXISTS exam_rules_write ON exam_eligibility_rules;
CREATE POLICY exam_rules_write ON exam_eligibility_rules FOR ALL
  TO authenticated
  USING      (is_super_admin() OR is_admin_groupe())
  WITH CHECK (is_super_admin() OR is_admin_groupe());

-- La lecture s'élargit du même pas : une règle nationale doit être visible de
-- tous (elle l'était déjà), et un admin de groupe doit voir les surcharges des
-- autres groupes qu'il peut désormais éditer, sans quoi il en créerait des
-- doublons à l'aveugle.
DROP POLICY IF EXISTS exam_rules_select ON exam_eligibility_rules;
CREATE POLICY exam_rules_select ON exam_eligibility_rules FOR SELECT
  TO authenticated
  USING (group_id IS NULL
         OR group_id = auth_group_id()
         OR is_super_admin()
         OR is_admin_groupe());

-- ── 4) L'outillage suit le même périmètre ──────────────────────────────────
--
-- `admin_groupe` écrivant des règles NATIONALES, le borner à son propre parc
-- lui cacherait l'effet réel de ce qu'il saisit : il verrait « 7 classes »
-- pour une règle qui en touche 200. Les trois fonctions de 0070 passent donc
-- au parc entier pour ce rôle.
CREATE OR REPLACE FUNCTION recompute_class_exams() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  -- `current_user` vaut `anon` / `authenticated` derrière PostgREST, et le rôle
  -- de maintenance en connexion directe (migrations 0044/0045/0067 appellent
  -- cette fonction en fin de script, sans `auth.uid()`).
  IF NOT (current_user IN ('postgres', 'supabase_admin')
          OR is_super_admin() OR is_admin_groupe()) THEN
    RAISE EXCEPTION 'Droits insuffisants pour recalculer les classes d''examen.'
      USING ERRCODE = '42501';
  END IF;

  WITH resolved AS (
    SELECT c.id,
           resolve_class_exam(c.cycle_code, c.level_code,
                              NULLIF(c.filiere_code, ''), s.tutelle, c.group_id) AS new_exam,
           c.exam_excluded,
           c.exam_override_id,
           is_terminal_level(c.cycle_code, c.level_code) AS terminal
      FROM classes c
      JOIN schools s ON s.id = c.school_id
  ), computed AS (
    SELECT id, new_exam,
           CASE
             WHEN exam_excluded                                        THEN 'passage'
             WHEN COALESCE(exam_override_id, new_exam) IS NOT NULL     THEN 'examen'
             WHEN terminal                                             THEN 'a_qualifier'
             ELSE 'passage'
           END::class_exam_status AS new_status
      FROM resolved
  )
  UPDATE classes c
     SET exam_id = k.new_exam, exam_status = k.new_status, updated_at = now()
    FROM computed k
   WHERE c.id = k.id
     AND (c.exam_id IS DISTINCT FROM k.new_exam
       OR c.exam_status IS DISTINCT FROM k.new_status);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

COMMENT ON FUNCTION recompute_class_exams IS
  'Recalcule la classe d''examen sur tout le parc. Réservé à super_admin, '
  'admin_groupe (qui écrit le référentiel national) et à la maintenance. '
  'À appeler après toute modification des règles d''éligibilité : le trigger '
  '`classes_derive_exam` ne s''arme qu''à l''écriture d''une CLASSE, donc une '
  'règle nouvelle ne toucherait aucune classe existante.';

REVOKE ALL ON FUNCTION recompute_class_exams() FROM PUBLIC;
REVOKE ALL ON FUNCTION recompute_class_exams() FROM anon;
GRANT  EXECUTE ON FUNCTION recompute_class_exams() TO authenticated;

CREATE OR REPLACE FUNCTION exam_rule_vocabulary()
RETURNS TABLE (kind text, code text, label text, class_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT (current_user IN ('postgres', 'supabase_admin')
          OR is_super_admin() OR is_admin_groupe()) THEN
    RAISE EXCEPTION 'Droits insuffisants.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH scope AS (
    SELECT c.cycle_code, c.level_code,
           NULLIF(c.filiere_code, '') AS filiere_code,
           NULLIF(c.filiere_label, '') AS filiere_label
      FROM classes c
  )
  SELECT 'cycle'::text, s.cycle_code,
         COALESCE(MAX(ec.name), s.cycle_code), COUNT(*)
    FROM scope s
    LEFT JOIN education_cycles ec
           ON ec.code = s.cycle_code AND ec.group_id IS NULL
   WHERE s.cycle_code IS NOT NULL
   GROUP BY s.cycle_code
  UNION ALL
  SELECT 'level'::text, s.level_code,
         COALESCE(MAX(el.name), s.level_code), COUNT(*)
    FROM scope s
    LEFT JOIN education_levels el
           ON el.code = s.level_code AND el.group_id IS NULL
   WHERE s.level_code IS NOT NULL
   GROUP BY s.level_code
  UNION ALL
  -- La filière porte déjà son libellé, dénormalisé sur la classe (0012).
  SELECT 'filiere'::text, s.filiere_code,
         COALESCE(MAX(s.filiere_label), s.filiere_code), COUNT(*)
    FROM scope s
   WHERE s.filiere_code IS NOT NULL
   GROUP BY s.filiere_code;
END $$;

REVOKE ALL ON FUNCTION exam_rule_vocabulary() FROM PUBLIC;
REVOKE ALL ON FUNCTION exam_rule_vocabulary() FROM anon;
GRANT  EXECUTE ON FUNCTION exam_rule_vocabulary() TO authenticated;

CREATE OR REPLACE FUNCTION exam_rule_match_count(
  p_cycle   text,
  p_level   text,
  p_program text DEFAULT NULL,
  p_tutelle tutelle_enum DEFAULT NULL,
  p_group   uuid DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  IF NOT (current_user IN ('postgres', 'supabase_admin')
          OR is_super_admin() OR is_admin_groupe()) THEN
    RAISE EXCEPTION 'Droits insuffisants.' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO v_count
    FROM classes c
    JOIN schools s ON s.id = c.school_id
   WHERE c.cycle_code = p_cycle
     AND c.level_code = p_level
     AND (p_program IS NULL OR NULLIF(c.filiere_code, '') = p_program)
     AND (p_tutelle IS NULL OR s.tutelle = p_tutelle)
     AND (p_group   IS NULL OR c.group_id = p_group);

  RETURN COALESCE(v_count, 0);
END $$;

REVOKE ALL ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) TO authenticated;

COMMIT;
