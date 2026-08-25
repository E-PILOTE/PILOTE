-- 0045 — Statut de la classe : examen · passage · à qualifier
--
-- Correctif de conception révélé par la dérivation réelle (migration 0044).
--
-- CONSTAT : après dérivation, une 6e, un CE1 et une Terminale série E se
-- retrouvaient TOUTES avec exam_id IS NULL — donc indistinguables. Or ce sont
-- deux situations opposées :
--
--   • 6e / CE1  -> classe de PASSAGE. Aucun examen n'est attendu. C'est normal,
--                  définitif, et il n'y a RIEN à faire.
--   • Tle E     -> classe TERMINALE d'un cycle : un examen EST attendu, mais
--                  aucune règle ne l'a résolu. C'est une anomalie à traiter.
--
-- Les confondre, c'est soit noyer l'anomalie dans le bruit (et rater des
-- candidats), soit harceler l'utilisateur pour des classes qui vont très bien.
-- Le brief le disait déjà : « Toutes les classes ne préparent pas un examen
-- national. Certaines sont des classes de passage. »
--
-- RÈGLE : une classe porte un examen potentiel si elle est au niveau TERMINAL
-- de son cycle (order_index maximal du référentiel national du cycle) :
--   primaire -> CM2 · college -> 3e · lycee -> Tle · formation_pro -> 3e année.
-- Le niveau terminal est DÉDUIT du référentiel, pas codé en dur : ajouter un
-- niveau au référentiel déplace automatiquement le niveau terminal.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'class_exam_status') THEN
    CREATE TYPE class_exam_status AS ENUM ('examen', 'passage', 'a_qualifier');
  END IF;
END $$;

ALTER TABLE classes ADD COLUMN IF NOT EXISTS exam_status class_exam_status;

COMMENT ON COLUMN classes.exam_status IS
  'DÉRIVÉ : examen = classe d''examen (exam_id résolu) · passage = classe '
  'intermédiaire, aucun examen attendu · a_qualifier = niveau terminal SANS '
  'règle résolue -> anomalie à traiter (règle manquante ou filière non saisie).';

-- ── Niveau terminal d'un cycle (déduit du référentiel national) ────────────
CREATE OR REPLACE FUNCTION is_terminal_level(p_cycle text, p_level text)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
      FROM education_levels l
      JOIN education_cycles c ON c.id = l.cycle_id
     WHERE c.code = p_cycle
       AND l.code = p_level
       AND l.group_id IS NULL
       AND l.order_index = (
         SELECT max(l2.order_index)
           FROM education_levels l2
          WHERE l2.cycle_id = c.id AND l2.group_id IS NULL
       )
  )
$$;

COMMENT ON FUNCTION is_terminal_level IS
  'Vrai si le niveau est le dernier de son cycle (donc porteur d''un examen '
  'd''État attendu). Déduit du référentiel — aucun code de niveau en dur.';

-- ── Le trigger de dérivation calcule désormais AUSSI le statut ─────────────
CREATE OR REPLACE FUNCTION trg_classes_derive_exam() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_tutelle tutelle_enum;
BEGIN
  SELECT s.tutelle INTO v_tutelle FROM schools s WHERE s.id = NEW.school_id;

  NEW.exam_id := resolve_class_exam(
    NEW.cycle_code,
    NEW.level_code,
    NULLIF(NEW.filiere_code, ''),
    v_tutelle,
    NEW.group_id
  );

  NEW.exam_status := CASE
    WHEN NEW.exam_excluded                                   THEN 'passage'
    WHEN COALESCE(NEW.exam_override_id, NEW.exam_id) IS NOT NULL THEN 'examen'
    WHEN is_terminal_level(NEW.cycle_code, NEW.level_code)   THEN 'a_qualifier'
    ELSE 'passage'
  END::class_exam_status;

  RETURN NEW;
END $$;

-- exam_override_id / exam_excluded doivent aussi redéclencher la dérivation.
DROP TRIGGER IF EXISTS classes_derive_exam ON classes;
CREATE TRIGGER classes_derive_exam
  BEFORE INSERT OR UPDATE OF cycle_code, level_code, filiere_code, school_id,
                             exam_override_id, exam_excluded
  ON classes
  FOR EACH ROW EXECUTE FUNCTION trg_classes_derive_exam();

-- ── Recalcul global : statut inclus ────────────────────────────────────────
CREATE OR REPLACE FUNCTION recompute_class_exams() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
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

CREATE INDEX IF NOT EXISTS idx_classes_exam_status
  ON classes(exam_status) WHERE exam_status <> 'passage';

COMMIT;

SELECT recompute_class_exams() AS classes_mises_a_jour;
