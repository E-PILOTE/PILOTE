-- 0048 — Module STAGES + catégorie FORMATION PROFESSIONNELLE
--
-- ── POURQUOI CE MODULE EST BLOQUANT, PAS CONFORTABLE ───────────────────────
-- La note d'information METP 2025-2026 exige, pour TOUT baccalauréat, « deux
-- copies légalisées du diplôme (BEPC, BEMG, BET, BEP) » ET une **ATTESTATION DE
-- STAGE**. Sans ce module, le module Examens (0044→0047) ne peut pas constituer
-- un dossier de bac professionnel : la pièce n'existe nulle part dans le système.
-- C'est une dépendance DURE, identifiée par l'analyse du 2026-07-17 (§5).
--
-- ── POURQUOI UNE CATÉGORIE DÉDIÉE (correction de l'analyse) ────────────────
-- L'analyse rangeait « stages » dans PATRIMOINE & LOGISTIQUE. C'était une
-- erreur : un stage est un acte PÉDAGOGIQUE (convention, tuteurs, évaluation,
-- attestation), pas de la logistique.
-- Surtout, l'analyse avait manqué un fait structurel : la plateforme est une
-- commande MEPSA **+ METP**, le METP pèse 14 écoles sur 24 en base… et n'a
-- AUCUNE catégorie dédiée. FORMATION PROFESSIONNELLE comble ce trou et accueille
-- la famille à venir (entreprises partenaires, ateliers, alternance).
--
-- ── REVENU ─────────────────────────────────────────────────────────────────
-- stages -> plans `pro` et `institutionnel` uniquement (comme `examens`). Une
-- école technique/professionnelle a besoin des DEUX pour fonctionner : c'est le
-- levier de montée en gamme du parc METP, qui est le plus gros tenant réel.

BEGIN;

-- ── 1) Types ───────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'internship_status') THEN
    CREATE TYPE internship_status AS ENUM
      ('prevu', 'en_cours', 'termine', 'interrompu', 'valide');
  END IF;
END $$;

-- ── 2) Entreprises d'accueil ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS internship_companies (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      uuid NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id     uuid REFERENCES schools(id) ON DELETE CASCADE,  -- NULL = partagée au groupe
  name          text NOT NULL,
  sector        text,
  address       text,
  city          text,
  department_id uuid REFERENCES departments(id),
  contact_name  text,
  contact_phone text,
  contact_email text,
  notes         text,
  is_active     boolean NOT NULL DEFAULT true,
  created_by    uuid REFERENCES profiles(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE internship_companies IS
  'Entreprises d''accueil des stagiaires. school_id NULL = entreprise partagée '
  'par toutes les écoles du groupe (un partenaire sert souvent plusieurs écoles).';

-- ── 3) Stages ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS internships (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id             uuid NOT NULL REFERENCES school_groups(id) ON DELETE CASCADE,
  school_id            uuid NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id           uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_id             uuid REFERENCES classes(id) ON DELETE SET NULL,
  academic_year_id     uuid REFERENCES academic_years(id) ON DELETE SET NULL,
  company_id           uuid REFERENCES internship_companies(id) ON DELETE SET NULL,
  title                text,
  start_date           date,
  end_date             date,
  school_tutor_id      uuid REFERENCES profiles(id),   -- tuteur pédagogique
  company_tutor_name   text,                           -- tuteur en entreprise
  company_tutor_phone  text,
  convention_signed_at date,
  convention_url       text,
  status               internship_status NOT NULL DEFAULT 'prevu',
  -- L'ATTESTATION : la pièce que le dossier d'examen réclame.
  attestation_issued_at date,
  attestation_url       text,
  evaluation_grade     numeric(4,2),
  evaluation_comment   text,
  notes                text,
  created_by           uuid REFERENCES profiles(id),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT internships_dates_chk
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

COMMENT ON COLUMN internships.attestation_issued_at IS
  'Date de délivrance de l''attestation de stage. Pièce OBLIGATOIRE du dossier '
  'de baccalauréat (note METP) -> consommée par le module Examens.';

CREATE INDEX IF NOT EXISTS idx_internships_school  ON internships(school_id);
CREATE INDEX IF NOT EXISTS idx_internships_group   ON internships(group_id);
CREATE INDEX IF NOT EXISTS idx_internships_student ON internships(student_id);
CREATE INDEX IF NOT EXISTS idx_internships_class   ON internships(class_id);
CREATE INDEX IF NOT EXISTS idx_internship_companies_group ON internship_companies(group_id);

-- ── 4) Le pont Stages -> Examens ───────────────────────────────────────────
-- Une attestation VALIDE = stage terminé/validé ET attestation délivrée.
CREATE OR REPLACE FUNCTION has_internship_attestation(p_student uuid)
RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM internships i
     WHERE i.student_id = p_student
       AND i.attestation_issued_at IS NOT NULL
       AND i.status IN ('termine', 'valide')
  )
$$;

COMMENT ON FUNCTION has_internship_attestation IS
  'Vrai si l''élève détient une attestation de stage délivrée. Consommé par le '
  'module Examens pour signaler un dossier de bac professionnel incomplet.';

-- ── 5) RLS — motif tenant standard ─────────────────────────────────────────
ALTER TABLE internship_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE internships          ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS internship_companies_select ON internship_companies;
CREATE POLICY internship_companies_select ON internship_companies FOR SELECT
  TO authenticated USING (is_super_admin() OR group_id = auth_group_id());
DROP POLICY IF EXISTS internship_companies_write ON internship_companies;
CREATE POLICY internship_companies_write ON internship_companies FOR ALL
  TO authenticated
  USING      (is_super_admin() OR group_id = auth_group_id())
  WITH CHECK (is_super_admin() OR group_id = auth_group_id());

DROP POLICY IF EXISTS internships_select ON internships;
CREATE POLICY internships_select ON internships FOR SELECT
  TO authenticated USING (is_super_admin() OR group_id = auth_group_id());
DROP POLICY IF EXISTS internships_write ON internships;
CREATE POLICY internships_write ON internships FOR ALL
  TO authenticated
  USING      (is_super_admin() OR group_id = auth_group_id())
  WITH CHECK (is_super_admin() OR group_id = auth_group_id());

-- ── 6) CATALOGUE : catégorie -> module -> plans (les 3 étages, sans oubli) ──
-- Placée après EXAMENS (4) : orientation -> stage -> examen suit le parcours.
UPDATE module_categories SET display_order = display_order + 1, updated_at = now()
 WHERE display_order >= 5;

INSERT INTO module_categories (name, slug, icon, display_order)
SELECT 'FORMATION PROFESSIONNELLE', 'formation-pro', '🔧', 5
 WHERE NOT EXISTS (SELECT 1 FROM module_categories WHERE slug = 'formation-pro');

INSERT INTO modules (category_id, name, slug, description, icon, display_order, is_active)
SELECT c.id,
       'Stages',
       'stages',
       'Stages en entreprise : conventions, tuteurs, suivi, évaluation et '
       'attestations. L''attestation est une pièce obligatoire du dossier de '
       'baccalauréat professionnel.',
       '🔧',                        -- icon = varchar(10), emoji comme tous les autres
       1,
       true
  FROM module_categories c
 WHERE c.slug = 'formation-pro'
   AND NOT EXISTS (SELECT 1 FROM modules WHERE slug = 'stages');

-- Étage 3 : le PLAN (sans quoi le module n'est vendu à personne).
INSERT INTO plan_modules (plan_id, module_id)
SELECT p.id, m.id
  FROM subscription_plans p
  CROSS JOIN modules m
 WHERE m.slug = 'stages'
   AND p.slug IN ('pro', 'institutionnel')
   AND NOT EXISTS (
     SELECT 1 FROM plan_modules pm WHERE pm.plan_id = p.id AND pm.module_id = m.id
   );

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select c.display_order, c.slug, count(m.id) from module_categories c
--   left join modules m on m.category_id=c.id group by 1,2 order by 1;
-- select p.slug, count(*) from subscription_plans p join plan_modules pm on pm.plan_id=p.id group by 1;
-- select m.slug, string_agg(p.slug,', ') from modules m
--   join plan_modules pm on pm.module_id=m.id join subscription_plans p on p.id=pm.plan_id
--  where m.slug in ('examens','stages') group by 1;
