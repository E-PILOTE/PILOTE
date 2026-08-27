-- ════════════════════════════════════════════════════════════════════════════
--  0124 — RECLER L'APPEL EXISTANT SUR SON IDENTITÉ DÉDUITE
--
--  L'application déduit désormais l'identifiant d'un appel de sa clé métier
--  (classe × date × période) au lieu de le tirer au sort, pour que deux
--  appareils hors ligne écrivent la MÊME ligne au lieu d'en créer deux
--  (`core/utils/identite_offline.dart`).
--
--  Une ligne d'appel existait déjà, créée à l'ancienne : 3 août 2026, matin,
--  5 élèves pointés, appel finalisé. Sans reclage, le prochain appareil qui
--  ouvre cette feuille ne la reconnaîtrait pas — il en créerait une SECONDE, et
--  la feuille afficherait chaque élève deux fois. Le correctif aurait produit,
--  sur cette classe, exactement le défaut qu'il corrige.
--
--  Les identifiants ci-dessous sont ceux que produit `idDeterministe`, calculés
--  avec le code livré. Les données (statuts, motifs, horaires, finalisation)
--  sont conservées telles quelles.
--
--  Une seule ligne était concernée dans toute la base — relevé avant reclage :
--  1 `attendance_record`, 5 `attendance_entries`. Vérifié après : 1 appel sous
--  son identité déduite, 5 entrées, 0 orpheline.
-- ════════════════════════════════════════════════════════════════════════════

-- 1) La ligne d'appel, à l'identique, sous son identité déduite.
INSERT INTO attendance_records (
  id, group_id, school_id, class_id, academic_year_id, subject_id,
  record_date, period, recorded_by, is_finalized, created_at, updated_at)
SELECT 'ad3e46ae-1b24-5eb5-9bb5-437112ae1915', group_id, school_id, class_id,
       academic_year_id, subject_id, record_date, period, recorded_by,
       is_finalized, created_at, updated_at
FROM attendance_records
WHERE id = 'cc41d018-131e-4016-b412-2eb94dac9f28';

-- 2) Les entrées suivent : nouvel appel, et leur propre identité déduite.
UPDATE attendance_entries SET
  attendance_record_id = 'ad3e46ae-1b24-5eb5-9bb5-437112ae1915',
  id = CASE student_id
    WHEN '412c390e-4acf-0bbe-10e5-b68636a48ca8'::uuid THEN '4b28e4a2-7d3f-5f22-a5c7-583fdcdb9539'::uuid
    WHEN '59d2ffed-7e73-3376-7679-d21794538d3d'::uuid THEN 'bf544b14-24bc-5172-b665-678d11033bd0'::uuid
    WHEN 'b0c59f7c-2ede-0531-8864-eb714c8f1267'::uuid THEN '2c79c6c6-0500-5d1f-8257-d0a9c92d795f'::uuid
    WHEN 'dff20d4b-50fd-03fa-c060-fe2cb829fc43'::uuid THEN 'ddba1644-0c79-5ab0-bc64-576196bd25ae'::uuid
    WHEN 'fc7e085c-1314-482d-a43c-f8e49afbf779'::uuid THEN '497c70ce-d5dc-5afa-8bf5-1639bccafddd'::uuid
    ELSE id
  END
WHERE attendance_record_id = 'cc41d018-131e-4016-b412-2eb94dac9f28';

-- 3) L'ancienne ligne n'a plus d'enfant : on la retire.
DELETE FROM attendance_records WHERE id = 'cc41d018-131e-4016-b412-2eb94dac9f28';
