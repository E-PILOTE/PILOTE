-- ════════════════════════════════════════════════════════════════════════════
--  SEED 06 — LES EXAMENS D'ÉTAT : candidatures et proclamation
--
--  ── CE QUE CE FICHIER FABRIQUE ─────────────────────────────────────────────
--    1. les sessions 2025-2026 passent en « proclamées »
--    2. les sessions 2026-2027 sont OUVERTES aux inscriptions (sans candidat)
--    3. un candidat par élève de classe d'examen, avec son résultat
--
--  ── CE QU'IL NE FABRIQUE PAS, ET POURQUOI ──────────────────────────────────
--  • **Aucune moyenne d'examen.** La DEC proclame des LISTES D'ADMIS, sans
--    relevé de notes : « admis / ajourné » est binaire. `average` et `mention`
--    restent donc NULL sur toute la cohorte — les remplir fabriquerait un
--    classement d'examen qui n'existe nulle part au Congo, et l'écran
--    « Meilleurs élèves » a justement été rebâti sur les classes de PASSAGE.
--  • **Aucune publication PDF** (`exam_publications`) : elle exige un fichier
--    réellement déposé. Un chemin qui ne mène à rien serait pire que rien ;
--    le dépôt se fait en séance.
--  • **Aucun taux départemental inventé.** La DEC n'a publié que la Bouenza et
--    la Cuvette-Ouest pour le bac technique de juin 2025 ; les treize autres
--    restent vides, et l'écran dit déjà que leur absence ne vaut pas zéro.
--
--  ── LE RÉSULTAT SUIT LE TRAVAIL DE L'ANNÉE ─────────────────────────────────
--  L'admission n'est pas tirée au sort : elle suit la moyenne annuelle de
--  l'élève (seed 05), plus ou moins trois points d'aléa. Un bon élève passe
--  généralement, un élève faible échoue généralement, et il reste des surprises
--  dans les deux sens — c'est ce qui rend une corrélation « contrôle continu vs
--  examen » lisible à l'écran, au lieu d'un nuage sans forme.
--
--  Les taux visés sont ancrés sur le réel :
--    • BET     ≈ 76 %   — la DEC a proclamé 77,59 % en juin 2025
--    • Bac T&P ≈ 50,5 % — la DEC a proclamé 51,61 % en juin 2026
--    • CEPE ≈ 78 %, BEPC ≈ 58 %, Bac G ≈ 46 %
--
--  ⚠️ L'écart d'un point entre le réseau et le national au bac technique est
--  VOLONTAIRE et documenté : on ne déplace pas la cohorte pour effacer l'écart,
--  on pose l'étalon de la DEC à côté. Le taux se lit toujours sur les PRÉSENTS,
--  jamais sur les inscrits.
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

CREATE OR REPLACE FUNCTION pg_temp.h(p_key text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS
$$ SELECT (abs(hashtext(p_key)) % 1000)::numeric / 1000.0 $$;

-- ────────────────────────────────────────────────────────────────────────────
--  1. LES SESSIONS 2025-2026 SONT PROCLAMÉES
--
--  Seuls les cinq examens que le réseau présente changent d'état. Les autres
--  (BEP, BTF, CAP, CQP, concours) gardent le leur : personne ne s'y est inscrit,
--  les proclamer serait annoncer un jury qui n'a pas siégé.
--
--  ⚠️ `fee_amount` n'est renseigné QUE là où le montant figure noir sur blanc
--  dans la liste des pièces exigées. Les autres restent vides : devant le
--  ministère, un tarif inventé se remarque immédiatement.
-- ────────────────────────────────────────────────────────────────────────────

UPDATE exam_sessions s SET
  status = 'published'::exam_session_status,
  results_published_at = CASE e.code
    WHEN 'CEPE' THEN DATE '2026-07-03'   -- le primaire délibère en premier
    ELSE              DATE '2026-07-17'
  END,
  fee_amount = CASE e.code
    WHEN 'BEPC'  THEN 5000     -- « 3 000 à 5 000 FCFA », liste des pièces
    WHEN 'BAC_G' THEN 10000    -- « 5 000 à 10 000 FCFA », liste des pièces
    ELSE s.fee_amount
  END,
  updated_at = now()
FROM national_exams e
WHERE e.id = s.exam_id AND s.year_label = '2025-2026'
  AND e.code IN ('CEPE', 'BEPC', 'BET', 'BAC_G', 'BAC_TP');

-- ────────────────────────────────────────────────────────────────────────────
--  2. LA SESSION SUIVANTE EST OUVERTE, ET VIDE
--
--  Elle reprend les pièces exigées et la limite d'âge de la session précédente,
--  décalées d'un an. Vide, parce que ses candidats n'existent pas encore : ils
--  naîtront de la délibération et de la réinscription, en séance. C'est le
--  dernier maillon de la chaîne que les seeds 04 et 05 ont laissée ouverte.
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO exam_sessions (id, exam_id, year_label, registration_opens_at,
                           registration_closes_at, written_from, written_to,
                           max_age, required_documents, fee_amount, status, notes)
SELECT seed_uuid('session:' || e.code || ':2026-2027'), s.exam_id, '2026-2027',
       s.registration_opens_at  + 365, s.registration_closes_at + 365,
       s.written_from + 365, s.written_to + 365,
       s.max_age, s.required_documents, s.fee_amount,
       'open'::exam_session_status,
       'Session déclarée ; les inscriptions ouvrent à la date indiquée.'
FROM exam_sessions s
JOIN national_exams e ON e.id = s.exam_id
WHERE s.year_label = '2025-2026'
  AND e.code IN ('CEPE', 'BEPC', 'BET', 'BAC_G', 'BAC_TP')
ON CONFLICT (exam_id, year_label) DO UPDATE SET
  registration_opens_at = EXCLUDED.registration_opens_at,
  registration_closes_at = EXCLUDED.registration_closes_at,
  written_from = EXCLUDED.written_from, written_to = EXCLUDED.written_to,
  max_age = EXCLUDED.max_age,
  required_documents = EXCLUDED.required_documents,
  status = 'open'::exam_session_status, updated_at = now();

-- ────────────────────────────────────────────────────────────────────────────
--  3. LA COHORTE — un candidat par élève de classe d'examen
--
--  La classe d'examen n'est pas choisie ici : elle est DÉRIVÉE par le trigger
--  `trg_classes_derive_exam` depuis le référentiel d'éligibilité. On la lit,
--  on ne la réinvente pas — c'est le même critère que le module Examens.
-- ────────────────────────────────────────────────────────────────────────────

-- La moyenne annuelle de chaque élève, calculée comme le bulletin : note
-- ramenée sur 20, pondérée par le coefficient de l'évaluation puis par celui de
-- la matière, absences exclues.
CREATE TEMP TABLE tmp_moy_annuelle ON COMMIT DROP AS
WITH par_matiere AS (
  SELECT g.enrollment_id, e.class_id, e.subject_id,
         sum(g.score / e.max_score * 20 * e.coefficient) / sum(e.coefficient)
           AS moyenne
  FROM grades g
  JOIN evaluations e ON e.id = g.evaluation_id
  WHERE NOT g.is_absent AND g.score IS NOT NULL
  GROUP BY g.enrollment_id, e.class_id, e.subject_id
)
SELECT p.enrollment_id,
       sum(p.moyenne * cs.coefficient) / sum(cs.coefficient) AS moyenne
FROM par_matiere p
JOIN class_subjects cs
  ON cs.class_id = p.class_id AND cs.subject_id = p.subject_id
GROUP BY p.enrollment_id;

CREATE INDEX ON tmp_moy_annuelle (enrollment_id);

-- Le chef d'établissement : c'est lui qui reçoit la proclamation et la porte
-- au dossier de l'élève.
CREATE TEMP TABLE tmp_chef ON COMMIT DROP AS
SELECT DISTINCT ON (school_id) school_id, id AS chef_id
FROM profiles
WHERE school_id IS NOT NULL AND role IN ('proviseur', 'directeur')
ORDER BY school_id, created_at;

CREATE TEMP TABLE tmp_candidat ON COMMIT DROP AS
SELECT ce.id                                   AS enrollment_id,
       ce.student_id, ce.group_id, ce.school_id, ce.class_id,
       ce.is_repeating,
       s.id                                    AS session_id,
       s.registration_opens_at, s.registration_closes_at,
       s.results_published_at,
       ne.code                                 AS exam_code,
       COALESCE(ch.chef_id, c.main_teacher_id) AS chef_id,
       -- Absent le jour de l'épreuve : ~2 %. Il n'est PAS un ajourné, et il ne
       -- compte pas dans le taux — un absent n'a pas échoué, il n'a pas composé.
       (pg_temp.h('exabs' || ce.id::text) < 0.02) AS est_absent,
       -- Le classement qui décidera de l'admission : le travail de l'année,
       -- plus ou moins trois points. Un élève sans note (arrivé en juin) part
       -- de la moyenne de passage, faute de mieux.
       COALESCE(m.moyenne, 10.0)
         + (pg_temp.h('exjury' || ce.id::text) - 0.5) * 6.0 AS rang_brut
FROM class_enrollments ce
JOIN classes c        ON c.id = ce.class_id
JOIN academic_years y ON y.id = c.academic_year_id AND y.label = '2025-2026'
JOIN national_exams ne ON ne.id = COALESCE(c.exam_override_id, c.exam_id)
JOIN exam_sessions s  ON s.exam_id = ne.id AND s.year_label = '2025-2026'
LEFT JOIN tmp_moy_annuelle m ON m.enrollment_id = ce.id
LEFT JOIN tmp_chef ch ON ch.school_id = ce.school_id
WHERE ce.status = 'active'
  AND c.exam_status = 'examen' AND NOT c.exam_excluded;

-- Taux visé par examen, et rang de l'élève parmi les PRÉSENTS de sa session.
--
-- ⚠️ Le classement se calcule sur les seuls présents. Le faire sur tous les
-- inscrits gonflerait le taux de deux points : on admettrait « 50,5 % des
-- inscrits », qui font 51,5 % des présents. Le taux se lit sur les présents,
-- il doit donc se fabriquer sur les présents.
CREATE TEMP TABLE tmp_verdict ON COMMIT DROP AS
SELECT t.*,
       CASE t.exam_code
         WHEN 'CEPE'   THEN 0.780
         WHEN 'BEPC'   THEN 0.580
         WHEN 'BET'    THEN 0.760
         WHEN 'BAC_G'  THEN 0.460
         WHEN 'BAC_TP' THEN 0.505
         ELSE               0.600
       END AS taux_vise,
       p.position,
       row_number() OVER (PARTITION BY t.session_id
                          ORDER BY t.school_id, t.enrollment_id) AS numero
FROM tmp_candidat t
LEFT JOIN (
  SELECT enrollment_id,
         percent_rank() OVER (PARTITION BY session_id ORDER BY rang_brut)
           AS position
  FROM tmp_candidat WHERE NOT est_absent
) p ON p.enrollment_id = t.enrollment_id;

INSERT INTO exam_candidates (
  id, session_id, student_id, group_id, school_id, class_id, candidate_number,
  center_id, dossier_status, missing_documents, is_repeater, registered_at,
  submitted_at, result, average, mention, decided_at, notes,
  result_source, result_received_at, result_recorded_by, created_by)
SELECT seed_uuid('cand:' || v.enrollment_id::text),
       v.session_id, v.student_id, v.group_id, v.school_id, v.class_id,
       '26' || v.exam_code || '-' || lpad(v.numero::text, 5, '0'),
       NULL,
       -- La session est proclamée : tous les dossiers ont été validés, sinon
       -- le candidat n'aurait pas composé.
       'valide'::exam_dossier_status, '[]'::jsonb, v.is_repeating,
       v.registration_opens_at
         + (pg_temp.h('reg' || v.enrollment_id::text) * 45)::int,
       v.registration_closes_at - 4,
       CASE WHEN v.est_absent THEN 'absent'::exam_result
            WHEN v.position >= 1 - v.taux_vise THEN 'admis'::exam_result
            ELSE 'ajourne'::exam_result END,
       -- ⚠️ Volontairement NULL : la DEC ne renvoie pas de notes.
       NULL, NULL,
       v.results_published_at, NULL,
       'saisie_manuelle'::result_source,
       v.results_published_at + 1, v.chef_id, v.chef_id
FROM tmp_verdict v
ON CONFLICT (session_id, student_id) DO UPDATE SET
  result = EXCLUDED.result, dossier_status = EXCLUDED.dossier_status,
  decided_at = EXCLUDED.decided_at,
  result_received_at = EXCLUDED.result_received_at,
  result_source = EXCLUDED.result_source, average = NULL, mention = NULL,
  updated_at = now();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT e.code AS examen,
       count(*)                                          AS inscrits,
       count(*) FILTER (WHERE c.result <> 'absent')       AS presents,
       count(*) FILTER (WHERE c.result = 'admis')         AS admis,
       round(100.0 * count(*) FILTER (WHERE c.result = 'admis')
             / NULLIF(count(*) FILTER (WHERE c.result <> 'absent'), 0), 2)
                                                          AS taux_sur_presents,
       count(*) FILTER (WHERE c.average IS NOT NULL)       AS avec_moyenne
FROM exam_candidates c
JOIN exam_sessions s ON s.id = c.session_id
JOIN national_exams e ON e.id = s.exam_id
GROUP BY e.code ORDER BY e.code;

SELECT s.year_label, e.code, s.status, s.results_published_at,
       (SELECT count(*) FROM exam_candidates c WHERE c.session_id = s.id) AS candidats
FROM exam_sessions s JOIN national_exams e ON e.id = s.exam_id
WHERE s.year_label IN ('2025-2026', '2026-2027')
ORDER BY s.year_label DESC, e.code;
