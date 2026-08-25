-- ════════════════════════════════════════════════════════════════════════════
--  0099 — LE BARÈME NE SE DÉDOUBLE PLUS, ET NE S'ÉCRIT PLUS SANS FONDEMENT
--
--  Trois trous fermés LÀ OÙ ILS TIENNENT POUR TOUS LES ÉCRIVAINS — l'écran du
--  ministère, une RPC, un seed, le code de demain :
--
--  1. UNICITÉ. Rien n'empêchait deux « Inscription 2025-2026 » actives sur la
--     même portée. En aval, `baremesApplicables` ne retient qu'UNE ligne par
--     type de frais et départageait, à spécificité égale, par ordre d'arrivée
--     — lequel vient d'une requête SANS `ORDER BY`. Deux postes de la même
--     école pouvaient réclamer deux sommes différentes au même élève, sans
--     qu'aucun des deux ne soit en faute.
--
--  2. FONDEMENT. « un montant sans texte qui le fonde n'est pas un tarif,
--     c'est un chiffre » n'existait que comme un `if` dans le formulaire Dart.
--     Un montant nul ou négatif, une échéance au 45 du mois : tout passait dès
--     qu'on n'entrait pas par ce formulaire.
--
--  3. TRACE. `log_fee_structure_change` ne se déclenchait qu'AFTER UPDATE, et
--     seulement si `amount_xaf` changeait. Publier un tarif à 35 000 F ne
--     laissait AUCUNE trace ; le retirer — ce qui ferme la caisse de tout un
--     réseau — non plus. Sur un module dont l'objet même est la lutte contre
--     la surfacturation, c'est la preuve qui manquait.
--
--  Réversible : les contraintes se DROPent, les index aussi, la fonction
--  d'audit se réécrit. Aucune donnée n'est détruite.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. Le fondement légal devient une contrainte, pas une politesse ─────────

-- Aucune ligne concernée sur la base au 2026-08-12 ; le filet vaut pour les
-- lignes qu'un seed ou un import aurait posées sans référence.
UPDATE fee_structures
   SET source_reference = '(fondement non renseigné — à régulariser)'
 WHERE source_reference IS NULL OR btrim(source_reference) = '';

ALTER TABLE fee_structures ALTER COLUMN source_reference SET NOT NULL;

ALTER TABLE fee_structures
  ADD CONSTRAINT fee_structures_source_non_vide
  CHECK (btrim(source_reference) <> '');

-- Un tarif à 0 n'est pas la gratuité (elle s'exprime par l'ABSENCE de barème,
-- ou par une exonération) ; un tarif négatif n'est rien du tout.
ALTER TABLE fee_structures
  ADD CONSTRAINT fee_structures_montant_positif
  CHECK (amount_xaf > 0);

-- `due_day_of_month` est un jour du mois. 45 s'enregistrait sans broncher.
ALTER TABLE fee_structures
  ADD CONSTRAINT fee_structures_echeance_valide
  CHECK (due_day_of_month IS NULL OR due_day_of_month BETWEEN 1 AND 31);

-- ─── 2. Un seul barème actif par portée ─────────────────────────────────────
--
-- `NULLS NOT DISTINCT` (PG 15+) est le cœur du garde-fou : sans lui, deux
-- tarifs réseau (`school_id NULL`, `applies_to_level_id NULL`) seraient jugés
-- DIFFÉRENTS par l'index — c'est-à-dire exactement le doublon qu'on ferme.
--
-- Partiel sur `is_active` : un tarif retiré ne doit pas empêcher d'en publier
-- un nouveau à sa place. C'est le geste normal d'une rentrée.
--
-- `exam_session_id` fait partie de la clé : deux sessions d'examen distinctes
-- portent légitimement deux barèmes `frais_examens` de même portée.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_portee_active
  ON fee_structures (
    group_id, academic_year_id, fee_type,
    school_id, applies_to_level_id, exam_session_id
  )
  NULLS NOT DISTINCT
  WHERE is_active;

-- Les deux index de session existants ignoraient `is_active` : une fois un
-- barème d'examen retiré, aucun autre ne pouvait plus être publié pour cette
-- session. Le retrait devenait définitif par accident.
DROP INDEX IF EXISTS uniq_fee_structure_exam_session_group;
CREATE UNIQUE INDEX uniq_fee_structure_exam_session_group
  ON fee_structures (group_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NULL AND is_active;

DROP INDEX IF EXISTS uniq_fee_structure_exam_session_school;
CREATE UNIQUE INDEX uniq_fee_structure_exam_session_school
  ON fee_structures (school_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NOT NULL AND is_active;

-- ─── 3. La trace couvre enfin les gestes qui engagent ───────────────────────
--
-- ⚠️ `audit_logs.action` est un varchar(20) : TARIF_PUBLIE (12),
-- TARIF_RETIRE (12), TARIF_RETABLI (13), TARIF_MODIFIE (13). Tous tiennent.
--
-- Pas de garde d'exception autour de l'INSERT d'audit, et c'est délibéré : un
-- tarif national qu'on ne saurait pas imputer ne doit pas être publié. Sur ce
-- module, l'auteur fait partie de l'acte.
CREATE OR REPLACE FUNCTION public.log_fee_structure_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_action  varchar(20);
  v_avant   jsonb;
  v_apres   jsonb;
BEGIN
  v_apres := jsonb_build_object(
    'name',                NEW.name,
    'fee_type',            NEW.fee_type,
    'amount_xaf',          NEW.amount_xaf,
    'school_id',           NEW.school_id,
    'applies_to_level_id', NEW.applies_to_level_id,
    'due_day_of_month',    NEW.due_day_of_month,
    'source_reference',    NEW.source_reference,
    'is_active',           NEW.is_active
  );

  IF TG_OP = 'INSERT' THEN
    v_action := 'TARIF_PUBLIE';
    v_avant  := NULL;
  ELSE
    v_avant := jsonb_build_object(
      'name',                OLD.name,
      'fee_type',            OLD.fee_type,
      'amount_xaf',          OLD.amount_xaf,
      'school_id',           OLD.school_id,
      'applies_to_level_id', OLD.applies_to_level_id,
      'due_day_of_month',    OLD.due_day_of_month,
      'source_reference',    OLD.source_reference,
      'is_active',           OLD.is_active
    );

    IF OLD.is_active AND NOT NEW.is_active THEN
      v_action := 'TARIF_RETIRE';
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      v_action := 'TARIF_RETABLI';
    ELSIF v_avant IS DISTINCT FROM v_apres THEN
      v_action := 'TARIF_MODIFIE';
    ELSE
      -- `updated_at` seul : rien qui engage, rien à tracer.
      RETURN NEW;
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

DROP TRIGGER IF EXISTS trg_log_fee_structure_change ON fee_structures;
CREATE TRIGGER trg_log_fee_structure_change
  AFTER INSERT OR UPDATE ON fee_structures
  FOR EACH ROW EXECUTE FUNCTION log_fee_structure_change();

COMMIT;
