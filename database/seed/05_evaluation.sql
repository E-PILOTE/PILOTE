-- ════════════════════════════════════════════════════════════════════════════
--  SEED 05 — LE TRAVAIL DE L'ANNÉE : trimestres, matières, notes, bulletins
--
--  ── CE QUE CE FICHIER FABRIQUE, ET DANS QUEL ORDRE ─────────────────────────
--    1. `trimesters`      — trois trimestres par année scolaire (les deux années)
--    2. `class_subjects`  — la maquette : quelles matières dans quelle classe
--    3. `evaluations`     — deux devoirs notés par matière et par trimestre
--    4. `grades`          — une note par élève et par évaluation
--    5. `bulletins`       — T1 et T2 publiés, T3 VOLONTAIREMENT non généré
--
--  ── POURQUOI LE TROISIÈME TRIMESTRE N'A PAS SES BULLETINS ──────────────────
--  Les notes du T3 sont saisies, les évaluations publiées — mais les bulletins
--  ne sont pas générés. C'est l'état exact d'un établissement début juillet, et
--  c'est ce qui laisse à la démonstration ses deux gestes à faire EN SÉANCE :
--  générer les bulletins du troisième trimestre, puis délibérer. Un jeu de
--  données qui a déjà tout fait ne prouve rien.
--
--  Même logique que le seed 04, qui laisse 2026-2027 sans effectifs.
--
--  ── LA MOYENNE EST CALCULÉE, JAMAIS STOCKÉE DEUX FOIS ──────────────────────
--  L'application recalcule tout depuis `grades` (`bulletinComputationProvider`).
--  Les colonnes `overall_average`, `rank`, `mention` des bulletins T1/T2 sont
--  donc écrites ici avec EXACTEMENT la même règle, sinon l'écran afficherait un
--  nombre et le PDF un autre :
--    • note ramenée sur 20 (`score / max_score * 20`) ;
--    • moyenne de matière = moyenne pondérée par le coefficient de l'ÉVALUATION ;
--    • moyenne générale  = moyenne pondérée par le coefficient de la MATIÈRE ;
--    • une ABSENCE est exclue du calcul — jamais comptée zéro ;
--    • la mention vient de `get_mention()`, la source unique (migration 0059).
--
--  ── DES NOTES QUI RESSEMBLENT À DES NOTES ──────────────────────────────────
--  Chaque élève reçoit une aptitude tirée de son identifiant (somme de trois
--  tirages : la courbe est en cloche, pas plate), corrigée d'un penchant par
--  matière et d'un aléa par devoir. Les trimestres PROGRESSENT (≈ 11,5 → 12,0
--  → 12,5) : une cohorte qui stagne au dixième près se voit au premier coup
--  d'œil. Environ 3,5 % d'absences aux devoirs.
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
--  1. LES TRIMESTRES
--
--  ⚠️ La contrainte d'unicité est (academic_year_id, trimester_number) : le
--  trimestre appartient à l'ANNÉE, pas à l'école. `school_id` reste NULL, le
--  découpage vaut pour tout le groupe — c'est le calendrier national.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO trimesters (id, academic_year_id, group_id, school_id, label,
                        trimester_number, start_date, end_date,
                        is_current, is_locked)
SELECT seed_uuid('trim:' || y.id::text || ':' || t.n),
       y.id, y.group_id, NULL, t.label, t.n,
       (make_date(EXTRACT(YEAR FROM y.start_date)::int, 1, 1) + t.deb)::date,
       (make_date(EXTRACT(YEAR FROM y.start_date)::int, 1, 1) + t.fin)::date,
       -- Seule l'année en cours a un trimestre courant, et c'est le dernier :
       -- nous sommes en juillet, l'année se termine.
       (y.is_current AND t.n = 3),
       -- T1 et T2 sont clos : on ne saisit plus une note de novembre en juillet.
       (y.is_current AND t.n < 3)
FROM academic_years y
-- Les décalages sont comptés depuis le 1er janvier de l'année d'OUVERTURE :
-- 273 → 1er octobre, 369 → 5 janvier de l'année suivante, etc.
CROSS JOIN (VALUES
  (1, '1er trimestre', 273, 352),   -- 1er oct.  → 19 déc.
  (2, '2e trimestre',  369, 450),   -- 5 janv.   → 27 mars
  (3, '3e trimestre',  460, 545)    -- 6 avril   → 30 juin
) AS t(n, label, deb, fin)
ON CONFLICT (academic_year_id, trimester_number) DO UPDATE SET
  label = EXCLUDED.label, start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date, is_current = EXCLUDED.is_current,
  is_locked = EXCLUDED.is_locked, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  2. LA MAQUETTE — quelles matières dans quelle classe
--
--  Le primaire n'a pas de physique-chimie ; les séries industrielles (F1–F4,
--  F7) portent l'atelier et le dessin technique ; les séries commerciales
--  (G1–G3) la comptabilité et l'économie. Donner les treize matières à tout le
--  monde produirait des bulletins que personne au ministère ne reconnaîtrait.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_maquette ON COMMIT DROP AS
SELECT c.id AS class_id, c.group_id, c.school_id, s.id AS subject_id,
       s.coefficient
FROM classes c
JOIN subjects s ON s.group_id = c.group_id AND s.is_active
WHERE
  CASE
    -- Tronc commun de tous les cycles.
    WHEN s.slug IN ('francais','maths','anglais','hist-geo','civique','eps')
      THEN true
    -- SVT partout sauf en série commerciale.
    WHEN s.slug = 'svt'
      THEN COALESCE(c.filiere_code, '') NOT LIKE 'serie_g%'
    -- Physique-chimie à partir du collège.
    WHEN s.slug = 'physique'
      THEN c.cycle_code <> 'primaire'
         AND COALESCE(c.filiere_code, '') NOT LIKE 'serie_g%'
    -- Matières industrielles : collège technique et séries F.
    WHEN s.slug IN ('techno-indus','dessin-tech','tp-atelier')
      THEN (c.cycle_code = 'college' AND c.group_id IN
              (SELECT id FROM school_groups WHERE slug = 'metp'))
         OR COALESCE(c.filiere_code, '') LIKE 'serie_f%'
    -- Matières tertiaires : séries G.
    WHEN s.slug IN ('compta-gen','eco-entrep')
      THEN COALESCE(c.filiere_code, '') LIKE 'serie_g%'
    ELSE false
  END;

INSERT INTO class_subjects (id, group_id, school_id, class_id, subject_id,
                            coefficient, weekly_hours)
SELECT seed_uuid('cs:' || m.class_id::text || ':' || m.subject_id::text),
       m.group_id, m.school_id, m.class_id, m.subject_id, m.coefficient,
       GREATEST(1, m.coefficient)
FROM tmp_maquette m
ON CONFLICT (class_id, subject_id) DO UPDATE SET
  coefficient = EXCLUDED.coefficient, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  3. LES ÉVALUATIONS — 2025-2026 seulement
--
--  Deux par matière et par trimestre : un devoir surveillé (coefficient 1) et
--  une composition (coefficient 2). C'est le rythme réel, et c'est le minimum
--  pour qu'une moyenne de matière veuille dire quelque chose.
--
--  `created_by` = le professeur titulaire de la classe. La colonne est NOT NULL
--  et sert de trace : une évaluation sans auteur n'est pas une évaluation.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE tmp_eval ON COMMIT DROP AS
SELECT seed_uuid('eval:' || cs.class_id::text || ':' || cs.subject_id::text
                 || ':' || t.trimester_number || ':' || k.kind)      AS id,
       cs.group_id, cs.school_id, cs.class_id, cs.subject_id,
       c.academic_year_id, t.id AS trimester_id, t.trimester_number,
       k.title, k.kind, k.coef,
       -- Le devoir tombe au tiers du trimestre, la composition à la fin.
       (t.start_date + ((t.end_date - t.start_date) * k.quand / 100))::date
                                                                     AS eval_date,
       c.main_teacher_id                                             AS created_by
FROM class_subjects cs
JOIN classes c        ON c.id = cs.class_id
JOIN trimesters t     ON t.academic_year_id = c.academic_year_id
JOIN academic_years y ON y.id = c.academic_year_id AND y.label = '2025-2026'
CROSS JOIN (VALUES
  ('devoir_surveille', 'Devoir surveillé', 1, 40),
  ('composition',      'Composition',      2, 92)
) AS k(kind, title, coef, quand);

INSERT INTO evaluations (id, group_id, school_id, class_id, subject_id,
                         academic_year_id, trimester_id, title, evaluation_type,
                         evaluation_date, max_score, coefficient, created_by,
                         status, validated_by, validated_at, published_at)
SELECT e.id, e.group_id, e.school_id, e.class_id, e.subject_id,
       e.academic_year_id, e.trimester_id,
       e.title || ' — ' || e.trimester_number ||
         CASE e.trimester_number WHEN 1 THEN 'er' ELSE 'e' END || ' trimestre',
       e.kind::evaluation_type, e.eval_date, 20, e.coef, e.created_by,
       'published'::evaluation_status, e.created_by,
       e.eval_date + 3, e.eval_date + 5
FROM tmp_eval e
ON CONFLICT (id) DO UPDATE SET
  status = 'published'::evaluation_status, max_score = 20,
  coefficient = EXCLUDED.coefficient, evaluation_date = EXCLUDED.evaluation_date,
  published_at = EXCLUDED.published_at, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  4. LES NOTES
--
--  `h(clé)` tire un réel dans [0,1[ à partir d'un libellé : même libellé, même
--  nombre, à chaque exécution. C'est ce qui rend le jeu de données REJOUABLE —
--  on peut refaire la démonstration et retrouver les mêmes premiers de classe.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION pg_temp.h(p_key text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS
$$ SELECT (abs(hashtext(p_key)) % 1000)::numeric / 1000.0 $$;

INSERT INTO grades (id, group_id, school_id, evaluation_id, student_id,
                    enrollment_id, score, is_absent, created_by)
SELECT seed_uuid('grade:' || e.id::text || ':' || ce.student_id::text),
       e.group_id, e.school_id, e.id, ce.student_id, ce.id,
       CASE WHEN pg_temp.h('abs' || e.id::text || ce.id::text) < 0.035
            THEN NULL
            ELSE round(LEAST(20, GREATEST(0,
                   -- aptitude propre à l'élève, en cloche (trois tirages)
                   3.5 + 17.0 * ((pg_temp.h('a1' || ce.student_id::text)
                                + pg_temp.h('a2' || ce.student_id::text)
                                + pg_temp.h('a3' || ce.student_id::text)) / 3.0)
                   -- penchant pour la matière
                   + (pg_temp.h('sb' || ce.student_id::text
                                     || e.subject_id::text) - 0.5) * 4.0
                   -- la classe progresse d'un trimestre à l'autre
                   + (e.trimester_number - 2) * 0.5
                   -- aléa du jour
                   + (pg_temp.h('g' || e.id::text || ce.id::text) - 0.5) * 5.0
                 )), 2)
       END,
       (pg_temp.h('abs' || e.id::text || ce.id::text) < 0.035),
       e.created_by
FROM tmp_eval e
JOIN class_enrollments ce
  ON ce.class_id = e.class_id AND ce.status = 'active'
ON CONFLICT (evaluation_id, student_id) DO UPDATE SET
  score = EXCLUDED.score, is_absent = EXCLUDED.is_absent, updated_at = now();

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
--  5. LES BULLETINS DU T1 ET DU T2
--
--  Transaction séparée : les notes sont posées, on peut maintenant les agréger
--  sans que la moindre erreur de calcul emporte les 500 000 notes avec elle.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.h(p_key text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS
$$ SELECT (abs(hashtext(p_key)) % 1000)::numeric / 1000.0 $$;

-- Moyenne de chaque élève dans chaque matière : pondérée par le coefficient de
-- l'ÉVALUATION, absences exclues.
CREATE TEMP TABLE tmp_moy_matiere ON COMMIT DROP AS
SELECT g.enrollment_id, g.student_id, e.class_id, e.trimester_id, e.subject_id,
       e.group_id, e.school_id, e.academic_year_id,
       sum(g.score / e.max_score * 20 * e.coefficient) / sum(e.coefficient)
                                                       AS moyenne
FROM grades g
JOIN evaluations e ON e.id = g.evaluation_id
JOIN trimesters t  ON t.id = e.trimester_id AND t.trimester_number IN (1, 2)
WHERE NOT g.is_absent AND g.score IS NOT NULL
GROUP BY g.enrollment_id, g.student_id, e.class_id, e.trimester_id,
         e.subject_id, e.group_id, e.school_id, e.academic_year_id;

CREATE INDEX ON tmp_moy_matiere (class_id, trimester_id, subject_id);

-- Moyenne générale : pondérée par le coefficient de la MATIÈRE, telle qu'elle
-- est portée par la maquette de la classe (`class_subjects`).
CREATE TEMP TABLE tmp_moy_generale ON COMMIT DROP AS
SELECT m.enrollment_id, m.student_id, m.class_id, m.trimester_id,
       m.group_id, m.school_id, m.academic_year_id,
       sum(m.moyenne * cs.coefficient) / sum(cs.coefficient) AS moyenne
FROM tmp_moy_matiere m
JOIN class_subjects cs
  ON cs.class_id = m.class_id AND cs.subject_id = m.subject_id
GROUP BY m.enrollment_id, m.student_id, m.class_id, m.trimester_id,
         m.group_id, m.school_id, m.academic_year_id;

-- Rang, moyenne de classe, effectif — la même fenêtre pour les trois.
CREATE TEMP TABLE tmp_bulletin ON COMMIT DROP AS
SELECT gg.*,
       rank() OVER (PARTITION BY gg.class_id, gg.trimester_id
                    ORDER BY gg.moyenne DESC)              AS rang,
       avg(gg.moyenne) OVER (PARTITION BY gg.class_id, gg.trimester_id)
                                                           AS moy_classe,
       (SELECT count(*) FROM class_enrollments ce
         WHERE ce.class_id = gg.class_id AND ce.status = 'active')
                                                           AS effectif
FROM tmp_moy_generale gg;

INSERT INTO bulletins (id, group_id, school_id, student_id, enrollment_id,
                       academic_year_id, trimester_id, overall_average,
                       class_average, rank, total_students, mention,
                       total_absences, total_lates, decision, status,
                       validated_by, validated_at, published_at)
SELECT seed_uuid('bull:' || b.enrollment_id::text || ':' || b.trimester_id::text),
       b.group_id, b.school_id, b.student_id, b.enrollment_id,
       b.academic_year_id, b.trimester_id,
       round(b.moyenne, 2), round(b.moy_classe, 2), b.rang::smallint,
       b.effectif::smallint, get_mention(round(b.moyenne, 2)),
       -- Les absences du bulletin sont celles constatées aux devoirs.
       (SELECT count(*) FROM grades g2
         JOIN evaluations e2 ON e2.id = g2.evaluation_id
        WHERE g2.enrollment_id = b.enrollment_id
          AND e2.trimester_id = b.trimester_id AND g2.is_absent)::smallint,
       (pg_temp.h('lat' || b.enrollment_id::text || b.trimester_id::text) * 5)::smallint,
       -- La distinction du conseil de classe, selon le barème usuel.
       CASE
         WHEN b.moyenne >= 16 THEN 'felicitations'
         WHEN b.moyenne >= 14 THEN 'encouragements'
         WHEN b.moyenne >= 12 THEN 'tableau_honneur'
         WHEN b.moyenne <  8  THEN 'avertissement_travail'
         ELSE NULL
       END,
       'published'::bulletin_status,
       c.main_teacher_id, t.end_date + 7, t.end_date + 10
FROM tmp_bulletin b
JOIN classes c    ON c.id = b.class_id
JOIN trimesters t ON t.id = b.trimester_id
ON CONFLICT (student_id, trimester_id) DO UPDATE SET
  overall_average = EXCLUDED.overall_average,
  class_average = EXCLUDED.class_average, rank = EXCLUDED.rank,
  total_students = EXCLUDED.total_students, mention = EXCLUDED.mention,
  total_absences = EXCLUDED.total_absences, decision = EXCLUDED.decision,
  status = EXCLUDED.status, updated_at = now();

-- Les lignes-matières, avec leur rang matière par matière.
--
-- On efface d'abord celles des bulletins QUE CE SEED POSSÈDE (identifiant
-- dérivé de `seed_uuid`), et elles seules : un établissement qui aurait généré
-- ses propres bulletins ne doit rien perdre. Sans cet effacement, retirer une
-- matière de la maquette laisserait sa ligne orpheline sur le bulletin.
DELETE FROM bulletin_subject_lines l
 WHERE l.bulletin_id IN (
   SELECT b.id FROM bulletins b
     JOIN trimesters t ON t.id = b.trimester_id AND t.trimester_number IN (1, 2)
    WHERE b.id = seed_uuid('bull:' || b.enrollment_id::text || ':'
                           || b.trimester_id::text));

INSERT INTO bulletin_subject_lines (id, bulletin_id, subject_id, group_id,
                                    average, class_average, rank, coefficient,
                                    weighted_average)
SELECT seed_uuid('bsl:' || m.enrollment_id::text || ':' || m.trimester_id::text
                 || ':' || m.subject_id::text),
       seed_uuid('bull:' || m.enrollment_id::text || ':' || m.trimester_id::text),
       m.subject_id, m.group_id,
       round(m.moyenne, 2),
       round(avg(m.moyenne) OVER (PARTITION BY m.class_id, m.trimester_id,
                                               m.subject_id), 2),
       rank() OVER (PARTITION BY m.class_id, m.trimester_id, m.subject_id
                    ORDER BY m.moyenne DESC)::smallint,
       cs.coefficient,
       round(m.moyenne * cs.coefficient, 2)
FROM tmp_moy_matiere m
JOIN class_subjects cs
  ON cs.class_id = m.class_id AND cs.subject_id = m.subject_id
ON CONFLICT (bulletin_id, subject_id) DO UPDATE SET
  average = EXCLUDED.average, class_average = EXCLUDED.class_average,
  rank = EXCLUDED.rank, coefficient = EXCLUDED.coefficient,
  weighted_average = EXCLUDED.weighted_average, updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT t.trimester_number AS trimestre,
       count(DISTINCT e.id)                    AS evaluations,
       count(g.id)                             AS notes,
       count(*) FILTER (WHERE g.is_absent)     AS absences,
       round(avg(g.score) FILTER (WHERE NOT g.is_absent), 2) AS moyenne_reseau
FROM evaluations e
JOIN trimesters t ON t.id = e.trimester_id
LEFT JOIN grades g ON g.evaluation_id = e.id
GROUP BY t.trimester_number ORDER BY t.trimester_number;

SELECT t.trimester_number AS trimestre, count(*) AS bulletins,
       count(*) FILTER (WHERE b.status = 'published') AS publies,
       round(avg(b.overall_average), 2) AS moyenne
FROM bulletins b JOIN trimesters t ON t.id = b.trimester_id
GROUP BY t.trimester_number ORDER BY t.trimester_number;
