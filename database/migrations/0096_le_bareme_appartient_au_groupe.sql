-- 0096_le_bareme_appartient_au_groupe.sql
--
-- Un barème n'est pas une donnée de l'école, c'est un ACTE DU GROUPE. Dans le
-- public le montant vient d'un arrêté, dans le privé du siège : l'école est un
-- exécutant. Tant qu'elle peut écrire le montant, il n'existe aucun tarif de
-- référence — donc la surfacturation est indétectable, et le ministère ne peut
-- pas répondre à « combien coûte l'inscription en 6e » : mille écoles, mille
-- réponses.
--
-- ⚠️ `school_id` CHANGE DE SENS. Il dit désormais « s'applique à », plus jamais
-- « créé par ». La variance est réelle et légitime — un groupe privé n'a pas le
-- même tarif à Brazzaville et à Dolisie, le ministère peut tarifer par niveau —
-- mais elle n'autorise personne à écrire : l'auteur est imposé par la RLS, pas
-- par le périmètre de la ligne.
--
-- Décisions D2, D3, D6, D9 de
-- docs/superpowers/specs/2026-08-04-frais-scolarite-public-prive-design.md

BEGIN;

-- ── 1. Portée ──────────────────────────────────────────────────────────────
ALTER TABLE fee_structures ALTER COLUMN school_id DROP NOT NULL;

COMMENT ON COLUMN fee_structures.school_id IS
  'S''APPLIQUE À (jamais « créé par »). NULL = barème du groupe, valable pour '
  'toutes ses écoles. Renseigné = barème posé par le groupe POUR cette école.';

-- ── 2. Vocabulaire ─────────────────────────────────────────────────────────
-- La cotisation APE est tracée nominativement (D1) : il lui faut son type.
ALTER TYPE fee_type ADD VALUE IF NOT EXISTS 'cotisation_ape';

-- Rien ne doit devenir une mensualité par omission — surtout dans le public,
-- où la mensualité n'existe pas.
ALTER TABLE fee_structures ALTER COLUMN fee_type DROP DEFAULT;

-- ── 3. Le texte qui fonde le tarif ─────────────────────────────────────────
-- Un montant sans texte fondateur n'est pas un tarif, c'est un chiffre.
ALTER TABLE fee_structures
  ADD COLUMN IF NOT EXISTS source_reference text;

COMMENT ON COLUMN fee_structures.source_reference IS
  'Texte fondateur : arrêté, note de service, délibération d''assemblée APE.';

-- ── 4. Unicité du barème d'examen ──────────────────────────────────────────
-- L'ancien index portait sur (school_id, exam_session_id). Avec school_id NULL,
-- deux barèmes de groupe pour la même session passeraient tous les deux : en
-- btree les NULL sont distincts. Deux barèmes concurrents feraient diverger
-- l'attendu et le recouvrement.
DROP INDEX IF EXISTS uniq_fee_structure_exam_session;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_exam_session_group
  ON fee_structures (group_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_fee_structure_exam_session_school
  ON fee_structures (school_id, exam_session_id)
  WHERE exam_session_id IS NOT NULL AND school_id IS NOT NULL;

-- ── 5. RLS : lecture large, écriture au seul groupe ────────────────────────
-- L'ancienne policy était un ALL unique : lire et écrire au même endroit. C'est
-- exactement ce qu'il faut casser.
DROP POLICY IF EXISTS fee_structures_tenant ON fee_structures;

-- Lecture : l'école voit le barème du groupe ET le sien.
CREATE POLICY fee_structures_read ON fee_structures
  FOR SELECT USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (
          is_admin_groupe()
          OR school_id IS NULL
          OR school_id = auth_school_id()))
  );

-- Écriture : le groupe, et lui seul.
CREATE POLICY fee_structures_insert ON fee_structures
  FOR INSERT WITH CHECK (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

CREATE POLICY fee_structures_update ON fee_structures
  FOR UPDATE USING (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  ) WITH CHECK (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

CREATE POLICY fee_structures_delete ON fee_structures
  FOR DELETE USING (
    is_super_admin() OR (is_admin_groupe() AND group_id = auth_group_id())
  );

-- ── 6. Un tarif qui change laisse une trace ────────────────────────────────
-- D3 autorise le ministère à changer un tarif à tout moment. Ce qui n'est pas
-- négociable, c'est de savoir qui l'a changé, quand, et depuis quel montant.
CREATE OR REPLACE FUNCTION log_fee_structure_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.amount_xaf IS DISTINCT FROM OLD.amount_xaf THEN
    INSERT INTO audit_logs (
      id, group_id, school_id, user_id, action, table_name, record_id,
      old_values, new_values, created_at
    ) VALUES (
      gen_random_uuid(), NEW.group_id, NEW.school_id,
      COALESCE(auth.uid(), NEW.group_id),
      'TARIF_MODIFIE',            -- 13 caractères ; la colonne est varchar(20)
      'fee_structures', NEW.id,
      jsonb_build_object('amount_xaf', OLD.amount_xaf,
                         'source_reference', OLD.source_reference),
      jsonb_build_object('amount_xaf', NEW.amount_xaf,
                         'source_reference', NEW.source_reference),
      now()
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_fee_structure_change ON fee_structures;
CREATE TRIGGER trg_log_fee_structure_change
  AFTER UPDATE ON fee_structures
  FOR EACH ROW EXECUTE FUNCTION log_fee_structure_change();

COMMIT;
