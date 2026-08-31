-- ═══════════════════════════════════════════════════════════════════════════
--  0164 — UNE COPIE QUI NE PEUT PAS DIVERGER
--
--  `schools.tutelle` et `schools.agrement_*` sont des COPIES de leur groupe.
--  Elles existent parce que retirer une colonne qu'un poste envoie encore
--  provoque un `42703`, rejoué à l'infini (cf. 0146). Une copie n'a donc de
--  sens que si elle ne peut pas s'écarter de l'original. Deux trous le
--  permettaient.
--
--  ── TROU 1 — LES DÉCLENCHEURS NE REGARDAIENT QUE `group_id` ──────────────
--  `trg_school_herite_tutelle` et `trg_school_herite_agrement` étaient posés
--  en `UPDATE OF group_id`. Écrire DIRECTEMENT `schools.tutelle` ne les
--  réveillait donc pas : la valeur écrite restait, quelle qu'elle soit.
--  Mesuré le 2026-08-31 — seul un commentaire de colonne l'interdisait.
--
--  ⚠️ Ce n'est pas théorique : une école dont la tutelle diverge sort de
--  `tutelle_ecoles()` (0158) et de toute circulaire (0161). Elle reste
--  parfaitement visible à son propre écran — c'est son ministère qui la perd.
--
--  ── TROU 2 — ON POUVAIT AJOUTER UN AGRÉMENT, JAMAIS L'ENLEVER ───────────
--  Les deux fonctions ne recopiaient que `IF agrement_numero IS NOT NULL`.
--  Un groupe qui CORRIGE un numéro erroné en l'effaçant laissait donc ses
--  écoles porter l'ancien, indéfiniment — et ce numéro s'imprime sur les
--  attestations d'un établissement privé. Un numéro périmé sur un document
--  officiel est pire que pas de numéro du tout.
--
--  ── LA RÈGLE, MAINTENANT TENUE PAR LA BASE ──────────────────────────────
--  L'agrément appartient à la PERSONNE MORALE, c'est-à-dire au groupe
--  (décision 0158). Une école n'a jamais le sien propre : elle porte celui de
--  son groupe, ou rien. La base le force au lieu de le demander.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Toujours recopier, y compris une valeur VIDE ─────────────────────────
CREATE OR REPLACE FUNCTION public.fn_school_herite_agrement()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE g record;
BEGIN
  SELECT agrement_numero, agrement_type, agrement_date INTO g
    FROM public.school_groups WHERE id = NEW.group_id;
  -- Sans `IF ... IS NOT NULL` : effacer l'agrément du groupe doit effacer
  -- celui des écoles. `FOUND` protège du seul cas où le groupe n'existe pas.
  IF FOUND THEN
    NEW.agrement_numero := g.agrement_numero;
    NEW.agrement_type   := g.agrement_type;
    NEW.agrement_date   := g.agrement_date;
  END IF;
  RETURN NEW;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.fn_groupe_propage_agrement()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
BEGIN
  IF OLD.agrement_numero IS DISTINCT FROM NEW.agrement_numero
     OR OLD.agrement_type IS DISTINCT FROM NEW.agrement_type
     OR OLD.agrement_date IS DISTINCT FROM NEW.agrement_date THEN
    UPDATE public.schools
       SET agrement_numero = NEW.agrement_numero,
           agrement_type   = NEW.agrement_type,
           agrement_date   = NEW.agrement_date
     WHERE group_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$fn$;

-- ── Réveiller les copies sur TOUTE modification d'une école ─────────────
-- ⚠️ `UPDATE` sans `OF` : c'est tout l'objet de cette migration. Restreindre
-- à `group_id` laisse passer l'écriture directe de la copie elle-même.
DROP TRIGGER IF EXISTS trg_school_herite_tutelle ON public.schools;
CREATE TRIGGER trg_school_herite_tutelle
  BEFORE INSERT OR UPDATE ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.fn_school_herite_tutelle();

DROP TRIGGER IF EXISTS trg_school_herite_agrement ON public.schools;
CREATE TRIGGER trg_school_herite_agrement
  BEFORE INSERT OR UPDATE ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.fn_school_herite_agrement();

COMMENT ON COLUMN public.schools.agrement_numero IS
  'COPIE de school_groups.agrement_numero, FORCEE par trg_school_herite_agrement '
  'a chaque ecriture (0164). Une ecole n''a jamais d''agrement propre : '
  'l''agrement appartient a la personne morale, donc au groupe.';

COMMIT;
