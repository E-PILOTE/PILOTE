-- ════════════════════════════════════════════════════════════════════════════
--  0070 — OUTILLER LA SAISIE DES RÈGLES D'ÉLIGIBILITÉ (+ un verrou oublié)
--
--  La migration 0044 a posé `exam_eligibility_rules`, la table qui décide
--  quelle classe prépare quel examen. Elle n'a jamais eu d'écran : une réforme
--  du METP exigeait donc du SQL en production. L'écran arrive ; il lui manque
--  trois choses que seule la base peut donner.
--
--  ── 1) UN VERROU QUI MANQUAIT ──────────────────────────────────────────────
--  `recompute_class_exams()` est SECURITY DEFINER et n'a jamais reçu de REVOKE.
--  Elle héritait donc de l'EXECUTE par défaut de PostgreSQL (PUBLIC) : TOUT
--  compte authentifié — un enseignant, un parent — pouvait réécrire
--  `classes.exam_id` et `classes.exam_status` sur le parc ENTIER, tous groupes
--  confondus, en contournant la RLS. Rien ne l'exploitait, mais la porte était
--  ouverte. On la ferme, et on borne la fonction au périmètre de l'appelant.
--
--  ── 2) LE VOCABULAIRE RÉEL ─────────────────────────────────────────────────
--  Une règle se saisit sur (cycle_code, level_code, filiere_code). Ces codes ne
--  vivent dans AUCUNE constante du dépôt : ils sont dénormalisés sur `classes`
--  depuis les référentiels de chaque groupe (`school_levels`, pas
--  `education_levels`). Une liste figée dans le Dart aurait donc produit des
--  règles qui ne matchent rien. `exam_rule_vocabulary()` rend les codes
--  RÉELLEMENT portés par les classes, avec leur effectif.
--
--  ── 3) L'EFFET AVANT L'EFFET ───────────────────────────────────────────────
--  `exam_rule_match_count()` répond « combien de classes cette règle
--  toucherait-elle ? » AVANT d'enregistrer. Une règle d'éligibilité fausse
--  inscrit des élèves au mauvais examen — la voir à blanc vaut mieux que la
--  découvrir à la proclamation.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) Recalcul global : borné au périmètre de l'appelant ──────────────────
--
-- Le corps de calcul est INCHANGÉ (version 0045, avec `exam_status`). Seuls
-- s'ajoutent le contrôle de rôle et le filtre de périmètre.
CREATE OR REPLACE FUNCTION recompute_class_exams() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count integer;
  v_group uuid;
BEGIN
  -- super_admin : tout le parc. admin_groupe : son groupe et rien d'autre.
  -- Quiconque d'autre n'a aucune raison de recalculer une dérivation.
  --
  -- `current_user` vaut `anon` / `authenticated` derrière PostgREST, et le rôle
  -- de maintenance en connexion directe. Une migration qui appelle la fonction
  -- en fin de script (0044, 0045, 0067 le font) n'a pas d'`auth.uid()` : sans
  -- cette branche, elle échouerait.
  IF current_user IN ('postgres', 'supabase_admin') THEN
    v_group := NULL;
  ELSIF is_super_admin() THEN
    v_group := NULL;
  ELSIF is_admin_groupe() THEN
    v_group := auth_group_id();
    IF v_group IS NULL THEN
      RAISE EXCEPTION 'Groupe introuvable pour cet administrateur.'
        USING ERRCODE = '42501';
    END IF;
  ELSE
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
     WHERE v_group IS NULL OR c.group_id = v_group
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
  'Recalcule la classe d''examen. super_admin : tout le parc ; admin_groupe : '
  'son groupe. À appeler après toute modification des règles d''éligibilité — '
  'le trigger `classes_derive_exam` ne s''arme qu''à l''écriture d''une CLASSE, '
  'donc une règle nouvelle ne toucherait aucune classe existante.';

REVOKE ALL ON FUNCTION recompute_class_exams() FROM PUBLIC;
REVOKE ALL ON FUNCTION recompute_class_exams() FROM anon;
GRANT  EXECUTE ON FUNCTION recompute_class_exams() TO authenticated;

-- ── 2) Vocabulaire réellement porté par les classes ────────────────────────
--
-- `kind` ∈ ('cycle', 'level', 'filiere'). Le libellé vient du référentiel
-- national quand il existe, sinon du code lui-même : mieux vaut un code brut
-- qu'un champ vide.
CREATE OR REPLACE FUNCTION exam_rule_vocabulary()
RETURNS TABLE (kind text, code text, label text, class_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_group uuid;
BEGIN
  -- Connexion directe de maintenance : déjà privilégiée (cf. commentaire de
  -- `recompute_class_exams`). Derrière PostgREST, `current_user` vaut
  -- `anon` / `authenticated` et l'on retombe sur le contrôle de rôle.
  IF current_user IN ('postgres', 'supabase_admin') THEN
    v_group := NULL;
  ELSIF is_super_admin() THEN
    v_group := NULL;
  ELSIF is_admin_groupe() THEN
    v_group := auth_group_id();
  ELSE
    RAISE EXCEPTION 'Droits insuffisants.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH scope AS (
    SELECT c.cycle_code, c.level_code,
           NULLIF(c.filiere_code, '') AS filiere_code,
           NULLIF(c.filiere_label, '') AS filiere_label
      FROM classes c
     WHERE (v_group IS NULL OR c.group_id = v_group)
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

COMMENT ON FUNCTION exam_rule_vocabulary IS
  'Codes de cycle / niveau / filière RÉELLEMENT portés par les classes, avec '
  'leur effectif. Sert à saisir une règle d''éligibilité sur des valeurs qui '
  'existent : les codes sont dénormalisés depuis les référentiels de chaque '
  'groupe, aucune liste figée côté client ne pourrait les connaître.';

REVOKE ALL ON FUNCTION exam_rule_vocabulary() FROM PUBLIC;
REVOKE ALL ON FUNCTION exam_rule_vocabulary() FROM anon;
GRANT  EXECUTE ON FUNCTION exam_rule_vocabulary() TO authenticated;

-- ── 3) Combien de classes cette règle toucherait-elle ? ────────────────────
--
-- Reproduit exactement le filtrage de `resolve_class_exam` (jokers NULL sur la
-- filière et la tutelle), sans rien écrire. Ne dit PAS que la règle gagnera :
-- une règle plus spécifique peut l'emporter. Elle dit ce qu'elle CONCERNE.
CREATE OR REPLACE FUNCTION exam_rule_match_count(
  p_cycle   text,
  p_level   text,
  p_program text DEFAULT NULL,
  p_tutelle tutelle_enum DEFAULT NULL,
  p_group   uuid DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_scope uuid;
  v_count integer;
BEGIN
  IF current_user IN ('postgres', 'supabase_admin') THEN
    v_scope := p_group;
  ELSIF is_super_admin() THEN
    v_scope := p_group;                    -- NULL = national, sinon le groupe visé
  ELSIF is_admin_groupe() THEN
    v_scope := auth_group_id();            -- jamais au-delà de son périmètre
  ELSE
    RAISE EXCEPTION 'Droits insuffisants.' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO v_count
    FROM classes c
    JOIN schools s ON s.id = c.school_id
   WHERE c.cycle_code = p_cycle
     AND c.level_code = p_level
     AND (p_program IS NULL OR NULLIF(c.filiere_code, '') = p_program)
     AND (p_tutelle IS NULL OR s.tutelle = p_tutelle)
     AND (v_scope   IS NULL OR c.group_id = v_scope);

  RETURN COALESCE(v_count, 0);
END $$;

COMMENT ON FUNCTION exam_rule_match_count IS
  'Nombre de classes concernées par une règle d''éligibilité candidate, à '
  'blanc. Une règle fausse inscrit des élèves au mauvais examen : on la voit '
  'avant de l''enregistrer.';

REVOKE ALL ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION exam_rule_match_count(text, text, text, tutelle_enum, uuid) TO authenticated;

COMMIT;
