-- ════════════════════════════════════════════════════════════════════════════
--  DES DOSSIERS INCOMPLETS, ET LES PIÈCES QUI MANQUENT — NOMMÉES.
--
--  La migration 0067 a refermé la chaîne de la campagne, mais elle est allée
--  trop loin : en passant à « valide » tout candidat dont le résultat est
--  connu, elle a fait disparaître le DERNIER dossier incomplet du réseau.
--
--  C'est un défaut, pas un progrès. Le travail quotidien d'un chef
--  d'établissement — et l'objet même de la relance ministérielle — c'est
--  précisément le dossier qui bloque. Un réseau à 100 % de dossiers complets
--  ne décrit aucune campagne réelle, et prive d'objet la liste nominative qui
--  nomme, candidat par candidat, la pièce qui manque.
--
--  ── OÙ LES PIÈCES MANQUENT, ET POURQUOI CELLES-LÀ ───────────────────────────
--  • Lycée de Madingou, l'établissement en retard : rien n'est parti, les six
--    dossiers restent ouverts. C'est le cas d'école du pilotage.
--  • Deux candidats de bac technique par lycée : l'ATTESTATION DE STAGE. Sans
--    elle, le dossier d'un bac technique et professionnel est irrecevable —
--    c'est l'alerte la plus coûteuse du réseau, une année perdue.
--  • Quelques dossiers d'état civil incomplets : l'acte de naissance et le
--    certificat de nationalité sont les deux pièces qui manquent le plus
--    souvent dans les faits.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. L'établissement en retard : dossiers ouverts, pièces identifiées ─────
UPDATE exam_candidates ec
   SET dossier_status    = 'incomplet',
       missing_documents = v.pieces,
       submitted_at      = NULL,
       updated_at        = now()
  FROM (
    SELECT c.id,
           row_number() OVER (ORDER BY c.created_at, c.id) AS n
      FROM exam_candidates c
      JOIN schools s ON s.id = c.school_id
     WHERE s.name = 'Lycée de Madingou'
  ) AS r
  CROSS JOIN LATERAL (
    SELECT CASE r.n % 3
             WHEN 0 THEN '["Acte de naissance"]'::jsonb
             WHEN 1 THEN '["Certificat de nationalité"]'::jsonb
             ELSE        '["Acte de naissance", "Photo d''identité"]'::jsonb
           END AS pieces
  ) AS v
 WHERE ec.id = r.id;

-- ── 2. Les bacs techniques sans attestation de stage ────────────────────────
-- Deux par établissement : assez pour que l'alerte « bacs bloqués » ait un
-- sens, trop peu pour qu'elle ressemble à une avarie générale.
UPDATE exam_candidates ec
   SET dossier_status    = 'incomplet',
       missing_documents = '["Attestation de stage"]'::jsonb,
       submitted_at      = NULL,
       updated_at        = now()
  FROM (
    SELECT c.id,
           row_number() OVER (PARTITION BY c.school_id
                              ORDER BY c.created_at, c.id) AS n
      FROM exam_candidates c
      JOIN exam_sessions es ON es.id = c.session_id
      JOIN national_exams ne ON ne.id = es.exam_id
     WHERE ne.code = 'BAC_TP'
  ) AS r
 WHERE ec.id = r.id AND r.n <= 2;

-- ── 3. Quelques dossiers d'état civil ouverts sur le BET ────────────────────
UPDATE exam_candidates ec
   SET dossier_status    = 'incomplet',
       missing_documents = '["Certificat de nationalité"]'::jsonb,
       submitted_at      = NULL,
       updated_at        = now()
  FROM (
    SELECT c.id,
           row_number() OVER (PARTITION BY c.school_id
                              ORDER BY c.created_at, c.id) AS n
      FROM exam_candidates c
      JOIN exam_sessions es ON es.id = c.session_id
      JOIN national_exams ne ON ne.id = es.exam_id
      JOIN schools s ON s.id = c.school_id
     WHERE ne.code = 'BET' AND s.name <> 'Lycée de Madingou'
  ) AS r
 WHERE ec.id = r.id AND r.n = 1;

COMMIT;

-- ── Vérification ────────────────────────────────────────────────────────────
-- select ne.short_name, count(*) filter (where ec.dossier_status='incomplet')
--   from exam_candidates ec
--   join exam_sessions es on es.id=ec.session_id
--   join national_exams ne on ne.id=es.exam_id group by 1;
-- Attendu : Bac T&P 4 (2 par lycée) · BET 12 (6 Madingou + 6 autres écoles).
