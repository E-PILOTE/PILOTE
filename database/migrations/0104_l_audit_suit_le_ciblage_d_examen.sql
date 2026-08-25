-- ════════════════════════════════════════════════════════════════════════════
--  0104 — LE CLICHÉ D'AUDIT SUIT `applies_to_exam_id`
--
--  La migration 0102 avait fermé ce trou et posé la règle : « toute colonne qui
--  décide du montant ou de qui le paie doit être dans le cliché, sinon sa
--  modification est invisible ». La 0103 ajoute une colonne de portée — sans
--  celle-ci, basculer un tarif du BAC technique vers le BEP produirait deux
--  clichés identiques, donc AUCUNE trace.
--
--  Le fait que ce rattrapage soit nécessaire une migration après l'autre est
--  le signe à retenir : `fn_fee_structure_snapshot` doit être relue à CHAQUE
--  `ALTER TABLE fee_structures ... ADD COLUMN`.
--
--  Vérifié en recette (13/08) : publier puis changer l'examen visé laisse bien
--  `TARIF_PUBLIE [— → BAC_T]` puis `TARIF_MODIFIE [BAC_T → BEP]`.
--
--  ⚠️ `created_at` vaut `now()`, c'est-à-dire l'horodatage de la TRANSACTION :
--  deux traces écrites dans le même bloc partagent la même valeur. Les lire par
--  `ORDER BY created_at DESC LIMIT 1` peut donc rendre la mauvaise — lister,
--  ne pas ordonner.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_fee_structure_snapshot(f public.fee_structures)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT jsonb_build_object(
    'name',                          f.name,
    'fee_type',                      f.fee_type,
    'amount_xaf',                    f.amount_xaf,
    'academic_year_id',              f.academic_year_id,
    'school_id',                     f.school_id,
    'applies_to_level_id',           f.applies_to_level_id,
    'applies_to_education_level_id', f.applies_to_education_level_id,
    'exam_session_id',               f.exam_session_id,
    'applies_to_exam_id',            f.applies_to_exam_id,
    'due_day_of_month',              f.due_day_of_month,
    'source_reference',              f.source_reference,
    'is_active',                     f.is_active
  );
$$;
