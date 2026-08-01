-- ════════════════════════════════════════════════════════════════════════════
--  SEED 01 — LES ÉTABLISSEMENTS, LES ANNÉES SCOLAIRES, LES PROFILS D'ACCÈS
--
--  ── LA COHÉRENCE DE TUTELLE, QUI N'EST PAS UN DÉTAIL ───────────────────────
--  Le jeu de données précédent mélangeait tout : le METP — ministère de
--  l'enseignement TECHNIQUE — hébergeait un « Collège Public de Kinkala » et
--  une « École Privée Saint-Exupéry », et le MEPSA un « Lycée Technique de
--  Brazzaville ». Devant un ministère, cette seule ligne suffit à discréditer
--  la démonstration.
--
--  La règle appliquée ici, sans exception :
--    • METP  → lycées techniques, instituts et collèges d'enseignement
--              TECHNIQUE. Jamais de primaire, jamais de collège général.
--    • MEPSA → écoles primaires et collèges d'enseignement GÉNÉRAL.
--    • Réseaux privés → primaire et général, tutelle MEPSA (c'est elle qui
--              agrée le privé sur ce segment).
--
--  ── LA GÉOGRAPHIE EST RÉELLE ───────────────────────────────────────────────
--  Les coordonnées viennent de `assets/geo/congo_places.json` (6 966 localités)
--  et pointent sur le vrai chef-lieu. La carte nationale n'a d'intérêt que si
--  les points tombent où ils doivent : un ministre reconnaît son département.
--  `location_source = 'manual'` le dit honnêtement — ce ne sont pas des relevés
--  GPS de terrain.
--
--  Les 15 départements sont couverts : c'est ce que la Vue Nationale mesure.
--
--  ── DEUX ANNÉES, ET UNE SEULE COURANTE ─────────────────────────────────────
--  2025-2026 est l'année COURANTE : c'est elle qui porte les notes, les
--  conseils et les résultats d'examen, et c'est sur elle que se prononce la
--  délibération de fin d'année. 2026-2027 existe déjà, structure reconduite,
--  pour que la réinscription ait une destination — sans quoi l'écran de clôture
--  annonce « quitte l'établissement » à toute une classe d'admis.
-- ════════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────────────────
--  IDENTITÉ D'EXÉCUTION — le seed agit AU NOM du super administrateur
--
--  ⚠️ `ON CONFLICT (id) DO UPDATE` ne dispense PAS des triggers `BEFORE
--  INSERT` : Postgres tente l'insertion, les triggers s'exécutent, et le
--  conflit n'est détecté qu'ensuite. Au deuxième passage, l'unique école du
--  groupe Bethel se comptait donc elle-même contre son propre quota, et le
--  seed devenait non rejouable — précisément ce qu'il promet d'être.
--
--  Plutôt que d'affaiblir `fn_enforce_school_quota`, on se donne l'identité qui
--  a légitimement le droit de peupler la plateforme. Un super_admin doit
--  exister en base ; sinon on s'arrête, on ne devine pas.
-- ────────────────────────────────────────────────────────────────────────────

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
--  0. UN SLUG MANQUANT
--
--  Le groupe du METP n'en avait pas — il est pourtant la clé de rattachement de
--  tout ce qui suit, et sans lui le ministère commanditaire serait le seul
--  groupe absent de sa propre démonstration.
-- ────────────────────────────────────────────────────────────────────────────

UPDATE school_groups SET slug = 'metp', updated_at = now()
 WHERE name ILIKE '%Enseignement Technique%' AND (slug IS NULL OR slug = '');

-- ────────────────────────────────────────────────────────────────────────────
--  1. LES ÉTABLISSEMENTS
-- ────────────────────────────────────────────────────────────────────────────

WITH src(gslug, key, name, stype, tut, dept, lat, lng, cap) AS (VALUES
  -- ── METP — enseignement technique et professionnel (12) ──────────────────
  ('metp','metp-lt-1er-mai',   'Lycée Technique du 1er Mai',                   'public','metp','brazzaville',  -4.26944, 15.27123, 1200),
  ('metp','metp-lti-sankara',  'Lycée Technique Industriel Thomas Sankara',    'public','metp','brazzaville',  -4.28500, 15.24500,  950),
  ('metp','metp-ltc-bacongo',  'Lycée Technique Commercial de Bacongo',        'public','metp','brazzaville',  -4.29800, 15.23100,  880),
  ('metp','metp-lt-pnr',       'Lycée Technique de Pointe-Noire',              'public','metp','pointe-noire', -4.79754, 11.85033, 1100),
  ('metp','metp-iti-loandjili','Institut Technique Industriel de Loandjili',   'public','metp','pointe-noire', -4.76500, 11.88200,  760),
  ('metp','metp-lt-dolisie',   'Lycée Technique de Dolisie',                   'public','metp','niari',        -4.20054, 12.67916,  640),
  ('metp','metp-cet-nkayi',    'Collège d''Enseignement Technique de Nkayi',   'public','metp','bouenza',      -4.18410, 13.28837,  420),
  ('metp','metp-lta-owando',   'Lycée Technique Agricole d''Owando',           'public','metp','cuvette',      -0.48336, 15.89742,  380),
  ('metp','metp-cet-ouesso',   'Collège d''Enseignement Technique de Ouésso',  'public','metp','sangha',        1.61040, 16.05093,  340),
  ('metp','metp-lt-kinkala',   'Lycée Technique de Kinkala',                   'public','metp','pool',         -4.35660, 14.75878,  460),
  ('metp','metp-cet-sibiti',   'Collège d''Enseignement Technique de Sibiti',  'public','metp','lekoumou',     -3.68471, 13.35069,  300),
  ('metp','metp-lt-djambala',  'Lycée Technique de Djambala',                  'public','metp','plateaux',     -2.54010, 14.75184,  320),

  -- ── MEPSA — primaire et secondaire général (14), un par département ───────
  ('mepsa','mepsa-ep-revolution','École Primaire de la Révolution',            'public','mepsa','brazzaville', -4.26100, 15.28400,  720),
  ('mepsa','mepsa-ceg-moungali', 'Collège d''Enseignement Général de Moungali','public','mepsa','brazzaville', -4.25300, 15.26800,  980),
  ('mepsa','mepsa-ceg-talangai', 'Collège d''Enseignement Général de Talangaï','public','mepsa','brazzaville', -4.21700, 15.30500, 1050),
  ('mepsa','mepsa-ep-makelekele','École Primaire de Makélékélé',               'public','mepsa','brazzaville', -4.30500, 15.21900,  680),
  ('mepsa','mepsa-ceg-loandjili','Collège d''Enseignement Général de Loandjili','public','mepsa','pointe-noire',-4.76900, 11.87400,  890),
  ('mepsa','mepsa-ep-tie-tie',   'École Primaire de Tié-Tié',                  'public','mepsa','pointe-noire',-4.80900, 11.87600,  610),
  ('mepsa','mepsa-ceg-dolisie',  'Collège d''Enseignement Général de Dolisie', 'public','mepsa','niari',       -4.19200, 12.68800,  540),
  ('mepsa','mepsa-ep-madingou',  'École Primaire de Madingou',                 'public','mepsa','bouenza',     -4.16426, 13.55165,  430),
  ('mepsa','mepsa-ceg-impfondo', 'Collège d''Enseignement Général d''Impfondo','public','mepsa','likouala',     1.62409, 18.06107,  360),
  ('mepsa','mepsa-ep-gamboma',   'École Primaire de Gamboma',                  'public','mepsa','nkeni-alima', -1.87103, 15.87799,  330),
  ('mepsa','mepsa-ceg-ewo',      'Collège d''Enseignement Général d''Ewo',     'public','mepsa','cuvette-ouest',-0.87410, 14.81685,  280),
  ('mepsa','mepsa-ep-mossaka',   'École Primaire de Mossaka',                  'public','mepsa','congo-oubangui',-1.22588,16.79469, 260),
  ('mepsa','mepsa-ep-odziba',    'École Primaire d''Odziba',                   'public','mepsa','djoue-lefini',-3.58508, 15.51740,  240),
  ('mepsa','mepsa-ceg-loango',   'Collège d''Enseignement Général de Loango',  'public','mepsa','kouilou',     -4.65617, 11.81150,  310),

  -- ── Établissements publics de référence (4) ───────────────────────────────
  ('savorgnan','sav-ep',  'École Savorgnan de Brazza',        'public','mepsa','brazzaville', -4.26500, 15.27900, 640),
  ('savorgnan','sav-ceg', 'Collège Savorgnan de Brazza',      'public','mepsa','brazzaville', -4.26300, 15.28100, 820),
  ('edec','edec-bacongo', 'Complexe Scolaire EDEC Bacongo',   'public','mepsa','brazzaville', -4.29500, 15.22700, 700),
  ('edec','edec-makelekele','Complexe Scolaire EDEC Makélékélé','public','mepsa','brazzaville',-4.30900,15.21200, 660),

  -- ── Réseaux privés (8) ────────────────────────────────────────────────────
  ('saint-pierre','sp-ep',   'École Primaire Saint-Pierre',      'prive','mepsa','brazzaville', -4.27600, 15.25400, 380),
  ('saint-pierre','sp-ceg',  'Collège Saint-Pierre',             'prive','mepsa','brazzaville', -4.27400, 15.25600, 420),
  ('saint-pierre','sp-lycee','Lycée Catholique Saint-Pierre',    'prive','mepsa','pointe-noire',-4.78900, 11.86300, 460),
  ('horizon','hz-ep',        'École Horizon Moungali',           'prive','mepsa','brazzaville', -4.25100, 15.26200, 320),
  ('horizon','hz-ceg',       'Collège Horizon Ouenzé',           'prive','mepsa','brazzaville', -4.24200, 15.28900, 360),
  ('horizon','hz-lycee',     'Lycée Horizon Bacongo',            'prive','mepsa','brazzaville', -4.29100, 15.23600, 300),
  -- Bethel est sur le plan GRATUIT, plafonné à une seule école. Lui en donner
  -- deux ferait échouer `trg_enforce_school_quota` — et surtout, la démo perdrait
  -- sa seule illustration honnête de l'offre d'entrée.
  ('bethel','bt-ep',         'École Bethel Dolisie',             'prive','mepsa','niari',       -4.20600, 12.67200, 260)
)
INSERT INTO schools (
  id, group_id, name, school_type, school_code, city, department, department_id,
  tutelle, latitude, longitude, location_source, location_captured_at,
  capacity, is_active, email, phone, parent_portal_enabled)
SELECT
  seed_uuid('school:' || s.key),
  g.id,
  s.name,
  s.stype::school_type_enum,
  upper(replace(s.key, '-', '')),
  d.chef_lieu,
  d.name,
  d.id,
  s.tut::tutelle_enum,
  s.lat, s.lng, 'manual', now(),
  s.cap, true,
  s.key || '@epilote.cg',
  '+242 06 ' || lpad((abs(hashtext(s.key)) % 900 + 100)::text, 3, '0')
             || ' ' || lpad((abs(hashtext(s.key || 'b')) % 90 + 10)::text, 2, '0')
             || ' ' || lpad((abs(hashtext(s.key || 'c')) % 90 + 10)::text, 2, '0'),
  true
FROM src s
JOIN school_groups g ON g.slug = s.gslug
JOIN departments   d ON d.code = s.dept
ON CONFLICT (id) DO UPDATE SET
  name          = EXCLUDED.name,
  school_type   = EXCLUDED.school_type,
  tutelle       = EXCLUDED.tutelle,
  city          = EXCLUDED.city,
  department    = EXCLUDED.department,
  department_id = EXCLUDED.department_id,
  latitude      = EXCLUDED.latitude,
  longitude     = EXCLUDED.longitude,
  capacity      = EXCLUDED.capacity,
  is_active     = true,
  updated_at    = now();

-- ────────────────────────────────────────────────────────────────────────────
--  2. LES ANNÉES SCOLAIRES — deux par groupe
--
--  L'année scolaire congolaise court d'octobre à juillet. `is_locked` sur
--  l'année écoulée protège ses notes d'une saisie tardive.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO academic_years (id, group_id, label, start_date, end_date, is_current, is_locked)
SELECT seed_uuid('year:' || g.slug || ':2025-2026'), g.id,
       '2025-2026', DATE '2025-10-01', DATE '2026-07-31', true, false
FROM school_groups g WHERE g.slug IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
  is_current = true, is_locked = false, updated_at = now();

INSERT INTO academic_years (id, group_id, label, start_date, end_date, is_current, is_locked)
SELECT seed_uuid('year:' || g.slug || ':2026-2027'), g.id,
       '2026-2027', DATE '2026-10-01', DATE '2027-07-31', false, false
FROM school_groups g WHERE g.slug IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
  is_current = false, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  3. LES PROFILS D'ACCÈS
--
--  ⚠️ Un compte SANS profil d'accès voit une barre latérale VIDE — c'est la
--  cause n°1 de « l'espace personnel ne montre rien ». Chaque agent créé par le
--  seed en reçoit un.
--
--  Le profil porte aussi les trois verrous de données sensibles (finance,
--  discipline, médical) : la donnée sensible suit le PROFIL, pas le rôle.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO access_profiles (id, group_id, name, description, role_type, is_active)
SELECT seed_uuid('ap:' || g.slug || ':' || p.slug), g.id, p.name, p.descr, p.slug, true
FROM school_groups g
CROSS JOIN (VALUES
  ('directeur',  'Direction',            'Pilotage complet de l''établissement : structure, personnel, finances, vie scolaire.'),
  ('secretaire', 'Secrétariat',          'Inscriptions, dossiers élèves, documents et annuaire. Sans accès aux finances.'),
  ('enseignant', 'Enseignant',           'Ses classes : notes, appréciations, cahier de textes, présences.'),
  ('comptable',  'Comptabilité',         'Frais de scolarité, encaissements, dépenses et budget.'),
  ('surveillant','Vie scolaire',         'Présences, discipline, retards et sanctions.')
) AS p(slug, name, descr)
WHERE g.slug IS NOT NULL
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description,
  role_type = EXCLUDED.role_type, is_active = true, updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT g.name AS groupe, count(s.id) AS ecoles,
       count(DISTINCT s.department) AS departements
FROM school_groups g LEFT JOIN schools s ON s.group_id = g.id
GROUP BY g.name ORDER BY count(s.id) DESC;

SELECT count(DISTINCT department_id) AS departements_couverts,
       (SELECT count(*) FROM departments) AS departements_total
FROM schools;
