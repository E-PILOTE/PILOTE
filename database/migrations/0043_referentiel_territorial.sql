-- 0043 — Référentiel territorial : 15 départements + inspections
--
-- VERROU N°2 de l'analyse fonctionnelle du 2026-07-17.
--
-- Constat : la plateforme doit produire des taux de réussite « par école,
-- inspection, direction, région, national ». Or aujourd'hui :
--   • AUCUNE table inspection / circonscription / direction départementale ;
--   • schools.department est du TEXTE LIBRE ('Brazzaville', 'Niari'…), sans
--     référentiel ni hiérarchie -> une faute de frappe crée un département
--     fantôme, et toute agrégation repose sur des chaînes non contrôlées ;
--   • la liste des 15 départements est CODÉE EN DUR dans le Dart, en double
--     (admin_schools_screen.dart et regional_project_dialog.dart) — donc
--     invisible du SQL, et deux sources de vérité qui peuvent diverger.
--
-- Cette migration pose le référentiel EN BASE. Additive : schools.department
-- (texte) est CONSERVÉE et laissée en place — rien ne casse — mais marquée
-- dépréciée au profit de schools.department_id.
--
-- SOURCE des données (vérifiée, pas mémorisée) : le Congo est passé de 12 à 15
-- départements par les lois du 8 octobre 2024 :
--   • loi n° 25-2024 -> DJOUÉ-LÉFINI    (chef-lieu Odziba)
--   • loi n° 26-2024 -> NKÉNI-ALIMA     (chef-lieu Gamboma)
--   • loi n° 27-2024 -> CONGO-OUBANGUI  (chef-lieu Mossaka)
--
-- ⚠️ Les INSPECTIONS sont créées comme STRUCTURE mais laissées VIDES : le
-- maillage réel (combien, quel ressort, primaire vs secondaire) n'a pas pu être
-- établi de source fiable. Les inventer serait pire que de les laisser vides —
-- une statistique « par inspection » fondée sur un découpage imaginaire est un
-- mensonge qui se propage. À peupler avec le MEPSA/METP.

BEGIN;

-- ── 1) Départements (référentiel national) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text NOT NULL UNIQUE,
  name         text NOT NULL,
  chef_lieu    text,
  created_by_law text,                 -- renseigné pour les 3 départements de 2024
  order_index  smallint,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE departments IS
  'Référentiel NATIONAL des 15 départements (réforme du 8 octobre 2024). '
  'Source de vérité unique — remplace les listes codées en dur côté Dart.';

INSERT INTO departments (code, name, chef_lieu, created_by_law, order_index) VALUES
  ('bouenza',        'Bouenza',        'Madingou',     NULL,             1),
  ('brazzaville',    'Brazzaville',    'Brazzaville',  NULL,             2),
  ('congo-oubangui', 'Congo-Oubangui', 'Mossaka',      'loi 27-2024',    3),
  ('cuvette',        'Cuvette',        'Owando',       NULL,             4),
  ('cuvette-ouest',  'Cuvette-Ouest',  'Ewo',          NULL,             5),
  ('djoue-lefini',   'Djoué-Léfini',   'Odziba',       'loi 25-2024',    6),
  ('kouilou',        'Kouilou',        'Loango',       NULL,             7),
  ('lekoumou',       'Lékoumou',       'Sibiti',       NULL,             8),
  ('likouala',       'Likouala',       'Impfondo',     NULL,             9),
  ('niari',          'Niari',          'Dolisie',      NULL,            10),
  ('nkeni-alima',    'Nkéni-Alima',    'Gamboma',      'loi 26-2024',   11),
  ('plateaux',       'Plateaux',       'Djambala',     NULL,            12),
  ('pointe-noire',   'Pointe-Noire',   'Pointe-Noire', NULL,            13),
  ('pool',           'Pool',           'Kinkala',      NULL,            14),
  ('sangha',         'Sangha',         'Ouésso',       NULL,            15)
ON CONFLICT (code) DO NOTHING;

-- ── 2) Inspections (structure ; données à venir du ministère) ──────────────
CREATE TABLE IF NOT EXISTS inspections (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES departments(id) ON DELETE RESTRICT,
  code          text NOT NULL UNIQUE,
  name          text NOT NULL,
  tutelle       tutelle_enum,          -- une inspection relève d'un ministère
  cycle_scope   text,                  -- 'primaire' | 'secondaire' | NULL = tous
  chef_lieu     text,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inspections_cycle_scope_chk
    CHECK (cycle_scope IS NULL OR cycle_scope IN ('primaire', 'secondaire'))
);

COMMENT ON TABLE inspections IS
  'Échelon administratif entre le département et l''école (circonscription '
  'd''inspection). VOLONTAIREMENT VIDE : le maillage réel n''a pas été établi '
  'de source fiable — à peupler avec le MEPSA/METP. Tant que la table est vide, '
  'les statistiques « par inspection » restent indisponibles (et non fausses).';

-- ── 3) Rattachement des écoles ─────────────────────────────────────────────
ALTER TABLE schools ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES departments(id);
ALTER TABLE schools ADD COLUMN IF NOT EXISTS inspection_id uuid REFERENCES inspections(id);

COMMENT ON COLUMN schools.department IS
  'DÉPRÉCIÉ — texte libre historique. Utiliser schools.department_id (FK vers '
  'le référentiel). Conservée le temps de la bascule du code Dart.';

-- Backfill depuis le texte libre. Normalisation accents + casse : les données
-- actuelles n'ont pas d'accent, mais « Lékoumou » en aura. translate() évite
-- d'ajouter une dépendance à l'extension unaccent (absente de ce projet).
UPDATE schools s
   SET department_id = d.id
  FROM departments d
 WHERE s.department_id IS NULL
   AND s.department IS NOT NULL
   AND lower(translate(trim(s.department), 'éèêëàâäîïôöûüçÉÈÊËÀÂÄÎÏÔÖÛÜÇ', 'eeeeaaaiioouucEEEEAAAIIOOUUC'))
     = lower(translate(d.name,             'éèêëàâäîïôöûüçÉÈÊËÀÂÄÎÏÔÖÛÜÇ', 'eeeeaaaiioouucEEEEAAAIIOOUUC'));

CREATE INDEX IF NOT EXISTS idx_schools_department_id ON schools(department_id);
CREATE INDEX IF NOT EXISTS idx_schools_inspection_id ON schools(inspection_id);
CREATE INDEX IF NOT EXISTS idx_inspections_department ON inspections(department_id);

-- ── 4) RLS — motif des référentiels nationaux déjà en place ────────────────
-- (cf. education_cycles : lecture ouverte au national, écriture super_admin)
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS departments_select ON departments;
CREATE POLICY departments_select ON departments FOR SELECT
  TO authenticated USING (true);          -- référentiel public : national par nature

DROP POLICY IF EXISTS departments_write ON departments;
CREATE POLICY departments_write ON departments FOR ALL
  TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS inspections_select ON inspections;
CREATE POLICY inspections_select ON inspections FOR SELECT
  TO authenticated USING (true);

DROP POLICY IF EXISTS inspections_write ON inspections;
CREATE POLICY inspections_write ON inspections FOR ALL
  TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select count(*) from departments;                    -- attendu : 15
-- select count(*) from schools where department_id is null;   -- attendu : 0
-- select d.name, count(s.id) from departments d left join schools s on s.department_id=d.id group by 1 order by 2 desc;
