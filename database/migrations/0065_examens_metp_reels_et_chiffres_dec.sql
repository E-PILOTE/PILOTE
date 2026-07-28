-- ════════════════════════════════════════════════════════════════════════════
--  LE RÉFÉRENTIEL D'EXAMENS DEVIENT CELUI QUE LA DEC PROCLAME.
--
--  ── TROIS DÉFAUTS, CONSTATÉS SUR LA BASE LIVE ───────────────────────────────
--
--  1. « Bac T » et « Bac P » figuraient comme DEUX examens distincts. La
--     Direction des examens et concours n'en proclame qu'UN : le
--     « Baccalauréat technique et professionnel ». Session de juin 2025 :
--     7 681 admis sur 15 843 présents, soit 48,48 % — un seul chiffre, un seul
--     jury, une seule délibération. Présenter deux bacs à un fonctionnaire du
--     METP, c'est se disqualifier à la première diapositive.
--
--  2. `ENBA_BET` : une entrée parasite, nommée « ENBA », de sigle « BAC »,
--     sans aucune session. Résidu d'une saisie.
--
--  3. Les chiffres officiels enregistrés étaient INVENTÉS. Le BET 2024-2025 y
--     valait 13 342 admis sur 21 315 présents (62,6 %) là où la DEC a proclamé
--     5 308 sur 6 841, soit 77,59 %. Ces nombres-là sont publics : la personne
--     à qui on les montre les connaît par cœur.
--
--  ── CE QUI EST ÉCRIT ICI, ET CE QUI NE L'EST PAS ────────────────────────────
--  Uniquement des chiffres PUBLIÉS et sourcés (délibérations d'août 2023, août
--  2024, août 2025 ; bac technique et professionnel 2024, 2025, 2026).
--
--  Les taux départementaux ne sont PAS inventés. Deux seulement sont publics
--  pour le bac technique et professionnel 2025 — Bouenza 99,23 %, en tête, et
--  Cuvette-Ouest 19,83 %, en queue. Les treize autres restent absents, et
--  l'écran dit déjà que leur absence ne vaut pas zéro. C'est aussi ce qui
--  donne son objet au panneau de relevé groupé : la DSIC les saisira depuis
--  ses propres publications.
--
--  Quand les effectifs publiés ne reconstituent pas exactement le pourcentage
--  annoncé, seul le TAUX est enregistré (`pass_rate` sans `present`/`admitted`)
--  — l'écran l'affiche alors « taux publié, sans effectifs ». Recalculer une
--  assiette pour faire joli produirait un chiffre que personne ne pourrait
--  recouper.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Entrée parasite ──────────────────────────────────────────────────────
DELETE FROM national_exams WHERE code = 'ENBA_BET';

-- ── 2. Fusion des deux bacs en celui qui existe ─────────────────────────────
-- Le bac professionnel disparaît : ses sessions et ses relevés partaient d'un
-- examen que la DEC ne délibère pas séparément.
DELETE FROM exam_sessions
 WHERE exam_id IN (SELECT id FROM national_exams WHERE code = 'BAC_P');
DELETE FROM national_exams WHERE code = 'BAC_P';

UPDATE national_exams
   SET code       = 'BAC_TP',
       name       = 'Baccalauréat technique et professionnel',
       short_name = 'Bac T&P',
       updated_at = now()
 WHERE code = 'BAC_T';

COMMENT ON TABLE national_exams IS
  'Référentiel NATIONAL des examens d''État. Côté METP, la Direction des '
  'examens et concours délibère : BET, BEP, BTF, CAP, CQP et le Baccalauréat '
  'technique et professionnel — UN seul bac, jamais un « bac T » et un '
  '« bac P » séparés.';

-- ── 3. Les chiffres officiels, remis sur leurs sources ──────────────────────
-- On efface les relevés inventés du groupe ministériel avant de réécrire.
DELETE FROM exam_official_results r
 USING exam_sessions es, national_exams ne
 WHERE r.session_id = es.id
   AND es.exam_id = ne.id
   AND ne.tutelle = 'metp';

-- Helper local : retrouve une session par (code examen, année scolaire).
CREATE OR REPLACE FUNCTION pg_temp.sess(p_code text, p_year text)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT es.id FROM exam_sessions es
    JOIN national_exams ne ON ne.id = es.exam_id
   WHERE ne.code = p_code AND es.year_label = p_year
   LIMIT 1;
$$;

-- Le groupe qui porte le ministère technique.
CREATE OR REPLACE FUNCTION pg_temp.metp() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM school_groups
   WHERE name ILIKE '%Enseignement Technique%' LIMIT 1;
$$;

-- ⚠️ `year_label` = ANNÉE SCOLAIRE ; la session se tient en juin de sa seconde
-- année. « 2024-2025 » désigne donc la session de juin 2025.
INSERT INTO exam_official_results
  (group_id, session_id, scope, department, registered, present, admitted,
   pass_rate, source_label, published_at)
SELECT pg_temp.metp(), s.session_id, s.scope, s.department,
       s.registered, s.present, s.admitted, s.pass_rate,
       s.source_label, s.published_at
  FROM (VALUES
    -- ── BET — Brevet d'études techniques ────────────────────────────────────
    (pg_temp.sess('BET','2022-2023'), 'national', NULL,
       5278, 5149, 3547, NULL,
       'Délibération DEC du 25 juillet 2023 — Lycée technique industriel du 1er Mai',
       DATE '2023-07-25'),
    (pg_temp.sess('BET','2023-2024'), 'national', NULL,
       NULL, 5937, 3835, NULL,
       'Proclamation DEC du 10 août 2024', DATE '2024-08-10'),
    (pg_temp.sess('BET','2024-2025'), 'national', NULL,
       NULL, 6841, 5308, NULL,
       'Délibération DEC du 27 août 2025', DATE '2025-08-27'),

    -- ── BEP — Brevet d'études professionnelles ──────────────────────────────
    (pg_temp.sess('BEP','2022-2023'), 'national', NULL,
       443, 436, 349, NULL,
       'Délibération DEC du 25 juillet 2023 — Lycée technique industriel du 1er Mai',
       DATE '2023-07-25'),
    -- 362 admis pour 90,50 % : les effectifs publiés ne reconstituent pas le
    -- taux annoncé (407 « présentés »). Le taux seul fait foi.
    (pg_temp.sess('BEP','2023-2024'), 'national', NULL,
       NULL, NULL, NULL, 90.50,
       'Proclamation DEC du 10 août 2024 — 362 admis', DATE '2024-08-10'),
    (pg_temp.sess('BEP','2024-2025'), 'national', NULL,
       NULL, 424, 315, NULL,
       'Délibération DEC du 27 août 2025', DATE '2025-08-27'),

    -- ── BTF — Brevet de technicien forestier ────────────────────────────────
    (pg_temp.sess('BTF','2022-2023'), 'national', NULL,
       119, 119, 119, NULL,
       'Délibération DEC du 25 juillet 2023', DATE '2023-07-25'),
    (pg_temp.sess('BTF','2023-2024'), 'national', NULL,
       97, NULL, NULL, 100.00,
       'Proclamation DEC du 10 août 2024 — 97 inscrits', DATE '2024-08-10'),
    (pg_temp.sess('BTF','2024-2025'), 'national', NULL,
       59, 59, 59, NULL,
       'Délibération DEC du 27 août 2025', DATE '2025-08-27'),

    -- ── Baccalauréat technique et professionnel ─────────────────────────────
    (pg_temp.sess('BAC_TP','2023-2024'), 'national', NULL,
       NULL, NULL, NULL, 43.00,
       'Session de juin 2024 — chiffre cité en comparaison par les jurys 2025',
       DATE '2024-08-10'),
    (pg_temp.sess('BAC_TP','2024-2025'), 'national', NULL,
       NULL, 15843, 7681, NULL,
       'Jurys du bac technique et professionnel, session de juin 2025 — '
       'Dr Armel Ibala Nzamba, président des jurys',
       DATE '2025-08-27'),
    -- Les deux seuls départements publiés : les extrêmes du classement.
    (pg_temp.sess('BAC_TP','2024-2025'), 'departement', 'Bouenza',
       NULL, NULL, NULL, 99.23,
       'Session de juin 2025 — premier département', DATE '2025-08-27'),
    (pg_temp.sess('BAC_TP','2024-2025'), 'departement', 'Cuvette-Ouest',
       NULL, NULL, NULL, 19.83,
       'Session de juin 2025 — dernier département', DATE '2025-08-27'),
    (pg_temp.sess('BAC_TP','2025-2026'), 'national', NULL,
       NULL, NULL, NULL, 51.61,
       'Session de juin 2026', DATE '2026-07-24')
  ) AS s(session_id, scope, department, registered, present, admitted,
         pass_rate, source_label, published_at)
 WHERE s.session_id IS NOT NULL
   AND pg_temp.metp() IS NOT NULL;

COMMIT;

-- ── Vérification ────────────────────────────────────────────────────────────
-- select ne.code, es.year_label, r.scope, coalesce(r.department,'national'),
--        r.present, r.admitted, coalesce(r.pass_rate, round(r.admitted*100.0/r.present,2)) as taux
--   from exam_official_results r
--   join exam_sessions es on es.id=r.session_id
--   join national_exams ne on ne.id=es.exam_id
--  order by ne.code, es.year_label, r.scope;
-- Attendu : BET 68,89 / 64,59 / 77,59 · BEP 80,05 / 90,50 / 74,29 ·
--           BTF 100 / 100 / 100 · Bac T&P 43 / 48,48 / 51,61.
