-- ════════════════════════════════════════════════════════════════════════════
--  0102 — L'AUDIT VOIT TOUTE LA PORTÉE DU TARIF
--
--  `log_fee_structure_change` (0099) photographiait le tarif AVANT que la
--  portée ne s'enrichisse. Trois colonnes qui décident QUI PAIE restaient hors
--  du cliché : `applies_to_education_level_id` (niveau national, 0101),
--  `exam_session_id` et `academic_year_id`.
--
--  Ce n'est pas qu'une lacune de contenu. La fonction compare l'avant et
--  l'après pour décider s'il s'est passé quelque chose :
--      ELSIF v_avant IS DISTINCT FROM v_apres THEN 'TARIF_MODIFIE'
--      ELSE RETURN NEW;                       -- aucune trace
--  Une modification portant UNIQUEMENT sur l'une de ces colonnes produisait
--  donc deux clichés identiques : le tarif de la 6e basculait sur la 5e, ou
--  d'une année scolaire à l'autre, EN SILENCE. C'est exactement le cas qu'un
--  registre d'audit existe pour rendre impossible.
--
--  Un seul point de vérité pour le cliché : `fn_fee_structure_snapshot`. La
--  prochaine colonne de portée s'ajoute à un seul endroit, plus à deux.
--
--  Vérifié en recette (groupe ZZ TEST, 13/08/2026) : avant 0102, modifier le
--  seul niveau national ne laissait AUCUNE trace ; après, `TARIF_MODIFIE`.
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
    'due_day_of_month',              f.due_day_of_month,
    'source_reference',              f.source_reference,
    'is_active',                     f.is_active
  );
$$;

COMMENT ON FUNCTION public.fn_fee_structure_snapshot(public.fee_structures) IS
  'Cliché d''un barème pour audit_logs. Doit contenir TOUTE colonne qui décide '
  'du montant ou de qui le paie : une colonne absente rend sa modification '
  'invisible dans le registre (cf. migration 0102).';

CREATE OR REPLACE FUNCTION public.log_fee_structure_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_action varchar(20);   -- ⚠️ audit_logs.action est un varchar(20)
  v_avant  jsonb;
  v_apres  jsonb;
BEGIN
  v_apres := fn_fee_structure_snapshot(NEW);

  IF TG_OP = 'INSERT' THEN
    v_action := 'TARIF_PUBLIE';
    v_avant  := NULL;
  ELSE
    v_avant := fn_fee_structure_snapshot(OLD);

    IF OLD.is_active AND NOT NEW.is_active THEN
      v_action := 'TARIF_RETIRE';
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      v_action := 'TARIF_RETABLI';
    ELSIF v_avant IS DISTINCT FROM v_apres THEN
      v_action := 'TARIF_MODIFIE';
    ELSE
      RETURN NEW;   -- rien de significatif n'a bougé
    END IF;
  END IF;

  INSERT INTO audit_logs (
    id, group_id, school_id, user_id, action, table_name, record_id,
    old_values, new_values, created_at
  ) VALUES (
    gen_random_uuid(), NEW.group_id, NEW.school_id,
    COALESCE(auth.uid(), NEW.group_id),
    v_action, 'fee_structures', NEW.id,
    v_avant, v_apres, now()
  );

  RETURN NEW;
END;
$function$;
