-- 0046 — Sessions, centres et candidatures d'examen (le pivot école ↔ ministère)
--
-- ── LA DÉCISION STRUCTURANTE ───────────────────────────────────────────────
-- Un examen national TRAVERSE les tenants : un centre accueille des candidats de
-- plusieurs groupes, un taux de réussite national agrège tout le pays. Or
-- E-PILOTE isole par group_id (RLS auth_group_id()). Les deux sont vrais et
-- incompatibles — c'est pourquoi OpenEMIS sépare « Exams » de « Core ».
--
-- exam_candidates est le SEUL point de jonction : il porte à la fois
--   • group_id / school_id -> l'école ne voit QUE ses élèves (RLS) ;
--   • session_id / center_id / candidate_number -> le ministère agrège au national.
-- C'est le seul endroit où l'isolation tenant est délibérément traversée, et
-- uniquement en lecture super_admin.
--
-- ── POURQUOI PAS DE FK VERS academic_years ─────────────────────────────────
-- academic_years est TENANT-SCOPÉ (group_id + school_id). Une session d'examen
-- est NATIONALE : la lier à l'année d'un groupe n'aurait aucun sens (quelle
-- ligne choisir parmi 7 groupes ?). D'où year_label ('2025-2026'), assumé.
--
-- ── SOURCES (vérifiées le 2026-07-17) ──────────────────────────────────────
-- Note d'information METP 2025-2026 : inscriptions du 8 déc. 2025 au 14 févr.
-- 2026 ; limites d'âge 24 ans (bacs), 20 ans (BET/CAP), 21 ans (autres brevets) ;
-- dossier = 2 photocopies d'acte de naissance, 4 photos, chemise, enveloppe A4,
-- frais. Bacs : copies légalisées du diplôme antérieur + ATTESTATION DE STAGE.
-- Session BET 2026 : écrits 23→27 juin, pratiques 30 juin→4 juillet.
-- Les dates NON vérifiées restent NULL — jamais inventées.

BEGIN;

-- ── 1) Types ───────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exam_session_status') THEN
    CREATE TYPE exam_session_status AS ENUM
      ('draft', 'open', 'closed', 'running', 'published', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exam_dossier_status') THEN
    CREATE TYPE exam_dossier_status AS ENUM
      ('incomplet', 'complet', 'depose', 'valide', 'rejete');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exam_result') THEN
    CREATE TYPE exam_result AS ENUM
      ('admis', 'ajourne', 'absent', 'fraude', 'en_attente');
  END IF;
END $$;

-- ── 2) Sessions ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS exam_sessions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id                uuid NOT NULL REFERENCES national_exams(id) ON DELETE RESTRICT,
  year_label             text NOT NULL,                 -- '2025-2026' (national)
  registration_opens_at  date,
  registration_closes_at date,
  written_from           date,
  written_to             date,
  practical_from         date,
  practical_to           date,
  results_published_at   date,
  max_age                smallint,                      -- 24 bacs · 20 BET/CAP · 21 autres
  age_reference_date     date,                          -- cf. COMMENT : date de calcul de l'âge
  fee_amount             numeric(10,2),                 -- frais d'inscription (XAF)
  required_documents     jsonb NOT NULL DEFAULT '[]'::jsonb,
  status                 exam_session_status NOT NULL DEFAULT 'draft',
  notes                  text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_sessions_unique UNIQUE (exam_id, year_label),
  CONSTRAINT exam_sessions_window_chk
    CHECK (registration_closes_at IS NULL OR registration_opens_at IS NULL
           OR registration_closes_at >= registration_opens_at)
);

COMMENT ON COLUMN exam_sessions.age_reference_date IS
  'Date à laquelle l''âge du candidat est apprécié pour max_age. ⚠️ La règle '
  'exacte n''a PAS été trouvée dans un texte officiel : elle est donc rendue '
  'PARAMÉTRABLE plutôt que devinée. NULL -> l''âge est apprécié à written_from.';

COMMENT ON COLUMN exam_sessions.required_documents IS
  'Pièces du dossier : [{"code":"acte_naissance","label":"...","copies":2}]. '
  'Paramétrable car réglementaire et variable selon le diplôme.';

-- ── 3) Centres (permanents : ~606 centres CEPE, ~59 BET — pas recréés chaque an) ──
CREATE TABLE IF NOT EXISTS exam_centers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text UNIQUE,
  name          text NOT NULL,
  department_id uuid REFERENCES departments(id),
  school_id     uuid REFERENCES schools(id),   -- un centre est souvent hébergé par une école
  tutelle       tutelle_enum,
  capacity      integer,
  latitude      double precision,
  longitude     double precision,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE exam_centers IS
  'Centres d''examen — registre NATIONAL et PERMANENT (un centre traverse les '
  'sessions et les groupes). Volontairement vide : à peupler par le ministère.';

-- ── 4) Candidatures — LE PIVOT ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS exam_candidates (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id       uuid NOT NULL REFERENCES exam_sessions(id) ON DELETE CASCADE,
  student_id       uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  group_id         uuid NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id         uuid REFERENCES classes(id) ON DELETE SET NULL,
  candidate_number text,                        -- attribué par le ministère
  center_id        uuid REFERENCES exam_centers(id),
  dossier_status   exam_dossier_status NOT NULL DEFAULT 'incomplet',
  missing_documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_repeater      boolean NOT NULL DEFAULT false,
  registered_at    timestamptz NOT NULL DEFAULT now(),
  submitted_at     timestamptz,
  result           exam_result NOT NULL DEFAULT 'en_attente',
  average          numeric(4,2),
  mention          text,
  decided_at       timestamptz,
  notes            text,
  created_by       uuid REFERENCES profiles(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_candidates_unique UNIQUE (session_id, student_id),
  CONSTRAINT exam_candidates_number_unique UNIQUE (session_id, candidate_number)
);

COMMENT ON TABLE exam_candidates IS
  'Candidature d''un élève à une session d''examen national. PIVOT : group_id/'
  'school_id -> l''école ne voit que ses élèves (RLS) ; session_id/center_id -> '
  'le ministère agrège au national. Seul point de jonction entre les deux mondes.';

CREATE INDEX IF NOT EXISTS idx_exam_candidates_session ON exam_candidates(session_id);
CREATE INDEX IF NOT EXISTS idx_exam_candidates_group   ON exam_candidates(group_id);
CREATE INDEX IF NOT EXISTS idx_exam_candidates_school  ON exam_candidates(school_id);
CREATE INDEX IF NOT EXISTS idx_exam_candidates_student ON exam_candidates(student_id);
CREATE INDEX IF NOT EXISTS idx_exam_candidates_center  ON exam_candidates(center_id);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam      ON exam_sessions(exam_id);

-- ── 5) Éligibilité par âge (paramétrable, non devinée) ─────────────────────
CREATE OR REPLACE FUNCTION exam_age_at_session(p_dob date, p_session uuid)
RETURNS integer
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN p_dob IS NULL THEN NULL
    ELSE extract(year FROM age(
           COALESCE(s.age_reference_date, s.written_from, CURRENT_DATE), p_dob))::int
  END
    FROM exam_sessions s
   WHERE s.id = p_session
$$;

COMMENT ON FUNCTION exam_age_at_session IS
  'Âge du candidat à la date d''appréciation de la session (paramétrable). '
  'Sert au contrôle max_age (24 bacs / 20 BET-CAP / 21 autres brevets).';

-- ── 6) RLS ─────────────────────────────────────────────────────────────────
ALTER TABLE exam_sessions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_centers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_candidates ENABLE ROW LEVEL SECURITY;

-- Sessions et centres : référentiel national -> lecture ouverte, écriture ministère.
DROP POLICY IF EXISTS exam_sessions_select ON exam_sessions;
CREATE POLICY exam_sessions_select ON exam_sessions FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS exam_sessions_write ON exam_sessions;
CREATE POLICY exam_sessions_write ON exam_sessions FOR ALL
  TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS exam_centers_select ON exam_centers;
CREATE POLICY exam_centers_select ON exam_centers FOR SELECT
  TO authenticated USING (true);
DROP POLICY IF EXISTS exam_centers_write ON exam_centers;
CREATE POLICY exam_centers_write ON exam_centers FOR ALL
  TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

-- Candidatures : l'école ne voit QUE les siennes. Le ministère voit tout.
DROP POLICY IF EXISTS exam_candidates_select ON exam_candidates;
CREATE POLICY exam_candidates_select ON exam_candidates FOR SELECT
  TO authenticated
  USING (is_super_admin() OR group_id = auth_group_id());

DROP POLICY IF EXISTS exam_candidates_write ON exam_candidates;
CREATE POLICY exam_candidates_write ON exam_candidates FOR ALL
  TO authenticated
  USING      (is_super_admin() OR group_id = auth_group_id())
  WITH CHECK (is_super_admin() OR group_id = auth_group_id());

-- ── 7) Session RÉELLE et VÉRIFIÉE (BET 2025-2026) ──────────────────────────
-- Seule session dont TOUTES les dates sont sourcées. Les autres examens
-- n'ont pas de session : le ministère les créera. Aucune date inventée.
INSERT INTO exam_sessions (
  exam_id, year_label, registration_opens_at, registration_closes_at,
  written_from, written_to, practical_from, practical_to,
  max_age, required_documents, status, notes
)
SELECT e.id, '2025-2026', DATE '2025-12-08', DATE '2026-02-14',
       DATE '2026-06-23', DATE '2026-06-27', DATE '2026-06-30', DATE '2026-07-04',
       20,
       '[{"code":"acte_naissance","label":"Photocopie d''acte de naissance","copies":2},
         {"code":"photos","label":"Photos d''identité couleur","copies":4},
         {"code":"chemise","label":"Chemise cartonnée","copies":1},
         {"code":"enveloppe","label":"Enveloppe format A4","copies":1},
         {"code":"frais","label":"Frais d''inscription","copies":1}]'::jsonb,
       'open',
       'Session METP 2025-2026. Dates vérifiées (note d''information METP + presse nationale).'
  FROM national_exams e
 WHERE e.code = 'BET'
   AND NOT EXISTS (SELECT 1 FROM exam_sessions s WHERE s.exam_id = e.id AND s.year_label = '2025-2026');

COMMIT;
