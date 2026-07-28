-- ════════════════════════════════════════════════════════════════════════════
--  LE STAGE DES BACHELIERS TECHNIQUES.
--
--  La migration 0067 a créé 91 candidats au baccalauréat technique et
--  professionnel. Aucun n'avait de stage : les 52 stages du réseau
--  appartenaient aux élèves du BET. Le cockpit affichait donc « 91 bacs
--  bloqués » — soit la totalité de la cohorte.
--
--  Une alerte qui se déclenche sur tout le monde ne protège plus personne : on
--  apprend à la regarder sans la lire. Or celle-ci est la plus coûteuse du
--  réseau — un bac technique sans attestation de stage a un dossier
--  IRRECEVABLE, et c'est une année perdue.
--
--  Le stage en entreprise faisant partie intégrante du cursus technique, la
--  quasi-totalité des candidats en a effectué un. Six restent sans attestation
--  délivrée : c'est ce que le pilotage doit voir, et c'est traitable avant la
--  clôture.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO internships (group_id, school_id, student_id, class_id,
                         academic_year_id, title, start_date, end_date,
                         company_tutor_name, convention_signed_at,
                         attestation_issued_at, evaluation_grade)
SELECT ec.group_id, ec.school_id, ec.student_id, ec.class_id,
       (SELECT id FROM academic_years
         WHERE group_id = ec.group_id AND is_current LIMIT 1),
       'Stage de fin de cycle — ' || coalesce(c.filiere_label, 'formation technique'),
       DATE '2026-02-02', DATE '2026-03-27',
       v.tuteur, DATE '2026-01-20',
       -- Les six derniers restent sans attestation : dossier irrecevable,
       -- rattrapable tant que la clôture n'est pas passée.
       CASE WHEN r.n > 6 THEN DATE '2026-04-10' END,
       CASE WHEN r.n > 6 THEN 12 + (r.n % 7) END
  FROM (
    SELECT c2.id,
           row_number() OVER (ORDER BY c2.created_at DESC, c2.id) AS n
      FROM exam_candidates c2
      JOIN exam_sessions es ON es.id = c2.session_id
      JOIN national_exams ne ON ne.id = es.exam_id
     WHERE ne.code = 'BAC_TP'
  ) AS r
  JOIN exam_candidates ec ON ec.id = r.id
  LEFT JOIN classes c ON c.id = ec.class_id
  CROSS JOIN LATERAL (
    SELECT (ARRAY['M. NGOMA Serge','Mme BAKALA Carine','M. ITOUA Fabrice',
                  'Mme MALONGA Prisca','M. MAVOUNGOU Landry'])[1 + (r.n % 5)]
             AS tuteur
  ) AS v
 WHERE NOT EXISTS (
   SELECT 1 FROM internships i WHERE i.student_id = ec.student_id);

COMMIT;

-- ── Vérification ────────────────────────────────────────────────────────────
-- select count(*) filter (where i.attestation_issued_at is null) as sans_attestation
--   from exam_candidates ec
--   join exam_sessions es on es.id=ec.session_id
--   join national_exams ne on ne.id=es.exam_id
--   left join internships i on i.student_id=ec.student_id
--  where ne.code='BAC_TP';
-- Attendu : 6.
