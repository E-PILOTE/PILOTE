-- ════════════════════════════════════════════════════════════════════════════
--  0060 — Le secteur d'une école HÉRITE de son groupe. Suppression de « mixte ».
--
--  Principe métier (confirmé) : un groupe scolaire est public XOR privé
--  (l'État/ministère vs un promoteur privé). Une école appartient à un groupe,
--  donc son secteur EST celui de son groupe — un secteur « mixte » n'a pas de
--  sens, et rien ne devait permettre à une école « privée » de vivre sous un
--  groupe public.
--
--  Ce que fait la migration :
--   1. Aligne toute école sur le secteur de son groupe (retire les « mixte » et
--      les incohérences privé-sous-groupe-public).
--   2. Retire « mixte » de school_type_enum (swap, car PG n'a pas ALTER TYPE
--      DROP VALUE).
--   3. Verrouille l'invariant par triggers : école.school_type = groupe.group_type,
--      auto-défini à l'insert/update de l'école ET propagé si le groupe change.
--
--  Vérifié avant écriture : schools.group_id NOT NULL ; aucune vue ni politique
--  RLS ne dépend de schools.school_type.
-- ════════════════════════════════════════════════════════════════════════════
BEGIN;

-- ── 1. Aligner chaque école sur le secteur de son groupe ────────────────────
--  Cast via ::text : 'public'/'prive' existent dans les deux enums.
UPDATE schools s
SET school_type = sg.group_type::text::school_type_enum,
    updated_at  = now()
FROM school_groups sg
WHERE sg.id = s.group_id
  AND s.school_type::text <> sg.group_type::text;

-- Garde-fou : plus aucune école « mixte » ne doit subsister avant le swap.
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM schools WHERE school_type::text = 'mixte';
  IF n > 0 THEN
    RAISE EXCEPTION 'Reste % école(s) « mixte » — swap enum annulé', n;
  END IF;
END $$;

-- ── 2. Retirer « mixte » de l'enum (swap) ───────────────────────────────────
ALTER TABLE schools ALTER COLUMN school_type DROP DEFAULT;
ALTER TYPE school_type_enum RENAME TO school_type_enum_old;
CREATE TYPE school_type_enum AS ENUM ('public', 'prive');
ALTER TABLE schools
  ALTER COLUMN school_type TYPE school_type_enum
  USING school_type::text::school_type_enum;
ALTER TABLE schools
  ALTER COLUMN school_type SET DEFAULT 'prive'::school_type_enum;
DROP TYPE school_type_enum_old;

-- ── 3. Verrou d'invariant : secteur école = secteur du groupe ───────────────
-- 3a. À l'insert/update de l'école : le secteur est TOUJOURS celui du groupe.
CREATE OR REPLACE FUNCTION set_school_type_from_group()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  SELECT sg.group_type::text::school_type_enum
    INTO NEW.school_type
  FROM school_groups sg
  WHERE sg.id = NEW.group_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_school_type_from_group ON schools;
CREATE TRIGGER trg_school_type_from_group
  BEFORE INSERT OR UPDATE OF group_id, school_type ON schools
  FOR EACH ROW EXECUTE FUNCTION set_school_type_from_group();

-- 3b. Si le secteur d'un groupe change, propager à ses écoles.
CREATE OR REPLACE FUNCTION cascade_group_type_to_schools()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.group_type IS DISTINCT FROM OLD.group_type THEN
    UPDATE schools
      SET school_type = NEW.group_type::text::school_type_enum,
          updated_at  = now()
      WHERE group_id = NEW.id
        AND school_type::text <> NEW.group_type::text;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cascade_group_type ON school_groups;
CREATE TRIGGER trg_cascade_group_type
  AFTER UPDATE OF group_type ON school_groups
  FOR EACH ROW EXECUTE FUNCTION cascade_group_type_to_schools();

COMMIT;
