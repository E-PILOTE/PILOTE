-- ════════════════════════════════════════════════════════════════════════════
--  0089 — DONNER SA STRUCTURE À UNE ÉCOLE
--
--  ── LE BUG ────────────────────────────────────────────────────────────────
--  L'écran « Offre éducative » du réseau enregistrait les niveaux cochés dans
--  `school_education_levels` et `school_education_programs`. Ces deux tables
--  contiennent 0 ligne et AUCUN lecteur : ni l'application, ni les sync-rules,
--  ni une vue. Toute l'application lit `school_levels` (175 lignes,
--  494 classes rattachées) — que cet écran n'écrivait jamais.
--
--  Conséquence : une école créée depuis l'interface reçoit ses cycles, mais
--  PAS un seul niveau. Sans niveau, aucune classe. Sans classe, aucune
--  inscription. L'établissement est mort-né, sans le moindre message d'erreur.
--  Les 37 écoles existantes ne le montrent pas : leurs niveaux viennent du
--  script de peuplement, pas de l'interface.
--
--  Le 2 octobre, chaque école ouverte depuis l'application tombait dessus.
--
--  ── CE QUE POSE CETTE MIGRATION ───────────────────────────────────────────
--  1. `school_levels.education_level_id` — le lien explicite vers le
--     référentiel national. Il existait de fait (appariement par cycle+code
--     exact sur 175/175 lignes) mais restait implicite, donc infiable.
--  2. `appliquer_structure_ecole()` — l'écriture réelle, transactionnelle.
--
--  ── LA RÈGLE QUI GOUVERNE CETTE FONCTION ──────────────────────────────────
--  On n'efface JAMAIS un niveau qui porte des classes. Ni suppression, ni
--  désactivation : la sync-rule des postes filtre `is_active = true`, donc un
--  niveau désactivé DISPARAÎT des appareils, et ses classes deviennent
--  illisibles hors ligne. Un décochage qui emporterait des classes fait
--  échouer l'opération ENTIÈRE et renvoie la liste de ce qui bloque.
--  Le refus est la fonctionnalité : il dit quoi fermer d'abord.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. Le lien vers le référentiel national ────────────────────────────────

ALTER TABLE school_levels
  ADD COLUMN IF NOT EXISTS education_level_id uuid REFERENCES education_levels(id);

-- Appariement rétroactif : cycle + code + filière. Vérifié 175/175 avant
-- écriture — aucun orphelin, aucun doublon.
UPDATE school_levels sl
   SET education_level_id = el.id
  FROM education_levels el
 WHERE sl.education_level_id IS NULL
   AND el.cycle_id   = sl.cycle_id
   AND el.code       IS NOT DISTINCT FROM sl.code
   AND el.program_id IS NOT DISTINCT FROM sl.program_id;

-- Deux fois le même niveau dans une école, c'est la famille de bugs qui a déjà
-- fait afficher « 42 niveaux au lieu de 6 ». La base l'interdit désormais.
CREATE UNIQUE INDEX IF NOT EXISTS school_levels_ecole_niveau_uniq
  ON school_levels (school_id, education_level_id)
  WHERE school_id IS NOT NULL AND education_level_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_school_levels_education_level
  ON school_levels (education_level_id);

COMMENT ON COLUMN school_levels.education_level_id IS
  'Niveau du référentiel national dont celui-ci est l''instance pour l''école. '
  'Clé d''idempotence de appliquer_structure_ecole().';

-- ─── 2. Fabrication du slug ─────────────────────────────────────────────────
-- `school_levels.slug` est UNIQUE (group_id, slug) et NOT NULL. Il n'est jamais
-- affiché : c'est une clé technique. On la dérive, on ne la demande pas.

-- `unaccent` est une extension qui peut manquer : on se donne un repli sans
-- dépendance, suffisant pour le français scolaire (é è ê à ô î ù ç).
CREATE OR REPLACE FUNCTION unaccent_simple(p_texte text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT translate(coalesce(p_texte, ''),
                   'àâäáãçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ',
                   'aaaaaceeeeiiiinooooouuuuyyAAAAACEEEEIIIINOOOOOUUUUY');
$$;

CREATE OR REPLACE FUNCTION epilote_slugifier(p_texte text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT trim(both '-' from
           regexp_replace(
             regexp_replace(
               lower(unaccent_simple(coalesce(p_texte, ''))),
               '[^a-z0-9]+', '-', 'g'),
             '-{2,}', '-', 'g'));
$$;

-- ─── 3. Le type de notation, déduit du cycle ────────────────────────────────
-- La maternelle n'attribue pas de notes : elle évalue des compétences. Partout
-- ailleurs, le Congo note sur 20 avec coefficients — c'est ce que portent les
-- 175 lignes existantes.

CREATE OR REPLACE FUNCTION notation_du_cycle(p_cycle_code text)
RETURNS notation_type
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE WHEN p_cycle_code = 'prescolaire' THEN 'competences'::notation_type
              ELSE 'numeric_with_coef'::notation_type END;
$$;

-- ─── 4. Appliquer la structure ──────────────────────────────────────────────

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

  -- Le réseau gouverne la structure de ses écoles ; personne d'autre.
  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND auth_group_id() = v_group_id)) THEN
    RAISE EXCEPTION 'La structure d''un établissement est posée par l''administration du réseau.';
  END IF;

  -- ── Ce qui bloquerait : les niveaux décochés qui portent des classes ──────
  -- Contrôlé AVANT toute écriture. Une opération qui emporterait des classes
  -- n'est pas exécutée à moitié : elle n'est pas exécutée du tout.
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
         AND NOT (sl.education_level_id = ANY (v_cibles))
       GROUP BY sl.id, sl.name
    ) x;

  IF jsonb_array_length(v_bloquants) > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'motif', 'classes_rattachees',
      'bloquants', v_bloquants);
  END IF;

  -- ── Les cycles offerts ───────────────────────────────────────────────────
  INSERT INTO school_cycles (school_id, cycle_id, group_id)
  SELECT p_school_id, cid, v_group_id FROM unnest(v_cycles) AS cid
  ON CONFLICT (school_id, cycle_id) DO NOTHING;
  GET DIAGNOSTICS v_cycles_add = ROW_COUNT;

  DELETE FROM school_cycles
   WHERE school_id = p_school_id
     AND NOT (cycle_id = ANY (v_cycles));
  GET DIAGNOSTICS v_cycles_del = ROW_COUNT;

  -- ── Les niveaux retirés (aucun ne porte de classe, on vient de le vérifier)
  DELETE FROM school_levels
   WHERE school_id = p_school_id
     AND (education_level_id IS NULL
          OR NOT (education_level_id = ANY (v_cibles)));
  GET DIAGNOSTICS v_supprimes = ROW_COUNT;

  -- ── Les niveaux à poser ──────────────────────────────────────────────────
  FOR r IN
    SELECT el.id, el.name, el.code, el.order_index, el.cycle_id, el.program_id,
           ec.code AS cycle_code
      FROM education_levels el
      JOIN education_cycles ec ON ec.id = el.cycle_id
     WHERE el.id = ANY (v_cibles)
     ORDER BY ec.order_index, el.order_index
  LOOP
    -- Déjà posé : on le remet en service s'il dormait, et on rafraîchit son
    -- libellé (le référentiel national peut avoir été corrigé depuis).
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

    -- Nouveau : on lui fabrique un slug libre dans le groupe.
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

REVOKE ALL ON FUNCTION appliquer_structure_ecole(uuid, uuid[], uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION appliquer_structure_ecole(uuid, uuid[], uuid[]) TO authenticated;

COMMENT ON FUNCTION appliquer_structure_ecole(uuid, uuid[], uuid[]) IS
  'Matérialise dans school_levels les niveaux du référentiel cochés pour une '
  'école. Refuse en bloc, sans rien modifier, si un niveau décoché porte '
  'encore des classes. Idempotente.';

-- ─── 5. Les deux tables mortes ──────────────────────────────────────────────
-- On ne les supprime pas dans la même migration que le correctif : si un
-- déploiement doit être annulé, il ne faut pas qu'il emporte des tables. Elles
-- sont marquées, et n'ont plus d'écrivain.

COMMENT ON TABLE school_education_levels IS
  'MORTE (0 ligne, aucun lecteur). Remplacée par school_levels + '
  'appliquer_structure_ecole() — migration 0089. À supprimer après le '
  'déploiement national.';
COMMENT ON TABLE school_education_programs IS
  'MORTE (0 ligne, aucun lecteur). Remplacée par school_levels + '
  'appliquer_structure_ecole() — migration 0089. À supprimer après le '
  'déploiement national.';

COMMIT;
