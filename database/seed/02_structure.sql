-- ════════════════════════════════════════════════════════════════════════════
--  SEED 02 — LA STRUCTURE ACADÉMIQUE : cycles, niveaux, matières, classes
--
--  ── CE QUI DÉCIDE DE TOUT : LE CYCLE HÉBERGÉ ───────────────────────────────
--  Une école primaire n'a pas de 3ᵉ, un lycée technique n'a pas de CP1. Le
--  jeu précédent l'ignorait, et l'incohérence remontait jusque dans les
--  statistiques d'examen. Chaque établissement déclare donc explicitement les
--  cycles qu'il héberge — rien n'est déduit de son nom.
--
--  ── LES SÉRIES SONT PORTÉES PAR LA CLASSE, PAS PAR LE NIVEAU ───────────────
--  ⚠️ Le référentiel n'a que trois niveaux de lycée (2nde, 1ère, Tle) : la
--  série (F2 Électronique, G2 Comptabilité…) vit sur la CLASSE, dans
--  `filiere_code` / `filiere_label`. C'est ce que lit le cockpit ministériel
--  pour agréger la réussite par filière. Créer un niveau par série
--  dédoublerait la structure et fausserait tous les comptes de niveau.
--
--  ── LA CLASSE D'EXAMEN N'EST PAS SAISIE ────────────────────────────────────
--  `exam_status` et `exam_id` sont DÉRIVÉS par trigger à partir du niveau et
--  du cycle. On ne les écrit pas ici : les poser à la main ferait diverger la
--  démonstration du mécanisme qu'elle est censée montrer.
--
--  ── DEUX ANNÉES, MÊME STRUCTURE ────────────────────────────────────────────
--  Les classes sont créées pour 2025-2026 ET 2026-2027. Sans structure d'accueil
--  l'année suivante, l'écran de clôture d'examen annonce « quitte
--  l'établissement » à une classe entière d'admis.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE v_me uuid;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin'
   ORDER BY created_at LIMIT 1;
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Aucun super_admin en base : créez-le avant de semer.';
  END IF;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, false);
END $$;

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
--  1. QUELS CYCLES POUR QUEL ÉTABLISSEMENT
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_school_cycle(school_key text, cycle_code text) ON COMMIT DROP;

INSERT INTO tmp_school_cycle VALUES
  -- METP : technique uniquement. Les collèges d'enseignement technique
  -- préparent le BET en 3ᵉ ; les lycées et instituts mènent au Bac T&P.
  ('metp-lt-1er-mai','lycee'), ('metp-lti-sankara','lycee'),
  ('metp-ltc-bacongo','lycee'), ('metp-lt-pnr','lycee'),
  ('metp-iti-loandjili','lycee'), ('metp-lt-dolisie','lycee'),
  ('metp-lta-owando','lycee'), ('metp-lt-kinkala','lycee'),
  ('metp-lt-djambala','lycee'),
  ('metp-cet-nkayi','college'), ('metp-cet-ouesso','college'),
  ('metp-cet-sibiti','college'),
  -- MEPSA : primaire (CEPE) et collège général (BEPC).
  ('mepsa-ep-revolution','primaire'), ('mepsa-ep-makelekele','primaire'),
  ('mepsa-ep-tie-tie','primaire'),   ('mepsa-ep-madingou','primaire'),
  ('mepsa-ep-gamboma','primaire'),   ('mepsa-ep-mossaka','primaire'),
  ('mepsa-ep-odziba','primaire'),
  ('mepsa-ceg-moungali','college'),  ('mepsa-ceg-talangai','college'),
  ('mepsa-ceg-loandjili','college'), ('mepsa-ceg-dolisie','college'),
  ('mepsa-ceg-impfondo','college'),  ('mepsa-ceg-ewo','college'),
  ('mepsa-ceg-loango','college'),
  -- Établissements de référence et complexes : primaire ET collège.
  ('sav-ep','primaire'), ('sav-ceg','college'),
  ('edec-bacongo','primaire'), ('edec-bacongo','college'),
  ('edec-makelekele','primaire'), ('edec-makelekele','college'),
  -- Privé : de la maternelle au baccalauréat général.
  ('sp-ep','primaire'), ('sp-ceg','college'), ('sp-lycee','lycee'),
  ('hz-ep','primaire'), ('hz-ceg','college'), ('hz-lycee','lycee'),
  ('bt-ep','primaire'), ('bt-ep','college');

INSERT INTO school_cycles (id, school_id, cycle_id, group_id)
SELECT seed_uuid('sc:' || t.school_key || ':' || t.cycle_code),
       s.id, c.id, s.group_id
FROM tmp_school_cycle t
JOIN schools s ON s.id = seed_uuid('school:' || t.school_key)
JOIN education_cycles c ON c.code = t.cycle_code AND c.group_id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
--  2. LES NIVEAUX DE CHAQUE ÉTABLISSEMENT
--
--  Recopiés du référentiel national, pas réinventés : c'est ce qui garantit
--  qu'un CM2 de Mossaka et un CM2 de Pointe-Noire sont le même niveau, donc
--  comparables dans un agrégat national.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO school_levels (id, group_id, school_id, name, slug, code,
                           order_index, display_order, cycle_id, is_active)
SELECT seed_uuid('sl:' || t.school_key || ':' || l.code),
       s.group_id, s.id, l.name,
       lower(t.school_key || '-' || l.code), l.code,
       l.order_index, l.order_index, c.id, true
FROM tmp_school_cycle t
JOIN schools s ON s.id = seed_uuid('school:' || t.school_key)
JOIN education_cycles c ON c.code = t.cycle_code AND c.group_id IS NULL
JOIN education_levels l ON l.cycle_id = c.id AND l.group_id IS NULL
                        AND l.program_id IS NULL
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, order_index = EXCLUDED.order_index,
  cycle_id = EXCLUDED.cycle_id, is_active = true, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  3. LES CLASSES, POUR LES DEUX ANNÉES
--
--  Une classe par niveau, deux (A et B) dans les établissements de plus de
--  600 places — c'est la réalité congolaise : les effectifs urbains obligent au
--  dédoublement, pas les écoles rurales.
--
--  Les séries ne s'appliquent qu'au lycée. Un lycée TECHNIQUE ouvre F2/F3/G2 ;
--  un lycée général A/C/D. La 2nde reste indifférenciée : l'orientation se joue
--  en fin de seconde.
-- ────────────────────────────────────────────────────────────────────────────

-- ⚠️ `code` porte le code du RÉFÉRENTIEL (`serie_f2`), pas l'abréviation
-- d'usage. C'est lui que `resolve_class_exam()` compare aux règles
-- d'éligibilité : avec « F2 » la Terminale ne se rattachait à AUCUN examen et
-- restait « à qualifier », donc absente du cockpit ministériel. `short` sert au
-- nom de la classe, `label` à l'affichage.
CREATE TEMP TABLE tmp_serie(school_key text, code text, short text, label text)
  ON COMMIT DROP;
INSERT INTO tmp_serie VALUES
  ('metp-lt-1er-mai','serie_f2','F2','F2 — Électronique'),
  ('metp-lt-1er-mai','serie_g2','G2','G2 — Comptabilité'),
  ('metp-lti-sankara','serie_f1','F1','F1 — Construction mécanique'),
  ('metp-lti-sankara','serie_f3','F3','F3 — Électrotechnique'),
  ('metp-ltc-bacongo','serie_g1','G1','G1 — Secrétariat'),
  ('metp-ltc-bacongo','serie_g2','G2','G2 — Comptabilité'),
  ('metp-lt-pnr','serie_f2','F2','F2 — Électronique'),
  ('metp-lt-pnr','serie_f4','F4','F4 — Génie civil'),
  ('metp-iti-loandjili','serie_f1','F1','F1 — Construction mécanique'),
  ('metp-lt-dolisie','serie_f3','F3','F3 — Électrotechnique'),
  ('metp-lta-owando','serie_f7','F7','F7 — Sciences agronomiques'),
  ('metp-lt-kinkala','serie_f2','F2','F2 — Électronique'),
  ('metp-lt-djambala','serie_g3','G3','G3 — Commerce'),
  ('sp-lycee','serie_a','A','A — Littéraire'),
  ('sp-lycee','serie_d','D','D — Sciences de la vie'),
  ('hz-lycee','serie_c','C','C — Mathématiques'),
  ('hz-lycee','serie_d','D','D — Sciences de la vie');

-- Les classes voulues sont d'abord CALCULÉES, puis comparées à l'existant.
-- Sans cette étape, changer une règle de nommage laisse les anciennes classes
-- en place : elles gardent leurs élèves, faussent les effectifs, et la
-- contrainte d'unicité (école, année, nom) finit par bloquer le seed.
CREATE TEMP TABLE tmp_classes ON COMMIT DROP AS
SELECT
  seed_uuid('class:' || t.school_key || ':' || l.code || ':' || COALESCE(f.code,'X')
            || ':' || sfx.suffix || ':' || y.label) AS id,
  s.group_id, s.id AS school_id, y.id AS academic_year_id, sl.id AS level_id,
  l.code || ' ' || COALESCE(f.short, sfx.suffix) AS name,
  (CASE WHEN s.capacity >= 600 THEN 48 ELSE 42 END)::smallint AS capacity,
  c.code AS cycle_code, l.code AS level_code, l.order_index AS level_order,
  f.code AS filiere_code, f.label AS filiere_label
FROM tmp_school_cycle t
JOIN schools s ON s.id = seed_uuid('school:' || t.school_key)
JOIN education_cycles c ON c.code = t.cycle_code AND c.group_id IS NULL
JOIN education_levels l ON l.cycle_id = c.id AND l.group_id IS NULL
                        AND l.program_id IS NULL
JOIN school_levels sl ON sl.id = seed_uuid('sl:' || t.school_key || ':' || l.code)
JOIN academic_years y ON y.group_id = s.group_id
LEFT JOIN tmp_serie f ON c.code = 'lycee' AND l.code <> '2nde'
                      AND f.school_key = t.school_key
JOIN (VALUES ('A'), ('B')) AS sfx(suffix)
  ON sfx.suffix = 'A' OR (s.capacity >= 600 AND c.code <> 'lycee')
WHERE f.code IS NOT NULL OR c.code <> 'lycee' OR l.code = '2nde';

-- Retrait des classes devenues sans objet. Celles qui portent déjà des
-- inscriptions sont épargnées : on ne détruit pas la scolarité d'un élève pour
-- faire place nette.
DELETE FROM classes c
 WHERE c.school_id IN (SELECT DISTINCT school_id FROM tmp_classes)
   AND c.id NOT IN (SELECT id FROM tmp_classes)
   AND NOT EXISTS (SELECT 1 FROM class_enrollments e WHERE e.class_id = c.id);

INSERT INTO classes (id, group_id, school_id, academic_year_id, level_id, name,
                     capacity, cycle_code, level_code, level_order,
                     filiere_code, filiere_label, is_active)
SELECT id, group_id, school_id, academic_year_id, level_id, name, capacity,
       cycle_code, level_code, level_order, filiere_code, filiere_label, true
FROM tmp_classes
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, capacity = EXCLUDED.capacity,
  filiere_code = EXCLUDED.filiere_code, filiere_label = EXCLUDED.filiere_label,
  is_active = true, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  4. LES MATIÈRES
--
--  Portées par le GROUPE (school_id NULL) : un réseau enseigne le même
--  programme dans toutes ses écoles, et le bulletin doit pouvoir se comparer
--  d'un établissement à l'autre. Le coefficient suit le poids réel au Congo —
--  les matières techniques pèsent lourd dans les séries F et G.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO subjects (id, group_id, name, slug, coefficient, display_order, is_active)
SELECT seed_uuid('subj:' || g.slug || ':' || m.slug), g.id, m.name, m.slug,
       m.coef, m.ord, true
FROM school_groups g
CROSS JOIN (VALUES
  ('Français',                'francais',    4, 1),
  ('Mathématiques',           'maths',       4, 2),
  ('Anglais',                 'anglais',     2, 3),
  ('Histoire-Géographie',     'hist-geo',    2, 4),
  ('Sciences de la Vie et de la Terre', 'svt', 2, 5),
  ('Physique-Chimie',         'physique',    3, 6),
  ('Éducation Civique',       'civique',     1, 7),
  ('Éducation Physique et Sportive', 'eps',   1, 8)
) AS m(name, slug, coef, ord)
WHERE g.slug IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, coefficient = EXCLUDED.coefficient, is_active = true,
  updated_at = now();

-- Les matières professionnelles n'existent que là où elles s'enseignent.
INSERT INTO subjects (id, group_id, name, slug, coefficient, display_order, is_active)
SELECT seed_uuid('subj:metp:' || m.slug), g.id, m.name, m.slug, m.coef, m.ord, true
FROM school_groups g
CROSS JOIN (VALUES
  ('Technologie industrielle',      'techno-indus', 5,  9),
  ('Dessin technique',              'dessin-tech',  4, 10),
  ('Travaux pratiques d''atelier',  'tp-atelier',   5, 11),
  ('Comptabilité générale',         'compta-gen',   5, 12),
  ('Économie d''entreprise',        'eco-entrep',   3, 13)
) AS m(name, slug, coef, ord)
WHERE g.slug = 'metp'
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, coefficient = EXCLUDED.coefficient, is_active = true,
  updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT y.label AS annee, c.cycle_code, count(*) AS classes,
       count(*) FILTER (WHERE c.exam_status = 'examen') AS classes_examen
FROM classes c JOIN academic_years y ON y.id = c.academic_year_id
GROUP BY y.label, c.cycle_code ORDER BY y.label, c.cycle_code;
