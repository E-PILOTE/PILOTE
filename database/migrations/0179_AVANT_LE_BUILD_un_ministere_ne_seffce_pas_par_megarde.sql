-- ════════════════════════════════════════════════════════════════════════════
--  0179 — UN MINISTÈRE DE TUTELLE NE S'EFFACE PAS PAR MÉGARDE
--
--  ── LA MOITIÉ QUI RESTAIT OUVERTE ─────────────────────────────────────────
--  La migration 0178 a fermé l'ÉCRITURE : deux groupes ne peuvent plus être
--  ministère du même enseignement. Elle n'a rien dit de la SUPPRESSION.
--
--  `delete_school_group(uuid)` — le seul chemin de suppression de l'écran
--  super_admin — efface une cinquantaine de tables puis le groupe, et ne
--  regarde JAMAIS `administre_referentiel_national`. Vérifié : la colonne
--  n'apparaît pas une fois dans sa définition. Supprimer le groupe MEPSA
--  était donc un clic comme un autre.
--
--  ── CE QUE CE CLIC AURAIT COÛTÉ ───────────────────────────────────────────
--  Le groupe MEPSA porte 14 écoles en propre, mais il est la TUTELLE de 25
--  établissements — les onze autres appartiennent à des groupes tiers, publics
--  et privés. Le supprimer aurait :
--
--   • laissé le référentiel national des examens `mepsa` sans personne pour
--     l'écrire (politique `national_exams_write`, 0155) — plus aucune session
--     d'examen d'État modifiable pour l'enseignement général ;
--   • rendu ces 25 établissements invisibles de leur propre tutelle
--     (`tutelle_groupes` / `tutelle_ecoles`, 0158) ;
--   • coupé toute circulaire descendante (0161 / 0167) ;
--   • et laissé `tutelle_licences` pointer sur un groupe disparu.
--
--  Rien de tout cela ne se serait signalé. L'écran aurait affiché
--  « Groupe supprimé définitivement » en vert.
--
--  ── POURQUOI UN REFUS, ET NON UN AVERTISSEMENT DE PLUS ────────────────────
--  Le dialogue de suppression avertit déjà — écoles, élèves, paiements,
--  archives — et fait cocher « je comprends que cette action est
--  irréversible ». Un cinquième avertissement dans la même liste se serait lu
--  comme les quatre autres. Ici la bonne réponse n'est pas d'insister, c'est
--  de refuser : il existe un chemin sûr, et il est court.
--
--    1. retirer le rôle de tutelle depuis la fiche du groupe (interrupteur) ;
--    2. supprimer le groupe.
--
--  Deux gestes explicites au lieu d'un geste ambigu. Et l'étape 1 force à
--  répondre d'abord à la seule question qui compte : QUI tient le référentiel
--  national après ? Même discipline que 0178, qui n'interdit pas le retrait du
--  rôle mais oblige à le retirer AVANT de l'accorder ailleurs.
--
--  ── POURQUOI UN DÉCLENCHEUR, ET NON UN CONTRÔLE DANS LA RPC ───────────────
--  Un contrôle posé dans `delete_school_group` ne couvrirait QUE cette
--  fonction. Un `DELETE` direct par PostgREST, par psql, par le service_role
--  ou par une future RPC passerait à côté. Le déclencheur est sur la TABLE :
--  il couvre tous les chemins, présents et à venir.
--
--  ── ORDRE : AVANT LE BUILD. Additif, aucune donnée touchée. ───────────────
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_ministere_ne_seffce_pas()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE n_ecoles integer;
BEGIN
  IF NOT OLD.administre_referentiel_national THEN
    RETURN OLD;
  END IF;

  -- Le nombre d'établissements que ce ministère supervise — pas seulement
  -- ceux qu'il possède. C'est la mesure de ce que la suppression emporte.
  SELECT count(*) INTO n_ecoles
    FROM public.schools s
   WHERE s.tutelle = OLD.tutelle;

  RAISE EXCEPTION
    'Le groupe % est le ministere de tutelle % : suppression refusee',
    OLD.name, upper(OLD.tutelle::text)
    USING ERRCODE = '23514',
          HINT = format(
            '« %s » est le ministère de tutelle %s : %s établissement(s) en '
            'dépendent pour leurs examens d''État et leurs circulaires. '
            'Retirez-lui d''abord ce rôle depuis sa fiche — vous devrez alors '
            'dire qui le reprend — puis supprimez le groupe.',
            OLD.name, upper(OLD.tutelle::text), n_ecoles);
END;
$fn$;

COMMENT ON FUNCTION public.fn_ministere_ne_seffce_pas() IS
  'Refuse la suppression d''un groupe marque administre_referentiel_national. '
  'Sur la TABLE et non dans delete_school_group : un DELETE direct passerait '
  'a cote. Le chemin sur reste ouvert — retirer le role, puis supprimer.';

DROP TRIGGER IF EXISTS trg_ministere_ne_seffce_pas ON public.school_groups;
CREATE TRIGGER trg_ministere_ne_seffce_pas
  BEFORE DELETE ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_ministere_ne_seffce_pas();
