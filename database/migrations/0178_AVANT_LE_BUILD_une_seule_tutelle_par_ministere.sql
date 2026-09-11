-- ════════════════════════════════════════════════════════════════════════════
--  0178 — UN SEUL GROUPE DE TUTELLE PAR MINISTÈRE
--
--  ── LA RÈGLE QUI N'EXISTAIT NULLE PART ────────────────────────────────────
--  La migration 0155 a introduit `school_groups.administre_referentiel_national`
--  et a vérifié, dans un bloc `DO`, qu'il y avait EXACTEMENT un groupe marqué
--  par tutelle. Ce bloc s'est exécuté une fois, puis a disparu avec la
--  migration. Il ne restait ensuite AUCUNE contrainte, AUCUN index : la règle
--  la plus lourde du modèle ne vivait que dans un commentaire.
--
--  Elle a tenu jusqu'ici pour une seule raison : aucun écran n'écrivait la
--  colonne. Elle était posée par 0155 et plus jamais touchée.
--
--  ⚠️ CE BUILD AJOUTE L'INTERRUPTEUR. À partir de là, un super_admin peut
--  accorder ce rôle depuis la fiche du groupe — et rien, aujourd'hui, ne
--  l'empêcherait de l'accorder DEUX FOIS pour le même ministère.
--
--  ── CE QUE DEUX GROUPES DE TUTELLE CASSERAIENT ────────────────────────────
--  Ce booléen n'est pas un réglage d'affichage. À lui seul il ouvre :
--   • l'ÉCRITURE du référentiel national des examens de sa tutelle
--     (politique `national_exams_write`, 0155) — deux groupes concurrents
--     écriraient la même session d'examen d'État ;
--   • la LECTURE de tout le réseau du ministère, écoles qu'il ne possède pas
--     comprises, avec le nom des chefs d'établissement (`tutelle_groupes` /
--     `tutelle_ecoles`, 0158) — un groupe privé promu par erreur verrait les
--     écoles de ses concurrents ;
--   • l'ÉMISSION de circulaires descendant jusqu'aux écoles (0161 / 0167) ;
--   • la vente d'une licence de tutelle (0160).
--
--  ── POURQUOI UN INDEX **ET** UN DÉCLENCHEUR ───────────────────────────────
--  Ils ne font pas le même travail, et l'un sans l'autre serait insuffisant :
--
--   • L'INDEX UNIQUE PARTIEL est la GARANTIE. Il est tenu par le moteur, il
--     survit à tout chemin d'écriture (écran, RPC, psql, service_role) et il
--     est à l'épreuve de la concurrence — deux super_admins qui valident à la
--     même seconde ne peuvent pas passer tous les deux. Un déclencheur qui
--     compte avec un SELECT, lui, a une fenêtre de course.
--
--   • LE DÉCLENCHEUR est le MESSAGE. Seul, l'index rendrait un 23505 que
--     l'application traduit par « Cet enregistrement existe déjà » — vrai, et
--     inutilisable : il ne dit ni QUEL groupe détient le rôle, ni qu'il faut
--     le lui retirer d'abord. Le HINT posé ici est, par convention du dépôt
--     (`message_erreur.dart`), affiché TEL QUEL à l'agent.
--
--  ── ⚠️ CE QU'ON NE CONTRAINT PAS, ET POURQUOI ─────────────────────────────
--  On n'impose PAS « au moins un groupe de tutelle par ministère ». Déplacer
--  le rôle d'un groupe vers un autre impose de le retirer au premier : un
--  plancher rendrait ce déplacement impossible. Le rôle peut donc être vacant
--  le temps d'une manœuvre — c'est réversible, visible, et l'écran le dit.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
--  Le garde doit exister AVANT que l'interrupteur ne soit livré, pas après.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Le garde AVANT l'index ──────────────────────────────────────────────────
--  `CREATE UNIQUE INDEX` sur des données déjà en double échoue avec un message
--  qui ne nomme ni le ministère ni les groupes fautifs. On refuse d'abord, en
--  disant lesquels.
DO $garde$
DECLARE fautifs text;
BEGIN
  SELECT string_agg(t.tutelle || ' (' || t.n || ' groupes)', ', ')
    INTO fautifs
    FROM (SELECT tutelle::text AS tutelle, count(*) AS n
            FROM public.school_groups
           WHERE administre_referentiel_national
           GROUP BY tutelle
          HAVING count(*) > 1) AS t;

  IF fautifs IS NOT NULL THEN
    RAISE EXCEPTION
      'Plusieurs groupes de tutelle pour un meme ministere : %. Retirer '
      'administre_referentiel_national aux groupes en trop AVANT de poser '
      'l''index.', fautifs;
  END IF;
END;
$garde$;

-- ── La garantie ─────────────────────────────────────────────────────────────
--  Partiel : seules les lignes marquées entrent dans l'index. Les six autres
--  groupes n'y figurent pas et peuvent partager leur tutelle sans limite.
--  `tutelle` est NOT NULL depuis 0163 : aucune ligne ne peut s'y soustraire
--  par un NULL.
CREATE UNIQUE INDEX IF NOT EXISTS school_groups_un_seul_par_tutelle
  ON public.school_groups (tutelle)
  WHERE administre_referentiel_national;

COMMENT ON INDEX public.school_groups_un_seul_par_tutelle IS
  'Un seul groupe peut administrer le referentiel national d''un ministere. '
  'Regle posee par 0155 dans un bloc DO ephemere ; rendue permanente par 0178 '
  'le jour ou un ecran a pu accorder ce role.';

-- ── Le message ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_une_seule_tutelle_par_ministere()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE detenteur text;
BEGIN
  -- Retirer le rôle, ou ne pas l'avoir, ne peut créer aucun conflit.
  IF NOT NEW.administre_referentiel_national THEN
    RETURN NEW;
  END IF;

  SELECT sg.name INTO detenteur
    FROM public.school_groups sg
   WHERE sg.administre_referentiel_national
     AND sg.tutelle = NEW.tutelle
     AND sg.id <> NEW.id
   LIMIT 1;

  IF detenteur IS NOT NULL THEN
    RAISE EXCEPTION
      'Le ministere % a deja un groupe de tutelle : %',
      upper(NEW.tutelle::text), detenteur
      USING ERRCODE = '23505',
            HINT = format(
              'Le groupe « %s » est déjà le ministère de tutelle %s. '
              'Retirez-lui d''abord ce rôle avant de l''accorder ici : deux '
              'groupes de tutelle pour un même ministère écriraient tous les '
              'deux le référentiel national des examens.',
              detenteur, upper(NEW.tutelle::text));
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.fn_une_seule_tutelle_par_ministere() IS
  'Rend lisible le refus de school_groups_un_seul_par_tutelle. L''index reste '
  'la garantie : ce declencheur ne fait que nommer le detenteur du role.';

DROP TRIGGER IF EXISTS trg_une_seule_tutelle_par_ministere ON public.school_groups;
CREATE TRIGGER trg_une_seule_tutelle_par_ministere
  BEFORE INSERT OR UPDATE OF administre_referentiel_national, tutelle
  ON public.school_groups
  FOR EACH ROW EXECUTE FUNCTION public.fn_une_seule_tutelle_par_ministere();

COMMIT;
