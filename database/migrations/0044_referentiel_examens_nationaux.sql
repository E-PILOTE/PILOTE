-- 0044 — Référentiel des examens nationaux + règles d'éligibilité + classe d'examen dérivée
--
-- Répond à la demande « gestion des classes d'examen » (module obligatoire) et
-- pose le socle du module Examens.
-- cf. docs/superpowers/specs/2026-07-17-analyse-fonctionnelle-modules-examens.md
--
-- ── POURQUOI PAS UN BOOLÉEN SUR LA CLASSE ──────────────────────────────────
-- La demande initiale était « définir POUR CHAQUE CLASSE si elle est une classe
-- d'examen ». Pris au pied de la lettre, cela impose de ressaisir « CM2 prépare
-- le CEPE » pour chaque CM2, de chaque école, à chaque rentrée : des dizaines de
-- milliers de saisies pour une règle NATIONALE et STABLE. Une seule case oubliée
-- = des candidats non inscrits à un examen d'État.
--
-- La règle n'est pas une propriété de la classe : c'est une propriété du
-- RÉFÉRENTIEL. Ici :
--   • exam_eligibility_rules  -> la règle (cycle, niveau, filière, tutelle),
--                                datée, donc capable d'absorber une réforme
--                                sans migration de données ;
--   • classes.exam_id         -> DÉRIVÉ automatiquement par trigger (0 saisie) ;
--   • classes.exam_override_id / exam_excluded -> la surcharge reste possible.
--
-- ── DIPLÔME vs CONCOURS ────────────────────────────────────────────────────
-- Seuls les DIPLÔMES sont dérivés sur la classe : un diplôme certifie une classe
-- entière (tout CM2 présente le CEPE). Un CONCOURS (entrée en 2nde) est un choix
-- de l'ÉLÈVE, pas une propriété de la classe -> il vivra au niveau candidature.
-- C'est pourquoi classes.exam_id est simple (0..1) et non une table de liaison.
--
-- ── HONNÊTETÉ SUR LES SOURCES ──────────────────────────────────────────────
-- Les examens ci-dessous sont vérifiés (liste officielle MEPSA/METP, presse
-- nationale). Les RÈGLES, elles, sont déduites — pas lues dans un texte
-- réglementaire. Ne sont donc créées que les règles à confiance HAUTE. Les cas
-- incertains (série E, mapping filière pro -> CAP/BEP/BTF/CQP) sont
-- VOLONTAIREMENT LAISSÉS SANS RÈGLE : une classe sans règle s'affiche « à
-- qualifier », ce qui est réparable ; une classe avec une règle fausse inscrit
-- des élèves au mauvais examen, ce qui ne l'est pas.

BEGIN;

-- ── 1) Types ───────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exam_kind') THEN
    CREATE TYPE exam_kind AS ENUM ('diplome', 'concours');
  END IF;
END $$;

-- ── 2) Référentiel des examens nationaux ───────────────────────────────────
CREATE TABLE IF NOT EXISTS national_exams (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE,
  name        text NOT NULL,
  short_name  text,
  tutelle     tutelle_enum NOT NULL,
  cycle_code  text,                       -- cycle de rattachement (indicatif)
  kind        exam_kind NOT NULL DEFAULT 'diplome',
  min_average numeric(4,2),               -- moyenne d'admission (ex. 10.00 pour le BET)
  order_index smallint,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE national_exams IS
  'Référentiel NATIONAL des examens et concours d''État (MEPSA + METP). '
  'Source : liste officielle des examens congolais, vérifiée le 2026-07-17.';

INSERT INTO national_exams (code, name, short_name, tutelle, cycle_code, kind, min_average, order_index) VALUES
  ('CEPE',          'Certificat d''Études Primaires Élémentaires', 'CEPE',  'mepsa', 'primaire',      'diplome', NULL,  1),
  ('CONCOURS_2NDE', 'Concours d''entrée en Seconde',               'C. 2nde','mepsa', 'college',      'concours',NULL,  2),
  ('BEPC',          'Brevet d''Études du Premier Cycle',           'BEPC',  'mepsa', 'college',       'diplome', NULL,  3),
  ('BET',           'Brevet d''Études Techniques',                 'BET',   'metp',  'college',       'diplome', 10.00, 4),
  ('BEP',           'Brevet d''Études Professionnelles',           'BEP',   'metp',  'formation_pro', 'diplome', NULL,  5),
  ('BTF',           'Brevet de Technicien Forestier',              'BTF',   'metp',  'formation_pro', 'diplome', NULL,  6),
  ('CAP',           'Certificat d''Aptitude Professionnelle',      'CAP',   'metp',  'formation_pro', 'diplome', NULL,  7),
  ('CQP',           'Certificat de Qualification Professionnelle', 'CQP',   'metp',  'formation_pro', 'diplome', NULL,  8),
  ('BAC_G',         'Baccalauréat général',                        'Bac G', 'mepsa', 'lycee',         'diplome', NULL,  9),
  ('BAC_T',         'Baccalauréat technique',                      'Bac T', 'metp',  'lycee',         'diplome', NULL, 10),
  ('BAC_P',         'Baccalauréat professionnel',                  'Bac P', 'metp',  'lycee',         'diplome', NULL, 11)
ON CONFLICT (code) DO NOTHING;

-- ── 3) Règles d'éligibilité (le cœur : la classe d'examen configurable) ────
CREATE TABLE IF NOT EXISTS exam_eligibility_rules (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id      uuid NOT NULL REFERENCES national_exams(id) ON DELETE CASCADE,
  cycle_code   text NOT NULL,
  level_code   text NOT NULL,
  program_code text,                 -- NULL = toutes filières (joker)
  tutelle      tutelle_enum,         -- NULL = toutes tutelles (joker)
  valid_from   date,                 -- NULL = depuis toujours
  valid_to     date,                 -- NULL = toujours en vigueur
  group_id     uuid REFERENCES school_groups(id) ON DELETE CASCADE,  -- NULL = national
  note         text,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE exam_eligibility_rules IS
  'Règle « quel examen prépare une classe ». Résolution du PLUS SPÉCIFIQUE au '
  'plus général : filière (poids 2) > tutelle (poids 1) > joker. Datée '
  '(valid_from/valid_to) : une réforme = une ligne fermée + une ligne nouvelle, '
  'jamais une migration de données.';

CREATE INDEX IF NOT EXISTS idx_exam_rules_lookup
  ON exam_eligibility_rules(cycle_code, level_code) WHERE is_active;

-- Règles à CONFIANCE HAUTE uniquement (cf. en-tête).
INSERT INTO exam_eligibility_rules (exam_id, cycle_code, level_code, program_code, tutelle, note)
SELECT e.id, v.cycle_code, v.level_code, v.program_code, v.tutelle::tutelle_enum, v.note
  FROM (VALUES
    -- CM2 -> CEPE. Joker de tutelle ASSUMÉ : il n'existe pas de primaire
    -- technique, tout CM2 présente le CEPE quelle que soit la tutelle du groupe.
    ('CEPE',  'primaire', 'CM2', NULL,                NULL,    'Tout CM2 présente le CEPE (aucun primaire technique).'),
    -- 3e : la filière tranche quand elle est renseignée…
    ('BEPC',  'college',  '3e',  'college_general',   NULL,    '3e générale -> BEPC.'),
    ('BET',   'college',  '3e',  'college_technique', NULL,    '3e technique -> BET.'),
    -- …sinon la tutelle de l'école tranche (parc actuel : filière non saisie).
    ('BEPC',  'college',  '3e',  NULL,                'mepsa', 'Repli : 3e sans filière, école sous tutelle MEPSA.'),
    ('BET',   'college',  '3e',  NULL,                'metp',  'Repli : 3e sans filière, école sous tutelle METP.'),
    -- Terminale : la série tranche. A/C/D = enseignement général (confiance haute).
    ('BAC_G', 'lycee',    'Tle', 'serie_a',           NULL,    'Série A -> Baccalauréat général.'),
    ('BAC_G', 'lycee',    'Tle', 'serie_c',           NULL,    'Série C -> Baccalauréat général.'),
    ('BAC_G', 'lycee',    'Tle', 'serie_d',           NULL,    'Série D -> Baccalauréat général.'),
    -- Séries F (industrielles) et G (tertiaires) = enseignement technique.
    ('BAC_T', 'lycee',    'Tle', 'serie_f1',          NULL,    'Série F1 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_f2',          NULL,    'Série F2 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_f3',          NULL,    'Série F3 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_f4',          NULL,    'Série F4 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_f6',          NULL,    'Série F6 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_f7',          NULL,    'Série F7 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_g1',          NULL,    'Série G1 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_g2',          NULL,    'Série G2 -> Baccalauréat technique.'),
    ('BAC_T', 'lycee',    'Tle', 'serie_g3',          NULL,    'Série G3 -> Baccalauréat technique.')
  ) AS v(exam_code, cycle_code, level_code, program_code, tutelle, note)
  JOIN national_exams e ON e.code = v.exam_code
 WHERE NOT EXISTS (
   SELECT 1 FROM exam_eligibility_rules r
    WHERE r.exam_id = e.id AND r.cycle_code = v.cycle_code AND r.level_code = v.level_code
      AND r.program_code IS NOT DISTINCT FROM v.program_code
      AND r.tutelle IS NOT DISTINCT FROM v.tutelle::tutelle_enum
      AND r.group_id IS NULL
 );

-- NON MAPPÉ VOLONTAIREMENT (à valider avec le MEPSA/METP avant toute règle) :
--   • série E (« Mathématiques et Technique ») : général ou technique ? ;
--   • formation professionnelle : quelle filière -> CAP / BEP / BTF / CQP ;
--   • Baccalauréat professionnel : quel parcours y conduit.
-- Ces classes afficheront « à qualifier ». C'est le comportement voulu.

-- ── 4) Classe d'examen : dérivée + surchargeable ───────────────────────────
ALTER TABLE classes ADD COLUMN IF NOT EXISTS exam_id          uuid REFERENCES national_exams(id);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS exam_override_id uuid REFERENCES national_exams(id);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS exam_excluded    boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN classes.exam_id IS
  'DÉRIVÉ par trigger depuis exam_eligibility_rules — NE PAS SAISIR À LA MAIN. '
  'Examen effectif = exam_excluded ? NULL : coalesce(exam_override_id, exam_id).';
COMMENT ON COLUMN classes.exam_override_id IS
  'Surcharge explicite (cas particulier autorisé). Prime sur exam_id.';
COMMENT ON COLUMN classes.exam_excluded IS
  'Exclut la classe de tout examen (ex. classe de redoublants non présentés).';

CREATE INDEX IF NOT EXISTS idx_classes_exam_id ON classes(exam_id) WHERE exam_id IS NOT NULL;

-- ── 5) Résolution (source de vérité UNIQUE de la logique) ──────────────────
CREATE OR REPLACE FUNCTION resolve_class_exam(
  p_cycle   text,
  p_level   text,
  p_program text,
  p_tutelle tutelle_enum,
  p_group   uuid DEFAULT NULL,
  p_on      date DEFAULT CURRENT_DATE
) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT r.exam_id
    FROM exam_eligibility_rules r
    JOIN national_exams e ON e.id = r.exam_id
   WHERE r.is_active
     AND e.is_active
     AND e.kind = 'diplome'                       -- un concours ne définit pas une classe
     AND r.cycle_code = p_cycle
     AND r.level_code = p_level
     AND (r.program_code IS NULL OR r.program_code = p_program)
     AND (r.tutelle     IS NULL OR r.tutelle     = p_tutelle)
     AND (r.group_id    IS NULL OR r.group_id    = p_group)   -- règle locale > nationale
     AND (r.valid_from  IS NULL OR r.valid_from <= p_on)
     AND (r.valid_to    IS NULL OR r.valid_to   >= p_on)
   ORDER BY (r.group_id IS NOT NULL)::int * 4       -- surcharge de groupe d'abord
          + (r.program_code IS NOT NULL)::int * 2   -- puis filière
          + (r.tutelle IS NOT NULL)::int            -- puis tutelle
            DESC,
            r.created_at DESC
   LIMIT 1
$$;

COMMENT ON FUNCTION resolve_class_exam IS
  'Résout l''examen (diplôme) d''une classe, du plus spécifique au plus général. '
  'Unique implémentation de la logique : le trigger et les recalculs l''appellent, '
  'le client lit le résultat dérivé — aucune règle dupliquée côté Dart.';

-- ── 6) Trigger de dérivation ───────────────────────────────────────────────
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
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS classes_derive_exam ON classes;
CREATE TRIGGER classes_derive_exam
  BEFORE INSERT OR UPDATE OF cycle_code, level_code, filiere_code, school_id
  ON classes
  FOR EACH ROW EXECUTE FUNCTION trg_classes_derive_exam();

-- ── 7) Recalcul global (après changement de règle ou de tutelle) ───────────
CREATE OR REPLACE FUNCTION recompute_class_exams() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  WITH resolved AS (
    SELECT c.id,
           resolve_class_exam(c.cycle_code, c.level_code,
                              NULLIF(c.filiere_code, ''), s.tutelle, c.group_id) AS new_exam
      FROM classes c
      JOIN schools s ON s.id = c.school_id
  )
  UPDATE classes c
     SET exam_id = r.new_exam, updated_at = now()
    FROM resolved r
   WHERE c.id = r.id
     AND c.exam_id IS DISTINCT FROM r.new_exam;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

COMMENT ON FUNCTION recompute_class_exams IS
  'Recalcule la classe d''examen de TOUTES les classes. À appeler après toute '
  'modification des règles ou de la tutelle d''une école.';

-- ── 8) RLS ─────────────────────────────────────────────────────────────────
ALTER TABLE national_exams        ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_eligibility_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS national_exams_select ON national_exams;
CREATE POLICY national_exams_select ON national_exams FOR SELECT
  TO authenticated USING (true);                      -- référentiel national
DROP POLICY IF EXISTS national_exams_write ON national_exams;
CREATE POLICY national_exams_write ON national_exams FOR ALL
  TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS exam_rules_select ON exam_eligibility_rules;
CREATE POLICY exam_rules_select ON exam_eligibility_rules FOR SELECT
  TO authenticated USING (group_id IS NULL OR group_id = auth_group_id() OR is_super_admin());
DROP POLICY IF EXISTS exam_rules_write ON exam_eligibility_rules;
CREATE POLICY exam_rules_write ON exam_eligibility_rules FOR ALL
  TO authenticated
  USING      (is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id()))
  WITH CHECK (is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id()));

COMMIT;

-- Application initiale de la dérivation au parc existant.
SELECT recompute_class_exams() AS classes_qualifiees;
