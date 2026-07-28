-- ════════════════════════════════════════════════════════════════════════════
--  LE RÉSEAU TECHNIQUE PREND FORME — ET LA CAMPAGNE DEVIENT COHÉRENTE.
--
--  ── TROIS DÉFAUTS DU JEU DE DÉMONSTRATION ───────────────────────────────────
--
--  1. UN SEUL EXAMEN portait des candidats : le BET, avec 80 inscrits. Le BEP,
--     le BTF et le baccalauréat technique et professionnel n'avaient personne.
--     Le cockpit ne pouvait donc rien comparer, et son sélecteur d'examen
--     restait masqué faute d'un second examen à proposer.
--
--  2. AUCUN LYCÉE TECHNIQUE n'avait de classe. « Lycée Technique de Poto-Poto »
--     et « Institut Technique de Pointe-Noire » existaient comme noms, sans un
--     seul élève. Le seul établissement doté de Terminales était un collège, et
--     ses séries étaient GÉNÉRALES — A, C, D. Un ministère de l'enseignement
--     technique ne prépare pas le bac général : ces séries appartiennent au
--     MEPSA. Le référentiel national portait pourtant déjà les bonnes (E, F1 à
--     F7, G1 à G3) ; elles n'avaient jamais été instanciées.
--
--  3. LA CHAÎNE ÉTAIT IMPOSSIBLE : 80 résultats proclamés pour 0 dossier déposé
--     et 0 transmission à la DEC. La DEC ne délibère pas sur des candidats
--     qu'elle n'a jamais reçus. Le cockpit affichait pourtant en même temps
--     « 74 % de réussite » et « 7 écoles à risque ».
--
--  ── CE QUE CETTE MIGRATION POSE ─────────────────────────────────────────────
--  Des effectifs plausibles, une chaîne qui se tient — déclaré, complet,
--  déposé, transmis, proclamé — et des taux cadrés sur ceux que la DEC a
--  réellement publiés : 51,61 % au bac technique et professionnel (juin 2026),
--  77,59 % au BET, 74,29 % au BEP, 100 % au BTF (juin 2025).
--
--  UN établissement reste volontairement en retard — dossiers complets, rien de
--  transmis, résultats en attente. C'est le cas que le pilotage doit savoir
--  montrer ; le faire disparaître rendrait la démonstration flatteuse et fausse.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Les séries générales d'un établissement technique deviennent des
--       séries techniques. La conversion préserve les inscriptions existantes.
--
-- ⚠️ Le nom se reconstruit à partir du NIVEAU de la classe, jamais en dur :
-- « Série A » se porte aussi bien en Première qu'en Terminale, et renommer les
-- deux « Tle … » ferait entrer en collision deux classes du même établissement.
UPDATE classes c
   SET filiere_code  = v.code,
       filiere_label = v.label,
       name          = CASE c.level_code
                         WHEN 'Tle'  THEN 'Tle '
                         WHEN '1ere' THEN '1ère '
                         ELSE c.level_code || ' '
                       END || v.short,
       updated_at    = now()
  FROM (VALUES
    ('Série A', 'serie_g2', 'Série G2 — Techniques administratives', 'G2'),
    ('Série C', 'serie_f2', 'Série F2 — Électronique',               'F2'),
    ('Série D', 'serie_f3', 'Série F3 — Électrotechnique',           'F3')
  ) AS v(ancien, code, label, short)
 WHERE c.filiere_label = v.ancien
   AND c.cycle_code = 'lycee'
   AND c.school_id IN (
     SELECT id FROM schools
      WHERE group_id = (SELECT id FROM school_groups
                         WHERE name ILIKE '%Enseignement Technique%' LIMIT 1));

-- ── 2. Peuplement : classes terminales, élèves, candidatures ────────────────
DO $$
DECLARE
  v_group   uuid;
  v_year    uuid;
  v_lvl     uuid;
  v_school  uuid;
  v_class   uuid;
  v_session uuid;
  v_student uuid;
  v_seq     int := 0;
  v_i       int;
  v_n       int;
  v_admis   int;
  v_res     exam_result;
  v_prenoms text[] := ARRAY[
    'Alice','Jean','Paul','Sarah','Chris','Grâce','Dieudonné','Prisca','Serge',
    'Nadège','Fabrice','Carine','Rodrigue','Bénédicte','Armand','Léa','Franck',
    'Merveille','Juste','Divine','Thierry','Sylvie','Guy','Rachel','Brice',
    'Emmanuelle','Landry','Josiane','Ulrich','Clarisse'];
  v_noms text[] := ARRAY[
    'MBEMBA','OKEMBA','NGOMA','LOEMBA','MOUKALA','BAKALA','ITOUA','MAKAYA',
    'NDINGA','OBAMBI','SAMBA','TCHIBOTA','KIMBEMBE','MALONGA','NGOULOU',
    'BOUANGA','MAVOUNGOU','ELENGA','KOUKA','MABIALA','NZABA','GOMA','POATY',
    'MOUYABI','NKOUNKOU'];

  -- examen · établissement · nom de classe · code filière · libellé · effectif
  -- · taux de réussite visé (celui que la DEC a proclamé pour cet examen).
  v_plan text[][] := ARRAY[
    ['BAC_TP','Lycée Technique de Poto-Poto',     'Tle F2','serie_f2','Série F2 — Électronique',               '18','0.5161'],
    ['BAC_TP','Lycée Technique de Poto-Poto',     'Tle F3','serie_f3','Série F3 — Électrotechnique',           '15','0.5161'],
    ['BAC_TP','Lycée Technique de Poto-Poto',     'Tle G2','serie_g2','Série G2 — Techniques administratives', '22','0.5161'],
    ['BAC_TP','Institut Technique de Pointe-Noire','Tle F1','serie_f1','Série F1 — Génie civil',               '16','0.5161'],
    ['BAC_TP','Institut Technique de Pointe-Noire','Tle G1','serie_g1','Série G1 — Techniques de gestion',     '20','0.5161'],
    -- Le BEP se prépare dans les instituts polyvalents.
    ['BEP',   'Institut Polyvalent de Dolisie',   'Tle BEP Maintenance','fp_maintenance_industrielle',
                                                   'Maintenance industrielle',                                '24','0.7429'],
    -- Le brevet de technicien forestier : la Sangha, département forestier.
    ['BTF',   'Complexe Scolaire Étoile du Nord', 'Tle BTF','fp_agriculture','Techniques forestières','11','1.0']
  ];
  v_row text[];
BEGIN
  SELECT id INTO v_group FROM school_groups
   WHERE name ILIKE '%Enseignement Technique%' LIMIT 1;
  IF v_group IS NULL THEN
    RAISE NOTICE 'Groupe METP absent — rien à faire';
    RETURN;
  END IF;

  SELECT id INTO v_year FROM academic_years
   WHERE group_id = v_group AND is_current LIMIT 1;

  -- ⚠️ `classes.level_id` référence `school_levels` (le référentiel DU GROUPE)
  -- et non `education_levels` (le référentiel national). Les deux portent les
  -- mêmes codes : s'y tromper passe la relecture et casse à l'insertion.
  SELECT id INTO v_lvl FROM school_levels
   WHERE code = 'Tle' AND group_id = v_group AND school_id IS NULL LIMIT 1;

  FOREACH v_row SLICE 1 IN ARRAY v_plan LOOP
    SELECT id INTO v_school FROM schools
     WHERE group_id = v_group AND name = v_row[2] LIMIT 1;

    SELECT es.id INTO v_session FROM exam_sessions es
      JOIN national_exams ne ON ne.id = es.exam_id
     WHERE ne.code = v_row[1] AND es.year_label = '2025-2026' LIMIT 1;

    CONTINUE WHEN v_school IS NULL OR v_session IS NULL;
    CONTINUE WHEN EXISTS (SELECT 1 FROM classes
                           WHERE school_id = v_school
                             AND academic_year_id = v_year
                             AND name = v_row[3]);

    INSERT INTO classes (group_id, school_id, academic_year_id, level_id, name,
                         capacity, cycle_code, level_code, level_order,
                         filiere_code, filiere_label, is_active)
    VALUES (v_group, v_school, v_year, v_lvl, v_row[3], 40,
            'lycee', 'Tle', 3, v_row[4], v_row[5], true)
    RETURNING id INTO v_class;

    v_n     := v_row[6]::int;
    v_admis := round(v_n * v_row[7]::numeric);

    FOR v_i IN 1 .. v_n LOOP
      v_seq := v_seq + 1;

      -- Un absent dans chaque cohorte non parfaite : « absent » est un
      -- résultat CONNU qui n'est pas une admission — c'est exactement la
      -- distinction que le calcul du taux doit respecter.
      v_res := CASE
                 WHEN v_i <= v_admis                  THEN 'admis'::exam_result
                 WHEN v_i = v_n AND v_admis < v_n     THEN 'absent'::exam_result
                 ELSE 'ajourne'::exam_result
               END;

      INSERT INTO students (group_id, school_id, matricule, first_name,
                            last_name, date_of_birth, gender, nationality,
                            is_active)
      VALUES (v_group, v_school, 'METP26-' || lpad(v_seq::text, 4, '0'),
              v_prenoms[1 + (v_seq % array_length(v_prenoms, 1))],
              v_noms[1 + (v_seq % array_length(v_noms, 1))],
              DATE '2007-01-01' + ((v_seq * 37) % 700),
              CASE WHEN v_seq % 2 = 0 THEN 'M' ELSE 'F' END::gender,
              'Congolaise', true)
      RETURNING id INTO v_student;

      INSERT INTO class_enrollments (group_id, school_id, student_id, class_id,
                                     academic_year_id, status, inscription_type)
      VALUES (v_group, v_school, v_student, v_class, v_year, 'active', 'new');

      INSERT INTO exam_candidates (session_id, student_id, group_id, school_id,
                                   class_id, candidate_number, dossier_status,
                                   result, submitted_at, decided_at)
      VALUES (v_session, v_student, v_group, v_school, v_class,
              v_row[1] || '26-' || lpad(v_seq::text, 5, '0'),
              'valide'::exam_dossier_status, v_res,
              now() - interval '5 months', now() - interval '1 month');
    END LOOP;
  END LOOP;

  RAISE NOTICE '% candidats créés sur les lycées et instituts techniques', v_seq;
END $$;

-- ── 3. La chaîne se referme : ce qui est proclamé a d'abord été transmis ────
--
-- Tout candidat dont le résultat est CONNU voit son dossier passé à « valide » :
-- la DEC ne délibère pas sur un dossier resté incomplet.
UPDATE exam_candidates
   SET dossier_status = 'valide',
       submitted_at   = COALESCE(submitted_at, now() - interval '5 months'),
       updated_at     = now()
 WHERE result <> 'en_attente'
   AND dossier_status <> 'valide'
   AND group_id = (SELECT id FROM school_groups
                    WHERE name ILIKE '%Enseignement Technique%' LIMIT 1);

-- Une transmission par (établissement, session) dès lors que des dossiers y
-- sont déposés — sauf l'établissement laissé volontairement en retard.
INSERT INTO transmissions (group_id, school_id, session_id, reference, status,
                           item_count, transmitted_at, acknowledged_at,
                           acknowledgment_ref, recipient)
SELECT ec.group_id, ec.school_id, ec.session_id,
       'TR-' || to_char(now(), 'YYYY') || '-' ||
         upper(substr(md5(ec.school_id::text || ec.session_id::text), 1, 6)),
       'accuse_reception'::transmission_status,
       count(*), now() - interval '4 months', now() - interval '3 months',
       'DEC/' || to_char(now(), 'YYYY') || '/' ||
         upper(substr(md5(ec.session_id::text || ec.school_id::text), 1, 5)),
       'Direction des Examens et Concours'
  FROM exam_candidates ec
  JOIN schools s ON s.id = ec.school_id
 WHERE ec.group_id = (SELECT id FROM school_groups
                       WHERE name ILIKE '%Enseignement Technique%' LIMIT 1)
   AND ec.dossier_status = 'valide'
   AND s.name <> 'Lycée de Madingou'
   AND NOT EXISTS (SELECT 1 FROM transmissions t
                    WHERE t.school_id = ec.school_id
                      AND t.session_id = ec.session_id)
 GROUP BY ec.group_id, ec.school_id, ec.session_id;

-- L'établissement en retard : dossiers complets, rien de déposé, rien de
-- proclamé. Le cockpit doit continuer à savoir nommer ce cas — c'est la seule
-- alerte irrattrapable de la campagne.
UPDATE exam_candidates ec
   SET dossier_status = 'complet',
       submitted_at   = NULL,
       result         = 'en_attente',
       decided_at     = NULL,
       updated_at     = now()
  FROM schools s
 WHERE s.id = ec.school_id
   AND s.name = 'Lycée de Madingou';

COMMIT;

-- ── Vérification ────────────────────────────────────────────────────────────
-- select ne.short_name, count(*) as candidats,
--        count(*) filter (where ec.dossier_status='valide') as deposes,
--        count(*) filter (where ec.result<>'en_attente')    as connus,
--        count(*) filter (where ec.result='admis')          as admis
--   from exam_candidates ec
--   join exam_sessions es on es.id=ec.session_id
--   join national_exams ne on ne.id=es.exam_id
--  group by 1 order by 2 desc;
