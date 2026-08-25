-- ════════════════════════════════════════════════════════════════════════════
--  SEED 04 — LES ÉLÈVES ET LEURS INSCRIPTIONS
--
--  ── UNE SEULE ANNÉE PEUPLÉE, ET C'EST VOLONTAIRE ───────────────────────────
--  Les élèves sont inscrits en 2025-2026 UNIQUEMENT. 2026-2027 a sa structure
--  mais pas encore ses effectifs : c'est exactement l'état d'un établissement
--  en juillet, avant la délibération de fin d'année.
--
--  C'est ce qui rend la démonstration possible de bout en bout : le conseil
--  prononce les passages, la clôture d'examen traite les admis et les ajournés,
--  et la réinscription remplit 2026-2027 SOUS LES YEUX du ministère. Pré-remplir
--  l'année suivante priverait la démonstration de sa seule preuve — que le
--  logiciel fait le travail, et pas le jeu de données.
--
--  ── DES ÂGES QUI TIENNENT ──────────────────────────────────────────────────
--  La date de naissance suit le niveau : 6 ans au CP1, 11 au CM2, 15 en 3ᵉ,
--  18 en Terminale, avec une dispersion de deux ans. Un CM2 né en 2010 sauterait
--  aux yeux d'un inspecteur, et fausserait toute statistique d'âge.
--
--  ⚠️ `date_of_birth` est NOT NULL en base : une inscription sans date était
--  perdue à la synchronisation, silencieusement.
--
--  ── DES EFFECTIFS RÉELS ────────────────────────────────────────────────────
--  40 à 46 élèves dans une classe urbaine publique, 26 à 34 en zone rurale,
--  20 à 28 dans le privé. Les moyennes congolaises, pas des classes de 25 comme
--  en Europe.
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

CREATE TEMP TABLE tmp_nom(idx int, nom text) ON COMMIT DROP;
INSERT INTO tmp_nom VALUES
  (0,'Mabiala'),(1,'Ngoma'),(2,'Bakala'),(3,'Loubaki'),(4,'Mouko'),
  (5,'Ondongo'),(6,'Nkodia'),(7,'Massamba'),(8,'Kimbembé'),(9,'Bantsimba'),
  (10,'Ossébi'),(11,'Mavoungou'),(12,'Tchicaya'),(13,'Okemba'),(14,'Ngouabi'),
  (15,'Ibara'),(16,'Samba'),(17,'Milandou'),(18,'Makosso'),(19,'Ekondi'),
  (20,'Bouity'),(21,'Malonga'),(22,'Ondzé'),(23,'Moukala'),(24,'Nzaba'),
  (25,'Kouka'),(26,'Bemba'),(27,'Itoua'),(28,'Gackosso'),(29,'Mfoutou'),
  (30,'Ngakosso'),(31,'Obami');

CREATE TEMP TABLE tmp_prenom(idx int, prenom text, genre text) ON COMMIT DROP;
INSERT INTO tmp_prenom VALUES
  (0,'Christ','M'),(1,'Merveille','F'),(2,'Bénédicte','F'),(3,'Exaucé','M'),
  (4,'Grâce','F'),(5,'Jonathan','M'),(6,'Divine','F'),(7,'Prince','M'),
  (8,'Naomie','F'),(9,'Gloire','M'),(10,'Esther','F'),(11,'Emmanuel','M'),
  (12,'Sarah','F'),(13,'Josué','M'),(14,'Ruth','F'),(15,'Cédric','M'),
  (16,'Laëtitia','F'),(17,'Franck','M'),(18,'Nadège','F'),(19,'Brice','M'),
  (20,'Carine','F'),(21,'Dieuveil','M'),(22,'Sandrine','F'),(23,'Arsène','M'),
  (24,'Prisca','F'),(25,'Ulrich','M'),(26,'Bella','F'),(27,'Juste','M'),
  (28,'Roxane','F'),(29,'Wilfrid','M'),(30,'Sylvia','F'),(31,'Aymar','M');

-- ────────────────────────────────────────────────────────────────────────────
--  L'EFFECTIF DE CHAQUE CLASSE
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_effectif ON COMMIT DROP AS
SELECT c.id AS class_id, c.school_id, c.group_id, c.academic_year_id,
       c.cycle_code, c.level_order, s.school_type,
       (CASE
          WHEN s.school_type = 'prive'  THEN 20 + (abs(hashtext(c.id::text)) % 9)
          WHEN s.capacity >= 600        THEN 40 + (abs(hashtext(c.id::text)) % 7)
          ELSE                               26 + (abs(hashtext(c.id::text)) % 9)
        END) AS effectif,
       -- Âge d'entrée théorique du niveau, tous cycles confondus.
       (CASE c.cycle_code
          WHEN 'primaire' THEN 5  + c.level_order
          WHEN 'college'  THEN 11 + c.level_order
          ELSE                 15 + c.level_order
        END) AS age_theorique
FROM classes c
JOIN schools s ON s.id = c.school_id
JOIN academic_years y ON y.id = c.academic_year_id
WHERE y.label = '2025-2026';

-- ────────────────────────────────────────────────────────────────────────────
--  LES ÉLÈVES
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_eleve ON COMMIT DROP AS
SELECT
  seed_uuid('student:' || e.class_id::text || ':' || n.i)      AS id,
  e.group_id, e.school_id, e.class_id, e.academic_year_id,
  pr.prenom                                                    AS first_name,
  nm.nom                                                       AS last_name,
  pr.genre                                                     AS gender,
  -- Deux ans de dispersion autour de l'âge théorique : redoublements et
  -- entrées tardives sont la règle, pas l'exception.
  (DATE '2026-01-01'
     - ((e.age_theorique * 365)
        + (abs(hashtext('dob' || e.class_id::text || n.i)) % 730) - 365))::date
                                                               AS date_of_birth,
  n.i                                                          AS seq
FROM tmp_effectif e
JOIN generate_series(1, 50) AS n(i) ON n.i <= e.effectif
JOIN tmp_prenom pr ON pr.idx = abs(hashtext('p' || e.class_id::text || n.i)) % 32
JOIN tmp_nom    nm ON nm.idx = abs(hashtext('n' || e.class_id::text || n.i)) % 32;

INSERT INTO students (id, group_id, school_id, matricule, first_name, last_name,
                      date_of_birth, gender, nationality, is_active, city)
SELECT t.id, t.group_id, t.school_id,
       s.school_code || '-' || lpad((row_number() OVER (PARTITION BY t.school_id
                                     ORDER BY t.id))::text, 4, '0'),
       t.first_name, t.last_name, t.date_of_birth, t.gender::gender, 'Congolaise',
       true, s.city
FROM tmp_eleve t
JOIN schools s ON s.id = t.school_id
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name,
  date_of_birth = EXCLUDED.date_of_birth, gender = EXCLUDED.gender,
  is_active = true, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  LES INSCRIPTIONS — 2025-2026 seulement
--
--  Un élève sur douze redouble : `is_repeating` est une déclaration d'ENTRÉE,
--  saisie à l'inscription — à ne pas confondre avec `promotion_decision`, qui
--  est le verdict de fin d'année (migration 0074).
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO class_enrollments (
  id, group_id, school_id, student_id, class_id, academic_year_id,
  enrollment_date, status, is_repeating, inscription_type, validated_at)
SELECT seed_uuid('enr:' || t.id::text), t.group_id, t.school_id, t.id,
       t.class_id, t.academic_year_id,
       DATE '2025-10-01' + (abs(hashtext('d' || t.id::text)) % 21),
       'active'::enrollment_status,
       (abs(hashtext('r' || t.id::text)) % 12 = 0),
       'new', now()
FROM tmp_eleve t
ON CONFLICT (id) DO UPDATE SET
  status = 'active'::enrollment_status, updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT g.name AS groupe, count(DISTINCT s.id) AS eleves,
       round(avg(cnt.n), 1) AS effectif_moyen_par_classe
FROM school_groups g
JOIN students s ON s.group_id = g.id
JOIN (SELECT class_id, count(*) AS n FROM class_enrollments GROUP BY class_id) cnt
  ON true
JOIN class_enrollments e ON e.student_id = s.id AND e.class_id = cnt.class_id
GROUP BY g.name ORDER BY count(DISTINCT s.id) DESC;

SELECT count(*) AS eleves_total,
       (SELECT count(*) FROM class_enrollments) AS inscriptions
FROM students;
