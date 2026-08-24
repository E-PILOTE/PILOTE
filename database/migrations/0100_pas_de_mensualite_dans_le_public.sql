-- ════════════════════════════════════════════════════════════════════════════
--  0100 — PAS DE MENSUALITÉ DANS L'ENSEIGNEMENT PUBLIC
--
--  ── CE QUI S'EST PASSÉ ─────────────────────────────────────────────────────
--  Le 2026-08-12 à 19:03 UTC, une mensualité RÉSEAU de 21 000 F a été publiée
--  dans le groupe « Ministère de l'Enseignement Technique et Professionnel »
--  (`group_type = 'public'`, 12 écoles, 1 775 élèves). L'écran ne l'a pas
--  refusée, ne l'a pas signalée, et la ligne partait vers les douze écoles à
--  leur prochaine synchronisation.
--
--  Or la loi 25-95 art. 1 pose que l'enseignement public est GRATUIT : une
--  mensualité y est illégale. C'est une règle gelée du projet, pas une
--  préférence — et jusqu'ici elle ne vivait que dans une note de conception.
--
--  ── POURQUOI UN TRIGGER ET PAS UN CHECK ────────────────────────────────────
--  La règle dépend d'une AUTRE table (`school_groups.group_type`) : un CHECK
--  ne peut pas la lire. Le trigger la relit à CHAQUE écriture — donc si un
--  groupe change de secteur, la règle suit sans qu'on redéploie quoi que ce
--  soit. Rien n'est figé, rien n'est recopié.
--
--  ── LES DEUX SENS ──────────────────────────────────────────────────────────
--  Un verrou qui ne garde qu'une porte n'en est pas un :
--   1. on ne publie pas une mensualité dans un groupe public ;
--   2. on ne bascule pas un groupe en public s'il porte encore une mensualité
--      active — sinon la même illégalité rentrerait par la fenêtre.
--
--  ── CE QUI RESTE PERMIS ────────────────────────────────────────────────────
--  L'inscription (payante en public depuis ~2022), les frais d'examen (tarif
--  d'État), la cotisation APE. Seule la MENSUALITÉ tombe.
--
--  Le retrait de la ligne fautive est LOGIQUE (`is_active = false`) : elle
--  reste lisible dans l'historique et dans le journal d'audit, qui garde le
--  nom de son auteur. On n'efface pas un acte, on cesse de l'appliquer.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── 1. La ligne fautive cesse de s'appliquer ───────────────────────────────
-- Avant le verrou : le trigger ne bloque que les mensualités ACTIVES, donc ce
-- retrait passerait de toute façon — mais l'ordre garde la migration rejouable.
UPDATE fee_structures f
   SET is_active = false, updated_at = now()
  FROM school_groups g
 WHERE g.id = f.group_id
   AND f.fee_type = 'mensualite'
   AND f.is_active
   AND g.group_type = 'public';

-- ─── 2. On ne publie pas une mensualité dans le public ──────────────────────
CREATE OR REPLACE FUNCTION public.fn_guard_mensualite_publique()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_type text;
  v_nom  text;
BEGIN
  -- Une mensualité RETIRÉE ne réclame rien : elle ne tombe pas sous la règle,
  -- et l'interdire empêcherait de retirer la ligne fautive.
  IF NEW.fee_type <> 'mensualite' OR NOT NEW.is_active THEN
    RETURN NEW;
  END IF;

  SELECT group_type, name INTO v_type, v_nom
    FROM school_groups WHERE id = NEW.group_id;

  IF v_type = 'public' THEN
    RAISE EXCEPTION
      'Une mensualité ne peut pas être publiée dans l''enseignement public : '
      'la loi 25-95 (art. 1) pose que l''enseignement public est gratuit. '
      '« % » est un groupe public. L''inscription, les frais d''examen et la '
      'cotisation APE restent possibles.', v_nom
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_mensualite_publique ON fee_structures;
CREATE TRIGGER trg_guard_mensualite_publique
  BEFORE INSERT OR UPDATE ON fee_structures
  FOR EACH ROW EXECUTE FUNCTION fn_guard_mensualite_publique();

-- ─── 3. On ne bascule pas en public avec une mensualité active ──────────────
CREATE OR REPLACE FUNCTION public.fn_guard_bascule_public_mensualite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_n integer;
BEGIN
  IF NEW.group_type = 'public' AND OLD.group_type IS DISTINCT FROM 'public' THEN
    SELECT count(*) INTO v_n
      FROM fee_structures
     WHERE group_id = NEW.id AND fee_type = 'mensualite' AND is_active;

    IF v_n > 0 THEN
      RAISE EXCEPTION
        'Ce groupe porte encore % mensualité(s) active(s). L''enseignement '
        'public est gratuit (loi 25-95, art. 1) : retirez-les avant de le '
        'basculer en public.', v_n
        USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_bascule_public_mensualite ON school_groups;
CREATE TRIGGER trg_guard_bascule_public_mensualite
  BEFORE UPDATE ON school_groups
  FOR EACH ROW EXECUTE FUNCTION fn_guard_bascule_public_mensualite();
