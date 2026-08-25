-- ════════════════════════════════════════════════════════════════════════════
--  0090 — LE REFUS DOIT RESTER LISIBLE
--
--  Correctif de `appliquer_structure_ecole()` (migration 0089).
--
--  ── L'ASYMÉTRIE ───────────────────────────────────────────────────────────
--  Le contrôle bloquant écartait les niveaux à retirer ainsi :
--      AND NOT (sl.education_level_id = ANY (v_cibles))
--  En SQL, `NULL = ANY (...)` vaut NULL, et `NOT NULL` vaut NULL : la ligne
--  sort du WHERE. Un `school_levels` sans lien vers le référentiel national
--  n'était donc JAMAIS vu par le contrôle — alors que la suppression, elle,
--  le visait explicitement (`education_level_id IS NULL OR NOT ...`).
--
--  ── CE QUE ÇA DONNAIT ─────────────────────────────────────────────────────
--  Un tel niveau portant des classes n'était pas annoncé comme bloquant, puis
--  la suppression butait sur `classes_level_id_fkey` (pas d'ON DELETE CASCADE,
--  vérifié) : la transaction entière était annulée. Aucune donnée perdue — la
--  clé étrangère fait son travail — mais l'administrateur recevait
--  « 23503 violates foreign key constraint » au lieu de « la 6ᵉ porte encore
--  3 classes, fermez-les d'abord ».
--
--  Or c'est précisément ce message qui était la fonctionnalité. Un refus qu'on
--  ne comprend pas se contourne au hasard.
--
--  Aujourd'hui aucune ligne n'a `education_level_id` à NULL (les 175 existantes
--  ont été appariées par la 0089). Le piège était dormant : il se serait
--  réveillé au premier niveau créé par un autre chemin.
--
--  Le contrôle et la suppression partagent désormais exactement le même
--  prédicat.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION appliquer_structure_ecole(
  p_school_id uuid,
  p_cycle_ids uuid[],
  p_level_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id   uuid;
  v_ecole      text;
  v_bloquants  jsonb := '[]'::jsonb;
  v_crees      int := 0;
  v_reactives  int := 0;
  v_supprimes  int := 0;
  v_cycles_add int := 0;
  v_cycles_del int := 0;
  v_cibles     uuid[] := coalesce(p_level_ids, ARRAY[]::uuid[]);
  v_cycles     uuid[] := coalesce(p_cycle_ids, ARRAY[]::uuid[]);
  r            record;
  v_slug       text;
  v_base       text;
  v_n          int;
BEGIN
  SELECT s.group_id, s.name INTO v_group_id, v_ecole
    FROM schools s WHERE s.id = p_school_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Établissement introuvable.';
  END IF;

  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = v_group_id)) THEN
    RAISE EXCEPTION 'La structure d''un établissement est posée par l''administration du réseau.';
  END IF;

  -- ── Ce qui bloquerait : les niveaux à retirer qui portent des classes ────
  -- Le prédicat est le MÊME que celui de la suppression, plus bas. Toute
  -- divergence entre les deux rend le refus muet et laisse la clé étrangère
  -- parler à sa place.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'niveau',  x.name,
           'classes', x.n)
         ORDER BY x.name), '[]'::jsonb)
    INTO v_bloquants
    FROM (
      SELECT sl.name, count(c.id) AS n
        FROM school_levels sl
        JOIN classes c ON c.level_id = sl.id
       WHERE sl.school_id = p_school_id
         AND (sl.education_level_id IS NULL
              OR NOT (sl.education_level_id = ANY (v_cibles)))
       GROUP BY sl.id, sl.name
    ) x;

  IF jsonb_array_length(v_bloquants) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'motif', 'classes_rattachees',
      'bloquants', v_bloquants);
  END IF;

  INSERT INTO school_cycles (school_id, cycle_id, group_id)
  SELECT p_school_id, cid, v_group_id FROM unnest(v_cycles) AS cid
  ON CONFLICT (school_id, cycle_id) DO NOTHING;
  GET DIAGNOSTICS v_cycles_add = ROW_COUNT;

  DELETE FROM school_cycles
   WHERE school_id = p_school_id
     AND NOT (cycle_id = ANY (v_cycles));
  GET DIAGNOSTICS v_cycles_del = ROW_COUNT;

  DELETE FROM school_levels
   WHERE school_id = p_school_id
     AND (education_level_id IS NULL
          OR NOT (education_level_id = ANY (v_cibles)));
  GET DIAGNOSTICS v_supprimes = ROW_COUNT;

  FOR r IN
    SELECT el.id, el.name, el.code, el.order_index, el.cycle_id, el.program_id,
           ec.code AS cycle_code
      FROM education_levels el
      JOIN education_cycles ec ON ec.id = el.cycle_id
     WHERE el.id = ANY (v_cibles)
     ORDER BY ec.order_index, el.order_index
  LOOP
    UPDATE school_levels
       SET is_active     = true,
           name          = r.name,
           code          = r.code,
           cycle_id      = r.cycle_id,
           program_id    = r.program_id,
           order_index   = r.order_index,
           display_order = r.order_index,
           updated_at    = now()
     WHERE school_id = p_school_id
       AND education_level_id = r.id
       AND (is_active IS DISTINCT FROM true
            OR name IS DISTINCT FROM r.name
            OR order_index IS DISTINCT FROM r.order_index);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_reactives := v_reactives + v_n;

    CONTINUE WHEN EXISTS (
      SELECT 1 FROM school_levels
       WHERE school_id = p_school_id AND education_level_id = r.id);

    v_base := epilote_slugifier(v_ecole || '-' || coalesce(r.code, r.name));
    v_slug := v_base;
    v_n := 1;
    WHILE EXISTS (SELECT 1 FROM school_levels
                   WHERE group_id = v_group_id AND slug = v_slug) LOOP
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    END LOOP;

    INSERT INTO school_levels (
      group_id, school_id, education_level_id, cycle_id, program_id,
      name, slug, code, order_index, display_order, notation_type, is_active)
    VALUES (
      v_group_id, p_school_id, r.id, r.cycle_id, r.program_id,
      r.name, v_slug, r.code, r.order_index, r.order_index,
      notation_du_cycle(r.cycle_code), true);
    v_crees := v_crees + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'niveaux_crees',      v_crees,
    'niveaux_maj',        v_reactives,
    'niveaux_supprimes',  v_supprimes,
    'cycles_ajoutes',     v_cycles_add,
    'cycles_retires',     v_cycles_del);
END;
$$;

COMMIT;
