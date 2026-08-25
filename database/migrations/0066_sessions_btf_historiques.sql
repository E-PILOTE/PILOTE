-- ════════════════════════════════════════════════════════════════════════════
--  LES SESSIONS HISTORIQUES DU BREVET DE TECHNICIEN FORESTIER.
--
--  La migration 0065 a voulu inscrire les chiffres proclamés du BTF pour 2023,
--  2024 et 2025 ; ils n'ont pas été écrits, faute de sessions correspondantes —
--  seule celle de 2025-2026 existait. Trois relevés publics sont donc restés à
--  la porte.
--
--  Le BTF est un petit examen — 59 candidats en 2025, 119 en 2023 — mais il
--  est le seul du réseau à afficher 100 % trois années de suite. Le retirer de
--  l'historique reviendrait à masquer la seule filière qui ne perd personne.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO exam_sessions (exam_id, year_label, results_published_at, status)
SELECT ne.id, y.label, y.published, 'closed'::exam_session_status
  FROM national_exams ne
  CROSS JOIN (VALUES
    ('2022-2023', DATE '2023-07-25'),
    ('2023-2024', DATE '2024-08-10'),
    ('2024-2025', DATE '2025-08-27')
  ) AS y(label, published)
 WHERE ne.code = 'BTF'
   AND NOT EXISTS (
     SELECT 1 FROM exam_sessions es
      WHERE es.exam_id = ne.id AND es.year_label = y.label);

CREATE OR REPLACE FUNCTION pg_temp.sess(p_code text, p_year text)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT es.id FROM exam_sessions es
    JOIN national_exams ne ON ne.id = es.exam_id
   WHERE ne.code = p_code AND es.year_label = p_year
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION pg_temp.metp() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM school_groups
   WHERE name ILIKE '%Enseignement Technique%' LIMIT 1;
$$;

INSERT INTO exam_official_results
  (group_id, session_id, scope, registered, present, admitted, pass_rate,
   source_label, published_at)
SELECT pg_temp.metp(), s.session_id, 'national',
       s.registered, s.present, s.admitted, s.pass_rate,
       s.source_label, s.published_at
  FROM (VALUES
    (pg_temp.sess('BTF','2022-2023'), 119, 119, 119, NULL::numeric,
       'Délibération DEC du 25 juillet 2023', DATE '2023-07-25'),
    -- 100 % annoncé sur 97 inscrits, sans effectif de présents publié.
    (pg_temp.sess('BTF','2023-2024'), 97, NULL, NULL, 100.00,
       'Proclamation DEC du 10 août 2024 — 97 inscrits', DATE '2024-08-10'),
    (pg_temp.sess('BTF','2024-2025'), 59, 59, 59, NULL,
       'Délibération DEC du 27 août 2025', DATE '2025-08-27')
  ) AS s(session_id, registered, present, admitted, pass_rate,
         source_label, published_at)
 WHERE s.session_id IS NOT NULL
   AND pg_temp.metp() IS NOT NULL
 ON CONFLICT DO NOTHING;

COMMIT;
