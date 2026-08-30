-- ════════════════════════════════════════════════════════════════════════════
--  0153 — LA TUTELLE APPARTIENT AU GROUPE, L'ÉCOLE EN HÉRITE
--
--  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
--  `schools.tutelle` était nullable, sans valeur par défaut, et le formulaire
--  de création d'école NE L'ÉCRIVAIT JAMAIS. Les 37 écoles actuelles la
--  portent parce qu'elles viennent d'une migration de départ. La prochaine
--  école créée depuis l'application serait née SANS MINISTÈRE — et une école
--  sans tutelle ne remonte dans aucun état ministériel.
--
--  ── POURQUOI AU GROUPE, ET PAS À L'ÉCOLE ──────────────────────────────────
--  Décision du fondateur, et les faits la soutiennent :
--
--   • Chaque ministère agrée SES propres établissements privés, par sa propre
--     commission. Le MEPSA a examiné 1 192 dossiers d'enseignement général ;
--     le METP en a examiné 108 puis 151 pour le technique et professionnel.
--     Un établissement privé relève donc d'UNE commission, pas des deux.
--   • Les groupes privés congolais couvrent des NIVEAUX (« de la maternelle au
--     lycée ») et non des ministères. Aucun contre-exemple trouvé.
--   • Et sur nos propres données : les 7 groupes ont chacun UNE seule tutelle
--     distincte. Zéro groupe mixte.
--
--  C'est exactement le traitement déjà réservé à `group_type` (public/privé),
--  que l'école hérite sans pouvoir le contredire.
--
--  ── POURQUOI ON NE SUPPRIME PAS `schools.tutelle` ─────────────────────────
--  ⚠️ Parce que la supprimer serait la faute de la migration 0146 : un poste
--  resté sur un build antérieur l'enverrait encore dans ses upserts, PostgREST
--  répondrait 42703, code que `_fatalResponseCodes` NE traite PAS comme fatal —
--  le connecteur rejouerait le lot indéfiniment et la synchro de ce poste
--  serait morte, en silence.
--
--  Elle devient donc une COPIE DÉNORMALISÉE, tenue à jour par déclencheur
--  depuis le groupe. Les lectures existantes (état de rentrée, examens,
--  rapports) continuent de fonctionner sans une ligne de code changée.
--
--  ── ⚠️ POURQUOI `tutelle` RESTE NULLABLE SUR LE GROUPE ────────────────────
--  La rendre NOT NULL maintenant casserait la création de groupe depuis le
--  build DÉPLOYÉ, qui ne l'envoie pas — un 23502, code de la famille fatale.
--  Elle passera NOT NULL dans une migration ultérieure, APRÈS que le build qui
--  la renseigne soit publié ET adopté. Même discipline que 0139 / 0146.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

-- ── La tutelle sur le groupe ────────────────────────────────────────────────
ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS tutelle public.tutelle_enum;

COMMENT ON COLUMN public.school_groups.tutelle IS
  'Ministere de tutelle du groupe (mepsa ou metp). SOURCE DE VERITE : schools.tutelle en est une copie tenue par declencheur. Un groupe n''est jamais mixte.';

-- Rétro-remplissage : sans ambiguïté, chaque groupe n'ayant qu'une tutelle.
UPDATE public.school_groups sg
   SET tutelle = sous.t
  FROM (SELECT s.group_id, min(s.tutelle::text) AS t
          FROM public.schools s
         WHERE s.tutelle IS NOT NULL
         GROUP BY s.group_id
        HAVING count(DISTINCT s.tutelle::text) = 1) AS sous
 WHERE sg.id = sous.group_id
   AND sg.tutelle IS NULL;

-- ── L'école hérite, et ne peut pas contredire ───────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_school_herite_tutelle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  t public.tutelle_enum;
BEGIN
  SELECT sg.tutelle INTO t FROM public.school_groups sg WHERE sg.id = NEW.group_id;
  -- ⚠️ On n'écrase PAS par NULL. Tant qu'un groupe ancien n'a pas de tutelle,
  -- l'école garde celle qu'elle avait : perdre l'information serait pire que
  -- de la laisser diverger un moment.
  IF t IS NOT NULL THEN
    NEW.tutelle := t;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_school_herite_tutelle ON public.schools;
CREATE TRIGGER trg_school_herite_tutelle
  BEFORE INSERT OR UPDATE OF group_id ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.fn_school_herite_tutelle();

-- ── Changer la tutelle d'un groupe la propage à ses écoles ──────────────────
CREATE OR REPLACE FUNCTION public.fn_groupe_propage_tutelle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  IF NEW.tutelle IS NOT NULL
     AND (OLD.tutelle IS NULL OR OLD.tutelle <> NEW.tutelle) THEN
    UPDATE public.schools SET tutelle = NEW.tutelle WHERE group_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_groupe_propage_tutelle ON public.school_groups;
CREATE TRIGGER trg_groupe_propage_tutelle
  AFTER UPDATE OF tutelle ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_groupe_propage_tutelle();

-- ── Le lycée avait 13 séries et ne les proposait pas ────────────────────────
--  `has_programs` commande l'écran où une école déclare ses filières. Il était
--  à `false` pour le lycée, alors que le référentiel porte les séries A, C, D,
--  E, F1–F7, G1–G3 : une école ne pouvait donc PAS déclarer les siennes. Elles
--  n'arrivaient qu'une par une, à la création de chaque classe.
--
--  ⚠️ Effet visible : une section « Filières » apparaît sur le cycle Lycée dans
--  la fiche d'école. Additif — rien de ce qui existe ne change de sens.
UPDATE public.education_cycles
   SET has_programs = true
 WHERE code = 'lycee' AND has_programs = false;
