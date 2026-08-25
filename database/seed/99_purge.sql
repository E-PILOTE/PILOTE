-- ════════════════════════════════════════════════════════════════════════════
--  SEED 99 — LA PURGE : effacer le jeu de démonstration, et rien d'autre
--
--  ── L'USAGE ────────────────────────────────────────────────────────────────
--    psql "$DATABASE_URL" -v purge_confirm=oui -f database/seed/99_purge.sql
--
--  Sans `-v purge_confirm=oui`, le script REFUSE de s'exécuter. Ce n'est pas de
--  la coquetterie : ce fichier supprime près d'un demi-million de lignes, et il
--  se trouve dans le même dossier que six fichiers inoffensifs.
--
--  ── COMMENT IL SAIT CE QU'IL A LE DROIT D'EFFACER ──────────────────────────
--  Tout ce que les seeds créent porte un identifiant DÉRIVÉ (`seed_uuid`) d'une
--  clé reconstructible depuis la ligne elle-même. Une école de démonstration se
--  reconnaît donc à ceci : `id = seed_uuid('school:' || <clé lue sur la ligne>)`.
--  Une école saisie par un vrai établissement ne satisfera jamais ce test.
--
--  C'est la seule méthode sûre. Effacer « toutes les écoles du groupe METP »
--  emporterait les quatorze établissements réels que le ministère y a déjà
--  déclarés — le groupe, lui, PRÉEXISTE aux seeds et n'est jamais supprimé.
--
--  ── L'ORDRE COMPTE ─────────────────────────────────────────────────────────
--  Des enfants vers les parents. Aucune suppression ne s'appuie sur un ON
--  DELETE CASCADE : ce qui est effacé est écrit ici, noir sur blanc.
-- ════════════════════════════════════════════════════════════════════════════

\if :{?purge_confirm}
\else
\echo '*** REFUS — cette commande efface le jeu de démonstration.'
\echo '*** Relancez avec :  -v purge_confirm=oui'
\quit
\endif

DO $$
DECLARE v_me uuid;
BEGIN
  SELECT id INTO v_me FROM profiles WHERE role = 'super_admin'
   ORDER BY created_at LIMIT 1;
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Aucun super_admin en base.';
  END IF;
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_me)::text, false);
END $$;

BEGIN;

-- ── Les écoles de démonstration, une fois pour toutes ───────────────────────
-- La clé d'origine est lisible dans l'adresse électronique : `hz-ceg@epilote.cg`
-- vient de la clé `hz-ceg`. On recalcule l'identifiant et on le compare.
CREATE TEMP TABLE tmp_purge_schools ON COMMIT DROP AS
SELECT id, group_id FROM schools
WHERE email LIKE '%@epilote.cg'
  AND id = seed_uuid('school:' || split_part(email, '@', 1));

CREATE TEMP TABLE tmp_purge_years ON COMMIT DROP AS
SELECT y.id FROM academic_years y
JOIN school_groups g ON g.id = y.group_id
WHERE g.slug IS NOT NULL
  AND y.id = seed_uuid('year:' || g.slug || ':' || y.label);

-- ── 1. L'évaluation ────────────────────────────────────────────────────────
DELETE FROM bulletin_subject_lines
 WHERE bulletin_id IN (SELECT id FROM bulletins
                        WHERE school_id IN (SELECT id FROM tmp_purge_schools));
DELETE FROM bulletins
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM grades
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM evaluations
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM council_meetings
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM trimesters
 WHERE academic_year_id IN (SELECT id FROM tmp_purge_years);

-- ── 2. Les examens ─────────────────────────────────────────────────────────
DELETE FROM exam_candidates
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);

-- Les sessions 2026-2027 sont nées du seed 06 ; celles de 2025-2026 lui
-- PRÉEXISTAIENT, on leur rend seulement l'état qu'elles avaient.
DELETE FROM exam_sessions s
 USING national_exams e
 WHERE e.id = s.exam_id AND s.year_label = '2026-2027'
   AND s.id = seed_uuid('session:' || e.code || ':2026-2027');

UPDATE exam_sessions s SET
  status = 'open'::exam_session_status,
  results_published_at = NULL,
  fee_amount = NULL,
  updated_at = now()
FROM national_exams e
WHERE e.id = s.exam_id AND s.year_label = '2025-2026'
  AND e.code IN ('CEPE', 'BEPC', 'BET', 'BAC_G', 'BAC_T');

-- ── 3. Les élèves ──────────────────────────────────────────────────────────
DELETE FROM class_enrollments
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM students
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);

-- ── 4. La structure ────────────────────────────────────────────────────────
DELETE FROM class_subjects
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM classes
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM school_levels
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM school_cycles
 WHERE school_id IN (SELECT id FROM tmp_purge_schools);

DELETE FROM subjects s
 USING school_groups g
 WHERE g.id = s.group_id AND g.slug IS NOT NULL
   AND s.id IN (seed_uuid('subj:' || g.slug || ':' || s.slug),
                seed_uuid('subj:metp:' || s.slug));

-- ── 5. Les comptes ─────────────────────────────────────────────────────────
-- Tous les comptes semés partagent le domaine `@epilote.cg`. La suppression
-- dans `auth.users` emporte le profil : c'est la seule façon de ne pas laisser
-- un profil orphelin dont plus personne ne peut se connecter.
DELETE FROM auth.users
 WHERE email LIKE '%@epilote.cg'
   AND id IN (SELECT id FROM profiles
               WHERE school_id IN (SELECT id FROM tmp_purge_schools)
                  OR role = 'admin_groupe');

-- ⚠️ `access_profiles` n'a pas de colonne `slug` : la clé d'origine est le
-- `role_type` (« directeur », « secretaire »…), c'est lui qui se recalcule.
--
-- Les permissions partiraient d'elles-mêmes par cascade ; on les efface quand
-- même, pour que ce fichier reste la liste complète de ce qu'il détruit.
DELETE FROM profile_permissions pp
 USING access_profiles ap, school_groups g
 WHERE pp.profile_id = ap.id AND g.id = ap.group_id AND g.slug IS NOT NULL
   AND ap.id = seed_uuid('ap:' || g.slug || ':' || ap.role_type);

DELETE FROM access_profiles ap
 USING school_groups g
 WHERE g.id = ap.group_id AND g.slug IS NOT NULL
   AND ap.id = seed_uuid('ap:' || g.slug || ':' || ap.role_type);

-- ── 6. Les écoles et les années ────────────────────────────────────────────
DELETE FROM schools WHERE id IN (SELECT id FROM tmp_purge_schools);
DELETE FROM academic_years WHERE id IN (SELECT id FROM tmp_purge_years);

-- ⚠️ `school_groups` n'est JAMAIS touché : le groupe du ministère préexiste aux
-- seeds, avec ses écoles réelles et son abonnement.

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
-- Les deux premières lignes doivent être à zéro : plus une seule école ni un
-- seul compte de démonstration. Les suivantes comptent ce qui RESTE en base —
-- c'est-à-dire les données réelles, que la purge n'a pas le droit de toucher.
SELECT 'ecoles de demo restantes' AS controle, count(*) FROM schools
  WHERE email LIKE '%@epilote.cg'
    AND id = seed_uuid('school:' || split_part(email, '@', 1))
UNION ALL SELECT 'comptes de demo restants', count(*) FROM auth.users
  WHERE email LIKE '%@epilote.cg'
UNION ALL SELECT 'ecoles reelles en base',   count(*) FROM schools
UNION ALL SELECT 'eleves en base',           count(*) FROM students
UNION ALL SELECT 'notes en base',            count(*) FROM grades
UNION ALL SELECT 'bulletins en base',        count(*) FROM bulletins
UNION ALL SELECT 'candidats en base',        count(*) FROM exam_candidates;
